import XCTest
@testable import Voicy

final class AppSettingsTests: XCTestCase {
    func test_default_hasSensibleValues() {
        let s = AppSettings.default
        XCTAssertEqual(s.whisperVariant, "openai_whisper-small")
        XCTAssertNil(s.language)
        XCTAssertFalse(s.autoLaunchAtLogin)
        XCTAssertFalse(s.hasCompletedOnboarding)
    }

    func test_codable_roundtrip() throws {
        var s = AppSettings.default
        s.language = "de"
        s.ollamaModel = "llama3.2:3b"
        s.hasCompletedOnboarding = true

        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded, s)
    }

    /// Settings persisted before `hasCompletedOnboarding` existed must still
    /// decode — otherwise `load()` would silently reset ALL settings for
    /// existing users. A missing key means a pre-onboarding (= fully set-up)
    /// user, so the flag defaults to `true`: the setup assistant must not be
    /// forced on existing users after the update.
    func test_decoding_legacyPayload_withoutOnboardingFlag_succeeds() throws {
        let legacyJSON = """
        {
            "language": "de",
            "whisperVariant": "openai_whisper-small",
            "ollamaModel": "llama3.2:3b",
            "autoLaunchAtLogin": true
        }
        """
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decoded.language, "de")
        XCTAssertEqual(decoded.whisperVariant, "openai_whisper-small")
        XCTAssertEqual(decoded.ollamaModel, "llama3.2:3b")
        XCTAssertTrue(decoded.autoLaunchAtLogin)
        XCTAssertTrue(decoded.hasCompletedOnboarding)
    }

    func test_encoding_includesOnboardingFlag() throws {
        var s = AppSettings.default
        s.hasCompletedOnboarding = true

        let data = try JSONEncoder().encode(s)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["hasCompletedOnboarding"] as? Bool, true)
    }
}
