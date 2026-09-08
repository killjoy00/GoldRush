#if canImport(StoreKit) && canImport(SwiftUI) && canImport(UIKit)
import Foundation
import StoreKit
import SwiftUI
import UIKit

/// Asking for a rating, at a moment worth asking at.
///
/// The system caps this at three prompts a year per user and gives no
/// indication whether one was shown, so the only lever that matters is
/// *when* it fires. The rules below spend those few chances on people who
/// have played enough to have an opinion and have just had a good time,
/// rather than on a first launch when nobody has anything to say.
enum RatingsPrompt {
    private static let askedVersionKey = "goldrush.ratingsPrompt.askedVersion"

    /// Games finished before it is reasonable to ask anyone anything.
    private static let minimumGames = 3

    /// Called after a finished game has been recorded.
    ///
    /// Three gates, in the order they are cheapest to check:
    ///
    /// - The player won. Asking someone to rate the app straight after
    ///   beating them is asking for the review that loss deserves.
    /// - They have finished `minimumGames`. One game is not an opinion.
    /// - This app version has not already asked. The system's own cap is
    ///   invisible to us, so this keeps a player who reinstalls or plays a
    ///   lot from meeting the prompt repeatedly for the same release.
    @MainActor
    static func consider(didWin: Bool, stats: CareerStats) {
        guard didWin, stats.games >= minimumGames else { return }

        let version = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: askedVersionKey) != version else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        // Recorded before asking, not after. The call is fire-and-forget and
        // reports nothing back, so a failure that is not recorded would be
        // retried on the very next win.
        defaults.set(version, forKey: askedVersionKey)
        AppStore.requestReview(in: scene)
    }
}
#endif
