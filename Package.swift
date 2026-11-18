// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownViewer",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "MarkdownCore"),
        .executableTarget(name: "MarkdownViewer", dependencies: ["MarkdownCore"]),
        .testTarget(name: "MarkdownCoreTests", dependencies: ["MarkdownCore"]),
    ]
)
