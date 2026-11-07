// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FukuraCore",
    products: [
        .library(name: "FukuraCore", targets: ["FukuraCore"])
    ],
    targets: [
        .target(name: "FukuraCore"),
        .testTarget(
            name: "FukuraCoreTests",
            dependencies: ["FukuraCore"]
        )
    ]
)
