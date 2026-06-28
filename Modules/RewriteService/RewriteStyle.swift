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

    public init(id: UUID = UUID(), name: String, systemPrompt: String, kind: Kind) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.kind = kind
    }

    public var isEditable: Bool { kind == .custom }
}

public extension RewriteStyle {
    /// Stable ID for the built-in style so the active-style preference survives
    /// upgrades. The UUID value is unchanged from the former "Friendly" style on
    /// purpose: users who had the built-in active keep it active after the
    /// upgrade — it just translates now instead of softening tone.
    static let translateID = UUID(uuidString: "F12E0001-0000-0000-0000-000000000001")!
    /// Stable ID for the single MVP custom slot.
    static let customSlotID = UUID(uuidString: "C05702E0-0000-0000-0000-000000000001")!

    static func defaultTranslate(prompt: String) -> RewriteStyle {
        RewriteStyle(
            id: Self.translateID,
            name: "German → English",
            systemPrompt: prompt,
            kind: .builtin
        )
    }

    static func defaultCustomSlot() -> RewriteStyle {
        RewriteStyle(
            id: Self.customSlotID,
            name: "Custom",
            systemPrompt: "",
            kind: .custom
        )
    }
}
