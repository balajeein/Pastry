// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "Pastry",
    platforms: [
        .macOS(.v11)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4")
    ],
    targets: [
        .target(
            name: "PastryCore",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Pastry",
            exclude: ["Resources/Info.plist"]
        ),
        .executableTarget(
            name: "Pastry",
            dependencies: [
                "PastryCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "PastryApp"
        ),
        .testTarget(
            name: "PastryTests",
            dependencies: ["PastryCore"],
            path: "Tests/PastryTests"
        )
    ]
)
