// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AerialSwitcher",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "AerialSwitcher", targets: ["AerialSwitcher"]),
    ],
    targets: [
        .target(name: "AerialCore"),
        .executableTarget(name: "AerialSwitcher", dependencies: ["AerialCore"]),
        .testTarget(name: "AerialCoreTests", dependencies: ["AerialCore"]),
    ]
)
