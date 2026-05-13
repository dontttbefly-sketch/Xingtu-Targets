// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StarfieldGoals",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "StarfieldGoalsCore", targets: ["StarfieldGoalsCore"]),
        .executable(name: "StarfieldGoalsCoreChecks", targets: ["StarfieldGoalsCoreChecks"])
    ],
    targets: [
        .target(
            name: "StarfieldGoalsCore",
            path: "Sources/StarfieldGoalsCore"
        ),
        .executableTarget(
            name: "StarfieldGoalsCoreChecks",
            dependencies: ["StarfieldGoalsCore"],
            path: "Checks/StarfieldGoalsCoreChecks"
        )
    ]
)
