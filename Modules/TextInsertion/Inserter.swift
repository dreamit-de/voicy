import AppKit
import CoreGraphics
import Foundation
import os

public protocol TextInserter: AnyObject, Sendable {
    func insert(_ text: String) async
}

/// Inserts text into the focused app via the universal Pasteboard + synthetic ⌘V path.
///
/// We snapshot the current pasteboard, replace it with our text, synthesize ⌘V, then
/// restore the snapshot after a short delay. This is the only insertion method that
/// works in all major Mac UIs (browsers, Slack, Electron, Notion, VS Code).
public actor Inserter: TextInserter {
    /// Pasteboard-restore delay in milliseconds. 80 ms is the empirically smallest
    /// value at which Electron/Chromium-based apps (Slack, VS Code, browsers)
    /// reliably pick up the synthesized ⌘V before we restore the previous
    /// pasteboard contents on Apple Silicon. Going lower risks the target app
    /// pasting the *restored* content instead of our text. Going higher just
    /// adds perceptible latency for no benefit.
    private static let restoreDelayMs: Int = 80

    private let pasteboard: NSPasteboard
    private let restoreDelay: UInt64
    private let log = Logger(subsystem: "de.dreamit.voicy", category: "Inserter")

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.restoreDelay = UInt64(Self.restoreDelayMs) * 1_000_000
    }

    public func insert(_ text: String) async {
        guard !text.isEmpty else { return }

        let snapshot = snapshotPasteboard()

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Yield briefly so the OS focus tracker has settled after the user released the hotkey.
        try? await Task.sleep(nanoseconds: 10_000_000)

        sendCommandV()

        try? await Task.sleep(nanoseconds: restoreDelay)
        restorePasteboard(snapshot)
    }

    // MARK: - Private

    private struct PasteboardSnapshot {
        let items: [[String: Data]]
    }

    private func snapshotPasteboard() -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems ?? []
        let serialized: [[String: Data]] = items.map { item in
            var dict: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type.rawValue] = data
                }
            }
            return dict
        }
        return PasteboardSnapshot(items: serialized)
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()
        let restored: [NSPasteboardItem] = snapshot.items.map { dict in
            let item = NSPasteboardItem()
            for (rawType, data) in dict {
                item.setData(data, forType: NSPasteboard.PasteboardType(rawType))
            }
            return item
        }
        if !restored.isEmpty {
            pasteboard.writeObjects(restored)
        }
    }

    private func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09 // kVK_ANSI_V

        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else {
            log.error("Failed to create CGEvent for ⌘V synthesis")
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand

        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
