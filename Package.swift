// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Undertone",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "UndertoneApp", targets: ["UndertoneApp"]),
        .executable(name: "undertone", targets: ["undertone"]),
    ],
    // The updater (MIT): checks Undertone's appcast, verifies each download's EdDSA signature, installs and relaunches.
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "UndertoneCore"),
        .executableTarget(
            name: "UndertoneApp",
            dependencies: ["UndertoneCore", .product(name: "Sparkle", package: "Sparkle")]
        ),
        // The command line tool: Contents/Helpers/undertone, linked onto the PATH by the cask.
        .executableTarget(name: "undertone", dependencies: ["UndertoneCore"]),
        .testTarget(name: "UndertoneCoreTests", dependencies: ["UndertoneCore"]),
    ]
)
