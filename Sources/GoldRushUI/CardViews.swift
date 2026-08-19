#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

/// One mining card.
///
/// Proper playing-card proportions (5:7) with a framed face, emblem art and a
/// name plate, rather than the small tinted square this used to be. Cards are
/// the thing the player spends the whole game looking at and dragging between
/// piles, so they are worth the space.
public struct MiningCardView: View {
    public let type: MiningType?
    public let faceDown: Bool
    public let selected: Bool
    public let size: CardSize

    public enum CardSize {
        case chip     // dense tallies in the tableau
        case compact  // pile contents while choosing
        case full     // the cards being split

        var width: CGFloat {
            switch self {
            case .chip: 38
            case .compact: 56
            case .full: 76
            }
        }
        var showsName: Bool { self != .chip }
        var corner: CGFloat {
            switch self {
            case .chip: 5
            case .compact: 7
            case .full: 9
            }
        }
    }

    public init(type: MiningType?, faceDown: Bool = false,
                selected: Bool = false, size: CardSize = .full) {
        self.type = type
        self.faceDown = faceDown
        self.selected = selected
        self.size = size
    }

    // Standard card ratio, so a pile of these looks like a pile of cards.
    var height: CGFloat { size.width * 7 / 5 }

    public var body: some View {
        ZStack {
            if faceDown || type == nil {
                back
            } else {
                face(type!)
            }
        }
        .frame(width: size.width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: size.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .strokeBorder(
                    selected ? Theme.goldBright
                             : (faceDown ? Theme.gold.opacity(0.35) : Color.black.opacity(0.45)),
                    lineWidth: selected ? 2.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.45), radius: selected ? 6 : 3, x: 0, y: 2)
    }

    @ViewBuilder
    func face(_ type: MiningType) -> some View {
        ZStack {
            Theme.cardFace(for: type)
            VStack(spacing: 0) {
                MiningArt(type)
                    .padding(.horizontal, size.width * 0.06)
                    .padding(.top, size.width * 0.05)
                if size.showsName {
                    Text(type.shortName.uppercased())
                        .font(.system(size: size == .full ? 8 : 7, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Theme.parchment.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 2)
                        .padding(.bottom, size.width * 0.06)
                }
            }
        }
    }

    @ViewBuilder
    var back: some View {
        ZStack {
            Theme.cardBack
            // A simple prospector's mark, so the back is clearly a back.
            GeometryReader { geo in
                let w = min(geo.size.width, geo.size.height)
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Theme.gold.opacity(0.28), lineWidth: 1)
                        .padding(w * 0.14)
                    Image(systemName: "questionmark")
                        .font(.system(size: w * 0.34, weight: .heavy))
                        .foregroundStyle(Theme.gold.opacity(0.55))
                }
            }
        }
    }
}

/// A scoring card. Shows its rules text, since players need to read it while
/// deciding what to collect.
public struct ScoringCardView: View {
    public let id: ScoringCardID
    public let selected: Bool
    public let dimmed: Bool
    public let points: Int?

    public init(id: ScoringCardID, selected: Bool = false, dimmed: Bool = false, points: Int? = nil) {
        self.id = id
        self.selected = selected
        self.dimmed = dimmed
        self.points = points
    }

    var card: ScoringCard { ScoringCardCatalog[id] }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(id.code)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.dirt)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.gold, in: RoundedRectangle(cornerRadius: 4))
                Text(card.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.parchment)
                Spacer(minLength: 0)
                if let points {
                    Text("\(points)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(points < 0 ? Theme.danger : Theme.goldBright)
                }
            }
            Text(card.text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.parchment.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            Text(card.family.displayName.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.gold.opacity(0.65))
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dirtLight, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(selected ? Theme.goldBright : Color.black.opacity(0.3),
                              lineWidth: selected ? 2 : 1)
        )
        .opacity(dimmed ? 0.45 : 1)
    }
}

/// A per-type tally, used for collections and the unseen pool.
public struct CountsStripView: View {
    public let counts: MiningCounts
    public let title: String
    public let emphasis: Bool

    public init(counts: MiningCounts, title: String, emphasis: Bool = false) {
        self.counts = counts
        self.title = title
        self.emphasis = emphasis
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.gold.opacity(0.8))
            HStack(spacing: 5) {
                ForEach(MiningType.allCases, id: \.rawValue) { type in
                    VStack(spacing: 2) {
                        Image(systemName: Theme.safeSymbol(for: type))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.tint(for: type))
                        Text("\(counts[type])")
                            .font(.system(size: emphasis ? 13 : 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.parchment)
                    }
                    .frame(minWidth: 22)
                }
            }
        }
    }
}
#endif
