// swift-tools-version:6.0

import PackageDescription

let platforms: [PackageDescription.Platform] = [.linux]
let swiftSettings: [SwiftSetting] = [.define("COMBINE_LINUX", .when(platforms: platforms))]

let package = Package(
    name: "WebShell",
    platforms: [
        .iOS(.v14), .macOS(.v11), .tvOS(.v13), .watchOS(.v6), .visionOS(.v1)
    ],
    products: [
        .library(name: "WebShell", targets: ["WebShell"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/0xfeedface1993/CombineX.git", from: "0.4.1"),
        .package(url: "https://github.com/0xfeedface1993/swift-async-broadcaster.git", from: "0.0.2"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.11.0"),
    ],
    targets: [
        .target(
            name: "WebShell",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: platforms))
            ],
            path: "Sources/WebShellEngine",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WebShellEngineTests",
            dependencies: ["WebShell"],
            path: "Tests/WebShellEngineTests"
        ),
        .target(
            name: "AnyErase",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "CombineX", package: "CombineX", condition: .when(platforms: platforms)),
                .product(name: "AsyncBroadcaster", package: "swift-async-broadcaster")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "hmjs",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Durex",
            dependencies: [
                "AnyErase",
                .product(name: "Crypto", package: "swift-crypto")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "WebShellLegacy",
            dependencies: [
                "Durex",
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .target(name: "hmjs")
            ],
            path: "Sources/WebShell",
            swiftSettings: swiftSettings
        ),
    ]
)
