# Local model performance benchmarks

Two reusable harnesses for picking and tuning the local models behind Voice
Transcript. Both run fully on-device and write Markdown + JSON to
`scripts/bench-results/`.

## Why

The app has two model stages with different requirements:

- **Transcription** (WhisperKit / Apple Neural Engine) — must be accurate for
  both German and English dictation.
- **Rewrite** (Ollama) — the built-in style translates German → English; this
  must finish in **under 5 seconds** with a faithful result.

These scripts measure latency + quality so the defaults in
`Modules/Transcription/WhisperModelCatalog.swift` and
`Modules/RewriteService/OllamaModelCatalog.swift` are backed by numbers, not
guesses. Re-run them whenever a newer local model lands.

## 1. Rewrite (Ollama) — `bench-rewrite.py`

Times each installed Ollama model (warm, model kept resident) on fixed German
and English dictation samples, for two prompts:

- `translate` — the built-in **German → English** style (DE in → EN out, EN in
  → light cleanup).
- `clean` — a concise-professional German same-language rewrite (a German
  Custom style), to confirm the model is still good for same-language editing.

```bash
python3 scripts/bench-rewrite.py                       # all installed non-reasoning models
python3 scripts/bench-rewrite.py --models qwen3:4b-instruct,gemma3:4b --runs 3
```

Reasoning models (`gpt-oss`, `*thinking`, `deepseek-r1`, `qwq`) are skipped —
they "think" for 10–30 s per rewrite and break dictation flow. Stdlib only; no
pip install. Reads/writes Ollama at `127.0.0.1:11434` (override with
`OLLAMA_HOST`).

## 2. Transcription (WhisperKit) — `bench-transcription/`

A standalone Swift package that drives the **same WhisperKit the app pins**
(`from: 0.9.0`) and loads models from the **same on-disk location the app uses**
(`~/Library/Application Support/Voice Transcript/Models/`), so it never
re-downloads and the numbers reflect the real transcription path. It synthesises
German/English speech with macOS `say`, downsamples to 16 kHz mono via ffmpeg,
transcribes with each model variant, and reports load time, per-sample latency,
and a rough word error rate (WER) against the reference text.

```bash
brew install ffmpeg          # one-time
cd scripts/bench-transcription
./run.sh                                                              # default variants
./run.sh openai_whisper-base,openai_whisper-large-v3-v20240930_626MB  # pick variants
```

Variants must already be installed by the app (run the app's setup/model step
first), otherwise WhisperKit would try to download into a sandbox-blocked path.

## Findings (Apple M4, 32 GB, 2026-06-28)

See `bench-results/rewrite.md` and `bench-results/transcription.md` for the full
tables and transcripts. Headlines:

- **Transcription:** `large-v3-turbo` (`openai_whisper-large-v3-v20240930_626MB`)
  hit **0 % WER on German** and excellent English at ~1–2 s/sentence — one
  multilingual model serves both DE and EN, so **no separate per-language model
  is needed**. `base` is a fast, decent fallback (~9 % DE WER, mostly number
  formatting). Note: the large model has a long *one-time* cold ANE-compile on
  first load (cached afterwards); the app prewarms it.
- **Rewrite (German → English):** **`qwen3:4b-instruct`** was the only small
  model with zero faithfulness faults (kept "tomorrow", "three o'clock",
  speech acts; translated filler "also" → "Well") at **~2.9 s warm** — now the
  default. `gemma3:4b` (~3.5–4.9 s) keeps the most natural *German* for Custom
  rewrites; `llama3.2:3b` and `qwen2.5:3b-instruct` (~2 s) are fastest but each
  occasionally clip/omit a detail. Disqualified for the translation default by
  the 5 s budget: the newest **`gemma3n:e4b` (~5.7 s)**, `gemma3:12b` (~14 s),
  and all reasoning models (`gpt-oss`, etc.).
