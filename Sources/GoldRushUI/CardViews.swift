#if canImport(SwiftUI)
import SwiftUI
import GoldRushEngine

/// One mining card. `faceDown` renders the back rather than the face, which is
/// how a chooser sees a card the splitter concealed.
public struct MiningCardView: View {
    public let type: MiningType?
    public let faceDown: Bool
    public let selected: Bool
    public let compact: Bool

    public init(type: MiningType?, faceDown: Bool = false, selected: Bool = false, compact: Bool = false) {
        self.type = type
        self.faceDown = faceDown
        self.selected = selected
        self.compact = compact
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(faceDown || type == nil ? Theme.dirtLight : Theme.tint(for: type!).opacity(0.22))
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    selected ? Theme.goldBright : (faceDown ? Theme.gold.opacity(0.5) : Color.black.opacity(0.25)),
                    lineWidth: selected ? 2.5 : 1
                )
            if faceDown || type == nil {
                Image(systemName: "questionmark")
                    .font(.system(size: compact ? 14 : 20, weight: .bold))
                    .foregroundStyle(Theme.gold.opacity(0.75))
            } else {
                VStack(spacing: 3) {
                    Image(systemName: Theme.safeSymbol(for: type!))
                        .font(.system(size: compact ? 14 : 20))
                        .foregroundStyle(Theme.tint(for: type!))
                    if !compact {
                        Text(type!.shortName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.parchment.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(2)
            }
        }
        .frame(width: compact ? 42 : 58, height: compact ? 54 : 74)
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
