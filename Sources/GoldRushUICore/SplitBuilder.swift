import Observation
import GoldRushEngine

/// Why a split cannot be confirmed yet.
public enum SplitProblem: Sendable, Equatable, Hashable {
    case pileEmpty(PileID)
    case wrongFaceDownCount(required: Int, placed: Int)

    public var message: String {
        switch self {
        case .pileEmpty(let pile):
            "Pile \(pile == .a ? "A" : "B") needs at least one card"
        case .wrongFaceDownCount(let required, let placed):
            placed < required
                ? "Turn \(required - placed) more card\(required - placed == 1 ? "" : "s") face down"
                : "Turn \(placed - required) fewer card\(placed - required == 1 ? "" : "s") face down"
        }
    }
}

/// The in-progress split on the split screen.
///
/// Lives here rather than in the SwiftUI view for a specific reason: on this
/// project the app target can only be compiled by CI, so any logic left in a
/// `View` is logic that never gets tested. Everything with a rule in it belongs
/// on this side of the line.
///
/// Splits are not undoable once confirmed, which is why `problems` is computed
/// continuously and the confirm gate reads `isLegal` rather than trusting the
/// UI to have prevented a bad state.
@Observable
public final class SplitBuilder {
    public let draw: [(id: CardID, type: MiningType)]
    public let requiredFaceDown: Int
    public let round: Int

    public private(set) var pileA: [CardID] = []
    public private(set) var pileB: [CardID] = []
    private var faceDownSet = CardSet()

    public init(view: PlayerView) {
        self.draw = view.currentDraw.compactMap { card in
            guard let type = card.type else { return nil }
            return (card.id, type)
        }
        self.requiredFaceDown = view.config.faceDownCount(round: view.round)
        self.round = view.round
        // Everything starts in pile A; the player divides from there.
        self.pileA = draw.map(\.id)
    }

    /// Test seam: build directly without a live game.
    public init(draw: [(id: CardID, type: MiningType)], requiredFaceDown: Int, round: Int = 1) {
        self.draw = draw
        self.requiredFaceDown = requiredFaceDown
        self.round = round
        self.pileA = draw.map(\.id)
    }

    public func type(of card: CardID) -> MiningType? {
        draw.first { $0.id == card }?.type
    }

    public func pile(_ id: PileID) -> [CardID] {
        id == .a ? pileA : pileB
    }

    public func location(of card: CardID) -> PileID? {
        if pileA.contains(card) { return .a }
        if pileB.contains(card) { return .b }
        return nil
    }

    public func isFaceDown(_ card: CardID) -> Bool {
        faceDownSet.contains(card)
    }

    public var faceDown: [CardID] { faceDownSet.cards }
    public var faceDownCount: Int { faceDownSet.count }

    // MARK: - Editing

    public func move(_ card: CardID, to destination: PileID) {
        guard draw.contains(where: { $0.id == card }) else { return }
        pileA.removeAll { $0 == card }
        pileB.removeAll { $0 == card }
        if destination == .a { pileA.append(card) } else { pileB.append(card) }
    }

    public func toggleFaceDown(_ card: CardID) {
        guard draw.contains(where: { $0.id == card }) else { return }
        if faceDownSet.contains(card) {
            var rebuilt = CardSet()
            for id in faceDownSet.cards where id != card { rebuilt.insert(id) }
            faceDownSet = rebuilt
        } else {
            faceDownSet.insert(card)
        }
    }

    public func reset() {
        pileA = draw.map(\.id)
        pileB = []
        faceDownSet = CardSet()
    }

    // MARK: - Validation

    /// Every reason the split is not yet confirmable, refreshed on each edit so
    /// the screen can show live guidance instead of failing at the gate.
    public var problems: [SplitProblem] {
        var out: [SplitProblem] = []
        if pileA.isEmpty { out.append(.pileEmpty(.a)) }
        if pileB.isEmpty { out.append(.pileEmpty(.b)) }
        if faceDownSet.count != requiredFaceDown {
            out.append(.wrongFaceDownCount(required: requiredFaceDown, placed: faceDownSet.count))
        }
        return out
    }

    public var isLegal: Bool { problems.isEmpty }

    /// The action to submit. `nil` while the split is still illegal, so the
    /// confirm gate cannot fire on an invalid arrangement.
    public var action: Action? {
        guard isLegal else { return nil }
        return .split(pileA: pileA, pileB: pileB, faceDown: faceDownSet.cards)
    }

    // MARK: - Presentation helpers

    /// Per-type tally of a pile's face-up cards -- what the opponent can see.
    public func visibleCounts(_ id: PileID) -> MiningCounts {
        var counts = MiningCounts()
        for card in pile(id) where !faceDownSet.contains(card) {
            if let type = type(of: card) { counts[type] += 1 }
        }
        return counts
    }

    public func faceDownCount(in id: PileID) -> Int {
        pile(id).count { faceDownSet.contains($0) }
    }
}
