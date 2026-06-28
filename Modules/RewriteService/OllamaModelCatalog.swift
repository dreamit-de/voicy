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

/// Curated instruct models that rewrite/translate in near-realtime on Apple
/// Silicon. Deliberately no reasoning models (gpt-oss, qwen3 thinking, …):
/// they spend 10–30 s "thinking" per rewrite, which breaks the dictation flow.
/// Ordering and copy reflect on-device latency and German→English translation
/// quality measured on a 32 GB Apple M4, 2026-06-28 — see scripts/bench-rewrite.py
/// and scripts/bench-results/. For the built-in German→English style, Qwen3 4B
/// Instruct was the only small model with zero faithfulness faults at ~2.9 s
/// warm; Gemma 3 4B keeps the most natural *German* phrasing for same-language
/// Custom rewrites; Llama 3.2 3B is the fastest but occasionally clips content.
public enum OllamaModelCatalog {
    /// Best balance of German→English translation faithfulness and speed — the onboarding default.
    public static let recommendedTag = "qwen3:4b-instruct"

    public static let options: [OllamaModelOption] = [
        OllamaModelOption(
            tag: "qwen3:4b-instruct",
            displayName: "Qwen3 4B Instruct",
            downloadSize: "2,5 GB",
            expectation: "Empfehlung: ~2–3 s, übersetzt Deutsch sinntreu und vollständig ins Englische."
        ),
        OllamaModelOption(
            tag: "gemma3:4b",
            displayName: "Gemma 3 4B",
            downloadSize: "3,3 GB",
            expectation: "Natürlichstes Deutsch für gleichsprachige Custom-Rewrites. Etwas langsamer (~3–4 s)."
        ),
        OllamaModelOption(
            tag: "llama3.2:3b",
            displayName: "Llama 3.2 3B",
            downloadSize: "2,0 GB",
            expectation: "Am schnellsten (~1–2 s) und kleinster Download, kürzt beim Übersetzen aber gelegentlich etwas."
        ),
        OllamaModelOption(
            tag: "gemma3:12b",
            displayName: "Gemma 3 12B",
            downloadSize: "8,1 GB",
            expectation: "Höchste Qualität, für Übersetzung aber zu langsam (~12 s) — eher für gleichsprachige Rewrites."
        ),
    ]

    public static func option(for tag: String) -> OllamaModelOption? {
        options.first { $0.tag == tag }
    }
}
