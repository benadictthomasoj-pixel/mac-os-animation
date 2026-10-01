// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SiriEdge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SiriEdge",
            targets: ["SiriEdge"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SiriEdge",
            dependencies: [],
            path: "SiriEdge",
            exclude: [
                "Rendering/EdgeGlow.metal",
                "Resources/Shaders/EdgeGlow.metal",
                "ScreenSaver/ScreenSaverInfo.plist"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SiriEdgeTests",
            dependencies: ["SiriEdge"],
            path: "Tests"
        )
    ]
)
