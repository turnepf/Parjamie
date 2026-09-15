import Foundation
import ParjamieEngine

/// Bumped whenever the messages below change shape. The two devices compare this
/// during the handshake so a stale build says so instead of corrupting a game.
public enum ProtocolVersion {
    public static let current = 4
}

public enum BonjourService {
    public static let type = "_parjamie._tcp"
    public static let domain = "local."
}

public struct Hello: Hashable, Codable, Sendable {
    public var protocolVersion: Int = ProtocolVersion.current
    public var displayName: String

    public init(displayName: String) {
        self.displayName = displayName
    }
}

public struct Welcome: Hashable, Codable, Sendable {
    public var protocolVersion: Int = ProtocolVersion.current
    public var displayName: String
    /// The seat the joining device plays. The host always keeps seat one.
    public var seat: Seat
    public var state: GameState

    public init(displayName: String, seat: Seat, state: GameState) {
        self.displayName = displayName
        self.seat = seat
        self.state = state
    }
}

public enum Rejection: String, Hashable, Codable, Sendable {
    case protocolMismatch
    case gameInProgress
}

/// Everything the two devices say to each other.
///
/// The host owns the game. A guest never changes its own state directly, it asks and
/// then redraws from the snapshot it gets back. That is what makes the two boards
/// impossible to desynchronize.
public enum GameMessage: Hashable, Codable, Sendable {
    case hello(Hello)
    case welcome(Welcome)
    case rejected(Rejection, hostProtocolVersion: Int)
    case snapshot(GameState)
    case requestRoll
    case requestMove(Move)
    case requestNewGame(PawnSetup)
    case ping
    case pong
    /// Every finished game this phone remembers. Both phones send theirs after connecting
    /// and keep the union, so the two scoreboards agree.
    case scoreboard([GameRecord])
}

// MARK: - Framing

/// TCP is a stream, not a sequence of messages, so every payload goes out behind a
/// four byte length header and the receiver reassembles.
public enum MessageFraming {
    public static let maximumPayloadBytes = 1 << 20

    public enum FramingError: Error, Equatable {
        case payloadTooLarge(Int)
    }

    public static func encode(_ message: GameMessage) throws -> Data {
        let payload = try JSONEncoder().encode(message)
        guard payload.count <= maximumPayloadBytes else {
            throw FramingError.payloadTooLarge(payload.count)
        }
        var framed = Data(capacity: payload.count + 4)
        var length = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &length) { framed.append(contentsOf: $0) }
        framed.append(payload)
        return framed
    }

    /// Accumulates bytes as they arrive and hands back whole messages.
    public struct Parser: Sendable {
        private var buffer = Data()
        private let decoder = JSONDecoder()

        public init() {}

        public mutating func append(_ incoming: Data) throws -> [GameMessage] {
            buffer.append(incoming)
            var messages: [GameMessage] = []

            while buffer.count >= 4 {
                let length = buffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
                guard length <= UInt32(maximumPayloadBytes) else {
                    throw FramingError.payloadTooLarge(Int(length))
                }
                let total = 4 + Int(length)
                guard buffer.count >= total else { break }

                let payload = buffer.subdata(in: 4..<total)
                buffer.removeSubrange(0..<total)
                messages.append(try decoder.decode(GameMessage.self, from: payload))
            }
            return messages
        }
    }
}
