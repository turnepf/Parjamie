import SwiftUI
import ParjamieEngine

/// Where the start screen keeps the house rules between launches.
enum HouseRulesSetting {
    static let key = "houseRules"

    static func decode(_ raw: String) -> HouseRules {
        guard let data = raw.data(using: .utf8),
              let rules = try? JSONDecoder().decode(HouseRules.self, from: data) else { return .classic }
        return rules
    }

    static func encode(_ rules: HouseRules) -> String {
        guard let data = try? JSONEncoder().encode(rules) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

/// Pick the house rules before hosting or starting a game on one phone. During a game the
/// same screen opens read-only, so both players can see what they are playing by.
struct HouseRulesView: View {
    @Binding var rules: HouseRules
    var editable = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("HOUSE RULES")
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
                Text(editable
                     ? "Change how the game plays. When you host, the other phone plays by your rules."
                     : (rules.isClassic ? "This game uses the classic rules." : "This game uses these house rules."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                group("Getting going") {
                    choice("Bring a helmet out on", detail: rules.entryPhrase.capitalizedFirst, selection: $rules.entry, options: [
                        (.five, "5"), (.six, "6"), (.oneOrSix, "1 or 6")
                    ])
                    toggle("Quick start", detail: "Each player begins with one helmet already on their start square.", isOn: $rules.quickStart)
                }

                group("Moving") {
                    choice("Getting home", detail: rules.home == .exact
                           ? "Takes an exact count."
                           : "Overshoot, and the helmet bounces back by the extra squares.",
                           selection: $rules.home, options: [(.exact, "Exact count"), (.bounce, "Bounce back")])
                    toggle("Blockades", detail: "Two helmets on one square block everyone, even their owner.", isOn: $rules.blockades)
                    toggle("Shuffle safe spots", detail: "Purple safe squares move to new places each game, the same for both players.", isOn: $rules.shuffleSafeSpots)
                }

                group("Captures and bonuses") {
                    toggle("Must capture", detail: "When you can capture, you have to.", isOn: $rules.mustCapture)
                    toggle("+20 for a capture", detail: "Squares to spend on one helmet after sending another player's helmet home.", isOn: $rules.captureBonus)
                    toggle("+10 for getting home", detail: "Squares to spend on one helmet after one reaches the middle.", isOn: $rules.homeBonus)
                }

                group("Doubles") {
                    toggle("Use the bottoms of the dice", detail: "Doubles with every helmet out also give the numbers on the bottoms, for four moves.", isOn: $rules.doublesUseBottoms)
                    choice("Three doubles in a row", detail: threeDoublesDetail, selection: $rules.threeDoubles, options: [
                        (.sendBack, "Overheat"), (.loseTurn, "Lose turn"), (.nothing, "Nothing")
                    ])
                }

                if editable && !rules.isClassic {
                    Button {
                        rules = .classic
                    } label: {
                        Label("Back to classic rules", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(.white)
                            .steelPlate()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background { ShopBackdrop().ignoresSafeArea() }
        .preferredColorScheme(.dark)
    }

    private var threeDoublesDetail: String {
        switch rules.threeDoubles {
        case .sendBack: "Overheated! Your farthest helmet goes back to its bay and your turn ends."
        case .loseTurn: "Your turn ends, but nobody goes back."
        case .nothing: "Keep rolling as long as the doubles come."
        }
    }

    // MARK: Pieces

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Palette.arc)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .steelPlate()
    }

    private func toggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Group {
            if editable {
                Toggle(isOn: isOn) { labels(title, detail) }
                    .tint(Palette.arc)
            } else {
                HStack(alignment: .top) {
                    labels(title, detail)
                    Spacer()
                    Text(isOn.wrappedValue ? "On" : "Off")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isOn.wrappedValue ? Palette.arc : .white.opacity(0.5))
                }
            }
        }
    }

    private func choice<Value: Hashable>(_ title: String, detail: String, selection: Binding<Value>, options: [(Value, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if editable {
                labels(title, detail)
                Picker(title, selection: selection) {
                    ForEach(options, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                HStack(alignment: .top) {
                    labels(title, detail)
                    Spacer()
                    Text(options.first { $0.0 == selection.wrappedValue }?.1 ?? "")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.arc)
                }
            }
        }
    }

    private func labels(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
