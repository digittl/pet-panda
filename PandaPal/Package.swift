// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PandaPal",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PandaPal",
            path: "PandaPal",
            exclude: ["Info.plist"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
