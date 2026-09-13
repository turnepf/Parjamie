import Foundation

// MARK: - Pawns

public struct PawnID: Hashable, Codable, Sendable {
    public let color: PlayerColor
    public let index: Int

    public init(color: PlayerColor, index: Int) {
        self.color = color
        self.index = index
    }
}

public enum PawnPosition: Hashable, Codable, Sendable {
    case nest
    case ring(Int)
    case homeColumn(Int)
    case home
}

public struct Pawn: Hashable, Codable, Sendable, Identifiable {
    public let id: PawnID
    public var position: PawnPosition

    public init(id: PawnID, position: PawnPosition = .nest) {
        self.id = id
        self.position = position
    }

    public var color: PlayerColor { id.color }
    public var isInNest: Bool { position == .nest }
    public var isHome: Bool { position == .home }

    /// Squares travelled since leaving the nest, or nil while still in the nest.
    public var progress: Int? {
        switch position {
        case .nest: nil
        case .ring(let index): Board.progress(ofRing: index, for: color)
        case .homeColumn(let step): Board.homeEntryProgress + 1 + step
        case .home: Board.homeProgress
        }
    }
}

// MARK: - Seats and setup

public enum Seat: Int, Codable, CaseIterable, Sendable, Hashable {
    case one = 0
    case two = 1

    public var opponent: Seat { self == .one ? .two : .one }
}

/// The one choice players make before a game starts.
public enum PawnSetup: String, Codable, CaseIterable, Sendable {
    /// One color each, four pawns per player. Colors sit on opposite arms.
    case oneColorEach
    /// Two colors each, eight pawns per player. The traditional two-player adaptation.
    case twoColorsEach

    public func colors(for seat: Seat) -> [PlayerColor] {
        switch self {
        case .oneColorEach:
            return seat == .one ? [.red] : [.yellow]
        case .twoColorsEach:
            return seat == .one ? [.red, .yellow] : [.blue, .green]
        }
    }

    public var allColors: [PlayerColor] {
        colors(for: .one) + colors(for: .two)
    }
}

// MARK: - Dice and move values

public struct DiceRoll: Hashable, Codable, Sendable {
    public let first: Int
    public let second: Int

    public init(first: Int, second: Int) {
        self.first = first
        self.second = second
    }

    public var isDoubles: Bool { first == second }
}

/// A single unused amount the current seat may spend on one pawn.
///
/// Dice values and bonus values are tracked separately because only dice may be
/// combined to enter a pawn from the nest, and only dice count toward doubles.
public struct MoveValue: Hashable, Codable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case die
        case captureBonus
        case homeBonus
    }

    public let id: Int
    public let amount: Int
    public let kind: Kind

    public init(id: Int, amount: Int, kind: Kind) {
        self.id = id
        self.amount = amount
        self.kind = kind
    }
}

// MARK: - Moves

public enum Move: Hashable, Codable, Sendable {
    /// Bring a pawn out of the nest onto its entry square, spending one five or two dice totalling five.
    case enter(pawn: PawnID, spending: [Int])
    /// Advance a pawn already in play, spending one value.
    case advance(pawn: PawnID, spending: Int)

    public var pawn: PawnID {
        switch self {
        case .enter(let pawn, _): pawn
        case .advance(let pawn, _): pawn
        }
    }

    public var spentValueIDs: [Int] {
        switch self {
        case .enter(_, let ids): ids
        case .advance(_, let id): [id]
        }
    }
}

// MARK: - Turn state

public enum TurnPhase: String, Codable, Sendable {
    case awaitingRoll
    case moving
    case finished
}

public struct TurnState: Hashable, Codable, Sendable {
    public var seat: Seat
    public var phase: TurnPhase
    public var roll: DiceRoll?
    public var values: [MoveValue]
    public var consecutiveDoubles: Int
    /// Increments so every value issued in a game has a distinct id.
    public var nextValueID: Int

    public init(
        seat: Seat = .one,
        phase: TurnPhase = .awaitingRoll,
        roll: DiceRoll? = nil,
        values: [MoveValue] = [],
        consecutiveDoubles: Int = 0,
        nextValueID: Int = 0
    ) {
        self.seat = seat
        self.phase = phase
        self.roll = roll
        self.values = values
        self.consecutiveDoubles = consecutiveDoubles
        self.nextValueID = nextValueID
    }
}

// MARK: - Game state

/// The complete game. This is the unit the host broadcasts after every move, so it
/// carries a version counter the other device uses to detect gaps.
public struct GameState: Hashable, Codable, Sendable {
    public var setup: PawnSetup
    public var pawns: [Pawn]
    public var turn: TurnState
    public var winner: Seat?
    public var version: Int

    public init(setup: PawnSetup) {
        self.setup = setup
        self.pawns = setup.allColors.flatMap { color in
            (0..<Board.pawnsPerColor).map { Pawn(id: PawnID(color: color, index: $0)) }
        }
        self.turn = TurnState()
        self.winner = nil
        self.version = 0
    }

    public func seat(owning color: PlayerColor) -> Seat {
        setup.colors(for: .one).contains(color) ? .one : .two
    }

    public func colors(for seat: Seat) -> [PlayerColor] {
        setup.colors(for: seat)
    }

    public func pawns(for seat: Seat) -> [Pawn] {
        let owned = Set(colors(for: seat))
        return pawns.filter { owned.contains($0.color) }
    }

    public func pawns(onRing index: Int) -> [Pawn] {
        pawns.filter { $0.position == .ring(index) }
    }

    /// Two pawns of one color on a square block every pawn, including their own.
    public func isBlockade(atRing index: Int) -> Bool {
        pawns(onRing: index).count >= 2
    }

    public subscript(id: PawnID) -> Pawn? {
        pawns.first { $0.id == id }
    }

    mutating func update(_ id: PawnID, to position: PawnPosition) {
        guard let slot = pawns.firstIndex(where: { $0.id == id }) else { return }
        pawns[slot].position = position
    }
}
