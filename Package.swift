// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AerialSwitcher",
    platforms: [
        .macOS(.v26),
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
