// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KillBill",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "KillBill", targets: ["KillBill"])
    ],
    targets: [
        .executableTarget(
            name: "KillBill",
            path: "Sources/KillBill",
            exclude: ["Resources"]
        )
    ]
)
