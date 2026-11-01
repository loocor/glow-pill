// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GlowPill",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GlowPill", targets: ["GlowPill"])
    ],
    targets: [
        .target(
            name: "GlowPill",
            resources: [.process("GlowPillShader.metal")]),
        .executableTarget(
            name: "GlowPillStudio",
            dependencies: ["GlowPill"]),
        .testTarget(
            name: "GlowPillTests",
            dependencies: ["GlowPill"]),
    ]
)
