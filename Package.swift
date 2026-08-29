// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JellyfinRemote",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "JellyfinRemote"
        )
    ]
)
