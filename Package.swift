// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Spidey",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Spidey",
            path: "Sources/Spidey"
        ),
        .testTarget(
            name: "SpideyTests",
            dependencies: ["Spidey"],
            path: "Tests/SpideyTests"
        ),
    ]
)
