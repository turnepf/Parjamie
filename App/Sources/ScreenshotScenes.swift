// Staged scenes for App Store screenshots, debug builds only. Launch with -shotGame,
// -shotWin, -shotScores, -shotRules or -shotGuide. See scripts/app-store-screenshots.sh.
#if DEBUG
import SwiftUI
import ParjamieEngine
import ParjamieNet

enum ScreenshotScene {
    static var current: String? {
        ProcessInfo.processInfo.arguments.first { $0.hasPrefix("-shot") }
    }

    @MainActor
    static func run(session: MatchSession, store: ScoreboardStore) async {
        guard let scene = current else { return }
        let day = 86_400.0
        let results: [(String, String, Bool)] = [
            ("Alex", "Sam", false), ("Sam", "Alex", false), ("Alex", "Torch", true), ("Alex", "Sam", false),
            ("Torch", "Alex", true), ("Sam", "Alex", false), ("Alex", "Sam", false), ("Sam", "Sparky", true)
        ]
        for (index, result) in results.enumerated() where store.scoreboard.records.isEmpty || index > 0 && store.scoreboard.records.count < results.count {
            let computer = result.2
            store.record(GameRecord(id: UUID(), finishedAt: Date(timeIntervalSinceNow: -day * Double(index + 1) - 3_600),
                                    setup: index % 3 == 2 ? .twoColorsEach : .oneColorEach,
                                    players: [result.0, result.1].sorted { a, _ in a == "Alex" || a == "Sam" },
                                    winner: result.0, onePhone: computer, vsComputer: computer))
        }
        guard scene == "-shotGame" || scene == "-shotWin" else { return }

        try? await Task.sleep(for: .milliseconds(600))
        session.startComputerGame(setup: .oneColorEach, playerName: "Alex", level: .hard)
        guard var game = session.game else { return }
        func place(_ color: PlayerColor, _ index: Int, _ position: PawnPosition) {
            if let slot = game.pawns.firstIndex(where: { $0.id == PawnID(color: color, index: index) }) {
                game.pawns[slot].position = position
            }
        }
        func along(_ color: PlayerColor, _ steps: Int) -> PawnPosition { Board.position(atProgress: steps, for: color)! }

        if scene == "-shotGame" {
            place(.red, 0, along(.red, 9))
            place(.red, 1, along(.red, 26))
            place(.red, 2, .homeColumn(3))
            place(.yellow, 0, along(.red, 30))
            place(.yellow, 1, along(.yellow, 12))
            place(.yellow, 2, along(.yellow, 44))
            game.turn.seat = .one
            game.turn.phase = .moving
            game.turn.roll = DiceRoll(first: 6, second: 4)
            game.turn.values = [MoveValue(id: 1, amount: 4, kind: .die)]
            game.turn.nextValueID = 2
            game.version = 30
        } else {
            for index in 0..<4 { place(.red, index, .home) }
            place(.yellow, 0, along(.yellow, 50))
            place(.yellow, 1, .homeColumn(2))
            place(.yellow, 2, along(.yellow, 21))
            game.winner = .one
            game.turn.phase = .finished
            game.version = 90
        }
        session.debugLoad(game)
    }
}
#endif
