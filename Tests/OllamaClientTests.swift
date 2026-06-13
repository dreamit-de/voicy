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
}
