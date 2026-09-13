import SwiftUI
import ParjamieEngine

enum Palette {
    static let felt = Color(red: 0.09, green: 0.17, blue: 0.15)
    static let feltEdge = Color(red: 0.05, green: 0.11, blue: 0.10)
    static let track = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let trackEdge = Color(red: 0.82, green: 0.78, blue: 0.70)
    static let ink = Color(red: 0.13, green: 0.14, blue: 0.13)
    static let parchment = Color(red: 0.99, green: 0.97, blue: 0.93)

    static func color(_ color: PlayerColor) -> Color {
        switch color {
        case .red: Color(red: 0.78, green: 0.23, blue: 0.24)
        case .blue: Color(red: 0.16, green: 0.40, blue: 0.62)
        case .yellow: Color(red: 0.90, green: 0.68, blue: 0.19)
        case .green: Color(red: 0.20, green: 0.52, blue: 0.35)
        }
    }

    static func name(_ color: PlayerColor) -> String {
        color.rawValue.capitalized
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
