#!/usr/bin/env bash
# Build & run the WhisperKit transcription benchmark.
#
#   ./run.sh [variant1,variant2,...]
#
# Generates German/English speech samples with macOS `say` (downsampled to
# 16 kHz mono via ffmpeg), then transcribes them with each WhisperKit model
# variant and writes ../bench-results/transcription.md.
#
# Set BENCH_DOWNLOAD_BASE=/some/dir to auto-download variants the app has not
# installed (kept out of the app's model folder).
#
# Requires: ffmpeg (brew install ffmpeg), Swift toolchain, network for the
# first run (WhisperKit downloads model variants from Hugging Face).
set -euo pipefail
cd "$(dirname "$0")"

AUDIO="audio"
RESULTS="../bench-results"
mkdir -p "$AUDIO" "$RESULTS"

# (file, voice, lang, text-to-speak, reference-for-WER)
gen() {
  local file="$1" voice="$2" text="$3"
  if [[ ! -f "$AUDIO/$file" ]]; then
    say -v "$voice" -o "$AUDIO/tmp.aiff" "$text"
    ffmpeg -y -loglevel error -i "$AUDIO/tmp.aiff" -ar 16000 -ac 1 "$AUDIO/$file"
    rm -f "$AUDIO/tmp.aiff"
  fi
}

gen de_1.wav Anna "Das Meeting wird morgen auf drei Uhr verschoben."
gen de_2.wav Anna "Bitte schick mir die Zahlen vom letzten Quartal bis Freitag."
gen de_3.wav Anna "Das Projekt läuft soweit gut, aber wir haben noch ein Problem mit der Datenbank-Performance."
gen en_1.wav Daniel "The meeting is moved to three p m tomorrow."
gen en_2.wav Daniel "Please send me the numbers from last quarter by Friday."
# Harder samples (added 2026-10-27): longer dictation, numbers/dates, names,
# English tech terms inside German sentences, and one longer English passage.
gen de_4.wav Anna "Ich habe gestern Abend den Pull Request für das neue Deployment auf Kubernetes erstellt. Kannst du bitte bis Donnerstag ein Review machen?"
gen de_5.wav Anna "Am 15. März um 14:30 Uhr treffen wir uns mit Frau Schneider von Siemens in München, um das Budget von 250.000 Euro zu besprechen."
gen de_6.wav Anna "Hallo Thomas, kurzes Update zum Sprint: Das Backend-Team hat die API für den Login fertig, aber das Frontend hängt noch am Caching im Browser. Wir sollten im Daily morgen klären, ob wir das Release auf nächste Woche verschieben."
gen en_3.wav Samantha "Hi Sarah, quick update on the migration. We finished moving the database to the new cluster on Tuesday, but the Grafana dashboards still show some latency spikes. Can we schedule a call on Thursday at ten to go through the logs?"

cat > "$AUDIO/manifest.json" <<'JSON'
[
  {"file":"de_1.wav","lang":"de","reference":"Das Meeting wird morgen auf drei Uhr verschoben."},
  {"file":"de_2.wav","lang":"de","reference":"Bitte schick mir die Zahlen vom letzten Quartal bis Freitag."},
  {"file":"de_3.wav","lang":"de","reference":"Das Projekt läuft soweit gut aber wir haben noch ein Problem mit der Datenbank Performance."},
  {"file":"en_1.wav","lang":"en","reference":"The meeting is moved to three p m tomorrow."},
  {"file":"en_2.wav","lang":"en","reference":"Please send me the numbers from last quarter by Friday."},
  {"file":"de_4.wav","lang":"de","reference":"Ich habe gestern Abend den Pull Request für das neue Deployment auf Kubernetes erstellt. Kannst du bitte bis Donnerstag ein Review machen?"},
  {"file":"de_5.wav","lang":"de","reference":"Am 15. März um 14:30 Uhr treffen wir uns mit Frau Schneider von Siemens in München, um das Budget von 250.000 Euro zu besprechen."},
  {"file":"de_6.wav","lang":"de","reference":"Hallo Thomas, kurzes Update zum Sprint: Das Backend-Team hat die API für den Login fertig, aber das Frontend hängt noch am Caching im Browser. Wir sollten im Daily morgen klären, ob wir das Release auf nächste Woche verschieben."},
  {"file":"en_3.wav","lang":"en","reference":"Hi Sarah, quick update on the migration. We finished moving the database to the new cluster on Tuesday, but the Grafana dashboards still show some latency spikes. Can we schedule a call on Thursday at ten to go through the logs?"}
]
JSON

echo "Building (first run resolves & compiles WhisperKit — can take a few minutes)…"
swift build -c release

BIN=".build/release/bench-transcription"
echo "Running benchmark…"
BENCH_DATE="${BENCH_DATE:-$(date +%F)}" "$BIN" ${1:+"$1"} > "$RESULTS/transcription.md"
echo "Wrote $RESULTS/transcription.md"
