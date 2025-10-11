// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftHablare",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftHablare",
            targets: ["SwiftHablare"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/stovak/SwiftFixtureManager.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftHablare",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftHablareTests",
            dependencies: [
                "SwiftHablare",
                .product(name: "SwiftFixtureManager", package: "SwiftFixtureManager")
            ]
        ),
    ]
)
