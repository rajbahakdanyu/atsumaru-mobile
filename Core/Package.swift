// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v26)],
    products: [.library(name: "Core", targets: ["Core"])],
    targets: [
        .target(name: "Core", path: "Sources"),
        .testTarget(name: "CoreTests", dependencies: ["Core"], path: "Tests")
    ]
)