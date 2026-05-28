// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MechanicKeyboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MechanicKeyboard", targets: ["MechanicKeyboard"])
    ],
    targets: [
        .executableTarget(
            name: "MechanicKeyboard",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
