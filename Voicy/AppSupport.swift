import Foundation

/// Shared on-disk home for the app's data (models, tokenizers, styles).
///
/// The folder was renamed from "Voicy" to "Voice Transcript" alongside the
/// app rename. `root()` migrates the legacy folder once so existing users
/// keep their downloaded models (~600 MB) and saved styles instead of
/// re-downloading. The bundle identifier is unchanged, so this is the only
/// on-disk path that needed migrating.
enum AppSupport {
    static let directoryName = "Voice Transcript"
    private static let legacyName = "Voicy"

    static func root() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let new = base.appendingPathComponent(directoryName, isDirectory: true)
        let old = base.appendingPathComponent(legacyName, isDirectory: true)
        if !fm.fileExists(atPath: new.path), fm.fileExists(atPath: old.path) {
            try? fm.moveItem(at: old, to: new)
        }
        try? fm.createDirectory(at: new, withIntermediateDirectories: true)
        return new
    }
}
