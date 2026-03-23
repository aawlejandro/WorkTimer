// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "WorkTimer",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "WorkTimer",
            targets: ["AppModule"],
            bundleIdentifier: "com.alejandro.WorkTimer",
            displayVersion: "1.0.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .clock),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources/AppModule"
        )
    ]
)
