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

public protocol HotkeyEngineProtocol: AnyObject {
    var events: AsyncStream<HotkeyEvent> { get }
    func start() throws
    func stop()
}

/// Tracks Right-Option (alone or with Control) held globally via a CGEventTap.
///
/// Why a tap and not `NSEvent.addGlobalMonitor`? Global monitors do not see modifier-only
/// `flagsChanged` events when no other key is pressed; a session event tap does.
public final class HotkeyEngine: HotkeyEngineProtocol {
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

        let flags = event.flags
        let rightOptionDown = flags.contains(.maskAlternate) && hasRightSideBit(flags, mask: NX_DEVICERALTKEYMASK)
        let controlDown = flags.contains(.maskControl)

        let newMode: HotkeyMode? = {
            guard rightOptionDown else { return nil }
            return controlDown ? .rewrite : .normal
        }()

        if newMode == currentMode { return }

        if let old = currentMode, newMode != old {
            continuation.yield(.released(old))
        }
        if let new = newMode, new != currentMode {
            continuation.yield(.pressed(new))
        }
        currentMode = newMode
    }

    /// CGEventFlags carries device-specific side bits in addition to the public masks.
    /// `NX_DEVICERALTKEYMASK` (0x040000) marks Right-Option specifically.
    private func hasRightSideBit(_ flags: CGEventFlags, mask: UInt) -> Bool {
        (flags.rawValue & UInt64(mask)) != 0
    }
}

public enum HotkeyEngineError: Error, Sendable {
    case tapCreationFailed
}

// IOKit constants. NX_DEVICERALTKEYMASK is part of `<IOKit/hidsystem/IOLLEvent.h>`
// but is not bridged into Swift as a constant; we redefine it here.
private let NX_DEVICERALTKEYMASK: UInt = 0x040000
