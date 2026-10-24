import SwiftUI

/// Puts the board and the game controls side by side when the space is wider than it is
/// tall, and the controls under the board when it is taller than it is wide.
///
/// This follows Apple's layout guidance for iPhone Duo, iPad and the Mac: decide from the
/// space the game has, never from the device or the orientation, and fill the screen in
/// every pose instead of letterboxing. On iOS 27.1 and later it is an `ArrangementView`,
/// which also moves the two halves clear of the fold when an iPhone Duo is partly folded.
/// Earlier systems get the same two arrangements from the window's shape.
struct BoardAndControls<Board: View, Controls: View>: View {
    @ViewBuilder var board: Board
    @ViewBuilder var controls: Controls

    /// Wide enough for the header, a hint and the roll button, narrow enough to leave the
    /// board most of the room.
    static var columnWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) { (300, 350, 400) }

    var body: some View {
        if #available(iOS 27.1, macCatalyst 27.1, *) {
            ArrangementView {
                ArrangementAxisReader { board }
            } secondary: {
                ArrangementAxisReader { controls }
                    .splitArrangementLayoutSize(minWidth: Self.columnWidth.min, idealWidth: Self.columnWidth.ideal, maxWidth: Self.columnWidth.max)
                    .splitArrangementFixedLayoutSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
            .arrangementViewStyle(.split)
        } else {
            GeometryReader { proxy in
                let axis: Axis = proxy.size.width > proxy.size.height ? .horizontal : .vertical
                let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
                layout {
                    board
                    controls
                        .frame(width: axis == .horizontal ? Self.columnWidth.ideal : nil)
                        .fixedSize(horizontal: false, vertical: axis == .vertical)
                }
                .environment(\.boardControlsAxis, axis)
            }
        }
    }
}

/// Passes the arrangement's split direction on to the board and controls.
@available(iOS 27.1, macCatalyst 27.1, *)
private struct ArrangementAxisReader<Content: View>: View {
    @Environment(\.splitArrangementAxis) private var axis
    @ViewBuilder var content: Content

    var body: some View {
        content.environment(\.boardControlsAxis, axis ?? .vertical)
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
