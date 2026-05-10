import SwiftUI

struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var status: StatusModel
    @ObservedObject var styleStore: RewriteStyleStore
    @ObservedObject var permissions: Permissions

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            permissionsSection
            Divider()
            styleSection
            Divider()
            actions
        }
        .frame(width: 280)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(status.statusHeadline).font(.headline)
            HStack(spacing: 12) {
                statusDot(label: "Whisper", on: status.whisperReady)
                statusDot(label: "Ollama", on: status.ollamaReachable)
            }
            .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var permissionsSection: some View {
        Group {
            if !permissions.allGranted {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Berechtigungen unvollständig")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Button("Onboarding öffnen…") {
                        openWindow(id: "onboarding")
                    }
                    .buttonStyle(.link)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Aktiver Rewrite-Stil").font(.caption).foregroundStyle(.secondary)
            ForEach(styleStore.styles) { style in
                Button {
                    coordinator.setActiveStyle(style.id)
                } label: {
                    HStack {
                        Image(systemName: styleStore.activeStyleID == style.id ? "checkmark.circle.fill" : "circle")
                        Text(style.name)
                        Spacer()
                        if style.kind == .builtin {
                            Text("built-in").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button("Settings…") { openSettings() }
                .keyboardShortcut(",", modifiers: .command)
                .buttonStyle(.plain)
            Button("Custom-Stil bearbeiten…") {
                openSettings()
                // Settings opens to the Rewrite tab via deep-link in real life;
                // for the MVP we just open Settings and let the user navigate.
            }
            .buttonStyle(.plain)
            Button("Beenden") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func statusDot(label: String, on: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(on ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 7, height: 7)
            Text(label).foregroundStyle(.secondary)
        }
    }
}
