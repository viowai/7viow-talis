// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Talis",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Talis", targets: ["Talis"])
    ],
    targets: [
        .target(
            name: "TalisCore",
            path: "Sources/TalisCore"
        ),
        .executableTarget(
            name: "Talis",
            dependencies: ["TalisCore"],
            path: "Sources/Talis"
        ),
        .testTarget(
            name: "TalisCoreTests",
            dependencies: ["TalisCore"],
            path: "Tests/TalisCoreTests"
        )
    ]
)
