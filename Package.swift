// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectSDK",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "ConnectSDK",
            targets: ["ConnectSDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/googlecast/CastSDK-ios", exact: "2.10.4.1"),
    ],
    targets: [
        .target(
            name: "ConnectSDK",
            dependencies: [
                .product(name: "google-cast-sdk", package: "CastSDK-ios"),
            ],
            path: "Sources",
            exclude: ["core/ConnectSDK*Tests/**/*"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("Sources"),
                .define("CONNECT_SDK_VERSION", to: "\"1.6.0\""),
                .define("CONNECT_SDK_ENABLE_LOG")
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("icucore"),
                .unsafeFlags(["-ObjC"]) // Tương đương với OTHER_LDFLAGS = $(inherited) -ObjC
            ]
        ),
        .testTarget(
            name: "ConnectSDKTests",
            dependencies: ["ConnectSDK"],
            path: "Tests"
        ),
    ]
)
