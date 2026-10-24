import Foundation
import Observation
import UIKit
import ParjamieEngine

/// Keeps the scoreboard on this phone, saved as a small JSON file between launches, with a
/// copy in the player's iCloud so it follows them to a new phone and their other devices.
@MainActor
@Observable
final class ScoreboardStore {
    private(set) var scoreboard: Scoreboard

    private let fileURL: URL
    private let cloud: NSUbiquitousKeyValueStore?

    /// Pass no `cloud` to keep the scoreboard on this device only.
    init(fileURL: URL = ScoreboardStore.defaultURL, cloud: NSUbiquitousKeyValueStore? = .default) {
        self.fileURL = fileURL
        self.cloud = cloud
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder.scoreboard.decode(Scoreboard.self, from: data) {
            scoreboard = saved
        } else {
            scoreboard = Scoreboard()
        }
        guard let cloud else { return }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pullFromCloud() }
        }
        cloud.synchronize()
        pullFromCloud()
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

    /// Takes in games other devices saved to iCloud, and sends up any this one has that its
    /// iCloud copy does not, such as games played before the scoreboard was in iCloud.
    private func pullFromCloud() {
        guard let cloud else { return }
        let before = scoreboard.records.count
        var mine = 0
        for (key, value) in cloud.dictionaryRepresentation where key.hasPrefix(Self.cloudPrefix) {
            guard let data = value as? Data,
                  let saved = try? JSONDecoder.scoreboard.decode(Scoreboard.self, from: data) else { continue }
            if key == Self.cloudKey { mine = saved.records.count }
            scoreboard.merge(saved.records)
        }
        if scoreboard.records.count != before || mine != scoreboard.records.count { save() }
    }

    private func save() {
        guard let data = try? JSONEncoder.scoreboard.encode(scoreboard) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
        saveToCloud(data)
    }

    /// Each device writes only its own copy, so a new phone that has not heard from iCloud
    /// yet can never overwrite the games the old one saved. iCloud holds about 1 MB per
    /// app; past this device's share, its oldest games stay on the device only.
    private func saveToCloud(_ data: Data) {
        guard let cloud, !scoreboard.records.isEmpty else { return }
        var data = data
        var records = scoreboard.records
        while data.count > Self.cloudLimit, !records.isEmpty {
            records.removeLast(records.count / 10 + 1)
            guard let smaller = try? JSONEncoder.scoreboard.encode(Scoreboard(records: records)) else { return }
            data = smaller
        }
        cloud.set(data, forKey: Self.cloudKey)
    }

    private static let cloudPrefix = "scoreboard."
    private static let cloudKey = cloudPrefix + (UIDevice.current.identifierForVendor ?? UUID()).uuidString
    private static let cloudLimit = 250_000

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
