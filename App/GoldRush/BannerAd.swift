import SwiftUI
import GoogleMobileAds
import GoldRushUI

/// A standard 320x50 AdMob banner, wrapped for SwiftUI.
///
/// Lives in the app target rather than in the GoldRushUI package because the
/// Google Mobile Ads SDK is an iOS-only binary framework and the package still
/// has to build on Linux for the engine tests. `AdSlot` is the seam.
struct BannerAd: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView()
        view.adSize = AdSizeBanner
        view.adUnitID = adUnitID
        view.rootViewController = Self.hostViewController()
        view.load(Self.request())
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // Nothing to push down: the ad unit never changes, and re-loading on
        // every SwiftUI update would burn impressions for no reason.
    }

    /// Non-personalised, always.
    ///
    /// The app never asks for tracking permission, so on iOS the advertising
    /// identifier comes back zeroed and Google would serve non-personalised
    /// ads regardless. Saying so explicitly means the behaviour does not
    /// depend on inferring it, and it is what the privacy policy claims.
    static func request() -> Request {
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }

    /// AdMob needs a view controller to present a tapped ad's landing page
    /// from. SwiftUI does not hand one out, so this finds the topmost one.
    static func hostViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
