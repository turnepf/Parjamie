import Foundation

/// The four playing colors. Each owns one arm of the cross.
public enum PlayerColor: String, Codable, CaseIterable, Sendable, Hashable {
    case red, blue, yellow, green

    /// Arm order around the ring: south, west, north, east.
    public var armIndex: Int {
        switch self {
        case .red: 0
        case .blue: 1
        case .yellow: 2
        case .green: 3
        }
    }
}

/// Board geometry, in squares rather than pixels.
///
/// The board is a cross of four arms. Each arm gives 17 squares to the shared ring:
/// eight up one side, one at the tip, eight back down the other. Four arms make a ring
/// of 68. The middle column of each arm is that color's private home column of seven
/// squares running inward to the center.
///
/// A pawn's `progress` counts squares travelled since it left the nest. Progress 0 is
/// the entry square, progress 60 is the tip of the pawn's own arm where it turns off
/// the ring, progress 61 through 67 are the home column, and progress 68 is home.
public enum Board {
    public static let ringLength = 68
    public static let armLength = 17
    public static let homeColumnLength = 7
    public static let pawnsPerColor = 4

    /// Where in its own arm a color's entry square sits.
    static let entryOffsetInArm = 16
    /// Progress at which a pawn reaches its own tip and turns into the home column.
    public static let homeEntryProgress = 60
    /// Progress meaning home. Reaching it needs an exact count.
    public static let homeProgress = homeEntryProgress + homeColumnLength + 1

    /// Ring square a pawn steps onto when it leaves the nest. Its nest sits in the
    /// board corner right beside it.
    public static func entryIndex(for color: PlayerColor) -> Int {
        (color.armIndex * armLength + entryOffsetInArm) % ringLength
    }

    /// The tip square of a color's own arm, where it leaves the ring for home.
    public static func homeEntryIndex(for color: PlayerColor) -> Int {
        (entryIndex(for: color) + homeEntryProgress) % ringLength
    }

    /// Offsets within each arm that are safety squares in the classic layout. Offset 16 is
    /// the entry square.
    public static let safetyOffsets: Set<Int> = [4, 11, 16]

    /// Whether a square is safe in the classic layout. A game with shuffled safe spots
    /// asks `GameState.isSafe(ring:)` instead.
    public static func isSafety(ring index: Int) -> Bool {
        safetyOffsets.contains(index % armLength)
    }

    /// Ring squares that are safe when every arm uses the same offsets.
    public static func safeSquares(offsets: Set<Int>) -> Set<Int> {
        Set((0..<ringLength).filter { offsets.contains($0 % armLength) })
    }

    /// A fresh layout of safe spots for the shuffled-safe-spots option.
    ///
    /// Two squares per arm move to new places, and every arm gets the same pair, so each
    /// player finds the same shelter at the same distance from their start. Start squares
    /// stay safe. The arm's tip, where a color turns for home, and the squares touching
    /// the center are left out so safe spots never crowd the corners.
    public static func shuffledSafetyOffsets<G: RandomNumberGenerator>(using generator: inout G) -> Set<Int> {
        let candidates = Array(1...7) + Array(9...14)
        while true {
            let first = candidates.randomElement(using: &generator)!
            let second = candidates.randomElement(using: &generator)!
            if abs(first - second) >= 3 { return [first, second, entryOffsetInArm] }
        }
    }

    public static func isEntry(ring index: Int) -> Bool {
        index % armLength == entryOffsetInArm
    }

    /// How far along its own journey a color is when standing on the given ring square.
    public static func progress(ofRing index: Int, for color: PlayerColor) -> Int {
        (index - entryIndex(for: color) + ringLength) % ringLength
    }

    /// Where a pawn of this color stands at the given progress, or nil if it overshoots home.
    public static func position(atProgress progress: Int, for color: PlayerColor) -> PawnPosition? {
        switch progress {
        case ...(-1):
            return nil
        case 0...homeEntryProgress:
            return .ring((entryIndex(for: color) + progress) % ringLength)
        case (homeEntryProgress + 1)..<homeProgress:
            return .homeColumn(progress - homeEntryProgress - 1)
        case homeProgress:
            return .home
        default:
            return nil
        }
    }
}
