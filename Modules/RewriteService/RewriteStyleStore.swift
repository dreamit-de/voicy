import Combine
import Foundation
import os

@MainActor
public final class RewriteStyleStore: ObservableObject {
    @Published public private(set) var styles: [RewriteStyle] = []
    @Published public private(set) var activeStyleID: UUID

    private let storeURL: URL
    private let log = Logger(subsystem: "de.dreamit.voicy", category: "RewriteStyleStore")
    private let builtinTranslatePrompt: String

    public init(
        storeURL: URL? = nil,
        builtinTranslatePrompt: String = RewriteStyleStore.loadBundledTranslatePrompt()
    ) {
        let url = storeURL ?? RewriteStyleStore.defaultStoreURL()
        self.storeURL = url
        self.builtinTranslatePrompt = builtinTranslatePrompt
        self.activeStyleID = RewriteStyle.translateID

        load()
    }

    public var activeStyle: RewriteStyle {
        styles.first(where: { $0.id == activeStyleID }) ?? styles.first ?? RewriteStyle.defaultTranslate(prompt: builtinTranslatePrompt)
    }

    public func setActive(_ id: UUID) {
        guard styles.contains(where: { $0.id == id }) else { return }
        activeStyleID = id
        persist()
    }

    /// Updates the editable Custom style. Throws if the caller targets a built-in style.
    public func updateCustom(name: String, systemPrompt: String) throws {
        guard let index = styles.firstIndex(where: { $0.id == RewriteStyle.customSlotID }) else {
            throw RewriteStyleStoreError.styleNotFound
        }
        guard styles[index].kind == .custom else {
            throw RewriteStyleStoreError.notEditable
        }
        styles[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom" : name
        styles[index].systemPrompt = systemPrompt
        persist()
    }

    public func resetCustom() {
        guard let index = styles.firstIndex(where: { $0.id == RewriteStyle.customSlotID }) else { return }
        styles[index] = .defaultCustomSlot()
        persist()
    }

    // MARK: - Persistence

    private struct Persisted: Codable {
        var styles: [RewriteStyle]
        var activeStyleID: UUID
    }

    private func load() {
        let defaults = defaultStyles()

        guard let data = try? Data(contentsOf: storeURL),
              let persisted = try? JSONDecoder().decode(Persisted.self, from: data) else {
            self.styles = defaults
            self.activeStyleID = RewriteStyle.translateID
            persist()
            return
        }

        // Always keep the built-in prompt in sync with the bundled file
        // (we never let users overwrite it on disk).
        var merged = persisted.styles
        if let i = merged.firstIndex(where: { $0.id == RewriteStyle.translateID }) {
            merged[i] = RewriteStyle.defaultTranslate(prompt: builtinTranslatePrompt)
        } else {
            merged.insert(.defaultTranslate(prompt: builtinTranslatePrompt), at: 0)
        }
        if !merged.contains(where: { $0.id == RewriteStyle.customSlotID }) {
            merged.append(.defaultCustomSlot())
        }
        self.styles = merged
        self.activeStyleID = merged.contains(where: { $0.id == persisted.activeStyleID })
            ? persisted.activeStyleID
            : RewriteStyle.translateID
    }

    private func persist() {
        let payload = Persisted(styles: styles, activeStyleID: activeStyleID)
        do {
            let data = try JSONEncoder().encode(payload)
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: storeURL, options: .atomic)
        } catch {
            log.error("Failed to persist styles: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func defaultStyles() -> [RewriteStyle] {
        [
            .defaultTranslate(prompt: builtinTranslatePrompt),
            .defaultCustomSlot()
        ]
    }

    // MARK: - Static helpers

    public static func defaultStoreURL() -> URL {
        AppSupport.root().appendingPathComponent("styles.json")
    }

    public static func loadBundledTranslatePrompt() -> String {
        if let url = Bundle.main.url(forResource: "translate", withExtension: "md"),
           let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        // Hardcoded fallback so unit tests and worst-case bundle issues still produce something usable.
        return "You are a translation assistant. If the input is German, translate it into natural English; if it is already English, leave it essentially unchanged. Reply with the result text only."
    }
}

public enum RewriteStyleStoreError: Error, Sendable {
    case styleNotFound
    case notEditable
}
