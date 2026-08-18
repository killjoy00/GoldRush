import GoldRushEngine

/// View-model layer. Lives in the package rather than the app target so it is
/// compiled and tested on Linux -- on this project the app itself can only be
/// built by CI, so every line moved in here is a line that gets verified.
public enum GoldRushUICoreVersion {
    public static let current = "0.1.0"
}
