// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let platforms: [PackageDescription.Platform] = [.linux]
//let platforms: [PackageDescription.Platform] = [.macOS]
let swiftSettings: [SwiftSetting] = [.define("COMBINE_LINUX", .when(platforms: platforms))]

let package = Package(
    name: "WebShell",
    platforms: [
        .macOS(.v11),
        .iOS(.v13)
    ],
    products: [
        .library(name: "WebShell", targets: ["WebShell"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/0xfeedface1993/CombineX.git", from: "0.4.1"),
//        .package(url: "https://github.com/adam-zethraeus/swift-async-broadcaster.git", from: "0.0.1"),
        .package(path: "../swift-async-broadcaster")
    ],
    targets: [
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
            name: "WebShell",
            dependencies: ["Durex"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "WebShellCoreTests",
            dependencies: ["WebShell"],
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
    ]
)
