import XCTest
@testable import ParjamieEngine

final class BoardTests: XCTestCase {

    func testEachArmHoldsOneEntrySquare() {
        XCTAssertEqual(Board.entryIndex(for: .red), 16)
        XCTAssertEqual(Board.entryIndex(for: .blue), 33)
        XCTAssertEqual(Board.entryIndex(for: .yellow), 50)
        XCTAssertEqual(Board.entryIndex(for: .green), 67)
    }

    func testAPawnLeavesTheRingAtTheTipOfItsOwnArm() {
        for color in PlayerColor.allCases {
            let tip = Board.homeEntryIndex(for: color)
            XCTAssertEqual(Board.progress(ofRing: tip, for: color), Board.homeEntryProgress)
            XCTAssertEqual(BoardGeometry.cell(ring: tip), BoardGeometry.homeColumn(for: color).first.map {
                // The tip sits one square beyond the outermost home square.
                neighbour(of: $0, towardOutside: color)
            })
        }
    }

    private func neighbour(of cell: BoardGeometry.Cell, towardOutside color: PlayerColor) -> BoardGeometry.Cell {
        switch color {
        case .red: BoardGeometry.Cell(cell.column, cell.row + 1)
        case .blue: BoardGeometry.Cell(cell.column - 1, cell.row)
        case .yellow: BoardGeometry.Cell(cell.column, cell.row - 1)
        case .green: BoardGeometry.Cell(cell.column + 1, cell.row)
        }
    }

    func testTheJourneyIsTheSameLengthForEveryColor() {
        for color in PlayerColor.allCases {
            for progress in 0...Board.homeProgress {
                XCTAssertNotNil(Board.position(atProgress: progress, for: color))
            }
            XCTAssertNil(Board.position(atProgress: Board.homeProgress + 1, for: color))
            XCTAssertEqual(Board.position(atProgress: Board.homeProgress, for: color), .home)
            XCTAssertEqual(Board.position(atProgress: 0, for: color), .ring(Board.entryIndex(for: color)))
        }
    }

    func testRingPositionsAndProgressAgree() {
        for color in PlayerColor.allCases {
            for progress in 0...Board.homeEntryProgress {
                guard case .ring(let index)? = Board.position(atProgress: progress, for: color) else {
                    return XCTFail("expected a ring square at \(progress)")
                }
                XCTAssertEqual(Board.progress(ofRing: index, for: color), progress)
            }
        }
    }

    func testEveryEntrySquareIsASafety() {
        for color in PlayerColor.allCases {
            XCTAssertTrue(Board.isSafety(ring: Board.entryIndex(for: color)))
            XCTAssertTrue(Board.isEntry(ring: Board.entryIndex(for: color)))
        }
    }

    func testThereAreTwelveSafetySquares() {
        let safeties = (0..<Board.ringLength).filter { Board.isSafety(ring: $0) }
        XCTAssertEqual(safeties.count, 12)
    }
}

final class BoardGeometryTests: XCTestCase {

    func testTheRingIsSixtyEightDistinctSquares() {
        XCTAssertEqual(BoardGeometry.ring.count, Board.ringLength)
        XCTAssertEqual(Set(BoardGeometry.ring).count, Board.ringLength)
    }

    func testEverySquareStaysOnTheGrid() {
        for cell in BoardGeometry.ring {
            XCTAssertTrue((0..<BoardGeometry.gridSize).contains(cell.column))
            XCTAssertTrue((0..<BoardGeometry.gridSize).contains(cell.row))
        }
    }

    func testConsecutiveSquaresTouch() {
        var diagonalTurns = 0
        for index in 0..<Board.ringLength {
            let here = BoardGeometry.cell(ring: index)
            let next = BoardGeometry.cell(ring: index + 1)
            let across = abs(next.column - here.column)
            let down = abs(next.row - here.row)
            XCTAssertEqual(max(across, down), 1, "squares \(index) and \(index + 1) do not touch")
            if across == 1 && down == 1 { diagonalTurns += 1 }
        }
        // One corner turn where each pair of arms meets.
        XCTAssertEqual(diagonalTurns, 4)
    }

    func testHomeColumnsAreSevenSquaresRunningInward() {
        let center = BoardGeometry.Cell(9, 9)
        for color in PlayerColor.allCases {
            let column = BoardGeometry.homeColumn(for: color)
            XCTAssertEqual(column.count, Board.homeColumnLength)
            XCTAssertEqual(Set(column).count, Board.homeColumnLength)

            // Each step moves one square closer to the middle of the board.
            let distances = column.map { abs($0.column - center.column) + abs($0.row - center.row) }
            XCTAssertEqual(distances, distances.sorted(by: >))
            XCTAssertEqual(distances.last, 2, "the innermost home square should border the middle")
        }
    }

    func testHomeColumnsNeverOverlapTheRing() {
        let ring = Set(BoardGeometry.ring)
        for color in PlayerColor.allCases {
            XCTAssertTrue(ring.isDisjoint(with: Set(BoardGeometry.homeColumn(for: color))))
        }
    }

    func testEachNestSitsInItsOwnCorner() {
        var covered: Set<BoardGeometry.Cell> = []
        for color in PlayerColor.allCases {
            let (origin, size) = BoardGeometry.nest(for: color)
            for column in origin.column..<(origin.column + size) {
                for row in origin.row..<(origin.row + size) {
                    XCTAssertTrue(covered.insert(BoardGeometry.Cell(column, row)).inserted)
                }
            }
        }
        XCTAssertTrue(covered.isDisjoint(with: Set(BoardGeometry.ring)))
    }

    func testANestTouchesItsOwnEntrySquare() {
        for color in PlayerColor.allCases {
            let (origin, size) = BoardGeometry.nest(for: color)
            let entry = BoardGeometry.cell(ring: Board.entryIndex(for: color))
            let touches = (origin.column..<(origin.column + size)).contains { column in
                (origin.row..<(origin.row + size)).contains { row in
                    max(abs(column - entry.column), abs(row - entry.row)) == 1
                }
            }
            XCTAssertTrue(touches, "\(color) enters the board away from its nest")
        }
    }

    // MARK: Shuffled safe spots

    func testShuffledSafeSpotsAreFairAndKeepStartSquaresSafe() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<200 {
            let offsets = Board.shuffledSafetyOffsets(using: &generator)
            XCTAssertEqual(offsets.count, 3)
            XCTAssertTrue(offsets.contains(16), "start squares stay safe")
            XCTAssertFalse(offsets.contains(8), "never on the tip where a color turns for home")
            XCTAssertFalse(offsets.contains(0) || offsets.contains(15), "never touching the center")
            let moved = offsets.subtracting([16]).sorted()
            XCTAssertGreaterThanOrEqual(moved[1] - moved[0], 3)

            let squares = Board.safeSquares(offsets: offsets)
            XCTAssertEqual(squares.count, 12)
            // Every color has the same safe spots relative to its own start.
            let relative = { (color: PlayerColor) in
                Set(squares.map { Board.progress(ofRing: $0, for: color) })
            }
            XCTAssertEqual(relative(.red), relative(.yellow))
            XCTAssertEqual(relative(.red), relative(.blue))
        }
    }
}
