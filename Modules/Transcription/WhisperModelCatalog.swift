import Foundation

/// One selectable Whisper model with honest expectation copy for the UI.
public struct WhisperModelOption: Identifiable, Equatable, Sendable {
    /// Exact folder name in the argmaxinc/whisperkit-coreml repo.
    public let variant: String
    public let displayName: String
    public let downloadSize: String
    /// What the user should expect: speed, quality, languages.
    public let expectation: String

    public var id: String { variant }
}

/// Curated subset of WhisperKit's CoreML models. Sizes are the actual
/// download volumes from huggingface.co (checked 2026-06-12). The onboarding
/// default (Large v3 Turbo, `_626MB`) was re-validated on 2026-10-27: no
/// other large-v3 build transcribed more accurately (see scripts/bench-results/).
public enum WhisperModelCatalog {
    public static let options: [WhisperModelOption] = [
        WhisperModelOption(
            variant: "openai_whisper-tiny",
            displayName: "Tiny",
            downloadSize: "73 MB",
            expectation: "Quasi sofortige Transkription, aber spürbar mehr Erkennungsfehler — für Deutsch nur bedingt geeignet."
        ),
        WhisperModelOption(
            variant: "openai_whisper-base",
            displayName: "Base",
            downloadSize: "139 MB",
            expectation: "Sehr schnell, solide für kurze englische Diktate. Bei Deutsch und Fachbegriffen merklich schwächer als Small."
        ),
        WhisperModelOption(
            variant: "openai_whisper-small",
            displayName: "Small",
            downloadSize: "463 MB",
            expectation: "Guter Kompromiss: ein Satz ist in etwa einer Sekunde transkribiert, Deutsch wird zuverlässig erkannt."
        ),
        WhisperModelOption(
            variant: "openai_whisper-large-v3-v20240930_626MB",
            displayName: "Large v3 Turbo (Standard)",
            downloadSize: "597 MB",
            expectation: "Beste Erkennung, auch bei Dialekt, Namen und Fachsprache. Transkription dauert etwas länger als Small (~1 s pro Satz auf M4) und braucht mehr Arbeitsspeicher."
        ),
    ]

    public static func option(for variant: String) -> WhisperModelOption? {
        options.first { $0.variant == variant }
    }
}
