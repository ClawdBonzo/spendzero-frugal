// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpendZero",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SpendZero", targets: ["SpendZero"]),
    ],
    dependencies: [
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "SpendZero",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
            ],
            path: "SpendZero"
        ),
    ]
)
