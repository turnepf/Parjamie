import SwiftUI

/// Puts the board and the game controls side by side when the space is wider than it is
/// tall, and the controls under the board when it is taller than it is wide.
///
/// This follows Apple's layout guidance for iPhone Duo, iPad and the Mac: decide from the
/// space the game has, never from the device or the orientation, and fill the screen in
/// every pose instead of letterboxing. When an iPhone Duo is partly folded, the board goes
/// on one side of the fold and the controls on the other, so nothing sits in the crease.
///
/// This is the split that `ArrangementView` describes, built by hand: on iOS 27.1 the
/// arrangement view ignored its sizing modifiers and never reported its split direction,
/// which left the board in half the screen with the controls laid out the wrong way.
struct BoardAndControls<Board: View, Controls: View>: View {
    @ViewBuilder var board: Board
    @ViewBuilder var controls: Controls

    /// Wide enough for the header, a hint and the roll button, narrow enough to leave the
    /// board most of the room.
    static var columnWidth: CGFloat { 350 }

    var body: some View {
        GeometryReader { proxy in
            let fold = Self.fold(in: proxy)
            let axis: Axis = if let fold {
                // A fold running top to bottom splits the screen into left and right.
                fold.height > fold.width ? .horizontal : .vertical
            } else {
                proxy.size.width > proxy.size.height ? .horizontal : .vertical
            }
            let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))

            layout {
                if let fold {
                    board
                        .frame(width: axis == .horizontal ? fold.minX : nil, height: axis == .vertical ? fold.minY : nil)
                    Color.clear
                        .frame(width: axis == .horizontal ? fold.width : nil, height: axis == .vertical ? fold.height : nil)
                    controls
                } else {
                    board
                    controls
                        .frame(width: axis == .horizontal ? Self.columnWidth : nil)
                        .fixedSize(horizontal: false, vertical: axis == .vertical)
                }
            }
            .environment(\.boardControlsAxis, axis)
        }
    }

    /// Where the fold crosses this view while an iPhone Duo is partly open.
    private static func fold(in proxy: GeometryProxy) -> CGRect? {
        guard #available(iOS 27.1, macCatalyst 27.1, *) else { return nil }
        return proxy.reservedRegions(kind: .division).first(where: \.isActive)?.frame
    }
}

/// Builds its content for whichever way the board and controls are arranged.
struct ForBoardControlsAxis<Content: View>: View {
    @Environment(\.boardControlsAxis) private var axis
    @ViewBuilder var content: (Axis) -> Content

    var body: some View { content(axis) }
}

extension EnvironmentValues {
    /// `.horizontal` when the controls sit beside the board, `.vertical` when under it.
    @Entry var boardControlsAxis: Axis = .vertical
}
