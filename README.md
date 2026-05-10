# Voicy

Native macOS-Menüleisten-App für lokales, datenschutzfreundliches Voice-to-Text mit optionalem LLM-Rewrite. Inspiriert von Wispr Flow / Superwhisper, mit Fokus auf Lokalität (alles bleibt auf dem Gerät) und Polish-Niveau (Raycast / CleanShot).

## Features

- **Normal-Modus** (`⌥` rechts halten): Aufnahme → WhisperKit → Auto-Insert.
- **Friendly-Modus** (`⌥` rechts + `⌃` halten, wenn Friendly aktiv): Aufnahme → Whisper → Ollama mit kuratiertem Friendly-Prompt → Auto-Insert.
- **Custom-Modus** (`⌥` rechts + `⌃` halten, wenn Custom aktiv): wie Friendly, aber mit benutzerdefiniertem System-Prompt (Name + Prompt jederzeit editierbar).
- Vollständig lokal: WhisperKit auf der Apple Neural Engine, Ollama auf `127.0.0.1:11434`.
- Funktioniert in jeder App: Browser, Slack, VS Code, Notion, Mail, Terminal.
- Aktiver Rewrite-Stil über Menü-Item umschaltbar.

## Voraussetzungen

| | |
|---|---|
| macOS | 14 (Sonoma) oder neuer |
| Architektur | Apple Silicon (M1/M2/M3/M4) |
| Xcode | 15.4 oder neuer |
| Tooling | [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen` |
| Ollama (optional, für Rewrite) | [ollama.com](https://ollama.com) — z.B. `ollama pull llama3.2:3b` |

## Build

```bash
git clone <repo-url> voicy
cd voicy
xcodegen generate
open Voicy.xcodeproj
```

In Xcode: Target `Voicy` wählen → Run (⌘R). Beim ersten Start:
1. Mikrofon-Permission gewähren (Systemdialog).
2. Accessibility + Input-Monitoring in Systemeinstellungen → Datenschutz aktivieren.
3. WhisperKit lädt das Modell `openai_whisper-small` (~470 MB) in `~/Library/Application Support/Voicy/Models/`.

## Architektur

```
Voicy/
├── Voicy/                     # App-Target (@main, MenuBarExtra, Coordinator)
└── Modules/
    ├── HotkeyEngine/          # CGEventTap, Right-Option / +Control-Tracking
    ├── AudioCapture/          # AVAudioEngine, 16 kHz mono Float32
    ├── Transcription/         # WhisperKit-Wrapper + Modell-Download
    ├── RewriteService/        # Ollama-Client + Stil-Speicher
    ├── TextInsertion/         # Pasteboard-Save → setString → ⌘V → Restore
    ├── PermissionsKit/        # Mic / AX / Input-Monitoring
    ├── Settings/              # SwiftUI Settings-Scenes
    └── Onboarding/            # First-Launch-Wizard
```

Jede Komponente ist Protokoll-First entworfen, um Mocks und Unit-Tests zu erlauben.

## Distribution

Release-Pipeline (Manuell, GitHub-Actions später):

```bash
xcodebuild -scheme Voicy -configuration Release archive -archivePath build/Voicy.xcarchive
xcodebuild -exportArchive -archivePath build/Voicy.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/Voicy
create-dmg --volname Voicy --app-drop-link 600 185 build/Voicy.dmg build/Voicy/Voicy.app
xcrun notarytool submit build/Voicy.dmg --keychain-profile "voicy-notary" --wait
xcrun stapler staple build/Voicy.dmg
```

Sparkle-Updates: `appcast.xml` wird über `generate_appcast` befüllt und auf GitHub Releases gehostet.

## Lizenz

MIT (siehe `LICENSE`).
