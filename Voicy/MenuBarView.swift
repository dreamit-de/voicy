import SwiftUI

struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var status: StatusModel
    @ObservedObject var styleStore: RewriteStyleStore
    @ObservedObject var permissions: Permissions
    @ObservedObject var updater: UpdaterService

    @Environment(\.openWindow) private var openWindow
    @State private var showingSettings = false
    @State private var didAutoOpenOnboarding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if showingSettings {
                SettingsView(coordinator: coordinator, updater: updater)
                    .frame(maxHeight: 480)
            } else {
                mainContent
            }
        }
        .frame(width: 340)
        .task(autoOpenSetupIfNeeded)
    }

    /// Opens the Setup window once per launch as long as the user has not
    /// finished the setup assistant. Deliberately NOT bound to
    /// `permissions.allGranted`: once setup was completed, revoked permissions
    /// only show the orange banner below — no auto-popup. Subsequent
    /// dismissals are respected — we don't keep re-popping the window every
    /// time the menu is opened.
    @Sendable private func autoOpenSetupIfNeeded() async {
        guard !didAutoOpenOnboarding else { return }
        didAutoOpenOnboarding = true
        try? await Task.sleep(nanoseconds: 200_000_000)
        await MainActor.run {
            if !coordinator.settings.hasCompletedOnboarding {
                openWindow(id: "onboarding")
            }
        }
    }

    // MARK: - Header (title + status pill + cog toggle)

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Voicy").font(.title3.bold())
                    Text("by dreamIT")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                statusPill
            }
            Spacer()
            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: showingSettings ? "chevron.left" : "gearshape")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(showingSettings ? "Zurück" : "Einstellungen")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            updateBanner
            permissionsBanner
            VStack(alignment: .leading, spacing: 8) {
                modeCard(
                    .normal,
                    icon: "mic",
                    title: "Normal",
                    description: "Sprache rein. Text raus."
                )
                modeCard(
                    .friendlyRewrite,
                    icon: "sparkles",
                    title: "Friendly",
                    description: "Höflich formuliert."
                )
                modeCard(
                    .customRewrite,
                    icon: "wand.and.stars",
                    title: "Custom: \(customStyleName)",
                    description: "Eigene Vorgabe."
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Divider()
            footer
        }
    }

    /// Blue counterpart to the orange permissions banner: shown while a
    /// scheduled Sparkle check found an update the user hasn't acted on yet.
    @ViewBuilder
    private var updateBanner: some View {
        if let version = updater.updateAvailable {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Update verfügbar: v\(version)")
                        .font(.caption.bold())
                }
                // Ellipsis on purpose: this opens Sparkle's standard dialog
                // (where the user confirms the install) rather than
                // installing directly.
                Button("Update anzeigen…") {
                    // User-initiated check resumes the pending update and
                    // brings Sparkle's dialog to the front.
                    updater.checkForUpdates()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1))
        }
    }

    @ViewBuilder
    private var permissionsBanner: some View {
        if !permissions.allGranted {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Berechtigungen unvollständig")
                        .font(.caption.bold())
                }
                Button("Setup abschließen") {
                    openWindow(id: "onboarding")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
        }
    }

    @ViewBuilder
    private func modeCard(
        _ mode: ModeRow,
        icon: String,
        title: String,
        description: String
    ) -> some View {
        let isActiveStyle = isActive(mode)
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32, height: 32)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            modeTrailing(mode, isActiveStyle: isActiveStyle)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            select(mode)
        }
    }

    @ViewBuilder
    private func modeTrailing(_ mode: ModeRow, isActiveStyle: Bool) -> some View {
        switch mode {
        case .normal:
            Text("⌥")
                .font(.callout.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.tertiary.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        case .friendlyRewrite, .customRewrite:
            HStack(spacing: 6) {
                if isActiveStyle {
                    Text("⌥⌃")
                        .font(.callout.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.tertiary.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Image(systemName: isActiveStyle ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(isActiveStyle ? .green : .secondary)
            }
        }
    }

    // MARK: - Footer (version + updates, status dots + quit)

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Voicy v\(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Nach Updates suchen…") { updater.checkForUpdates() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .disabled(!updater.canCheckForUpdates)
            }
            HStack(spacing: 14) {
                statusDot(label: "Setup", on: permissions.allGranted)
                statusDot(label: "Whisper", on: status.whisperReady)
                statusDot(label: "Ollama", on: status.ollamaReachable)
                Spacer()
                Button("Beenden") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    @ViewBuilder
    private func statusDot(label: String, on: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(on ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Mode model

    private enum ModeRow {
        case normal
        case friendlyRewrite
        case customRewrite
    }

    private func isActive(_ mode: ModeRow) -> Bool {
        switch mode {
        case .normal:           return false
        case .friendlyRewrite:  return styleStore.activeStyleID == RewriteStyle.friendlyID
        case .customRewrite:    return styleStore.activeStyleID == RewriteStyle.customSlotID
        }
    }

    private func select(_ mode: ModeRow) {
        switch mode {
        case .normal: break
        case .friendlyRewrite: coordinator.setActiveStyle(RewriteStyle.friendlyID)
        case .customRewrite:   coordinator.setActiveStyle(RewriteStyle.customSlotID)
        }
    }

    private var customStyleName: String {
        styleStore.styles
            .first(where: { $0.id == RewriteStyle.customSlotID })?.name ?? "Custom"
    }

    // MARK: - Status presentation

    private var statusColor: Color {
        switch status.state {
        case .recording:    return .red
        case .transcribing: return .blue
        case .rewriting:    return .purple
        case .error:        return .orange
        case .idle:         return status.whisperReady ? .green : .gray
        }
    }

    private var statusLabel: String {
        switch status.state {
        case .recording(.normal):  return "Aufnahme — Normal"
        case .recording(.rewrite): return "Aufnahme — Rewrite"
        case .transcribing:        return "Transkribiere…"
        case .rewriting:           return "Rewrite läuft…"
        case .error(let message):  return message
        case .idle:                return status.whisperReady ? "Bereit" : "Whisper lädt…"
        }
    }
}
