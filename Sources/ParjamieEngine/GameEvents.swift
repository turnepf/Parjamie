import Foundation

/// Something worth celebrating (or groaning at) between two snapshots of a game.
///
/// Both devices only ever see whole states, so events are recovered by comparing the
/// board before and after. That keeps the effects identical on the host and the guest
/// without adding anything to the network protocol.
public enum GameEvent: Hashable, Sendable {
    /// A pawn left one spot for another, including leaving the nest.
    case moved(PawnID, to: PawnPosition)
    /// An opponent landed on this pawn and sent it back to its nest.
    case captured(PawnID, at: PawnPosition)
    case reachedHome(PawnID)
    /// Three doubles in a row sent this pawn back to its nest.
    case overheated(PawnID, at: PawnPosition)
    /// Doubles with every pawn out also earned the bottoms of the dice: four moves.
    case bottomsOfTheDice(DiceRoll)
    case won(Seat)
}

public enum GameEvents {

    public static func between(_ old: GameState, _ new: GameState) -> [GameEvent] {
        // A different game (new setup, or a fresh start) is not a sequence of moves.
        guard new.id == old.id,
              new.version > old.version,
              old.setup == new.setup,
              old.pawns.map(\.id) == new.pawns.map(\.id) else { return [] }

        var events: [GameEvent] = []
        // A doubles roll is the only thing that bumps the doubles count. The three-doubles
        // penalty resets it, and that roll gets no moves at all.
        if old.turn.phase == .awaitingRoll,
           new.turn.seat == old.turn.seat,
           new.turn.consecutiveDoubles == old.turn.consecutiveDoubles + 1,
           let roll = new.turn.roll, Rules.grantsBottoms(roll, in: old) {
            events.append(.bottomsOfTheDice(roll))
        }

        var sentBack: [(PawnID, PawnPosition)] = []
        for (before, after) in zip(old.pawns, new.pawns) where before.position != after.position {
            if after.position == .nest {
                sentBack.append((after.id, before.position))
            } else {
                events.append(.moved(after.id, to: after.position))
                if after.position == .home { events.append(.reachedHome(after.id)) }
            }
        }

        // A capture always comes with the capturing pawn moving. A pawn going back on
        // its own is the three-doubles penalty.
        let someoneMoved = !events.isEmpty
        if sentBack.count > 1 { return [] }
        if let (pawn, spot) = sentBack.first {
            events.append(someoneMoved ? .captured(pawn, at: spot) : .overheated(pawn, at: spot))
        }

        if old.winner == nil, let winner = new.winner {
            events.append(.won(winner))
        }
        return events
    }
}
