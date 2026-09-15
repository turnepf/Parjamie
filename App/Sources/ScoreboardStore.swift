import Foundation
import Observation
import ParjamieEngine

/// Keeps the scoreboard on this phone, saved as a small JSON file between launches.
@MainActor
@Observable
final class ScoreboardStore {
    private(set) var scoreboard: Scoreboard

    private let fileURL: URL

    init(fileURL: URL = ScoreboardStore.defaultURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder.scoreboard.decode(Scoreboard.self, from: data) {
            scoreboard = saved
        } else {
            scoreboard = Scoreboard()
        }
    }

    func record(_ record: GameRecord) {
        guard scoreboard.add(record) else { return }
        save()
    }

    /// Takes in the other phone's games. Only saves when something was new.
    func merge(_ records: [GameRecord]) {
        let before = scoreboard.records.count
        scoreboard.merge(records)
        if scoreboard.records.count != before { save() }
    }

    private func save() {
        guard let data = try? JSONEncoder.scoreboard.encode(scoreboard) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    nonisolated static var defaultURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("scoreboard.json")
    }
}

private extension JSONEncoder {
    static var scoreboard: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var scoreboard: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
