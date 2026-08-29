// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JellyfinRemote",
    platforms: [
        .macOS(.v14) // Поддержка macOS 14 Sonoma и macOS 15 Sequoia
    ],
    targets: [
        .executableTarget(
            name: "JellyfinRemote"
        )
    ]
)
