// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FukuraMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "FukuraMac",
            targets: ["FukuraMac"]
        )
    ],
    targets: [
        .executableTarget(
            name: "FukuraMac",
            path: "FukuraMac"
        )
    ]
)
