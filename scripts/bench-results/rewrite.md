# Rewrite model benchmark

Host: Ollama at http://127.0.0.1:11434 · best of 2 runs/case · model kept warm

## Latency summary

| Model | max latency | avg latency | < 5 s |
|---|---|---|---|
| `qwen2.5:3b-instruct` | 1.84s | 1.38s | ✅ |
| `llama3.2:3b` | 2.02s | 1.24s | ✅ |
| `qwen3:4b-instruct` | 2.45s | 1.86s | ✅ |
| `gemma3:4b` | 3.65s | 3.13s | ✅ |
| `qwen2.5:7b-instruct` | 4.47s | 3.39s | ✅ |
| `gemma3n:e4b` | 5.70s | 4.46s | ❌ |
| `gemma3:12b` | 13.98s | 11.43s | ❌ |

## Outputs (translate = DE→EN built-in, clean = DE Custom rewrite)

### `qwen3:4b-instruct`

**translate**

- `de1` (1.79s, 11.9 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Anyway, just to say the meeting is being rescheduled to tomorrow at three o'clock.
- `de2` (1.41s, 14.9 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Can you please send me the numbers from last quarter? I need them by Friday.
- `de3` (2.18s, 13.6 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is going pretty well, but we still have a problem with database performance, and that needs to be addressed next week.
- `en1` (1.43s, 13.8 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: So I just want to say the meeting is moved to 3 pm tomorrow.

**clean**

- `de1` (1.55s, 14.3 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Ich möchte nur kurz sagen, dass das Meeting morgen auf drei Uhr verschoben wird.
- `de2` (2.20s, 12.8 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Kannst du mir bitte die Zahlen aus dem letzten Quartal schicken? Ich brauche sie bis Freitag.
- `de3` (2.45s, 13.6 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft soweit gut, aber wir haben weiterhin ein Problem mit der Datenbankperformance, das wir nächste Woche angehen müssen.

### `gemma3:4b`

**translate**

- `de1` (3.42s, 22.1 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Also, I just wanted to say that the meeting is now postponed until three o'clock tomorrow.
- `de2` (3.19s, 26.2 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Can you please send me the figures for last quarter I need them by Friday
- `de3` (3.65s, 17.2 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: the project is going quite well, but we do have a problem with database performance and we need to address that next week
- `en1` (3.12s, 26.6 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: So I just wanted to say that the meeting is moved to three PM tomorrow.

**clean**

- `de1` (2.62s, 10.7 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting wird morgen um 15:00 Uhr verschoben.
- `de2` (2.52s, 15.4 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Bitte senden Sie mir die Zahlen des letzten Quartals, da ich diese bis Freitag benötige.
- `de3` (3.37s, 21.2 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft derzeit gut, jedoch besteht weiterhin ein Problem mit der Datenbankperformance, welches wir nächste Woche adressieren werden.

### `llama3.2:3b`

**translate**

- `de1` (1.08s, 21.3 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Also I just wanted to say that the meeting will be postponed tomorrow to three o'clock.
- `de2` (0.93s, 22.5 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Can you please send me the numbers from the last quarter up to Friday?
- `de3` (1.72s, 19.2 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is going well so far, but we have a bit of an issue with database performance and that needs to be addressed next week.
- `en1` (0.81s, 21.7 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: The meeting has been rescheduled for 3pm tomorrow.

**clean**

- `de1` (0.66s, 31.9 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting ist morgen um 3 Uhr verschoben worden.
- `de2` (1.48s, 15.1 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Könnte ich Ihnen bitte die Zahlen für das letzte Quartal bis Freitag des jeweiligen Monats zur Verfügung stellen?
- `de3` (2.02s, 12.4 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft soweit ganz gut, aber wir haben noch ein Problem mit der Datenbankleistung, das müssen wir nächste Woche ansprechen.

### `qwen2.5:3b-instruct`

**translate**

- `de1` (1.57s, 16.4 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Also I wanted to just say that the meeting is now canceled and will be rescheduled for 3 PM.
- `de2` (1.04s, 15.9 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Could you please send me the numbers from last quarter by Friday?
- `de3` (1.70s, 17.6 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: the project is going well so far, but we still have a problem with database performance and we need to address that next week.
- `en1` (1.22s, 16.5 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: So I just wanted to say that the meeting is moved to 3 PM tomorrow.

**clean**

- `de1` (1.08s, 23.7 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Also ich wollte nur kurz sagen, dass das Meeting morgen versetzt wird auf 15 Uhr.
- `de2` (1.20s, 28.6 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Könntest du mir bitte die Zahlen vom letzten Quartal schicken? Ich brauche sie bis Freitag.
- `de3` (1.84s, 18.6 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft so weit ganz gut, jedoch haben wir noch ein Problem mit der Datenbank-Performance und müssen diese nächste Woche angehen.

### `qwen2.5:7b-instruct`

**translate**

- `de1` (2.88s, 7.1 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Also, I just wanted to say that the meeting is postponed to three o'clock tomorrow.
- `de2` (2.47s, 8.5 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: can you please send me the numbers from the last quarter? I need them by Friday.
- `de3` (4.00s, 7.0 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is going pretty well so far, but we still have a database performance issue that we need to address next week.
- `en1` (2.54s, 7.4 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: So I just wanted to say that the meeting is moved to three PM tomorrow.

**clean**

- `de1` (3.61s, 6.2 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting wurde verschieben und findet morgen um 15:00 Uhr statt.
- `de2` (3.77s, 7.0 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Könnten Sie mir bitte die Zahlen des letzten Quartals senden? Ich benötige sie bis Freitag.
- `de3` (4.47s, 5.5 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft bisher gut, jedoch besteht noch ein Problem mit der Datenbankperformance, das wir in der nächsten Woche bearbeiten werden.

### `gemma3n:e4b`

**translate**

- `de1` (5.58s, 16.0 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: So, I just wanted to quickly say that the meeting is moved to three o'clock tomorrow.
- `de2` (5.20s, 18.4 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Could you please send me the figures for last quarter? I need them by Friday.
- `de3` (5.70s, 7.2 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is going pretty well so far, but we still have a problem with the database performance, and we need to address that next week.
- `en1` (4.64s, 21.0 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: So I just wanted to say that the meeting is moved to three pm tomorrow.

**clean**

- `de1` (2.77s, 22.9 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting ist morgen um drei Uhr verschoben.
- `de2` (3.17s, 12.0 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Bitte senden Sie mir die Zahlen des letzten Quartals bis Freitag.
- `de3` (4.16s, 18.4 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt verläuft bisher gut, jedoch besteht weiterhin ein Problem mit der Datenbankperformance, das wir nächste Woche angehen müssen.

### `gemma3:12b`

**translate**

- `de1` (13.44s, 3.8 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: I just wanted to quickly say that the meeting will be postponed until tomorrow at three o’clock.
- `de2` (13.43s, 3.3 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Could you please send me the figures from last quarter? I need them by Friday.
- `de3` (13.98s, 3.7 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is going well so far, but we still have a database performance issue that we need to address next week.
- `en1` (12.34s, 4.4 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: So I just wanted to say that the meeting is moved to 3 p.m. tomorrow.

**clean**

- `de1` (6.11s, 5.9 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting findet morgen um drei Uhr statt.
- `de2` (7.39s, 5.2 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Bitte senden Sie mir die Zahlen des letzten Quartals bis Freitag.
- `de3` (13.30s, 2.9 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt verläuft überwiegend planmäßig, jedoch besteht weiterhin eine Herausforderung hinsichtlich der Datenbankperformance, die nächste Woche adressiert werden muss.
