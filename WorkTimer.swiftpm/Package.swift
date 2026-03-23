// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorkTimer",
    platforms: [
        .iOS("17.0")
    ],
    targets: [
        .executableTarget(
            name: "WorkTimer",
            path: "Sources"
        )
    ]
)
