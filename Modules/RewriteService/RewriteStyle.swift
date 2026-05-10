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
    /// Stable ID for the built-in Friendly style so the active-style preference survives upgrades.
    static let friendlyID = UUID(uuidString: "F12E0001-0000-0000-0000-000000000001")!
    /// Stable ID for the single MVP custom slot.
    static let customSlotID = UUID(uuidString: "C05702E0-0000-0000-0000-000000000001")!

    static func defaultFriendly(prompt: String) -> RewriteStyle {
        RewriteStyle(
            id: .friendlyID,
            name: "Friendly",
            systemPrompt: prompt,
            kind: .builtin
        )
    }

    static func defaultCustomSlot() -> RewriteStyle {
        RewriteStyle(
            id: .customSlotID,
            name: "Custom",
            systemPrompt: "",
            kind: .custom
        )
    }
}
