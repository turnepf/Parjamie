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

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            title
            Spacer(minLength: 24)

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
                ProgressView()
            }

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 28)
        .animation(.easeInOut(duration: 0.2), value: session.discovered)
    }

    private var title: some View {
        VStack(spacing: 8) {
            Text("Parjamie")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.felt)
            Text("The race home, for two")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Palette.ink.opacity(0.45))
        }
    }

    // MARK: Choosing a game

    private var start: some View {
        VStack(spacing: 26) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your name")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Palette.ink.opacity(0.45))
                TextField("So the other player knows it's you", text: $playerName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .padding(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Palette.ink.opacity(nameFocused ? 0.3 : 0.1), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Pawns")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Palette.ink.opacity(0.45))
                ForEach(PawnSetup.allCases, id: \.self) { option in
                    setupRow(option)
                }
            }

            Toggle(isOn: $showHints) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show hints")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("Step-by-step help on each turn while you learn.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.5))
                }
            }
            .tint(Palette.felt)
            .padding(.horizontal, 14)

            Toggle(isOn: $playSounds) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shop sounds")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("Arc crackle and sparks. The silent switch mutes them too.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.5))
                }
            }
            .tint(Palette.felt)
            .padding(.horizontal, 14)

            VStack(spacing: 12) {
                primary("Host a game") {
                    session.displayName = trimmedName
                    session.startHosting(setup: setup)
                }
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.4 : 1)
                secondary("Join a game") {
                    session.displayName = trimmedName
                    session.startSearching()
                }
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.4 : 1)
                Button("Both of us on this phone") { session.startLocalGame(setup: setup) }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.5))
                    .padding(.top, 2)
            }
        }
    }

    private func setupRow(_ option: PawnSetup) -> some View {
        Button {
            setup = option
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .stroke(setup == option ? Palette.felt : Palette.ink.opacity(0.25), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .overlay {
                        if setup == option {
                            Circle().fill(Palette.felt).frame(width: 11, height: 11)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text(option.detail)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(setup == option ? Palette.felt.opacity(0.07) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Palette.ink.opacity(setup == option ? 0.18 : 0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Connecting

    private var waiting: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text("Waiting for the other phone")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text("On the other device, tap Join a game and pick \(session.displayName).")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.55))
                .multilineTextAlignment(.center)
            cancel
        }
    }

    private var searching: some View {
        VStack(spacing: 16) {
            if session.discovered.isEmpty {
                ProgressView().controlSize(.large)
                Text("Looking for a game nearby")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("Both phones need to be on the same Wi-Fi, and the other one has to be hosting.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.55))
                    .multilineTextAlignment(.center)
            } else {
                Text("Tap a game to join")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Palette.ink.opacity(0.45))
                ForEach(session.discovered) { peer in
                    Button { session.join(peer) } label: {
                        HStack {
                            Text(peer.name)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Palette.ink.opacity(0.3))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Palette.felt.opacity(0.07))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            cancel
        }
    }

    private func problem(_ reason: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(Palette.color(.red))
            Text(reason)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            primary("Start over") { session.stop() }
        }
    }

    private var cancel: some View {
        Button("Cancel") { session.stop() }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(Palette.ink.opacity(0.5))
            .padding(.top, 6)
    }

    // MARK: Buttons

    private func primary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.felt))
                .foregroundStyle(Palette.parchment)
        }
        .buttonStyle(.plain)
    }

    private func secondary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.felt.opacity(0.1)))
                .foregroundStyle(Palette.felt)
        }
        .buttonStyle(.plain)
    }
}
