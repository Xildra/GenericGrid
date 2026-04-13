// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GenericGrid",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GenericGrid",
            targets: ["GenericGrid"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GenericGrid"
        ),
        .testTarget(
            name: "GenericGridTests",
            dependencies: ["GenericGrid"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
