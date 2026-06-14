import CoreGraphics
import XCTest
@testable import Voicy

final class HotkeyEngineTests: XCTestCase {
    // Raw flag values as macOS delivers them in flagsChanged events:
    // public mask + device-specific side bit (IOLLEvent.h).
    private let rightOption: UInt64 = 0x80000 | 0x40   // NX_ALTERNATEMASK | NX_DEVICERALTKEYMASK
    private let leftOption: UInt64 = 0x80000 | 0x20    // NX_ALTERNATEMASK | NX_DEVICELALTKEYMASK
    private let leftControl: UInt64 = 0x40000 | 0x01   // NX_CONTROLMASK | NX_DEVICELCTLKEYMASK
    private let rightCommand: UInt64 = 0x100000 | 0x10 // NX_COMMANDMASK | NX_DEVICERCMDKEYMASK
    private let leftCommand: UInt64 = 0x100000 | 0x08  // NX_COMMANDMASK | NX_DEVICELCMDKEYMASK

    private func mode(_ raw: UInt64, _ config: HotkeyConfig = .default) -> HotkeyMode? {
        HotkeyEngine.mode(for: CGEventFlags(rawValue: raw), config: config)
    }

    // MARK: - Default config (right Option)

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

    // MARK: - Custom primary modifier

    func test_rightCommandConfig_normalAndRewrite() {
        let config = HotkeyConfig(primary: .rightCommand)
        XCTAssertEqual(mode(rightCommand, config), .normal)
        XCTAssertEqual(mode(rightCommand | leftControl, config), .rewrite)
        // The old default key must no longer trigger under the new config.
        XCTAssertNil(mode(rightOption, config))
        // Left command is the wrong side.
        XCTAssertNil(mode(leftCommand, config))
    }

    func test_controlAsPrimary_usesOptionAsRewriteModifier() {
        // When Control is the primary, the rewrite modifier becomes Option so
        // the two modes never need the same key.
        let config = HotkeyConfig(primary: .rightControl)
        XCTAssertEqual(config.rewriteModifier, .rightOption)
        XCTAssertEqual(mode(0x40000 | 0x2000, config), .normal)            // right control alone
        XCTAssertEqual(mode(0x40000 | 0x2000 | leftOption, config), .rewrite)
    }
}
