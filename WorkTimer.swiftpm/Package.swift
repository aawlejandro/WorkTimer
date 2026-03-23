// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorkTimer",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        // Swift Playgrounds requires an iOSApplication product to identify
        // the executable app target and show the Run button in the editor.
        .iOSApplication(
            name: "WorkTimer",
            targets: ["WorkTimer"],
            bundleIdentifier: "com.worktimer.app",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "WorkTimer",
            path: "Sources"
        )
    ]
)
