import SwiftUI
import ParjamieEngine

/// Draws the board and the pawns on it.
///
/// The board itself is static geometry, so it goes into a single Canvas that the
/// system can cache. Pawns are real views on top, which is what lets them animate
/// between squares instead of being redrawn.
struct BoardView: View {
    let game: GameState
    let viewingColor: PlayerColor
    let movable: Set<PawnID>
    let selected: PawnID?
    let onTap: (PawnID) -> Void

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let unit = side / CGFloat(BoardGeometry.gridSize)

            ZStack {
                Canvas(rendersAsynchronously: false) { context, _ in
                    draw(in: &context, unit: unit)
                }
                .frame(width: side, height: side)

                ForEach(game.pawns) { pawn in
                    PawnView(
                        color: pawn.color,
                        isMovable: movable.contains(pawn.id),
                        isSelected: selected == pawn.id,
                        counterRotation: -quarterTurns * 90
                    )
                    .frame(width: unit * 1.5, height: unit * 1.5)
                    .position(point(for: pawn, unit: unit))
                    .onTapGesture { onTap(pawn.id) }
                    .zIndex(selected == pawn.id ? 2 : 1)
                }
            }
            .frame(width: side, height: side)
            .rotationEffect(.degrees(Double(quarterTurns) * 90))
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: game.pawns)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var quarterTurns: Double {
        Double(BoardGeometry.rotationQuarterTurns(bringingToBottom: viewingColor))
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, unit: CGFloat) {
        let side = unit * CGFloat(BoardGeometry.gridSize)
        let board = Path(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerRadius: unit * 0.9)
        context.fill(board, with: .linearGradient(
            Gradient(colors: [Palette.felt, Palette.feltEdge]),
            startPoint: .zero,
            endPoint: CGPoint(x: side, y: side)
        ))

        for color in PlayerColor.allCases {
            drawNest(color, in: &context, unit: unit)
            drawHomeColumn(color, in: &context, unit: unit)
        }
        for index in 0..<Board.ringLength {
            drawTrackSquare(index, in: &context, unit: unit)
        }
        drawCenter(in: &context, unit: unit)
    }

    private func rect(_ cell: BoardGeometry.Cell, unit: CGFloat, inset: CGFloat = 0.06) -> CGRect {
        CGRect(
            x: (CGFloat(cell.column) + inset) * unit,
            y: (CGFloat(cell.row) + inset) * unit,
            width: (1 - inset * 2) * unit,
            height: (1 - inset * 2) * unit
        )
    }

    private func drawTrackSquare(_ index: Int, in context: inout GraphicsContext, unit: CGFloat) {
        let cell = BoardGeometry.cell(ring: index)
        let box = rect(cell, unit: unit)
        let path = Path(roundedRect: box, cornerRadius: unit * 0.18)

        let owner = PlayerColor.allCases.first { Board.entryIndex(for: $0) == index }
        if let owner {
            context.fill(path, with: .color(Palette.color(owner).opacity(0.85)))
        } else if Board.isSafety(ring: index) {
            context.fill(path, with: .color(Palette.track))
            let dot = box.insetBy(dx: box.width * 0.3, dy: box.height * 0.3)
            context.fill(Path(ellipseIn: dot), with: .color(Palette.ink.opacity(0.32)))
        } else {
            context.fill(path, with: .color(Palette.track))
        }
        context.stroke(path, with: .color(Palette.trackEdge.opacity(0.8)), lineWidth: unit * 0.03)
    }

    private func drawHomeColumn(_ color: PlayerColor, in context: inout GraphicsContext, unit: CGFloat) {
        for (step, cell) in BoardGeometry.homeColumn(for: color).enumerated() {
            let box = rect(cell, unit: unit)
            let path = Path(roundedRect: box, cornerRadius: unit * 0.18)
            // A light base first, so the outer home squares do not sink into the felt.
            context.fill(path, with: .color(Palette.track))
            // The squares deepen in color as they approach home.
            let depth = 0.30 + 0.6 * Double(step) / Double(Board.homeColumnLength - 1)
            context.fill(path, with: .color(Palette.color(color).opacity(depth)))
            context.stroke(path, with: .color(Palette.color(color).opacity(0.7)), lineWidth: unit * 0.03)
        }
    }

    private func drawNest(_ color: PlayerColor, in context: inout GraphicsContext, unit: CGFloat) {
        let (origin, size) = BoardGeometry.nest(for: color)
        let box = CGRect(
            x: (CGFloat(origin.column) + 0.7) * unit,
            y: (CGFloat(origin.row) + 0.7) * unit,
            width: (CGFloat(size) - 1.4) * unit,
            height: (CGFloat(size) - 1.4) * unit
        )
        let path = Path(roundedRect: box, cornerRadius: unit * 1.1)
        context.fill(path, with: .color(Palette.color(color).opacity(0.22)))
        context.stroke(path, with: .color(Palette.color(color).opacity(0.75)), lineWidth: unit * 0.06)
    }

    private func drawCenter(in context: inout GraphicsContext, unit: CGFloat) {
        let origin = BoardGeometry.homeOrigin
        let size = CGFloat(BoardGeometry.homeSize)
        let box = CGRect(
            x: (CGFloat(origin.column) + 0.15) * unit,
            y: (CGFloat(origin.row) + 0.15) * unit,
            width: (size - 0.3) * unit,
            height: (size - 0.3) * unit
        )
        context.fill(Path(roundedRect: box, cornerRadius: unit * 0.4), with: .color(Palette.track))

        // Four triangles meeting in the middle, one per color.
        let middle = CGPoint(x: box.midX, y: box.midY)
        let corners = [
            (CGPoint(x: box.minX, y: box.maxY), CGPoint(x: box.maxX, y: box.maxY), PlayerColor.red),
            (CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.minX, y: box.maxY), PlayerColor.blue),
            (CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY), PlayerColor.yellow),
            (CGPoint(x: box.maxX, y: box.minY), CGPoint(x: box.maxX, y: box.maxY), PlayerColor.green)
        ]
        for (a, b, color) in corners {
            var wedge = Path()
            wedge.move(to: middle)
            wedge.addLine(to: a)
            wedge.addLine(to: b)
            wedge.closeSubpath()
            context.fill(wedge, with: .color(Palette.color(color).opacity(0.8)))
        }
        context.stroke(
            Path(roundedRect: box, cornerRadius: unit * 0.4),
            with: .color(Palette.ink.opacity(0.35)),
            lineWidth: unit * 0.05
        )
    }

    // MARK: Pawn placement

    private func center(of cell: BoardGeometry.Cell, unit: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(cell.column) + 0.5) * unit, y: (CGFloat(cell.row) + 0.5) * unit)
    }

    private func point(for pawn: Pawn, unit: CGFloat) -> CGPoint {
        switch pawn.position {
        case .nest:
            let (origin, size) = BoardGeometry.nest(for: pawn.color)
            let middle = CGPoint(
                x: (CGFloat(origin.column) + CGFloat(size) / 2) * unit,
                y: (CGFloat(origin.row) + CGFloat(size) / 2) * unit
            )
            let across: CGFloat = pawn.id.index % 2 == 0 ? -1.15 : 1.15
            let down: CGFloat = pawn.id.index < 2 ? -1.15 : 1.15
            return CGPoint(x: middle.x + across * unit, y: middle.y + down * unit)

        case .ring(let index):
            let base = center(of: BoardGeometry.cell(ring: index), unit: unit)
            // Two pawns stacked on one square sit side by side so both stay visible.
            let sharing = game.pawns(onRing: index)
            guard sharing.count > 1, let slot = sharing.firstIndex(where: { $0.id == pawn.id }) else { return base }
            return CGPoint(x: base.x + (slot == 0 ? -0.2 : 0.2) * unit, y: base.y)

        case .homeColumn(let step):
            return center(of: BoardGeometry.cell(homeColumn: step, for: pawn.color), unit: unit)

        case .home:
            let origin = BoardGeometry.homeOrigin
            let middle = CGPoint(
                x: (CGFloat(origin.column) + CGFloat(BoardGeometry.homeSize) / 2) * unit,
                y: (CGFloat(origin.row) + CGFloat(BoardGeometry.homeSize) / 2) * unit
            )
            let across: CGFloat = pawn.id.index % 2 == 0 ? -0.3 : 0.3
            let down: CGFloat = pawn.id.index < 2 ? -0.3 : 0.3
            return CGPoint(x: middle.x + across * unit, y: middle.y + down * unit)
        }
    }
}

/// A single pawn. Round, so the board rotation never turns it upside down.
struct PawnView: View {
    let color: PlayerColor
    let isMovable: Bool
    let isSelected: Bool
    let counterRotation: Double

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(.radialGradient(
                        Gradient(colors: [Palette.color(color).opacity(0.95), Palette.color(color)]),
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.7
                    ))
                    .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: size * 0.07))
                    .shadow(color: .black.opacity(0.3), radius: size * 0.08, y: size * 0.06)

                Circle()
                    .fill(.white.opacity(0.35))
                    .frame(width: size * 0.22, height: size * 0.22)
                    .offset(x: -size * 0.15, y: -size * 0.18)

                if isMovable {
                    Circle()
                        .stroke(.white, lineWidth: size * 0.09)
                        .opacity(isSelected ? 1 : 0.75)
                        .scaleEffect(isSelected ? 1.18 : 1.08)
                }
            }
            .frame(width: size * 0.62, height: size * 0.62)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .rotationEffect(.degrees(counterRotation))
        }
    }
}
