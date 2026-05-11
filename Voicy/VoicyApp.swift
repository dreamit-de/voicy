import SwiftUI
import UserNotifications

@main
struct VoicyApp: App {
    @StateObject private var coordinator = AppCoordinator()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                coordinator: coordinator,
                status: coordinator.statusModel,
                styleStore: coordinator.styleStore,
                permissions: coordinator.permissions
            )
            .onAppear { coordinator.start() }
        } label: {
            MenuBarLabel(status: coordinator.statusModel)
        }
        .menuBarExtraStyle(.window)

        // Single-instance window — `Window` (vs `WindowGroup`) prevents
        // duplicate Setup windows when the user clicks the banner again
        // or the auto-open trigger fires twice.
        Window("Voicy Setup", id: "onboarding") {
            OnboardingView(coordinator: coordinator)
                .frame(minWidth: 520, minHeight: 420)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var status: StatusModel

    var body: some View {
        Image(systemName: status.menuBarSymbol)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
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
