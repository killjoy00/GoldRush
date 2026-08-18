#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

public enum Theme {
    public static let dirt = Color(red: 0.13, green: 0.11, blue: 0.09)
    public static let dirtLight = Color(red: 0.20, green: 0.17, blue: 0.14)
    public static let gold = Color(red: 0.85, green: 0.65, blue: 0.22)
    public static let goldBright = Color(red: 0.98, green: 0.80, blue: 0.35)
    public static let parchment = Color(red: 0.93, green: 0.89, blue: 0.81)
    public static let danger = Color(red: 0.78, green: 0.31, blue: 0.24)
    public static let sluice = Color(red: 0.35, green: 0.55, blue: 0.62)

    public static func tint(for type: MiningType) -> Color {
        switch type {
        case .goldNugget: goldBright
        case .foolsGold: Color(red: 0.72, green: 0.62, blue: 0.30)
        case .goldOre: Color(red: 0.80, green: 0.52, blue: 0.28)
        case .shovel: Color(red: 0.55, green: 0.58, blue: 0.62)
        case .gravel: Color(red: 0.58, green: 0.53, blue: 0.47)
        case .pan: sluice
        case .quartz: Color(red: 0.70, green: 0.76, blue: 0.85)
        case .packMule: Color(red: 0.64, green: 0.45, blue: 0.35)
        }
    }

    /// A glyph per type. SF Symbols only -- no bundled art, so the app has no
    /// asset dependencies beyond its icon.
    public static func symbol(for type: MiningType) -> String {
        switch type {
        case .goldNugget: "circle.hexagongrid.fill"
        case .foolsGold: "circle.hexagemgrid"
        case .goldOre: "cube.fill"
        case .shovel: "hammer.fill"
        case .gravel: "circle.grid.3x3.fill"
        case .pan: "frying.pan.fill"
        case .quartz: "diamond.fill"
        case .packMule: "hare.fill"
        }
    }
}

/// Fallback-safe symbol name: `circle.hexagemgrid` is not a real symbol, so
/// Fool's Gold uses a deliberately duller stand-in that definitely exists.
public extension Theme {
    static func safeSymbol(for type: MiningType) -> String {
        type == .foolsGold ? "circle.hexagongrid" : symbol(for: type)
    }
}
#endif
