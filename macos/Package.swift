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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "FukuraMac",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "FukuraMac",
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "FukuraMacTests", dependencies: ["FukuraMac"], path: "Tests")
    ]
)
