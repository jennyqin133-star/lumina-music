// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LuminaMusic",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "LuminaMusic", targets: ["LuminaMusic"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "LuminaMusic",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/LuminaMusic",
            exclude: [],
            resources: [],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"], .when(configuration: .release)),
                .unsafeFlags(["-parse-as-library"], .when(configuration: .debug)),
            ]
        ),
    ]
)
