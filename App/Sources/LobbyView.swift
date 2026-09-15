import SwiftUI
import ParjamieEngine
import ParjamieNet

struct LobbyView: View {
    @Bindable var session: MatchSession
    @State private var setup: PawnSetup = .oneColorEach
    @AppStorage(PlayerName.key) private var playerName = ""
    @AppStorage(HintSetting.key) private var showHints = true
    @AppStorage(SoundSetting.key) private var playSounds = true
    @FocusState private var nameFocused: Bool
    @State private var showHowToPlay = false
    @State private var showScoreboard = false
    @State private var showOnePhone = false
    @State private var showComputer = false
    @AppStorage(SecondPlayerName.key) private var secondName = ""
    @AppStorage(HouseRulesSetting.key) private var houseRulesRaw = ""
    @State private var showHouseRules = false
    @Environment(ScoreboardStore.self) private var scoreboardStore

    private var houseRules: Binding<HouseRules> {
        Binding(
            get: { HouseRulesSetting.decode(houseRulesRaw) },
            set: { houseRulesRaw = HouseRulesSetting.encode($0) }
        )
    }

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .background { ShopBackdrop().ignoresSafeArea() }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: session.discovered)
        .sheet(isPresented: $showHowToPlay) { HowToPlayView() }
        // Sheets on the Mac don't inherit observable environment objects, so pass the store along.
        .sheet(isPresented: $showScoreboard) { ScoreboardView().environment(scoreboardStore) }
        .sheet(isPresented: $showHouseRules) { HouseRulesView(rules: houseRules) }
        .onAppear {
            #if DEBUG
            switch ScreenshotScene.current {
            case "-shotScores": showScoreboard = true
            case "-shotRules": showHouseRules = true
            case "-shotGuide": showHowToPlay = true
            default: break
            }
            #endif
        }
        .sheet(isPresented: $showComputer) {
            ComputerSetupView(playerName: $playerName) { level in
                showComputer = false
                session.startComputerGame(setup: setup, playerName: trimmedName.isEmpty ? "You" : trimmedName,
                                          level: level, rules: houseRules.wrappedValue)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showOnePhone) {
            OnePhoneSetupView(firstName: $playerName, secondName: $secondName, setup: setup) { names in
                showOnePhone = false
                session.startLocalGame(setup: setup, names: names, rules: houseRules.wrappedValue)
            }
            .presentationDetents([.medium])
        }
    }

    /// Everything on the start screen. It fits a phone without scrolling at the usual text
    /// sizes; the scroll view is only a fallback for very large text.
    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            title
            Spacer(minLength: 14)

            switch session.status {
            case .idle:
                start
            case .waitingForPlayer:
                waiting
            case .searching, .connecting:
                searching
            case .lost(let reason):
                problem(reason)
            case .playing, .reconnecting:
                ProgressView().tint(Palette.arc)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 20)
        // Keep the controls a comfortable width on iPad and Mac.
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private var title: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(.radialGradient(colors: [Palette.arc.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 36))
                    .frame(width: 72, height: 72)
                    .offset(x: 14, y: 12)
                HelmetShape(tint: Palette.color(.red), lensLit: true)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
            }
            .frame(height: 48)
            Text("PARJAMIE")
                .font(.rounded(32, .black))
                .tracking(3)
                .foregroundStyle(.linearGradient(colors: [Color(white: 0.97), Color(white: 0.7)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.6), radius: 0, y: 2)
            WeldBead()
                .frame(width: 160, height: 6)
            Text("The race home, for two")
                .font(.rounded(13, .semibold))
                .tracking(1.5)
                .foregroundStyle(Palette.arc)
        }
    }

    // MARK: Choosing a game

    private var start: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Your name")
                TextField("", text: $playerName, prompt: Text("So the other player knows it's you").foregroundStyle(.white.opacity(0.35)))
                    .font(.rounded(17, .semibold))
                    .foregroundStyle(.white)
                    .tint(Palette.arc)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.black.opacity(0.4)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(nameFocused ? Palette.arc : .white.opacity(0.14), lineWidth: nameFocused ? 1.5 : 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Pawns")
                HStack(spacing: 10) {
                    ForEach(PawnSetup.allCases, id: \.self) { option in
                        setupTile(option)
                    }
                }
                houseRulesButton
            }

            HStack(spacing: 10) {
                settingToggle("Hints", systemImage: "lightbulb.fill", isOn: $showHints)
                settingToggle("Sound", systemImage: "speaker.wave.2.fill", isOn: $playSounds)
            }

            VStack(spacing: 10) {
                // Two phones: one hosts, the other joins.
                HStack(spacing: 10) {
                    primary("Host a game") {
                        session.displayName = trimmedName
                        session.startHosting(setup: setup, rules: houseRules.wrappedValue)
                    }
                    secondary("Join a game") {
                        session.displayName = trimmedName
                        session.startSearching()
                    }
                }
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.4 : 1)
                HStack(spacing: 10) {
                    secondary("Together", systemImage: "iphone") {
                        showOnePhone = true
                    }
                    secondary("Vs computer", systemImage: "cpu") {
                        showComputer = true
                    }
                }
                HStack(spacing: 10) {
                    secondary("Scoreboard", systemImage: "list.number", compact: true) {
                        showScoreboard = true
                    }
                    secondary("How to play", systemImage: "questionmark.circle", compact: true) {
                        showHowToPlay = true
                    }
                }
            }
        }
    }

    private var houseRulesButton: some View {
        let changed = houseRules.wrappedValue.changedCount
        return Button {
            showHouseRules = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.arc)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("House rules")
                        .font(.rounded(16, .semibold))
                        .foregroundStyle(.white)
                    Text(changed == 0 ? "Classic rules" : "\(changed) \(changed == 1 ? "rule" : "rules") changed")
                        .font(.rounded(12))
                        .foregroundStyle(changed == 0 ? .white.opacity(0.55) : Palette.arc)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .steelPlate(highlighted: changed > 0)
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.mono(12, .bold))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.leading, 2)
    }

    private func settingToggle(_ title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(Palette.arc)
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.rounded(16, .semibold))
            .foregroundStyle(.white)
            .accessibilityElement(children: .combine)
        }
        .tint(Palette.arc)
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .steelPlate()
    }

    private func setupTile(_ option: PawnSetup) -> some View {
        let chosen = setup == option
        return Button {
            setup = option
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // A little helmet lens stands in for the radio button, lit when chosen.
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(chosen
                              ? AnyShapeStyle(.linearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.7), Palette.arc], startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color(red: 0.06, green: 0.12, blue: 0.09)))
                        .frame(width: 18, height: 8)
                        .padding(3)
                        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color(white: 0.12)))
                        .shadow(color: chosen ? Palette.arc.opacity(0.8) : .clear, radius: 6)
                    Text(option.title)
                        .font(.rounded(15, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(option.detail)
                    .font(.rounded(12))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .steelPlate(highlighted: chosen)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    // MARK: Connecting

    private var waiting: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large).tint(Palette.arc)
            Text("Waiting for the other phone")
                .font(.rounded(19, .semibold))
                .foregroundStyle(.white)
            Text("On the other device, tap Join a game and pick \(session.displayName).")
                .font(.rounded(14))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            cancel
        }
        .padding(24)
        .steelPlate()
    }

    private var searching: some View {
        VStack(spacing: 14) {
            if session.discovered.isEmpty {
                ProgressView().controlSize(.large).tint(Palette.arc)
                Text("Looking for a game nearby")
                    .font(.rounded(19, .semibold))
                    .foregroundStyle(.white)
                Text("Both phones need to be on the same Wi-Fi, and the other one has to be hosting.")
                    .font(.rounded(14))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            } else {
                sectionLabel("Tap a game to join")
                ForEach(session.discovered) { peer in
                    Button { session.join(peer) } label: {
                        HStack(spacing: 12) {
                            HelmetShape(tint: Palette.color(.yellow), lensLit: true)
                                .frame(width: 26, height: 26)
                            Text(peer.name)
                                .font(.rounded(17, .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Palette.arc)
                        }
                        .padding(16)
                        .steelPlate()
                    }
                    .buttonStyle(.plain)
                }
            }
            cancel
        }
    }

    private func problem(_ reason: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                .font(.system(size: 36))
                .foregroundStyle(Palette.arc)
            Text(reason)
                .font(.rounded(16, .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            primary("Start over") { session.stop() }
        }
        .padding(24)
        .steelPlate()
    }

    private var cancel: some View {
        Button("Cancel") { session.stop() }
            .font(.rounded(15, .medium))
            .foregroundStyle(.white.opacity(0.55))
            .padding(.top, 6)
    }

    // MARK: Buttons

    /// Glows like a struck arc.
    private func primary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.rounded(18, .bold))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.linearGradient(colors: [Color(red: 1, green: 0.72, blue: 0.3), Palette.arc, Color(red: 0.85, green: 0.38, blue: 0.05)],
                                              startPoint: .top, endPoint: .bottom))
                )
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: Palette.arc.opacity(0.45), radius: 12, y: 2)
                .foregroundStyle(Palette.ink)
        }
        .buttonStyle(.plain)
    }

    private func secondary(_ label: String, systemImage: String? = nil, compact: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(label)
            }
                .font(.rounded(compact ? 16 : 18, .semibold))
                .frame(maxWidth: .infinity, minHeight: compact ? 44 : 50)
                .foregroundStyle(.white)
                .steelPlate()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shop pieces

/// Dark brushed steel with a faint arc glow, behind the setup screens.
struct ShopBackdrop: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.13, green: 0.14, blue: 0.16), Color(red: 0.06, green: 0.07, blue: 0.08)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
            ))
            var grain = Path()
            var y: CGFloat = 2
            var i = 0
            while y < size.height {
                grain.move(to: CGPoint(x: CGFloat(i % 3) * 8, y: y))
                grain.addLine(to: CGPoint(x: size.width - CGFloat((i * 7) % 4) * 6, y: y))
                y += 3 + CGFloat((i * 5) % 3)
                i += 1
            }
            context.stroke(grain, with: .color(.white.opacity(0.03)), lineWidth: 1)
            let glow = CGPoint(x: size.width * 0.62, y: size.height * 0.1)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
                Gradient(colors: [Palette.arc.opacity(0.16), .clear]), center: glow, startRadius: 0, endRadius: size.width * 0.8
            ))
        }
    }
}

/// A short run of weld bead, used as a rule under the title.
struct WeldBead: View {
    var body: some View {
        Canvas { context, size in
            let r = size.height / 2
            var x = r
            while x < size.width - r {
                let dot = CGRect(x: x - r, y: 0, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: dot), with: .radialGradient(
                    Gradient(colors: [Color(white: 0.95), Palette.bead, Palette.beadEdge]),
                    center: CGPoint(x: x - r * 0.35, y: r * 0.65), startRadius: 0, endRadius: r * 1.3
                ))
                x += r * 1.3
            }
        }
    }
}

private struct SteelPlate: ViewModifier {
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.linearGradient(colors: [Color(white: 0.27), Color(white: 0.17)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(highlighted ? Palette.arc : .white.opacity(0.12), lineWidth: highlighted ? 1.5 : 1)
            )
            .shadow(color: highlighted ? Palette.arc.opacity(0.3) : .black.opacity(0.4), radius: highlighted ? 8 : 4, y: 2)
    }
}

extension View {
    func steelPlate(highlighted: Bool = false) -> some View {
        modifier(SteelPlate(highlighted: highlighted))
    }
}

/// Names for both players before a game passed back and forth on one phone.
struct OnePhoneSetupView: View {
    @Binding var firstName: String
    @Binding var secondName: String
    let setup: PawnSetup
    let onStart: ([String]) -> Void

    private var names: [String] {
        [firstName, secondName].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PLAY ON ONE PHONE")
                .font(.rounded(20, .black))
                .tracking(2)
                .foregroundStyle(.white)
            Text("Take turns passing the phone. The board turns to face whoever is up.")
                .font(.rounded(14))
                .foregroundStyle(.white.opacity(0.65))
            playerField("First player", tint: Palette.color(setup.colors(for: .one)[0]), text: $firstName)
            playerField("Second player", tint: Palette.color(setup.colors(for: .two)[0]), text: $secondName)
            Button {
                onStart(names)
            } label: {
                Text("Start")
                    .font(.rounded(18, .bold))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.linearGradient(colors: [Color(red: 1, green: 0.72, blue: 0.3), Palette.arc, Color(red: 0.85, green: 0.38, blue: 0.05)],
                                                  startPoint: .top, endPoint: .bottom))
                    )
                    .foregroundStyle(Palette.ink)
            }
            .buttonStyle(.plain)
            .disabled(names.contains(where: \.isEmpty))
            .opacity(names.contains(where: \.isEmpty) ? 0.4 : 1)
            Spacer(minLength: 0)
        }
        .padding(24)
        .background { ShopBackdrop().ignoresSafeArea() }
        .preferredColorScheme(.dark)
    }

    private func playerField(_ label: String, tint: Color, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            HelmetShape(tint: tint, lensLit: true)
                .frame(width: 34, height: 34)
            TextField("", text: text, prompt: Text(label).foregroundStyle(.white.opacity(0.35)))
                .font(.rounded(17, .semibold))
                .foregroundStyle(.white)
                .tint(Palette.arc)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.black.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
        }
    }
}

/// Choose a computer opponent to play on this phone.
struct ComputerSetupView: View {
    @Binding var playerName: String
    let onStart: (ComputerPlayer.Level) -> Void
    @State private var level: ComputerPlayer.Level = .easy

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("PLAY THE COMPUTER")
                    .font(.rounded(20, .black))
                    .tracking(2)
                    .foregroundStyle(.white)
                Text("You play Red and go first. The computer takes its turns on its own.")
                    .font(.rounded(14))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)

                TextField("", text: $playerName, prompt: Text("Your name").foregroundStyle(.white.opacity(0.35)))
                    .font(.rounded(17, .semibold))
                    .foregroundStyle(.white)
                    .tint(Palette.arc)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.black.opacity(0.4)))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))

                opponent(.easy, name: "Sparky", detail: "Still learning. Makes plenty of friendly moves.")
                opponent(.hard, name: "Torch", detail: "A seasoned pro. Captures, blocks and plays it safe.")

                Button {
                    onStart(level)
                } label: {
                    Text("Start")
                        .font(.rounded(18, .bold))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.linearGradient(colors: [Color(red: 1, green: 0.72, blue: 0.3), Palette.arc, Color(red: 0.85, green: 0.38, blue: 0.05)],
                                                      startPoint: .top, endPoint: .bottom))
                        )
                        .foregroundStyle(Palette.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .background { ShopBackdrop().ignoresSafeArea() }
        .preferredColorScheme(.dark)
    }

    private func opponent(_ option: ComputerPlayer.Level, name: String, detail: String) -> some View {
        let chosen = level == option
        return Button {
            level = option
        } label: {
            HStack(spacing: 14) {
                HelmetShape(tint: Palette.color(.yellow), lensLit: chosen)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(name) · \(option == .easy ? "Easy" : "Hard")")
                        .font(.rounded(17, .semibold))
                        .foregroundStyle(.white)
                    Text(detail)
                        .font(.rounded(13))
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .steelPlate(highlighted: chosen)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
