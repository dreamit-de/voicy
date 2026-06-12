import SwiftUI
import UserNotifications

@main
struct VoicyApp: App {
    @StateObject private var coordinator = AppCoordinator()
    // Owns the Sparkle controller; starts the scheduled update cycle on init.
    @StateObject private var updater = UpdaterService()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                coordinator: coordinator,
                status: coordinator.statusModel,
                styleStore: coordinator.styleStore,
                permissions: coordinator.permissions,
                updater: updater
            )
        } label: {
            MenuBarLabel(coordinator: coordinator, status: coordinator.statusModel, updater: updater)
        }
        .menuBarExtraStyle(.window)

        // Single-instance window — `Window` (vs `WindowGroup`) prevents
        // duplicate Setup windows when the user clicks the banner again
        // or the auto-open trigger fires twice.
        Window("Voicy Setup", id: "onboarding") {
            OnboardingView(coordinator: coordinator)
                .frame(width: 680, height: 560)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var status: StatusModel
    @ObservedObject var updater: UpdaterService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: status.menuBarSymbol)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            // Subtle update hint: `StatusModel.menuBarSymbol` stays focused on
            // recording state (and Sparkle-agnostic) — a pending update is an
            // orthogonal condition, rendered as a small badge on top. Hidden
            // while busy so it never competes with recording/processing icons.
            .overlay(alignment: .topTrailing) {
                if updater.updateAvailable != nil, !status.state.isBusy {
                    Circle()
                        .fill(.blue)
                        .frame(width: 5, height: 5)
                        .offset(x: 3, y: -2)
                }
            }
            // The MenuBarExtra *label* exists from launch on — the content view
            // (MenuBarView) is only created once the user clicks the icon. This
            // makes the label the reliable launch hook for starting the
            // coordinator and auto-opening the setup assistant on first run.
            .task(runLaunchTasks)
    }

    @Sendable private func runLaunchTasks() async {
        // Start hotkey loop / Whisper preparation immediately, not only after
        // the first click on the menu bar icon. `start()` is idempotent.
        await MainActor.run { coordinator.start() }
        // Give the scene setup a moment before opening a window.
        try? await Task.sleep(nanoseconds: 300_000_000)
        await MainActor.run {
            if !coordinator.settings.hasCompletedOnboarding {
                openWindow(id: "onboarding")
                // Menu bar apps run as accessory processes; without explicit
                // activation the setup window would appear behind other apps.
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private var tint: Color {
        switch status.state {
        case .recording: return .red
        case .rewriting: return .purple
        case .transcribing: return .blue
        case .error: return .orange
        case .idle: return .primary
        }
    }
}
