// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-mobile-ad-coordinator",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MobileAdCoordinator",
            targets: ["MobileAdCoordinator"]
        ),
    ],
    targets: [
        .target(
            name: "MobileAdCoordinator",
            dependencies: [],
            path: "Sources/MobileAdCoordinator"
        ),
        .testTarget(
            name: "MobileAdCoordinatorTests",
            dependencies: ["MobileAdCoordinator"],
            path: "Tests/MobileAdCoordinatorTests"
        ),
    ]
)
