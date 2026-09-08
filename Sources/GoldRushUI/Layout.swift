#if canImport(SwiftUI)
import SwiftUI

/// How wide the app lets things get.
///
/// Every screen here was originally written for a single phone-width column,
/// which on a 13-inch iPad produces a "Keep" button a thousand points wide and
/// a wall of empty space beneath it. These three caps are the whole adaptive
/// story: one for a column of prose or controls, one for the board, one for
/// the menu.
///
/// Not called `Layout`: SwiftUI has a protocol by that name and `FlowRow` in
/// this module conforms to it, so a type called `Layout` here shadows the
/// protocol and breaks that conformance.
public enum Widths {
    /// Widest a single column of text or controls is allowed to get.
    ///
    /// A button stretched across an iPad is not easier to hit, only harder to
    /// look at, and prose past roughly this width stops being comfortable to
    /// read. Single-column content is centred inside this instead of filling.
    public static let readable: CGFloat = 620

    /// Widest the in-game board gets before it is centred with margins.
    ///
    /// Wider than `Widths.readable` because the board legitimately wants two
    /// columns -- the game is about comparing two piles, and on an iPad both
    /// should be visible at once rather than one scrolled past the other.
    public static let board: CGFloat = 1040

    /// Widest the two halves of the menu get as a pair.
    public static let menu: CGFloat = 940
}

public extension View {
    /// Cap the width and centre, instead of filling whatever is available.
    ///
    /// Two frames rather than one: the inner limits the content, the outer
    /// takes the full width so the limited content ends up centred in it.
    func centredColumn(maxWidth: CGFloat = Widths.readable) -> some View {
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

public extension View {
    /// Present this sheet at page size rather than iPadOS's small centred form.
    ///
    /// A plain `.sheet` on a 13-inch iPad is a fixed, roughly form-sized panel
    /// floating in the middle of the display, with the blurred menu showing
    /// around it -- so the rules sheet was cut off partway down while most of
    /// the screen sat empty behind it. `.page` sizes the sheet to the display
    /// instead.
    ///
    /// No effect in a compact size class, which is what iPhone always is here,
    /// so this changes iPad only.
    ///
    /// Scoped to iOS because `presentationSizing` needs macOS 15 and this
    /// package still declares macOS 14. `GoldRushUI` is behind
    /// `canImport(SwiftUI)`, which is true on a Mac, so an unguarded call
    /// would break `swift build` there -- something CI would not catch,
    /// since it only builds this module for iOS.
    func pageSheet() -> some View {
        #if os(iOS)
        return presentationSizing(.page)
        #else
        return self
        #endif
    }
}
#endif
