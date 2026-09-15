import XCTest
@testable import ParjamieEngine

final class ComputerPlayerTests: XCTestCase {

    private func red(_ index: Int) -> PawnID { PawnID(color: .red, index: index) }
    private func yellow(_ index: Int) -> PawnID { PawnID(color: .yellow, index: index) }

    private func moving(seat: Seat = .one, placing placements: [(PawnID, PawnPosition)], values: [Int]) -> GameState {
        var state = GameState(setup: .oneColorEach)
        for (id, position) in placements { state.update(id, to: position) }
        state.turn.seat = seat
        state.turn.phase = .moving
        state.turn.roll = DiceRoll(first: values[0], second: values.count > 1 ? values[1] : 1)
        state.turn.values = values.enumerated().map { MoveValue(id: $0.offset, amount: $0.element, kind: .die) }
        state.turn.nextValueID = values.count
        return state
    }

    func testHardTakesACaptureWhenOneIsThere() throws {
        let target = try XCTUnwrap(Board.position(atProgress: 3, for: .red))
        guard case .ring(let index) = target else { return XCTFail() }
        XCTAssertFalse(Board.isSafety(ring: index))
        let game = moving(placing: [
            (red(0), .ring(Board.entryIndex(for: .red))),
            (red(1), try XCTUnwrap(Board.position(atProgress: 30, for: .red))),
            (yellow(0), target)
        ], values: [3, 6])
        var generator = SeededGenerator(seed: 1)
        let move = ComputerPlayer.chooseMove(in: game, level: .hard, using: &generator)
        XCTAssertEqual(move, .advance(pawn: red(0), spending: 0))
    }

    func testHardBringsAPawnHomeOverAPlainStep() throws {
        let game = moving(placing: [
            (red(0), try XCTUnwrap(Board.position(atProgress: Board.homeProgress - 4, for: .red))),
            (red(1), try XCTUnwrap(Board.position(atProgress: 10, for: .red)))
        ], values: [4, 2])
        var generator = SeededGenerator(seed: 2)
        XCTAssertEqual(ComputerPlayer.chooseMove(in: game, level: .hard, using: &generator), .advance(pawn: red(0), spending: 0))
    }

    func testHardBeatsEasyOverManyGames() {
        var hardWins = 0
        let games = 40
        for seed in UInt64(1)...UInt64(games) {
            var game = GameState(setup: .oneColorEach)
            var cup = DiceCup(seed: seed)
            var generator = SeededGenerator(seed: seed &* 7)
            // Alternate which seat is hard so moving first does not decide it.
            let hardSeat: Seat = seed % 2 == 0 ? .one : .two
            var steps = 0
            while game.winner == nil && steps < 50_000 {
                steps += 1
                switch game.turn.phase {
                case .awaitingRoll:
                    Rules.applyRoll(cup.roll(), to: &game)
                case .moving:
                    let level: ComputerPlayer.Level = game.turn.seat == hardSeat ? .hard : .easy
                    guard let move = ComputerPlayer.chooseMove(in: game, level: level, using: &generator) else {
                        return XCTFail("no move offered in the moving phase")
                    }
                    Rules.apply(move, to: &game)
                case .finished:
                    break
                }
            }
            XCTAssertNotNil(game.winner)
            if game.winner == hardSeat { hardWins += 1 }
        }
        XCTAssertGreaterThan(hardWins, games * 6 / 10, "hard won \(hardWins) of \(games)")
    }
}
