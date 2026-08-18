// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GoldRush",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "GoldRushEngine", targets: ["GoldRushEngine"]),
        .library(name: "GoldRushAgents", targets: ["GoldRushAgents"]),
        .library(name: "GoldRushUICore", targets: ["GoldRushUICore"]),
        .library(name: "GoldRushUI", targets: ["GoldRushUI"]),
        .executable(name: "GoldRushSim", targets: ["GoldRushSim"]),
    ],
    targets: [
        // Pure rules, state and scoring. Zero UIKit/SwiftUI. Fully deterministic.
        .target(
            name: "GoldRushEngine",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Strategy layer. Consumes PlayerView only -- cannot see hidden information.
        .target(
            name: "GoldRushAgents",
            dependencies: ["GoldRushEngine"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // View models, no SwiftUI. Exists so app logic is compilable on Linux.
        .target(
            name: "GoldRushUICore",
            dependencies: ["GoldRushEngine", "GoldRushAgents"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // SwiftUI screens. They live in the package rather than the app target
        // so CI can typecheck them with xcodebuild against an iOS destination,
        // without depending on the hand-written project file being correct.
        // Every file is guarded by `#if canImport(SwiftUI)`, so `swift build`
        // on Linux still succeeds and the engine tests keep running there.
        .target(
            name: "GoldRushUI",
            dependencies: ["GoldRushEngine", "GoldRushAgents", "GoldRushUICore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "GoldRushSim",
            dependencies: ["GoldRushEngine", "GoldRushAgents"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "GoldRushEngineTests",
            dependencies: ["GoldRushEngine", "GoldRushAgents", "GoldRushUICore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
