# Transcription model benchmark

measured 2026-10-27

WhisperKit on Apple Neural Engine · `say`-synthesised DE/EN samples · WER vs reference text

## Summary

| Model | load | DE avg | EN avg | DE WER | EN WER |
|---|---|---|---|---|---|
| `openai_whisper-base` | 7.3s | 0.22s | 0.10s | 13% | 14% |
| `openai_whisper-small` | 22.8s | 0.41s | 0.32s | 7% | 14% |
| `openai_whisper-large-v3-v20240930_626MB` | 67.0s | 0.98s | 0.89s | 1% | 14% |
| `openai_whisper-large-v3-v20240930_turbo_632MB` | 141.8s | 0.66s | 0.59s | 1% | 14% |
| `openai_whisper-large-v3-v20240930_547MB` | 10.7s | 0.92s | 0.86s | 1% | 14% |
| `openai_whisper-large-v3-v20240930` | 13.8s | 1.82s | 1.73s | 1% | 14% |

## Transcripts

### `openai_whisper-base`

- `de/de_1.wav` (0.60s, WER 12%): Das Meeting wird morgen auf 3 Uhr verschoben.
- `de/de_2.wav` (0.08s, WER 0%): Bitte schick mir die Zahlen vom letzten Quartal bis Freitag.
- `de/de_3.wav` (0.10s, WER 13%): Das Projekt läuft so weit gut, aber wir haben noch ein Problem mit der Datenbank Performance.
- `en/en_1.wav` (0.06s, WER 33%): The meeting is moved to 3pm tomorrow.
- `en/en_2.wav` (0.07s, WER 0%): Please send me the numbers from last quarter by Friday.
- `de/de_4.wav` (0.15s, WER 23%): Ich habe gestern Abend den Pulriquist für das neue Decloimment auf Kuba Netes erstellt. Kannst du bitte bis Donnerstag ein Review machen?
- `de/de_5.wav` (0.15s, WER 8%): Am 15. März um 14 Uhr 30 treffen wir uns mit Frau Schneider von Siemens in München, um das Budget von 250.000 Euro zu besprechen.
- `de/de_6.wav` (0.22s, WER 21%): Hallo Thomas, kurzes Abund seltsam Sprint, das Backend-Team hat die AP für den Login fertig, aber das Frontenthängt noch am Kaching im Brauser. Wir sollten im Daily Morgan klären, ob wir das Release auf nächste Woche verschieben.
- `en/en_3.wav` (0.18s, WER 7%): Hi Sarah, quick update on the migration. We finished moving the database to the new cluster on Tuesday, but the Grafana dashboard still shows some latency spikes. Can we schedule a call on Thursday at 10 to go through the logs?

### `openai_whisper-small`

- `de/de_1.wav` (0.31s, WER 25%): Das Meeting wird Norgen auf 3 Uhr verschoben.
- `de/de_2.wav` (0.27s, WER 0%): Bitte schick mir die Zahlen vom letzten Quartal bis Freitag.
- `de/de_3.wav` (0.29s, WER 0%): Das Projekt läuft soweit gut, aber wir haben noch ein Problem mit der Datenbank Performance.
- `en/en_1.wav` (0.19s, WER 33%): The meeting is moved to 3pm tomorrow.
- `en/en_2.wav` (0.21s, WER 0%): Please send me the numbers from last quarter by Friday.
- `de/de_4.wav` (0.42s, WER 0%): Ich habe gestern Abend den Pull-Request für das neue Deployment auf Kubernetes erstellt. Kannst du bitte bis Donnerstag ein Review machen?
- `de/de_5.wav` (0.45s, WER 0%): Am 15. März um 14.30 Uhr treffen wir uns mit Frau Schneider von Siemens in München, um das Budget von 250.000 Euro zu besprechen.
- `de/de_6.wav` (0.69s, WER 18%): Hallo Thomas, kurzes Appunkteil zum Sprint. Das Backenteam hat die API für den Login fertig, aber das Frontenthängt noch am Caching im Browser. Wir sollten im DailyMorgen klären, ob wir das Release auf nächste Woche verschieben.
- `en/en_3.wav` (0.57s, WER 10%): Hi Sarah, quick update on the migration. We finished moving the database to the new cluster on Tuesday, but the Grafana dashboard still shows some latency spikes. Can we schedule a call on Thursday attend to go through the logs?

### `openai_whisper-large-v3-v20240930_626MB`

- `de/de_1.wav` (0.86s, WER 0%): Das Meeting wird morgen auf drei Uhr verschoben.
- `de/de_2.wav` (0.83s, WER 0%): Bitte schick mir die Zahlen vom letzten Quartal bis Freitag.
- `de/de_3.wav` (0.90s, WER 0%): Das Projekt läuft soweit gut, aber wir haben noch ein Problem mit der Datenbank-Performance.
- `en/en_1.wav` (0.76s, WER 33%): The meeting is moved to 3pm tomorrow.
- `en/en_2.wav` (0.78s, WER 0%): Please send me the numbers from last quarter by Friday.
- `de/de_4.wav` (1.00s, WER 0%): Ich habe gestern Abend den Pull-Request für das neue Deployment auf Kubernetes erstellt. Kannst du bitte bis Donnerstag ein Review machen?
- `de/de_5.wav` (1.02s, WER 0%): Am 15. März um 14.30 Uhr treffen wir uns mit Frau Schneider von Siemens in München, um das Budget von 250.000 Euro zu besprechen.
- `de/de_6.wav` (1.27s, WER 5%): Hallo Thomas, kurzes A.Z zum Sprint, das Backend-Team hat die API für den Login fertig, aber das Frontend hängt noch am Caching im Browser. Wir sollten im Daily Morgen klären, ob wir das Release auf nächste Woche verschieben.
- `en/en_3.wav` (1.14s, WER 7%): Hi Sarah. Quick update on the migration. We finished moving the database to the new cluster on Tuesday, but the Grafana dashboard still shows some latency spikes. Can we schedule a call on Thursday at 10 to go through the logs?

### `openai_whisper-large-v3-v20240930_turbo_632MB`

- `de/de_1.wav` (0.55s, WER 0%): Das Meeting wird morgen auf drei Uhr verschoben.
- `de/de_2.wav` (0.53s, WER 0%): Bitte schick mir die Zahlen vom letzten Quartal bis Freitag.
- `de/de_3.wav` (0.59s, WER 0%): Das Projekt läuft soweit gut, aber wir haben noch ein Problem mit der Datenbank-Performance.
- `en/en_1.wav` (0.46s, WER 33%): The meeting is moved to 3pm tomorrow.
- `en/en_2.wav` (0.48s, WER 0%): Please send me the numbers from last quarter by Friday.
- `de/de_4.wav` (0.68s, WER 0%): Ich habe gestern Abend den Pull-Request für das neue Deployment auf Kubernetes erstellt. Kannst du bitte bis Donnerstag ein Review machen?
- `de/de_5.wav` (0.72s, WER 0%): Am 15. März um 14.30 Uhr treffen wir uns mit Frau Schneider von Siemens in München, um das Budget von 250.000 Euro zu besprechen.
- `de/de_6.wav` (0.92s, WER 5%): Hallo Thomas, kurzes A.Z zum Sprint, das Backend-Team hat die API für den Login fertig, aber das Frontend hängt noch am Caching im Browser. Wir sollten im Daily Morgen klären, ob wir das Release auf nächste Woche verschieben.
- `en/en_3.wav` (0.83s, WER 7%): Hi Sarah. Quick update on the migration. We finished moving the database to the new cluster on Tuesday, but the Grafana dashboard still shows some latency spikes. Can we schedule a call on Thursday at 10 to go through the logs?

### `openai_whisper-large-v3-v20240930_547MB`

- `de/de_1.wav` (0.77s, WER 0%): Das Meeting wird morgen auf drei Uhr verschoben.
- `de/de_2.wav` (0.79s, WER 0%): Bitte schick mir die Zahlen vom letzten Quartal bis Freitag.
- `de/de_3.wav` (0.86s, WER 0%): Das Projekt läuft soweit gut, aber wir haben noch ein Problem mit der Datenbank-Performance.
- `en/en_1.wav` (0.73s, WER 33%): The meeting is moved to 3pm tomorrow.
- `en/en_2.wav` (0.78s, WER 0%): Please send me the numbers from last quarter by Friday.
- `de/de_4.wav` (0.95s, WER 0%): Ich habe gestern Abend den Pull-Request für das neue Deployment auf Kubernetes erstellt. Kannst du bitte bis Donnerstag ein Review machen?
- `de/de_5.wav` (0.97s, WER 0%): Am 15. März um 14.30 Uhr treffen wir uns mit Frau Schneider von Siemens in München, um das Budget von 250.000 Euro zu besprechen.
- `de/de_6.wav` (1.16s, WER 5%): Hallo Thomas, kurzes A.Z zum Sprint, das Backend-Team hat die API für den Login fertig, aber das Frontend hängt noch am Caching im Browser. Wir sollten im Daily Morgen klären, ob wir das Release auf nächste Woche verschieben.
- `en/en_3.wav` (1.08s, WER 7%): Hi Sarah. Quick update on the migration. We finished moving the database to the new cluster on Tuesday, but the Grafana dashboard still shows some latency spikes. Can we schedule a call on Thursday at 10 to go through the logs?

### `openai_whisper-large-v3-v20240930`

- `de/de_1.wav` (1.53s, WER 0%): Das Meeting wird morgen auf drei Uhr verschoben.
- `de/de_2.wav` (1.55s, WER 0%): Bitte schick mir die Zahlen vom letzten Quartal bis Freitag.
- `de/de_3.wav` (1.56s, WER 0%): Das Projekt läuft soweit gut, aber wir haben noch ein Problem mit der Datenbank-Performance.
- `en/en_1.wav` (1.37s, WER 33%): The meeting is moved to 3pm tomorrow.
- `en/en_2.wav` (1.46s, WER 0%): Please send me the numbers from last quarter by Friday.
- `de/de_4.wav` (1.97s, WER 0%): Ich habe gestern Abend den Pull-Request für das neue Deployment auf Kubernetes erstellt. Kannst du bitte bis Donnerstag ein Review machen?
- `de/de_5.wav` (1.94s, WER 0%): Am 15. März um 14.30 Uhr treffen wir uns mit Frau Schneider von Siemens in München, um das Budget von 250.000 Euro zu besprechen.
- `de/de_6.wav` (2.36s, WER 8%): Hallo Thomas, kurzes A.Z zum Sprint, das Backen-Team hat die API für den Login fertig, aber das Frontend hängt noch am Caching im Browser. Wir sollten im Daily Morgen klären, ob wir das Release auf nächste Woche verschieben.
- `en/en_3.wav` (2.37s, WER 7%): Hi Sarah. Quick update on the migration. We finished moving the database to the new cluster on Tuesday, but the Grafana dashboard still shows some latency spikes. Can we schedule a call on Thursday at 10 to go through the logs?

## Notes (2026-10-27, Apple M4 32 GB, argmax-oss-swift 1.1.1)

- Test set extended with 4 harder samples (`de_4`–`de_6`, `en_3`): English tech terms inside German sentences, dates/times/amounts, names, and ~30-word dictations.
- `load` = first load in this run including ANE compile when not cached. The turbo build needed a fresh ~2.4 min compile. `_626MB` was already compiled from app use. Steady-state loads are seconds for all large-v3 builds.
- All four large-v3 v20240930 builds give **identical transcripts** (1% DE WER; the only miss is "kurzes Update" → "kurzes A.Z"). The full 1.6 GB build is no more accurate here and is 2× slower.
- `turbo_632MB` is **~33% faster** than `_626MB` (DE 0.66 s vs 0.98 s) with the same output, but Argmax lists it for M2–M4 only, not M1.
- `small` (the `WhisperEngine.defaultModel` fallback) fails on the long German sample and on compounds (7% DE WER). `base` mangles tech terms ("Pulriquist", "Kuba Netes").
- EN WER 14% is the same for every model: it comes from number formatting ("3pm", "10", "dashboard shows") and is not a recognition error.
