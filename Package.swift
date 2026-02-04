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
        .package(url: "https://github.com/grantiva/ios-sdk.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "GrantivaUI",
            dependencies: [
                .product(name: "Grantiva", package: "ios-sdk"),
            ]
        ),
        .testTarget(
            name: "GrantivaUITests",
            dependencies: ["GrantivaUI"]
        ),
    ]
)
