import SwiftUI
import ParjamieEngine

/// A welding shop: steel plate, weld beads, painted floor markings and the orange of
/// a struck arc. The board keeps the traditional cross-and-circle race layout.
enum Palette {
    /// Dark blued steel, used for titles and the main buttons.
    static let felt = Color(red: 0.16, green: 0.19, blue: 0.23)
    static let feltEdge = Color(red: 0.09, green: 0.10, blue: 0.12)
    /// The shop floor the board sits on.
    static let floor = Color(red: 0.17, green: 0.18, blue: 0.20)
    static let floorEdge = Color(red: 0.08, green: 0.09, blue: 0.10)
    /// Diamond plate for the track.
    static let plate = Color(red: 0.66, green: 0.68, blue: 0.70)
    static let plateShade = Color(red: 0.47, green: 0.49, blue: 0.52)
    static let seam = Color(red: 0.24, green: 0.25, blue: 0.27)
    /// A cooled weld bead, and the straw-to-blue heat tint beside it.
    static let bead = Color(red: 0.74, green: 0.70, blue: 0.64)
    static let beadEdge = Color(red: 0.33, green: 0.30, blue: 0.28)
    static let heatTint = Color(red: 0.72, green: 0.56, blue: 0.30)
    /// The glow of a struck arc.
    static let arc = Color(red: 1.0, green: 0.56, blue: 0.12)
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.15)
    static let parchment = Color(red: 0.94, green: 0.94, blue: 0.92)

    static func color(_ color: PlayerColor) -> Color {
        switch color {
        case .red: Color(red: 0.82, green: 0.20, blue: 0.16)    // safety red
        case .blue: Color(red: 0.18, green: 0.42, blue: 0.80)   // cobalt
        case .yellow: Color(red: 0.97, green: 0.74, blue: 0.08) // hi-vis yellow
        case .green: Color(red: 0.16, green: 0.60, blue: 0.34)  // machine green
        }
    }

    static func name(_ color: PlayerColor) -> String {
        switch color {
        case .red: "Red"
        case .blue: "Blue"
        case .yellow: "Yellow"
        case .green: "Green"
        }
    }
}

extension PawnSetup {
    var title: String {
        switch self {
        case .oneColorEach: "One color each"
        case .twoColorsEach: "Two colors each"
        }
    }

    var detail: String {
        switch self {
        case .oneColorEach: "Four pawns apiece. A quicker game."
        case .twoColorsEach: "Eight pawns apiece. The longer, tactical game."
        }
    }
}
