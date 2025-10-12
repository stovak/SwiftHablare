// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftHablare",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "SwiftHablare",
            targets: ["SwiftHablare"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/intrusive-memory/SwiftFijos.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftHablare"
        ),
        .testTarget(
            name: "SwiftHablareTests",
            dependencies: [
                "SwiftHablare",
                .product(name: "SwiftFijos", package: "SwiftFijos")
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-disable-actor-data-race-checks"])
            ]
        ),
    ]
)
