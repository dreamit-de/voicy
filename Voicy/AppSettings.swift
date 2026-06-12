import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var language: String?            // BCP-47 like "de" or "en"; nil = auto-detect
    public var whisperVariant: String       // e.g. "openai_whisper-small"
    public var ollamaModel: String          // e.g. "llama3.2:3b"
    /// Rewrite is opt-in: false means the rewrite hotkey inserts the plain
    /// transcript and no Ollama model is auto-selected.
    public var rewriteEnabled: Bool
    public var autoLaunchAtLogin: Bool
    public var hasCompletedOnboarding: Bool

    public init(
        language: String?,
        whisperVariant: String,
        ollamaModel: String,
        rewriteEnabled: Bool = true,
        autoLaunchAtLogin: Bool,
        hasCompletedOnboarding: Bool = false
    ) {
        self.language = language
        self.whisperVariant = whisperVariant
        self.ollamaModel = ollamaModel
        self.rewriteEnabled = rewriteEnabled
        self.autoLaunchAtLogin = autoLaunchAtLogin
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    public static let `default` = AppSettings(
        language: nil,
        whisperVariant: WhisperEngine.defaultModel,
        ollamaModel: "",
        autoLaunchAtLogin: false,
        hasCompletedOnboarding: false
    )

    private enum CodingKeys: String, CodingKey {
        case language
        case whisperVariant
        case ollamaModel
        case rewriteEnabled
        case autoLaunchAtLogin
        case hasCompletedOnboarding
    }

    /// Custom decoding keeps existing users' settings intact: `hasCompletedOnboarding`
    /// was added after the first release, and strictly decoding the new non-optional
    /// field would make `load()` fail for previously persisted payloads — silently
    /// resetting ALL settings to `.default`.
    ///
    /// A payload without the key was written by a pre-onboarding release, i.e.
    /// by an existing, fully set-up user — default to `true` so the setup
    /// assistant is not forced upon them after the update (the launch hook
    /// would otherwise open it above all apps on every start). Fresh installs
    /// have no payload at all, fall back to `.default`, and keep the flag
    /// `false` so they DO get the wizard.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        whisperVariant = try container.decode(String.self, forKey: .whisperVariant)
        ollamaModel = try container.decode(String.self, forKey: .ollamaModel)
        // Added after rewrite shipped always-on — existing users keep it on.
        rewriteEnabled = try container.decodeIfPresent(Bool.self, forKey: .rewriteEnabled) ?? true
        autoLaunchAtLogin = try container.decode(Bool.self, forKey: .autoLaunchAtLogin)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? true
    }

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
