/// The six scoring families. Eight cards each, 48 in total.
public enum ScoringFamily: UInt8, CaseIterable, Sendable, Codable, Hashable, Comparable {
    case strike = 0
    case dig = 1
    case sluice = 2
    case vein = 3
    case outfit = 4
    case prospect = 5

    /// Cards per family. `ScoringCardID`'s dense indexing derives from this
    /// rather than hardcoding it in several places, so resizing the catalog
    /// is one edit -- as it was going from six per family to eight.
    public static let cardCount = 8

    public static func < (lhs: ScoringFamily, rhs: ScoringFamily) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var letter: String {
        switch self {
        case .strike: "S"
        case .dig: "D"
        case .sluice: "L"
        case .vein: "V"
        case .outfit: "O"
        case .prospect: "P"
        }
    }

    public var displayName: String {
        switch self {
        case .strike: "Strike"
        case .dig: "Dig"
        case .sluice: "Sluice"
        case .vein: "Vein"
        case .outfit: "Outfit"
        case .prospect: "Prospect"
        }
    }

    /// What this family pays you for, in one phrase. Kept beside the family
    /// itself for the same reason `ScoringCard.text` sits beside its effects:
    /// so the rules the player reads cannot drift away from the rules the
    /// engine actually applies.
    public var rewardSummary: String {
        switch self {
        case .strike: "Gold Nuggets"
        case .dig: "Ore + Shovel sets"
        case .sluice: "Gravel + Pan sets"
        case .vein: "Quartz"
        case .outfit: "Tools"
        case .prospect: "odd angles — junk, breadth, sheer volume"
        }
    }
}

/// Stable identity of a scoring card, e.g. `S1`, `P6`.
public struct ScoringCardID: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
    public let family: ScoringFamily
    public let ordinal: Int  // 1...ScoringFamily.cardCount

    public init(_ family: ScoringFamily, _ ordinal: Int) {
        precondition((1...ScoringFamily.cardCount).contains(ordinal),
                     "scoring card ordinal must be 1...\(ScoringFamily.cardCount)")
        self.family = family
        self.ordinal = ordinal
    }

    /// Dense index, used for deterministic ordering and array keying.
    public var index: Int { Int(family.rawValue) * ScoringFamily.cardCount + (ordinal - 1) }

    public var code: String { "\(family.letter)\(ordinal)" }
    public var description: String { code }

    public static func < (lhs: ScoringCardID, rhs: ScoringCardID) -> Bool {
        lhs.index < rhs.index
    }

    /// Total cards in the catalog: every family, at `ScoringFamily.cardCount` each.
    public static var total: Int { ScoringFamily.allCases.count * ScoringFamily.cardCount }

    public static func at(index: Int) -> ScoringCardID {
        precondition((0..<total).contains(index), "scoring card index must be 0..<\(total)")
        return ScoringCardID(ScoringFamily(rawValue: UInt8(index / ScoringFamily.cardCount))!,
                              index % ScoringFamily.cardCount + 1)
    }
}

/// One scoring card: identity, flavour name, and the rules that pay it out.
public struct ScoringCard: Sendable, Codable, Hashable, Identifiable {
    public let id: ScoringCardID
    public let name: String
    public let effects: [ScoringEffect]
    /// Human-readable rules text, kept beside the data so the UI and the table
    /// cannot drift apart.
    public let text: String

    public init(_ id: ScoringCardID, _ name: String, _ text: String, _ effects: [ScoringEffect]) {
        self.id = id
        self.name = name
        self.text = text
        self.effects = effects
    }

    public var family: ScoringFamily { id.family }
}

/// The scoring deck as a plain data table.
///
/// This table is expected to be re-tuned by the simulator. Every payout is an
/// integer literal in one place; nothing here is behaviour. Adding a mechanic
/// means adding a `ScoringEffect` case, not editing this file's shape.
///
/// Ordinals 7 and 8 in every family were added after the original 36 and
/// screened by the simulator over 100k games apiece before shipping; three
/// of them (D8, P7, P8) were re-tuned on those numbers. See
/// docs/SIM_FINDINGS.md.
public enum ScoringCardCatalog {
    /// The six types P3 treats as "resource types". Tools and junk are excluded:
    /// Fool's Gold should not pay a card that rewards a broad claim, and holding
    /// 4+ Pack Mules would mean holding the entire mule supply.
    public static let broadClaimTypes: [MiningType] = [
        .goldNugget, .goldOre, .shovel, .gravel, .pan, .quartz,
    ]

    public static let all: [ScoringCard] = strike + dig + sluice + vein + outfit + prospect

    // MARK: - STRIKE

    static let strike: [ScoringCard] = [
        ScoringCard(
            ScoringCardID(.strike, 1), "Rich Vein",
            "3 per Gold Nugget",
            [.perType(.goldNugget, points: 3)]
        ),
        ScoringCard(
            ScoringCardID(.strike, 2), "Sure Thing",
            "2 per Gold Nugget; +7 if strictly more Gold Nugget than opponent",
            [
                .perType(.goldNugget, points: 2),
                .bonusIfStrictlyMore(.type(.goldNugget), points: 7),
            ]
        ),
        ScoringCard(
            ScoringCardID(.strike, 3), "Careful Assay",
            "4 per Gold Nugget; -2 per Fool's Gold",
            [
                .perType(.goldNugget, points: 4),
                .perType(.foolsGold, points: -2),
            ]
        ),
        ScoringCard(
            ScoringCardID(.strike, 4), "Bonanza",
            "5 per Gold Nugget beyond your 3rd",
            [.perTypeBeyond(.goldNugget, threshold: 3, points: 5)]
        ),
        ScoringCard(
            ScoringCardID(.strike, 5), "Steady Take",
            "2 per Gold Nugget; 1 per Quartz",
            [
                .perType(.goldNugget, points: 2),
                .perType(.quartz, points: 1),
            ]
        ),
        ScoringCard(
            ScoringCardID(.strike, 6), "Grubstake",
            "5 per Gold Nugget, max 3 counted",
            [.perTypeCapped(.goldNugget, points: 5, maxCount: 3)]
        ),
        ScoringCard(
            ScoringCardID(.strike, 7), "Gold Fever",
            "1 per Gold Nugget; 3 per Fool's Gold",
            [
                .perType(.goldNugget, points: 1),
                .perType(.foolsGold, points: 3),
            ]
        ),
        ScoringCard(
            ScoringCardID(.strike, 8), "Assay Office",
            "4 per Gold Nugget; -8 per Gold Nugget beyond your 6th",
            [
                .perType(.goldNugget, points: 4),
                .perTypeBeyond(.goldNugget, threshold: 6, points: -8),
            ]
        ),
    ]

    // MARK: - DIG

    static let dig: [ScoringCard] = [
        ScoringCard(
            ScoringCardID(.dig, 1), "Pay Streak",
            "4 per Ore+Shovel set",
            [.perSet(.oreShovel, points: 4)]
        ),
        ScoringCard(
            ScoringCardID(.dig, 2), "Hard Rock",
            "3 per Ore+Shovel set; +8 if 4+ sets",
            [
                .perSet(.oreShovel, points: 3),
                .bonusIfAtLeast(.set(.oreShovel), count: 4, points: 8),
            ]
        ),
        ScoringCard(
            ScoringCardID(.dig, 3), "Deep Shaft",
            "5 per Ore+Shovel set; -1 per unmatched Gold Ore",
            [
                .perSet(.oreShovel, points: 5),
                .perUnmatched(.goldOre, points: -1),
            ]
        ),
        ScoringCard(
            ScoringCardID(.dig, 4), "Ore Buyer",
            "2 per Gold Ore; 2 per Shovel (matched or not)",
            [
                .perType(.goldOre, points: 2),
                .perType(.shovel, points: 2),
            ]
        ),
        ScoringCard(
            ScoringCardID(.dig, 5), "Claim Rivalry",
            "3 per Ore+Shovel set; +7 if strictly more sets than opponent",
            [
                .perSet(.oreShovel, points: 3),
                .bonusIfStrictlyMore(.set(.oreShovel), points: 7),
            ]
        ),
        ScoringCard(
            ScoringCardID(.dig, 6), "Muck Out",
            "5 per Ore+Shovel set; -1 per Fool's Gold",
            // Tuned from 6 per set (see docs/SIM_FINDINGS.md §11). D6 and L8
            // Fine Gold were the only two set cards paying the top rate, but
            // L8's penalty (-1 per Gold Nugget) costs a type worth building
            // toward, while D6's (-1 per Fool's Gold) costs nothing a
            // competent player wasn't already avoiding -- won 57.8% at 6.
            [
                .perSet(.oreShovel, points: 5),
                .perType(.foolsGold, points: -1),
            ]
        ),
        ScoringCard(
            ScoringCardID(.dig, 7), "Prospector's Eye",
            "3 per Ore+Shovel set; +3 per unmatched Gold Ore",
            [
                .perSet(.oreShovel, points: 3),
                .perUnmatched(.goldOre, points: 3),
            ]
        ),
        ScoringCard(
            ScoringCardID(.dig, 8), "Union Crew",
            "5 per Ore+Shovel set; -4 per Shovel not in a set (Pack Mules exempt)",
            // Tuned from 4 per set. At 4 this was strictly worse than D1 --
            // identical rate, plus a penalty -- and won 41.9%. The extra point
            // per set pays for the risk without blunting it.
            [
                .perSet(.oreShovel, points: 5),
                .perUnmatched(.shovel, points: -4),
            ]
        ),
    ]

    // MARK: - SLUICE

    static let sluice: [ScoringCard] = [
        ScoringCard(
            ScoringCardID(.sluice, 1), "Wash Plant",
            "4 per Gravel+Pan set; -1 per unmatched Gravel",
            [
                .perSet(.gravelPan, points: 4),
                .perUnmatched(.gravel, points: -1),
            ]
        ),
        ScoringCard(
            ScoringCardID(.sluice, 2), "Long Tom",
            "3 per Gravel+Pan set; +8 if 4+ sets",
            [
                .perSet(.gravelPan, points: 3),
                .bonusIfAtLeast(.set(.gravelPan), count: 4, points: 8),
            ]
        ),
        ScoringCard(
            ScoringCardID(.sluice, 3), "Tailings",
            "2 per Gravel; 2 per Pan (matched or not)",
            [
                .perType(.gravel, points: 2),
                .perType(.pan, points: 2),
            ]
        ),
        ScoringCard(
            ScoringCardID(.sluice, 4), "Riffle Box",
            "5 per Gravel+Pan set; -2 per unmatched Gravel",
            [
                .perSet(.gravelPan, points: 5),
                .perUnmatched(.gravel, points: -2),
            ]
        ),
        ScoringCard(
            ScoringCardID(.sluice, 5), "Downstream Claim",
            "3 per Gravel+Pan set; +7 if strictly more sets than opponent",
            [
                .perSet(.gravelPan, points: 3),
                .bonusIfStrictlyMore(.set(.gravelPan), points: 7),
            ]
        ),
        ScoringCard(
            ScoringCardID(.sluice, 6), "Sluice Rights",
            "4 per Gravel+Pan set; +1 per Pack Mule",
            [
                .perSet(.gravelPan, points: 4),
                .perType(.packMule, points: 1),
            ]
        ),
        ScoringCard(
            ScoringCardID(.sluice, 7), "River Rat",
            "2 per Gravel; 2 per Pan; +8 if Gravel exceeds Pan by 3 or more",
            [
                .perType(.gravel, points: 2),
                .perType(.pan, points: 2),
                .bonusIfExceeds(.gravel, other: .pan, margin: 3, points: 8),
            ]
        ),
        ScoringCard(
            ScoringCardID(.sluice, 8), "Fine Gold",
            "6 per Gravel+Pan set; -1 per Gold Nugget",
            [
                .perSet(.gravelPan, points: 6),
                .perType(.goldNugget, points: -1),
            ]
        ),
    ]

    // MARK: - VEIN

    static let vein: [ScoringCard] = [
        ScoringCard(
            ScoringCardID(.vein, 1), "Crystal Ladder",
            "Nth Quartz scores 3/4/5/6/7; 6th and beyond score 7",
            [.perNthScaling(.quartz, schedule: [3, 4, 5, 6, 7], repeatLast: true)]
        ),
        ScoringCard(
            ScoringCardID(.vein, 2), "Mother Lode",
            "4 per Quartz; +10 if 5+ Quartz",
            [
                .perType(.quartz, points: 4),
                .bonusIfAtLeast(.type(.quartz), count: 5, points: 10),
            ]
        ),
        ScoringCard(
            ScoringCardID(.vein, 3), "Crystal Trade",
            "5 per Quartz; -1 per unmatched Gravel",
            [
                .perType(.quartz, points: 5),
                .perUnmatched(.gravel, points: -1),
            ]
        ),
        ScoringCard(
            ScoringCardID(.vein, 4), "Prism",
            "Nth Quartz scores 2xN",
            [.perNthLinear(.quartz, multiplier: 2)]
        ),
        ScoringCard(
            ScoringCardID(.vein, 5), "Vein Rivalry",
            "3 per Quartz; +9 if strictly more Quartz than opponent",
            [
                .perType(.quartz, points: 3),
                .bonusIfStrictlyMore(.type(.quartz), points: 9),
            ]
        ),
        ScoringCard(
            ScoringCardID(.vein, 6), "Cut and Polish",
            "2 per Quartz; 1 per Tool",
            [
                .perType(.quartz, points: 2),
                .perTool(points: 1),
            ]
        ),
        ScoringCard(
            ScoringCardID(.vein, 7), "Crystal Cache",
            "3 per Quartz; +4 per Quartz beyond your 3rd",
            [
                .perType(.quartz, points: 3),
                .perTypeBeyond(.quartz, threshold: 3, points: 4),
            ]
        ),
        ScoringCard(
            ScoringCardID(.vein, 8), "Lode Miner",
            "6 per Quartz; -2 per Gravel+Pan set",
            [
                .perType(.quartz, points: 6),
                .perSet(.gravelPan, points: -2),
            ]
        ),
    ]

    // MARK: - OUTFIT

    static let outfit: [ScoringCard] = [
        ScoringCard(
            ScoringCardID(.outfit, 1), "Full Outfit",
            "2 per Tool",
            [.perTool(points: 2)]
        ),
        ScoringCard(
            ScoringCardID(.outfit, 2), "Mule Train",
            "5 per Pack Mule; 1 per other Tool",
            [
                .perType(.packMule, points: 5),
                .perToolExcluding(.packMule, points: 1),
            ]
        ),
        ScoringCard(
            ScoringCardID(.outfit, 3), "Well Equipped",
            "3 per Tool, max 6 counted",
            [.perToolCapped(points: 3, maxCount: 6)]
        ),
        ScoringCard(
            ScoringCardID(.outfit, 4), "Sharpened Steel",
            "2 per Shovel; 2 per Pan; +6 if 8+ Tools",
            [
                .perType(.shovel, points: 2),
                .perType(.pan, points: 2),
                .bonusIfAtLeast(.tools, count: 8, points: 6),
            ]
        ),
        ScoringCard(
            ScoringCardID(.outfit, 5), "Supply Line",
            "1 per Tool; +12 if strictly more Tools than opponent",
            [
                .perTool(points: 1),
                .bonusIfStrictlyMore(.tools, points: 12),
            ]
        ),
        ScoringCard(
            ScoringCardID(.outfit, 6), "Camp Store",
            "1 per Tool; 1 per Gold Nugget",
            [
                .perTool(points: 1),
                .perType(.goldNugget, points: 1),
            ]
        ),
        ScoringCard(
            ScoringCardID(.outfit, 7), "Traveling Crew",
            "1 per Tool; +2 per resource type of which you hold 3 or more"
                + " (Gold Nugget, Gold Ore, Gravel, Quartz, Fool's Gold)",
            [
                .perTool(points: 1),
                .typesHeldAtLeast(
                    types: [.goldNugget, .goldOre, .gravel, .quartz, .foolsGold],
                    count: 3, points: 2
                ),
            ]
        ),
        ScoringCard(
            ScoringCardID(.outfit, 8), "Broken Handles",
            "2 per Tool; +8 if you hold 7 or fewer Tools",
            [
                .perTool(points: 2),
                .bonusIfAtMost(.tools, count: 7, points: 8),
            ]
        ),
    ]

    // MARK: - PROSPECT

    static let prospect: [ScoringCard] = [
        ScoringCard(
            ScoringCardID(.prospect, 1), "Pyrite Hoarder",
            "3 per Fool's Gold; +8 if strictly more Fool's Gold than opponent",
            [
                .perType(.foolsGold, points: 3),
                .bonusIfStrictlyMore(.type(.foolsGold), points: 8),
            ]
        ),
        ScoringCard(
            ScoringCardID(.prospect, 2), "Clean Claim",
            "22 if 4 or fewer Fool's Gold; 11 if 5-7; 0 if 8+",
            // Tuned from 20/≤3, 10/4-6 (see docs/SIM_FINDINGS.md). A ~30-card
            // collection expects ~4.2 Fool's Gold by luck alone (10 of 72
            // cards), so the original top band sat just below average and the
            // card mostly paid its flat middle value regardless of play. Moving
            // the band to ≤4 brings the top payout within reach of ordinary
            // dodging, so the card rewards a real decision instead of luck.
            [.tieredByCount(.type(.foolsGold), tiers: [
                Tier(maxCount: 4, points: 22),
                Tier(maxCount: 7, points: 11),
                Tier(maxCount: Int.max, points: 0),
            ])]
        ),
        ScoringCard(
            ScoringCardID(.prospect, 3), "Broad Claim",
            "4 per resource type of which you hold 4+",
            [.typesHeldAtLeast(types: broadClaimTypes, count: 4, points: 4)]
        ),
        ScoringCard(
            ScoringCardID(.prospect, 4), "Two Trades",
            "2 per Ore+Shovel set; 2 per Gravel+Pan set",
            [
                .perSet(.oreShovel, points: 2),
                .perSet(.gravelPan, points: 2),
            ]
        ),
        ScoringCard(
            ScoringCardID(.prospect, 5), "Highgrader",
            "13 for each of Gold Nugget, Quartz, Gold Ore where strictly more than opponent",
            // Tuned from 8 (see docs/SIM_FINDINGS.md). Leading in three
            // independent types at once is close to conjunctive impossibility --
            // a Strike player dominates Gold Nugget, a Vein player dominates
            // Quartz, and this card needs to beat both plus Gold Ore. 8 points
            // per type undervalued that difficulty; 13 pays for it properly.
            [.bonusPerTypeStrictlyMore([.goldNugget, .quartz, .goldOre], points: 13)]
        ),
        ScoringCard(
            ScoringCardID(.prospect, 6), "Volume Play",
            "1 per mining card in collection; -4 per Fool's Gold",
            // Tuned from -3 (see docs/SIM_FINDINGS.md). Every card taken helps
            // this one, so it never competes with the rest of a hand -- there
            // was no real decision attached to holding it. A deeper junk
            // penalty creates one: junk arrives bundled with everything else,
            // so wanting volume and dodging Fool's Gold now pull against each
            // other.
            [
                .perTotalMiningCards(points: 1),
                .perType(.foolsGold, points: -4),
            ]
        ),
        ScoringCard(
            ScoringCardID(.prospect, 7), "Lucky Strike",
            "6 for each: 5+ Gold Nugget, 4+ Quartz,"
                + " 3+ Ore+Shovel sets, 3+ Gravel+Pan sets",
            // Tuned from thresholds of 1 at 5 points. Any ordinary collection
            // cleared all four, so it paid ~20 every game (SD 0.57) with no
            // decision attached, and won 56.9%. Each threshold now scales to
            // how scarce the thing actually is, so all four at once is an
            // achievement rather than a formality.
            [
                .bonusIfAtLeast(.type(.goldNugget), count: 5, points: 6),
                .bonusIfAtLeast(.type(.quartz), count: 4, points: 6),
                .bonusIfAtLeast(.set(.oreShovel), count: 3, points: 6),
                .bonusIfAtLeast(.set(.gravelPan), count: 3, points: 6),
            ]
        ),
        ScoringCard(
            ScoringCardID(.prospect, 8), "Grubstake Partner",
            "7 per resource type where your count and your opponent's are within 2"
                + " (Gold Nugget, Gold Ore, Gravel, Quartz, Fool's Gold)",
            // Tuned from within-1 at 6 points, which won 35.5% -- the worst of
            // all 48. Within-1 turned out to be rare across ~30-card
            // collections, so the card paid the least of any in the deck AND
            // paid for standing level, which is not how anyone wins. The wider
            // band makes parity attainable enough to actually chase.
            [
                .bonusPerTypeWithinMargin(
                    [.goldNugget, .goldOre, .gravel, .quartz, .foolsGold],
                    margin: 2, points: 7
                ),
            ]
        ),
    ]

    /// Indexed 0..<36 by `ScoringCardID.index`. Built once, ordered, no hashing.
    public static let byIndex: [ScoringCard] = {
        var table = all
        table.sort { $0.id.index < $1.id.index }
        return table
    }()

    public static subscript(id: ScoringCardID) -> ScoringCard {
        byIndex[id.index]
    }
}
