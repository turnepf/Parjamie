import SwiftUI
import ParjamieEngine

/// Draws the board, the pawns on it, and the sparks that fly when something happens.
///
/// The board itself is static geometry, so it goes into a single Canvas that the
/// system can cache. Pawns are real views on top, which is what lets them animate
/// between squares instead of being redrawn.
struct BoardView: View {
    let game: GameState
    let viewingColor: PlayerColor
    let movable: Set<PawnID>
    let selected: PawnID?
    var effects: [BoardEffect] = []
    var guides = BoardGuides()
    /// Stencilled on each color's bay, such as "YOU" or the other player's name.
    var bayLabels: [PlayerColor: String] = [:]
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
                .accessibilityHidden(true)

                guideLayer(unit: unit)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                ForEach(PlayerColor.allCases.filter { bayLabels[$0] != nil }, id: \.self) { color in
                    Text(bayLabels[color] ?? "")
                        .font(.system(size: unit * 0.62, weight: .heavy, design: .monospaced))
                        .tracking(unit * 0.08)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Palette.color(color).opacity(0.9))
                        .frame(width: unit * 3.4)
                        .rotationEffect(.degrees(-quarterTurns * 90))
                        .position(point(for: nil, at: .nest, color: color, unit: unit))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                ForEach(game.pawns) { pawn in
                    PawnView(
                        color: pawn.color,
                        isSafe: isOnSafeSquare(pawn),
                        isMovable: movable.contains(pawn.id),
                        isSelected: selected == pawn.id,
                        counterRotation: -quarterTurns * 90
                    )
                    .frame(width: unit * 1.5, height: unit * 1.5)
                    .position(point(for: pawn.id, at: pawn.position, unit: unit))
                    .onTapGesture { onTap(pawn.id) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(spokenDescription(of: pawn))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(movable.contains(pawn.id) ? "Can move. Double tap to move it." : "")
                    .accessibilityAction { onTap(pawn.id) }
                    .zIndex(selected == pawn.id ? 2 : 1)
                }

                blockadeWelds(unit: unit)
                    .zIndex(3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                ForEach(guides.landings, id: \.self) { landing in
                    LandingMarker(color: landing.pawn.color)
                        .frame(width: unit * 1.5, height: unit * 1.5)
                        .rotationEffect(.degrees(-quarterTurns * 90))
                        .position(point(for: nil, at: landing.position, color: landing.pawn.color, unit: unit))
                        .zIndex(2.5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                ForEach(effects) { effect in
                    EffectView(effect: effect, unit: unit)
                        .rotationEffect(.degrees(-quarterTurns * 90))
                        .position(point(for: nil, at: effect.position, color: effect.color, unit: unit))
                        .zIndex(4)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
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

    // A welding shop take on the cross-and-circle board: diamond plate for the track,
    // squares cut apart at the seams, a weld bead run around the whole cross, tack welds
    // marking the castles, painted floor bays for the nests, and a bolted flange at home.

    private func draw(in context: inout GraphicsContext, unit: CGFloat) {
        let side = unit * CGFloat(BoardGeometry.gridSize)
        drawFloor(side: side, in: &context, unit: unit)
        for color in PlayerColor.allCases {
            drawNest(color, in: &context, unit: unit)
        }
        drawPlate(in: &context, unit: unit)
        for color in PlayerColor.allCases {
            drawHomeColumn(color, in: &context, unit: unit)
        }
        for index in 0..<Board.ringLength {
            drawTrackSquare(index, in: &context, unit: unit)
        }
        drawOutlineBead(in: &context, unit: unit)
        drawCenter(in: &context, unit: unit)
    }

    private func rect(_ cell: BoardGeometry.Cell, unit: CGFloat, inset: CGFloat = 0) -> CGRect {
        CGRect(
            x: (CGFloat(cell.column) + inset) * unit,
            y: (CGFloat(cell.row) + inset) * unit,
            width: (1 - inset * 2) * unit,
            height: (1 - inset * 2) * unit
        )
    }

    private func drawFloor(side: CGFloat, in context: inout GraphicsContext, unit: CGFloat) {
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        let board = Path(roundedRect: bounds, cornerRadius: unit * 0.5)
        context.fill(board, with: .linearGradient(
            Gradient(colors: [Palette.floor, Palette.floorEdge]),
            startPoint: .zero, endPoint: CGPoint(x: side, y: side)
        ))

        // Brushed steel: faint horizontal grain.
        var grain = Path()
        var y: CGFloat = unit * 0.1
        var i = 0
        while y < side {
            grain.move(to: CGPoint(x: unit * CGFloat(i % 3) * 0.4, y: y))
            grain.addLine(to: CGPoint(x: side - unit * CGFloat((i * 7) % 4) * 0.3, y: y))
            y += unit * (0.14 + CGFloat((i * 5) % 3) * 0.05)
            i += 1
        }
        context.stroke(grain, with: .color(.white.opacity(0.035)), lineWidth: unit * 0.03)

        // Bolted frame.
        context.stroke(Path(roundedRect: bounds.insetBy(dx: unit * 0.18, dy: unit * 0.18), cornerRadius: unit * 0.4),
                       with: .color(.white.opacity(0.12)), lineWidth: unit * 0.05)
        let inset = unit * 0.45
        for p in [CGPoint(x: inset, y: inset), CGPoint(x: side - inset, y: inset),
                  CGPoint(x: inset, y: side - inset), CGPoint(x: side - inset, y: side - inset)] {
            drawBolt(at: p, radius: unit * 0.18, in: &context)
        }
    }

    private func drawBolt(at p: CGPoint, radius r: CGFloat, in context: inout GraphicsContext) {
        var hex = Path()
        for k in 0..<6 {
            let a = Double(k) * .pi / 3 + .pi / 6
            let q = CGPoint(x: p.x + cos(a) * r, y: p.y + sin(a) * r)
            if k == 0 { hex.move(to: q) } else { hex.addLine(to: q) }
        }
        hex.closeSubpath()
        context.fill(hex, with: .linearGradient(Gradient(colors: [Color(white: 0.78), Color(white: 0.38)]),
                                                startPoint: CGPoint(x: p.x - r, y: p.y - r), endPoint: CGPoint(x: p.x + r, y: p.y + r)))
        context.stroke(hex, with: .color(.black.opacity(0.4)), lineWidth: r * 0.15)
    }

    /// A painted floor bay where a color's helmets wait: a stencilled outline with
    /// hazard brackets at the corners.
    private func drawNest(_ color: PlayerColor, in context: inout GraphicsContext, unit: CGFloat) {
        let (origin, size) = BoardGeometry.nest(for: color)
        let box = CGRect(
            x: (CGFloat(origin.column) + 1.0) * unit,
            y: (CGFloat(origin.row) + 1.0) * unit,
            width: (CGFloat(size) - 2.0) * unit,
            height: (CGFloat(size) - 2.0) * unit
        )
        let tint = Palette.color(color)
        context.fill(Path(box), with: .color(tint.opacity(0.07)))
        context.stroke(Path(box), with: .color(tint.opacity(0.75)),
                       style: StrokeStyle(lineWidth: unit * 0.1, dash: [unit * 0.5, unit * 0.3]))

        let arm = unit * 1.1
        var brackets = Path()
        for (corner, dx, dy) in [(CGPoint(x: box.minX, y: box.minY), 1.0, 1.0), (CGPoint(x: box.maxX, y: box.minY), -1.0, 1.0),
                                 (CGPoint(x: box.minX, y: box.maxY), 1.0, -1.0), (CGPoint(x: box.maxX, y: box.maxY), -1.0, -1.0)] {
            brackets.move(to: CGPoint(x: corner.x + arm * dx, y: corner.y))
            brackets.addLine(to: corner)
            brackets.addLine(to: CGPoint(x: corner.x, y: corner.y + arm * dy))
        }
        context.stroke(brackets, with: .color(tint), style: StrokeStyle(lineWidth: unit * 0.22, lineCap: .square, lineJoin: .miter))
    }

    private var crossPath: (CGFloat) -> Path {
        { unit in
            let grid = CGFloat(BoardGeometry.gridSize)
            var cross = Path()
            let tips: [CGPoint] = [
                CGPoint(x: 8, y: 0), CGPoint(x: 11, y: 0), CGPoint(x: 11, y: 8), CGPoint(x: grid, y: 8),
                CGPoint(x: grid, y: 11), CGPoint(x: 11, y: 11), CGPoint(x: 11, y: grid), CGPoint(x: 8, y: grid),
                CGPoint(x: 8, y: 11), CGPoint(x: 0, y: 11), CGPoint(x: 0, y: 8), CGPoint(x: 8, y: 8)
            ].map { CGPoint(x: $0.x * unit, y: $0.y * unit) }
            cross.addLines(tips)
            cross.closeSubpath()
            return cross
        }
    }

    /// The steel cross with a raised diamond-plate tread.
    private func drawPlate(in context: inout GraphicsContext, unit: CGFloat) {
        let cross = crossPath(unit)
        let side = unit * CGFloat(BoardGeometry.gridSize)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.6), radius: unit * 0.3, y: unit * 0.12))
            layer.fill(cross, with: .linearGradient(
                Gradient(colors: [Palette.plate, Palette.plateShade]),
                startPoint: .zero, endPoint: CGPoint(x: side, y: side)
            ))
        }

        // Two raised lugs per square, alternating direction like real tread plate.
        var light = Path()
        var dark = Path()
        let cells = BoardGeometry.ring + (0..<3).flatMap { c in (0..<3).map { BoardGeometry.Cell(8 + c, 8 + $0) } }
            + PlayerColor.allCases.flatMap(BoardGeometry.homeColumn)
        for cell in cells {
            let box = rect(cell, unit: unit)
            for (k, center) in [CGPoint(x: box.minX + box.width * 0.3, y: box.minY + box.height * 0.3),
                                CGPoint(x: box.minX + box.width * 0.7, y: box.minY + box.height * 0.7)].enumerated() {
                let flip = ((cell.column + cell.row + k) % 2 == 0) ? 1.0 : -1.0
                let along = CGVector(dx: unit * 0.16, dy: unit * 0.16 * flip)
                let across = CGVector(dx: unit * 0.045, dy: -unit * 0.045 * flip)
                var lug = Path()
                lug.move(to: CGPoint(x: center.x - along.dx, y: center.y - along.dy))
                lug.addLine(to: CGPoint(x: center.x + across.dx, y: center.y + across.dy))
                lug.addLine(to: CGPoint(x: center.x + along.dx, y: center.y + along.dy))
                lug.addLine(to: CGPoint(x: center.x - across.dx, y: center.y - across.dy))
                lug.closeSubpath()
                light.addPath(lug)
                dark.addPath(lug.offsetBy(dx: unit * 0.03, dy: unit * 0.03))
            }
        }
        context.fill(dark, with: .color(.black.opacity(0.22)))
        context.fill(light, with: .color(.white.opacity(0.38)))
    }

    private func drawTrackSquare(_ index: Int, in context: inout GraphicsContext, unit: CGFloat) {
        let box = rect(BoardGeometry.cell(ring: index), unit: unit)

        if let owner = PlayerColor.allCases.first(where: { Board.entryIndex(for: $0) == index }) {
            // Painted start square, framed in the safe-square violet because it is one.
            context.fill(Path(box.insetBy(dx: unit * 0.05, dy: unit * 0.05)), with: .color(Palette.color(owner).opacity(0.9)))
            context.stroke(Path(box.insetBy(dx: unit * 0.1, dy: unit * 0.1)), with: .color(Palette.safe), lineWidth: unit * 0.12)
            Self.drawTackWeld(in: box, in: &context, unit: unit)
        } else if game.isSafe(ring: index) {
            context.fill(Path(box.insetBy(dx: unit * 0.05, dy: unit * 0.05)), with: .linearGradient(
                Gradient(colors: [Palette.safe.opacity(0.95), Palette.safe.opacity(0.7)]),
                startPoint: CGPoint(x: box.minX, y: box.minY), endPoint: CGPoint(x: box.maxX, y: box.maxY)
            ))
            Self.drawTackWeld(in: box, in: &context, unit: unit)
        }
        context.stroke(Path(box), with: .color(Palette.seam.opacity(0.65)), lineWidth: unit * 0.035)
    }

    /// A cross of tack welds with a heat-tinted halo, marking a castle.
    static func drawTackWeld(in box: CGRect, in context: inout GraphicsContext, unit: CGFloat) {
        let c = CGPoint(x: box.midX, y: box.midY)
        context.fill(Path(ellipseIn: box.insetBy(dx: unit * 0.1, dy: unit * 0.1)), with: .radialGradient(
            Gradient(colors: [Palette.heatTint.opacity(0.0), Palette.heatTint.opacity(0.45), Color(red: 0.35, green: 0.4, blue: 0.7).opacity(0.25), .clear]),
            center: c, startRadius: 0, endRadius: unit * 0.45
        ))
        let reach = unit * 0.27
        for (dx, dy) in [(1.0, 1.0), (1.0, -1.0)] {
            let steps = 5
            for s in 0..<steps {
                let t = CGFloat(s) / CGFloat(steps - 1) * 2 - 1
                let p = CGPoint(x: c.x + reach * t * dx, y: c.y + reach * t * dy)
                Self.drawBeadDot(at: p, radius: unit * 0.075, in: &context)
            }
        }
    }

    static func drawBeadDot(at p: CGPoint, radius r: CGFloat, in context: inout GraphicsContext) {
        let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        context.fill(dot, with: .radialGradient(
            Gradient(colors: [Color(white: 0.93), Palette.bead, Palette.beadEdge]),
            center: CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.35), startRadius: 0, endRadius: r * 1.3
        ))
    }

    /// A continuous weld bead run all the way around the cross.
    private func drawOutlineBead(in context: inout GraphicsContext, unit: CGFloat) {
        let cross = crossPath(unit)
        context.stroke(cross, with: .color(Palette.heatTint.opacity(0.35)), lineWidth: unit * 0.4)
        context.stroke(cross, with: .color(Color(red: 0.35, green: 0.42, blue: 0.7).opacity(0.18)), lineWidth: unit * 0.62)

        let grid = CGFloat(BoardGeometry.gridSize)
        let corners: [CGPoint] = [
            CGPoint(x: 8, y: 0), CGPoint(x: 11, y: 0), CGPoint(x: 11, y: 8), CGPoint(x: grid, y: 8),
            CGPoint(x: grid, y: 11), CGPoint(x: 11, y: 11), CGPoint(x: 11, y: grid), CGPoint(x: 8, y: grid),
            CGPoint(x: 8, y: 11), CGPoint(x: 0, y: 11), CGPoint(x: 0, y: 8), CGPoint(x: 8, y: 8)
        ].map { CGPoint(x: $0.x * unit, y: $0.y * unit) }
        let spacing = unit * 0.13
        for (i, a) in corners.enumerated() {
            let b = corners[(i + 1) % corners.count]
            let length = hypot(b.x - a.x, b.y - a.y)
            let count = Int(length / spacing)
            for s in 0..<count {
                let t = CGFloat(s) / CGFloat(count)
                Self.drawBeadDot(at: CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t), radius: unit * 0.1, in: &context)
            }
        }
    }

    private func drawHomeColumn(_ color: PlayerColor, in context: inout GraphicsContext, unit: CGFloat) {
        let tint = Palette.color(color)
        let cells = BoardGeometry.homeColumn(for: color)
        for (step, cell) in cells.enumerated() {
            let box = rect(cell, unit: unit)
            context.fill(Path(box), with: .color(tint.opacity(0.55 + 0.35 * Double(step) / Double(cells.count - 1))))

            // A stencilled chevron pointing the way home.
            let inward = BoardGeometry.homeOrigin
            let toward = CGVector(
                dx: CGFloat((inward.column + 1) - cell.column).clamped(),
                dy: CGFloat((inward.row + 1) - cell.row).clamped()
            )
            let c = CGPoint(x: box.midX, y: box.midY)
            let r = unit * 0.2
            var chevron = Path()
            chevron.move(to: CGPoint(x: c.x - toward.dx * r * 0.5 - toward.dy * r, y: c.y - toward.dy * r * 0.5 - toward.dx * r))
            chevron.addLine(to: CGPoint(x: c.x + toward.dx * r * 0.6, y: c.y + toward.dy * r * 0.6))
            chevron.addLine(to: CGPoint(x: c.x - toward.dx * r * 0.5 + toward.dy * r, y: c.y - toward.dy * r * 0.5 + toward.dx * r))
            context.stroke(chevron, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: unit * 0.09, lineCap: .round, lineJoin: .round))
        }
    }

    /// Home: a bolted flange with a torch flame pointing down each color's column.
    private func drawCenter(in context: inout GraphicsContext, unit: CGFloat) {
        let origin = BoardGeometry.homeOrigin
        let size = CGFloat(BoardGeometry.homeSize)
        let box = CGRect(x: CGFloat(origin.column) * unit, y: CGFloat(origin.row) * unit, width: size * unit, height: size * unit)
        let middle = CGPoint(x: box.midX, y: box.midY)

        let flange = CGRect(x: middle.x - unit * 1.38, y: middle.y - unit * 1.38, width: unit * 2.76, height: unit * 2.76)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.45), radius: unit * 0.12, y: unit * 0.06))
            layer.fill(Path(ellipseIn: flange), with: .linearGradient(
                Gradient(colors: [Color(white: 0.58), Color(white: 0.30)]),
                startPoint: CGPoint(x: flange.minX, y: flange.minY), endPoint: CGPoint(x: flange.maxX, y: flange.maxY)
            ))
        }
        context.stroke(Path(ellipseIn: flange.insetBy(dx: unit * 0.06, dy: unit * 0.06)), with: .color(.white.opacity(0.25)), lineWidth: unit * 0.04)
        for k in 0..<8 {
            let a = Double(k) / 8 * .pi * 2 + .pi / 8
            drawBolt(at: CGPoint(x: middle.x + cos(a) * unit * 1.13, y: middle.y + sin(a) * unit * 1.13), radius: unit * 0.13, in: &context)
        }

        let flames: [(CGVector, PlayerColor)] = [
            (CGVector(dx: 0, dy: 1), .red), (CGVector(dx: -1, dy: 0), .blue),
            (CGVector(dx: 0, dy: -1), .yellow), (CGVector(dx: 1, dy: 0), .green)
        ]
        for (direction, color) in flames {
            let length = unit * 0.95
            let width = unit * 0.32
            let tip = CGPoint(x: middle.x + direction.dx * length, y: middle.y + direction.dy * length)
            let across = CGVector(dx: -direction.dy * width, dy: direction.dx * width)
            let belly = CGPoint(x: middle.x + direction.dx * length * 0.32, y: middle.y + direction.dy * length * 0.32)
            var flame = Path()
            flame.move(to: middle)
            flame.addCurve(to: tip,
                           control1: CGPoint(x: belly.x + across.dx * 1.6, y: belly.y + across.dy * 1.6),
                           control2: CGPoint(x: tip.x - direction.dx * length * 0.3 + across.dx * 0.3, y: tip.y - direction.dy * length * 0.3 + across.dy * 0.3))
            flame.addCurve(to: middle,
                           control1: CGPoint(x: tip.x - direction.dx * length * 0.3 - across.dx * 0.3, y: tip.y - direction.dy * length * 0.3 - across.dy * 0.3),
                           control2: CGPoint(x: belly.x - across.dx * 1.6, y: belly.y - across.dy * 1.6))
            context.fill(flame, with: .linearGradient(
                Gradient(colors: [.white, Palette.color(color), Palette.color(color).opacity(0.85)]),
                startPoint: middle, endPoint: tip
            ))
        }

        // The torch nozzle at the very center.
        let nozzle = CGRect(x: middle.x - unit * 0.26, y: middle.y - unit * 0.26, width: unit * 0.52, height: unit * 0.52)
        context.fill(Path(ellipseIn: nozzle), with: .radialGradient(
            Gradient(colors: [Color(red: 0.95, green: 0.72, blue: 0.48), Color(red: 0.55, green: 0.32, blue: 0.18)]),
            center: CGPoint(x: nozzle.midX - unit * 0.08, y: nozzle.midY - unit * 0.08), startRadius: 0, endRadius: unit * 0.34
        ))
        context.fill(Path(ellipseIn: nozzle.insetBy(dx: unit * 0.14, dy: unit * 0.14)), with: .color(Palette.ink))
    }

    // MARK: Guides

    /// Learning aids drawn under the pawns: which way to travel, and a pulsing start
    /// square when a helmet can come out.
    private func guideLayer(unit: CGFloat) -> some View {
        ZStack {
            if guides.showDirection {
                Canvas { context, _ in
                    var arrows = Path()
                    for index in 0..<Board.ringLength
                    where !game.isSafe(ring: index) {
                        let here = BoardGeometry.cell(ring: index)
                        let next = BoardGeometry.cell(ring: index + 1)
                        let dx = CGFloat(next.column - here.column), dy = CGFloat(next.row - here.row)
                        guard abs(dx) + abs(dy) == 1 else { continue }
                        let c = center(of: here, unit: unit)
                        let r = unit * 0.2
                        arrows.move(to: CGPoint(x: c.x - dx * r * 0.5 - dy * r, y: c.y - dy * r * 0.5 - dx * r))
                        arrows.addLine(to: CGPoint(x: c.x + dx * r * 0.6, y: c.y + dy * r * 0.6))
                        arrows.addLine(to: CGPoint(x: c.x - dx * r * 0.5 + dy * r, y: c.y - dy * r * 0.5 + dx * r))
                    }
                    context.stroke(arrows, with: .color(.white.opacity(0.8)),
                                   style: StrokeStyle(lineWidth: unit * 0.17, lineCap: .round, lineJoin: .round))
                    context.stroke(arrows, with: .color(Palette.ink.opacity(0.75)),
                                   style: StrokeStyle(lineWidth: unit * 0.09, lineCap: .round, lineJoin: .round))
                }
            }
            if !guides.startSquares.isEmpty {
                TimelineView(.animation) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2
                    Canvas { context, _ in
                        for color in guides.startSquares {
                            let c = center(of: BoardGeometry.cell(ring: Board.entryIndex(for: color)), unit: unit)
                            let r = unit * (0.55 + 0.35 * phase)
                            context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                                           with: .color(Palette.arc.opacity(1 - phase)), lineWidth: unit * 0.14)
                        }
                    }
                }
            }
        }
    }

    // MARK: Blockades

    /// Two pawns sharing a square are shown tack-welded together: nobody gets past.
    private func blockadeWelds(unit: CGFloat) -> some View {
        Canvas { context, _ in
            for index in 0..<Board.ringLength where game.isBlockade(atRing: index) {
                let cell = BoardGeometry.cell(ring: index)
                let c = CGPoint(x: (CGFloat(cell.column) + 0.5) * unit, y: (CGFloat(cell.row) + 0.5) * unit)
                context.fill(Path(ellipseIn: CGRect(x: c.x - unit * 0.22, y: c.y - unit * 0.5, width: unit * 0.44, height: unit * 1.0)),
                             with: .radialGradient(Gradient(colors: [Palette.arc.opacity(0.55), .clear]), center: c, startRadius: 0, endRadius: unit * 0.5))
                for s in 0..<6 {
                    let y = c.y - unit * 0.34 + CGFloat(s) * unit * 0.135
                    Self.drawBeadDot(at: CGPoint(x: c.x, y: y), radius: unit * 0.085, in: &context)
                }
            }
        }
    }

    // MARK: Placement

    /// What VoiceOver reads for a pawn, such as "Red helmet, 12 squares along, on a safe square".
    private func spokenDescription(of pawn: Pawn) -> String {
        let name = "\(Palette.name(pawn.color)) helmet"
        switch pawn.position {
        case .nest:
            return "\(name), waiting in its bay"
        case .ring:
            let along = pawn.progress ?? 0
            let place = along == 0 ? "on its start square" : "\(along) \(along == 1 ? "square" : "squares") along"
            return "\(name), \(place)\(isOnSafeSquare(pawn) ? ", on a safe square" : "")"
        case .homeColumn(let step):
            let left = Board.homeColumnLength - step
            return "\(name), in its home row, \(left) \(left == 1 ? "square" : "squares") from home"
        case .home:
            return "\(name), home"
        }
    }

    private func isOnSafeSquare(_ pawn: Pawn) -> Bool {
        if case .ring(let index) = pawn.position { return game.isSafe(ring: index) }
        return false
    }

    private func center(of cell: BoardGeometry.Cell, unit: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(cell.column) + 0.5) * unit, y: (CGFloat(cell.row) + 0.5) * unit)
    }

    /// Where a pawn stands, or where an effect for that spot should appear.
    private func point(for pawnID: PawnID?, at position: PawnPosition, color: PlayerColor? = nil, unit: CGFloat) -> CGPoint {
        switch position {
        case .nest:
            let nestColor = pawnID?.color ?? color ?? .red
            let (origin, size) = BoardGeometry.nest(for: nestColor)
            let middle = CGPoint(
                x: (CGFloat(origin.column) + CGFloat(size) / 2) * unit,
                y: (CGFloat(origin.row) + CGFloat(size) / 2) * unit
            )
            guard let pawnID else { return middle }
            let across: CGFloat = pawnID.index % 2 == 0 ? -1.15 : 1.15
            let down: CGFloat = pawnID.index < 2 ? -1.15 : 1.15
            return CGPoint(x: middle.x + across * unit, y: middle.y + down * unit)

        case .ring(let index):
            let base = center(of: BoardGeometry.cell(ring: index), unit: unit)
            // Two pawns stacked on one square sit side by side, welded at the middle.
            let sharing = game.pawns(onRing: index)
            guard let pawnID, sharing.count > 1, let slot = sharing.firstIndex(where: { $0.id == pawnID }) else { return base }
            return CGPoint(x: base.x + (slot == 0 ? -0.3 : 0.3) * unit, y: base.y)

        case .homeColumn(let step):
            return center(of: BoardGeometry.cell(homeColumn: step, for: pawnID?.color ?? color ?? .red), unit: unit)

        case .home:
            let origin = BoardGeometry.homeOrigin
            let middle = CGPoint(
                x: (CGFloat(origin.column) + CGFloat(BoardGeometry.homeSize) / 2) * unit,
                y: (CGFloat(origin.row) + CGFloat(BoardGeometry.homeSize) / 2) * unit
            )
            guard let pawnID else { return middle }
            let across: CGFloat = pawnID.index % 2 == 0 ? -0.3 : 0.3
            let down: CGFloat = pawnID.index < 2 ? -0.3 : 0.3
            return CGPoint(x: middle.x + across * unit, y: middle.y + down * unit)
        }
    }
}

/// Learning aids the game screen asks the board to show.
struct BoardGuides: Equatable {
    var showDirection = false
    /// Colors whose start square should pulse because a helmet can come out now.
    var startSquares: [PlayerColor] = []
    /// Where each movable helmet would land with the chosen number.
    var landings: [PawnLanding] = []
}

struct PawnLanding: Hashable {
    let pawn: PawnID
    let position: PawnPosition
}

/// A dashed outline of a helmet on the square a move would reach.
struct LandingMarker: View {
    let color: PlayerColor

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(Palette.arc, style: StrokeStyle(lineWidth: size * 0.06, dash: [size * 0.1, size * 0.07]))
                    .frame(width: size * 0.78, height: size * 0.78)
                HelmetShape(tint: Palette.color(color))
                    .frame(width: size * 0.55, height: size * 0.55)
                    .opacity(0.45)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private extension CGFloat {
    /// -1, 0 or 1.
    func clamped() -> CGFloat { self > 0 ? 1 : (self < 0 ? -1 : 0) }
}

// MARK: - Pawns

/// A welding helmet in the player's color. Its lens lights up like a struck arc when
/// the pawn can move. It is counter-rotated with the board so it always faces the player.
struct PawnView: View {
    let color: PlayerColor
    /// On a safe square, where it cannot be captured. Shown as a small shield.
    var isSafe = false
    let isMovable: Bool
    let isSelected: Bool
    let counterRotation: Double

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                if isMovable {
                    Circle()
                        .fill(Palette.arc.opacity(isSelected ? 0.45 : 0.25))
                        .overlay(Circle().stroke(.white, lineWidth: size * 0.06))
                        .opacity(isSelected ? 1 : 0.85)
                        .scaleEffect(isSelected ? 1.22 : 1.1)
                }
                HelmetShape(tint: Palette.color(color), lensLit: isMovable)
                    .shadow(color: .black.opacity(0.4), radius: size * 0.05, y: size * 0.05)
                if isSafe {
                    Image(systemName: "shield.fill")
                        .font(.system(size: size * 0.3, weight: .bold))
                        .foregroundStyle(Palette.safe)
                        .overlay(
                            Image(systemName: "shield")
                                .font(.system(size: size * 0.3, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: size * 0.26, y: size * 0.24)
                        .accessibilityLabel("Safe")
                }
            }
            .frame(width: size * 0.7, height: size * 0.7)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .rotationEffect(.degrees(counterRotation))
        }
    }
}

/// The welding helmet drawing, shared by the pawns and the hint card.
struct HelmetShape: View {
    let tint: Color
    var lensLit: Bool = false

    var body: some View {
        drawing.accessibilityHidden(true)
    }

    private var drawing: some View {
        Canvas { context, size in
            let w = min(size.width, size.height)
            let ox = (size.width - w) / 2
            let oy = (size.height - w) / 2
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * w, y: oy + y * w) }

            // Shell: a rounded dome that narrows to a chin.
            var shell = Path()
            shell.move(to: p(0.14, 0.58))
            shell.addCurve(to: p(0.5, 0.05), control1: p(0.12, 0.22), control2: p(0.28, 0.05))
            shell.addCurve(to: p(0.86, 0.58), control1: p(0.72, 0.05), control2: p(0.88, 0.22))
            shell.addCurve(to: p(0.64, 0.95), control1: p(0.86, 0.78), control2: p(0.76, 0.92))
            shell.addLine(to: p(0.36, 0.95))
            shell.addCurve(to: p(0.14, 0.58), control1: p(0.24, 0.92), control2: p(0.14, 0.78))
            shell.closeSubpath()

            context.fill(shell, with: .color(tint))
            context.fill(shell, with: .linearGradient(
                Gradient(colors: [.white.opacity(0.38), .clear, .black.opacity(0.3)]),
                startPoint: p(0.15, 0.1), endPoint: p(0.85, 0.9)
            ))
            context.stroke(shell, with: .color(.black.opacity(0.45)), lineWidth: w * 0.035)

            // Ridge over the crown.
            var ridge = Path()
            ridge.move(to: p(0.3, 0.2))
            ridge.addQuadCurve(to: p(0.7, 0.2), control: p(0.5, 0.08))
            context.stroke(ridge, with: .color(.white.opacity(0.35)), lineWidth: w * 0.04)

            // Headgear pivot.
            context.fill(Path(ellipseIn: CGRect(x: ox + 0.09 * w, y: oy + 0.45 * w, width: 0.11 * w, height: 0.11 * w)), with: .color(Color(white: 0.2)))
            context.fill(Path(ellipseIn: CGRect(x: ox + 0.80 * w, y: oy + 0.45 * w, width: 0.11 * w, height: 0.11 * w)), with: .color(Color(white: 0.2)))

            // Lens.
            let lensRect = CGRect(x: ox + 0.27 * w, y: oy + 0.40 * w, width: 0.46 * w, height: 0.2 * w)
            let lens = Path(roundedRect: lensRect, cornerRadius: w * 0.04)
            context.fill(Path(roundedRect: lensRect.insetBy(dx: -w * 0.04, dy: -w * 0.04), cornerRadius: w * 0.06), with: .color(Color(white: 0.16)))
            if lensLit {
                context.fill(lens, with: .linearGradient(
                    Gradient(colors: [Color(red: 1, green: 0.95, blue: 0.7), Palette.arc]),
                    startPoint: CGPoint(x: lensRect.minX, y: lensRect.minY), endPoint: CGPoint(x: lensRect.maxX, y: lensRect.maxY)
                ))
            } else {
                context.fill(lens, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.12, green: 0.24, blue: 0.18), Color(red: 0.04, green: 0.08, blue: 0.06)]),
                    startPoint: CGPoint(x: lensRect.minX, y: lensRect.minY), endPoint: CGPoint(x: lensRect.maxX, y: lensRect.maxY)
                ))
                var glint = Path()
                glint.move(to: CGPoint(x: lensRect.minX + w * 0.05, y: lensRect.minY + w * 0.05))
                glint.addLine(to: CGPoint(x: lensRect.minX + w * 0.16, y: lensRect.minY + w * 0.05))
                context.stroke(glint, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: w * 0.035, lineCap: .round))
            }
        }
    }
}
