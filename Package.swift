// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SidebarSettingsKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SidebarSettingsKit", targets: ["SidebarSettingsKit"])
    ],
    targets: [
        .target(
            name: "SidebarSettingsKit",
            resources: [.process("Resources")]
        ),
        // Shared test fixtures. Not in any product, so packages that depend on the kit never
        // build it; the demo reuses the same sources through a symlink.
        .target(
            name: "SidebarSettingsFixtures",
            dependencies: ["SidebarSettingsKit"],
            path: "Tests/Fixtures"
        ),
        // Logic tests: no window on screen.
        .testTarget(
            name: "SidebarSettingsKitTests",
            dependencies: ["SidebarSettingsKit", "SidebarSettingsFixtures"]
        ),
        // Tests that open real windows and drive them; they run one at a time.
        .testTarget(
            name: "SidebarSettingsKitWindowTests",
            dependencies: ["SidebarSettingsKit", "SidebarSettingsFixtures"]
        ),
    ]
)
