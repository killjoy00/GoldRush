import SwiftUI
import GoogleMobileAds
import GoldRushUI

/// The app target is deliberately this thin. Every screen lives in the
/// GoldRushUI package target so CI can typecheck it against the iOS SDK
/// without relying on the Xcode project file being correct -- which matters
/// here because nobody on this project has a Mac to open it on.
///
/// The one thing that cannot live in the package is the ads SDK: it is an
/// iOS-only binary framework, and the package has to keep building on Linux
/// for the engine tests. So it is started here, and handed to the screens
/// through AdSlot.
@main
struct GoldRushApp: App {
    /// From AdMob. The app ID also has to appear in Info.plist as
    /// GADApplicationIdentifier, or the SDK traps on launch.
    static let bannerAdUnitID = "ca-app-pub-1217971050094766/6345151109"

    init() {
        MobileAds.shared.start()
        AdSlot.banner = {
            AnyView(
                BannerAd(adUnitID: Self.bannerAdUnitID)
                    // The standard banner is exactly this, and reserving it
                    // keeps the rules text from jumping when the ad arrives.
                    .frame(width: 320, height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.35))
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            NewGameView()
                .preferredColorScheme(.dark)
        }
    }
}
