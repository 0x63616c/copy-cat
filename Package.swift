// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CopyCat",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
    ],
    targets: [
        .target(name: "CopyCatCore"),
        .target(name: "CopyCatKit", dependencies: ["CopyCatCore"]),
        .executableTarget(name: "CopyCat", dependencies: ["CopyCatKit"]),
        .testTarget(name: "CopyCatCoreTests", dependencies: ["CopyCatCore"]),
        .testTarget(
            name: "CopyCatKitTests",
            dependencies: ["CopyCatKit", "ViewInspector"]
        ),
    ]
)
