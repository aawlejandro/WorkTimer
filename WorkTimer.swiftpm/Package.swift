// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorkTimer",
    platforms: [.iOS(.v17)],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources/AppModule"
        )
    ]
)
