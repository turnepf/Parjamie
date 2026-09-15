import SwiftUI
import ParjamieEngine

struct DieFace: View {
    let value: Int

    private static let layouts: [Int: [(CGFloat, CGFloat)]] = [
        1: [(0.5, 0.5)],
        2: [(0.28, 0.28), (0.72, 0.72)],
        3: [(0.28, 0.28), (0.5, 0.5), (0.72, 0.72)],
        4: [(0.28, 0.28), (0.72, 0.28), (0.28, 0.72), (0.72, 0.72)],
        5: [(0.28, 0.28), (0.72, 0.28), (0.5, 0.5), (0.28, 0.72), (0.72, 0.72)],
        6: [(0.28, 0.24), (0.72, 0.24), (0.28, 0.5), (0.72, 0.5), (0.28, 0.76), (0.72, 0.76)]
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                // A machined steel block with punched pips.
                RoundedRectangle(cornerRadius: side * 0.18, style: .continuous)
                    .fill(.linearGradient(
                        Gradient(colors: [Color(white: 0.90), Color(white: 0.62)]),
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .shadow(color: .black.opacity(0.28), radius: side * 0.06, y: side * 0.04)
                RoundedRectangle(cornerRadius: side * 0.18, style: .continuous)
                    .stroke(Palette.seam.opacity(0.7), lineWidth: 1)
                ForEach(Array((Self.layouts[value] ?? []).enumerated()), id: \.offset) { _, spot in
                    Circle()
                        .fill(.radialGradient(
                            Gradient(colors: [Palette.ink, Palette.ink.opacity(0.75)]),
                            center: UnitPoint(x: 0.65, y: 0.65), startRadius: 0, endRadius: side * 0.09
                        ))
                        .overlay(
                            Circle().trim(from: 0.55, to: 0.95)
                                .stroke(.white.opacity(0.7), lineWidth: side * 0.018)
                                .rotationEffect(.degrees(-20))
                        )
                        .frame(width: side * 0.15, height: side * 0.15)
                        .position(x: side * spot.0, y: side * spot.1)
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Die showing \(value)")
    }
}

/// One unspent amount the player can put on a pawn.
struct ValueChip: View {
    let value: MoveValue
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    private var label: String {
        switch value.kind {
        case .die: "\(value.amount)"
        case .captureBonus, .homeBonus: "+\(value.amount)"
        }
    }

    private var tint: Color {
        value.kind == .die ? Palette.ink : Color(red: 0.62, green: 0.42, blue: 0.13)
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.rounded(20, .semibold))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Palette.parchment : tint)
                .frame(minWidth: 52, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? tint : Palette.parchment)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tint.opacity(isSelected ? 0 : 0.45), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
        .accessibilityLabel(value.kind == .die ? "Move \(value.amount)" : "Bonus move \(value.amount)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
