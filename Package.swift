// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WiFiGuard",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "WiFiGuard",
            path: "Sources/WiFiGuard",
            resources: [
                .copy("../../Resources/Info.plist")
            ],
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("Network"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
