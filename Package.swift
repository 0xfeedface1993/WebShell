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
    dependencies: [],
    targets: [
        .target(name: "WebShell", dependencies: ["Durex"]),
        .testTarget(name: "WebShellCoreTests", dependencies: ["WebShell"]),
        .target(
            name: "AnyErase",
            dependencies: []),
        .target(
            name: "Durex",
            dependencies: ["AnyErase"]),
    ]
)
