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
        .frame(width: 352)
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
        HStack(alignment: .center, spacing: 10) {
            // Transparent logo motif (no icon squircle) — the full app icon
            // looks muddy at this size; source: docs/assets/voicy-logo-transparent.png
            Image("MenuLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
            whisperBanner
            rewriteBanner
            VStack(alignment: .leading, spacing: 14) {
                // Normal is always available, nothing to choose — render it as
                // a plain info row, not as a card that begs to be clicked.
                VStack(alignment: .leading, spacing: 6) {
                    shortcutHeader(keys: ["⌥"], label: "Rechte Option-Taste halten und sprechen")
                    normalRow
                }
                // The rewrite styles ARE a choice — selectable cards in their
                // own set-off container.
                VStack(alignment: .leading, spacing: 6) {
                    shortcutHeader(keys: ["⌥", "⌃"], label: "Zusätzlich Control — wähle den Stil:")
                    if coordinator.settings.rewriteEnabled {
                        styleCard(
                            .friendlyRewrite,
                            icon: "sparkles",
                            title: "Friendly",
                            description: "Höflich formuliert."
                        )
                        styleCard(
                            .customRewrite,
                            icon: "wand.and.stars",
                            title: "Custom: \(customStyleName)",
                            description: "Eigene Vorgabe."
                        )
                    } else {
                        Text("Rewrite ist deaktiviert — ⌥⌃ fügt den Text unverändert ein. Aktivieren: Einstellungen → Rewrite → Modell wählen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 2)
                            .padding(.vertical, 4)
                    }
                }
                .padding(10)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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
                        .font(.callout.weight(.semibold))
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
                .controlSize(.regular)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1))
        }
    }

    /// Shown when Whisper preparation has given up for now (it auto-retries
    /// with backoff, but the user can force an immediate attempt).
    @ViewBuilder
    private var whisperBanner: some View {
        if case .failed(let message) = status.whisper {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text("Whisper konnte nicht geladen werden")
                        .font(.callout.weight(.semibold))
                }
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Button("Erneut versuchen") {
                    coordinator.retryWhisperPreparation()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1))
        }
    }

    /// Shown after a rewrite (or connection test) failed. Dictation still
    /// works — Voicy falls back to inserting the unmodified transcript — but
    /// that fallback is silent, so make the broken rewrite path visible until
    /// a rewrite succeeds or the connection test passes.
    @ViewBuilder
    private var rewriteBanner: some View {
        if let message = status.rewriteError {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.orange)
                    Text("Rewrite funktioniert nicht — Original-Text wird eingefügt")
                        .font(.callout.weight(.semibold))
                }
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Button(status.rewriteTestRunning ? "Teste…" : "Verbindung testen") {
                    coordinator.testRewriteSetup()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(status.rewriteTestRunning)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
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
                        .font(.callout.weight(.semibold))
                }
                Button("Setup abschließen") {
                    openWindow(id: "onboarding")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
        }
    }

    /// The always-available dictation mode: informational, not clickable.
    private var normalRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic")
                .font(.title2)
                .frame(width: 32, height: 32)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Normal").font(.headline)
                Text("Sprache rein. Text raus.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    /// A selectable rewrite style. The active one is tinted and stroked in
    /// the accent color so the radio choice is obvious at a glance.
    @ViewBuilder
    private func styleCard(
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
                .foregroundStyle(isActiveStyle ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isActiveStyle ? "checkmark.circle.fill" : "circle")
                .imageScale(.large)
                .foregroundStyle(isActiveStyle ? Color.accentColor : .secondary)
        }
        .padding(12)
        .background(
            isActiveStyle ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(.regularMaterial),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActiveStyle ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            select(mode)
        }
    }

    /// Group headline: keycaps + short explanation of what holding them does.
    /// Carries the shortcut so the cards below stay free of badges.
    private func shortcutHeader(keys: [String], label: String) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.footnote.monospaced().weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tertiary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 2)
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
                statusDot(label: "Setup", color: permissions.allGranted ? .green : .gray.opacity(0.5))
                statusDot(label: "Whisper", color: whisperDotColor)
                statusDot(label: "Ollama", color: ollamaDotColor)
                Spacer()
                Button("Beenden") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var whisperDotColor: Color {
        switch status.whisper {
        case .ready: return .green
        case .loading: return .gray.opacity(0.5)
        case .failed: return .red
        }
    }

    /// Reachable alone is not enough for green: an in-flight model download
    /// or a failed rewrite turns the dot orange until rewriting works again.
    /// With rewrite disabled the dot is neutral gray — that is not an error.
    private var ollamaDotColor: Color {
        if !coordinator.settings.rewriteEnabled { return .gray.opacity(0.5) }
        if !status.ollamaReachable { return .gray.opacity(0.5) }
        if status.ollamaPullModel != nil { return .orange }
        return status.rewriteError == nil ? .green : .orange
    }

    @ViewBuilder
    private func statusDot(label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
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
        case .idle:
            switch status.whisper {
            case .ready: return .green
            case .loading: return .gray
            case .failed: return .red
            }
        }
    }

    private var statusLabel: String {
        switch status.state {
        case .recording(.normal):  return "Aufnahme — Normal"
        case .recording(.rewrite): return "Aufnahme — Rewrite"
        case .transcribing:        return "Transkribiere…"
        case .rewriting:           return "Rewrite läuft…"
        case .error(let message):  return message
        case .idle:
            switch status.whisper {
            case .ready: return "Bereit"
            case .loading:
                if let progress = status.whisperProgress {
                    return "Whisper-Modell wird geladen… \(Int(progress * 100)) %"
                }
                return "Whisper lädt…"
            case .failed: return "Whisper nicht verfügbar"
            }
        }
    }
}
