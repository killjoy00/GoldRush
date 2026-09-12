import Foundation
import XCTest
@testable import GoldRushEngine

final class ScoringCatalogParityTests: XCTestCase {
    func testScoringCatalogMatchesSharedSnapshot() throws {
        let expected = try String(contentsOf: snapshotURL(), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let actual = canonicalCatalog()
        XCTAssertEqual(
            expected,
            actual,
            "Scoring catalog drifted from the shared Android/iOS snapshot.\nACTUAL:\n\(actual)"
        )
    }

    private func snapshotURL() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("docs/scoring-catalog.snapshot")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(
                domain: "ScoringCatalogParityTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing shared snapshot at \(url.path)"]
            )
        }
        return url
    }

    private func canonicalCatalog() -> String {
        ScoringCardCatalog.all.map { card in
            let effects = card.effects.map(effectToken).joined(separator: ";")
            return "\(card.id.code)|\(card.name)|\(card.text)|\(effects)"
        }.joined(separator: "\n")
    }

    private func miningToken(_ type: MiningType) -> String {
        switch type {
        case .goldNugget: "goldNugget"
        case .foolsGold: "foolsGold"
        case .goldOre: "goldOre"
        case .shovel: "shovel"
        case .gravel: "gravel"
        case .pan: "pan"
        case .quartz: "quartz"
        case .packMule: "packMule"
        }
    }

    private func setToken(_ kind: SetKind) -> String {
        switch kind {
        case .oreShovel: "oreShovel"
        case .gravelPan: "gravelPan"
        }
    }

    private func countableToken(_ countable: Countable) -> String {
        switch countable {
        case .type(let type): "type(\(miningToken(type)))"
        case .set(let kind): "set(\(setToken(kind)))"
        case .tools: "tools"
        case .totalMiningCards: "totalMiningCards"
        }
    }

    private func listToken(_ types: [MiningType]) -> String {
        types.map(miningToken).joined(separator: ",")
    }

    private func tiersToken(_ tiers: [Tier]) -> String {
        tiers.map {
            let max = $0.maxCount == Int.max ? "MAX" : String($0.maxCount)
            return "\(max):\($0.points)"
        }.joined(separator: ",")
    }

    private func effectToken(_ effect: ScoringEffect) -> String {
        switch effect {
        case .perType(let type, let points):
            "perType(\(miningToken(type)),\(points))"
        case .perTypeBeyond(let type, let threshold, let points):
            "perTypeBeyond(\(miningToken(type)),\(threshold),\(points))"
        case .perTypeCapped(let type, let points, let maxCount):
            "perTypeCapped(\(miningToken(type)),\(points),\(maxCount))"
        case .perSet(let kind, let points):
            "perSet(\(setToken(kind)),\(points))"
        case .perUnmatched(let type, let points):
            "perUnmatched(\(miningToken(type)),\(points))"
        case .perTool(let points):
            "perTool(\(points))"
        case .perToolCapped(let points, let maxCount):
            "perToolCapped(\(points),\(maxCount))"
        case .perToolExcluding(let type, let points):
            "perToolExcluding(\(miningToken(type)),\(points))"
        case .perNthScaling(let type, let schedule, let repeatLast):
            "perNthScaling(\(miningToken(type)),\(schedule.map(String.init).joined(separator: ",")),\(repeatLast ? 1 : 0))"
        case .perNthLinear(let type, let multiplier):
            "perNthLinear(\(miningToken(type)),\(multiplier))"
        case .perTotalMiningCards(let points):
            "perTotalMiningCards(\(points))"
        case .typesHeldAtLeast(let types, let count, let points):
            "typesHeldAtLeast(\(listToken(types)),\(count),\(points))"
        case .bonusIfAtLeast(let countable, let count, let points):
            "bonusIfAtLeast(\(countableToken(countable)),\(count),\(points))"
        case .bonusIfAtMost(let countable, let count, let points):
            "bonusIfAtMost(\(countableToken(countable)),\(count),\(points))"
        case .bonusIfStrictlyMore(let countable, let points):
            "bonusIfStrictlyMore(\(countableToken(countable)),\(points))"
        case .bonusIfExceeds(let type, let other, let margin, let points):
            "bonusIfExceeds(\(miningToken(type)),\(miningToken(other)),\(margin),\(points))"
        case .bonusPerTypeStrictlyMore(let types, let points):
            "bonusPerTypeStrictlyMore(\(listToken(types)),\(points))"
        case .bonusPerTypeWithinMargin(let types, let margin, let points):
            "bonusPerTypeWithinMargin(\(listToken(types)),\(margin),\(points))"
        case .tieredByCount(let countable, let tiers):
            "tieredByCount(\(countableToken(countable)),\(tiersToken(tiers)))"
        }
    }
}
