import Foundation

/// Maps the abstract board onto a square grid, so the interface can draw it without
/// knowing anything about the rules.
///
/// The grid is 19 by 19. The middle three columns and middle three rows form the
/// cross. The four corners hold the nests, and the middle three by three is home.
public enum BoardGeometry {
    public static let gridSize = 19

    public struct Cell: Hashable, Sendable {
        public let column: Int
        public let row: Int

        public init(_ column: Int, _ row: Int) {
            self.column = column
            self.row = row
        }
    }

    /// Ring squares in travel order, starting at the first square of the south arm.
    public static let ring: [Cell] = {
        var cells: [Cell] = []
        // South arm: down the right column, across the tip, up the left column.
        cells += (11...18).map { Cell(10, $0) }
        cells.append(Cell(9, 18))
        cells += (11...18).reversed().map { Cell(8, $0) }
        // West arm.
        cells += (0...7).reversed().map { Cell($0, 10) }
        cells.append(Cell(0, 9))
        cells += (0...7).map { Cell($0, 8) }
        // North arm.
        cells += (0...7).reversed().map { Cell(8, $0) }
        cells.append(Cell(9, 0))
        cells += (0...7).map { Cell(10, $0) }
        // East arm.
        cells += (11...18).map { Cell($0, 8) }
        cells.append(Cell(18, 9))
        cells += (11...18).reversed().map { Cell($0, 10) }
        return cells
    }()

    public static func cell(ring index: Int) -> Cell {
        ring[((index % Board.ringLength) + Board.ringLength) % Board.ringLength]
    }

    /// Home column squares, outermost first, running inward to the center.
    public static func homeColumn(for color: PlayerColor) -> [Cell] {
        switch color {
        case .red: (11...17).reversed().map { Cell(9, $0) }
        case .blue: (1...7).map { Cell($0, 9) }
        case .yellow: (1...7).map { Cell(9, $0) }
        case .green: (11...17).reversed().map { Cell($0, 9) }
        }
    }

    public static func cell(homeColumn step: Int, for color: PlayerColor) -> Cell {
        homeColumn(for: color)[step]
    }

    /// The corner block a color's pawns wait in, given as its top left cell and size.
    public static func nest(for color: PlayerColor) -> (origin: Cell, size: Int) {
        switch color {
        case .red: (Cell(0, 11), 8)
        case .blue: (Cell(0, 0), 8)
        case .yellow: (Cell(11, 0), 8)
        case .green: (Cell(11, 11), 8)
        }
    }

    /// The three by three block at the middle of the board.
    public static let homeOrigin = Cell(8, 8)
    public static let homeSize = 3

    /// Quarter turns to rotate the board so the given color's arm sits at the bottom.
    public static func rotationQuarterTurns(bringingToBottom color: PlayerColor) -> Int {
        // Red already sits south. Each following arm is one quarter turn clockwise.
        (4 - color.armIndex) % 4
    }
}
