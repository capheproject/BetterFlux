// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BetterFlux",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "BetterFlux", path: "Sources/BetterFlux", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
