import XCTest
@testable import Voicy

@MainActor
final class RewriteStyleStoreTests: XCTestCase {
    func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    func test_initialState_hasFriendlyAndCustom_friendlyIsActive() throws {
        let url = temporaryStoreURL()
        let store = RewriteStyleStore(storeURL: url, builtinFriendlyPrompt: "PROMPT")
        XCTAssertEqual(store.styles.count, 2)
        XCTAssertTrue(store.styles.contains(where: { $0.id == RewriteStyle.friendlyID }))
        XCTAssertTrue(store.styles.contains(where: { $0.id == RewriteStyle.customSlotID }))
        XCTAssertEqual(store.activeStyleID, RewriteStyle.friendlyID)
        XCTAssertEqual(store.activeStyle.systemPrompt, "PROMPT")
    }

    func test_updateCustom_persistsAndRehydrates() throws {
        let url = temporaryStoreURL()
        let store = RewriteStyleStore(storeURL: url, builtinFriendlyPrompt: "P")
        try store.updateCustom(name: "Slack", systemPrompt: "Make it casual.")

        let store2 = RewriteStyleStore(storeURL: url, builtinFriendlyPrompt: "P")
        let custom = store2.styles.first { $0.id == RewriteStyle.customSlotID }
        XCTAssertEqual(custom?.name, "Slack")
        XCTAssertEqual(custom?.systemPrompt, "Make it casual.")
    }

    func test_setActive_persists() throws {
        let url = temporaryStoreURL()
        let store = RewriteStyleStore(storeURL: url, builtinFriendlyPrompt: "P")
        store.setActive(RewriteStyle.customSlotID)

        let store2 = RewriteStyleStore(storeURL: url, builtinFriendlyPrompt: "P")
        XCTAssertEqual(store2.activeStyleID, RewriteStyle.customSlotID)
    }

    func test_friendlyPromptAlwaysSyncedFromBundle() throws {
        let url = temporaryStoreURL()
        let store1 = RewriteStyleStore(storeURL: url, builtinFriendlyPrompt: "OLD")
        XCTAssertEqual(store1.styles.first(where: { $0.id == RewriteStyle.friendlyID })?.systemPrompt, "OLD")

        let store2 = RewriteStyleStore(storeURL: url, builtinFriendlyPrompt: "NEW")
        XCTAssertEqual(store2.styles.first(where: { $0.id == RewriteStyle.friendlyID })?.systemPrompt, "NEW")
    }

    func test_resetCustom_clearsName_and_prompt() throws {
        let url = temporaryStoreURL()
        let store = RewriteStyleStore(storeURL: url, builtinFriendlyPrompt: "P")
        try store.updateCustom(name: "X", systemPrompt: "Y")
        store.resetCustom()
        let custom = store.styles.first { $0.id == RewriteStyle.customSlotID }
        XCTAssertEqual(custom?.name, "Custom")
        XCTAssertEqual(custom?.systemPrompt, "")
    }
}
