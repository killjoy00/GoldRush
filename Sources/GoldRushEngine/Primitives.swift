public enum PlayerID: UInt8, CaseIterable, Sendable, Codable, Hashable, Comparable {
    case p1 = 0
    case p2 = 1

    public var opponent: PlayerID { self == .p1 ? .p2 : .p1 }
    public var displayName: String { self == .p1 ? "Player 1" : "Player 2" }

    public static func < (lhs: PlayerID, rhs: PlayerID) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum PileID: UInt8, CaseIterable, Sendable, Codable, Hashable {
    case a = 0
    case b = 1

    public var other: PileID { self == .a ? .b : .a }
}

/// Two values keyed by player.
///
/// Used everywhere a `[PlayerID: T]` would be natural. A dictionary would be
/// the obvious choice and is exactly what this engine must avoid: Swift
/// randomises hash seeds per process, so anything derived from dictionary
/// iteration order fails to reproduce across runs. This has a fixed layout and
/// no hashing at all.
public struct PlayerPair<Value: Sendable & Equatable>: Sendable, Equatable {
    public var p1: Value
    public var p2: Value

    public init(p1: Value, p2: Value) {
        self.p1 = p1
        self.p2 = p2
    }

    public init(repeating value: Value) {
        self.p1 = value
        self.p2 = value
    }

    public subscript(player: PlayerID) -> Value {
        get { player == .p1 ? p1 : p2 }
        set { if player == .p1 { p1 = newValue } else { p2 = newValue } }
    }

    /// Always p1 then p2. Never derived from a hashed collection.
    public var ordered: [(player: PlayerID, value: Value)] {
        [(.p1, p1), (.p2, p2)]
    }

    public func map<T>(_ transform: (Value) throws -> T) rethrows -> PlayerPair<T> {
        PlayerPair<T>(p1: try transform(p1), p2: try transform(p2))
    }
}

extension PlayerPair: Hashable where Value: Hashable {}
extension PlayerPair: Codable where Value: Codable {}

/// A set of card identities, as a fixed 128-bit mask.
///
/// This is the observation tracker's storage, and it is a bitset rather than a
/// `Set<CardID>` for two reasons. It iterates in ascending card order on every
/// platform and every run, which `Set` does not; and membership, union and
/// count are branch-free integer work on the simulator's hot path.
///
/// 128 bits covers every deck size the game supports (the largest studied is 84).
public struct CardSet: Sendable, Codable, Equatable, Hashable {
    public private(set) var low: UInt64 = 0
    public private(set) var high: UInt64 = 0

    public static let capacity = 128

    public init() {}

    public init(_ cards: some Sequence<CardID>) {
        for card in cards { insert(card) }
    }

    public mutating func insert(_ card: CardID) {
        let bit = Int(card.rawValue)
        precondition(bit < Self.capacity, "CardSet holds ids 0..<128")
        if bit < 64 { low |= (1 << UInt64(bit)) } else { high |= (1 << UInt64(bit - 64)) }
    }

    public mutating func formUnion(_ other: CardSet) {
        low |= other.low
        high |= other.high
    }

    public func union(_ other: CardSet) -> CardSet {
        var copy = self
        copy.formUnion(other)
        return copy
    }

    public func contains(_ card: CardID) -> Bool {
        let bit = Int(card.rawValue)
        guard bit < Self.capacity else { return false }
        return bit < 64
            ? (low & (1 << UInt64(bit))) != 0
            : (high & (1 << UInt64(bit - 64))) != 0
    }

    public var count: Int { low.nonzeroBitCount + high.nonzeroBitCount }
    public var isEmpty: Bool { low == 0 && high == 0 }

    /// Ascending card order, always.
    public var cards: [CardID] {
        var out: [CardID] = []
        out.reserveCapacity(count)
        var word = low
        while word != 0 {
            let bit = word.trailingZeroBitCount
            out.append(CardID(UInt16(bit)))
            word &= word - 1
        }
        word = high
        while word != 0 {
            let bit = word.trailingZeroBitCount
            out.append(CardID(UInt16(bit + 64)))
            word &= word - 1
        }
        return out
    }
}
