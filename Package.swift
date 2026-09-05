// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CopyCat",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0"),
    ],
    targets: [
        .target(name: "CopyCatCore"),
        .target(name: "CopyCatKit", dependencies: ["CopyCatCore", .product(name: "Sparkle", package: "Sparkle")]),
        .executableTarget(name: "CopyCat", dependencies: ["CopyCatKit"], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "CopyCatCoreTests", dependencies: ["CopyCatCore"]),
        .testTarget(
            name: "CopyCatKitTests",
            dependencies: ["CopyCatKit", "ViewInspector"]
        ),
    ]
)
