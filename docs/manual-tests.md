# Manuelle End-to-End Tests

Wir können WhisperKit, CGEventTap-Eingaben und Pasteboard-Insertion nicht in CI emulieren — diese Liste validiert das Verhalten manuell vor jedem Release.

## Voraussetzungen

- macOS 14+ auf Apple Silicon
- Voicy mit Mikrofon, Accessibility und Input Monitoring erlaubt
- Ollama läuft mit mindestens einem Modell (z.B. `ollama pull llama3.2:3b`)
- Whisper-Modell `openai_whisper-small` heruntergeladen

## Tests

1. **Diktat in TextEdit**
   - In TextEdit eintippen: irgendetwas, dann `⌘C`, sodass im Pasteboard "irgendetwas" liegt.
   - Cursor in einem leeren Abschnitt platzieren.
   - `⌥` rechts halten, "Hallo Welt" sprechen, loslassen.
   - **Erwartet**: "Hallo Welt." erscheint an Cursor-Position. `⌘V` an anderer Stelle fügt weiterhin "irgendetwas" ein (Pasteboard wiederhergestellt).

2. **Diktat in Slack-Web (Browser)**
   - In Chrome auf slack.com einloggen, Channel öffnen, Cursor im Message-Eingabefeld.
   - `⌥` rechts halten, deutschen Satz sprechen, loslassen.
   - **Erwartet**: Text erscheint im Slack-Eingabefeld (validiert Cmd-V-Pfad in Electron-/Web-Apps).

3. **Friendly als aktiver Stil**
   - Im Menü "Friendly" auswählen.
   - `⌥` rechts + `⌃` halten, "kannst du das mal machen" sagen, loslassen.
   - **Erwartet**: Eingefügter Text enthält Höflichkeitsformeln, z.B. "Könntest du das bitte machen?".

4. **Custom als aktiver Stil — Bullet-Liste**
   - Settings → Rewrite → Custom: Name "Bullets", Prompt "Antworte als kompakte Bullet-Liste auf Deutsch. Antworte nur mit der Liste.". Speichern.
   - Im Menü "Bullets" als aktiv wählen.
   - `⌥` rechts + `⌃` halten, "ich brauche Milch Eier und Brot", loslassen.
   - **Erwartet**: Mehrzeilige `- Milch / - Eier / - Brot` Liste.

5. **Custom-Editor Live-Reload**
   - Custom-Prompt anpassen, speichern.
   - Sofort `⌥+⌃` drücken — kein App-Neustart.
   - **Erwartet**: Neuer Prompt wirkt sofort.

6. **Ollama gestoppt → Fallback**
   - `ollama stop` (oder Ollama.app beenden).
   - `⌥+⌃` halten und sprechen.
   - **Erwartet**: System-Notification "Rewrite nicht möglich"; das rohe Transkript wird stattdessen eingefügt. Normaler `⌥`-Pfad funktioniert weiterhin.

7. **Permissions widerrufen**
   - In Systemeinstellungen → Datenschutz → Input Monitoring den Voicy-Eintrag deaktivieren.
   - **Erwartet**: Menü zeigt rotes Banner "Berechtigungen unvollständig". Hotkeys reagieren nicht. Re-Aktivieren in Settings, ohne App-Neustart, → Hotkeys funktionieren wieder.

8. **Schnelle Folge-Trigger**
   - 3× Diktat innerhalb von 5 s in TextEdit.
   - **Erwartet**: Alle drei Texte werden korrekt eingefügt; ursprünglicher Pasteboard-Inhalt bleibt am Ende erhalten (kein Verlust durch Race-Condition).

9. **Sleep/Wake**
   - MacBook zuklappen, 30 s warten, aufklappen.
   - **Erwartet**: Hotkey reagiert weiter (CGEventTap automatisch reaktiviert).

10. **Notarisiertes DMG auf cleanem Mac**
    - DMG auf einem zweiten, nicht-entwickler Mac öffnen → Voicy in /Applications ziehen → starten.
    - **Erwartet**: Gatekeeper akzeptiert ohne "unidentified developer"-Warnung.

## Performance-Ziele (M1)

- Hotkey-Down → erstes Audio-Sample: < 100 ms.
- Hotkey-Up → Text eingefügt (5-Sekunden-Aufnahme, small-Modell): < 1.5 s.
- Friendly-Mode-Overhead: < 2 s zusätzlich (llama3.2:3b).
