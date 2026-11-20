// swift-tools-version: 6.2
import Foundation
import PackageDescription

// Linker flags take paths, not paths relative to the package.
let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let infoPlist = "\(packageDirectory)/Sources/SidebarSettingsDemo/Info.plist"

let package = Package(
    name: "SidebarSettingsDemo",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SidebarSettingsDemo", targets: ["SidebarSettingsDemo"])
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        // The kit's shared fixtures, compiled a second time under this name: the demo shows
        // what the unit tests test. Sources/DemoFixtures is a symlink to Tests/Fixtures.
        .target(
            name: "DemoFixtures",
            dependencies: [
                .product(name: "SidebarSettingsKit", package: "SidebarSettingsKit")
            ],
            path: "Sources/DemoFixtures"
        ),
        .executableTarget(
            name: "SidebarSettingsDemo",
            dependencies: [
                "DemoFixtures",
                .product(name: "SidebarSettingsKit", package: "SidebarSettingsKit"),
            ],
            exclude: ["Info.plist"],
            // SwiftPM's bare executable has no app bundle, so its Info.plist is embedded in
            // __TEXT instead. The demo declares every language the kit has, so the kit's own
            // words follow the app's language in each (`-AppleLanguages "(ja)"`). A root
            // package nobody depends on may use unsafeFlags.
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", infoPlist,
                ])
            ]
        ),
    ]
)
