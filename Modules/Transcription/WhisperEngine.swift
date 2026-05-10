import Foundation
@preconcurrency import WhisperKit
import os

public protocol TranscriptionService: AnyObject {
    func transcribe(_ pcm: [Float], language: String?) async throws -> String
    var isReady: Bool { get }
}

public actor WhisperEngine: TranscriptionService {
    public static let defaultModel = "openai_whisper-small"

    private let modelVariant: String
    private let modelStore: ModelStore
    private var whisperKit: WhisperKit?
    private let log = Logger(subsystem: "de.dreamit.voicy", category: "WhisperEngine")

    public init(modelVariant: String = WhisperEngine.defaultModel, modelStore: ModelStore = .shared) {
        self.modelVariant = modelVariant
        self.modelStore = modelStore
    }

    nonisolated public var isReady: Bool {
        // The actor's `whisperKit` is isolated, so this is a best-effort cached flag
        // updated by `prepare`. It's used only for the menu UI dot.
        modelStore.isModelInstalled(variant: modelVariant)
    }

    /// Loads the model. Must be called once before `transcribe`. Idempotent.
    public func prepare() async throws {
        if whisperKit != nil { return }

        let modelFolder = try await modelStore.ensureModel(
            variant: modelVariant,
            progress: nil
        )

        let config = WhisperKitConfig(
            model: modelVariant,
            modelFolder: modelFolder.path,
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
