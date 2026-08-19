#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

/// Emblem art for the eight mining types.
///
/// Drawn as vector paths rather than shipped as images: the app has no asset
/// pipeline beyond its icon, and vectors stay crisp at every size the card is
/// rendered at, from the 34pt tableau chip to the full split-screen card.
///
/// The coordinates are normalised 0...1 and were designed against a rendered
/// preview before being transcribed here -- nobody on this project has a
/// simulator, so "draw it and hope" was not available.
public struct MiningArt: View {
    public let type: MiningType

    public init(_ type: MiningType) {
        self.type = type
    }

    public var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(Array(Self.layers(for: type).enumerated()), id: \.offset) { _, layer in
                    layer.path(scale: s)
                        .fill(layer.color)
                }
            }
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Shape description

    struct Layer {
        enum Figure {
            case polygon([CGPoint])
            case circle(center: CGPoint, radius: CGFloat)
            case ring(center: CGPoint, radius: CGFloat, width: CGFloat)
        }
        let figures: [Figure]
        let color: Color

        func path(scale: CGFloat) -> Path {
            var path = Path()
            for figure in figures {
                switch figure {
                case .polygon(let points):
                    guard let first = points.first else { continue }
                    path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
                    for point in points.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * scale, y: point.y * scale))
                    }
                    path.closeSubpath()
                case .circle(let center, let radius):
                    path.addEllipse(in: CGRect(
                        x: (center.x - radius) * scale, y: (center.y - radius) * scale,
                        width: radius * 2 * scale, height: radius * 2 * scale))
                case .ring(let center, let radius, let width):
                    path.addEllipse(in: CGRect(
                        x: (center.x - radius) * scale, y: (center.y - radius) * scale,
                        width: radius * 2 * scale, height: radius * 2 * scale))
                    let inner = radius - width
                    path.addEllipse(in: CGRect(
                        x: (center.x - inner) * scale, y: (center.y - inner) * scale,
                        width: inner * 2 * scale, height: inner * 2 * scale))
                }
            }
            return path
        }
    }

    static func p(_ pairs: [(CGFloat, CGFloat)]) -> Layer.Figure {
        .polygon(pairs.map { CGPoint(x: $0.0, y: $0.1) })
    }
    static func c(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Layer.Figure {
        .circle(center: CGPoint(x: x, y: y), radius: r)
    }
    static func r(_ x: CGFloat, _ y: CGFloat, _ rad: CGFloat, _ w: CGFloat) -> Layer.Figure {
        .ring(center: CGPoint(x: x, y: y), radius: rad, width: w)
    }

    // Shared palette, warmer and more saturated than a flat tint would be.
    static let gold = Color(red: 0.910, green: 0.698, blue: 0.227)
    static let goldHi = Color(red: 0.988, green: 0.839, blue: 0.463)
    static let goldDk = Color(red: 0.659, green: 0.471, blue: 0.118)
    static let pyrite = Color(red: 0.588, green: 0.518, blue: 0.290)
    static let pyriteHi = Color(red: 0.729, green: 0.659, blue: 0.408)
    static let pyriteDk = Color(red: 0.478, green: 0.416, blue: 0.227)
    static let rock = Color(red: 0.471, green: 0.408, blue: 0.353)
    static let steel = Color(red: 0.588, green: 0.620, blue: 0.659)
    static let steelHi = Color(red: 0.745, green: 0.776, blue: 0.816)
    static let wood = Color(red: 0.502, green: 0.329, blue: 0.188)
    static let woodHi = Color(red: 0.620, green: 0.431, blue: 0.259)
    static let stone = Color(red: 0.478, green: 0.447, blue: 0.400)
    static let stoneHi = Color(red: 0.588, green: 0.557, blue: 0.502)
    static let water = Color(red: 0.337, green: 0.541, blue: 0.612)
    static let quartz = Color(red: 0.690, green: 0.769, blue: 0.863)
    static let quartzHi = Color(red: 0.863, green: 0.922, blue: 0.973)
    static let quartzDk = Color(red: 0.549, green: 0.635, blue: 0.745)
    static let hide = Color(red: 0.549, green: 0.376, blue: 0.259)
    static let hideDk = Color(red: 0.376, green: 0.251, blue: 0.173)
    static let panDark = Color(red: 0.275, green: 0.235, blue: 0.204)

    static func layers(for type: MiningType) -> [Layer] {
        switch type {
        case .goldNugget:
            return [
                Layer(figures: [p([(0.28,0.58),(0.36,0.38),(0.54,0.32),(0.72,0.42),
                                   (0.76,0.62),(0.60,0.74),(0.38,0.72)]),
                                c(0.66,0.55,0.075), c(0.36,0.62,0.06)], color: gold),
                Layer(figures: [p([(0.36,0.52),(0.44,0.40),(0.56,0.38),
                                   (0.58,0.48),(0.46,0.56)])], color: goldHi),
            ]
        case .foolsGold:
            // Deliberately geometric where the nugget is organic: at a glance the
            // difference in silhouette is what tells them apart.
            return [
                Layer(figures: [p([(0.30,0.46),(0.48,0.56),(0.48,0.74),(0.30,0.64)])], color: pyrite),
                Layer(figures: [p([(0.66,0.46),(0.66,0.64),(0.48,0.74),(0.48,0.56)])], color: pyriteDk),
                Layer(figures: [p([(0.30,0.46),(0.48,0.36),(0.66,0.46),(0.48,0.56)])], color: pyriteHi),
            ]
        case .goldOre:
            return [
                Layer(figures: [p([(0.24,0.62),(0.32,0.40),(0.52,0.32),(0.74,0.42),
                                   (0.78,0.64),(0.56,0.76),(0.32,0.74)])], color: rock),
                Layer(figures: [p([(0.36,0.60),(0.46,0.46),(0.52,0.50),(0.44,0.64)]),
                                p([(0.56,0.66),(0.64,0.52),(0.70,0.56),(0.62,0.68)])], color: gold),
            ]
        case .shovel:
            return [
                Layer(figures: [p([(0.46,0.16),(0.54,0.16),(0.54,0.56),(0.46,0.56)])], color: wood),
                Layer(figures: [p([(0.40,0.12),(0.60,0.12),(0.60,0.20),(0.40,0.20)])], color: woodHi),
                Layer(figures: [p([(0.34,0.54),(0.66,0.54),(0.60,0.80),
                                   (0.50,0.86),(0.40,0.80)])], color: steel),
                Layer(figures: [p([(0.40,0.58),(0.48,0.58),(0.46,0.76),(0.42,0.74)])], color: steelHi),
            ]
        case .gravel:
            return [
                Layer(figures: [c(0.36,0.62,0.10), c(0.58,0.66,0.085), c(0.48,0.44,0.075),
                                c(0.68,0.48,0.06), c(0.28,0.44,0.055)], color: stone),
                Layer(figures: [c(0.335,0.585,0.035), c(0.56,0.635,0.03),
                                c(0.462,0.418,0.026)], color: stoneHi),
            ]
        case .pan:
            return [
                Layer(figures: [c(0.50,0.54,0.245)], color: panDark),
                Layer(figures: [c(0.50,0.56,0.185)], color: water),
                Layer(figures: [r(0.50,0.54,0.30,0.055)], color: steel),
                Layer(figures: [c(0.44,0.58,0.028), c(0.57,0.52,0.022)], color: goldHi),
            ]
        case .quartz:
            return [
                Layer(figures: [p([(0.38,0.44),(0.50,0.80),(0.28,0.60),(0.26,0.42)])], color: quartzDk),
                Layer(figures: [p([(0.62,0.44),(0.50,0.80),(0.72,0.62),(0.74,0.42)])], color: quartz),
                Layer(figures: [p([(0.50,0.16),(0.62,0.44),(0.50,0.80),(0.38,0.44)])], color: quartz),
                Layer(figures: [p([(0.50,0.22),(0.56,0.44),(0.50,0.60),(0.45,0.44)])], color: quartzHi),
            ]
        case .packMule:
            return [
                Layer(figures: [p([(0.28,0.62),(0.34,0.62),(0.33,0.86),(0.28,0.86)]),
                                p([(0.38,0.62),(0.44,0.62),(0.44,0.86),(0.39,0.86)]),
                                p([(0.52,0.62),(0.58,0.62),(0.58,0.84),(0.53,0.84)]),
                                p([(0.60,0.62),(0.66,0.62),(0.67,0.84),(0.62,0.84)]),
                                p([(0.22,0.52),(0.17,0.48),(0.15,0.62),(0.20,0.60)]),
                                p([(0.24,0.50),(0.62,0.48),(0.68,0.54),(0.66,0.66),
                                   (0.30,0.68),(0.22,0.60)]),
                                p([(0.58,0.50),(0.70,0.34),(0.78,0.36),(0.70,0.54)]),
                                p([(0.68,0.30),(0.80,0.28),(0.86,0.38),(0.78,0.44),(0.68,0.42)]),
                                p([(0.70,0.30),(0.68,0.16),(0.75,0.28)]),
                                p([(0.78,0.28),(0.82,0.15),(0.84,0.30)])], color: hide),
                Layer(figures: [p([(0.40,0.40),(0.45,0.40),(0.46,0.68),(0.41,0.68)])], color: hideDk),
                Layer(figures: [p([(0.30,0.42),(0.56,0.40),(0.58,0.50),(0.28,0.52)])], color: goldDk),
                Layer(figures: [p([(0.32,0.43),(0.54,0.415),(0.55,0.455),(0.33,0.47)])], color: gold),
            ]
        }
    }
}
#endif
