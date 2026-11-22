// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FC26Launcher",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FC26Launcher", targets: ["FC26Launcher"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FC26Launcher",
            path: "Sources/FC26Launcher",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        )
    ]
)