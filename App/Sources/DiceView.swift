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
                RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                    .fill(Palette.parchment)
                    .shadow(color: .black.opacity(0.18), radius: side * 0.06, y: side * 0.04)
                RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                    .stroke(Palette.trackEdge, lineWidth: 1)
                ForEach(Array((Self.layouts[value] ?? []).enumerated()), id: \.offset) { _, spot in
                    Circle()
                        .fill(Palette.ink)
                        .frame(width: side * 0.16, height: side * 0.16)
                        .position(x: side * spot.0, y: side * spot.1)
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
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
                .font(.system(size: 20, weight: .semibold, design: .rounded))
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
    }
}
