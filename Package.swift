// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GrantivaUI",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "GrantivaUI",
            targets: ["GrantivaUI"]
        ),
    ],
    dependencies: [
        .package(path: "../GrantivaSDK"),
    ],
    targets: [
        .target(
            name: "GrantivaUI",
            dependencies: [
                .product(name: "Grantiva", package: "GrantivaSDK"),
            ]
        ),
        .testTarget(
            name: "GrantivaUITests",
            dependencies: ["GrantivaUI"]
        ),
    ]
)
