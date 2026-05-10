import Foundation
import os

public protocol RewriteService: AnyObject {
    func availableModels() async throws -> [String]
    func isReachable() async -> Bool
    func rewrite(_ text: String, using style: RewriteStyle, model: String) async throws -> String
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
            options: .init(temperature: 0.4)
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response)
        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
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
        struct Options: Encodable { let temperature: Double }
        let model: String
        let prompt: String
        let system: String
        let stream: Bool
        let options: Options
    }

    private struct GenerateResponse: Decodable {
        let response: String
    }
}

public enum OllamaError: LocalizedError, Sendable {
    case httpStatus(Int)
    case modelNotSelected
    case emptySystemPrompt

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code): return "Ollama responded with HTTP \(code)."
        case .modelNotSelected: return "No Ollama model selected. Open Settings → Rewrite to choose one."
        case .emptySystemPrompt: return "The selected style has no system prompt."
        }
    }
}
