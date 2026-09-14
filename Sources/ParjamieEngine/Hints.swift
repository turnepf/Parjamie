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
            return "You rolled doubles, so you get another roll. Tap Strike an Arc."
        }
        let pawns = state.pawns(for: state.turn.seat)
        let noneInPlay = pawns.allSatisfy { $0.isInNest || $0.isHome }
        if noneInPlay {
            return "Tap Strike an Arc to roll. To bring a pawn out of your nest you need a 5: one die showing 5, or both dice adding up to 5."
        }
        return "Tap Strike an Arc to roll the dice."
    }

    // MARK: A number is picked

    private static func selectedHint(for value: MoveValue, in state: GameState) -> String {
        let moves = Rules.legalMoves(in: state).filter { $0.spentValueIDs.contains(value.id) }
        guard !moves.isEmpty else {
            return "No pawn can move \(value.amount) right now. Tap a different number."
        }
        let enters = moves.contains { if case .enter = $0 { true } else { false } }
        let advances = moves.contains { if case .advance = $0 { true } else { false } }
        let orMove = advances ? " Or tap a glowing pawn on the board to move it \(value.amount) spaces." : ""

        if enters {
            if value.amount == 5 {
                return "Tap a glowing pawn in your nest to bring it onto the board." + orMove
            }
            return "Tap a glowing pawn in your nest to bring it out. That uses your \(value.amount) and \(5 - value.amount) together." + orMove
        }
        return "Tap a glowing pawn to move it \(value.amount) spaces."
    }

    // MARK: Nothing picked yet

    private static func choosingHint(in state: GameState) -> String {
        let values = state.turn.values
        let moves = Rules.legalMoves(in: state)
        var parts: [String] = []

        if values.count == 1, let only = values.first {
            parts.append("Tap a glowing pawn to move it \(only.amount) spaces.")
        } else {
            parts.append("Tap one of the numbers under the board, then tap a glowing pawn to move it that many spaces.")
        }

        let enterMoves = moves.compactMap { move -> [Int]? in
            if case .enter(_, let ids) = move { ids } else { nil }
        }
        let dice = values.filter { $0.kind == .die }
        if enterMoves.contains(where: { $0.count == 1 }) {
            parts.append("You have a 5, so you can bring a pawn out: tap the 5, then a glowing pawn in your nest.")
        } else if let pair = enterMoves.first(where: { $0.count == 2 }),
                  let a = dice.first(where: { $0.id == pair[0] }),
                  let b = dice.first(where: { $0.id == pair[1] }) {
            parts.append("Your \(a.amount) and \(b.amount) add up to 5, so you can bring a pawn out: tap either one, then a glowing pawn in your nest.")
        } else if entryIsBlocked(in: state) {
            parts.append("Two pawns are welded together on your starting square, which blocks it. Move one of them off before bringing out another pawn.")
        }

        if values.contains(where: { $0.kind == .captureBonus }) {
            parts.append("The +20 is your reward for capturing. Spend it all on one pawn.")
        }
        if values.contains(where: { $0.kind == .homeBonus }) {
            parts.append("The +10 is your reward for getting a pawn home. Spend it all on one pawn.")
        }
        if dice.count == 4 {
            parts.append("Doubles with every pawn out also gives you the bottoms of the dice, so you have four moves.")
        }

        return parts.joined(separator: " ")
    }

    /// Whether a pawn could have entered on these dice if its starting square were not blockaded.
    private static func entryIsBlocked(in state: GameState) -> Bool {
        let dice = state.turn.values.filter { $0.kind == .die }.map(\.amount)
        let hasFive = dice.contains(5) || dice.indices.contains { i in
            dice.indices.contains { j in j > i && dice[i] + dice[j] == 5 }
        }
        guard hasFive else { return false }
        return state.pawns(for: state.turn.seat).contains {
            $0.isInNest && state.isBlockade(atRing: Board.entryIndex(for: $0.color))
        }
    }
}
