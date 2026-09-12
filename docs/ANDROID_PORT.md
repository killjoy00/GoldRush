# Android port

Gold Rush is being ported in-place rather than split into a second repository. The iOS app remains Swift/SwiftUI under `App/` + `Sources/`; Android lives under `Android/` as a Kotlin/Jetpack Compose app. Keeping both clients together makes rules-parity reviews and fixture tests much harder to accidentally drift.

## Architecture decision

The Swift package has excellent logical boundaries, but Swift itself is not the right runtime boundary for Android. The Android client therefore ports the deterministic rules into Kotlin instead of trying to call Swift through JNI or shipping a second native toolchain.

Mapping:

| iOS / shared Swift | Android |
|---|---|
| `GoldRushEngine` | Kotlin engine package (`com.killjoy00.goldrush.engine`) |
| `GoldRushAgents` | Kotlin AI package (next phase) |
| `GoldRushUICore` | Kotlin state/controller layer (next phase) |
| `GoldRushUI` | Jetpack Compose |
| UserDefaults career data | Android DataStore (later) |
| Game Center turn-based | Cross-platform service (later) |
| StoreKit remove-ads purchase | Google Play Billing (later) |
| Google Mobile Ads iOS | Google Mobile Ads Android with a new Android app/ad unit |

The parity contract is behavioral, not source-sharing: identical deck composition, identical SplitMix64 stream, identical deterministic Fisher-Yates shuffle, identical round structure, then identical state transitions and scoring fixtures as those pieces are ported.

## Phase 1 — landed on the Android branch

- Modern Android project using AGP 9.4, Kotlin 2.3.21, Compose BOM 2026.06.00, compile/target SDK 36. Android 17 / API 37 is still a preview SDK as of September 2026, so production CI deliberately stays on the current stable SDK. The September Compose BOM already raises its compileSdk floor to 37, so the June production BOM is intentionally pinned until API 37 is stable.
- Gold Rush visual language recreated in Compose.
- Standard 72-card mining deck ported.
- `GameConfig` round/draw/hidden-card structure ported.
- SplitMix64 and deterministic shuffle ported with hard cross-language fixture values.
- A real pass-and-play split/choose slice: Player 1 divides a seven-card draw, turns one card face down, hands off the phone, and Player 2 chooses a pile without seeing the hidden identity.
- GitHub Actions builds/tests on Linux and publishes an installable debug APK artifact.

This is intentionally labeled a port-in-progress. It proves the build, UI direction, privacy handoff, and deterministic foundation before duplicating the large scoring catalog/state machine.

## Next implementation order

1. Port scoring effects + the 48-card scoring catalog with fixture parity against Swift.
2. Port full `GameState`, `PlayerView`, split validation, persistent hidden information, recaps and final scoring.
3. Port the seven-card paired scoring draft.
4. Port the AI (start with the current full-fidelity inference agent) and career stats.
5. Replace the prototype screens with full game routing while preserving the Compose visual work already here.
6. Add Android AdMob + Google Play Billing remove-ads entitlement.
7. Add Play Console release signing/build pipeline and store metadata/screenshots.
8. Decide online architecture. Game Center cannot provide Android/iOS cross-play; if cross-platform friend play is desired, move turn transport to a small shared backend while keeping the engine client-side.

## Vercel

There is no Gold Rush Vercel project today, and Phase 1 does not create one. Pass-and-play and solo are on-device and should stay that way. Vercel only becomes relevant if Gold Rush replaces Game Center with cross-platform online matches (or later adds a small web companion/admin surface). Avoiding a backend until that feature requires one keeps cost and failure surface down.

## Build

The CI path is authoritative:

```bash
gradle -p Android :app:testDebugUnitTest :app:assembleDebug
```

The workflow uploads `app-debug.apk` as the `gold-rush-android-debug` artifact so the current build can be sideloaded without a Mac or local Android toolchain.
