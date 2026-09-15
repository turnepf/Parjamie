import Foundation

/// Optional rule changes the host picks before a game. The defaults are the classic rules.
/// They travel inside `GameState`, so both phones always play by the same ones.
public struct HouseRules: Hashable, Codable, Sendable {

    public enum Entry: String, CaseIterable, Codable, Sendable {
        /// One die showing 5, or both dice adding up to 5.
        case five
        /// One die showing 6, or both dice adding up to 6.
        case six
        /// One die showing 1 or 6, or both dice adding up to 6.
        case oneOrSix
    }

    public enum Home: String, CaseIterable, Codable, Sendable {
        /// Getting home takes an exact count.
        case exact
        /// Overshooting home moves the helmet back by the extra squares.
        case bounce
    }

    public enum ThreeDoubles: String, CaseIterable, Codable, Sendable {
        /// The farthest helmet goes back to its bay and the turn ends.
        case sendBack
        /// The turn ends, but nobody goes back.
        case loseTurn
        /// Keep rolling as long as the doubles come.
        case nothing
    }

    public var entry: Entry = .five
    public var home: Home = .exact
    public var threeDoubles: ThreeDoubles = .sendBack
    /// +20 for a capture.
    public var captureBonus = true
    /// +10 for getting a helmet home.
    public var homeBonus = true
    /// Doubles with every helmet out also give the bottoms of the dice.
    public var doublesUseBottoms = true
    /// Two helmets on a square block everyone.
    public var blockades = true
    /// Each color starts with one helmet already on its start square.
    public var quickStart = false
    /// When a capture is possible, it has to be taken.
    public var mustCapture = false
    /// The purple safe squares move to new places each game.
    public var shuffleSafeSpots = false

    public init() {}

    public static let classic = HouseRules()

    public var isClassic: Bool { self == .classic }

    /// How many rules differ from classic, for the start screen button.
    public var changedCount: Int {
        let classic = HouseRules.classic
        return [
            entry != classic.entry, home != classic.home, threeDoubles != classic.threeDoubles,
            captureBonus != classic.captureBonus, homeBonus != classic.homeBonus,
            doublesUseBottoms != classic.doublesUseBottoms, blockades != classic.blockades,
            quickStart != classic.quickStart, mustCapture != classic.mustCapture,
            shuffleSafeSpots != classic.shuffleSafeSpots
        ].filter { $0 }.count
    }

    /// Die faces that bring a helmet out on their own.
    public var entryFaces: Set<Int> {
        switch entry {
        case .five: [5]
        case .six: [6]
        case .oneOrSix: [1, 6]
        }
    }

    /// What two dice must add up to for a helmet to come out using both.
    public var entryTotal: Int {
        entry == .five ? 5 : 6
    }

    /// "a 5", "a 6" or "a 1 or a 6".
    public var entryShortPhrase: String {
        switch entry {
        case .five: "a 5"
        case .six: "a 6"
        case .oneOrSix: "a 1 or a 6"
        }
    }

    /// The full requirement, such as "a 5: one die showing 5, or both dice adding up to 5".
    public var entryPhrase: String {
        switch entry {
        case .five: "a 5: one die showing 5, or both dice adding up to 5"
        case .six: "a 6: one die showing 6, or both dice adding up to 6"
        case .oneOrSix: "a 1 or a 6: one die showing 1 or 6, or both dice adding up to 6"
        }
    }

    // Rules saved on a phone by an older build may lack newer keys, so every field falls
    // back to its classic value.
    private enum CodingKeys: String, CodingKey {
        case entry, home, threeDoubles, captureBonus, homeBonus, doublesUseBottoms,
             blockades, quickStart, mustCapture, shuffleSafeSpots
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let classic = HouseRules.classic
        entry = try container.decodeIfPresent(Entry.self, forKey: .entry) ?? classic.entry
        home = try container.decodeIfPresent(Home.self, forKey: .home) ?? classic.home
        threeDoubles = try container.decodeIfPresent(ThreeDoubles.self, forKey: .threeDoubles) ?? classic.threeDoubles
        captureBonus = try container.decodeIfPresent(Bool.self, forKey: .captureBonus) ?? classic.captureBonus
        homeBonus = try container.decodeIfPresent(Bool.self, forKey: .homeBonus) ?? classic.homeBonus
        doublesUseBottoms = try container.decodeIfPresent(Bool.self, forKey: .doublesUseBottoms) ?? classic.doublesUseBottoms
        blockades = try container.decodeIfPresent(Bool.self, forKey: .blockades) ?? classic.blockades
        quickStart = try container.decodeIfPresent(Bool.self, forKey: .quickStart) ?? classic.quickStart
        mustCapture = try container.decodeIfPresent(Bool.self, forKey: .mustCapture) ?? classic.mustCapture
        shuffleSafeSpots = try container.decodeIfPresent(Bool.self, forKey: .shuffleSafeSpots) ?? classic.shuffleSafeSpots
    }
}
