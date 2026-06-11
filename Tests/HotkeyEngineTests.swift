import CoreGraphics
import XCTest
@testable import Voicy

final class HotkeyEngineTests: XCTestCase {
    // Raw flag values as macOS delivers them in flagsChanged events:
    // public mask + device-specific side bit (IOLLEvent.h).
    private let rightOption: UInt64 = 0x80000 | 0x40   // NX_ALTERNATEMASK | NX_DEVICERALTKEYMASK
    private let leftOption: UInt64 = 0x80000 | 0x20    // NX_ALTERNATEMASK | NX_DEVICELALTKEYMASK
    private let leftControl: UInt64 = 0x40000 | 0x01   // NX_CONTROLMASK | NX_DEVICELCTLKEYMASK

    private func mode(_ raw: UInt64) -> HotkeyMode? {
        HotkeyEngine.mode(for: CGEventFlags(rawValue: raw))
    }

    func test_rightOptionAlone_isNormalMode() {
        XCTAssertEqual(mode(rightOption), .normal)
    }

    func test_rightOptionWithControl_isRewriteMode() {
        XCTAssertEqual(mode(rightOption | leftControl), .rewrite)
    }

    func test_leftOptionAlone_isNoMode() {
        XCTAssertNil(mode(leftOption))
    }

    func test_leftOptionWithControl_isNoMode() {
        // Regression: with the right-alt bit mistaken for NX_CONTROLMASK,
        // Ctrl + *any* Option triggered rewrite and normal was unreachable.
        XCTAssertNil(mode(leftOption | leftControl))
    }

    func test_controlAlone_isNoMode() {
        XCTAssertNil(mode(leftControl))
    }

    func test_noFlags_isNoMode() {
        XCTAssertNil(mode(0))
    }
}
