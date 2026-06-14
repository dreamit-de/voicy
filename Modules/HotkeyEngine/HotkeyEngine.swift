import AppKit
import CoreGraphics
import Foundation
import os

public enum HotkeyMode: Equatable, Sendable {
    case normal     // primary modifier held alone
    case rewrite    // primary + rewrite modifier held
}

public enum HotkeyEvent: Equatable, Sendable {
    case pressed(HotkeyMode)
    case released(HotkeyMode)
}

public protocol HotkeyEngineProtocol: AnyObject, Sendable {
    var events: AsyncStream<HotkeyEvent> { get }
    func start() throws
    func stop()
    /// Live-update the trigger configuration (e.g. from settings).
    func updateConfig(_ config: HotkeyConfig)
}

/// Tracks the configured push-to-talk modifier (alone or with the rewrite
/// modifier) held globally via a CGEventTap.
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
    // Read in the tap callback and written via updateConfig — both happen on
    // the main run loop, so no synchronization is needed.
    private var config: HotkeyConfig

    public init(config: HotkeyConfig = .default) {
        self.config = config
        var continuation: AsyncStream<HotkeyEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    public func updateConfig(_ config: HotkeyConfig) {
        self.config = config
        // A held key under the old config should not stay "pressed" forever.
        if let mode = currentMode {
            continuation.yield(.released(mode))
            currentMode = nil
        }
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

        let newMode = HotkeyEngine.mode(for: event.flags, config: config)

        if newMode == currentMode { return }

        if let old = currentMode, newMode != old {
            continuation.yield(.released(old))
        }
        if let new = newMode, new != currentMode {
            continuation.yield(.pressed(new))
        }
        currentMode = newMode
    }

    /// Derives the hotkey mode from modifier flags for a given config. The
    /// primary modifier held alone is `.normal`, primary + rewrite modifier is
    /// `.rewrite`, anything else is nil. The primary honors its device side bit
    /// (so e.g. only the *right* Option counts); the rewrite modifier matches
    /// either side for forgiveness.
    static func mode(for flags: CGEventFlags, config: HotkeyConfig) -> HotkeyMode? {
        guard config.primary.isDown(in: flags) else { return nil }
        return flags.contains(config.rewriteModifier.mask) ? .rewrite : .normal
    }
}

public enum HotkeyEngineError: Error, Sendable {
    case tapCreationFailed
}
