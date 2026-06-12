import Foundation
@preconcurrency import WhisperKit
import os

public protocol TranscriptionService: AnyObject, Sendable {
    func transcribe(_ pcm: [Float], language: String?) async throws -> String
}

public actor WhisperEngine: TranscriptionService {
    public static let defaultModel = "openai_whisper-small"

    private var modelVariant: String
    private let modelStore: ModelStore
    private var whisperKit: WhisperKit?
    private let log = Logger(subsystem: "de.dreamit.voicy", category: "WhisperEngine")

    public init(modelVariant: String = WhisperEngine.defaultModel, modelStore: ModelStore = .shared) {
        self.modelVariant = modelVariant
        self.modelStore = modelStore
    }

    /// Switches to another model variant. The current model is unloaded;
    /// the next `prepare` (or `transcribe`) downloads/loads the new one.
    public func switchModel(to variant: String) {
        guard variant != modelVariant else { return }
        modelVariant = variant
        whisperKit = nil
        log.info("Switched model variant to \(variant, privacy: .public)")
    }

    /// Loads the model. Must be called once before `transcribe`. Idempotent.
    /// `progress` reports download progress in [0, 1] when the model is not
    /// on disk yet; loading an installed model reports nothing.
    public func prepare(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        if whisperKit != nil { return }
        do {
            try await ensureAndLoad(progress: progress)
        } catch {
            // A model that is on disk but fails to load is almost always a
            // corrupt/incomplete download (e.g. a single missing file inside
            // an .mlmodelc). Wipe the variant and re-download once instead of
            // failing forever on the same broken files.
            log.warning("Model load failed, wiping and re-downloading \(self.modelVariant, privacy: .public): \(error.localizedDescription, privacy: .public)")
            try modelStore.remove(variant: modelVariant)
            try await ensureAndLoad(progress: progress)
        }
    }

    private func ensureAndLoad(progress: (@Sendable (Double) -> Void)?) async throws {
        let modelFolder = try await modelStore.ensureModel(
            variant: modelVariant,
            progress: progress
        )

        let config = WhisperKitConfig(
            model: modelVariant,
            modelFolder: modelFolder.path,
            tokenizerFolder: modelStore.tokenizersRoot,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true
        )

        let kit = try await WhisperKit(config)
        self.whisperKit = kit
        log.info("WhisperKit loaded (\(self.modelVariant, privacy: .public))")
    }

    public func transcribe(_ pcm: [Float], language: String?) async throws -> String {
        if whisperKit == nil {
            try await prepare()
        }
        guard let kit = whisperKit else {
            throw TranscriptionError.notReady
        }
        guard pcm.count > 1600 else {
            // < 100 ms of audio — most likely a misfire.
            throw TranscriptionError.audioTooShort
        }

        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: language,
            temperature: 0.0,
            usePrefillPrompt: true,
            withoutTimestamps: true
        )

        let results = try await kit.transcribe(audioArray: pcm, decodeOptions: options)
        let joined = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        log.info("Transcribed \(pcm.count, privacy: .public) samples → \(joined.count, privacy: .public) chars")
        return joined
    }
}

public enum TranscriptionError: Error, LocalizedError, Sendable {
    case notReady
    case audioTooShort

    public var errorDescription: String? {
        switch self {
        case .notReady: return "Whisper model is not loaded yet."
        case .audioTooShort: return "Recording was too short to transcribe."
        }
    }
}
