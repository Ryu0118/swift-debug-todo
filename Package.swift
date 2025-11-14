// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-debug-todo",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
        .macCatalyst(.v17),
    ],
    products: [
        .library(
            name: "DebugTodo",
            targets: ["DebugTodo"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2")
    ],
    targets: [
        .target(
            name: "DebugTodo",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "DebugTodoTests",
            dependencies: ["DebugTodo"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
