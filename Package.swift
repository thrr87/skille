// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Skille",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SkilleControl", targets: ["SkilleControl"]),
        .executable(name: "Skille", targets: ["Skille"]),
    ],
    targets: [
        .target(name: "SkilleControl"),
        .executableTarget(
            name: "Skille",
            dependencies: ["SkilleControl"]
        ),
        .testTarget(
            name: "SkilleControlTests",
            dependencies: ["SkilleControl"]
        ),
    ]
)
