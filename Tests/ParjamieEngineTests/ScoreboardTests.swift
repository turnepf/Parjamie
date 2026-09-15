import XCTest
@testable import ParjamieEngine

final class ScoreboardTests: XCTestCase {

    private func record(_ winner: String, over loser: String, daysAgo: Double = 0, id: UUID = UUID()) -> GameRecord {
        GameRecord(id: id, finishedAt: Date(timeIntervalSinceNow: -daysAgo * 86_400), setup: .oneColorEach,
                   players: [winner, loser], winner: winner, onePhone: false)
    }

    func testTheSameGameFromBothPhonesCountsOnce() {
        let shared = UUID()
        var board = Scoreboard()
        XCTAssertTrue(board.add(record("Jamie", over: "Fiona", id: shared)))
        XCTAssertFalse(board.add(record("Jamie", over: "Fiona", id: shared)))
        board.merge([record("Jamie", over: "Fiona", id: shared), record("Fiona", over: "Jamie")])
        XCTAssertEqual(board.records.count, 2)
    }

    func testStandingsIgnoreCapitalizationAndPreferTheNewestSpelling() {
        let board = Scoreboard(records: [
            record("jamie", over: "Fiona", daysAgo: 3),
            record("Jamie ", over: "Fiona", daysAgo: 2),
            record("Fiona", over: "Jamie", daysAgo: 1)
        ])
        XCTAssertEqual(board.standings, [
            .init(name: "Jamie", wins: 2, played: 3),
            .init(name: "Fiona", wins: 1, played: 3)
        ])
    }

    func testTallyNamesTheLeader() {
        var board = Scoreboard()
        XCTAssertEqual(board.tally(between: "Jamie", and: "Fiona"), "All square at 0–0")
        board.add(record("Fiona", over: "Jamie"))
        board.add(record("Fiona", over: "Jamie"))
        board.add(record("Jamie", over: "Fiona"))
        XCTAssertEqual(board.tally(between: "Jamie", and: "Fiona"), "Fiona leads 2–1")
    }

    func testRecordsStayNewestFirst() {
        let board = Scoreboard(records: [record("A", over: "B", daysAgo: 5), record("B", over: "A", daysAgo: 1)])
        XCTAssertEqual(board.records.first?.winner, "B")
    }
}
