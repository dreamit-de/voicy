import CoreGraphics
import Foundation

/// A push-to-talk trigger modifier. Only modifier keys are offered: they can be
/// held without typing characters or auto-repeating, which is what hold-to-talk
/// needs. Device-specific side bits (from `<IOKit/hidsystem/IOLLEvent.h>`)
/// distinguish left from right where it matters.
public enum HotkeyModifier: String, CaseIterable, Codable, Sendable {
    case rightOption
    case rightCommand
    case rightControl
    case rightShift
    case fn

    /// Public CGEventFlags mask for "this kind of modifier is down" (any side).
    public var mask: CGEventFlags {
        switch self {
        case .rightOption:  return .maskAlternate
        case .rightCommand: return .maskCommand
        case .rightControl: return .maskControl
        case .rightShift:   return .maskShift
        case .fn:           return .maskSecondaryFn
        }
    }

    /// Device-dependent side bit that pins the modifier to the right-hand key.
    /// 0 means "no side distinction" (Fn is a single key).
    public var deviceBit: UInt64 {
        switch self {
        case .rightShift:   return 0x4      // NX_DEVICERSHIFTKEYMASK
        case .rightCommand: return 0x10     // NX_DEVICERCMDKEYMASK
        case .rightOption:  return 0x40     // NX_DEVICERALTKEYMASK
        case .rightControl: return 0x2000   // NX_DEVICERCTLKEYMASK
        case .fn:           return 0
        }
    }

    /// True when this modifier is currently held, honoring the side bit.
    public func isDown(in flags: CGEventFlags) -> Bool {
        guard flags.contains(mask) else { return false }
        return deviceBit == 0 || (flags.rawValue & deviceBit) != 0
    }

    public var displaySymbol: String {
        switch self {
        case .rightOption:  return "⌥"
        case .rightCommand: return "⌘"
        case .rightControl: return "⌃"
        case .rightShift:   return "⇧"
        case .fn:           return "fn"
        }
    }

    public var displayName: String {
        switch self {
        case .rightOption:  return "Rechte Wahltaste (⌥)"
        case .rightCommand: return "Rechte Befehlstaste (⌘)"
        case .rightControl: return "Rechte Control-Taste (⌃)"
        case .rightShift:   return "Rechte Umschalttaste (⇧)"
        case .fn:           return "Fn-Taste"
        }
    }

    /// Honest, curated guidance per key. macOS exposes no API to enumerate all
    /// registered global hotkeys, so these are known-conflict notes rather than
    /// a live check.
    public var conflictHint: String {
        switch self {
        case .rightOption:
            return "Empfohlen: in der Regel frei und gut allein zu halten."
        case .rightCommand:
            return "Meist frei. ⌘ wird mit weiteren Tasten oft für App-Shortcuts genutzt — allein gehalten als Push-to-Talk aber unproblematisch."
        case .rightControl:
            return "Kann mit „Eingabequelle wechseln“ oder App-Shortcuts kollidieren. Prüfe Systemeinstellungen → Tastatur → Tastaturkurzbefehle."
        case .rightShift:
            return "Frei, aber Vorsicht: Ist „Slow Keys“/„Tastenverzögerung“ aktiv, kann langes Halten stören."
        case .fn:
            return "macOS belegt Fn standardmäßig mit Diktat oder dem Emoji-Picker (Systemeinstellungen → Tastatur). Kann kollidieren."
        }
    }
}

/// The full push-to-talk configuration: a primary modifier for dictation, and
/// dictation-while-also-holding the rewrite modifier for the rewrite mode.
public struct HotkeyConfig: Equatable, Sendable {
    public var primary: HotkeyModifier

    public init(primary: HotkeyModifier) {
        self.primary = primary
    }

    public static let `default` = HotkeyConfig(primary: .rightOption)

    /// The extra modifier that, held together with `primary`, selects rewrite.
    /// Control by default; if Control *is* the primary, Option takes its place
    /// so the two modes never require the same key twice.
    public var rewriteModifier: HotkeyModifier {
        primary == .rightControl ? .rightOption : .rightControl
    }

    /// Keycaps for the normal (dictation) trigger.
    public var normalSymbols: [String] { [primary.displaySymbol] }

    /// Keycaps for the rewrite trigger.
    public var rewriteSymbols: [String] { [primary.displaySymbol, rewriteModifier.displaySymbol] }
}
