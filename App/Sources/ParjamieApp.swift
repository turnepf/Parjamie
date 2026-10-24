import SwiftUI
import ParjamieNet

@main
struct ParjamieApp: App {
    @State private var session = MatchSession(
        displayName: UserDefaults.standard.string(forKey: PlayerName.key) ?? ""
    )
    @State private var scoreboard = ScoreboardStore(cloud: ScoreboardStore.usesCloud ? .default : nil)

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

extension ScoreboardStore {
    /// The staged screenshot games stay out of the player's real iCloud scoreboard.
    static var usesCloud: Bool {
        #if DEBUG
        ScreenshotScene.current == nil
        #else
        true
        #endif
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

extension RootView {
    /// On the Mac the game runs in a resizable window. Keep it big enough that the board
    /// stays playable; past that, a tall window puts the controls under the board and a
    /// wide one puts them beside it.
    func limitMacWindowSize() {
        #if targetEnvironment(macCatalyst)
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.sizeRestrictions?.minimumSize = CGSize(width: 520, height: 640)
        }
        #endif
    }
}

struct RootView: View {
    @Bindable var session: MatchSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(WelcomeTourSetting.key) private var seenWelcomeTour = false
    @Environment(ScoreboardStore.self) private var shotStore

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
        // Fonts are sized from the text size setting when drawn, so rebuild when it changes.
        .id(typeSize)
        .animation(.easeInOut(duration: 0.25), value: session.status)
        .fullScreenCover(isPresented: Binding(get: { !seenWelcomeTour }, set: { seenWelcomeTour = !$0 })) {
            WelcomeTourView { seenWelcomeTour = true }
        }
        .onAppear(perform: limitMacWindowSize)
        .task {
            #if DEBUG
            await ScreenshotScene.run(session: session, store: shotStore)
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.appBecameActive() }
        }
    }
}
