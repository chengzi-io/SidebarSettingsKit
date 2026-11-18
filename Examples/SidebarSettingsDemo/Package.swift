// swift-tools-version: 6.2
import PackageDescription

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
            ]
        ),
    ]
)
