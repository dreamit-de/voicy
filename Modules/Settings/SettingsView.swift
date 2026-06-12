import SwiftUI

/// Single-page inline settings shown inside the menu bar popover (cog toggle).
public struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var updater: UpdaterService
    /// Nested ObservableObjects do not propagate through `coordinator` —
    /// observe the status model directly so model-load progress and the
    /// Ollama state update live while settings are open.
    @ObservedObject private var status: StatusModel

    @State private var languageSelection: String = "auto"
    @State private var customName: String = "Custom"
    @State private var customPrompt: String = ""
    @State private var customExamplePrefilled = false
    @State private var saveError: String?

    public init(coordinator: AppCoordinator, updater: UpdaterService) {
        self.coordinator = coordinator
        self.updater = updater
        self.status = coordinator.statusModel
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
            Picker("Modell", selection: Binding(
                get: { coordinator.settings.whisperVariant },
                set: { coordinator.setWhisperModel($0) }
            )) {
                ForEach(WhisperModelCatalog.options) { option in
                    Text("\(option.displayName) · \(option.downloadSize)").tag(option.variant)
                }
                // Settings written by older builds may reference a variant
                // outside the curated list — keep it selectable instead of
                // showing an empty picker.
                if WhisperModelCatalog.option(for: coordinator.settings.whisperVariant) == nil {
                    Text(coordinator.settings.whisperVariant)
                        .tag(coordinator.settings.whisperVariant)
                }
            }
            if let option = WhisperModelCatalog.option(for: coordinator.settings.whisperVariant) {
                Text(option.expectation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            whisperModelStatusRow
        }
    }

    /// Live feedback while a model change downloads/loads, mirroring the
    /// menu's whisper status so the user does not have to guess.
    @ViewBuilder
    private var whisperModelStatusRow: some View {
        switch status.whisper {
        case .ready:
            EmptyView()
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                if let progress = status.whisperProgress {
                    Text("Modell wird geladen… \(Int(progress * 100)) %")
                } else {
                    Text("Modell wird geladen…")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }

    private var rewriteSection: some View {
        section(title: "Rewrite") {
            if status.ollamaReachable {
                Picker("Ollama-Modell", selection: Binding(
                    get: { status.ollamaPullModel ?? status.selectedOllamaModel },
                    set: { selectOrDownloadOllamaModel($0) }
                )) {
                    // Curated near-realtime models; missing ones download on selection.
                    ForEach(OllamaModelCatalog.options) { option in
                        let installed = status.ollamaModels.contains(option.tag)
                        Text("\(option.displayName) · \(option.downloadSize)\(installed ? "" : " · Download")")
                            .tag(option.tag)
                    }
                    // Models that are installed but not in the curated list
                    // (e.g. pulled manually) stay selectable.
                    ForEach(status.ollamaModels.filter { OllamaModelCatalog.option(for: $0) == nil }, id: \.self) { model in
                        Text(model).tag(model)
                    }
                    if !status.selectedOllamaModel.isEmpty,
                       !status.ollamaModels.contains(status.selectedOllamaModel),
                       OllamaModelCatalog.option(for: status.selectedOllamaModel) == nil {
                        Text("\(status.selectedOllamaModel) (nicht installiert)")
                            .tag(status.selectedOllamaModel)
                    }
                }
                .disabled(status.ollamaPullModel != nil)
                if let option = OllamaModelCatalog.option(for: status.ollamaPullModel ?? status.selectedOllamaModel) {
                    Text(option.expectation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !status.selectedOllamaModel.isEmpty {
                    Text("Eigenes Modell. Faustregel: kleine Instruct-Modelle antworten in 1–2 s, Reasoning-Modelle (z. B. gpt-oss) brauchen 10–30 s pro Rewrite.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ollamaPullStatusRow
            } else {
                LabeledContent("Ollama-Modell") {
                    Text("Ollama nicht erreichbar (127.0.0.1:11434)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Curated models that are not installed yet are downloaded on selection;
    /// everything already installed is selected directly.
    private func selectOrDownloadOllamaModel(_ tag: String) {
        if status.ollamaModels.contains(tag) {
            coordinator.setOllamaModel(tag)
        } else if OllamaModelCatalog.option(for: tag) != nil {
            coordinator.downloadOllamaModel(tag)
        } else {
            coordinator.setOllamaModel(tag)
        }
    }

    @ViewBuilder
    private var ollamaPullStatusRow: some View {
        if let model = status.ollamaPullModel {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                if let progress = status.ollamaPullProgress {
                    Text("\(model) wird geladen… \(Int(progress * 100)) %")
                } else {
                    Text("\(model) wird geladen…")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
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
