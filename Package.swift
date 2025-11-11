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
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "DebugTodo",
            targets: ["DebugTodo"]
        ),
    ],
    targets: [
        .target(
            name: "DebugTodo"
        ),
        .testTarget(
            name: "DebugTodoTests",
            dependencies: ["DebugTodo"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
