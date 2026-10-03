// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AttendanceMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AttendanceMac",
            targets: ["AttendanceMac"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AttendanceMac",
            dependencies: [],
            path: "Sources/AttendanceMac",
            exclude: [
                "Resources"
            ]
        )
    ]
)
