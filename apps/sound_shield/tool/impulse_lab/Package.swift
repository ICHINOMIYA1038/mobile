// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "impulse_lab",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "impulse_lab", path: "Sources/impulse_lab"),
    ]
)
