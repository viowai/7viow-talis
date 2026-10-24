// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PromptLibraryMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PromptLibraryMac", targets: ["PromptLibraryMac"])
    ],
    targets: [
        .target(
            name: "TalisCore",
            path: "Sources/TalisCore"
        ),
        .executableTarget(
            name: "PromptLibraryMac",
            dependencies: ["TalisCore"],
            path: "Sources/PromptLibraryMac"
        )
    ]
)
