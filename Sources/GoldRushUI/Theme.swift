#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

public enum Theme {
    // Warmer and deeper than a flat brown: the background is a lit hearth rather
    // than a sheet of mud, which is what makes gold read as gold on top of it.
    public static let dirt = Color(red: 0.086, green: 0.071, blue: 0.059)
    public static let dirtDeep = Color(red: 0.043, green: 0.035, blue: 0.031)
    public static let dirtWarm = Color(red: 0.176, green: 0.129, blue: 0.090)
    public static let dirtLight = Color(red: 0.161, green: 0.133, blue: 0.110)
    public static let ember = Color(red: 0.325, green: 0.212, blue: 0.098)
    public static let gold = Color(red: 0.882, green: 0.686, blue: 0.235)
    public static let goldBright = Color(red: 0.988, green: 0.847, blue: 0.494)
    public static let goldDeep = Color(red: 0.545, green: 0.388, blue: 0.106)
    public static let parchment = Color(red: 0.937, green: 0.910, blue: 0.847)
    public static let danger = Color(red: 0.816, green: 0.353, blue: 0.267)
    public static let sluice = Color(red: 0.361, green: 0.588, blue: 0.667)

    /// The app's ground. A warm radial pool over a dark field, so the screen has
    /// a centre of light instead of being uniformly flat.
    public static var background: some View {
        ZStack {
            dirtDeep
            RadialGradient(
                colors: [dirtWarm.opacity(0.95), dirtDeep.opacity(0.0)],
                center: .init(x: 0.5, y: 0.32), startRadius: 8, endRadius: 460
            )
            LinearGradient(
                colors: [ember.opacity(0.16), .clear],
                startPoint: .top, endPoint: .center
            )
        }
        .ignoresSafeArea()
    }

    /// Face stock for a card. Subtle vertical shading so it reads as a physical
    /// object catching light rather than a flat rectangle.
    public static func cardFace(for type: MiningType?) -> LinearGradient {
        let base = type.map { tint(for: $0) } ?? Color(red: 0.212, green: 0.176, blue: 0.145)
        return LinearGradient(
            colors: [base.opacity(0.30), base.opacity(0.13), Color.black.opacity(0.22)],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// The back of a face-down card: dark, patterned, and obviously not a face.
    public static var cardBack: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.153, green: 0.118, blue: 0.086),
                     Color(red: 0.086, green: 0.067, blue: 0.051)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

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
