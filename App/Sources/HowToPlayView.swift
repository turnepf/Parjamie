import SwiftUI
import ParjamieEngine

/// Whether this phone has shown the guide once already.
enum HowToPlaySetting {
    static let seenKey = "seenHowToPlay"
}

/// The rules in plain words, with a key to every kind of square on the board.
/// Opens by itself before the first game on each phone, and from the ? button after that.
struct HowToPlayView: View {
    /// Colors this phone plays. Empty when shown from the start screen before a game.
    var myColors: [PlayerColor] = []
    var isLocal = false
    var otherName: String?
    @Environment(\.dismiss) private var dismiss

    private var colorNames: String { myColors.map(Palette.name).joined(separator: " & ") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("HOW TO PLAY")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .accessibilityLabel("Close")
                }
                WeldBead().frame(width: 150, height: 6)

                if !myColors.isEmpty && !isLocal {
                    section {
                        HStack(spacing: 12) {
                            HStack(spacing: -6) {
                                ForEach(myColors, id: \.self) { HelmetShape(tint: Palette.color($0), lensLit: true).frame(width: 40, height: 40) }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("You're \(colorNames)")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Palette.color(myColors[0]))
                                Text("Your helmets start in the bay marked YOU. \(otherName ?? "The other player")'s bay has their name on it.")
                                    .modifier(GuideText())
                            }
                        }
                    }
                }

                section(title: "The goal") {
                    Text("Race all of your helmets out of your bay, once around the board, and into the steel flange in the middle. The first player to get every helmet home wins.")
                        .modifier(GuideText())
                }

                section(title: "A turn") {
                    step(1, "Tap **Strike an arc** to roll the dice.")
                    step(2, "To bring a helmet out you need a **5**: one die showing 5, or both dice adding up to 5. Tap the 5, then a helmet in your bay. It jumps to your start square.")
                    step(3, "To move, tap a number, then a glowing helmet. It moves that many squares. Each die is used on its own, and you can split them between two helmets.")
                    step(4, "Helmets travel **clockwise**, following the arrows. After nearly a full lap they turn up the painted home row in their own color and into the middle. Getting home takes an exact count.")
                    step(5, "Roll doubles and you roll again after moving.")
                }

                section(title: "What the squares mean") {
                    keyRow(sample: { StartSquareSample(color: myColors.first ?? .red) },
                           title: "Colored square with an X",
                           text: "A start square. That color's helmets come onto the board here. It's also a safe square.")
                    keyRow(sample: { SafeSquareSample() },
                           title: "Plain square with an X",
                           text: "A safe square. A helmet sitting here can't be captured. Any color can use it. You never need to land on your own color.")
                    keyRow(sample: { HomeRowSample(color: myColors.first ?? .red) },
                           title: "Painted row with arrows",
                           text: "A home row. Only helmets of that color can go up it, to the middle.")
                    keyRow(sample: { BlockadeSample(color: myColors.first ?? .red) },
                           title: "Two helmets welded together",
                           text: "A blockade. Two helmets on one square block it. Nobody can pass or land there, not even their owner.")
                }

                section(title: "Capturing") {
                    Text("Land exactly on the other player's helmet and it gets sent back to its bay. You earn **+20** squares to spend on one of your helmets.")
                        .modifier(GuideText())
                    Text("A helmet on a safe square (any X) is protected. You can't land on it at all. The one exception: bringing a helmet out onto your own start square bumps anyone sitting there.")
                        .modifier(GuideText())
                }

                section(title: "Bonuses and penalties") {
                    Text("**+10** when a helmet reaches home, to spend on another helmet.")
                        .modifier(GuideText())
                    Text("**Overheated!** Three doubles in a row sends your farthest helmet back to its bay, and your turn ends.")
                        .modifier(GuideText())
                    Text("If no helmet can use a number, it's skipped.")
                        .modifier(GuideText())
                }

                Button { dismiss() } label: {
                    Text("Got it")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.linearGradient(colors: [Color(red: 1, green: 0.72, blue: 0.3), Palette.arc, Color(red: 0.85, green: 0.38, blue: 0.05)],
                                                      startPoint: .top, endPoint: .bottom))
                        )
                        .foregroundStyle(Palette.ink)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background { ShopBackdrop().ignoresSafeArea() }
        .preferredColorScheme(.dark)
    }

    // MARK: Pieces

    private func section<Content: View>(title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.arc)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steelPlate()
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Palette.arc))
            Text(text).modifier(GuideText())
        }
    }

    private func keyRow<Sample: View>(@ViewBuilder sample: () -> Sample, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            sample()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(text).modifier(GuideText())
            }
        }
    }

    private struct GuideText: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Board key samples

/// One diamond-plate square, the base for each sample.
private struct PlateSquare: View {
    var paint: Color?
    var body: some View {
        Canvas { context, size in
            let box = CGRect(origin: .zero, size: size)
            context.fill(Path(box), with: .linearGradient(Gradient(colors: [Palette.plate, Palette.plateShade]),
                                                         startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            if let paint {
                context.fill(Path(box.insetBy(dx: size.width * 0.05, dy: size.height * 0.05)), with: .color(paint.opacity(0.9)))
            }
            context.stroke(Path(box), with: .color(Palette.seam.opacity(0.8)), lineWidth: 1.5)
        }
    }
}

private struct StartSquareSample: View {
    let color: PlayerColor
    var body: some View {
        ZStack {
            PlateSquare(paint: Palette.color(color))
            Canvas { context, size in
                BoardView.drawTackWeld(in: CGRect(origin: .zero, size: size), in: &context, unit: size.width)
            }
        }
    }
}

private struct SafeSquareSample: View {
    var body: some View {
        ZStack {
            PlateSquare()
            Canvas { context, size in
                BoardView.drawTackWeld(in: CGRect(origin: .zero, size: size), in: &context, unit: size.width)
            }
        }
    }
}

private struct HomeRowSample: View {
    let color: PlayerColor
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                ZStack {
                    PlateSquare(paint: Palette.color(color))
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(width: 19)
    }
}

private struct BlockadeSample: View {
    let color: PlayerColor
    var body: some View {
        ZStack {
            PlateSquare()
            HelmetShape(tint: Palette.color(color)).frame(width: 30, height: 30).offset(x: -9)
            HelmetShape(tint: Palette.color(color)).frame(width: 30, height: 30).offset(x: 9)
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for k in 0..<5 {
                    BoardView.drawBeadDot(at: CGPoint(x: c.x, y: c.y - 12 + CGFloat(k) * 6), radius: 3.2, in: &context)
                }
            }
        }
    }
}
