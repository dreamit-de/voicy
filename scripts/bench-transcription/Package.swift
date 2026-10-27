// swift-tools-version: 5.10
import PackageDescription

// Standalone harness that drives the SAME WhisperKit the app uses
// (project.yml pins argmax-oss-swift `from: 1.1.1`) so measured latency/accuracy
// reflect the real transcription path. Run via ./run.sh from this directory.
let package = Package(
    name: "bench-transcription",
    platforms: [.macOS(.v14)],
    dependencies: [
        // WhisperKit's repo was renamed to argmax-oss-swift; the product is
        // still "WhisperKit", but the package identity follows the URL.
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift", from: "1.1.1"),
    ],
    targets: [
        .executableTarget(
            name: "bench-transcription",
            dependencies: [.product(name: "WhisperKit", package: "argmax-oss-swift")]
        ),
    ]
)
