import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var language: String?            // BCP-47 like "de" or "en"; nil = auto-detect
    public var whisperVariant: String       // e.g. "openai_whisper-small"
    public var ollamaModel: String          // e.g. "llama3.2:3b"
    public var insertionDelayMs: Int        // pasteboard restore delay
    public var autoLaunchAtLogin: Bool

    public static let `default` = AppSettings(
        language: nil,
        whisperVariant: WhisperEngine.defaultModel,
        ollamaModel: "",
        insertionDelayMs: 150,
        autoLaunchAtLogin: false
    )

    private static let storeKey = "de.dreamit.voicy.settings.v1"

    public static func load() -> AppSettings {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: AppSettings.storeKey)
        }
    }
}
