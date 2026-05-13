// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StarfieldGoals",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "StarfieldGoalsCore", targets: ["StarfieldGoalsCore"]),
        .executable(name: "StarfieldGoals", targets: ["StarfieldGoals"])
    ],
    targets: [
        .target(
            name: "StarfieldGoalsCore",
            path: "StarfieldGoalsCore"
        ),
        .executableTarget(
            name: "StarfieldGoals",
            dependencies: ["StarfieldGoalsCore"],
            path: "StarfieldGoals"
        ),
        .testTarget(
            name: "StarfieldGoalsTests",
            dependencies: ["StarfieldGoalsCore"],
            path: "StarfieldGoalsTests"
        )
    ]
)
