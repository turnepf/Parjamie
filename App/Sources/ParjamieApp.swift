import SwiftUI
import ParjamieNet

@main
struct ParjamieApp: App {
    @State private var session = MatchSession(
        displayName: UserDefaults.standard.string(forKey: PlayerName.key) ?? ""
    )
    @State private var scoreboard = ScoreboardStore()

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
                .environment(scoreboard)
                .preferredColorScheme(.light)
                .onAppear {
                    ShopSounds.shared.warmUp()
                    // The two phones swap finished games whenever they connect.
                    session.scoreboardRecords = { [scoreboard] in scoreboard.scoreboard.records }
                    session.onScoreboardReceived = { [scoreboard] in scoreboard.merge($0) }
                }
        }
    }
}

/// iOS reports every phone as just "iPhone", so players type their own name once.
enum PlayerName {
    static let key = "playerName"
}

/// The name last used for the second player on a shared phone.
enum SecondPlayerName {
    static let key = "secondPlayerName"
}

/// Turn-by-turn coaching for people learning the game. On unless the player turns it off.
enum HintSetting {
    static let key = "showHints"
}

struct RootView: View {
    @Bindable var session: MatchSession
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Palette.parchment.ignoresSafeArea()
            if session.game != nil, session.status == .playing || session.status == .reconnecting {
                GameView(session: session)
                    .transition(.opacity)
            } else {
                LobbyView(session: session)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.status)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.appBecameActive() }
        }
    }
}
