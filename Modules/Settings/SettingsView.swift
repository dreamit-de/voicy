import SwiftUI

public struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        TabView {
            GeneralSettingsView(coordinator: coordinator)
                .tabItem { Label("General", systemImage: "gear") }
            TranscriptionSettingsView(coordinator: coordinator)
                .tabItem { Label("Transcription", systemImage: "waveform") }
            RewriteSettingsView(coordinator: coordinator)
                .tabItem { Label("Rewrite", systemImage: "wand.and.stars") }
            PermissionsSettingsView(permissions: coordinator.permissions)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 560, height: 460)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Form {
            Toggle("Beim Login starten", isOn: Binding(
                get: { coordinator.settings.autoLaunchAtLogin },
                set: { newValue in
                    coordinator.settings.autoLaunchAtLogin = newValue
                    coordinator.settings.save()
                    LaunchAtLogin.set(enabled: newValue)
                }
            ))
            Toggle("Sound-Feedback", isOn: Binding(
                get: { coordinator.settings.soundFeedback },
                set: { v in coordinator.settings.soundFeedback = v; coordinator.settings.save() }
            ))
            HStack {
                Text("Insertion-Delay")
                Slider(
                    value: Binding(
                        get: { Double(coordinator.settings.insertionDelayMs) },
                        set: { v in coordinator.settings.insertionDelayMs = Int(v); coordinator.settings.save() }
                    ),
                    in: 50...500,
                    step: 25
                )
                Text("\(coordinator.settings.insertionDelayMs) ms").monospacedDigit().frame(width: 70, alignment: .trailing)
            }
        }
        .padding()
    }
}

private struct TranscriptionSettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var languageSelection: String = "auto"

    var body: some View {
        Form {
            Picker("Sprache", selection: $languageSelection) {
                Text("Auto").tag("auto")
                Text("Deutsch").tag("de")
                Text("English").tag("en")
                Text("Français").tag("fr")
                Text("Español").tag("es")
            }
            .onAppear { languageSelection = coordinator.settings.language ?? "auto" }
            .onChange(of: languageSelection) { _, newValue in
                coordinator.settings.language = newValue == "auto" ? nil : newValue
                coordinator.settings.save()
            }

            LabeledContent("Modell") {
                VStack(alignment: .leading) {
                    Text(coordinator.settings.whisperVariant).monospaced()
                    Text("Im MVP fest auf `openai_whisper-small`. Modellauswahl folgt in v1.1.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

private struct RewriteSettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var customName: String = ""
    @State private var customPrompt: String = ""
    @State private var saveError: String?

    var body: some View {
        Form {
            Section("Ollama") {
                if coordinator.statusModel.ollamaReachable {
                    Picker("Modell", selection: Binding(
                        get: { coordinator.statusModel.selectedOllamaModel },
                        set: { coordinator.setOllamaModel($0) }
                    )) {
                        ForEach(coordinator.statusModel.ollamaModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                } else {
                    Text("Ollama läuft nicht (erwartet auf 127.0.0.1:11434).")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Aktiver Stil") {
                Picker("Stil", selection: Binding(
                    get: { coordinator.styleStore.activeStyleID },
                    set: { coordinator.styleStore.setActive($0) }
                )) {
                    ForEach(coordinator.styleStore.styles) { style in
                        Text(style.name).tag(style.id)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Custom-Stil") {
                TextField("Name", text: $customName)
                Text("System-Prompt").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $customPrompt)
                    .font(.body)
                    .frame(minHeight: 140)
                    .border(Color.secondary.opacity(0.3))

                HStack {
                    Button("Speichern") {
                        do {
                            try coordinator.styleStore.updateCustom(name: customName, systemPrompt: customPrompt)
                            saveError = nil
                        } catch {
                            saveError = error.localizedDescription
                        }
                    }
                    .disabled(customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Auf Default zurücksetzen") {
                        coordinator.styleStore.resetCustom()
                        loadCustom()
                    }

                    if let saveError {
                        Text(saveError).font(.caption).foregroundStyle(.red)
                    }
                }
            }
        }
        .padding()
        .onAppear(perform: loadCustom)
    }

    private func loadCustom() {
        if let custom = coordinator.styleStore.styles.first(where: { $0.id == RewriteStyle.customSlotID }) {
            customName = custom.name
            customPrompt = custom.systemPrompt
        }
    }
}

private struct PermissionsSettingsView: View {
    @ObservedObject var permissions: Permissions

    var body: some View {
        Form {
            row("Mikrofon", status: permissions.microphone) {
                Task { _ = await permissions.requestMicrophone() }
            } openAction: {
                permissions.openSystemSettings(for: .microphone)
            }
            row("Accessibility", status: permissions.accessibility) {
                permissions.requestAccessibility()
            } openAction: {
                permissions.openSystemSettings(for: .accessibility)
            }
            row("Input Monitoring", status: permissions.inputMonitoring) {
                permissions.requestInputMonitoring()
            } openAction: {
                permissions.openSystemSettings(for: .inputMonitoring)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func row(
        _ label: String,
        status: PermissionStatus,
        request: @escaping () -> Void,
        openAction: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            statusBadge(status)
            Button("Anfragen", action: request)
                .disabled(status == .granted)
            Button("Settings öffnen", action: openAction)
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: PermissionStatus) -> some View {
        switch status {
        case .granted: Text("✓ erlaubt").foregroundStyle(.green)
        case .denied: Text("✗ verweigert").foregroundStyle(.red)
        case .notDetermined: Text("• offen").foregroundStyle(.secondary)
        }
    }
}
