// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftHablare",
    platforms: [
        .macOS(.v15),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SwiftHablare",
            targets: ["SwiftHablare"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftHablare",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftHablareTests",
            dependencies: ["SwiftHablare"]
        ),
    ]
)
