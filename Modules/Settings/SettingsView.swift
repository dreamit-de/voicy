import SwiftUI

/// Single-page inline settings shown inside the menu bar popover (cog toggle).
public struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var updater: UpdaterService

    @State private var languageSelection: String = "auto"
    @State private var customName: String = "Custom"
    @State private var customPrompt: String = ""
    @State private var customExamplePrefilled = false
    @State private var saveError: String?

    public init(coordinator: AppCoordinator, updater: UpdaterService) {
        self.coordinator = coordinator
        self.updater = updater
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                generalSection
                Divider()
                transcriptionSection
                Divider()
                rewriteSection
                Divider()
                customStyleSection
                Divider()
                permissionsSection
            }
            .padding(16)
        }
        .onAppear(perform: loadFromCoordinator)
    }

    // MARK: - Sections

    private var generalSection: some View {
        section(title: "Allgemein") {
            Toggle("Beim Login starten", isOn: Binding(
                get: { coordinator.settings.autoLaunchAtLogin },
                set: { newValue in
                    coordinator.settings.autoLaunchAtLogin = newValue
                    coordinator.settings.save()
                    LaunchAtLogin.set(enabled: newValue)
                }
            ))
            .toggleStyle(.switch)
            // Backed directly by Sparkle (persisted in user defaults).
            Toggle("Automatisch nach Updates suchen", isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.automaticallyChecksForUpdates = $0 }
            ))
            .toggleStyle(.switch)
        }
    }

    private var transcriptionSection: some View {
        section(title: "Transkription") {
            Picker("Sprache", selection: $languageSelection) {
                Text("Auto").tag("auto")
                Text("Deutsch").tag("de")
                Text("English").tag("en")
                Text("Français").tag("fr")
                Text("Español").tag("es")
            }
            .onChange(of: languageSelection) { _, newValue in
                coordinator.settings.language = newValue == "auto" ? nil : newValue
                coordinator.settings.save()
                refreshCustomExampleIfUnedited()
            }
            LabeledContent("Modell") {
                Text(coordinator.settings.whisperVariant).monospaced().foregroundStyle(.secondary)
            }
        }
    }

    private var rewriteSection: some View {
        section(title: "Rewrite") {
            LabeledContent("Ollama-Modell") {
                if coordinator.statusModel.ollamaReachable {
                    Text(coordinator.statusModel.selectedOllamaModel.isEmpty
                        ? coordinator.statusModel.ollamaModels.first ?? "—"
                        : coordinator.statusModel.selectedOllamaModel)
                        .monospaced()
                        .foregroundStyle(.secondary)
                } else {
                    Text("Ollama nicht erreichbar (127.0.0.1:11434)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var customStyleSection: some View {
        section(title: "Custom-Stil") {
            TextField("Name", text: $customName)
                .textFieldStyle(.roundedBorder)
            Text("System-Prompt — Beispiel ist sprachabhängig vorbefüllt:")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $customPrompt)
                .font(.body)
                .frame(minHeight: 140)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
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

                Button("Auf Beispiel zurücksetzen") {
                    customName = "Custom"
                    customPrompt = CustomPromptExamples.example(for: coordinator.settings.language)
                    customExamplePrefilled = true
                    saveError = nil
                }

                if let saveError {
                    Text(saveError).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    private var permissionsSection: some View {
        section(title: "Berechtigungen") {
            permissionRow("Mikrofon", status: coordinator.permissions.microphone) {
                Task { _ = await coordinator.permissions.requestMicrophone() }
            } openAction: {
                coordinator.permissions.openSystemSettings(for: .microphone)
            }
            permissionRow("Accessibility", status: coordinator.permissions.accessibility) {
                coordinator.permissions.requestAccessibility()
            } openAction: {
                coordinator.permissions.openSystemSettings(for: .accessibility)
            }
            permissionRow("Input Monitoring", status: coordinator.permissions.inputMonitoring) {
                coordinator.permissions.requestInputMonitoring()
            } openAction: {
                coordinator.permissions.openSystemSettings(for: .inputMonitoring)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    @ViewBuilder
    private func permissionRow(
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
        case .granted:       Text("✓ erlaubt").foregroundStyle(.green)
        case .denied:        Text("✗ verweigert").foregroundStyle(.red)
        case .notDetermined: Text("• offen").foregroundStyle(.secondary)
        }
    }

    private func loadFromCoordinator() {
        languageSelection = coordinator.settings.language ?? "auto"
        if let custom = coordinator.styleStore.styles.first(where: { $0.id == RewriteStyle.customSlotID }) {
            customName = custom.name
            if custom.systemPrompt.isEmpty {
                customPrompt = CustomPromptExamples.example(for: coordinator.settings.language)
                customExamplePrefilled = true
            } else {
                customPrompt = custom.systemPrompt
                customExamplePrefilled = false
            }
        }
    }

    /// When the language changes while the editor still shows an untouched example,
    /// swap the example to the new language. Don't touch a prompt the user edited.
    private func refreshCustomExampleIfUnedited() {
        guard customExamplePrefilled else { return }
        customPrompt = CustomPromptExamples.example(for: coordinator.settings.language)
    }
}
