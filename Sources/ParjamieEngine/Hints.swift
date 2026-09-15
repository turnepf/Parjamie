import Foundation

/// Plain-language coaching for whoever is taking the current turn, for players who
/// are still learning the game. Wording follows exactly what `Rules` allows right now.
public enum Hints {

    /// The hint for the seat whose turn it is, or nil when there is nothing to say.
    /// `selectedValueID` is the number the player has tapped, if any.
    public static func forTurn(in state: GameState, selectedValueID: Int?) -> String? {
        guard state.winner == nil else { return nil }
        switch state.turn.phase {
        case .awaitingRoll:
            return rollHint(in: state)
        case .moving:
            if let selected = state.turn.values.first(where: { $0.id == selectedValueID }) {
                return selectedHint(for: selected, in: state)
            }
            return choosingHint(in: state)
        case .finished:
            return nil
        }
    }

    // MARK: Before rolling

    private static func rollHint(in state: GameState) -> String {
        if state.turn.consecutiveDoubles > 0 {
            return "You rolled doubles, so you get another roll. Tap Strike an arc."
        }
        let pawns = state.pawns(for: state.turn.seat)
        let noneInPlay = pawns.allSatisfy { $0.isInNest || $0.isHome }
        if noneInPlay {
            let shuffled = state.hasShuffledSafeSpots ? " Safe spots are shuffled this game, so look for the purple squares." : ""
            return "Tap Strike an arc to roll. To bring a helmet out of your bay you need \(state.rules.entryPhrase)." + shuffled
        }
        return "Tap Strike an arc to roll the dice."
    }

    // MARK: A number is picked

    private static func selectedHint(for value: MoveValue, in state: GameState) -> String {
        let moves = Rules.legalMoves(in: state).filter { $0.spentValueIDs.contains(value.id) }
        guard !moves.isEmpty else {
            return "No helmet can move \(value.amount) right now. Tap a different number."
        }
        let enters = moves.contains { if case .enter = $0 { true } else { false } }
        let advances = moves.contains { if case .advance = $0 { true } else { false } }
        let orMove = advances ? " Or tap a glowing helmet on the board to move it \(value.amount) spaces." : ""

        if enters {
            if state.rules.entryFaces.contains(value.amount) {
                return "Tap a glowing helmet in your bay to bring it onto your start square." + orMove
            }
            return "Tap a glowing helmet in your bay to bring it out. That uses your \(value.amount) and \(state.rules.entryTotal - value.amount) together." + orMove
        }
        return "Tap a glowing helmet to move it \(value.amount) spaces. The outline shows where it will land."
    }

    // MARK: Nothing picked yet

    private static func choosingHint(in state: GameState) -> String {
        let values = state.turn.values
        let moves = Rules.legalMoves(in: state)
        var parts: [String] = []

        if values.count == 1, let only = values.first {
            parts.append("Tap a glowing helmet to move it \(only.amount) spaces. The outline shows where it will land.")
        } else {
            parts.append("Tap one of the numbers under the board, then tap a glowing helmet to move it that many spaces.")
        }

        let enterMoves = moves.compactMap { move -> [Int]? in
            if case .enter(_, let ids) = move { ids } else { nil }
        }
        let dice = values.filter { $0.kind == .die }
        if let single = enterMoves.first(where: { $0.count == 1 }),
           let face = dice.first(where: { $0.id == single[0] }) {
            parts.append("You have a \(face.amount), so you can bring a helmet out: tap the \(face.amount), then a glowing helmet in your bay.")
        } else if let pair = enterMoves.first(where: { $0.count == 2 }),
                  let a = dice.first(where: { $0.id == pair[0] }),
                  let b = dice.first(where: { $0.id == pair[1] }) {
            parts.append("Your \(a.amount) and \(b.amount) add up to \(a.amount + b.amount), so you can bring a helmet out: tap either one, then a glowing helmet in your bay.")
        } else if entryIsBlocked(in: state) {
            parts.append("Two helmets are welded together on your start square, which blocks it. Move one of them off before bringing out another.")
        }

        if values.contains(where: { $0.kind == .captureBonus }) {
            parts.append("The +20 is your reward for capturing. Spend it all on one helmet.")
        }
        if values.contains(where: { $0.kind == .homeBonus }) {
            parts.append("The +10 is your reward for getting a helmet home. Spend it all on one helmet.")
        }
        if dice.count == 4 {
            parts.append("Doubles with every helmet out also gives you the bottoms of the dice, so you have four moves.")
        }

        return parts.joined(separator: " ")
    }

    // MARK: A tap that did nothing

    /// Why tapping this pawn did not move it, in words a new player can act on.
    public static func whyCantMove(_ pawnID: PawnID, in state: GameState, selectedValueID: Int?) -> String {
        guard state.winner == nil else { return "The game is over." }
        guard state.colors(for: state.turn.seat).contains(pawnID.color) else {
            return "That helmet belongs to the other player. Yours are the ones in your own color."
        }
        guard state.turn.phase == .moving else { return "Strike an arc to roll the dice first." }
        guard let pawn = state[pawnID] else { return "That helmet can't move right now." }
        if pawn.isHome { return "That helmet is already home." }

        let selected = state.turn.values.first { $0.id == selectedValueID }
        if pawn.isInNest {
            if state.isBlockade(atRing: Board.entryIndex(for: pawn.color)) {
                return "Your start square is blocked by two helmets welded together. Move one of them off first."
            }
            if selected?.kind != nil && selected?.kind != .die {
                return "Bonus moves can't bring a helmet out. Pick a die instead."
            }
            return "Helmets leave the bay only on \(state.rules.entryPhrase)."
        }

        let amounts = selected.map { [$0] } ?? state.turn.values
        guard let value = amounts.first, let progress = pawn.progress else {
            return "That helmet has no move with this roll."
        }
        let reason: String
        if Board.position(atProgress: progress + value.amount, for: pawn.color) == nil, state.rules.home == .exact {
            reason = "it would overshoot home. Getting in needs an exact count"
        } else if (1...value.amount).contains(where: { step in
            if case .ring(let index)? = Board.position(atProgress: progress + step, for: pawn.color) {
                return state.isBlockade(atRing: index)
            }
            return false
        }) {
            reason = "two helmets welded together are blocking the way"
        } else {
            reason = "that square is taken"
        }
        if selected != nil {
            return "That helmet can't move \(value.amount): \(reason). Try a different number or helmet."
        }
        return "That helmet can't use this roll: \(reason)."
    }

    /// Whether a pawn could have entered on these dice if its starting square were not blockaded.
    private static func entryIsBlocked(in state: GameState) -> Bool {
        let dice = state.turn.values.filter { $0.kind == .die }.map(\.amount)
        let canEnter = dice.contains(where: state.rules.entryFaces.contains) || dice.indices.contains { i in
            dice.indices.contains { j in j > i && dice[i] + dice[j] == state.rules.entryTotal }
        }
        guard canEnter else { return false }
        return state.pawns(for: state.turn.seat).contains {
            $0.isInNest && state.isBlockade(atRing: Board.entryIndex(for: $0.color))
        }
    }
}
