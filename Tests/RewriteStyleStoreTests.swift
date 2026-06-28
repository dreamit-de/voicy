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
}
