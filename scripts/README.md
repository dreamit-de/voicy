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
(`argmax-oss-swift`, `from: 1.1.1`) and loads models from the **same on-disk location the app uses**
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

Variants are read from the app's model folder (run the app's setup/model step
first). Set `BENCH_DOWNLOAD_BASE=/some/dir` to download the variants the app has
not installed into that folder instead; the app's model folder is never touched.
That is how the `_547MB`, `turbo_632MB` and full large-v3 builds in
`bench-results/transcription.md` were measured.

## Findings (Apple M4, 32 GB, 2026-10-27)

See `bench-results/rewrite.md` and `bench-results/transcription.md` for the full
tables and transcripts. Headlines:

- **Transcription:** keep `openai_whisper-large-v3-v20240930_626MB` (onboarding
  default). On the 9-sample set (incl. tech terms, numbers, a long sprint update)
  all four large-v3 builds produced identical transcripts (1 % DE WER, ~1 s per
  sentence). `turbo_632MB` is ~33 % faster with the same output but supported on
  M2–M4 only; the full 1.6 GB build is no more accurate and twice as slow.
  `small` scores 7 % DE WER, so the code fallback `WhisperEngine.defaultModel`
  now points at the same Large v3 Turbo build.
  The 14 % English WER is identical for every model and comes from number
  formatting ("3pm", "10"), not recognition errors.
- **Rewrite (German → English):** **`gemma4:e2b`** is now the default — the only
  model with no faithfulness faults on all six translate cases, identical output
  across repeat runs, and the lowest latency (0.76 s max). Its catch is a 7.5 GB
  download. With Ollama 0.40.9 every candidate answers in ~1 s, so quality, not
  the 5 s budget, decides. The previous default `qwen3:4b-instruct` garbles the
  long multi-sentence case every run but keeps the best *German* (du, register,
  all content) — the recommendation for Custom rewrites via the per-style model.
  `llama3.2:3b` turned 250 € into 255 €; `qwen3.5:4b` turned "morgen" into
  "today". The bench and the app both send `think: false`, so hybrid-thinking
  models answer directly; pure reasoning models (`gpt-oss`, etc.) stay excluded.
