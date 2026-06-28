// swift-tools-version: 5.10
import PackageDescription

// Standalone harness that drives the SAME WhisperKit the app uses
// (project.yml pins `from: 0.9.0`) so measured latency/accuracy reflect the
// real transcription path. Run via ./run.sh from this directory.
let package = Package(
    name: "bench-transcription",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "bench-transcription",
            dependencies: [.product(name: "WhisperKit", package: "WhisperKit")]
        ),
    ]
)
