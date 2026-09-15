import XCTest
@testable import ParjamieEngine

final class GameEventsTests: XCTestCase {

    private func red(_ index: Int) -> PawnID { PawnID(color: .red, index: index) }
    private func yellow(_ index: Int) -> PawnID { PawnID(color: .yellow, index: index) }

    private func moving(_ values: [Int], placing placements: [(PawnID, PawnPosition)] = []) -> GameState {
        var state = GameState(setup: .oneColorEach)
        for (id, position) in placements { state.update(id, to: position) }
        state.turn.phase = .moving
        state.turn.roll = DiceRoll(first: values[0], second: values.count > 1 ? values[1] : 1)
        state.turn.values = values.enumerated().map { MoveValue(id: $0.offset, amount: $0.element, kind: .die) }
        state.turn.nextValueID = values.count
        return state
    }

    func testEnteringIsAMove() {
        let before = moving([5, 3])
        var after = before
        Rules.apply(.enter(pawn: red(0), spending: [0]), to: &after)
        XCTAssertEqual(GameEvents.between(before, after), [.moved(red(0), to: .ring(Board.entryIndex(for: .red)))])
    }

    func testLandingOnAnOpponentIsACapture() throws {
        let target = try XCTUnwrap(Board.position(atProgress: 3, for: .red))
        guard case .ring(let index) = target else { return XCTFail("expected a ring square") }
        XCTAssertFalse(Board.isSafety(ring: index), "pick a square that is not a castle")

        let before = moving([3, 6], placing: [(red(0), .ring(Board.entryIndex(for: .red))), (yellow(0), target)])
        var after = before
        XCTAssertNotNil(Rules.apply(.advance(pawn: red(0), spending: 0), to: &after))

        let events = GameEvents.between(before, after)
        XCTAssertTrue(events.contains(.moved(red(0), to: target)))
        XCTAssertTrue(events.contains(.captured(yellow(0), at: target)))
    }

    func testThreeDoublesIsOverheating() {
        var before = GameState(setup: .oneColorEach)
        let spot = PawnPosition.ring(Board.entryIndex(for: .red))
        before.update(red(0), to: spot)
        before.turn.consecutiveDoubles = 2
        var after = before
        Rules.applyRoll(DiceRoll(first: 4, second: 4), to: &after)
        XCTAssertEqual(GameEvents.between(before, after), [.overheated(red(0), at: spot)])
    }

    func testANewGameProducesNoEvents() {
        var before = GameState(setup: .oneColorEach)
        before.update(red(0), to: .ring(3))
        before.update(red(1), to: .ring(9))
        before.version = 40
        var fresh = GameState(setup: .oneColorEach)
        fresh.version = 41
        XCTAssertNotEqual(fresh.id, before.id)
        XCTAssertEqual(GameEvents.between(before, fresh), [])
    }
}
