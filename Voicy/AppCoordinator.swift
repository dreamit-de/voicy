import AppKit
import Combine
import Foundation
import UserNotifications
import os

@MainActor
public final class AppCoordinator: ObservableObject {
    public let permissions: Permissions
    public let statusModel: StatusModel
    public let styleStore: RewriteStyleStore
    public let hotkeyEngine: HotkeyEngineProtocol
    public let recorder: AudioRecorderProtocol
    public let transcription: TranscriptionService
    public let inserter: TextInserter
    public let rewriter: RewriteService

    @Published public var settings = AppSettings.load()

    private let log = Logger(subsystem: "de.dreamit.voicy", category: "AppCoordinator")
    private var hotkeyTask: Task<Void, Never>?
    private var ollamaPollTask: Task<Void, Never>?
    private var modelPrepTask: Task<Void, Never>?
    private var started = false

    public init(
        permissions: Permissions = Permissions(),
        styleStore: RewriteStyleStore = RewriteStyleStore(),
        hotkeyEngine: HotkeyEngineProtocol = HotkeyEngine(),
        recorder: AudioRecorderProtocol = AudioRecorder(),
        transcription: TranscriptionService = WhisperEngine(),
        inserter: TextInserter = Inserter(),
        rewriter: RewriteService = OllamaClient()
    ) {
        self.permissions = permissions
        self.styleStore = styleStore
        self.statusModel = StatusModel()
        self.hotkeyEngine = hotkeyEngine
        self.recorder = recorder
        self.transcription = transcription
        self.inserter = inserter
        self.rewriter = rewriter
        self.statusModel.selectedOllamaModel = settings.ollamaModel
    }

    /// Called once from the launch hook in `VoicyApp`. Idempotent — the menu
    /// bar label can re-appear, so guard against starting the loops twice.
    public func start() {
        guard !started else { return }
        started = true
        hotkeyEngine.updateConfig(settings.hotkeyConfig)
        startHotkeyLoop()
        startOllamaPolling()
        prepareWhisperIfPossible()
    }

    /// Changes the push-to-talk trigger and applies it to the running engine.
    public func setHotkeyPrimary(_ modifier: HotkeyModifier) {
        settings.hotkeyPrimary = modifier.rawValue
        settings.save()
        hotkeyEngine.updateConfig(settings.hotkeyConfig)
    }

    /// Switches the Whisper model: persists the choice, unloads the current
    /// engine and drives download + load through the usual preparation path
    /// (including its retry/backoff and the visible error state).
    public func setWhisperModel(_ variant: String) {
        guard variant != settings.whisperVariant else { return }
        settings.whisperVariant = variant
        settings.save()
        retryWhisperPreparation()
    }

    /// Downloads a curated Ollama model and selects it as the global default
    /// once installed. While running, the menu's Ollama dot shows orange and
    /// settings show live progress.
    public func downloadOllamaModel(_ tag: String) {
        performOllamaPull(tag) { [weak self] installed in
            self?.setOllamaModel(installed)
        }
    }

    /// Downloads an Ollama model and pins it to a single rewrite style (the
    /// per-function override), without touching the global default model.
    public func downloadStyleModel(_ styleID: UUID, tag: String) {
        performOllamaPull(tag) { [weak self] installed in
            self?.styleStore.setModel(installed, for: styleID)
            self?.statusModel.rewriteError = nil
        }
    }

    /// Pins (or clears, with "") a per-style model override. Empty string makes
    /// the style fall back to the global default model again.
    public func setStyleModel(_ styleID: UUID, _ model: String) {
        styleStore.setModel(model, for: styleID)
        statusModel.rewriteError = nil
    }

    /// Shared pull machinery for both the global picker and per-style overrides.
    /// `onInstalled` runs on the main actor after the model is confirmed on disk.
    private func performOllamaPull(_ tag: String, onInstalled: @escaping @MainActor (String) -> Void) {
        guard statusModel.ollamaPullModel == nil else { return }
        statusModel.ollamaPullModel = tag
        statusModel.ollamaPullProgress = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.rewriter.pull(model: tag, progress: { fraction in
                    Task { @MainActor [weak self] in
                        self?.statusModel.ollamaPullProgress = fraction
                    }
                })
                await MainActor.run {
                    self.statusModel.ollamaPullModel = nil
                    self.statusModel.ollamaPullProgress = nil
                    if !self.statusModel.ollamaModels.contains(tag) {
                        self.statusModel.ollamaModels.append(tag)
                    }
                    onInstalled(tag)
                }
            } catch {
                self.log.error("Ollama pull failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    self.statusModel.ollamaPullModel = nil
                    self.statusModel.ollamaPullProgress = nil
                    self.statusModel.rewriteError = error.localizedDescription
                }
            }
        }
    }

    public func setOllamaModel(_ model: String) {
        statusModel.selectedOllamaModel = model
        // A stale failure from the previous model should not stick to the new one.
        statusModel.rewriteError = nil
        settings.ollamaModel = model
        settings.rewriteEnabled = !model.isEmpty
        settings.save()
    }

    /// Turns the rewrite feature off: the ⌥⌃ hotkey inserts the plain
    /// transcript and no model gets auto-selected.
    public func disableRewrite() {
        statusModel.selectedOllamaModel = ""
        statusModel.rewriteError = nil
        settings.ollamaModel = ""
        settings.rewriteEnabled = false
        settings.save()
    }

    public func setActiveStyle(_ id: UUID) {
        styleStore.setActive(id)
    }

    // MARK: - Hotkey loop

    private func startHotkeyLoop() {
        do {
            try hotkeyEngine.start()
        } catch {
            log.error("Hotkey engine failed to start: \(error.localizedDescription, privacy: .public)")
            statusModel.lastError = "Eingabeüberwachung nicht erlaubt — bitte in den Einstellungen freigeben."
        }
        hotkeyTask = Task { [weak self] in
            guard let stream = self?.hotkeyEngine.events else { return }
            for await event in stream {
                await self?.handle(event)
            }
        }
    }

    private func handle(_ event: HotkeyEvent) async {
        switch event {
        case .pressed(let mode):
            await beginRecording(mode: mode)
        case .released(let mode):
            await finishRecording(mode: mode)
        }
    }

    private func beginRecording(mode: HotkeyMode) async {
        guard case .idle = statusModel.state else { return }
        do {
            try await recorder.start()
            statusModel.state = .recording(mode)
        } catch {
            statusModel.state = .error(error.localizedDescription)
            statusModel.lastError = error.localizedDescription
        }
    }

    private func finishRecording(mode: HotkeyMode) async {
        guard case .recording = statusModel.state else { return }
        let pcm = await recorder.stop()
        statusModel.state = .transcribing

        let text: String
        do {
            text = try await transcription.transcribe(pcm, language: settings.language)
            // transcribe() prepares the engine on demand — if that succeeded
            // while the launch-time preparation had failed, reflect it here.
            statusModel.whisper = .ready
        } catch {
            statusModel.state = .error(error.localizedDescription)
            await notify("Transkription fehlgeschlagen", body: error.localizedDescription)
            statusModel.state = .idle
            return
        }

        guard !text.isEmpty else {
            statusModel.state = .idle
            return
        }

        let outputText: String
        switch mode {
        case .normal:
            outputText = text
        case .rewrite:
            let model = effectiveRewriteModel()
            if !settings.rewriteEnabled || model.isEmpty {
                // Rewrite is opt-in; without a resolvable model the hotkey
                // degrades gracefully to plain dictation.
                outputText = text
            } else {
                statusModel.state = .rewriting
                outputText = await rewrite(text, model: model)
            }
        }

        await inserter.insert(outputText)
        statusModel.state = .idle
    }

    /// The Ollama model the active style will actually use: its own pinned
    /// model when set, otherwise the global default (`settings.ollamaModel`).
    public func effectiveRewriteModel() -> String {
        let style = styleStore.activeStyle
        return style.model.isEmpty ? settings.ollamaModel : style.model
    }

    private func rewrite(_ text: String, model: String) async -> String {
        let style = styleStore.activeStyle
        do {
            let rewritten = try await rewriter.rewrite(text, using: style, model: model)
            statusModel.rewriteError = nil
            return rewritten
        } catch {
            log.error("Rewrite failed: \(error.localizedDescription, privacy: .public)")
            // Notifications are easy to miss (or not authorized) — persist the
            // failure so the menu shows a banner until rewriting works again.
            statusModel.rewriteError = error.localizedDescription
            await notify(
                "Rewrite nicht möglich",
                body: "\(error.localizedDescription) — Original-Transkript wird eingefügt."
            )
            return text
        }
    }

    /// Deep Ollama health check: runs a minimal generate with the selected
    /// model. Catches failures `/api/tags` cannot see, e.g. a model whose
    /// on-disk format the current Ollama version can no longer load.
    public func testRewriteSetup() {
        guard !statusModel.rewriteTestRunning else { return }
        statusModel.rewriteTestRunning = true
        Task { [weak self] in
            guard let self else { return }
            let model = self.effectiveRewriteModel()
            do {
                try await self.rewriter.ping(model: model)
                await MainActor.run {
                    self.statusModel.rewriteError = nil
                    self.statusModel.rewriteTestRunning = false
                }
            } catch {
                await MainActor.run {
                    self.statusModel.rewriteError = error.localizedDescription
                    self.statusModel.rewriteTestRunning = false
                }
            }
        }
    }

    // MARK: - Background tasks

    private func startOllamaPolling() {
        ollamaPollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let models = (try? await self.rewriter.availableModels()) ?? []
                await MainActor.run {
                    self.statusModel.ollamaReachable = !models.isEmpty
                    self.statusModel.ollamaModels = models
                    // Auto-select only while rewrite is wanted — picking a
                    // model behind the user's back would silently re-enable it.
                    if self.settings.rewriteEnabled,
                       self.statusModel.selectedOllamaModel.isEmpty, let first = models.first {
                        self.statusModel.selectedOllamaModel = first
                        self.settings.ollamaModel = first
                        self.settings.save()
                    }
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    /// Cancels a running preparation attempt and starts over. Used by the
    /// menu's "Erneut versuchen" button and by onboarding after the model
    /// download finishes, so the engine actually loads (incl. tokenizer).
    public func retryWhisperPreparation() {
        modelPrepTask?.cancel()
        statusModel.whisper = .loading
        prepareWhisperIfPossible()
    }

    private func prepareWhisperIfPossible() {
        modelPrepTask = Task { [weak self] in
            // First-launch blocks on the model download via the Onboarding
            // window which hosts its own progress UI; after that, prepare is
            // fast. Preparation can still fail transiently (e.g. the tokenizer
            // fetch needs huggingface.co once), so retry with backoff instead
            // of leaving the app stuck on "lädt…" until the next restart.
            var delay: Duration = .seconds(2)
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    if let actor = self.transcription as? WhisperEngine {
                        // Align the engine with the persisted variant — the
                        // settings picker may have changed it. No-op when equal.
                        await actor.switchModel(to: self.settings.whisperVariant)
                        try await actor.prepare(progress: { fraction in
                            Task { @MainActor [weak self] in
                                self?.statusModel.whisperProgress = fraction
                            }
                        })
                    }
                    await MainActor.run {
                        self.statusModel.whisperProgress = nil
                        self.statusModel.whisper = .ready
                    }
                    return
                } catch {
                    self.log.error("Whisper preparation failed: \(error.localizedDescription, privacy: .public)")
                    await MainActor.run {
                        self.statusModel.whisperProgress = nil
                        self.statusModel.whisper = .failed(error.localizedDescription)
                    }
                    try? await Task.sleep(for: delay)
                    delay = min(delay * 2, .seconds(60))
                }
            }
        }
    }

    private func notify(_ title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
