// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "KKPurchaseManager",
    products: [
        .library(
            name: "KKPurchaseManager",
            targets: ["KKPurchaseManager"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "KKPurchaseManager",
            dependencies: []),
        .testTarget(
            name: "KKPurchaseManagerTests",
            dependencies: ["KKPurchaseManager"]),
    ]
)
