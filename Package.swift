// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LimitLens",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LimitLens", targets: ["LimitLens"]),
        .library(name: "LimitLensCore", targets: ["LimitLensCore"])
    ],
    targets: [
        .target(name: "LimitLensCore"),
        .executableTarget(
            name: "LimitLens",
            dependencies: ["LimitLensCore"]
        ),
        .testTarget(
            name: "LimitLensCoreTests",
            dependencies: ["LimitLensCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "LimitLensTests",
            dependencies: ["LimitLens"]
        )
    ]
)
