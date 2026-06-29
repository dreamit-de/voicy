# Changelog

## [Unreleased]

## [0.2.9]

### Added
- **Per-function rewrite model** (Settings → „Modell pro Funktion"): each rewrite style can run on its own Ollama model — e.g. a translation model for "German → English" and a different one for "Custom". The default per style is "Standard", which follows the globally selected model, so existing setups are unchanged; picking an uninstalled model downloads it on selection. The transcription model ("Normal") stays the single Whisper model in Settings → Transkription.

### Changed
- **Built-in rewrite style is now "German → English" instead of "Friendly".** Holding the rewrite trigger with the built-in style active translates German dictation into fluent English (English input passes through with light cleanup) — more useful day-to-day than tone-softening. The style keeps its stable identifier, so anyone who had the built-in active stays on it after the upgrade; the editable Custom slot is unchanged. The default rewrite model and Ollama request options were re-tuned so a translation completes in well under 5 s (see `scripts/bench-rewrite.py` and `scripts/bench-transcription/` for the on-device measurements behind the choice).
- **Renamed the app to "Voice Transcript"** (product name, all user-facing text, DMG, docs). The bundle identifier stays `de.dreamit.voicy` and the Xcode target/scheme/Swift module stay `Voicy` on purpose — that technical identity is what TCC permissions and Sparkle updates key on, so changing it would reset both for existing users. The Application Support folder migrates from `Voicy` to `Voice Transcript` on first launch without re-downloading models.

### Added
- **Configurable push-to-talk shortcut** (Settings → Kurzbefehl): choose the trigger modifier (right Option = default, right Command/Control/Shift, or Fn). Only hold-friendly modifier keys are offered, each with a known-conflict hint (macOS exposes no API to enumerate registered global hotkeys, so these are curated notes). The rewrite trigger stays "primary + Control" (or "+ Option" when Control is the primary); the menu headers reflect the chosen keys.
- Rewrite quality overhaul after measuring German output on-device: **Gemma 3 4B** became the recommended rewrite model at the time (better German phrasing and faithful speech acts than Qwen at the same ~1–2 s latency) — later superseded by **Qwen3 4B Instruct** for the German → English default (see the Changed entry above); Gemma 3 12B added as a best-quality option (~3–5 s). The rewrite temperature dropped to 0.3 for steadier, more faithful output, the system prompt forbids preambles and language mixing more firmly, and a safety net strips leftover acknowledgement preambles ("Ja, natürlich.", "Sure!") from model output.

### Added
- Setup assistant asks for the primary dictation language via a single language selector (German default; English, Français, Español, Italiano, auto-detect) and recommends models accordingly: Large v3 Turbo for transcription plus — optionally — Qwen3 4B Instruct for rewrite. Both download in the model step with progress; a missing Ollama is a notice, not a blocker.
- Missing-Ollama guidance: the setup notice links straight to ollama.com/download, Settings show the same link while Ollama is unreachable, and once Ollama appears (even later) the menu offers a one-click "Modell laden" banner with download progress — the assistant also auto-pulls if Ollama shows up while it is open.
- Setup window enlarged to 680×560 so no step needs scrolling.
- Rewrite is opt-in: disabled via the onboarding toggle or the new "Kein Rewrite" option in Settings → Rewrite. When off, ⌥⌃ inserts the plain transcript, no model is auto-selected in the background, and the Ollama status dot is neutral gray.
- Curated Ollama model catalog in Settings → Rewrite: three vetted near-realtime models (Qwen3 4B Instruct, Llama 3.2 3B, Gemma 3 4B) with size and expectation notes. Selecting an uninstalled one downloads it through the Ollama API with live progress; the menu's Ollama dot shows orange while downloading and green when ready. Manually installed models remain selectable with a generic latency rule of thumb.
- Ollama model is selectable in Settings → Rewrite (was display-only). Rewrites keep the model loaded via `keep_alive: 60m`, eliminating multi-second cold starts after pauses. With a small instruct model (e.g. `qwen3:4b-instruct`, ~1 s warm) rewriting feels near-realtime; reasoning models like `gpt-oss:20b` take 10–30 s per rewrite.
- Friendly prompt pins politeness markers to the input language — small models no longer append English "Thanks!" to German rewrites.
- Whisper model picker in Settings → Transkription: curated choice of Tiny/Base/Small/Large-v3-Turbo with honest size, speed, and quality expectations per model; switching downloads the model with live progress (also shown in the menu status) and reloads the engine through the usual retry/error path. Settings also state expected rewrite latency depending on the Ollama model.
- Menu polish: transparent logo in the header (extracted motif, `docs/assets/voicy-logo-transparent.png`), more generous spacing, and crisper typography — banner titles and buttons moved up from 10 pt bold/small controls, which rendered blurry.
- Menu regrouped by shortcut: a "⌥ halten" headline over the always-available Normal row (now a plain info row, not a clickable-looking card) and a set-off "⌥ ⌃ — wähle den Stil" group where the two rewrite styles are accent-tinted selectable cards.
- Visible rewrite failure handling: when a rewrite fails (the app silently inserts the unmodified transcript as fallback), the menu now shows an orange banner with the error and a "Verbindung testen" button. The connection test runs a real minimal generate against the selected Ollama model — catching models that are listed by `/api/tags` but can no longer load (e.g. an outdated GGUF format after an Ollama update). The Ollama status dot turns orange in that state instead of pretending everything is fine.

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
