import XCTest
@testable import ParjamieEngine

final class HintsTests: XCTestCase {

    private func state(
        placing placements: [(PawnID, PawnPosition)] = [],
        values: [(Int, MoveValue.Kind)] = []
    ) -> GameState {
        var state = GameState(setup: .oneColorEach)
        for (id, position) in placements { state.update(id, to: position) }
        state.turn.phase = values.isEmpty ? .awaitingRoll : .moving
        if values.count >= 2 { state.turn.roll = DiceRoll(first: values[0].0, second: values[1].0) }
        state.turn.values = values.enumerated().map { MoveValue(id: $0.offset, amount: $0.element.0, kind: $0.element.1) }
        state.turn.nextValueID = values.count
        return state
    }

    private func red(_ index: Int) -> PawnID { PawnID(color: .red, index: index) }
    private var redEntry: PawnPosition { .ring(Board.entryIndex(for: .red)) }

    func testFirstRollExplainsTheFive() throws {
        let hint = try XCTUnwrap(Hints.forTurn(in: state(), selectedValueID: nil))
        XCTAssertTrue(hint.hasPrefix("Tap Strike an arc to roll."))
        XCTAssertTrue(hint.contains("need a 5"))
    }

    func testDoublesSaysRollAgain() throws {
        var game = state(placing: [(red(0), redEntry)])
        game.turn.consecutiveDoubles = 1
        XCTAssertTrue(try XCTUnwrap(Hints.forTurn(in: game, selectedValueID: nil)).contains("another roll"))
    }

    func testAFiveExplainsBringingAPawnOut() throws {
        let hint = try XCTUnwrap(Hints.forTurn(in: state(values: [(5, .die), (3, .die)]), selectedValueID: nil))
        XCTAssertTrue(hint.contains("tap the 5, then a glowing helmet in your bay"))
    }

    func testDiceAddingToFiveAreNamed() throws {
        let hint = try XCTUnwrap(Hints.forTurn(in: state(values: [(2, .die), (3, .die)]), selectedValueID: nil))
        XCTAssertTrue(hint.contains("Your 2 and 3 add up to 5"))
    }

    func testPickingHalfOfAFiveSaysBothDiceAreUsed() throws {
        let game = state(placing: [(red(0), redEntry)], values: [(2, .die), (3, .die)])
        let hint = try XCTUnwrap(Hints.forTurn(in: game, selectedValueID: 0))
        XCTAssertTrue(hint.contains("uses your 2 and 3 together"))
        XCTAssertTrue(hint.contains("Or tap a glowing helmet on the board to move it 2 spaces"))
    }

    func testBlockadeOnTheStartingSquareIsExplained() throws {
        let game = state(placing: [(red(0), redEntry), (red(1), redEntry)], values: [(5, .die), (4, .die)])
        let hint = try XCTUnwrap(Hints.forTurn(in: game, selectedValueID: nil))
        XCTAssertTrue(hint.contains("blocks it"))
    }

    func testTappingANestHelmetWithoutAFiveExplainsTheFive() {
        let game = state(values: [(3, .die), (4, .die)])
        XCTAssertTrue(Hints.whyCantMove(red(0), in: game, selectedValueID: nil).contains("only on a 5"))
    }

    func testTappingTheOtherPlayersHelmetSaysWhoseItIs() {
        let game = state(values: [(3, .die), (4, .die)])
        XCTAssertTrue(Hints.whyCantMove(PawnID(color: .yellow, index: 0), in: game, selectedValueID: nil).contains("other player"))
    }

    func testOvershootingHomeIsExplained() throws {
        let nearHome = try XCTUnwrap(Board.position(atProgress: Board.homeProgress - 2, for: .red))
        let game = state(placing: [(red(0), nearHome)], values: [(6, .die), (4, .die)])
        let reason = Hints.whyCantMove(red(0), in: game, selectedValueID: 0)
        XCTAssertTrue(reason.contains("overshoot home"))
    }

    func testLandingOfAnEntryIsTheStartSquare() {
        let game = state(values: [(5, .die), (2, .die)])
        XCTAssertEqual(Rules.landing(of: .enter(pawn: red(0), spending: [0]), in: game), redEntry)
    }

    func testCaptureBonusIsExplained() throws {
        let game = state(placing: [(red(0), redEntry)], values: [(20, .captureBonus)])
        let hint = try XCTUnwrap(Hints.forTurn(in: game, selectedValueID: nil))
        XCTAssertTrue(hint.contains("move it 20 spaces"))
        XCTAssertTrue(hint.contains("reward for capturing"))
    }
}
