// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
    ],
    targets: [
        .target(name: "WebShell", dependencies: ["Durex"]),
        .testTarget(name: "WebShellCoreTests", dependencies: ["WebShell"]),
        .target(
            name: "AnyErase",
            dependencies: ["Logging"]),
        .target(
            name: "Durex",
            dependencies: ["AnyErase"]),
    ]
)
