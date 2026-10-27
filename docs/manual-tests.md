# Manuelle End-to-End Tests

Wir können WhisperKit, CGEventTap-Eingaben und Pasteboard-Insertion nicht in CI emulieren — diese Liste validiert das Verhalten manuell vor jedem Release.

## Voraussetzungen

- macOS 14+ auf Apple Silicon
- Voice Transcript mit Mikrofon, Accessibility und Input Monitoring erlaubt
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

3. **German → English als aktiver Stil**
   - Im Menü "German → English" auswählen.
   - `⌥` rechts + `⌃` halten, "kannst du mir die Zahlen bis Freitag schicken" sagen, loslassen.
   - **Erwartet**: Eingefügter Text ist eine flüssige englische Übersetzung, z.B. "Can you send me the numbers by Friday?".
   - Gegenprobe: einen englischen Satz sprechen → bleibt englisch, nur leicht geglättet.

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
   - In Systemeinstellungen → Datenschutz → Input Monitoring den Voice Transcript-Eintrag deaktivieren.
   - **Erwartet**: Menü zeigt rotes Banner "Berechtigungen unvollständig". Hotkeys reagieren nicht. Re-Aktivieren in Settings, ohne App-Neustart, → Hotkeys funktionieren wieder.

8. **Schnelle Folge-Trigger**
   - 3× Diktat innerhalb von 5 s in TextEdit.
   - **Erwartet**: Alle drei Texte werden korrekt eingefügt; ursprünglicher Pasteboard-Inhalt bleibt am Ende erhalten (kein Verlust durch Race-Condition).

9. **Sleep/Wake**
   - MacBook zuklappen, 30 s warten, aufklappen.
   - **Erwartet**: Hotkey reagiert weiter (CGEventTap automatisch reaktiviert).

10. **Notarisiertes DMG auf cleanem Mac**
    - DMG auf einem zweiten, nicht-entwickler Mac öffnen → Voice Transcript in /Applications ziehen → starten.
    - **Erwartet**: Gatekeeper akzeptiert ohne "unidentified developer"-Warnung.

11. **Onboarding — Happy Path mit Schritt-Validierung**
    - Frische Installation simulieren: `defaults delete de.dreamit.voicy` (bzw. App-Container leeren), Voice Transcript in Systemeinstellungen → Datenschutz aus Mikrofon/Eingabehilfe/Eingabeüberwachung entfernen, App starten.
    - Onboarding Schritt für Schritt durchlaufen und jede Berechtigung gewähren.
    - **Erwartet**: Jeder Schritt validiert seinen Status live (Haken erscheint erst nach tatsächlich erteilter Berechtigung, ohne App-Neustart); "Weiter" ist erst aktiv, wenn der Schritt erfüllt ist; nach dem letzten Schritt ist Voice Transcript sofort per Hotkey nutzbar.

12. **Onboarding — Verweigern-Pfade**
    - Onboarding erneut frisch starten, diesmal: (a) Mikrofon im Systemdialog verweigern, (b) Eingabehilfe-Schritt überspringen/Systemeinstellungen ohne Aktivierung schließen, (c) Eingabeüberwachung verweigern.
    - **Erwartet**: Pro Schritt erscheint eine verständliche deutsche Fehlermeldung mit Hinweis, wie die Berechtigung in den Systemeinstellungen nachträglich erteilt wird (inkl. Button dorthin); das Onboarding crasht nicht, hängt nicht und lässt sich nach Erteilen der Berechtigung ohne App-Neustart fortsetzen. Wird das Onboarding mit fehlenden Berechtigungen beendet, zeigt das Menü das rote Banner "Berechtigungen unvollständig".

13. **Sparkle-Update-Flow (alte Version → Auto-Update)**
    - Eine ältere internal-DMG (niedrigere Build-Nummer) installieren und starten; sicherstellen, dass `https://dreamit-de.github.io/voicy/appcast.xml` bereits die neuere Version listet.
    - Auf den automatischen Update-Check warten oder "Nach Updates suchen…" im Menü auslösen.
    - **Erwartet**: Ein sichtbarer Update-Hinweis erscheint (Menübar-Hinweis bzw. Update-Dialog im Vordergrund — kein versteckter Hintergrund-Alert, obwohl Voice Transcript eine LSUIElement-App ist). Nach Klick auf "Installieren" lädt Sparkle das Update, installiert es und startet die neue Version — ohne dass der Nutzer das DMG manuell herunterladen oder die Quarantäne entfernen muss. Versionsnummer im "Über"-Bereich entspricht danach dem neuen Release; die Release Notes im Dialog sind deutsch.

14. **Mikrofon-Auswahl und Fallback**
    - Zweites Eingabegerät anschließen (USB-Mikrofon oder AirPods). Menü öffnen: Die Zeile „Mikrofon: …" nennt das aktuelle Gerät; das neue Gerät erscheint ohne App-Neustart in der Liste (Menü und Einstellungen → Mikrofon).
    - (a) „Systemstandard" gewählt: In Systemeinstellungen → Ton → Eingabe das Gerät wechseln, dann diktieren. **Erwartet**: Die Aufnahme kommt vom neuen Standardgerät; im Log (`log stream --predicate 'subsystem == "de.dreamit.voicy"'`) steht bei „AudioRecorder started" dessen Name und UID.
    - (b) Im Menü das eingebaute Mikrofon fest wählen, danach AirPods verbinden (macOS macht sie zum Standard) und diktieren. **Erwartet**: Es wird weiter über das eingebaute Mikrofon aufgenommen (Log nennt es, AirPods bleiben in hoher Wiedergabequalität).
    - (c) Das USB-Mikrofon fest wählen und abziehen. **Erwartet**: Die Menüzeile wird orange („… nicht verbunden — nutze …"), die Einstellungen zeigen den Hinweis, das Diktat funktioniert über den Systemstandard (Log: `fallback=true`). Wieder anschließen: Die Zeile wird normal, die nächste Aufnahme nutzt wieder das USB-Mikrofon.
    - (d) Während einer laufenden Aufnahme das Gerät abziehen. **Erwartet**: Kein Absturz; die bis dahin aufgenommene Audiospur wird transkribiert; die nächste Aufnahme funktioniert normal.

## Performance-Ziele (M1)

- Hotkey-Down → erstes Audio-Sample: < 100 ms.
- Hotkey-Up → Text eingefügt (5-Sekunden-Aufnahme, small-Modell): < 1.5 s.
- Rewrite-Mode-Overhead (German → English): < 5 s zusätzlich; Default-Modell zielt auf ~1–2 s.
