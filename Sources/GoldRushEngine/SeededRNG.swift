/// Deterministic pseudo-random source.
///
/// SplitMix64. Chosen because the whole algorithm is a handful of integer
/// operations with no lookup tables and no platform-dependent behaviour, so the
/// same seed produces the same stream on Linux, macOS and iOS alike. That
/// portability matters: the simulator's findings are only meaningful if the
/// device reproduces the sequence the simulator explored.
///
/// Determinism rule for the whole engine: never let a `Set` or `Dictionary`
/// iteration order influence state. Swift randomises hash seeds per process, so
/// such an ordering is not reproducible even with an identical RNG stream.
/// Everything sequence-shaped in this package is an `Array`.
public struct SeededRNG: RandomNumberGenerator, Sendable, Equatable, Codable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in `0..<upperBound`, rejection-sampled so the result is
    /// unbiased. `Int.random(in:using:)` would also work, but pinning the
    /// derivation here keeps the stream stable if the stdlib ever changes its
    /// internal algorithm.
    public mutating func next(upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        let bound = UInt64(upperBound)
        let limit = UInt64.max - (UInt64.max % bound)
        var draw = next()
        while draw >= limit { draw = next() }
        return Int(draw % bound)
    }

    /// In-place Fisher-Yates. Deterministic given the seed and the input order.
    public mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, to: 0, by: -1) {
            let j = next(upperBound: i + 1)
            if i != j { items.swapAt(i, j) }
        }
    }

    public func shuffled<T>(_ items: [T]) -> (shuffled: [T], rng: SeededRNG) {
        var copy = items
        var rng = self
        rng.shuffle(&copy)
        return (copy, rng)
    }

    /// Derives an independent stream for game `index`. Used by the simulator so
    /// parallel workers stay reproducible regardless of scheduling order.
    public static func derive(base: UInt64, index: Int) -> SeededRNG {
        var mixer = SeededRNG(seed: base &+ (UInt64(bitPattern: Int64(index)) &* 0x9E37_79B9_7F4A_7C15))
        _ = mixer.next()
        return SeededRNG(seed: mixer.next())
    }
}
