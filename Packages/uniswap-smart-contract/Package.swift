// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UniswapSmartContract",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "UniswapSmartContract",
            targets: ["UniswapSmartContract"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.17.0"),
        .package(url: "https://github.com/argentlabs/web3.swift.git", from: "0.9.0"),
        .package(name: "EVMChain", path: "../evm-chain"),
    ],
    targets: [
        .target(
            name: "UniswapSmartContract",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "web3.swift", package: "web3.swift"),
                .product(name: "EVMChain", package: "EVMChain"),
            ]
        ),
        .testTarget(
            name: "UniswapSmartContractTests",
            dependencies: ["UniswapSmartContract"]
        ),
    ]
)
