// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "FieldLineCore", platforms: [.macOS(.v13)],
    products: [.library(name: "FieldLineCore", targets: ["FieldLineCore"])],
    targets: [
        .target(name: "FieldLineCore", path: "FieldLine/Core"),
        .testTarget(name: "FieldLineCoreTests", dependencies: ["FieldLineCore"], path: "Tests/FieldLineCoreTests")
    ]
)
