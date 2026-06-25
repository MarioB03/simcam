// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimCamHost",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SimCamHost",
            dependencies: ["SimCamHostKit"]
        ),
        .target(name: "SimCamHostKit"),
        .executableTarget(
            name: "SimCamProbe",
            dependencies: ["SimCamHostKit"]
        ),
        .testTarget(
            name: "SimCamHostKitTests",
            dependencies: ["SimCamHostKit"]
        ),
    ]
)
