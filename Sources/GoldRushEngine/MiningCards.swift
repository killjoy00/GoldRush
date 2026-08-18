/// The eight kinds of card in the mining deck.
///
/// Raw values are stable and are used for deterministic ordering. Never reorder
/// these cases -- golden-hash determinism tests depend on the numbering.
public enum MiningType: UInt8, CaseIterable, Sendable, Codable, Comparable, Hashable {
    case goldNugget = 0
    case foolsGold = 1
    case goldOre = 2
    case shovel = 3
    case gravel = 4
    case pan = 5
    case quartz = 6
    case packMule = 7

    public static func < (lhs: MiningType, rhs: MiningType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Tool = Shovel | Pan | PackMule. A tool consumed by a set still counts as one Tool.
    public var isTool: Bool {
        switch self {
        case .shovel, .pan, .packMule: true
        case .goldNugget, .foolsGold, .goldOre, .gravel, .quartz: false
        }
    }

    public var displayName: String {
        switch self {
        case .goldNugget: "Gold Nugget"
        case .foolsGold: "Fool's Gold"
        case .goldOre: "Gold Ore"
        case .shovel: "Shovel"
        case .gravel: "Gravel"
        case .pan: "Pan"
        case .quartz: "Quartz"
        case .packMule: "Pack Mule"
        }
    }

    /// Short label for dense HUD readouts.
    public var shortName: String {
        switch self {
        case .goldNugget: "Nugget"
        case .foolsGold: "Pyrite"
        case .goldOre: "Ore"
        case .shovel: "Shovel"
        case .gravel: "Gravel"
        case .pan: "Pan"
        case .quartz: "Quartz"
        case .packMule: "Mule"
        }
    }
}

/// Stable identity for one physical card in the mining deck.
public struct CardID: Hashable, Sendable, Codable, Comparable {
    public let rawValue: UInt16

    public init(_ rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static func < (lhs: CardID, rhs: CardID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One physical card: an identity plus its type.
public struct MiningCard: Hashable, Sendable, Codable {
    public let id: CardID
    public let type: MiningType

    public init(id: CardID, type: MiningType) {
        self.id = id
        self.type = type
    }
}

/// A per-type tally. Eight stored properties rather than an array or dictionary:
/// allocation-free (this is the hot path in the simulator) and free of any
/// hash-order dependence.
public struct MiningCounts: Sendable, Equatable, Hashable, Codable {
    public var goldNugget: Int
    public var foolsGold: Int
    public var goldOre: Int
    public var shovel: Int
    public var gravel: Int
    public var pan: Int
    public var quartz: Int
    public var packMule: Int

    public init(
        goldNugget: Int = 0,
        foolsGold: Int = 0,
        goldOre: Int = 0,
        shovel: Int = 0,
        gravel: Int = 0,
        pan: Int = 0,
        quartz: Int = 0,
        packMule: Int = 0
    ) {
        self.goldNugget = goldNugget
        self.foolsGold = foolsGold
        self.goldOre = goldOre
        self.shovel = shovel
        self.gravel = gravel
        self.pan = pan
        self.quartz = quartz
        self.packMule = packMule
    }

    public subscript(type: MiningType) -> Int {
        get {
            switch type {
            case .goldNugget: goldNugget
            case .foolsGold: foolsGold
            case .goldOre: goldOre
            case .shovel: shovel
            case .gravel: gravel
            case .pan: pan
            case .quartz: quartz
            case .packMule: packMule
            }
        }
        set {
            switch type {
            case .goldNugget: goldNugget = newValue
            case .foolsGold: foolsGold = newValue
            case .goldOre: goldOre = newValue
            case .shovel: shovel = newValue
            case .gravel: gravel = newValue
            case .pan: pan = newValue
            case .quartz: quartz = newValue
            case .packMule: packMule = newValue
            }
        }
    }

    /// Every mining card held, junk included.
    public var total: Int {
        goldNugget + foolsGold + goldOre + shovel + gravel + pan + quartz + packMule
    }

    /// Tool = Shovel | Pan | PackMule, regardless of whether it is consumed by a set.
    public var toolCount: Int {
        shovel + pan + packMule
    }

    public mutating func add(_ type: MiningType, _ n: Int = 1) {
        self[type] += n
    }

    public static func counting(_ cards: some Sequence<MiningCard>) -> MiningCounts {
        var counts = MiningCounts()
        for card in cards { counts[card.type] += 1 }
        return counts
    }

    public static func counting(_ types: some Sequence<MiningType>) -> MiningCounts {
        var counts = MiningCounts()
        for type in types { counts[type] += 1 }
        return counts
    }

    public static func - (lhs: MiningCounts, rhs: MiningCounts) -> MiningCounts {
        var out = MiningCounts()
        for type in MiningType.allCases { out[type] = lhs[type] - rhs[type] }
        return out
    }

    public static func + (lhs: MiningCounts, rhs: MiningCounts) -> MiningCounts {
        var out = MiningCounts()
        for type in MiningType.allCases { out[type] = lhs[type] + rhs[type] }
        return out
    }
}

/// Deck composition. The standard deck is exactly 72 cards.
public enum MiningDeck {
    /// Ordered by `MiningType` raw value so deck construction is deterministic.
    public static let standardComposition: [(type: MiningType, count: Int)] = [
        (.goldNugget, 14),
        (.foolsGold, 10),
        (.goldOre, 10),
        (.shovel, 8),
        (.gravel, 10),
        (.pan, 8),
        (.quartz, 8),
        (.packMule, 4),
    ]

    public static let standardSize = 72

    public static var standardCounts: MiningCounts {
        var counts = MiningCounts()
        for entry in standardComposition { counts[entry.type] = entry.count }
        return counts
    }

    /// Builds the ordered, unshuffled deck for a given composition.
    /// Card IDs are assigned in composition order, so a given composition always
    /// produces the same IDs for the same types.
    public static func build(composition: [(type: MiningType, count: Int)]) -> [MiningCard] {
        var cards: [MiningCard] = []
        cards.reserveCapacity(composition.reduce(0) { $0 + $1.count })
        var next: UInt16 = 0
        for entry in composition {
            for _ in 0..<entry.count {
                cards.append(MiningCard(id: CardID(next), type: entry.type))
                next += 1
            }
        }
        return cards
    }

    public static func standardDeck() -> [MiningCard] {
        build(composition: standardComposition)
    }

    /// Scales the standard composition to a different total for `sim deck`.
    ///
    /// Largest-remainder apportionment in pure integer arithmetic. Deliberately
    /// no floating point: this engine's whole value rests on reproducing a state
    /// exactly, and integer math removes any question of rounding differing
    /// between the simulator host and an iPhone. It also keeps the engine free of
    /// a Foundation/libm dependency.
    ///
    /// Each type gets `floor(count * size / 72)`, then the shortfall is handed out
    /// one card at a time in descending order of remainder, ties broken by
    /// `MiningType` raw value. Always hits `size` exactly.
    public static func scaledComposition(to size: Int) -> [(type: MiningType, count: Int)] {
        precondition(size > 0, "deck size must be positive")
        if size == standardSize { return standardComposition }

        var scaled: [(type: MiningType, count: Int, remainder: Int)] = []
        var assigned = 0
        for entry in standardComposition {
            let numerator = entry.count * size
            let floored = numerator / standardSize
            scaled.append((entry.type, floored, numerator % standardSize))
            assigned += floored
        }

        // Total order: remainder descending, then raw value ascending. No tie is
        // left for the sort to break arbitrarily.
        let order = scaled.indices.sorted { lhs, rhs in
            if scaled[lhs].remainder != scaled[rhs].remainder {
                return scaled[lhs].remainder > scaled[rhs].remainder
            }
            return scaled[lhs].type.rawValue < scaled[rhs].type.rawValue
        }

        var shortfall = size - assigned
        var cursor = 0
        while shortfall > 0 {
            scaled[order[cursor % order.count]].count += 1
            shortfall -= 1
            cursor += 1
        }

        return scaled.map { ($0.type, $0.count) }
    }
}
