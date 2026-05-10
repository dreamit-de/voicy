import XCTest
@testable import Voicy

final class AppSettingsTests: XCTestCase {
    func test_default_hasSensibleValues() {
        let s = AppSettings.default
        XCTAssertEqual(s.whisperVariant, "openai_whisper-small")
        XCTAssertNil(s.language)
        XCTAssertEqual(s.insertionDelayMs, 150)
        XCTAssertFalse(s.soundFeedback)
    }

    func test_codable_roundtrip() throws {
        var s = AppSettings.default
        s.language = "de"
        s.ollamaModel = "llama3.2:3b"
        s.insertionDelayMs = 250

        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded, s)
    }
}
