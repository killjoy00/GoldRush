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
