// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = [.define("COMBINE_LINUX", .when(platforms: [.linux]))]

let package = Package(
    name: "WebShell",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(name: "WebShell", targets: ["WebShell"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2"),
        //        .package(url: "https://github.com/0xfeedface1993/OpenCombine.git", from: "0.15.0"),
        .package(url: "https://github.com/cx-org/CombineX.git", from: "0.4.0"),
    ],
    targets: [
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
            name: "AnyErase",
            dependencies: ["Logging", "CombineX"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Durex",
            dependencies: ["AnyErase"],
            swiftSettings: swiftSettings
        ),
    ]
)
