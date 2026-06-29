import XCTest
@testable import Voicy

@MainActor
final class RewriteStyleStoreTests: XCTestCase {
    func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    func test_initialState_hasTranslateAndCustom_translateIsActive() throws {
        let url = temporaryStoreURL()
        let store = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "PROMPT")
        XCTAssertEqual(store.styles.count, 2)
        XCTAssertTrue(store.styles.contains(where: { $0.id == RewriteStyle.translateID }))
        XCTAssertTrue(store.styles.contains(where: { $0.id == RewriteStyle.customSlotID }))
        XCTAssertEqual(store.activeStyleID, RewriteStyle.translateID)
        XCTAssertEqual(store.activeStyle.systemPrompt, "PROMPT")
    }

    func test_updateCustom_persistsAndRehydrates() throws {
        let url = temporaryStoreURL()
        let store = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "P")
        try store.updateCustom(name: "Slack", systemPrompt: "Make it casual.")

        let store2 = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "P")
        let custom = store2.styles.first { $0.id == RewriteStyle.customSlotID }
        XCTAssertEqual(custom?.name, "Slack")
        XCTAssertEqual(custom?.systemPrompt, "Make it casual.")
    }

    func test_setActive_persists() throws {
        let url = temporaryStoreURL()
        let store = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "P")
        store.setActive(RewriteStyle.customSlotID)

        let store2 = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "P")
        XCTAssertEqual(store2.activeStyleID, RewriteStyle.customSlotID)
    }

    func test_translatePromptAlwaysSyncedFromBundle() throws {
        let url = temporaryStoreURL()
        let store1 = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "OLD")
        XCTAssertEqual(store1.styles.first(where: { $0.id == RewriteStyle.translateID })?.systemPrompt, "OLD")

        let store2 = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "NEW")
        XCTAssertEqual(store2.styles.first(where: { $0.id == RewriteStyle.translateID })?.systemPrompt, "NEW")
    }

    func test_resetCustom_clearsName_and_prompt() throws {
        let url = temporaryStoreURL()
        let store = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "P")
        try store.updateCustom(name: "X", systemPrompt: "Y")
        store.resetCustom()
        let custom = store.styles.first { $0.id == RewriteStyle.customSlotID }
        XCTAssertEqual(custom?.name, "Custom")
        XCTAssertEqual(custom?.systemPrompt, "")
    }

    // MARK: - Per-style model

    func test_defaultStyles_inheritGlobalModel() throws {
        let store = RewriteStyleStore(storeURL: temporaryStoreURL(), builtinTranslatePrompt: "P")
        // Empty model = inherit the global default.
        XCTAssertEqual(store.styles.first { $0.id == RewriteStyle.translateID }?.model, "")
        XCTAssertEqual(store.styles.first { $0.id == RewriteStyle.customSlotID }?.model, "")
    }

    func test_setModel_persistsPerStyle() throws {
        let url = temporaryStoreURL()
        let store = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "P")
        store.setModel("gemma3:4b", for: RewriteStyle.customSlotID)
        store.setModel("qwen3:4b-instruct", for: RewriteStyle.translateID)

        let store2 = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "P")
        XCTAssertEqual(store2.styles.first { $0.id == RewriteStyle.customSlotID }?.model, "gemma3:4b")
        XCTAssertEqual(store2.styles.first { $0.id == RewriteStyle.translateID }?.model, "qwen3:4b-instruct")
    }

    func test_translateModel_survivesPromptResync() throws {
        let url = temporaryStoreURL()
        let store1 = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "OLD")
        store1.setModel("llama3.2:3b", for: RewriteStyle.translateID)

        // Re-open with a new bundled prompt: prompt updates, model is preserved.
        let store2 = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "NEW")
        let translate = store2.styles.first { $0.id == RewriteStyle.translateID }
        XCTAssertEqual(translate?.systemPrompt, "NEW")
        XCTAssertEqual(translate?.model, "llama3.2:3b")
    }

    func test_resetCustom_keepsModel() throws {
        let url = temporaryStoreURL()
        let store = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "P")
        store.setModel("gemma3:4b", for: RewriteStyle.customSlotID)
        try store.updateCustom(name: "X", systemPrompt: "Y")
        store.resetCustom()
        let custom = store.styles.first { $0.id == RewriteStyle.customSlotID }
        XCTAssertEqual(custom?.name, "Custom")
        XCTAssertEqual(custom?.systemPrompt, "")
        XCTAssertEqual(custom?.model, "gemma3:4b") // model is configured separately
    }

    func test_decodesLegacyStylesWithoutModelField() throws {
        // A pre-0.2.9 styles.json has no "model" key — it must still decode,
        // defaulting each style to inherit the global model.
        let url = temporaryStoreURL()
        let legacy = """
        {"activeStyleID":"\(RewriteStyle.translateID.uuidString)","styles":[\
        {"id":"\(RewriteStyle.translateID.uuidString)","name":"German → English","systemPrompt":"X","kind":"builtin"},\
        {"id":"\(RewriteStyle.customSlotID.uuidString)","name":"Custom","systemPrompt":"","kind":"custom"}]}
        """
        try legacy.data(using: .utf8)!.write(to: url)

        let store = RewriteStyleStore(storeURL: url, builtinTranslatePrompt: "P")
        XCTAssertEqual(store.styles.count, 2)
        XCTAssertEqual(store.styles.first { $0.id == RewriteStyle.customSlotID }?.model, "")
        XCTAssertEqual(store.styles.first { $0.id == RewriteStyle.translateID }?.model, "")
    }
}
