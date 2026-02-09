// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoodMirror",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MoodMirror",
            targets: ["MoodMirror"]
        )
    ],
    targets: [
        .target(
            name: "MoodMirror",
            path: "MoodMirror",
            resources: [
                .process("MoodMirror.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "MoodMirrorTests",
            dependencies: ["MoodMirror"],
            path: "MoodMirrorTests"
        )
    ]
)
