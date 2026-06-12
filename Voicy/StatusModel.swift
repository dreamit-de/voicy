import Combine
import Foundation
import SwiftUI

public enum AppState: Equatable, Sendable {
    case idle
    case recording(HotkeyMode)
    case transcribing
    case rewriting
    case error(String)

    var isBusy: Bool {
        switch self {
        case .idle, .error: return false
        case .recording, .transcribing, .rewriting: return true
        }
    }
}

public enum WhisperStatus: Equatable, Sendable {
    case loading
    case ready
    case failed(String)
}

@MainActor
public final class StatusModel: ObservableObject {
    @Published public var state: AppState = .idle
    @Published public var whisper: WhisperStatus = .loading
    /// Download progress in [0, 1] while a model is being fetched; nil when
    /// no download is running (loading an installed model reports nothing).
    @Published public var whisperProgress: Double? = nil

    public var whisperReady: Bool { whisper == .ready }
    @Published public var ollamaReachable: Bool = false
    @Published public var ollamaModels: [String] = []
    @Published public var selectedOllamaModel: String = ""
    /// Last rewrite/ping failure. Reachability alone is not honest — a model
    /// can be listed by `/api/tags` and still fail to generate. Set on rewrite
    /// failure, cleared on success, a passed connection test, or model change.
    @Published public var rewriteError: String? = nil
    @Published public var rewriteTestRunning: Bool = false
    @Published public var lastError: String? = nil

    public init() {}

    public var menuBarSymbol: String {
        switch state {
        case .idle:
            return whisperReady ? "mic" : "mic.slash"
        case .recording:
            return "mic.fill"
        case .transcribing:
            return "waveform"
        case .rewriting:
            return "wand.and.stars"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    public var statusHeadline: String {
        switch state {
        case .idle:
            switch whisper {
            case .ready: return "Bereit"
            case .loading: return "Whisper-Modell wird vorbereitet…"
            case .failed: return "Whisper nicht verfügbar"
            }
        case .recording(.normal):
            return "Aufnahme (Normal)"
        case .recording(.rewrite):
            return "Aufnahme (Rewrite)"
        case .transcribing:
            return "Transkribiere…"
        case .rewriting:
            return "Rewrite läuft…"
        case .error(let message):
            return "Fehler: \(message)"
        }
    }
}
