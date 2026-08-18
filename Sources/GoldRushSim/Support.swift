import Foundation

/// Minimal argument parsing. Hand-rolled because the project takes no
/// third-party dependencies, and a CLI this shape needs perhaps forty lines.
struct Args {
    let subcommand: String
    private var flags: Set<String> = []
    private var values: [String: String] = [:]

    init?(_ argv: [String]) {
        guard argv.count > 1 else { return nil }
        subcommand = argv[1]
        var i = 2
        while i < argv.count {
            let token = argv[i]
            guard token.hasPrefix("--") else { i += 1; continue }
            let key = String(token.dropFirst(2))
            if i + 1 < argv.count, !argv[i + 1].hasPrefix("--") {
                values[key] = argv[i + 1]
                i += 2
            } else {
                flags.insert(key)
                i += 1
            }
        }
    }

    func has(_ key: String) -> Bool { flags.contains(key) || values[key] != nil }
    func string(_ key: String, default fallback: String) -> String { values[key] ?? fallback }
    func int(_ key: String, default fallback: Int) -> Int {
        values[key].flatMap(Int.init) ?? fallback
    }
    func uint64(_ key: String, default fallback: UInt64) -> UInt64 {
        values[key].flatMap(UInt64.init) ?? fallback
    }
    func intList(_ key: String, default fallback: [Int]) -> [Int] {
        guard let raw = values[key] else { return fallback }
        let parsed = raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return parsed.isEmpty ? fallback : parsed
    }
}

/// Streaming mean and standard deviation (Welford), so a hundred thousand games
/// never need to be held in memory at once.
struct Stats: Sendable {
    private(set) var count = 0
    private(set) var mean = 0.0
    private var m2 = 0.0
    private(set) var minimum = Double.infinity
    private(set) var maximum = -Double.infinity

    mutating func add(_ value: Double) {
        count += 1
        let delta = value - mean
        mean += delta / Double(count)
        m2 += delta * (value - mean)
        minimum = Swift.min(minimum, value)
        maximum = Swift.max(maximum, value)
    }

    mutating func add(_ value: Int) { add(Double(value)) }

    var variance: Double { count > 1 ? m2 / Double(count - 1) : 0 }
    var sd: Double { variance.squareRoot() }

    /// Standard error of the mean -- the number that says whether a difference
    /// between two runs is real or noise.
    var standardError: Double { count > 0 ? sd / Double(count).squareRoot() : 0 }

    mutating func merge(_ other: Stats) {
        guard other.count > 0 else { return }
        guard count > 0 else { self = other; return }
        let combined = count + other.count
        let delta = other.mean - mean
        let newMean = (Double(count) * mean + Double(other.count) * other.mean) / Double(combined)
        m2 += other.m2 + delta * delta * Double(count) * Double(other.count) / Double(combined)
        mean = newMean
        count = combined
        minimum = Swift.min(minimum, other.minimum)
        maximum = Swift.max(maximum, other.maximum)
    }
}

func fmt(_ value: Double, _ places: Int = 2) -> String {
    String(format: "%.\(places)f", value)
}

/// 95% confidence half-width for a proportion. Printed alongside every win rate
/// so a reader can tell a real effect from sampling noise without doing the
/// arithmetic themselves.
func winRateCI(rate: Double, n: Int) -> Double {
    guard n > 0 else { return 0 }
    return 1.96 * (rate * (1 - rate) / Double(n)).squareRoot()
}

/// Runs `body` for every index, in parallel, returning results in index order.
///
/// Order matters: each game is seeded from its index, so the results are
/// identical to a serial run regardless of how the work was scheduled. A
/// simulator whose numbers shifted with thread timing would be useless for
/// comparing two rule variants.
/// A write-once slot per index, shared across worker threads.
///
/// `@unchecked Sendable` is justified rather than assumed: `parallelMap` gives
/// each chunk a disjoint index range and every slot is initialised exactly once,
/// so no two threads ever touch the same address and there is no read of a slot
/// before its write. The compiler cannot see that partition, hence the manual
/// vouch.
private struct WriteOnceBuffer<T>: @unchecked Sendable {
    let base: UnsafeMutableBufferPointer<T>
    func write(_ value: T, at index: Int) {
        base.baseAddress!.advanced(by: index).initialize(to: value)
    }
}

/// Runs `body` for every index, in parallel, returning results in index order.
///
/// Order matters: each game is seeded from its index, so the results are
/// identical to a serial run regardless of how the work was scheduled. A
/// simulator whose numbers shifted with thread timing would be useless for
/// comparing two rule variants.
func parallelMap<T: Sendable>(
    count: Int,
    threads: Int,
    _ body: @Sendable @escaping (Int) -> T
) -> [T] {
    guard count > 0 else { return [] }
    guard threads > 1, count > 1 else { return (0..<count).map(body) }

    let storage = UnsafeMutableBufferPointer<T>.allocate(capacity: count)
    defer { storage.deallocate() }
    let shared = WriteOnceBuffer(base: storage)

    let chunkCount = min(threads, count)
    let chunkSize = (count + chunkCount - 1) / chunkCount
    DispatchQueue.concurrentPerform(iterations: chunkCount) { chunk in
        let start = chunk * chunkSize
        let end = min(start + chunkSize, count)
        guard start < end else { return }
        for i in start..<end {
            shared.write(body(i), at: i)
        }
    }
    return Array(storage)
}
