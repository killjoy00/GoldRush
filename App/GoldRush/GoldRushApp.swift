import SwiftUI
import GoldRushUI

/// The app target is deliberately this thin. Every screen lives in the
/// GoldRushUI package target so CI can typecheck it against the iOS SDK
/// without relying on the Xcode project file being correct -- which matters
/// here because nobody on this project has a Mac to open it on.
@main
struct GoldRushApp: App {
    var body: some Scene {
        WindowGroup {
            NewGameView()
                .preferredColorScheme(.dark)
        }
    }
}
