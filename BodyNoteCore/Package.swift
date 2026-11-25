// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BodyNoteCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "BodyNoteCore", targets: ["BodyNoteCore"])],
    targets: [
        .target(name: "BodyNoteCore"),
        .testTarget(name: "BodyNoteCoreTests", dependencies: ["BodyNoteCore"])
    ]
)
