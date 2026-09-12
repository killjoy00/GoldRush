import Testing
@testable import GoldRushEngine

@Suite("Scoring catalog digest")
struct ScoringCatalogDigestTests {
    @Test("Full scoring catalog matches the cross-platform digest")
    func fullScoringCatalogMatchesCrossPlatformDigest() {
        let canonical = ScoringCardCatalog.all
            .sorted { $0.id.index < $1.id.index }
            .map { card in
                [
                    card.id.code,
                    card.effects.map(effect).joined(separator: ","),
                ].joined(separator: "|")
            }
            .joined(separator: "\n")
        let digest = fnv1a64(canonical)
        print("SCORING_CATALOG_DIGEST=\(digest)")

        #expect(digest == "PENDING", "Catalog digest: \(digest)")
    }

    private func effect(_ value: ScoringEffect) -> String {
        switch value {
        case .perType(let type, points: let points):
            "pt:\(miningType(type)):\(points)"
        case .perTypeBeyond(let type, threshold: let threshold, points: let points):
            "ptb:\(miningType(type)):\(threshold):\(points)"
        case .perTypeCapped(let type, points: let points, maxCount: let maxCount):
            "ptc:\(miningType(type)):\(points):\(maxCount)"
        case .perSet(let kind, points: let points):
            "ps:\(setKind(kind)):\(points)"
        case .perUnmatched(let type, points: let points):
            "pu:\(miningType(type)):\(points)"
        case .perTool(points: let points):
            "tool:\(points)"
        case .perToolCapped(points: let points, maxCount: let maxCount):
            "toolc:\(points):\(maxCount)"
        case .perToolExcluding(let excluded, points: let points):
            "toolx:\(miningType(excluded)):\(points)"
        case .perNthScaling(let type, schedule: let schedule, repeatLast: let repeatLast):
            "nth:\(miningType(type)):\(ints(schedule)):\(bool(repeatLast))"
        case .perNthLinear(let type, multiplier: let multiplier):
            "nthl:\(miningType(type)):\(multiplier)"
        case .perTotalMiningCards(points: let points):
            "total:\(points)"
        case .typesHeldAtLeast(types: let types, count: let count, points: let points):
            "types:\(miningTypes(types)):\(count):\(points)"
        case .bonusIfAtLeast(let countable, count: let count, points: let points):
            "min:\(self.countable(countable)):\(count):\(points)"
        case .bonusIfAtMost(let countable, count: let count, points: let points):
            "max:\(self.countable(countable)):\(count):\(points)"
        case .bonusIfStrictlyMore(let countable, points: let points):
            "more:\(self.countable(countable)):\(points)"
        case .bonusIfExceeds(let type, other: let other, margin: let margin, points: let points):
            "exceeds:\(miningType(type)):\(miningType(other)):\(margin):\(points)"
        case .bonusPerTypeStrictlyMore(let types, points: let points):
            "moretypes:\(miningTypes(types)):\(points)"
        case .bonusPerTypeWithinMargin(let types, margin: let margin, points: let points):
            "near:\(miningTypes(types)):\(margin):\(points)"
        case .tieredByCount(let countable, tiers: let tiers):
            "tiers:\(self.countable(countable)):\(tiers.map(tier).joined(separator: "."))"
        }
    }

    private func countable(_ value: Countable) -> String {
        switch value {
        case .type(let type): "t\(miningType(type))"
        case .set(let kind): "s\(setKind(kind))"
        case .tools: "tools"
        case .totalMiningCards: "total"
        }
    }

    private func tier(_ value: Tier) -> String {
        "\(value.maxCount == Int.max ? "INF" : String(value.maxCount)):\(value.points)"
    }

    private func miningType(_ value: MiningType) -> String { String(value.rawValue) }
    private func setKind(_ value: SetKind) -> String { String(value.rawValue) }
    private func miningTypes(_ values: [MiningType]) -> String { values.map(miningType).joined(separator: ".") }
    private func ints(_ values: [Int]) -> String { values.map(String.init).joined(separator: ".") }
    private func bool(_ value: Bool) -> String { value ? "1" : "0" }

    private func fnv1a64(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        let raw = String(hash, radix: 16)
        return String(repeating: "0", count: max(0, 16 - raw.count)) + raw
    }
}