import Foundation

/// Deterministic generator so a game can be replayed exactly from a seed.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Rolls the dice. Only the host owns one of these, which is what keeps the two
/// devices from ever disagreeing about what was rolled.
public struct DiceCup: Sendable {
    private var generator: SeededGenerator

    public init(seed: UInt64 = UInt64.random(in: .min ... .max)) {
        self.generator = SeededGenerator(seed: seed)
    }

    public mutating func roll() -> DiceRoll {
        DiceRoll(
            first: Int.random(in: 1...6, using: &generator),
            second: Int.random(in: 1...6, using: &generator)
        )
    }
}
