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
    }

    public var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                .progressViewStyle(.linear)

            Group {
                switch step {
                case .welcome: welcome
                case .microphone: microphone
                case .system: system
                case .model: model
                case .done: done
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
                } else {
                    Button("Schließen") {
                        NSApp.keyWindow?.close()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(28)
    }

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
            Button("Mikrofon erlauben") {
                Task { _ = await coordinator.permissions.requestMicrophone() }
            }
            .disabled(coordinator.permissions.microphone == .granted)
        }
    }

    private var system: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accessibility & Input Monitoring").font(.title2.bold())
            Text("Diese beiden System-Berechtigungen sind nötig, damit Voicy global auf den Hotkey reagieren und Text einfügen kann.")
            HStack {
                Text("Accessibility:"); Text(label(for: coordinator.permissions.accessibility))
                Button("Anfragen") { coordinator.permissions.requestAccessibility() }
                Button("Settings öffnen") { coordinator.permissions.openSystemSettings(for: .accessibility) }
            }
            HStack {
                Text("Input Monitoring:"); Text(label(for: coordinator.permissions.inputMonitoring))
                Button("Anfragen") { coordinator.permissions.requestInputMonitoring() }
                Button("Settings öffnen") { coordinator.permissions.openSystemSettings(for: .inputMonitoring) }
            }
        }
    }

    private var model: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Whisper-Modell").font(.title2.bold())
            Text("Lade das multilinguale `\(coordinator.settings.whisperVariant)` Modell (~470 MB). Es bleibt lokal und wird auf der Apple Neural Engine ausgeführt.")
            ProgressView(value: downloadProgress)
            HStack {
                Button("Download starten") { startDownload() }
                    .disabled(downloadProgress > 0 && downloadProgress < 1)
                if let downloadError {
                    Text(downloadError).foregroundStyle(.red).font(.caption)
                }
            }
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
        case .granted: return "✓ erlaubt"
        case .denied: return "✗ verweigert"
        case .notDetermined: return "offen"
        }
    }
}
