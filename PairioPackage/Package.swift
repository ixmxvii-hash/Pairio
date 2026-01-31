// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PairioPackage",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "PairioFeature",
            targets: ["PairioFeature"]
        )
    ],
    targets: [
        .target(
            name: "PairioFeature",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PairioFeatureTests",
            dependencies: ["PairioFeature"]
        )
    ]
)
