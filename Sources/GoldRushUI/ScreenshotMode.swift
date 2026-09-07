#if DEBUG
import Foundation

/// Launch-argument switches that put the app into a state worth photographing.
///
/// The whole file is `#if DEBUG`, and every call site is guarded the same way,
/// so none of this exists in a Release binary. That is deliberate rather than
/// tidy-minded: a distributed build must not be able to reach a mode that
/// skips Game Center authentication and hides the ad, however it is launched.
/// Making `isActive` merely return false in Release would leave the code
/// present and only unreachable, which is a weaker promise.
///
/// Why launch arguments rather than a UI test target: the capture only needs
/// the app to *start* somewhere specific, and a launch argument survives
/// layout changes. Synthesised taps go stale the first time a button moves,
/// and a UI test target is a second thing to keep compiling on a project
/// nobody can open in Xcode.
public enum ScreenshotMode {
    public static let launchArgument = "-AppScreenshotMode"
    public static let screenArgument = "-AppScreenshotScreen"

    public static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// The screens worth a store listing, and reachable without inventing
    /// anything.
    ///
    /// Career Stats and the Claim Journal are deliberately absent. Both are
    /// empty until someone has actually played, and the only ways to fill
    /// them are to play a game through in the capture or to write fake
    /// history into UserDefaults. The second puts invented numbers in a store
    /// listing and is not on the table; the first is worth doing but is more
    /// moving parts than the first version of this pipeline should carry.
    public enum Screen: String, CaseIterable, Sendable {
        /// The menu: mode, difficulty, and the three ways to play.
        case home
        /// How to Play.
        case rules
        /// The reference for all 48 scoring cards.
        case compendium
        /// A drafted game, which opens directly into the draft.
        case draft
        /// The remove-ads purchase sheet, for the App Store Connect review
        /// screenshot every in-app purchase has to ship with.
        case removeAds = "removeads"
        /// The core act: a drawn hand being divided into two piles.
        case split
    }

    /// An unrecognised name falls back to `home` rather than trapping. A typo
    /// in a workflow input should cost one wrong screenshot, not a crashed
    /// run that captures nothing at all.
    public static var screen: Screen {
        guard let raw = value(after: screenArgument),
              let screen = Screen(rawValue: raw.lowercased())
        else { return .home }
        return screen
    }

    /// Reads `-Flag value` out of the argument list.
    ///
    /// Done by hand rather than through UserDefaults, which also absorbs
    /// `-key value` pairs: this way the parsing is visible, and a value that
    /// happens to look like another flag cannot be swallowed silently.
    private static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.index(after: index) < arguments.endIndex
        else { return nil }
        let candidate = arguments[arguments.index(after: index)]
        return candidate.hasPrefix("-") ? nil : candidate
    }

    /// A fixed seed, so the same screen photographs identically on every run
    /// and on both device sizes. A random deal would make two captures of the
    /// same screen differ for no reason, and would make the duplicate check in
    /// the workflow meaningless.
    public static let seed: UInt64 = 0x60_1D_2025
}
#endif
