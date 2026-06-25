// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimCam",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [.library(name: "SimCam", targets: ["SimCam"])],
    targets: [
        .target(name: "SimCam"),
        .testTarget(name: "SimCamTests", dependencies: ["SimCam"]),
    ]
)
