import Foundation

/// One recommended Ollama rewrite model with honest expectation copy.
public struct OllamaModelOption: Identifiable, Equatable, Sendable {
    /// Exact Ollama tag, e.g. "gemma4:e2b".
    public let tag: String
    public let displayName: String
    public let downloadSize: String
    public let expectation: String

    public var id: String { tag }
}

/// Curated instruct models that rewrite/translate in near-realtime on Apple
/// Silicon. Deliberately no reasoning models (gpt-oss, qwen3 thinking, …):
/// they spend 10–30 s "thinking" per rewrite, which breaks the dictation flow.
/// Hybrid-thinking models are fine because `OllamaClient` sends `think: false`.
///
/// Ordering and copy reflect on-device latency and quality measured on a
/// 32 GB Apple M4 with Ollama 0.40.9, 2026-10-27 — see scripts/bench-rewrite.py
/// and scripts/bench-results/. With the current Ollama runtime every candidate
/// answers in ~1 s, so quality decides:
/// - Gemma 4 E2B was the only model without faithfulness faults on all six
///   German→English cases, stable across repeat runs and the fastest (0.76 s
///   max) — the default for the built-in German→English style. Its catch is a
///   7.5 GB download (it ships vision/audio encoders).
/// - Qwen3 4B Instruct (the previous default) keeps the best *German* — du,
///   register and all content — so it stays the pick for same-language Custom
///   rewrites via the per-style model ("Modell pro Funktion"). As a translator
///   it garbled the longest multi-sentence case in every run.
/// - Llama 3.2 3B changed an amount (250 → 255 €); Gemma 3 4B dropped
///   punctuation and content. Gemma 3 12B was not re-measured (June: ~12 s).
public enum OllamaModelCatalog {
    /// Most faithful German→English translation at the lowest latency — the
    /// onboarding default for new setups. Existing users keep their saved model.
    public static let recommendedTag = "gemma4:e2b"

    /// Best same-language German rewrite — the setup assistant pulls it as a
    /// second model and pins it to the Custom style ("Modell pro Funktion").
    public static let recommendedCustomTag = "qwen3:4b-instruct"

    public static let options: [OllamaModelOption] = [
        OllamaModelOption(
            tag: "gemma4:e2b",
            displayName: "Gemma 4 E2B",
            downloadSize: "7,5 GB",
            expectation: "Empfehlung für German → English: ~1 s, übersetzt sinntreu und vollständig. Großer Download; beim Umformulieren auf Deutsch wechselt es gelegentlich von „du“ zu „Sie“."
        ),
        OllamaModelOption(
            tag: "qwen3:4b-instruct",
            displayName: "Qwen3 4B Instruct",
            downloadSize: "2,5 GB",
            expectation: "Bestes Deutsch für Custom-Rewrites: behält „du“, Tonfall und alle Inhalte (~1 s). Beim Übersetzen langer, mehrsätziger Diktate verdreht es gelegentlich den Sinn."
        ),
        OllamaModelOption(
            tag: "llama3.2:3b",
            displayName: "Llama 3.2 3B",
            downloadSize: "2,0 GB",
            expectation: "Kleinster Download (~1 s), aber beim Übersetzen schon einmal eine Zahl verfälscht und auf Deutsch unzuverlässig."
        ),
        OllamaModelOption(
            tag: "gemma3:4b",
            displayName: "Gemma 3 4B",
            downloadSize: "3,3 GB",
            expectation: "~1 s, lässt beim Übersetzen aber Satzzeichen weg und kürzt auf Deutsch gelegentlich Inhalte."
        ),
        OllamaModelOption(
            tag: "gemma3:12b",
            displayName: "Gemma 3 12B",
            downloadSize: "8,1 GB",
            expectation: "Großes Modell, spürbar langsamer als die kleinen — eher für gleichsprachige Rewrites, wenn Zeit keine Rolle spielt."
        ),
    ]

    public static func option(for tag: String) -> OllamaModelOption? {
        options.first { $0.tag == tag }
    }
}
