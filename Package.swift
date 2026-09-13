// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Parjamie",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ParjamieEngine", targets: ["ParjamieEngine"]),
        .library(name: "ParjamieNet", targets: ["ParjamieNet"])
    ],
    targets: [
        .target(name: "ParjamieEngine"),
        .target(name: "ParjamieNet", dependencies: ["ParjamieEngine"]),
        .testTarget(name: "ParjamieNetTests", dependencies: ["ParjamieNet"]),
        .testTarget(name: "ParjamieEngineTests", dependencies: ["ParjamieEngine"])
    ]
)
