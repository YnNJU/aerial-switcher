// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AerialSwitcher",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "aerial-switcher",
            targets: ["AerialSwitcher"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "AerialSwitcher"
        ),
    ]
)
