import Foundation
import WhisperKit
import os

/// Manages on-disk Whisper model storage and downloads.
///
/// Models live in `~/Library/Application Support/Voicy/Models/<variant>/`.
public final class ModelStore: @unchecked Sendable {
    public static let shared = ModelStore()

    private let log = Logger(subsystem: "de.dreamit.voicy", category: "ModelStore")
    private let fileManager = FileManager.default

    public init() {}

    public var modelsRoot: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Voicy", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    public func modelFolder(variant: String) -> URL {
        modelsRoot.appendingPathComponent(variant, isDirectory: true)
    }

    public func isModelInstalled(variant: String) -> Bool {
        let folder = modelFolder(variant: variant)
        guard let contents = try? fileManager.contentsOfDirectory(atPath: folder.path) else {
            return false
        }
        // WhisperKit lays out audio_encoder.mlmodelc / text_decoder.mlmodelc next to tokenizer files.
        return contents.contains(where: { $0.hasSuffix(".mlmodelc") })
    }

    /// Ensures the requested variant is on disk, downloading it if missing.
    /// `progress` is invoked on an arbitrary queue with values in [0, 1].
    public func ensureModel(
        variant: String,
        progress: ((Double) -> Void)?
    ) async throws -> URL {
        let folder = modelFolder(variant: variant)
        if isModelInstalled(variant: variant) {
            log.info("Model \(variant, privacy: .public) already installed")
            return folder
        }

        log.info("Downloading model \(variant, privacy: .public)…")
        let downloaded = try await WhisperKit.download(
            variant: variant,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { p in
                progress?(p.fractionCompleted)
            }
        )

        // WhisperKit downloads into a HF-cache style path; mirror it under our models root
        // so `modelFolder(variant:)` is the canonical lookup.
        if downloaded.path != folder.path {
            try? fileManager.removeItem(at: folder)
            try fileManager.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: downloaded, to: folder)
        }
        log.info("Model \(variant, privacy: .public) ready at \(folder.path, privacy: .public)")
        return folder
    }

    public func remove(variant: String) throws {
        let folder = modelFolder(variant: variant)
        if fileManager.fileExists(atPath: folder.path) {
            try fileManager.removeItem(at: folder)
            log.info("Removed model \(variant, privacy: .public)")
        }
    }
}
