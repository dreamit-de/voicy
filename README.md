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

### Interne Releases (GitHub Actions)

Der Workflow **Internal Release** (`.github/workflows/internal-release.yml`, `workflow_dispatch` mit `version` / `build_number` / optional `release_notes`) baut ein ad-hoc-signiertes DMG, veröffentlicht es als GitHub-Prerelease `v{version}-internal` und publiziert anschließend den Sparkle-Appcast. Die `build_number` (CFBundleVersion = `sparkle:version`) muss streng monoton steigen — der Workflow bricht früh ab, wenn sie nicht größer ist als die zuletzt auf `gh-pages` publizierte `sparkle:version`, da Sparkle ausschließlich diese Nummer vergleicht.

### Auto-Update via Sparkle

- Installierte Voicy-Versionen aktualisieren sich automatisch über [Sparkle 2](https://sparkle-project.org).
- **Feed-URL** (`SUFeedURL`): `https://dreamit-de.github.io/voicy/appcast.xml` — gehostet auf GitHub Pages (Branch `gh-pages`).
- Der Appcast enthält immer nur das neueste Release; das DMG-Asset liegt weiterhin auf GitHub Releases.
- Reihenfolge in der Pipeline: erst GitHub-Release mit DMG publizieren, dann `appcast.xml` nach `gh-pages` pushen — der Feed zeigt also nie auf ein nicht existierendes Asset.

**Key-Handling (EdDSA / Ed25519):**

- **Public Key** (`SUPublicEDKey`): steht im Klartext in `project.yml` (Public Keys sind nicht geheim) und landet via XcodeGen in der `Info.plist`. Der Internal-Release-Workflow verifiziert vor dem Signieren, dass die gebaute App einen gültigen 32-Byte-Ed25519-Key trägt. **Achtung:** Key niemals rotieren ohne Migrationsplan — installierte Apps lehnen Updates ab, die mit einem anderen Key signiert sind.
- **Private Key**: liegt ausschließlich als Repo-Secret `SPARKLE_PRIVATE_KEY` (base64-codierter 32-Byte-Ed25519-Seed, Format von `generate_keys -x`). Der Workflow schreibt ihn nur in eine temporäre Datei (`chmod 600`) für `sign_update -f` und löscht sie sofort danach. Der Key darf niemals committet oder geloggt werden.

### Notarisierter Release (später)

Der Workflow `release.yml` (Developer-ID-Signatur + Notarisierung) ist vorbereitet, aber noch ohne Appcast-Publishing — siehe TODO-Kommentar im Workflow:

```bash
xcodebuild -scheme Voicy -configuration Release archive -archivePath build/Voicy.xcarchive
xcodebuild -exportArchive -archivePath build/Voicy.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/Voicy
create-dmg --volname Voicy --app-drop-link 600 185 build/Voicy.dmg build/Voicy/Voicy.app
xcrun notarytool submit build/Voicy.dmg --keychain-profile "voicy-notary" --wait
xcrun stapler staple build/Voicy.dmg
```

## Lizenz

MIT (siehe `LICENSE`).
