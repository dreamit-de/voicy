import SwiftUI

public struct OnboardingView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var step: Step = .welcome
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    enum Step: Int, CaseIterable {
        case welcome, microphone, system, model, done

        /// Human-readable step number for the middle steps (1, 2, 3).
        /// Returns nil for welcome and done screens.
        var displayNumber: Int? {
            switch self {
            case .welcome, .done: return nil
            default: return rawValue // microphone=1, system=2, model=3
            }
        }
    }

    public var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .center, spacing: 12) {
                ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                    .progressViewStyle(.linear)
                if let n = step.displayNumber {
                    Text("\(n) / 3")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }

            Group {
                switch step {
                case .welcome:    welcome
                case .microphone: microphone
                case .system:     system
                case .model:      model
                case .done:       done
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                if step != .welcome {
                    Button("Zurück") { step = Step(rawValue: step.rawValue - 1) ?? .welcome }
                }
                Spacer()
                if step != .done {
                    Button(step == .welcome ? "Los geht's" : "Weiter") {
                        step = Step(rawValue: step.rawValue + 1) ?? .done
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(step == .model && downloadProgress < 1)
                } else {
                    Button("Schließen") { NSApp.keyWindow?.close() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(28)
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Willkommen bei Voicy").font(.largeTitle.bold())
            Text("Voicy verwandelt deine Sprache lokal in Text — ohne Cloud, ohne Account.")
                .foregroundStyle(.secondary)
            Text("Wir richten dich in drei Schritten ein:")
            Label("Mikrofon-Berechtigung", systemImage: "mic")
            Label("Accessibility & Input Monitoring", systemImage: "lock.shield")
            Label("Whisper-Modell herunterladen", systemImage: "arrow.down.circle")
        }
    }

    private var microphone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mikrofon").font(.title2.bold())
            Text("Voicy nimmt nur auf, während du den Hotkey hältst. Audio verlässt dein Gerät nie.")
            HStack {
                Text("Status:")
                Text(label(for: coordinator.permissions.microphone))
            }
            Button("Erneut anfragen") {
                Task { _ = await coordinator.permissions.requestMicrophone() }
            }
            .disabled(coordinator.permissions.microphone == .granted)
        }
        .onAppear {
            Task { _ = await coordinator.permissions.requestMicrophone() }
        }
    }

    private var system: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Systemberechtigungen").font(.title2.bold())
            Text("Voicy braucht zwei macOS-Berechtigungen. Klicke auf „Anfragen", erlaube den Zugriff im erscheinenden Dialog, und kehre dann hierher zurück.")
                .fixedSize(horizontal: false, vertical: true)

            systemPermissionCard(
                title: "Accessibility",
                subtitle: "Erlaubt Voicy, Text in aktive Felder einzufügen.",
                icon: "lock.shield",
                status: coordinator.permissions.accessibility,
                onRequest: { coordinator.permissions.requestAccessibility() },
                onSettings: { coordinator.permissions.openSystemSettings(for: .accessibility) }
            )

            systemPermissionCard(
                title: "Input Monitoring",
                subtitle: "Erlaubt Voicy, den globalen Hotkey zu erkennen.",
                icon: "keyboard",
                status: coordinator.permissions.inputMonitoring,
                onRequest: { coordinator.permissions.requestInputMonitoring() },
                onSettings: { coordinator.permissions.openSystemSettings(for: .inputMonitoring) }
            )

            if coordinator.permissions.accessibility == .granted &&
               coordinator.permissions.inputMonitoring == .granted {
                Label("Alle Berechtigungen erteilt", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("Der Status aktualisiert sich automatisch nach dem Erteilen. Falls er sich nicht ändert, starte Voicy neu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { coordinator.permissions.refresh() }
    }

    @ViewBuilder
    private func systemPermissionCard(
        title: String,
        subtitle: String,
        icon: String,
        status: PermissionStatus,
        onRequest: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(permissionTint(status))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    permissionBadge(status)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if status != .granted {
                    HStack(spacing: 8) {
                        Button("Anfragen", action: onRequest)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("Einstellungen öffnen", action: onSettings)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func permissionBadge(_ status: PermissionStatus) -> some View {
        switch status {
        case .granted:
            Label("Erlaubt", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.caption)
        case .denied:
            Label("Verweigert", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red).font(.caption)
        case .notDetermined:
            Label("Ausstehend", systemImage: "clock")
                .foregroundStyle(.secondary).font(.caption)
        }
    }

    private func permissionTint(_ status: PermissionStatus) -> Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .secondary
        }
    }

    private var model: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Whisper-Modell").font(.title2.bold())
            Text("Lade das multilinguale `\(coordinator.settings.whisperVariant)` Modell (~470 MB). Es bleibt lokal und wird auf der Apple Neural Engine ausgeführt.")
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: downloadProgress)

            Group {
                if downloadProgress == 1 {
                    Label("Modell erfolgreich heruntergeladen", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if downloadProgress > 0 {
                    Text("Lädt herunter…")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else if downloadError != nil {
                    Button("Erneut versuchen") { startDownload() }
                }
            }

            if let downloadError {
                Text(downloadError)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            // Auto-start download when reaching this step — no extra button click needed.
            // ensureModel() is a no-op if the model is already on disk.
            if downloadProgress == 0 { startDownload() }
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fertig!").font(.largeTitle.bold())
            Text("Halte ⌥ rechts gedrückt für eine Aufnahme im Normal-Modus.")
            Text("Halte ⌥ rechts + ⌃ gedrückt für den aktiv ausgewählten Rewrite-Stil.")
            Text("Aktive Stile und das Ollama-Modell findest du im Menüleisten-Menü und in den Settings.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Download

    private func startDownload() {
        downloadError = nil
        downloadProgress = 0.001
        Task {
            do {
                _ = try await ModelStore.shared.ensureModel(
                    variant: coordinator.settings.whisperVariant,
                    progress: { fraction in
                        Task { @MainActor in downloadProgress = fraction }
                    }
                )
                await MainActor.run {
                    downloadProgress = 1
                    coordinator.statusModel.whisperReady = true
                }
            } catch {
                await MainActor.run {
                    downloadError = error.localizedDescription
                    downloadProgress = 0
                }
            }
        }
    }

    private func label(for status: PermissionStatus) -> String {
        switch status {
        case .granted:       return "✓ erlaubt"
        case .denied:        return "✗ verweigert"
        case .notDetermined: return "offen"
        }
    }
}
