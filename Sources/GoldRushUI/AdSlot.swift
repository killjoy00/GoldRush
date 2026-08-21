#if canImport(SwiftUI)
import SwiftUI

/// Where the app target hands a banner ad to the screens that show one.
///
/// The screens live in this package, which has to keep building on Linux so the
/// engine tests can run -- and the Google Mobile Ads SDK is an iOS-only binary
/// framework. So the package cannot depend on it, and the dependency lives in
/// the app target alone. This is the seam between them: the app fills the slot
/// at launch, and anything that does not (Linux, the test suite, a preview,
/// any future target) simply finds it empty and renders nothing.
///
/// A static rather than an environment value because the only screen that shows
/// an ad is presented in a sheet, and environment propagation into sheets is
/// the kind of thing that works until it quietly doesn't.
@MainActor
public enum AdSlot {
    /// Set once, at launch, by the app target. Nil everywhere else.
    public static var banner: (() -> AnyView)?

    /// The banner, if one has been installed. Nothing at all if not -- an
    /// empty view rather than reserved blank space, so a build without ads
    /// has no hole in the layout where they would have been.
    @ViewBuilder
    public static var bannerView: some View {
        if let banner {
            banner()
        }
    }
}
#endif
