import Foundation
import WhisperKit
import os

/// Manages on-disk Whisper model storage and downloads.
///
/// Models live in `~/Library/Application Support/Voicy/Models/<variant>/`.
///
/// Concurrent `ensureModel` calls for the same variant (e.g. the coordinator's
/// launch-time Whisper preparation and the onboarding model step) share a
/// single download task. Without this deduplication, two parallel downloads
/// would race in the final `removeItem`/`moveItem` install step: whichever
/// finishes second deletes the freshly installed model of the first and then
/// fails its own move because the source is already gone.
public final class ModelStore: @unchecked Sendable {
    public static let shared = ModelStore()

    private let log = Logger(subsystem: "de.dreamit.voicy", category: "ModelStore")
    private let fileManager = FileManager.default

    /// Protects `inFlightDownloads` and `progressHandlers`.
    private let lock = NSLock()
    /// One shared download/install task per variant.
    private var inFlightDownloads: [String: Task<URL, Error>] = [:]
    /// Progress observers of all concurrent callers, fanned out per variant.
    private var progressHandlers: [String: [UUID: @Sendable (Double) -> Void]] = [:]

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
    /// Concurrent calls for the same variant all await one shared download
    /// task; every caller's `progress` closure receives the shared updates.
    public func ensureModel(
        variant: String,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        if isModelInstalled(variant: variant) {
            log.info("Model \(variant, privacy: .public) already installed")
            return modelFolder(variant: variant)
        }

        let handlerID = UUID()
        let task: Task<URL, Error> = lock.withLock {
            if let progress {
                progressHandlers[variant, default: [:]][handlerID] = progress
            }
            if let running = inFlightDownloads[variant] {
                return running
            }
            let download = Task<URL, Error> {
                defer {
                    self.lock.withLock {
                        _ = self.inFlightDownloads.removeValue(forKey: variant)
                    }
                }
                return try await self.downloadAndInstall(variant: variant)
            }
            inFlightDownloads[variant] = download
            return download
        }
        defer {
            lock.withLock {
                _ = progressHandlers[variant]?.removeValue(forKey: handlerID)
            }
        }
        return try await task.value
    }

    /// Performs the actual download and installs it into the canonical model
    /// folder. Only ever runs inside the shared per-variant task created by
    /// `ensureModel`, so the `removeItem`/`moveItem` sequence cannot race.
    private func downloadAndInstall(variant: String) async throws -> URL {
        let folder = modelFolder(variant: variant)
        if isModelInstalled(variant: variant) {
            log.info("Model \(variant, privacy: .public) already installed")
            return folder
        }

        log.info("Downloading model \(variant, privacy: .public)…")
        let downloaded = try await WhisperKit.download(
            variant: variant,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { [weak self] p in
                self?.notifyProgress(variant: variant, fraction: p.fractionCompleted)
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

    /// Fans a progress update out to every caller currently awaiting the
    /// shared download of `variant`.
    private func notifyProgress(variant: String, fraction: Double) {
        let handlers = lock.withLock {
            progressHandlers[variant].map { Array($0.values) } ?? []
        }
        for handler in handlers {
            handler(fraction)
        }
    }

    public func remove(variant: String) throws {
        let folder = modelFolder(variant: variant)
        if fileManager.fileExists(atPath: folder.path) {
            try fileManager.removeItem(at: folder)
            log.info("Removed model \(variant, privacy: .public)")
        }
    }
}
