import Foundation

/// Picks moves for a computer opponent.
///
/// Easy plays like someone new to the game: usually a sensible move, often just any move.
/// Hard scores every legal move by what it leads to (captures, getting home, reaching
/// shelter, leaving pawns exposed) and plays the best one.
public enum ComputerPlayer {

    public enum Level: String, CaseIterable, Codable, Sendable {
        case easy
        case hard
    }

    public static func chooseMove<G: RandomNumberGenerator>(in state: GameState, level: Level, using generator: inout G) -> Move? {
        let moves = Rules.legalMoves(in: state)
        guard !moves.isEmpty else { return nil }

        let scored = moves.map { (move: $0, score: score($0, in: state)) }
        switch level {
        case .hard:
            let best = scored.map(\.score).max()!
            // Break ties randomly so the computer does not look robotic.
            return scored.filter { $0.score >= best - 0.01 }.randomElement(using: &generator)!.move
        case .easy:
            // Take the best move about a third of the time, otherwise anything goes.
            if Double.random(in: 0..<1, using: &generator) < 0.35 {
                return scored.max { $0.score < $1.score }!.move
            }
            return moves.randomElement(using: &generator)!
        }
    }

    // MARK: Scoring

    /// How good a move looks for the player making it. Higher is better.
    static func score(_ move: Move, in state: GameState) -> Double {
        guard let mover = state[move.pawn] else { return -.infinity }
        var after = state
        guard let outcome = Rules.apply(move, to: &after) else { return -.infinity }
        let seat = state.seat(owning: mover.color)
        var score = 0.0

        if after.winner == seat { return 10_000 }

        if let captured = outcome.captured, let victim = state[captured] {
            // Sending back a pawn that had travelled far is worth more.
            score += 60 + Double(victim.progress ?? 0)
        }
        if outcome.reachedHome { score += 80 }
        if case .enter = move { score += 35 }

        let before = mover.progress ?? -1
        let now = after[move.pawn]?.progress ?? before
        score += Double(max(0, now - before)) * 0.6

        // Pawns in the home column can never be captured.
        if now > Board.homeEntryProgress, before <= Board.homeEntryProgress { score += 25 }

        if case .ring(let index)? = after[move.pawn]?.position {
            if after.isSafe(ring: index) { score += 18 }
            if after.isBlockade(atRing: index) { score += 10 }
        }

        // Every pawn of ours left where an opponent could hit it next turn is a risk,
        // scaled by how much progress would be lost.
        let exposureBefore = exposure(of: seat, in: state)
        let exposureAfter = exposure(of: seat, in: after)
        score -= (exposureAfter - exposureBefore) * 0.9

        return score
    }

    /// Total progress at stake across this seat's pawns that an opponent could reach with
    /// a roll of up to twelve.
    static func exposure(of seat: Seat, in state: GameState) -> Double {
        let opponents = state.pawns(for: seat.opponent).filter { !$0.isHome }
        var total = 0.0
        for pawn in state.pawns(for: seat) {
            guard case .ring(let index) = pawn.position, !state.isSafe(ring: index) else { continue }
            let hunters = opponents.filter { hunter in
                guard let distance = distance(from: hunter, to: index, in: state) else { return false }
                return (1...12).contains(distance)
            }
            guard !hunters.isEmpty else { continue }
            // A pawn two dice can reach is likelier to be hit when it is close.
            total += Double(10 + (pawn.progress ?? 0)) * min(1.0, Double(hunters.count) * 0.6)
        }
        return total
    }

    /// Squares a pawn would travel along its own route to reach a ring square, or nil if
    /// that square is not ahead of it on the ring part of its route.
    private static func distance(from pawn: Pawn, to ring: Int, in state: GameState) -> Int? {
        let target = Board.progress(ofRing: ring, for: pawn.color)
        guard target <= Board.homeEntryProgress else { return nil }
        if pawn.isInNest {
            // A pawn waiting in its nest threatens only its own start square, by entering.
            return ring == Board.entryIndex(for: pawn.color) ? 5 : nil
        }
        guard let progress = pawn.progress, progress <= Board.homeEntryProgress, target > progress else { return nil }
        return target - progress
    }
}
