import SwiftUI

/// Installer-style setup assistant: step indicator sidebar on the left,
/// step content + footer button row on the right. Fixed 560 × 440 pt.
@MainActor
public struct OnboardingView: View {
    @ObservedObject var coordinator: AppCoordinator
    /// Nested ObservableObjects do not propagate through `coordinator` —
    /// observe both directly so permission flips and model-download progress
    /// re-render the assistant live.
    @ObservedObject private var permissions: Permissions
    @ObservedObject private var status: StatusModel
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .welcome
    /// Primary dictation language chosen in the language step.
    @State private var languageChoice: String = "de"
    /// Whether the user wants the optional rewrite feature.
    @State private var rewriteWanted: Bool = true
    @State private var didInitLanguageStep = false
    /// Highest step the user has reached; used to mark earlier steps as done.
    @State private var maxVisitedStep: Step = .welcome
    /// Steps skipped via "Später erledigen". Display-only, not persisted.
    @State private var skipped: Set<Step> = []
    /// Snapshot taken when the view first appears. If Input Monitoring flips
    /// to granted during this session, the hotkey event tap can only be
    /// created after an app relaunch — we surface a restart hint for that.
    @State private var inputMonitoringGrantedAtLaunch: Bool?
    @State private var modelState: ModelDownloadState = .idle
    @State private var modelDownloadTask: Task<Void, Never>?

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.permissions = coordinator.permissions
        self.status = coordinator.statusModel
    }

    /// Recommended models for the supported primary languages (de/en).
    static let recommendedWhisperVariant = "openai_whisper-large-v3-v20240930_626MB"
    static let recommendedOllamaModel = "qwen3:4b-instruct"

    // MARK: - Steps

    enum Step: Int, CaseIterable {
        case welcome, language, microphone, accessibility, inputMonitoring, model, done

        var sidebarTitle: String {
            switch self {
            case .welcome: return "Willkommen"
            case .language: return "Sprache"
            case .microphone: return "Mikrofon"
            case .accessibility: return "Bedienungshilfen"
            case .inputMonitoring: return "Eingabeüberwachung"
            case .model: return "Modelle"
            case .done: return "Fertig"
            }
        }

        var sidebarSymbol: String {
            switch self {
            case .welcome: return "hand.wave"
            case .language: return "globe"
            case .microphone: return "mic"
            case .accessibility: return "accessibility"
            case .inputMonitoring: return "keyboard"
            case .model: return "arrow.down.circle"
            case .done: return "checkmark.seal"
            }
        }
    }

    enum ModelDownloadState: Equatable {
        case idle
        case downloading(Double)
        case installed
        case failed(String)
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            contentColumn
        }
        .frame(width: 560, height: 440)
        .onAppear {
            if inputMonitoringGrantedAtLaunch == nil {
                inputMonitoringGrantedAtLaunch =
                    coordinator.permissions.inputMonitoring == .granted
                resumeAtFirstOpenStep()
            }
        }
    }

    // MARK: - Sidebar (step indicator, display-only)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                sidebarRow(for: item)
            }
            Spacer()
        }
        .padding(16)
        .frame(width: 168, alignment: .topLeading)
        .frame(maxHeight: .infinity)
        .background(.quaternary.opacity(0.5))
    }

    private enum SidebarRowState {
        case current, completed, skipped, upcoming
    }

    private func sidebarRowState(for item: Step) -> SidebarRowState {
        if item == step { return .current }
        if isFulfilled(item), item.rawValue <= maxVisitedStep.rawValue { return .completed }
        if skipped.contains(item), !isFulfilled(item) { return .skipped }
        return .upcoming
    }

    private func sidebarRow(for item: Step) -> some View {
        let state = sidebarRowState(for: item)
        return HStack(spacing: 8) {
            sidebarIcon(for: item, state: state)
                .font(.system(size: 16))
                .frame(width: 20)
            Text(item.sidebarTitle)
                .font(.callout)
                .fontWeight(state == .current ? .bold : .regular)
                .foregroundStyle(state == .upcoming ? Color.secondary : Color.primary)
        }
    }

    @ViewBuilder
    private func sidebarIcon(for item: Step, state: SidebarRowState) -> some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .skipped:
            Image(systemName: "minus.circle.fill").foregroundStyle(.orange)
        case .current:
            Image(systemName: item.sidebarSymbol).foregroundStyle(.tint)
        case .upcoming:
            Image(systemName: item.sidebarSymbol).foregroundStyle(.secondary)
        }
    }

    // MARK: - Content column

    private var contentColumn: some View {
        VStack(spacing: 16) {
            ScrollView {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            footerBar
        }
        .padding(24)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome: welcomeStep
        case .language: languageStep
        case .microphone: microphoneStep
        case .accessibility: accessibilityStep
        case .inputMonitoring: inputMonitoringStep
        case .model: modelStep
        case .done: doneStep
        }
    }

    // MARK: - Footer button row

    private var footerBar: some View {
        HStack {
            if step != .welcome {
                Button("Zurück") { goBack() }
            }
            Spacer()
            if step != .welcome, step != .done, !isFulfilled(step) {
                Button("Später erledigen") { skipCurrentStep() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Button(primaryButtonTitle) { advance() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdvance)
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome: return "Los geht’s"
        case .done: return "Setup abschließen"
        default: return "Weiter"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .welcome, .done: return true
        default: return isFulfilled(step)
        }
    }

    // MARK: - Step fulfilment & navigation

    private func isFulfilled(_ item: Step) -> Bool {
        switch item {
        case .welcome, .done:
            return true
        case .language:
            // A choice is always preselected; the step never blocks.
            return true
        case .microphone:
            return coordinator.permissions.microphone == .granted
        case .accessibility:
            return coordinator.permissions.accessibility == .granted
        case .inputMonitoring:
            return coordinator.permissions.inputMonitoring == .granted
        case .model:
            guard modelState == .installed else { return false }
            // Rewrite is optional: only block while its model is genuinely
            // on the way. Unreachable Ollama shows a notice instead.
            guard coordinator.settings.rewriteEnabled,
                  !coordinator.settings.ollamaModel.isEmpty,
                  status.ollamaReachable else { return true }
            return status.ollamaPullModel == nil
                && status.ollamaModels.contains(coordinator.settings.ollamaModel)
        }
    }

    private func advance() {
        if step == .done {
            finishSetup()
        } else {
            // Fulfilling a previously skipped step clears its skip marker.
            if isFulfilled(step) { skipped.remove(step) }
            goNext()
        }
    }

    private func goNext() {
        let next = Step(rawValue: step.rawValue + 1) ?? .done
        step = next
        if next.rawValue > maxVisitedStep.rawValue { maxVisitedStep = next }
    }

    private func goBack() {
        step = Step(rawValue: step.rawValue - 1) ?? .welcome
    }

    private func skipCurrentStep() {
        skipped.insert(step)
        goNext()
    }

    private func finishSetup() {
        coordinator.settings.hasCompletedOnboarding = true
        coordinator.settings.save()
        dismiss()
    }

    /// Granting Input Monitoring makes macOS force-quit and reopen the app,
    /// killing the assistant mid-run — so a successful setup could never
    /// reach the done step. On (re)open, resume at the first unfulfilled
    /// step instead of walking the user through Willkommen again; with
    /// everything already set up that is the done step, one click from
    /// finishing. A completely untouched setup still starts at Willkommen.
    private func resumeAtFirstOpenStep() {
        if ModelStore.shared.isModelInstalled(variant: coordinator.settings.whisperVariant) {
            modelState = .installed
        }
        let firstOpen = [Step.microphone, .accessibility, .inputMonitoring, .model]
            .first { !isFulfilled($0) }
        guard firstOpen != .microphone else { return }
        step = firstOpen ?? .done
        maxVisitedStep = step
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Willkommen bei Voicy")
                .font(.largeTitle.bold())
            Text("Voicy verwandelt deine Sprache in Text — komplett lokal auf deinem Mac, ohne Cloud und ohne Account.")
            Text("Dieser Assistent richtet Voicy in fünf kurzen Schritten ein:")
            VStack(alignment: .leading, spacing: 8) {
                Label("Sprache — wir empfehlen dir die passenden Modelle", systemImage: "globe")
                Label("Mikrofon — damit Voicy dich aufnehmen kann", systemImage: "mic")
                Label("Bedienungshilfen — damit Voicy Text einfügen kann", systemImage: "accessibility")
                Label("Eingabeüberwachung — damit der Hotkey überall funktioniert", systemImage: "keyboard")
                Label("Modelle — werden einmalig geladen und bleiben lokal", systemImage: "arrow.down.circle")
            }
            Text("Dauert etwa zwei Minuten. Jeden Schritt kannst du überspringen und später im Menü nachholen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Step 1: Language & recommendation

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(icon: "globe", title: "Sprache")
            Text("In welcher Sprache diktierst du hauptsächlich? Voicy wählt danach die passenden Modelle für dich aus.")

            HStack(spacing: 10) {
                languageCard("Deutsch", code: "de")
                languageCard("English", code: "en")
            }
            Picker("Weitere Sprachen", selection: Binding(
                get: { ["de", "en"].contains(languageChoice) ? "" : languageChoice },
                set: { if !$0.isEmpty { selectLanguage($0) } }
            )) {
                Text("—").tag("")
                Text("Français").tag("fr")
                Text("Español").tag("es")
                Text("Automatisch erkennen").tag("auto")
            }

            OnboardingNoticeBox(
                style: .info,
                text: transcriptionRecommendation
            )

            Toggle(isOn: Binding(
                get: { rewriteWanted },
                set: { rewriteWanted = $0; applyChoices() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rewrite aktivieren (empfohlen)")
                    Text("Formuliert Diktate auf Wunsch um, z. B. höflicher. Modell: Qwen3 4B Instruct (2,5 GB, ~1 s pro Rewrite) — benötigt Ollama. Ohne Rewrite fügt ⌥⌃ den Text unverändert ein; aktivierbar bleibt es jederzeit in den Einstellungen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
        }
        .onAppear(perform: initLanguageStepIfNeeded)
    }

    private func languageCard(_ title: String, code: String) -> some View {
        let isSelected = languageChoice == code
        return Button {
            selectLanguage(code)
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.15)) : AnyShapeStyle(.regularMaterial),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var transcriptionRecommendation: String {
        switch languageChoice {
        case "de":
            return "Empfehlung für Deutsch: Transkription mit „Large v3 Turbo“ (597 MB) — beste Erkennung, auch bei Namen und Fachbegriffen."
        case "en":
            return "Empfehlung für Englisch: Transkription mit „Large v3 Turbo“ (597 MB) — beste Erkennung, auch bei Namen und Fachbegriffen."
        default:
            return "Voicy startet mit dem mehrsprachigen Modell „Small“ (463 MB). In den Einstellungen kannst du jederzeit ein anderes Modell wählen."
        }
    }

    /// Preselect from the system locale on a fresh install, then persist the
    /// initial recommendation so skipping the rest of the assistant still
    /// leaves consistent settings behind.
    private func initLanguageStepIfNeeded() {
        guard !didInitLanguageStep else { return }
        didInitLanguageStep = true
        if let saved = coordinator.settings.language, coordinator.settings.hasCompletedOnboarding {
            // Re-opened assistant: reflect the existing configuration.
            languageChoice = saved
            rewriteWanted = coordinator.settings.rewriteEnabled
            return
        }
        let system = Locale.current.language.languageCode?.identifier
        languageChoice = system == "de" ? "de" : "en"
        applyChoices()
    }

    private func selectLanguage(_ code: String) {
        languageChoice = code
        applyChoices()
    }

    private func applyChoices() {
        coordinator.settings.language = languageChoice == "auto" ? nil : languageChoice
        if ["de", "en"].contains(languageChoice) {
            coordinator.settings.whisperVariant = Self.recommendedWhisperVariant
        }
        coordinator.settings.rewriteEnabled = rewriteWanted
        coordinator.settings.ollamaModel = rewriteWanted ? Self.recommendedOllamaModel : ""
        coordinator.statusModel.selectedOllamaModel = coordinator.settings.ollamaModel
        coordinator.settings.save()
        // The whisper variant may have changed — invalidate a previous check.
        if modelState == .installed,
           !ModelStore.shared.isModelInstalled(variant: coordinator.settings.whisperVariant) {
            modelState = .idle
        }
    }

    // MARK: - Step 2: Microphone

    private var microphoneStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(icon: "mic.fill", title: "Mikrofon")
            Text("Voicy braucht Zugriff auf dein Mikrofon, um deine Sprache aufzunehmen. Aufgenommen wird nur, während du den Hotkey gedrückt hältst — und die Aufnahme verlässt deinen Mac nie.")
            // Only promise a system dialog while one can actually still appear.
            if coordinator.permissions.microphone != .granted {
                Text("macOS zeigt dir gleich einen Dialog. Klicke dort auf „Erlauben“.")
                    .foregroundStyle(.secondary)
            }
            OnboardingStatusCard(title: "Mikrofonzugriff", badge: microphoneBadge)
            if coordinator.permissions.microphone == .denied {
                OnboardingNoticeBox(
                    style: .warning,
                    text: "Du hast den Mikrofonzugriff abgelehnt. macOS zeigt diesen Dialog nur ein einziges Mal — erlaube den Zugriff jetzt manuell: Öffne die Systemeinstellungen, gehe zu „Datenschutz & Sicherheit“ → „Mikrofon“ und aktiviere Voicy. Der Status hier wird automatisch grün.",
                    buttonTitle: "Systemeinstellungen öffnen"
                ) {
                    coordinator.permissions.openSystemSettings(for: .microphone)
                }
            }
            if coordinator.permissions.microphone != .granted {
                consequenceFootnote("Ohne Mikrofonzugriff kann Voicy nichts aufnehmen.")
            }
        }
        .onAppear {
            // Trigger the system prompt the moment the user lands on this step.
            // requestMicrophone() is idempotent: no-op if already granted.
            Task { _ = await coordinator.permissions.requestMicrophone() }
        }
    }

    private var microphoneBadge: StatusBadge.Kind {
        switch coordinator.permissions.microphone {
        case .granted: return .granted
        case .notDetermined: return .pending
        case .denied: return .denied
        }
    }

    // MARK: - Step 2: Accessibility

    private var accessibilityStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(icon: "accessibility", title: "Bedienungshilfen")
            Text("Voicy fügt den fertigen Text automatisch dort ein, wo dein Cursor gerade steht. Dafür verlangt macOS die Berechtigung „Bedienungshilfen“.")
            // Only promise a system dialog while one can actually still appear.
            if coordinator.permissions.accessibility != .granted {
                Text("macOS zeigt gleich einen Hinweis-Dialog. Klicke dort auf „Systemeinstellungen öffnen“ und aktiviere Voicy in der Liste. Der Status hier wird automatisch grün.")
                    .foregroundStyle(.secondary)
            }
            // AXIsProcessTrusted() never reports "notDetermined" — the default
            // state is .denied, so we show a non-alarming orange badge instead
            // of a red "Verweigert" one.
            OnboardingStatusCard(
                title: "Bedienungshilfen",
                badge: coordinator.permissions.accessibility == .granted ? .granted : .notYetAllowed
            )
            if coordinator.permissions.accessibility != .granted {
                OnboardingNoticeBox(
                    style: .info,
                    text: "Kein Dialog erschienen? macOS zeigt ihn nur ein einziges Mal. Du kannst Voicy jederzeit direkt aktivieren: Systemeinstellungen → „Datenschutz & Sicherheit“ → „Bedienungshilfen“.",
                    buttonTitle: "Systemeinstellungen öffnen"
                ) {
                    coordinator.permissions.openSystemSettings(for: .accessibility)
                }
                consequenceFootnote("Ohne Bedienungshilfen kann Voicy keinen Text einfügen.")
            }
        }
        .onAppear {
            // Auto-trigger the prompt on appearance. Required so the Voicy.app
            // entry actually shows up in System Settings → Privacy →
            // Accessibility (smoke-test finding #6). Idempotent.
            coordinator.permissions.requestAccessibility()
        }
    }

    // MARK: - Step 3: Input Monitoring

    private var inputMonitoringStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(icon: "keyboard", title: "Eingabeüberwachung")
            Text("Der Voicy-Hotkey ist die rechte ⌥-Taste. Damit Voicy sie in jeder App erkennen kann, verlangt macOS die Berechtigung „Eingabeüberwachung“. Voicy reagiert dabei ausschließlich auf die Modifier-Tasten ⌥ und ⌃ — Tastatureingaben werden nicht aufgezeichnet.")
            // Only promise a system dialog while one can actually still appear.
            if coordinator.permissions.inputMonitoring != .granted {
                Text("macOS zeigt gleich einen Dialog. Klicke dort auf „Systemeinstellungen öffnen“ und aktiviere Voicy in der Liste.")
                    .foregroundStyle(.secondary)
            }
            OnboardingStatusCard(title: "Eingabeüberwachung", badge: inputMonitoringBadge)
            if coordinator.permissions.inputMonitoring != .granted {
                OnboardingNoticeBox(
                    style: .info,
                    text: "Kein Dialog erschienen? macOS zeigt ihn nur ein einziges Mal. Aktiviere Voicy direkt: Systemeinstellungen → „Datenschutz & Sicherheit“ → „Eingabeüberwachung“.",
                    buttonTitle: "Systemeinstellungen öffnen"
                ) {
                    coordinator.permissions.openSystemSettings(for: .inputMonitoring)
                }
                consequenceFootnote("Ohne Eingabeüberwachung funktioniert der Hotkey nicht.")
            }
            if inputMonitoringGrantedDuringSession {
                // The CGEventTap in HotkeyEngine can only be created after an
                // app relaunch when the permission was granted at runtime.
                OnboardingNoticeBox(
                    style: .restart,
                    text: "Fast geschafft: Damit der Hotkey aktiv wird, muss Voicy einmal neu gestartet werden. Du wirst im letzten Schritt daran erinnert."
                )
            }
        }
        .onAppear {
            // Auto-trigger the prompt on appearance so the Voicy.app entry is
            // registered in System Settings → Privacy → Input Monitoring
            // (smoke-test finding #6). Idempotent.
            coordinator.permissions.requestInputMonitoring()
        }
    }

    private var inputMonitoringBadge: StatusBadge.Kind {
        switch coordinator.permissions.inputMonitoring {
        case .granted: return .granted
        case .notDetermined: return .pending
        // IOHIDCheckAccess reports .denied even without an active refusal, so
        // orange "Noch nicht erlaubt" instead of red "Verweigert".
        case .denied: return .notYetAllowed
        }
    }

    private var inputMonitoringGrantedDuringSession: Bool {
        inputMonitoringGrantedAtLaunch == false
            && coordinator.permissions.inputMonitoring == .granted
    }

    // MARK: - Step 4: Model download

    private var whisperDisplayName: String {
        WhisperModelCatalog.option(for: coordinator.settings.whisperVariant)?.displayName
            ?? coordinator.settings.whisperVariant
    }

    private var modelStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader(icon: "arrow.down.circle", title: "Modelle")
            Text("Voicy lädt die empfohlenen Modelle einmalig herunter. Sie bleiben lokal auf deinem Mac — nichts wird in die Cloud geschickt.")

            switch modelState {
            case .idle:
                OnboardingStatusCard(title: "Transkription: \(whisperDisplayName)", badge: .pending)
            case .downloading(let fraction):
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: fraction)
                        .frame(maxWidth: .infinity)
                    Text("Lade Modell … \(Int((fraction * 100).rounded())) %")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                OnboardingStatusCard(title: "Transkription: \(whisperDisplayName)", badge: .pending)
            case .installed:
                OnboardingStatusCard(title: "Transkription: \(whisperDisplayName)", badge: .installed)
            case .failed(let message):
                OnboardingStatusCard(title: "Transkription: \(whisperDisplayName)", badge: .pending)
                OnboardingNoticeBox(
                    style: .warning,
                    text: "Der Download ist fehlgeschlagen. Prüfe deine Internetverbindung und versuche es dann erneut.",
                    detail: message,
                    buttonTitle: "Erneut versuchen"
                ) {
                    startModelDownload()
                }
            }

            rewriteModelSection

            if !isFulfilled(.model) {
                consequenceFootnote("Ohne Transkriptionsmodell kann Voicy nicht arbeiten. Überspringst du den Schritt, lädt Voicy das Modell beim nächsten Start im Hintergrund nach.")
            }
        }
        .onAppear { startModelInstallIfNeeded() }
        .onChange(of: modelState) { _, newState in
            if newState == .installed { startOllamaPullIfNeeded() }
        }
    }

    /// Optional rewrite model: pulled via the local Ollama server. Missing
    /// Ollama is a notice, not a blocker — the feature stays available in
    /// the settings later.
    @ViewBuilder
    private var rewriteModelSection: some View {
        if coordinator.settings.rewriteEnabled, !coordinator.settings.ollamaModel.isEmpty {
            let tag = coordinator.settings.ollamaModel
            if !status.ollamaReachable {
                OnboardingNoticeBox(
                    style: .info,
                    text: "Für Rewrite braucht Voicy die kostenlose App „Ollama“ (ollama.com) — sie wurde nicht gefunden. Du kannst das Rewrite-Modell später jederzeit in den Einstellungen laden."
                )
            } else if status.ollamaModels.contains(tag) {
                OnboardingStatusCard(title: "Rewrite: \(tag)", badge: .installed)
            } else if status.ollamaPullModel == tag {
                VStack(alignment: .leading, spacing: 6) {
                    if let fraction = status.ollamaPullProgress {
                        ProgressView(value: fraction)
                            .frame(maxWidth: .infinity)
                        Text("Lade Rewrite-Modell … \(Int((fraction * 100).rounded())) %")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                OnboardingStatusCard(title: "Rewrite: \(tag)", badge: .pending)
            } else {
                OnboardingStatusCard(title: "Rewrite: \(tag)", badge: .pending)
            }
        }
    }

    private func startOllamaPullIfNeeded() {
        guard coordinator.settings.rewriteEnabled else { return }
        let tag = coordinator.settings.ollamaModel
        guard !tag.isEmpty,
              status.ollamaReachable,
              !status.ollamaModels.contains(tag),
              status.ollamaPullModel == nil else { return }
        coordinator.downloadOllamaModel(tag)
    }

    /// Auto-start on entering the step: quick disk check first, then download.
    /// Re-entering the step reuses a running download task instead of starting
    /// a second one. Skipping the step does NOT cancel a running download.
    private func startModelInstallIfNeeded() {
        if modelState != .installed {
            if ModelStore.shared.isModelInstalled(variant: coordinator.settings.whisperVariant) {
                modelState = .installed
            } else if modelDownloadTask == nil {
                startModelDownload()
            }
        }
        if modelState == .installed { startOllamaPullIfNeeded() }
    }

    private func startModelDownload() {
        modelState = .downloading(0)
        let variant = coordinator.settings.whisperVariant
        modelDownloadTask = Task {
            do {
                _ = try await ModelStore.shared.ensureModel(
                    variant: variant,
                    progress: { fraction in
                        Task { @MainActor in
                            if case .downloading = modelState {
                                modelState = .downloading(fraction)
                            }
                        }
                    }
                )
                modelState = .installed
                // Download ≠ loaded engine: kick off preparation so the
                // tokenizer is fetched and the model actually loads now.
                coordinator.retryWhisperPreparation()
            } catch {
                modelState = .failed(error.localizedDescription)
            }
            modelDownloadTask = nil
        }
    }

    // MARK: - Step 5: Done

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(allRequirementsMet ? "Alles bereit!" : "Fast geschafft")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 6) {
                checklistRow(
                    title: "Mikrofon",
                    fulfilled: coordinator.permissions.microphone == .granted,
                    fulfilledBadge: .granted,
                    target: .microphone
                )
                checklistRow(
                    title: "Bedienungshilfen",
                    fulfilled: coordinator.permissions.accessibility == .granted,
                    fulfilledBadge: .granted,
                    target: .accessibility
                )
                checklistRow(
                    title: "Eingabeüberwachung",
                    fulfilled: coordinator.permissions.inputMonitoring == .granted,
                    fulfilledBadge: .granted,
                    target: .inputMonitoring
                )
                checklistRow(
                    title: "Spracherkennungsmodell",
                    fulfilled: modelState == .installed,
                    fulfilledBadge: .installed,
                    target: .model
                )
            }

            if !allRequirementsMet {
                Text("Offene Punkte erreichst du jederzeit über „Setup abschließen“ im Voicy-Menü in der Menüleiste.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            hotkeyCard

            if inputMonitoringGrantedDuringSession {
                OnboardingNoticeBox(
                    style: .restart,
                    text: "Die Eingabeüberwachung wurde gerade erst erlaubt. Starte Voicy einmal neu, damit der Hotkey funktioniert.",
                    buttonTitle: "Voicy neu starten"
                ) {
                    relaunchApp()
                }
            }
        }
    }

    private var allRequirementsMet: Bool {
        coordinator.permissions.allGranted && modelState == .installed
    }

    private func checklistRow(
        title: String,
        fulfilled: Bool,
        fulfilledBadge: StatusBadge.Kind,
        target: Step
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            if !fulfilled {
                Button("Nachholen") { step = target }
                    .buttonStyle(.link)
            }
            StatusBadge(kind: fulfilled ? fulfilledBadge : .skipped)
        }
    }

    private var hotkeyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("So benutzt du Voicy").font(.headline)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                OnboardingKeycap(keys: "⌥")
                Text("Rechte ⌥-Taste gedrückt halten — sprechen — loslassen: Voicy fügt den Text an der Cursor-Position ein.")
                    .font(.callout)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                OnboardingKeycap(keys: "⌥⌃")
                Text("Rechte ⌥-Taste + ⌃ gedrückt halten: Voicy formuliert das Gesagte im aktiven Rewrite-Stil um.")
                    .font(.callout)
            }
            Text("Den aktiven Stil und das Ollama-Modell wählst du im Voicy-Menü in der Menüleiste.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    /// Relaunches the app so the hotkey event tap can be created with the
    /// freshly granted Input Monitoring permission.
    private func relaunchApp() {
        // The restart button is the wizard's own recommended exit from the
        // done step — persist completion exactly like finishSetup() does,
        // otherwise the relaunched app would start the wizard from scratch.
        coordinator.settings.hasCompletedOnboarding = true
        coordinator.settings.save()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }

    // MARK: - Shared pieces

    private func stepHeader(icon: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            Text(title).font(.title2.bold())
        }
    }

    private func consequenceFootnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
