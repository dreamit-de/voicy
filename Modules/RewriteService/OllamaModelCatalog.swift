import Foundation

/// One recommended Ollama rewrite model with honest expectation copy.
public struct OllamaModelOption: Identifiable, Equatable, Sendable {
    /// Exact Ollama tag, e.g. "qwen3:4b-instruct".
    public let tag: String
    public let displayName: String
    public let downloadSize: String
    public let expectation: String

    public var id: String { tag }
}

/// Curated instruct models that rewrite in near-realtime on Apple Silicon.
/// Deliberately no reasoning models (gpt-oss, qwen3 thinking, …): they spend
/// 10–30 s "thinking" per rewrite, which breaks the dictation flow. Ordering
/// and copy reflect German rewrite quality and latency measured on a 32 GB
/// M-series Mac, 2026-06-13 (gemma3 handles German speech acts and phrasing
/// markedly better than qwen at the same speed).
public enum OllamaModelCatalog {
    /// Best balance of German quality and speed — the onboarding default.
    public static let recommendedTag = "gemma3:4b"

    public static let options: [OllamaModelOption] = [
        OllamaModelOption(
            tag: "gemma3:4b",
            displayName: "Gemma 3 4B",
            downloadSize: "3,3 GB",
            expectation: "Empfehlung: ~1–2 s pro Rewrite, formuliert Deutsch natürlich und sinntreu um."
        ),
        OllamaModelOption(
            tag: "gemma3:12b",
            displayName: "Gemma 3 12B",
            downloadSize: "8,1 GB",
            expectation: "Beste Qualität, am genauesten bei langen Sätzen. Langsamer (~3–5 s pro Rewrite) und größter Download."
        ),
        OllamaModelOption(
            tag: "qwen3:4b-instruct",
            displayName: "Qwen3 4B Instruct",
            downloadSize: "2,5 GB",
            expectation: "Schnell (~1 s), neigt im Deutschen aber dazu, Inhalte leicht umzudeuten oder Floskeln zu ergänzen."
        ),
        OllamaModelOption(
            tag: "llama3.2:3b",
            displayName: "Llama 3.2 3B",
            downloadSize: "2,0 GB",
            expectation: "Am schnellsten (unter 1 s) und kleinster Download. Deutsch solide, bei verschachtelten Sätzen etwas einfacher."
        ),
    ]

    public static func option(for tag: String) -> OllamaModelOption? {
        options.first { $0.tag == tag }
    }
}
