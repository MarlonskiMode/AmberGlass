// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AmberGlass",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "GlassKit", path: "Sources/GlassKit"),
        .executableTarget(name: "AmberGlass", dependencies: ["GlassKit"], path: "Sources/AmberGlass"),
    ]
)
