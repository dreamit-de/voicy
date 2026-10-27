import XCTest
@testable import Voicy

final class OllamaClientTests: XCTestCase {
    private func strip(_ s: String) -> String {
        OllamaClient.stripAcknowledgementPreamble(s)
    }

    func test_stripsStandaloneAcknowledgement() {
        XCTAssertEqual(
            strip("Ja, natürlich. Könnten Sie mir bitte die Unterlagen schicken?"),
            "Könnten Sie mir bitte die Unterlagen schicken?"
        )
        XCTAssertEqual(strip("Sure! Could you send me the slides?"), "Could you send me the slides?")
        XCTAssertEqual(strip("Hier ist die Umformulierung: Bitte schick mir das."), "Bitte schick mir das.")
    }

    func test_keepsLegitSentenceStartingWithSimilarWord() {
        // "Klar," continues into the same sentence — not a standalone preamble.
        let s = "Klar, das erledige ich bis morgen."
        XCTAssertEqual(strip(s), s)
    }

    func test_keepsNormalRewrite() {
        let s = "Könnten Sie mir bitte die Unterlagen von letzter Woche schicken?"
        XCTAssertEqual(strip(s), s)
    }

    func test_doesNotStripWhenNothingFollows() {
        // Only an acknowledgement and nothing else — keep it rather than empty out.
        XCTAssertEqual(strip("Natürlich."), "Natürlich.")
    }

    func test_generateRequestDisablesThinking() throws {
        let body = OllamaClient.GenerateRequest(
            model: "gemma4:e2b", prompt: "Hallo", system: "S", stream: false,
            options: .init(temperature: 0.3)
        )
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any]
        )
        XCTAssertEqual(json["think"] as? Bool, false)
        XCTAssertEqual(json["keep_alive"] as? String, "60m")
    }

    func test_recommendedModelIsInCatalog() {
        XCTAssertNotNil(OllamaModelCatalog.option(for: OllamaModelCatalog.recommendedTag))
        XCTAssertEqual(OllamaModelCatalog.options.first?.tag, OllamaModelCatalog.recommendedTag)
    }

    func test_pullFailedForOutdatedOllamaAsksToUpdate() {
        let error = OllamaError.pullFailed("pull model manifest: 412: The model you are attempting to pull requires a newer version of Ollama.")
        XCTAssertTrue(error.localizedDescription.contains("bitte Ollama aktualisieren"))
    }

    func test_pullFailedKeepsOtherMessages() {
        let error = OllamaError.pullFailed("file does not exist")
        XCTAssertEqual(error.localizedDescription, "Modell-Download fehlgeschlagen: file does not exist")
    }
}
