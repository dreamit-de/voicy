import Foundation

public struct RewriteStyle: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case builtin
        case custom
    }

    public let id: UUID
    public var name: String
    public var systemPrompt: String
    public let kind: Kind
    /// Preferred Ollama model for this style. Empty string means "inherit the
    /// global default" (`AppSettings.ollamaModel`) — so existing setups and
    /// users who never touch the per-style picker keep one shared model, while
    /// power users can pin a different model per function (e.g. a translation
    /// model for German → English, a casual model for Custom).
    public var model: String

    public init(id: UUID = UUID(), name: String, systemPrompt: String, kind: Kind, model: String = "") {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.kind = kind
        self.model = model
    }

    public var isEditable: Bool { kind == .custom }

    private enum CodingKeys: String, CodingKey {
        case id, name, systemPrompt, kind, model
    }

    /// `model` was added after the first styles.json shipped. Decoding it with
    /// `decodeIfPresent` keeps older payloads valid (default: inherit global).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        systemPrompt = try c.decode(String.self, forKey: .systemPrompt)
        kind = try c.decode(Kind.self, forKey: .kind)
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
    }
}

public extension RewriteStyle {
    /// Stable ID for the built-in style so the active-style preference survives
    /// upgrades. The UUID value is unchanged from the former "Friendly" style on
    /// purpose: users who had the built-in active keep it active after the
    /// upgrade — it just translates now instead of softening tone.
    static let translateID = UUID(uuidString: "F12E0001-0000-0000-0000-000000000001")!
    /// Stable ID for the single MVP custom slot.
    static let customSlotID = UUID(uuidString: "C05702E0-0000-0000-0000-000000000001")!

    static func defaultTranslate(prompt: String, model: String = "") -> RewriteStyle {
        RewriteStyle(
            id: Self.translateID,
            name: "German → English",
            systemPrompt: prompt,
            kind: .builtin,
            model: model
        )
    }

    static func defaultCustomSlot(model: String = "") -> RewriteStyle {
        RewriteStyle(
            id: Self.customSlotID,
            name: "Custom",
            systemPrompt: "",
            kind: .custom,
            model: model
        )
    }
}
