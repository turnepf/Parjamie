import XCTest
@testable import ParjamieEngine

final class HouseRulesTests: XCTestCase {

    private func red(_ index: Int) -> PawnID { PawnID(color: .red, index: index) }
    private func yellow(_ index: Int) -> PawnID { PawnID(color: .yellow, index: index) }

    private func state(
        rules: HouseRules,
        placing placements: [(PawnID, PawnPosition)] = [],
        values: [Int] = [],
        roll: DiceRoll? = nil
    ) -> GameState {
        var state = GameState(setup: .oneColorEach, rules: rules, safetyOffsets: Board.safetyOffsets)
        for (id, position) in placements { state.update(id, to: position) }
        state.turn.phase = values.isEmpty ? .awaitingRoll : .moving
        state.turn.roll = roll ?? DiceRoll(first: values.first ?? 1, second: values.count > 1 ? values[1] : 2)
        state.turn.values = values.enumerated().map { MoveValue(id: $0.offset, amount: $0.element, kind: .die) }
        state.turn.nextValueID = values.count
        return state
    }

    private func entersAny(_ game: GameState) -> Bool {
        Rules.legalMoves(in: game).contains { if case .enter = $0 { true } else { false } }
    }

    func testEntryNumberFollowsTheRule() {
        var six = HouseRules(); six.entry = .six
        XCTAssertFalse(entersAny(state(rules: six, values: [5, 3])))
        XCTAssertTrue(entersAny(state(rules: six, values: [6, 3])))
        XCTAssertTrue(entersAny(state(rules: six, values: [2, 4])), "two dice adding up to 6")

        var oneOrSix = HouseRules(); oneOrSix.entry = .oneOrSix
        XCTAssertTrue(entersAny(state(rules: oneOrSix, values: [1, 3])))
        XCTAssertFalse(entersAny(state(rules: oneOrSix, values: [2, 3])))
    }

    func testBounceBackCarriesTheExtraSquaresBackDownTheHomeColumn() throws {
        var bounce = HouseRules(); bounce.home = .bounce
        let nearHome = try XCTUnwrap(Board.position(atProgress: Board.homeProgress - 2, for: .red))
        let game = state(rules: bounce, placing: [(red(0), nearHome)], values: [5, 1])
        let landing = Rules.destination(for: game[red(0)]!, advancing: 5, in: game)
        XCTAssertEqual(landing, Board.position(atProgress: Board.homeProgress - 3, for: .red))

        let exact = state(rules: .classic, placing: [(red(0), nearHome)], values: [5, 1])
        XCTAssertNil(Rules.destination(for: exact[red(0)]!, advancing: 5, in: exact))
    }

    func testThreeDoublesCanJustEndTheTurnOrBeIgnored() {
        let spot = PawnPosition.ring(Board.entryIndex(for: .red))

        var loseTurn = HouseRules(); loseTurn.threeDoubles = .loseTurn
        var game = state(rules: loseTurn, placing: [(red(0), spot)])
        game.turn.consecutiveDoubles = 2
        Rules.applyRoll(DiceRoll(first: 3, second: 3), to: &game)
        XCTAssertEqual(game[red(0)]?.position, spot)
        XCTAssertEqual(game.turn.seat, .two)

        var nothing = HouseRules(); nothing.threeDoubles = .nothing
        var keepGoing = state(rules: nothing, placing: [(red(0), spot)])
        keepGoing.turn.consecutiveDoubles = 2
        Rules.applyRoll(DiceRoll(first: 3, second: 3), to: &keepGoing)
        XCTAssertEqual(keepGoing.turn.seat, .one)
        XCTAssertEqual(keepGoing[red(0)]?.position, spot)
    }

    func testBonusesCanBeTurnedOff() throws {
        var noBonus = HouseRules(); noBonus.captureBonus = false
        let target = try XCTUnwrap(Board.position(atProgress: 3, for: .red))
        var game = state(rules: noBonus, placing: [(red(0), .ring(Board.entryIndex(for: .red))), (yellow(0), target)], values: [3, 6])
        let outcome = try XCTUnwrap(Rules.apply(.advance(pawn: red(0), spending: 0), to: &game))
        XCTAssertEqual(outcome.captured, yellow(0))
        XCTAssertTrue(outcome.bonusesAwarded.isEmpty)
    }

    func testWithoutBlockadesTwoHelmetsDoNotStopAPassingPawn() throws {
        var open = HouseRules(); open.blockades = false
        let wall = try XCTUnwrap(Board.position(atProgress: 5, for: .red))
        let game = state(rules: open, placing: [(red(0), .ring(Board.entryIndex(for: .red))), (red(1), wall), (red(2), wall)], values: [6, 1])
        XCTAssertNotNil(Rules.destination(for: game[red(0)]!, advancing: 6, in: game))
        XCTAssertFalse(game.isBlockade(atRing: { if case .ring(let i) = wall { i } else { -1 } }()))

        let classic = state(rules: .classic, placing: [(red(0), .ring(Board.entryIndex(for: .red))), (red(1), wall), (red(2), wall)], values: [6, 1])
        XCTAssertNil(Rules.destination(for: classic[red(0)]!, advancing: 6, in: classic))
    }

    func testQuickStartPutsOneHelmetOnEachStartSquare() {
        var quick = HouseRules(); quick.quickStart = true
        let game = GameState(setup: .twoColorsEach, rules: quick)
        for color in PawnSetup.twoColorsEach.allColors {
            XCTAssertEqual(game[PawnID(color: color, index: 0)]?.position, .ring(Board.entryIndex(for: color)))
            XCTAssertTrue(game[PawnID(color: color, index: 1)]?.isInNest ?? false)
        }
    }

    func testMustCaptureLeavesOnlyCapturingMoves() throws {
        var must = HouseRules(); must.mustCapture = true
        let target = try XCTUnwrap(Board.position(atProgress: 3, for: .red))
        let game = state(rules: must, placing: [
            (red(0), .ring(Board.entryIndex(for: .red))),
            (red(1), try XCTUnwrap(Board.position(atProgress: 20, for: .red))),
            (yellow(0), target)
        ], values: [3, 2])
        let moves = Rules.legalMoves(in: game)
        XCTAssertEqual(moves, [.advance(pawn: red(0), spending: 0)])
    }

    func testChangedCountAndOldSavesDecodeToClassic() throws {
        var rules = HouseRules()
        XCTAssertTrue(rules.isClassic)
        rules.entry = .six
        rules.quickStart = true
        XCTAssertEqual(rules.changedCount, 2)
        let decoded = try JSONDecoder().decode(HouseRules.self, from: Data(#"{"entry":"six"}"#.utf8))
        XCTAssertEqual(decoded.entry, .six)
        XCTAssertEqual(decoded.changedCount, 1)
    }

    func testRandomGamesUnderEveryHouseRuleStillFinish() {
        var everything = HouseRules()
        everything.entry = .oneOrSix
        everything.home = .bounce
        everything.threeDoubles = .nothing
        everything.captureBonus = false
        everything.homeBonus = false
        everything.doublesUseBottoms = false
        everything.blockades = false
        everything.quickStart = true
        everything.mustCapture = true
        everything.shuffleSafeSpots = true
        var sixBounce = HouseRules(); sixBounce.entry = .six; sixBounce.home = .bounce; sixBounce.threeDoubles = .loseTurn

        for rules in [everything, sixBounce] {
            for setup in PawnSetup.allCases {
                for seed in UInt64(1)...25 {
                    var game = GameState(setup: setup, rules: rules)
                    var cup = DiceCup(seed: seed)
                    var generator = SeededGenerator(seed: seed &* 17)
                    var steps = 0
                    while game.winner == nil && steps < 100_000 {
                        steps += 1
                        switch game.turn.phase {
                        case .awaitingRoll:
                            Rules.applyRoll(cup.roll(), to: &game)
                        case .moving:
                            let moves = Rules.legalMoves(in: game)
                            XCTAssertFalse(moves.isEmpty)
                            guard let move = moves.randomElement(using: &generator) else { break }
                            XCTAssertNotNil(Rules.apply(move, to: &game))
                        case .finished:
                            break
                        }
                    }
                    XCTAssertNotNil(game.winner, "stalled: \(setup) seed \(seed)")
                }
            }
        }
    }
}
