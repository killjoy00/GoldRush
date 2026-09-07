#if canImport(SwiftUI)
import SwiftUI

/// How much room the app has, and what it should do with it.
///
/// Every screen here was originally written for a single phone-width column,
/// which on a 13-inch iPad produces a "Keep" button a thousand points wide and
/// a wall of empty space beneath it. The numbers below are the whole adaptive
/// story: one cap for a column of prose or controls, one cap for the board,
/// and one threshold for when two piles are better side by side than stacked.
public enum Layout {
    /// Widest a single column of text or controls is allowed to get.
    ///
    /// A button stretched across an iPad is not easier to hit, only harder to
    /// look at, and prose past roughly this width stops being comfortable to
    /// read. Single-column content is centred inside this instead of filling.
    public static let readableWidth: CGFloat = 620

    /// Widest the in-game board gets before it is centred with margins.
    ///
    /// Wider than `readableWidth` because the board legitimately wants two
    /// columns -- the game is about comparing two piles, and on an iPad both
    /// should be visible at once rather than one scrolled past the other.
    public static let boardWidth: CGFloat = 1040

    /// Widest the two halves of the menu get as a pair.
    public static let menuWidth: CGFloat = 940
}

public extension View {
    /// Cap the width and centre, instead of filling whatever is available.
    ///
    /// Two frames rather than one: the inner limits the content, the outer
    /// takes the full width so the limited content ends up centred in it.
    func centredColumn(maxWidth: CGFloat = Layout.readableWidth) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

/// Whether the app currently has room for a genuinely wide layout.
///
/// Size class rather than device model or raw width, because it answers the
/// question actually being asked. It is regular on a full-screen iPad in
/// either orientation, and compact in Slide Over or a narrow Split View --
/// which is exactly when the two-column layouts should collapse back to one.
@MainActor
public struct WideLayoutReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    private let content: (Bool) -> Content

    public init(@ViewBuilder content: @escaping (Bool) -> Content) {
        self.content = content
    }

    public var body: some View {
        content(sizeClass == .regular)
    }
}
#endif
