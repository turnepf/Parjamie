import XCTest
@testable import ParjamieEngine

final class RulesTests: XCTestCase {

    /// A game with the given pawns placed and the seat mid-turn holding the given values.
    private func state(
        setup: PawnSetup = .twoColorsEach,
        seat: Seat = .one,
        placing placements: [(PawnID, PawnPosition)] = [],
        values: [Int] = []
    ) -> GameState {
        var state = GameState(setup: setup)
        for (id, position) in placements { state.update(id, to: position) }
        state.turn.seat = seat
        state.turn.phase = .moving
        state.turn.roll = DiceRoll(first: values.first ?? 1, second: values.count > 1 ? values[1] : 2)
        state.turn.values = values.enumerated().map {
            MoveValue(id: $0.offset, amount: $0.element, kind: .die)
        }
        state.turn.nextValueID = values.count
        return state
    }

    private func red(_ index: Int) -> PawnID { PawnID(color: .red, index: index) }

    /// A red pawn's position after travelling the given number of squares.
    private func afterRed(_ steps: Int) -> PawnPosition {
        Board.position(atProgress: steps, for: .red)!
    }

    /// The ring square a red pawn stands on after travelling the given number of squares.
    private func redRing(_ steps: Int) -> Int {
        guard case .ring(let index) = afterRed(steps) else { fatalError("not a ring square") }
        return index
    }
    private func blue(_ index: Int) -> PawnID { PawnID(color: .blue, index: index) }

    // MARK: Entering the board

    func testPawnLeavesNestOnlyOnAFive() {
        let noFive = state(values: [3, 4])
        XCTAssertFalse(Rules.legalMoves(in: noFive).contains { if case .enter = $0 { true } else { false } })

        let withFive = state(values: [5, 4])
        XCTAssertTrue(withFive.pawns.allSatisfy(\.isInNest))
        XCTAssertTrue(Rules.legalMoves(in: withFive).contains(.enter(pawn: red(0), spending: [0])))
    }

    func testBothDiceMayBeCombinedToMakeFive() {
        let combined = state(values: [2, 3])
        XCTAssertTrue(Rules.legalMoves(in: combined).contains(.enter(pawn: red(0), spending: [0, 1])))
    }

    func testEnteringSpendsBothDiceWhenCombined() {
        var game = state(values: [2, 3])
        XCTAssertNotNil(Rules.apply(.enter(pawn: red(0), spending: [0, 1]), to: &game))
        XCTAssertEqual(game[red(0)]?.position, .ring(Board.entryIndex(for: .red)))
        XCTAssertTrue(game.turn.values.isEmpty)
    }

    func testBonusMovesCannotBeSpentOnEntering() {
        var game = state(values: [3, 4])
        game.turn.values.append(MoveValue(id: 99, amount: 5, kind: .captureBonus))
        XCTAssertFalse(Rules.legalMoves(in: game).contains { if case .enter = $0 { true } else { false } })
    }

    // MARK: Blockades

    func testBlockadeStopsAPawnLandingOnIt() {
        let game = state(
            placing: [(red(0), afterRed(20)), (red(1), afterRed(25)), (red(2), afterRed(25))],
            values: [5, 1]
        )
        XCTAssertNil(Rules.destination(for: game[red(0)]!, advancing: 5, in: game))
    }

    func testBlockadeStopsAPawnPassingThroughIt() {
        let game = state(
            placing: [(red(0), afterRed(20)), (red(1), afterRed(25)), (red(2), afterRed(25))],
            values: [6, 1]
        )
        XCTAssertNil(Rules.destination(for: game[red(0)]!, advancing: 6, in: game))
    }

    func testTwoOwnPawnsMayShareASquare() {
        let game = state(placing: [(red(0), afterRed(20)), (red(1), afterRed(23))], values: [3, 1])
        XCTAssertEqual(Rules.destination(for: game[red(0)]!, advancing: 3, in: game), afterRed(23))
    }

    // MARK: Capturing

    func testLandingOnALoneOpponentCapturesItAndPaysTwenty() {
        var game = state(placing: [(red(0), afterRed(20)), (blue(0), afterRed(23))], values: [3, 1])
        let outcome = Rules.apply(.advance(pawn: red(0), spending: 0), to: &game)
        XCTAssertEqual(outcome?.captured, blue(0))
        XCTAssertEqual(game[blue(0)]?.position, .nest)
        XCTAssertEqual(outcome?.bonusesAwarded.first?.amount, 20)
        XCTAssertTrue(game.turn.values.contains { $0.amount == 20 && $0.kind == .captureBonus })
    }

    func testAnOpponentOnASafetySquareCannotBeCaptured() {
        let game = state(placing: [(red(0), afterRed(2)), (blue(0), afterRed(5))], values: [3, 1])
        XCTAssertTrue(Board.isSafety(ring: redRing(5)))
        XCTAssertNil(Rules.destination(for: game[red(0)]!, advancing: 3, in: game))
    }

    func testEnteringPawnBumpsAnOpponentOffTheEntrySquare() {
        var game = state(placing: [(blue(0), afterRed(0))], values: [5, 1])
        XCTAssertTrue(Board.isSafety(ring: Board.entryIndex(for: .red)))
        let outcome = Rules.apply(.enter(pawn: red(0), spending: [0]), to: &game)
        XCTAssertEqual(outcome?.captured, blue(0))
        XCTAssertEqual(game[red(0)]?.position, .ring(Board.entryIndex(for: .red)))
    }

    // MARK: Going home

    func testHomeNeedsAnExactCount() {
        let game = state(placing: [(red(0), .homeColumn(6))], values: [1, 2])
        XCTAssertEqual(Rules.destination(for: game[red(0)]!, advancing: 1, in: game), .home)
        XCTAssertNil(Rules.destination(for: game[red(0)]!, advancing: 2, in: game))
    }

    func testReachingHomePaysTen() {
        var game = state(placing: [(red(0), .homeColumn(6)), (red(1), afterRed(4))], values: [1, 2])
        let outcome = Rules.apply(.advance(pawn: red(0), spending: 0), to: &game)
        XCTAssertEqual(outcome?.reachedHome, true)
        XCTAssertEqual(outcome?.bonusesAwarded.first?.amount, 10)
    }

    func testHomeColumnHoldsOnePawnPerSquare() {
        let game = state(placing: [(red(0), .homeColumn(2)), (red(1), .homeColumn(4))], values: [2, 1])
        XCTAssertNil(Rules.destination(for: game[red(0)]!, advancing: 2, in: game))
    }

    func testGameEndsWhenEveryPawnOfASeatIsHome() {
        var game = state(
            setup: .oneColorEach,
            placing: [
                (red(0), .home), (red(1), .home), (red(2), .home), (red(3), .homeColumn(6))
            ],
            values: [1, 3]
        )
        Rules.apply(.advance(pawn: red(3), spending: 0), to: &game)
        XCTAssertEqual(game.winner, .one)
        XCTAssertEqual(game.turn.phase, .finished)
    }

    // MARK: Doubles

    func testDoublesWithEveryPawnOutGrantsFourMoves() {
        var game = GameState(setup: .oneColorEach)
        for index in 0..<4 { game.update(red(index), to: Board.position(atProgress: index * 3, for: .red)!) }
        game.turn.phase = .awaitingRoll
        Rules.applyRoll(DiceRoll(first: 3, second: 3), to: &game)
        XCTAssertEqual(game.turn.values.map(\.amount).sorted(), [3, 3, 4, 4])
    }

    func testDoublesWithAPawnStillInTheNestGrantsTwoMoves() {
        var game = GameState(setup: .oneColorEach)
        game.update(red(0), to: Board.position(atProgress: 3, for: .red)!)
        game.turn.phase = .awaitingRoll
        Rules.applyRoll(DiceRoll(first: 3, second: 3), to: &game)
        XCTAssertEqual(game.turn.values.map(\.amount).sorted(), [3, 3])
    }

    func testDoublesLetsTheSameSeatRollAgain() {
        var game = GameState(setup: .oneColorEach)
        game.turn.phase = .awaitingRoll
        Rules.applyRoll(DiceRoll(first: 2, second: 2), to: &game)
        XCTAssertEqual(game.turn.phase, .awaitingRoll)
        XCTAssertEqual(game.turn.seat, .one)
    }

    func testThreeDoublesSendsTheFarthestPawnBackToTheNest() {
        var game = GameState(setup: .oneColorEach)
        game.update(red(0), to: Board.position(atProgress: 4, for: .red)!)
        game.update(red(1), to: Board.position(atProgress: 30, for: .red)!)
        game.turn.phase = .awaitingRoll
        game.turn.consecutiveDoubles = 2
        Rules.applyRoll(DiceRoll(first: 6, second: 6), to: &game)
        XCTAssertEqual(game[red(1)]?.position, .nest)
        XCTAssertEqual(game[red(0)]?.position, Board.position(atProgress: 4, for: .red))
        XCTAssertEqual(game.turn.seat, .two)
    }

    // MARK: Turn handling

    func testTurnPassesWhenNoValueCanBeUsed() {
        var game = GameState(setup: .oneColorEach)
        game.turn.phase = .awaitingRoll
        Rules.applyRoll(DiceRoll(first: 2, second: 3), to: &game)
        // Every pawn is in the nest and neither die is a five, but two and three total five.
        XCTAssertEqual(game.turn.phase, .moving)

        var stuck = GameState(setup: .oneColorEach)
        stuck.turn.phase = .awaitingRoll
        Rules.applyRoll(DiceRoll(first: 2, second: 4), to: &stuck)
        XCTAssertEqual(stuck.turn.seat, .two)
        XCTAssertEqual(stuck.turn.phase, .awaitingRoll)
    }

    func testIllegalMovesAreRejected() {
        var game = state(placing: [(red(0), afterRed(20))], values: [3, 1])
        XCTAssertNil(Rules.apply(.advance(pawn: blue(0), spending: 0), to: &game))
        XCTAssertNil(Rules.apply(.advance(pawn: red(0), spending: 42), to: &game))
    }
}

final class SelfPlayTests: XCTestCase {
    /// Plays complete games with random legal moves. Catches rule combinations that
    /// deadlock a turn, which is the failure that would strand Fiona and Jamie mid-game.
    func testRandomGamesAlwaysReachAWinner() {
        for setup in PawnSetup.allCases {
            for seed in UInt64(1)...60 {
                var game = GameState(setup: setup)
                var cup = DiceCup(seed: seed)
                var generator = SeededGenerator(seed: seed &* 31)
                var steps = 0

                while game.winner == nil {
                    steps += 1
                    XCTAssertLessThan(steps, 100_000, "game stalled with setup \(setup) seed \(seed)")
                    guard steps < 100_000 else { break }

                    switch game.turn.phase {
                    case .awaitingRoll:
                        Rules.applyRoll(cup.roll(), to: &game)
                    case .moving:
                        let moves = Rules.legalMoves(in: game)
                        XCTAssertFalse(moves.isEmpty, "moving phase with no legal move")
                        guard let move = moves.randomElement(using: &generator) else { break }
                        XCTAssertNotNil(Rules.apply(move, to: &game))
                    case .finished:
                        break
                    }
                }

                let winner = try! XCTUnwrap(game.winner)
                XCTAssertTrue(game.pawns(for: winner).allSatisfy(\.isHome))
            }
        }
    }

    func testStateSurvivesARoundTripThroughJSON() throws {
        var game = GameState(setup: .twoColorsEach)
        var cup = DiceCup(seed: 7)
        Rules.applyRoll(cup.roll(), to: &game)

        let data = try JSONEncoder().encode(game)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(game, restored)
    }
}
