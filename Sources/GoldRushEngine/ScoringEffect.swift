/// The two kinds of matched pair in the game. Sets match 1:1.
public enum SetKind: UInt8, Sendable, Codable, Hashable, CaseIterable {
    case oreShovel = 0
    case gravelPan = 1

    /// The resource half of the set -- the part that can be left "unmatched".
    public var resource: MiningType {
        switch self {
        case .oreShovel: .goldOre
        case .gravelPan: .gravel
        }
    }

    /// The tool half. PackMule may substitute for this slot.
    public var tool: MiningType {
        switch self {
        case .oreShovel: .shovel
        case .gravelPan: .pan
        }
    }
}

/// Something a scoring effect can count. Kept separate from `ScoringEffect` so
/// the comparison and threshold effects can share one notion of "how many".
public enum Countable: Sendable, Codable, Hashable {
    case type(MiningType)
    case set(SetKind)
    case tools
    case totalMiningCards
}

/// One band of a step-function payout. `maxCount` is inclusive.
public struct Tier: Sendable, Codable, Hashable {
    public let maxCount: Int
    public let points: Int

    public init(maxCount: Int, points: Int) {
        self.maxCount = maxCount
        self.points = points
    }
}

/// A single scoring rule.
///
/// Deliberately data, not a closure: the catalog is expected to be re-tuned by
/// the simulator, and a table of enum values can be diffed, serialised and
/// mutated by a tuner. A closure could do none of that.
///
/// Two invariants hold across every case:
///  - PackMule never satisfies `perType(.shovel)` or `perType(.pan)`. Those count
///    literal Shovel and Pan cards, matched or not, as the spec requires.
///  - PackMule always contributes exactly 1 to any Tool count, whether or not it
///    was consumed filling a set slot.
public enum ScoringEffect: Sendable, Codable, Hashable {
    /// Flat rate per card of a type. Negative points express a penalty.
    case perType(MiningType, points: Int)

    /// Rate applied only to copies past `threshold` (S4: "beyond your 3rd").
    case perTypeBeyond(MiningType, threshold: Int, points: Int)

    /// Rate applied to at most `maxCount` copies (S6: "max 3 count").
    case perTypeCapped(MiningType, points: Int, maxCount: Int)

    /// Rate per completed set, after PackMule allocation.
    case perSet(SetKind, points: Int)

    /// Rate per card of a type left over once sets are formed. Usually negative.
    case perUnmatched(MiningType, points: Int)

    /// Rate per Tool, where Tool = Shovel | Pan | PackMule.
    case perTool(points: Int)

    /// Rate per Tool, counting at most `maxCount` of them (O3).
    case perToolCapped(points: Int, maxCount: Int)

    /// Rate per Tool that is not of the excluded type (O2: "per other Tool").
    case perToolExcluding(MiningType, points: Int)

    /// The Nth card of a type scores `schedule[N-1]`. When `repeatLast` is set,
    /// copies past the schedule keep scoring its final entry (V1).
    case perNthScaling(MiningType, schedule: [Int], repeatLast: Bool)

    /// The Nth card of a type scores `multiplier * N` (V4).
    case perNthLinear(MiningType, multiplier: Int)

    /// Rate per mining card held, junk included (P6).
    case perTotalMiningCards(points: Int)

    /// Points for each listed type of which at least `count` are held (P3).
    case typesHeldAtLeast(types: [MiningType], count: Int, points: Int)

    /// Flat bonus when a count reaches a threshold.
    case bonusIfAtLeast(Countable, count: Int, points: Int)

    /// Flat bonus when a count is STRICTLY greater than the opponent's.
    /// Ties award nothing to either player.
    case bonusIfStrictlyMore(Countable, points: Int)

    /// Points for each listed type held in strictly greater number than the
    /// opponent (P5).
    case bonusPerTypeStrictlyMore([MiningType], points: Int)

    /// Step function over a count (P2).
    case tieredByCount(Countable, tiers: [Tier])

    /// Whether this effect reads the opponent's board.
    ///
    /// Used to break the D5/L5 circularity: the opponent's set counts are taken
    /// from their own best arrangement computed with these effects switched off,
    /// which makes the comparison well-defined without a fixpoint.
    public var isOpponentRelative: Bool {
        switch self {
        case .bonusIfStrictlyMore, .bonusPerTypeStrictlyMore: true
        default: false
        }
    }
}
