# Voice Transcript

Native macOS-Menüleisten-App für lokales, datenschutzfreundliches Voice-to-Text mit optionalem LLM-Rewrite. Inspiriert von Wispr Flow / Superwhisper, mit Fokus auf Lokalität (alles bleibt auf dem Gerät) und Polish-Niveau (Raycast / CleanShot).

Drücke einen Hotkey, sprich, lass los — der transkribierte Text landet direkt im aktiven Eingabefeld. Optional formuliert ein lokales Sprachmodell das Diktat vorher um (z. B. höflicher). Es verlässt nichts deinen Mac: kein Cloud-Dienst, kein Account.

> Hinweis: Der Bundle-Identifier bleibt aus Kompatibilitätsgründen `de.dreamit.voicy` (frühere interne Builds hießen „Voicy"). Das ist die technische App-Identität, an der erteilte Berechtigungen und Auto-Updates hängen — sie ist nicht öffentlich sichtbar.

## Features

- **Normal-Modus** (Trigger-Taste halten): Aufnahme → Whisper → Auto-Insert.
- **Rewrite-Modus** (Trigger-Taste + `⌃` halten): Aufnahme → Whisper → lokales LLM (Ollama) → Auto-Insert. Der aktive Stil ist im Menü umschaltbar:
  - **German → English** — kuratierter Prompt, übersetzt deutsches Diktat in flüssiges Englisch (englische Eingabe bleibt nahezu unverändert).
  - **Custom** — eigener System-Prompt (Name + Prompt jederzeit editierbar).
- **Konfigurierbarer Kurzbefehl** — Push-to-Talk-Taste wählbar (rechte Wahltaste = Standard, rechte Befehls-/Control-/Umschalttaste oder Fn), jeweils mit Konflikt-Hinweis.
- **Rewrite ist optional** — ohne gewähltes Modell (oder bewusst deaktiviert) fügt der Rewrite-Trigger den unveränderten Transkript-Text ein.
- **Wählbare Modelle** für beide Stufen, inkl. In-App-Download mit Fortschritt:
  - Transkription: Tiny · Base · Small · Large v3 Turbo (Empfehlung für DE/EN).
  - Rewrite: Qwen3 4B Instruct (Empfehlung, ~2–3 s, beste DE→EN-Übersetzung) · Gemma 3 4B (natürlichstes Deutsch für Custom) · Llama 3.2 3B (am schnellsten) · Gemma 3 12B (höchste Qualität, langsam).
- **Geführtes Setup** mit Sprachauswahl und passender Modell-Empfehlung.
- **Vollständig lokal**: Whisper (WhisperKit) auf der Apple Neural Engine, Ollama auf `127.0.0.1:11434`.
- Funktioniert in jeder App: Browser, Slack, VS Code, Notion, Mail, Terminal.
- **Auto-Update** via Sparkle.

## Installation (interne Builds)

Interne Builds werden als DMG unter [Releases](https://github.com/dreamit-de/voicy/releases) veröffentlicht.

1. DMG öffnen, `Voice Transcript.app` in den Ordner `Programme` ziehen.
2. **Quarantäne entfernen** (siehe Hinweis unten) — sonst startet die App nicht.
3. Voice Transcript starten. Das Setup führt durch Sprachwahl, Berechtigungen und Modell-Download.

> [!IMPORTANT]
> **xattr-Hinweis 1 — heruntergeladene App entsperren.** Die internen Builds sind signiert, aber **nicht von Apple notarisiert**. macOS markiert heruntergeladene Apps deshalb mit dem Quarantäne-Flag und blockiert den Start („… kann nicht geöffnet werden, da Apple sie nicht auf Schadsoftware prüfen konnte"). Entferne das Flag nach dem Kopieren nach `/Programme` einmalig (Pfad in Anführungszeichen wegen des Leerzeichens):
>
> ```bash
> xattr -dr com.apple.quarantine "/Applications/Voice Transcript.app"
> ```
>
> Danach startet die App normal; die Berechtigungen (Mikrofon, Bedienungshilfen, Eingabeüberwachung) bleiben über künftige Sparkle-Updates erhalten.

## Voraussetzungen

| | |
|---|---|
| macOS | 14 (Sonoma) oder neuer |
| Architektur | Apple Silicon (M1/M2/M3/M4) |
| Xcode (für Build) | 16 oder neuer |
| Tooling (für Build) | [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen` |
| Ollama (optional, für Rewrite) | [ollama.com](https://ollama.com) — Modell z. B. via Setup oder `ollama pull gemma3:4b` |

Whisper- und Rewrite-Modelle lädt die App selbst herunter und legt sie unter `~/Library/Application Support/Voice Transcript/Models/` (Whisper) bzw. im Ollama-Cache ab. Nichts davon muss manuell installiert werden.

## Build & lokal ausführen

```bash
git clone https://github.com/dreamit-de/voicy.git
cd voicy
xcodegen generate
open Voicy.xcodeproj
```

In Xcode: Target `Voicy` wählen → Run (⌘R). Das Xcode-Projekt, der Quellordner und der Swift-Modulname heißen weiterhin `Voicy` (technische Identität); das gebaute Produkt ist `Voice Transcript.app`. Beim ersten Start führt das Setup durch:

1. **Sprache** — Standard ist Deutsch; danach empfiehlt die App die passenden Modelle.
2. **Mikrofon** — Systemdialog bestätigen.
3. **Bedienungshilfen** + **Eingabeüberwachung** — in Systemeinstellungen → Datenschutz & Sicherheit aktivieren.
4. **Modelle** — Transkriptions- (und optional Rewrite-)Modell werden geladen.

> [!IMPORTANT]
> **xattr-Hinweis 2 — lokal gebaute App ohne Zertifikat starten.** Ein lokaler Build ohne Developer-ID-Zertifikat ist nur ad-hoc signiert. Solange du ihn aus Xcode startest (⌘R), ist das unkritisch. Kopierst du das gebaute `Voice Transcript.app` aber woandershin oder gibst es weiter, greift dieselbe Gatekeeper-Quarantäne wie bei den internen Builds — dann ebenfalls einmalig entsperren:
>
> ```bash
> xattr -dr com.apple.quarantine "/pfad/zu/Voice Transcript.app"
> ```

## Architektur

Die Diktier-Kette ist zweistufig: zwei spezialisierte, unabhängig austauschbare Modelle. Das Rewrite-LLM sieht nie das Audio, nur den fertigen Transkript-Text.

```
Audio (PCM)
  └─► Whisper (Transkription, Neural Engine)      → Text
        └─► Ollama-LLM (Rewrite, nur im Rewrite-Modus) → umformulierter Text
              └─► Auto-Insert ins aktive Feld
```

```
Voicy/                          # Repo-Wurzel (Modulname bleibt „Voicy")
├── Voicy/                      # App-Target (@main, MenuBarExtra, Coordinator)
└── Modules/
    ├── HotkeyEngine/           # CGEventTap, konfigurierbarer Modifier-Trigger
    ├── AudioCapture/           # AVAudioEngine, 16 kHz mono Float32
    ├── Transcription/          # WhisperKit-Wrapper, Modell-Katalog + Download
    ├── RewriteService/         # Ollama-Client, Modell-Katalog + Stil-Speicher
    ├── TextInsertion/          # Pasteboard-Save → setString → ⌘V → Restore
    ├── PermissionsKit/         # Mic / AX / Input-Monitoring
    ├── Settings/               # SwiftUI Settings-Scenes
    └── Onboarding/             # Setup-Assistent (Sprache, Rechte, Modelle)
```

Jede Komponente ist Protokoll-First entworfen, um Mocks und Unit-Tests zu erlauben.

## Distribution

### Interne Releases (GitHub Actions)

Der Workflow **Internal Release** (`.github/workflows/internal-release.yml`, `workflow_dispatch` mit `version` / `build_number` / optional `release_notes`) baut ein DMG, veröffentlicht es als GitHub-Prerelease `v{version}-internal` und publiziert anschließend den Sparkle-Appcast.

- **Signierung:** Das DMG wird mit dem selbstsignierten Zertifikat „dreamIT Voicy Internal Signing" signiert (Repo-Secrets `MACOS_CERT_P12_BASE64` / `MACOS_CERT_P12_PASSWORD` / `MACOS_KEYCHAIN_PASSWORD` — dieselben Namen wie `release.yml`; der Zertifikatsname bleibt aus Kompatibilitätsgründen unverändert). Das ergibt ein über alle Builds stabiles *Designated Requirement*, sodass erteilte TCC-Berechtigungen Updates überleben. Der Workflow bricht ab, falls die Signatur auf ein ad-hoc-cdhash-Requirement zurückfiele. **Nicht notarisiert** → heruntergeladene Builds brauchen den `xattr`-Schritt oben.
- **build_number:** CFBundleVersion = `sparkle:version` muss streng monoton steigen — der Workflow bricht früh ab, wenn sie nicht größer ist als die zuletzt auf `gh-pages` publizierte `sparkle:version`, da Sparkle ausschließlich diese Nummer vergleicht.

### Auto-Update via Sparkle

- Installierte Versionen aktualisieren sich automatisch über [Sparkle 2](https://sparkle-project.org).
- **Feed-URL** (`SUFeedURL`): `https://dreamit-de.github.io/voicy/appcast.xml` — gehostet auf GitHub Pages (Branch `gh-pages`). Die URL bleibt unverändert (Umbenennen würde den Update-Feed aller installierten Apps brechen).
- Der Appcast enthält immer nur das neueste Release; das DMG-Asset liegt auf GitHub Releases.
- Reihenfolge in der Pipeline: erst GitHub-Release mit DMG publizieren, dann `appcast.xml` nach `gh-pages` pushen — der Feed zeigt also nie auf ein nicht existierendes Asset.

**Key-Handling (EdDSA / Ed25519):**

- **Public Key** (`SUPublicEDKey`): steht im Klartext in `project.yml` (Public Keys sind nicht geheim) und landet via XcodeGen in der `Info.plist`. Der Workflow verifiziert vor dem Signieren, dass die gebaute App einen gültigen 32-Byte-Ed25519-Key trägt. **Achtung:** Key niemals rotieren ohne Migrationsplan — installierte Apps lehnen Updates ab, die mit einem anderen Key signiert sind.
- **Private Key:** liegt ausschließlich als Repo-Secret `SPARKLE_PRIVATE_KEY` (base64-codierter 32-Byte-Ed25519-Seed, Format von `generate_keys -x`). Der Workflow schreibt ihn nur in eine temporäre Datei (`chmod 600`) für `sign_update -f` und löscht sie sofort danach. Niemals committen oder loggen.

### Notarisierter Release (später)

Der Workflow `release.yml` (Developer-ID-Signatur + Apple-Notarisierung) ist vorbereitet, aber noch ohne Appcast-Publishing — siehe TODO-Kommentar im Workflow. Sobald ein Developer-ID-Zertifikat in denselben `MACOS_CERT_P12_*`-Secrets liegt, entfällt der `xattr`-Schritt für Endnutzer komplett.

## Lizenz

MIT (siehe `LICENSE`).
