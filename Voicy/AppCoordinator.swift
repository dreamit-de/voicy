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
        startHotkeyLoop()
        startOllamaPolling()
        prepareWhisperIfPossible()
    }

    public func setOllamaModel(_ model: String) {
        statusModel.selectedOllamaModel = model
        settings.ollamaModel = model
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
            statusModel.state = .rewriting
            outputText = await rewrite(text)
        }

        await inserter.insert(outputText)
        statusModel.state = .idle
    }

    private func rewrite(_ text: String) async -> String {
        let style = styleStore.activeStyle
        let model = settings.ollamaModel
        do {
            return try await rewriter.rewrite(text, using: style, model: model)
        } catch {
            await notify(
                "Rewrite nicht möglich",
                body: "\(error.localizedDescription) — Original-Transkript wird eingefügt."
            )
            return text
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
                    if self.statusModel.selectedOllamaModel.isEmpty, let first = models.first {
                        self.statusModel.selectedOllamaModel = first
                        self.settings.ollamaModel = first
                        self.settings.save()
                    }
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    private func prepareWhisperIfPossible() {
        modelPrepTask = Task { [weak self] in
            guard let self else { return }
            // We try to prepare immediately; first-launch will block on download via the
            // Onboarding window which hosts its own progress UI. After that, prepare is fast.
            do {
                if let actor = self.transcription as? WhisperEngine {
                    try await actor.prepare()
                }
                await MainActor.run { self.statusModel.whisperReady = true }
            } catch {
                self.log.error("Whisper preparation failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run { self.statusModel.whisperReady = false }
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
