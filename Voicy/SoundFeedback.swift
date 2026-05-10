import AppKit
import Foundation

/// Tiny wrapper around the system sounds in `/System/Library/Sounds/` for
/// audible state-transition cues. Sounds only play when the user has
/// `soundFeedback` enabled in Settings; otherwise calls are no-ops.
enum SoundFeedback {
    enum Cue {
        case startRecording
        case stopRecording
        case error

        fileprivate var systemName: NSSound.Name {
            switch self {
            case .startRecording: return NSSound.Name("Tink")
            case .stopRecording:  return NSSound.Name("Pop")
            case .error:          return NSSound.Name("Funk")
            }
        }
    }

    /// Plays `cue` if `enabled` is true. Safe to call from any thread —
    /// `NSSound.play()` is documented as thread-safe.
    static func play(_ cue: Cue, when enabled: Bool) {
        guard enabled else { return }
        NSSound(named: cue.systemName)?.play()
    }
}
