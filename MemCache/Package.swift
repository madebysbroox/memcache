// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MemCache",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MemCache",
            path: "Sources/MemCache",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
