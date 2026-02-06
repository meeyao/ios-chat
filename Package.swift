// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "DankChat",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "DankChatCore",
            targets: ["DankChatCore"]
        ),
        .executable(
            name: "DankChatApp",
            targets: ["DankChatApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.21.5"),
        .package(url: "https://github.com/SDWebImage/SDWebImageWebPCoder.git", from: "0.15.0")
    ],
    targets: [
        .target(
            name: "DankChatCore"
        ),
        .executableTarget(
            name: "DankChatApp",
            dependencies: [
                "DankChatCore",
                .product(name: "SDWebImage", package: "SDWebImage"),
                .product(name: "SDWebImageWebPCoder", package: "SDWebImageWebPCoder")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DankChatCoreTests",
            dependencies: ["DankChatCore"]
        )
    ]
)
