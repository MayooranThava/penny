// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PennyCoreLogic",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PennyCoreLogic", targets: ["PennyCoreLogic"])
    ],
    targets: [
        .target(name: "PennyCoreLogic"),
        .testTarget(name: "PennyCoreLogicTests", dependencies: ["PennyCoreLogic"])
    ]
)
