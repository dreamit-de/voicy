import Foundation
import os

public protocol RewriteService: AnyObject, Sendable {
    func availableModels() async throws -> [String]
    func isReachable() async -> Bool
    func rewrite(_ text: String, using style: RewriteStyle, model: String) async throws -> String
    /// Verifies that `model` can actually generate, not just that the server
    /// answers `/api/tags` — a listed model can still fail to load (e.g. an
    /// outdated GGUF format after an Ollama update). Throws on failure.
    func ping(model: String) async throws
    /// Downloads `model` from the Ollama registry. `progress` is called with
    /// values in [0, 1] aggregated over all layers.
    func pull(model: String, progress: (@Sendable (Double) -> Void)?) async throws
}

/// Talks to a locally running Ollama server (default `127.0.0.1:11434`).
public final class OllamaClient: RewriteService, @unchecked Sendable {
    public let baseURL: URL
    private let session: URLSession
    private let log = Logger(subsystem: "de.dreamit.voicy", category: "OllamaClient")

    public init(baseURL: URL = URL(string: "http://127.0.0.1:11434")!,
                session: URLSession = OllamaClient.makeSession()) {
        self.baseURL = baseURL
        self.session = session
    }

    public func isReachable() async -> Bool {
        do {
            _ = try await availableModels()
            return true
        } catch {
            return false
        }
    }

    public func availableModels() async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        request.timeoutInterval = 1.5
        let (data, response) = try await session.data(for: request)
        try validate(response)
        let tags = try JSONDecoder().decode(TagsResponse.self, from: data)
        return tags.models.map(\.name)
    }

    public func rewrite(_ text: String, using style: RewriteStyle, model: String) async throws -> String {
        guard !text.isEmpty else { return text }
        guard !style.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaError.emptySystemPrompt
        }
        guard !model.isEmpty else { throw OllamaError.modelNotSelected }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body = GenerateRequest(
            model: model,
            prompt: text,
            system: style.systemPrompt,
            stream: false,
            // Low temperature keeps the rewrite faithful — at 0.4 small models
            // occasionally mangle or embellish phrases; 0.3 is markedly steadier.
            options: .init(temperature: 0.3)
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response)
        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        let cleaned = OllamaClient.stripAcknowledgementPreamble(
            decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return cleaned
    }

    /// Removes a leading acknowledgement sentence that small models sometimes
    /// prepend despite the prompt ("Ja, natürlich.", "Sure!", "Hier ist …:").
    /// Conservative: only strips a known opener that forms its own sentence
    /// (ends in . ! :) and is followed by more text, so it never eats a real
    /// rewrite that merely starts with "Klar, …".
    static func stripAcknowledgementPreamble(_ text: String) -> String {
        let openers = [
            "ja, natürlich", "ja natürlich", "natürlich", "klar", "klar doch",
            "aber gerne", "gerne", "sehr gerne", "sicher", "selbstverständlich",
            "alles klar", "hier ist", "hier ist es", "hier ist die umformulierung",
            "hier hast du", "hier kommt", "sure", "of course", "certainly",
            "absolutely", "no problem", "here is", "here you go", "here's the",
            "okay", "ok",
        ]
        // Find the first sentence terminator (. ! :) — German rewrites rarely
        // open with a colon, so it's a safe preamble boundary too.
        guard let boundary = text.firstIndex(where: { $0 == "." || $0 == "!" || $0 == ":" }) else {
            return text
        }
        let head = text[..<boundary]
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
        guard openers.contains(head) else { return text }
        let rest = text[text.index(after: boundary)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Don't strip if nothing meaningful remains.
        return rest.isEmpty ? text : rest
    }

    public func ping(model: String) async throws {
        guard !model.isEmpty else { throw OllamaError.modelNotSelected }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Generous: a cold model first loads into memory (10s+ for large models).
        request.timeoutInterval = 120

        let body = GenerateRequest(
            model: model,
            prompt: "Antworte nur mit OK.",
            system: "Du bist ein Echo-Test.",
            stream: false,
            options: .init(temperature: 0.0, numPredict: 8)
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response)
        // Success = the model loaded and produced a generate response at all;
        // the content is irrelevant (reasoning models may spend the token
        // budget on thinking).
        _ = try JSONDecoder().decode(GenerateResponse.self, from: data)
    }

    public func pull(model: String, progress: (@Sendable (Double) -> Void)?) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/pull"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Idle timeout between chunks; the overall download may take much longer.
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "stream": true])

        let (bytes, response) = try await session.bytes(for: request)
        try validate(response)

        // Streamed JSON lines: {"status":"pulling <digest>","digest":…,
        // "total":N,"completed":M}. Aggregate across layers; the model blob
        // dominates, so the sum tracks perceived progress well.
        var layers: [String: (completed: Int64, total: Int64)] = [:]
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let message = obj["error"] as? String {
                throw OllamaError.pullFailed(message)
            }
            if let digest = obj["digest"] as? String,
               let total = (obj["total"] as? NSNumber)?.int64Value, total > 0 {
                let completed = (obj["completed"] as? NSNumber)?.int64Value ?? 0
                layers[digest] = (completed, total)
                let sums = layers.values.reduce(into: (c: Int64(0), t: Int64(0))) {
                    $0.c += $1.completed; $0.t += $1.total
                }
                progress?(Double(sums.c) / Double(sums.t))
            }
        }

        // The stream ends after "success"; trust but verify — a vanished
        // connection mid-pull also ends the stream without an error line.
        let models = try await availableModels()
        guard models.contains(where: { $0 == model || $0.hasPrefix("\(model):") }) else {
            throw OllamaError.pullFailed("Download wurde unterbrochen — Modell ist nicht installiert.")
        }
        log.info("Pulled model \(model, privacy: .public)")
    }

    // MARK: - Helpers

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw OllamaError.httpStatus(http.statusCode)
        }
    }

    public static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    // MARK: - Wire types

    private struct TagsResponse: Decodable {
        struct Model: Decodable { let name: String }
        let models: [Model]
    }

    private struct GenerateRequest: Encodable {
        struct Options: Encodable {
            let temperature: Double
            var numPredict: Int? = nil

            enum CodingKeys: String, CodingKey {
                case temperature
                case numPredict = "num_predict"
            }
        }

        let model: String
        let prompt: String
        let system: String
        let stream: Bool
        let options: Options
        /// Keep the model loaded between dictations — Ollama's 5-minute
        /// default unload would add several seconds of cold start to the
        /// first rewrite after every pause.
        var keepAlive: String = "60m"

        enum CodingKeys: String, CodingKey {
            case model, prompt, system, stream, options
            case keepAlive = "keep_alive"
        }
    }

    private struct GenerateResponse: Decodable {
        let response: String
    }
}

public enum OllamaError: LocalizedError, Sendable {
    case httpStatus(Int)
    case modelNotSelected
    case emptySystemPrompt
    case pullFailed(String)

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code): return "Ollama responded with HTTP \(code)."
        case .modelNotSelected: return "No Ollama model selected. Open Settings → Rewrite to choose one."
        case .emptySystemPrompt: return "The selected style has no system prompt."
        case .pullFailed(let message): return "Modell-Download fehlgeschlagen: \(message)"
        }
    }
}
