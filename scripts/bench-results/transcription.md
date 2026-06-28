# Transcription model benchmark

WhisperKit on Apple Neural Engine · `say`-synthesised DE/EN samples · WER vs reference text

## Summary

| Model | load | DE avg | EN avg | DE WER | EN WER |
|---|---|---|---|---|---|
| `openai_whisper-tiny` | 4.4s | 0.29s | 0.04s | 13% | 17% |
| `openai_whisper-base` | 7.8s | 0.10s | 0.08s | 9% | 17% |
| `openai_whisper-large-v3-v20240930_626MB` | 673.9s | 1.35s | 1.31s | 0% | 17% |

## Transcripts

### `openai_whisper-tiny`

- `de/de_1.wav` (0.74s, WER 0%): Das Meeting wird morgen auf drei Uhr verschoben.
- `de/de_2.wav` (0.05s, WER 20%): Bitteschick mir die Zahlen vom letzten Quartal bis Freitag.
- `de/de_3.wav` (0.06s, WER 20%): Das Projekt läuft so weit gut, aber wir haben noch ein Problem mit der Datenbank verformen.
- `en/en_1.wav` (0.04s, WER 33%): The meeting is moved to 3pm tomorrow.
- `en/en_2.wav` (0.04s, WER 0%): Please send me the numbers from last quarter by Friday.

### `openai_whisper-base`

- `de/de_1.wav` (0.08s, WER 12%): Das Meeting wird morgen auf 3 Uhr verschoben.
- `de/de_2.wav` (0.10s, WER 0%): Bitte schick mir die Zahlen vom letzten Quartal bis Freitag.
- `de/de_3.wav` (0.11s, WER 13%): Das Projekt läuft so weit gut, aber wir haben noch ein Problem mit der Datenbank Performance.
- `en/en_1.wav` (0.08s, WER 33%): The meeting is moved to 3pm tomorrow.
- `en/en_2.wav` (0.08s, WER 0%): Please send me the numbers from last quarter by Friday.

### `openai_whisper-large-v3-v20240930_626MB`

- `de/de_1.wav` (1.08s, WER 0%): Das Meeting wird morgen auf drei Uhr verschoben.
- `de/de_2.wav` (1.10s, WER 0%): Bitte schick mir die Zahlen vom letzten Quartal bis Freitag.
- `de/de_3.wav` (1.86s, WER 0%): Das Projekt läuft soweit gut, aber wir haben noch ein Problem mit der Datenbank-Performance.
- `en/en_1.wav` (1.46s, WER 33%): The meeting is moved to 3pm tomorrow.
- `en/en_2.wav` (1.17s, WER 0%): Please send me the numbers from last quarter by Friday.

