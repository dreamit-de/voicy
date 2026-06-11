# Changelog

## [Unreleased]

### Fixed
- Setup assistant resumes at the first unfulfilled step when reopened. Granting Input Monitoring makes macOS force-quit and reopen the app mid-assistant, so a successful setup could never reach the final step — after the relaunch it now lands one click away from finishing instead of restarting at "Willkommen".
- Internal builds are signed with a stable CI certificate instead of ad-hoc, so TCC permission grants (Microphone, Accessibility, Input Monitoring) survive updates and the setup no longer has to be repeated after every update.

## [0.2.1] — 2026-06-11

### Added
- App icon (dreamIT microphone logo); generator pipeline in `scripts/compose-app-icon.swift`, master at `docs/assets/voicy-logo-master.png`.

### Fixed
- Right-Option hotkey never triggered the normal dictation mode: the right-alt device mask was mistakenly `NX_CONTROLMASK`, so dictation only worked as Ctrl+Option rewrite. Mode derivation is now a tested pure function.
- Whisper preparation no longer hangs forever on "Whisper lädt…": corrupt model downloads self-heal (wipe + re-download once), preparation retries with exponential backoff, and load failures surface in the menu with an error banner and retry button.
- Tokenizer files are persisted under `Models/Tokenizers`, so launches after the first successful load no longer need huggingface.co.
- Onboarding starts real engine preparation after the model download instead of only flipping the status flag.

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
