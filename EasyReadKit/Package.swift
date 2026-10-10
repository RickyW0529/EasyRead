// swift-tools-version: 5.9
// The Swift Package Manager build manifest for EasyReadKit.
//
// EasyReadKit holds EasyRead's pure context-extraction and privacy logic.
// It deliberately depends only on Foundation so it can be built and tested
// with `swift test` on any machine with the Swift toolchain, without Xcode.

import PackageDescription

let package = Package(
    name: "EasyReadKit",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "EasyReadKit",
            targets: ["EasyReadKit"]
        ),
    ],
    targets: [
        .target(
            name: "EasyReadKit"
        ),
        .testTarget(
            name: "EasyReadKitTests",
            dependencies: ["EasyReadKit"]
        ),
    ]
)
