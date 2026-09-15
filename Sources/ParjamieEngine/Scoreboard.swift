import Foundation

/// One finished game, as the scoreboard remembers it.
public struct GameRecord: Hashable, Codable, Sendable, Identifiable {
    /// The game's own id, so the same game reported by two phones counts once.
    public let id: UUID
    public let finishedAt: Date
    public let setup: PawnSetup
    /// Player names in seat order.
    public let players: [String]
    public let winner: String
    /// Played by passing one phone back and forth, rather than on two phones.
    public let onePhone: Bool
    /// Played against the computer. Optional so scoreboards saved before it existed load.
    public var vsComputer: Bool?

    public init(id: UUID, finishedAt: Date, setup: PawnSetup, players: [String], winner: String, onePhone: Bool, vsComputer: Bool = false) {
        self.id = id
        self.finishedAt = finishedAt
        self.setup = setup
        self.players = players
        self.winner = winner
        self.onePhone = onePhone
        self.vsComputer = vsComputer
    }

    public var loser: String? {
        players.first { !Scoreboard.sameName($0, winner) }
    }
}

/// Every game the players have finished, newest first.
public struct Scoreboard: Hashable, Codable, Sendable {
    public private(set) var records: [GameRecord]

    public init(records: [GameRecord] = []) {
        self.records = []
        merge(records)
    }

    public struct Standing: Hashable, Sendable {
        public let name: String
        public let wins: Int
        public let played: Int
    }

    /// Adds a finished game. Returns false when it was already recorded.
    @discardableResult
    public mutating func add(_ record: GameRecord) -> Bool {
        guard !records.contains(where: { $0.id == record.id }) else { return false }
        records.append(record)
        records.sort { $0.finishedAt > $1.finishedAt }
        return true
    }

    /// Folds in games the other phone remembers that this one does not.
    public mutating func merge(_ incoming: [GameRecord]) {
        for record in incoming { add(record) }
    }

    /// Wins and games played per person, most wins first. Names match regardless of
    /// capitalization or stray spaces, and show as most recently typed.
    public var standings: [Standing] {
        var byKey: [String: (name: String, wins: Int, played: Int)] = [:]
        // Oldest first, so the newest spelling of a name wins.
        for record in records.reversed() {
            for player in record.players {
                let key = Self.key(player)
                var entry = byKey[key] ?? (name: player, wins: 0, played: 0)
                entry.name = player.trimmingCharacters(in: .whitespacesAndNewlines)
                entry.played += 1
                if Self.sameName(player, record.winner) { entry.wins += 1 }
                byKey[key] = entry
            }
        }
        return byKey.values
            .map { Standing(name: $0.name, wins: $0.wins, played: $0.played) }
            .sorted { ($0.wins, $0.played, $1.name) > ($1.wins, $1.played, $0.name) }
    }

    /// A one-line summary of how two people stand against each other, such as
    /// "Jamie leads 3–2" or "All square at 2–2".
    public func tally(between first: String, and second: String) -> String {
        let games = records.filter { record in
            record.players.contains { Self.sameName($0, first) } && record.players.contains { Self.sameName($0, second) }
        }
        let firstWins = games.filter { Self.sameName($0.winner, first) }.count
        let secondWins = games.filter { Self.sameName($0.winner, second) }.count
        if firstWins == secondWins { return "All square at \(firstWins)–\(secondWins)" }
        return firstWins > secondWins
            ? "\(first) leads \(firstWins)–\(secondWins)"
            : "\(second) leads \(secondWins)–\(firstWins)"
    }

    public static func sameName(_ a: String, _ b: String) -> Bool {
        key(a) == key(b)
    }

    private static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
