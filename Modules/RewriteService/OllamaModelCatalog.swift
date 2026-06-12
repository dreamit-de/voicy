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

/// Curated small instruct models that rewrite in near-realtime on Apple
/// Silicon. Deliberately no reasoning models (gpt-oss, qwen3 thinking, …):
/// they spend 10–30 s "thinking" per rewrite, which breaks the dictation
/// flow. Sizes verified against the Ollama registry 2026-06-12.
public enum OllamaModelCatalog {
    public static let options: [OllamaModelOption] = [
        OllamaModelOption(
            tag: "qwen3:4b-instruct",
            displayName: "Qwen3 4B Instruct",
            downloadSize: "2,5 GB",
            expectation: "Empfehlung: ~1 s pro Rewrite, formuliert Deutsch zuverlässig und natürlich um."
        ),
        OllamaModelOption(
            tag: "llama3.2:3b",
            displayName: "Llama 3.2 3B",
            downloadSize: "2,0 GB",
            expectation: "Am schnellsten (unter 1 s) und kleinster Download. Deutsch solide, bei verschachtelten Sätzen etwas einfacher."
        ),
        OllamaModelOption(
            tag: "gemma3:4b",
            displayName: "Gemma 3 4B",
            downloadSize: "3,3 GB",
            expectation: "Sehr gute Mehrsprachigkeit, ~1–2 s pro Rewrite. Größter Download der Auswahl."
        ),
    ]

    public static func option(for tag: String) -> OllamaModelOption? {
        options.first { $0.tag == tag }
    }
}
