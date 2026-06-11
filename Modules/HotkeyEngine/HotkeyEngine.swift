import AppKit
import CoreGraphics
import Foundation
import os

public enum HotkeyMode: Equatable, Sendable {
    case normal     // Right-Option held alone
    case rewrite    // Right-Option + Control held
}

public enum HotkeyEvent: Equatable, Sendable {
    case pressed(HotkeyMode)
    case released(HotkeyMode)
}

public protocol HotkeyEngineProtocol: AnyObject, Sendable {
    var events: AsyncStream<HotkeyEvent> { get }
    func start() throws
    func stop()
}

/// Tracks Right-Option (alone or with Control) held globally via a CGEventTap.
///
/// Why a tap and not `NSEvent.addGlobalMonitor`? Global monitors do not see modifier-only
/// `flagsChanged` events when no other key is pressed; a session event tap does.
public final class HotkeyEngine: HotkeyEngineProtocol, @unchecked Sendable {
    public let events: AsyncStream<HotkeyEvent>
    private let continuation: AsyncStream<HotkeyEvent>.Continuation

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let log = Logger(subsystem: "de.dreamit.voicy", category: "HotkeyEngine")

    private var currentMode: HotkeyMode? = nil

    public init() {
        var continuation: AsyncStream<HotkeyEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    deinit {
        stop()
        continuation.finish()
    }

    public func start() throws {
        guard eventTap == nil else { return }

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<HotkeyEngine>.fromOpaque(refcon).takeUnretainedValue()
                engine.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        )

        guard let tap else {
            log.error("Failed to create CGEventTap. Input Monitoring permission missing?")
            throw HotkeyEngineError.tapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        log.info("HotkeyEngine started")
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            self.eventTap = nil
        }
        if let mode = currentMode {
            continuation.yield(.released(mode))
            currentMode = nil
        }
    }

    // MARK: - Private

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // System suspended the tap; re-enable it.
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                log.notice("Re-enabled CGEventTap after system disable")
            }
            return
        }
        guard type == .flagsChanged else { return }

        let newMode = HotkeyEngine.mode(for: event.flags)

        if newMode == currentMode { return }

        if let old = currentMode, newMode != old {
            continuation.yield(.released(old))
        }
        if let new = newMode, new != currentMode {
            continuation.yield(.pressed(new))
        }
        currentMode = newMode
    }

    /// Derives the hotkey mode from modifier flags. Right-Option held alone is
    /// `.normal`, Right-Option + Control is `.rewrite`, anything else is nil.
    ///
    /// CGEventFlags carries device-specific side bits in addition to the public
    /// masks; the right-alt bit distinguishes Right- from Left-Option.
    static func mode(for flags: CGEventFlags) -> HotkeyMode? {
        let rightOptionDown = flags.contains(.maskAlternate)
            && (flags.rawValue & UInt64(nxDeviceRAltKeyMask)) != 0
        guard rightOptionDown else { return nil }
        return flags.contains(.maskControl) ? .rewrite : .normal
    }
}

public enum HotkeyEngineError: Error, Sendable {
    case tapCreationFailed
}

/// `NX_DEVICERALTKEYMASK` from `<IOKit/hidsystem/IOLLEvent.h>` — not bridged
/// into Swift, so we redefine it. NOT to be confused with `NX_CONTROLMASK`
/// (0x040000): using that value here silently turns the Right-Option check
/// into a Control check, making the normal mode unreachable.
private let nxDeviceRAltKeyMask: UInt = 0x40
