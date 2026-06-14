import AppKit
import Combine
import Foundation
import Sparkle

/// Thin ObservableObject wrapper around Sparkle's `SPUStandardUpdaterController`.
///
/// The app runs as a background agent (`LSUIElement`), so scheduled update alerts would
/// be shown *behind* other windows by Sparkle's default presentation and easily
/// go unnoticed. This service therefore implements Sparkle's "gentle reminders"
/// (`SPUStandardUserDriverDelegate`): scheduled checks never pop UI on their
/// own — a found update is published via `updateAvailable` and surfaced in the
/// menu bar instead. The user opens Sparkle's regular update dialog through a
/// user-initiated check (`checkForUpdates()`), which always activates the app.
@MainActor
public final class UpdaterService: NSObject, ObservableObject {
    /// Mirrors `SPUUpdater.canCheckForUpdates` (KVO-driven). False while a
    /// check or an update session is already in progress.
    @Published public private(set) var canCheckForUpdates = false

    /// Human-readable version of an update found by a *scheduled* check
    /// (e.g. "1.2"), or `nil` if none is pending. Drives the menu bar hint.
    @Published public private(set) var updateAvailable: String?

    // Implicitly unwrapped so `self` can act as the user driver delegate;
    // assigned exactly once right below in `init`.
    private var updaterController: SPUStandardUpdaterController!

    public override init() {
        super.init()
        // `startingUpdater: true` starts the scheduled update cycle right away.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
        // Keep the published flag in sync with Sparkle's KVO-compliant state.
        updaterController.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    /// User-initiated check. Sparkle activates the app (also for background
    /// apps) and presents its standard dialog in immediate focus — this is
    /// also how a pending `updateAvailable` is acted upon ("Update anzeigen…").
    public func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Whether Sparkle performs automatic background checks. Backed directly
    /// by Sparkle (persisted in user defaults); `objectWillChange` keeps any
    /// bound SwiftUI toggle refreshed.
    public var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            updaterController.updater.automaticallyChecksForUpdates = newValue
        }
    }
}

// MARK: - Gentle reminders (SPUStandardUserDriverDelegate)
//
// Sparkle invokes these callbacks on the main thread, but the protocol is not
// actor-annotated — so the methods are `nonisolated`, extract only Sendable
// values from the Sparkle objects, and hop onto the main actor explicitly.
extension UpdaterService: SPUStandardUserDriverDelegate {
    /// Required minimum for background apps: tells Sparkle we present
    /// scheduled-update reminders ourselves (and silences its log warning).
    public nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Returning `false` overrides Sparkle's default presentation for
    /// scheduled checks — no alert appears (neither in front nor buried in the
    /// back); we surface the update via the menu bar instead.
    public nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        false
    }

    public nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        let version = update.displayVersionString
        let userInitiated = state.userInitiated
        Task { @MainActor in
            // For user-initiated checks Sparkle's dialog comes to the front
            // anyway; only scheduled finds need the persistent menu bar hint.
            if !userInitiated {
                self.updateAvailable = version
            }
        }
    }

    /// The user has seen the update (e.g. opened the dialog) — clear the hint.
    public nonisolated func standardUserDriverDidReceiveUserAttention(
        forUpdate update: SUAppcastItem
    ) {
        Task { @MainActor in
            self.updateAvailable = nil
        }
    }

    /// Update session ended (installed, skipped, or dismissed) — clean up.
    public nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in
            self.updateAvailable = nil
        }
    }
}
