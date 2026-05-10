# Changelog

## [Unreleased]

### Added
- Initial macOS menu bar app scaffold (`Voicy.app`).
- `HotkeyEngine`: global Right-Option / Right-Option+Control tracking via `CGEventTap`, with auto-recovery from system tap timeouts.
- `AudioCapture`: `AVAudioEngine` recording resampled to 16 kHz mono Float32 for WhisperKit.
- `Transcription`: WhisperKit wrapper with `ModelStore` for first-launch `openai_whisper-small` download.
- `RewriteService`: `OllamaClient` (detection via `/api/tags`, generation via `/api/generate`) plus a persisted `RewriteStyleStore` with a built-in Friendly style and one editable Custom slot.
- `TextInsertion`: pasteboard snapshot → `setString` → synthetic ⌘V → restore, serialized via Swift `actor`.
- `PermissionsKit`: live status + request flows for Microphone, Accessibility, and Input Monitoring.
- SwiftUI Settings (General / Transcription / Rewrite / Permissions tabs) and 4-step Onboarding window.
- `XcodeGen` `project.yml` as the source of truth for the Xcode project.
- Manual end-to-end test plan in `docs/manual-tests.md`.
- Unit tests for `RewriteStyleStore` persistence and `AppSettings` round-tripping.

### Modes
- **Normal** — held Right-Option: dictation only.
- **Friendly** — held Right-Option + Control with Friendly active: built-in friendly rewrite via Ollama.
- **Custom** — held Right-Option + Control with Custom active: user-defined system prompt.
