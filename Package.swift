// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CHAuth",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "CHAuth",
            targets: ["CHAuth"]),
        .library(
            name: "CHAuthSupabase",
            targets: ["CHAuthSupabase"]),
    ],
    dependencies: [
        .package(url: "https://github.com/openid/AppAuth-iOS.git", from: "1.7.5"),
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.12.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .target(
            name: "CHAuth",
            dependencies: [
                .product(name: "AppAuth", package: "AppAuth-iOS"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]
        ),
        .target(
            name: "CHAuthSupabase",
            dependencies: [
                "CHAuth",
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
        .testTarget(
            name: "CHAuthTests",
            dependencies: ["CHAuth"]
        ),
        .testTarget(
            name: "CHAuthSupabaseTests",
            dependencies: ["CHAuthSupabase"]
        ),
    ]
)
