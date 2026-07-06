// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PrefEngine",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "PrefEngine", targets: ["PrefEngine"])
    ],
    targets: [
        .target(name: "PrefEngine", path: "Sources/PrefEngine"),
        .testTarget(name: "PrefEngineTests", dependencies: ["PrefEngine"], path: "Tests/PrefEngineTests")
    ]
)
