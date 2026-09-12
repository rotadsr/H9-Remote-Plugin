// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "H9RemoteCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "H9RemoteCore", targets: ["H9RemoteCore"])
    ],
    targets: [
        .target(name: "H9RemoteCore"),
        .testTarget(name: "H9RemoteCoreTests", dependencies: ["H9RemoteCore"])
    ]
)
