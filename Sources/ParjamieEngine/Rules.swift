import Foundation

/// What a single move did, so the interface can animate it.
public struct MoveOutcome: Hashable, Sendable {
    public var captured: PawnID?
    public var reachedHome: Bool = false
    public var bonusesAwarded: [MoveValue] = []
}

/// The classic race-home rules. Every function here is pure, so the host can apply a move
/// and hand the resulting state to the other device with no hidden context.
public enum Rules {

    // MARK: - Rolling

    public static func applyRoll(_ roll: DiceRoll, to state: inout GameState) {
        guard state.winner == nil, state.turn.phase == .awaitingRoll else { return }

        state.turn.roll = roll
        if roll.isDoubles {
            state.turn.consecutiveDoubles += 1
            if state.turn.consecutiveDoubles >= 3 {
                applyThreeDoublesPenalty(to: &state)
                return
            }
        } else {
            state.turn.consecutiveDoubles = 0
        }

        // Rolling doubles with every pawn out of the nest also grants the underside of
        // each die, so the seat gets four moves instead of two.
        let everyPawnOut = state.pawns(for: state.turn.seat).allSatisfy { !$0.isInNest }
        let amounts: [Int] = roll.isDoubles && everyPawnOut
            ? [roll.first, roll.first, 7 - roll.first, 7 - roll.first]
            : [roll.first, roll.second]

        state.turn.values = amounts.map { issue($0, kind: .die, in: &state) }
        state.turn.phase = .moving
        state.version += 1
        resolvePhase(of: &state)
    }

    /// Three doubles in a row sends the seat's farthest-along pawn back to the nest.
    static func applyThreeDoublesPenalty(to state: inout GameState) {
        let inPlay = state.pawns(for: state.turn.seat).filter { !$0.isInNest && !$0.isHome }
        if let farthest = inPlay.max(by: { ($0.progress ?? -1) < ($1.progress ?? -1) }) {
            state.update(farthest.id, to: .nest)
        }
        state.turn.values = []
        state.turn.roll = nil
        state.turn.consecutiveDoubles = 0
        state.turn.seat = state.turn.seat.opponent
        state.turn.phase = .awaitingRoll
        state.version += 1
    }

    // MARK: - Legal moves

    public static func legalMoves(in state: GameState) -> [Move] {
        guard state.winner == nil, state.turn.phase == .moving else { return [] }

        let owned = Set(state.colors(for: state.turn.seat))
        let dice = state.turn.values.filter { $0.kind == .die }
        var moves: [Move] = []

        // A pawn leaves the nest on a five, either one die showing five or both dice
        // totalling five. Bonus moves may never be spent on entering.
        var entryCombinations: [[Int]] = dice.filter { $0.amount == 5 }.map { [$0.id] }
        for i in dice.indices {
            for j in dice.indices where j > i && dice[i].amount + dice[j].amount == 5 {
                entryCombinations.append([dice[i].id, dice[j].id])
            }
        }
        if !entryCombinations.isEmpty {
            for pawn in state.pawns where owned.contains(pawn.color) && pawn.isInNest {
                guard !state.isBlockade(atRing: Board.entryIndex(for: pawn.color)) else { continue }
                moves += entryCombinations.map { .enter(pawn: pawn.id, spending: $0) }
            }
        }

        for pawn in state.pawns where owned.contains(pawn.color) && !pawn.isInNest && !pawn.isHome {
            for value in state.turn.values
            where destination(for: pawn, advancing: value.amount, in: state) != nil {
                moves.append(.advance(pawn: pawn.id, spending: value.id))
            }
        }

        return moves
    }

    /// Where a move would leave its pawn, or nil when the move does not apply.
    public static func landing(of move: Move, in state: GameState) -> PawnPosition? {
        switch move {
        case .enter(let pawn, _):
            return .ring(Board.entryIndex(for: pawn.color))
        case .advance(let id, let valueID):
            guard let pawn = state[id],
                  let value = state.turn.values.first(where: { $0.id == valueID }) else { return nil }
            return destination(for: pawn, advancing: value.amount, in: state)
        }
    }

    /// Where a pawn lands, or nil when the move is illegal.
    public static func destination(for pawn: Pawn, advancing amount: Int, in state: GameState) -> PawnPosition? {
        guard let from = pawn.progress, amount > 0 else { return nil }
        let target = from + amount
        // Home needs an exact count, so overshooting is not a move.
        guard let landing = Board.position(atProgress: target, for: pawn.color) else { return nil }

        // No pawn may pass or land on a blockade, not even one of its own color.
        for step in (from + 1)...target {
            if case .ring(let index)? = Board.position(atProgress: step, for: pawn.color),
               state.isBlockade(atRing: index) {
                return nil
            }
        }

        switch landing {
        case .ring(let index):
            let occupants = state.pawns(onRing: index).filter { $0.id != pawn.id }
            guard occupants.count < 2 else { return nil }
            guard let other = occupants.first else { return landing }
            if other.color == pawn.color { return landing }
            // Safety squares shelter their occupant from being bumped.
            return Board.isSafety(ring: index) ? nil : landing
        case .homeColumn(let step):
            let taken = state.pawns.contains {
                $0.color == pawn.color && $0.id != pawn.id && $0.position == .homeColumn(step)
            }
            return taken ? nil : landing
        case .home:
            return landing
        case .nest:
            return nil
        }
    }

    // MARK: - Applying moves

    @discardableResult
    public static func apply(_ move: Move, to state: inout GameState) -> MoveOutcome? {
        guard legalMoves(in: state).contains(move) else { return nil }
        var outcome = MoveOutcome()

        switch move {
        case .enter(let pawnID, let spending):
            let entry = Board.entryIndex(for: pawnID.color)
            // Entering bumps an opponent off the entry square even though it is a safety.
            if let victim = state.pawns(onRing: entry).first(where: { $0.color != pawnID.color }) {
                state.update(victim.id, to: .nest)
                outcome.captured = victim.id
            }
            state.update(pawnID, to: .ring(entry))
            state.turn.values.removeAll { spending.contains($0.id) }

        case .advance(let pawnID, let valueID):
            guard let pawn = state[pawnID],
                  let value = state.turn.values.first(where: { $0.id == valueID }),
                  let landing = destination(for: pawn, advancing: value.amount, in: state)
            else { return nil }

            if case .ring(let index) = landing,
               let victim = state.pawns(onRing: index).first(where: { $0.color != pawnID.color }) {
                state.update(victim.id, to: .nest)
                outcome.captured = victim.id
            }
            state.update(pawnID, to: landing)
            outcome.reachedHome = landing == .home
            state.turn.values.removeAll { $0.id == valueID }
        }

        if outcome.captured != nil {
            outcome.bonusesAwarded.append(issue(20, kind: .captureBonus, in: &state))
        }
        if outcome.reachedHome {
            outcome.bonusesAwarded.append(issue(10, kind: .homeBonus, in: &state))
        }
        state.turn.values += outcome.bonusesAwarded

        if state.pawns(for: state.turn.seat).allSatisfy(\.isHome) {
            state.winner = state.turn.seat
        }

        state.version += 1
        resolvePhase(of: &state)
        return outcome
    }

    // MARK: - Turn progression

    /// Ends the move phase once the seat has nothing left it can legally do.
    static func resolvePhase(of state: inout GameState) {
        if state.winner != nil {
            state.turn.phase = .finished
            state.turn.values = []
            return
        }
        guard state.turn.phase == .moving else { return }
        guard legalMoves(in: state).isEmpty else { return }

        // Unusable values are forfeited.
        state.turn.values = []
        if state.turn.roll?.isDoubles == true {
            // Doubles earns another roll for the same seat.
            state.turn.phase = .awaitingRoll
        } else {
            state.turn.seat = state.turn.seat.opponent
            state.turn.consecutiveDoubles = 0
            state.turn.roll = nil
            state.turn.phase = .awaitingRoll
        }
    }

    static func issue(_ amount: Int, kind: MoveValue.Kind, in state: inout GameState) -> MoveValue {
        let value = MoveValue(id: state.turn.nextValueID, amount: amount, kind: kind)
        state.turn.nextValueID += 1
        return value
    }
}
