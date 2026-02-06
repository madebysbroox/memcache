// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MenuBarMeetings",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MenuBarMeetings",
            path: "MenuBarMeetings",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MenuBarMeetingsTests",
            path: "Tests/MenuBarMeetingsTests"
        )
    ]
)
