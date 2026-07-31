// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "tictactoe",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "tictactoe", targets: ["tictactoe"])
    ],
    targets: [
        .executableTarget(
            name: "tictactoe",
            path: "Sources/MechaKeys",
            resources: [.process("Resources")]
        )
    ]
)
