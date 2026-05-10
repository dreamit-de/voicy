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

@MainActor
public final class StatusModel: ObservableObject {
    @Published public var state: AppState = .idle
    @Published public var whisperReady: Bool = false
    @Published public var ollamaReachable: Bool = false
    @Published public var ollamaModels: [String] = []
    @Published public var selectedOllamaModel: String = ""
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
            return whisperReady ? "Bereit" : "Whisper-Modell wird vorbereitet…"
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
