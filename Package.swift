// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "CreditCardScanner",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "CreditCardScanner",
            targets: ["CreditCardScanner"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CreditCardScanner",
            dependencies: []
        ),
        .testTarget(
            name: "CreditCardScannerTests",
            dependencies: ["CreditCardScanner"]
        ),
    ]
)