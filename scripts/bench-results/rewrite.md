# Rewrite model benchmark

measured 2026-10-27

Host: Ollama at http://127.0.0.1:11434 · best of 2 runs/case · model kept warm

## Latency summary

| Model | max latency | avg latency | < 5 s |
|---|---|---|---|
| `gemma4:e2b` | 0.76s | 0.39s | ✅ |
| `granite4.2:3b` | 1.53s | 0.73s | ✅ |
| `ministral-3:3b` | 1.58s | 0.76s | ✅ |
| `translategemma:4b` | 1.60s | 0.87s | ✅ |
| `llama3.2:3b` | 1.60s | 0.77s | ✅ |
| `gemma3:4b` | 1.62s | 0.88s | ✅ |
| `qwen3:4b-instruct` | 1.74s | 0.93s | ✅ |
| `qwen3.5:4b` | 2.12s | 1.17s | ✅ |

## Outputs (translate = DE→EN built-in, clean = DE Custom rewrite)

### `qwen3.5:4b`

**translate**

- `de1` (0.86s, 26.7 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Also, I just wanted to briefly say that the meeting is postponed to 3 o'clock today.
- `de2` (0.74s, 25.0 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Can you please send me the numbers from last quarter? I need them by Friday.
- `de3` (0.94s, 25.9 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is going well, but we have an issue with database performance that we need to address next week.
- `de4` (1.32s, 26.2 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: I opened the pull request for the Kubernetes deployment yesterday. Frau Schneider says we need an additional 250 euros in budget. Can you review it by Thursday?
- `de5` (2.07s, 24.6 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hi Thomas, quick update on the sprint: the backend team is done with the login API, but the frontend is still stuck on caching. We should clarify in tomorrow's daily whether to push the release back a week. What do you think?
- `en1` (0.72s, 25.0 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: I just wanted to say the meeting has been moved to 3 PM tomorrow.

**clean**

- `de1` (0.72s, 25.0 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting wird für morgen um 15:00 Uhr verschoben.
- `de2` (0.77s, 24.6 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Könnten Sie mir bitte die Zahlen des letzten Quartals bis Freitag zusenden?
- `de3` (0.95s, 25.3 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt verläuft bisher erfolgreich; jedoch muss die Datenbankperformance in der nächsten Woche bearbeitet werden.
- `de4` (1.66s, 26.1 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: Ich habe gestern einen Pull Request für das Kubernetes-Deployment erstellt. Frau Schneider hat darauf hingewiesen, dass wir zusätzlich 250 Euro Budget benötigen. Könnten Sie diese Anfrage bis Donnerstag prüfen?
- `de5` (2.12s, 26.1 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hallo Thomas, kurzupdate zum Sprint: Das Backend-Team hat die Login-API abgeschlossen, das Frontend hängt jedoch am Caching. Wir sollten im morgigen Daily klären, ob wir das Release um eine Woche verschieben müssen. Was meinst du?

### `ministral-3:3b`

**translate**

- `de1` (0.36s, 40.6 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: The meeting is being rescheduled to **3 PM tomorrow**.
- `de2` (0.51s, 38.3 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Could you please send me the numbers from last quarter? I need them by Friday.
- `de3` (0.70s, 38.8 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is running well so far, but we still have an issue with database performance that we need to address next week.
- `de4` (0.86s, 39.8 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: I opened a pull request for the Kubernetes deployment yesterday. Frau Schneider says we need an additional €250 in budget—could you review it by Thursday?
- `de5` (1.31s, 38.2 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hi Thomas, here’s a quick update on the sprint: the backend team has finished the login API, but the frontend is still stuck due to caching. We’ll discuss whether to delay the release by a week tomorrow—what do you think?
- `en1` (0.35s, 40.6 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: The meeting has been rescheduled to three o’clock tomorrow.

**clean**

- `de1` (0.30s, 42.3 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting wird morgen um drei Uhr stattfinden.
- `de2` (0.65s, 37.7 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Können Sie mir bitte die Zahlen des letzten Quartals zukommen? Bitte benötige ich sie bis Freitag.
- `de3` (0.70s, 40.5 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft bisher gut, doch die Datenbankperformance stellt aktuell ein Hindernis dar, das wir in der kommenden Woche angehen müssen.
- `de4` (1.08s, 40.0 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: Der Pull Request für das Kubernetes Deployment wurde gestern erstellt.
Frau Schneider fordert zusätzliche Mittel von 250 € auf.
Kannst du den Review bis Donnerstag abschließen?
- `de5` (1.58s, 39.0 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Guten Tag Thomas,

wir haben kurz besprochen: Das Backend-Team hat die Login-API abgeschlossen. Im Frontend bleibt noch das Caching-Problem. Morgen im Daily wird geklärt, ob wir den Release um eine Woche verschieben. Wie siehst du das?

### `gemma4:e2b`

**translate**

- `de1` (0.29s, 67.9 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: I just wanted to quickly say that the meeting will be postponed to three o'clock tomorrow.
- `de2` (0.31s, 60.0 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Can you please send me the numbers from the last quarter, I need them by Friday.
- `de3` (0.44s, 62.8 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is going quite well, but we still have a problem with the database performance, and we have to address that next week.
- `de4` (0.47s, 69.6 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: I opened the pull request for the Kubernetes deployment yesterday, and Ms. Schneider says we need two hundred fifty euros more budget. Can you review that by Thursday?
- `de5` (0.67s, 74.2 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hello Thomas, update on the sprint. The backend team is finished with the login API, but the frontend is still stuck on caching. We should clarify tomorrow in the daily whether we should postpone the release by a week. What do you think?
- `en1` (0.16s, 56.2 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: The meeting is moved to three pm tomorrow.

**clean**

- `de1` (0.16s, 66.7 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting wird morgen auf drei Uhr verschoben.
- `de2` (0.20s, 65.0 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Bitte senden Sie mir die Zahlen des letzten Quartals bis Freitag.
- `de3` (0.35s, 70.6 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft gut, aber wir haben noch ein Problem mit der Datenbankleistung, das wir nächste Woche angehen müssen.
- `de4` (0.53s, 67.3 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: Ich habe gestern den Pull Request für das Kubernetes-Deployment erstellt. Frau Schneider benötigt noch zweihundertfünfzig Euro Budget. Kannst du dies bis Donnerstag überprüfen?
- `de5` (0.76s, 68.0 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Thomas, kurzes Update zum Sprint: Das Backend-Team hat die Login-API fertiggestellt, das Frontend hängt noch beim Caching. Wir sollten morgen im Daily klären, ob wir das Release um eine Woche verschieben. Was denkst du?

### `granite4.2:3b`

**translate**

- `de1` (0.49s, 43.5 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Also I just wanted to say that the meeting will be moved to three o'clock tomorrow.
- `de2` (0.47s, 44.2 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Can you please send me the numbers from the last quarter? I need them by Friday.
- `de3` (0.63s, 43.3 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is running very well overall, but we still have one issue with database performance that we need to address next week.
- `de4` (0.76s, 43.1 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: I opened the pull request for the Kubernetes deployment yesterday, and Frau Schneider says we need an additional 250 euros. Can you review it by Thursday?
- `de5` (1.11s, 42.6 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hi Thomas, here's a short update on the sprint: the backend team is finished with the login API, but the frontend is still stuck on caching. Should we move the release by one week? What do you think?
- `en1` (0.37s, 45.5 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: Sure, the meeting is moved to 3 PM tomorrow.

**clean**

- `de1` (0.34s, 45.2 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting wird morgen auf 3 Uhr verschoben.
- `de2` (0.49s, 43.5 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Könntest du bitte die Zahlen vom letzten Quartal bis Freitag schicken?
- `de3` (0.68s, 43.1 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft gut, aber es gibt ein Problem mit der Datenbank-Performance, das wir nächste Woche angehen sollten.
- `de4` (1.19s, 41.7 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: Ich habe gestern den Pull Request für das Kubernetes-Deployment aufgegeben. Frau Schneider meint, wir benötigen noch 250 Euro mehr Budget. Könntest du den Review bis Donnerstag abschließen?
- `de5` (1.53s, 42.0 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hallo Thomas,

Sprint-Update: Das Backend-Team ist mit der Login-API fertig. Das Frontend hängt noch am Caching. Wir sollten morgen im Daily besprechen, ob wir den Release um eine Woche verschieben.

Was meinst du?

### `translategemma:4b`

**translate**

- `de1` (0.60s, 36.5 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Also, I just wanted to say that the meeting is postponed to 3 pm tomorrow.
- `de2` (0.59s, 36.5 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Can you please send me the figures for the last quarter? I need them by Friday.
- `de3` (0.80s, 36.1 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: the project is going well so far, but we still have a problem with database performance, which we need to address next week
- `de4` (1.22s, 34.5 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: Um, I submitted the pull request for the Kubernetes deployment yesterday, and Frau Schneider says we still need an additional 250 euros in budget. Can you please review it by Thursday?
- `de5` (1.60s, 35.1 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hi Thomas, here's a quick update: the backend team has finished the login API, but the frontend is still working on caching. We should discuss whether to postpone the release by a week tomorrow during the daily stand-up. What do you think?
- `en1` (0.63s, 36.4 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: So, I just wanted to say that the meeting has been moved to 3 pm tomorrow.

**clean**

- `de1` (0.60s, 36.5 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting wird auf morgen, 15:00 Uhr, verschoben.
- `de2` (0.66s, 36.2 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Bitte senden Sie mir die Zahlen des letzten Quartals, da ich diese bis Freitag benötige.
- `de3` (0.54s, 37.0 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft grundsätzlich gut. Wir müssen jedoch die Datenbankperformance nächste Woche verbessern.
- `de4` (0.94s, 36.0 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: Ich habe gestern einen Pull Request für den Kubernetes-Deployment erstellt. Frau Schneider benötigt zusätzliche 250 Euro Budget. Bitte bis Donnerstag prüfen.
- `de5` (1.37s, 35.7 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hallo Thomas,

kurzes Update zum Sprint: Backend-Team hat die Login-API fertiggestellt. Frontend arbeitet noch an Caching. Sollten wir das Release um eine Woche verschieben? Was hältst du davon?

### `qwen3:4b-instruct`

**translate**

- `de1` (0.54s, 36.0 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Anyway, just to say the meeting is being postponed to tomorrow at three o'clock.
- `de2` (0.56s, 36.5 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Can you please send me the numbers from the last quarter? I need them by Friday.
- `de3` (0.80s, 36.0 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is going pretty well, but we still have a problem with database performance, and that needs to be addressed next week.
- `de4` (1.03s, 35.4 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: I opened the pull request for the Kubernetes deployment yesterday, and Frau Schneider says we need an additional 250 euros in budget. Can you review that by Thursday?
- `de5` (1.51s, 33.6 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hello Thomas, quick update on the sprint. The backend team is done with the login API, but the frontend is still stuck on caching. Should we move the release by a week tomorrow in the daily standup? What do you think?
- `en1` (0.51s, 37.0 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: So I just want to say the meeting is moved to 3 pm tomorrow.

**clean**

- `de1` (0.59s, 36.4 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Ich möchte nur kurz sagen, dass das Meeting morgen auf drei Uhr verschoben wird.
- `de2` (0.76s, 36.1 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Kannst du mir bitte die Zahlen aus dem letzten Quartal schicken? Ich brauche sie bis Freitag.
- `de3` (0.93s, 33.7 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft soweit gut, aber wir haben noch ein Problem mit der Datenbankperformance, das wir nächste Woche angehen müssen.
- `de4` (1.31s, 34.6 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: Ich habe gestern den Pull Request zum Kubernetes-Deployment aufgemacht. Frau Schneider meint, wir benötigen noch 250 Euro mehr Budget. Kannst du das bis Donnerstag reviewen?
- `de5` (1.74s, 34.9 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hallo Thomas, kurzes Update zum Sprint: Das Backend-Team ist mit der Login-API fertig, das Frontend hängt jedoch noch am Caching. Wir sollten morgen im Daily klären, ob wir das Release um eine Woche verschieben. Was meinst du?

### `gemma3:4b`

**translate**

- `de1` (0.66s, 36.2 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Also, I just wanted to say that the meeting is now postponed to three o'clock tomorrow.
- `de2` (0.61s, 36.5 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Can you please send me the figures from the last quarter, I need them by Friday.
- `de3` (0.78s, 36.2 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: the project is going quite well, but we do have a problem with database performance and we need to address that next week
- `de4` (1.04s, 35.8 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: I submitted the pull request for the Kubernetes deployment yesterday, and Frau Schneider thinks we still need an additional €250 budget. Could you review it by Thursday?
- `de5` (1.62s, 35.3 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hello Thomas, here's a quick update on the sprint. The backend team has finished the login API, but the frontend is still stuck with caching. We should discuss tomorrow in the daily whether we should postpone the release by a week. What do you think?
- `en1` (0.58s, 36.7 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: So, I just wanted to say that the meeting is moved to three PM tomorrow.

**clean**

- `de1` (0.52s, 37.2 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting wird morgen auf 15:00 Uhr verschoben.
- `de2` (0.60s, 36.5 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Bitte senden Sie mir die Zahlen des letzten Quartals, ich benötige sie bis Freitag.
- `de3` (0.78s, 35.7 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft derzeit gut, jedoch besteht weiterhin ein Problem mit der Datenbankperformance, welches wir nächste Woche adressieren werden.
- `de4` (0.89s, 36.2 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: Ich habe gestern einen Pull Request für das Kubernetes Deployment erstellt. Frau Schneider benötigt zusätzlich 250 Euro Budget. Bitte bis Donnerstag prüfen.
- `de5` (1.58s, 34.9 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hallo Thomas,

Backend hat die Login-API fertiggestellt. Frontend arbeitet noch an der Caching-Implementierung. Wir sollten morgen im Daily besprechen, ob eine Verschiebung des Releases um eine Woche möglich ist. Was denkst du dazu?

### `llama3.2:3b`

**translate**

- `de1` (0.45s, 46.3 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Also I just wanted to say that the meeting will be postponed to three o'clock tomorrow.
- `de2` (0.35s, 46.9 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Can you please send me the numbers from the last quarter by Friday?
- `de3` (0.66s, 45.2 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: The project is running quite well so far, but we have a problem with the database performance and we need to tackle that next week.
- `de4` (0.78s, 44.6 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: I created a pull request for the Kubernetes deployment yesterday and Frau Schneider says we need an additional 255 euros in the budget. Can you review this by Thursday?
- `de5` (1.34s, 43.1 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hello Thomas, here's a brief update on the sprint: The backend team has finished the login API, but the frontend is still stuck on caching issues. We should discuss this tomorrow in the daily to decide whether to delay the release by a week. What are your thoughts?
- `en1` (0.39s, 44.4 tok/s)
  - in:  um so i just wanted to say that the meeting is moved to three pm tomorrow
  - out: The meeting has been rescheduled to take place at 3 pm tomorrow.

**clean**

- `de1` (0.32s, 46.4 tok/s)
  - in:  ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr
  - out: Das Meeting wird morgen auf drei Uhr verschoben.
- `de2` (0.50s, 44.7 tok/s)
  - in:  kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag
  - out: Kannst du mir bitte die Zahlen vom letzten Quartal schicken, bis Freitag?
- `de3` (0.80s, 43.4 tok/s)
  - in:  das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen
  - out: Das Projekt läuft soweit ganz gut, aber wir haben noch ein Problem mit der Datenbankleistung, das müssen wir nächste Woche angehen.
- `de4` (1.23s, 42.9 tok/s)
  - in:  ähm ich hab gestern den pull request fürs kubernetes deployment aufgemacht und frau schneider meint wir brauchen noch zweihundertfünfzig euro mehr budget kannst du das bis donnerstag reviewen
  - out: Ich habe gestern einen Pull-Request für das Kubernetes-Deployment aufgemacht und Frau Schneider sagt, dass wir noch 255 Euro mehr fürs Budget benötigen. Ich werde mich bis Donnerstag um die Überprüfung kümmern.
- `de5` (1.60s, 41.8 tok/s)
  - in:  hallo thomas kurzes update zum sprint also das backend team ist mit der login api fertig aber das frontend hängt halt noch am caching wir sollten morgen im daily klären ob wir das release um eine woche verschieben was meinst du
  - out: Hallo, hier ist der umformulierte Text:

Hallo, ich möchte einen kurzen Update zum Sprint teilen. Das Backend-Team hat die Login-API abgeschlossen, während das Frontend noch am Caching hängt. Morgen im Daily sollten wir überlegen, ob wir das Release um eine Woche verschieben sollten. Was denkst du darüber?

## Quality judgement (2026-10-27, Apple M4 32 GB, Ollama 0.40.9)

Requests send `"think": false`, which hybrid-thinking models (qwen3.5, gemma4, granite4.2) need. Two harder cases were added (`de4`: tech terms, name, amount; `de5`: long multi-sentence with a question). Key translate cases were re-run 4× more to check consistency. Latencies are far lower than in June (≈1 s vs ≈3 s) for every model, including the baselines. The cause is the newer Ollama runtime, not the models.

| Model | DE→EN translate faults | German clean | Verdict |
|---|---|---|---|
| `gemma4:e2b` | none. Minor: drops "kurzes" in de5 (4/4 runs identical) | good. du→Sie in de2, drops "Hallo" in de5 | **best translate, fastest (0.76 s max)**. 7.5 GB download (vision/audio encoders), ~7.4 GB resident |
| `qwen3:4b-instruct` | de5: turns "we should clarify in the daily whether…" into a garbled question "Should we move the release by a week tomorrow in the daily?" (4/4 runs) | **best**. Keeps du, register and all content | current default. Still best for German Custom rewrites |
| `qwen3.5:4b` | de1: "morgen" → **"today"** (4/4 runs). de3 sometimes drops "still" | du→Sie, de3 meaning shifted | rejected: wrong date |
| `ministral-3:3b` | de1 emits markdown `**…**`. de5 drops "in the daily". en1 rewrites wording | poor: broken German (de2), meaning change (de1), invented "wir haben kurz besprochen" (de5) | rejected |
| `granite4.2:3b` | de3 "very well overall" (exaggerated). de5 drops the daily clarification. en1 "Sure," preamble | ok | rejected |
| `translategemma:4b` | keeps filler "Um," (de4). Lowercase, no period (de3) | changes meaning (de3), drops content (de5) | rejected: translation-only template, ignores our rules |
| `gemma3:4b` | lowercase/no punctuation (de3), missing "?" (de2) | du→Sie, drops content in de5 | unchanged |
| `llama3.2:3b` | **wrong number** 250 → "255 euros" (de4) | preamble "hier ist der umformulierte Text" (de5), request turned into commitment (de4) | rejected |
