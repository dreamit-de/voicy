# Changelog

## [Unreleased]

## [0.2.0] — 2026-06-11

### Added
- Reworked onboarding wizard with per-step validation and explicit error handling (including recovery paths when a permission is denied).
- Sparkle auto-update (feed: `https://dreamit-de.github.io/voicy/appcast.xml`) with a visible update hint in the menu bar for the background app (gentle reminders).

### CI / CD
- `Internal Release` workflow now signs the DMG with Sparkle's EdDSA key (`sign_update`, repo secret `SPARKLE_PRIVATE_KEY`), generates a validated `appcast.xml`, and publishes it to GitHub Pages (`gh-pages`) after the GitHub Release — so existing installs update automatically.

## [0.1.0] — 2026-06-08

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

### CI / CD
- GitHub Actions `CI` workflow: SwiftLint, plist + entitlements validation, build & XCTest on macOS 14 / arm64, gitleaks secret scan.
- GitHub Actions `CodeQL` workflow for Swift static analysis (PR + weekly schedule).
- GitHub Actions `Release` workflow (workflow_dispatch): archive → Developer ID export → notarize + staple → DMG → draft GitHub Release.
- Dependabot for GitHub Actions and SwiftPM weekly.
- `CODEOWNERS`, PR template, `SECURITY.md`, `.swiftlint.yml`.

### Modes
- **Normal** — held Right-Option: dictation only.
- **Friendly** — held Right-Option + Control with Friendly active: built-in friendly rewrite via Ollama.
- **Custom** — held Right-Option + Control with Custom active: user-defined system prompt.
