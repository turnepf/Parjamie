import XCTest
@testable import ParjamieNet
import ParjamieEngine

final class FramingTests: XCTestCase {

    private let sample: [GameMessage] = [
        .hello(Hello(displayName: "Fiona")),
        .requestRoll,
        .snapshot(GameState(setup: .twoColorsEach)),
        .requestMove(.advance(pawn: PawnID(color: .red, index: 2), spending: 3)),
        .ping,
        .scoreboard([GameRecord(id: UUID(), finishedAt: Date(timeIntervalSince1970: 1_800_000_000), setup: .oneColorEach,
                                players: ["Jamie", "Fiona"], winner: "Fiona", onePhone: false)])
    ]

    func testEachMessageSurvivesARoundTrip() throws {
        var parser = MessageFraming.Parser()
        for message in sample {
            let decoded = try parser.append(try MessageFraming.encode(message))
            XCTAssertEqual(decoded, [message])
        }
    }

    func testSeveralMessagesArrivingInOneChunkAreAllRead() throws {
        var stream = Data()
        for message in sample { stream.append(try MessageFraming.encode(message)) }

        var parser = MessageFraming.Parser()
        XCTAssertEqual(try parser.append(stream), sample)
    }

    func testAMessageSplitAcrossPacketsIsReassembled() throws {
        let framed = try MessageFraming.encode(.snapshot(GameState(setup: .oneColorEach)))
        var parser = MessageFraming.Parser()

        // Deliver one byte at a time, the worst case a network can hand us.
        var delivered: [GameMessage] = []
        for byte in framed {
            delivered += try parser.append(Data([byte]))
        }
        XCTAssertEqual(delivered.count, 1)
    }

    func testAPartialHeaderYieldsNothingAndWaits() throws {
        var parser = MessageFraming.Parser()
        XCTAssertEqual(try parser.append(Data([0, 0])), [])
    }

    func testAnAbsurdLengthHeaderIsRejected() {
        var parser = MessageFraming.Parser()
        XCTAssertThrowsError(try parser.append(Data([0xFF, 0xFF, 0xFF, 0xFF])))
    }

    func testProtocolVersionTravelsInTheHandshake() throws {
        let welcome = Welcome(displayName: "Jamie", seat: .two, state: GameState(setup: .oneColorEach))
        var parser = MessageFraming.Parser()
        let decoded = try parser.append(try MessageFraming.encode(.welcome(welcome)))
        guard case .welcome(let received)? = decoded.first else { return XCTFail("expected a welcome") }
        XCTAssertEqual(received.protocolVersion, ProtocolVersion.current)
        XCTAssertEqual(received.seat, .two)
    }
}
