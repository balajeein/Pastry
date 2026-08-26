// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Pastry",
    platforms: [
        .macOS(.v11)
    ],
    targets: [
        .target(
            name: "PastryCore",
            path: "Pastry",
            exclude: ["Resources/Info.plist"]
        ),
        .executableTarget(
            name: "Pastry",
            dependencies: ["PastryCore"],
            path: "PastryApp"
        ),
        .testTarget(
            name: "PastryTests",
            dependencies: ["PastryCore"],
            path: "Tests/PastryTests"
        )
    ]
)
