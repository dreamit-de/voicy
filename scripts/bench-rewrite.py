#!/usr/bin/env python3
"""Benchmark local Ollama models for the Voice Transcript Rewrite feature.

Measures, per model, the warm latency and output quality for two prompts:
  - translate : the new built-in "German → English" style (DE in → EN out,
                EN in → light cleanup). This is the default Rewrite path.
  - clean     : a concise-professional German rewrite (representative of a
                German Custom style), to confirm the model is still good for
                same-language rewriting.

Latency is wall-clock around a non-streamed /api/generate call, after one
warm-up call per model so cold model-load time is excluded (the app keeps the
model resident via keep_alive). Ollama's own eval timings are recorded too.

Outputs:
  scripts/bench-results/rewrite.md    human-readable table
  scripts/bench-results/rewrite.json  full outputs (for quality judging)

Usage:
  python3 scripts/bench-rewrite.py [--models gemma3:4b,llama3.2:3b] [--runs 2]

With no --models, benchmarks every installed model except reasoning models
(gpt-oss, *thinking) which spend many seconds "thinking" and break dictation
flow.
"""
import argparse
import json
import os
import time
import urllib.request
from pathlib import Path

OLLAMA = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
RESULTS_DIR = Path(__file__).resolve().parent / "bench-results"

# DE→EN translation built-in (mirrors what ships in translate.md). EN passes
# through with light cleanup; DE is translated to natural English.
TRANSLATE_PROMPT = """You are a translation assistant for short voice-dictated text.

Output rules — strict:
- Output ONLY the result text. No preamble, no acknowledgement ("Sure", "Here is"), no explanation, no quotes, no markdown.

Behaviour:
- If the input is German, translate it into natural, fluent English. Keep the same meaning, speech act (statement/question/request), person, and tone.
- If the input is already English, leave it essentially unchanged — only fix obvious grammar, punctuation, and remove filler words ("um", "you know").
- Remove dictation filler words ("ähm", "halt", "you know", "um").
- Do not invent facts, names, numbers, or commitments not present in the input.
- Keep the length close to the input."""

# Representative German same-language rewrite (a German Custom style).
CLEAN_PROMPT = """Du bist ein Schreibassistent. Formuliere die Eingabe knapp und professionell um, ohne den Sinn zu verändern.

Regeln:
- Antworte nur mit dem umformulierten Text. Kein Vorspann, keine Anführungszeichen, keine Erklärung.
- Behalte die Sprache der Eingabe bei.
- Korrigiere Grammatik, Zeichensetzung und Großschreibung. Entferne Füllwörter ("ähm", "halt")."""

CASES = [
    ("de1", "de", "ähm also ich wollte nur kurz sagen dass das meeting halt morgen verschoben wird auf drei uhr"),
    ("de2", "de", "kannst du mir bitte ähm die zahlen vom letzten quartal schicken ich brauch die bis freitag"),
    ("de3", "de", "das projekt läuft soweit ganz gut aber wir haben halt noch ein problem mit der datenbank performance und das müssen wir nächste woche angehen"),
    ("en1", "en", "um so i just wanted to say that the meeting is moved to three pm tomorrow"),
]

REASONING_HINTS = ("gpt-oss", "thinking", "deepseek-r1", "qwq")


def installed_models():
    req = urllib.request.Request(f"{OLLAMA}/api/tags")
    with urllib.request.urlopen(req, timeout=5) as r:
        data = json.load(r)
    return [m["name"] for m in data.get("models", [])]


def generate(model, system, prompt, num_predict=None):
    body = {
        "model": model,
        "system": system,
        "prompt": prompt,
        "stream": False,
        "keep_alive": "60m",
        "options": {"temperature": 0.3},
    }
    if num_predict is not None:
        body["options"]["num_predict"] = num_predict
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"{OLLAMA}/api/generate", data=data,
        headers={"Content-Type": "application/json"},
    )
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=300) as r:
        out = json.load(r)
    wall = time.perf_counter() - t0
    return {
        "response": out.get("response", "").strip(),
        "wall_s": round(wall, 2),
        "eval_count": out.get("eval_count"),
        "eval_s": round(out.get("eval_duration", 0) / 1e9, 2) if out.get("eval_duration") else None,
        "load_s": round(out.get("load_duration", 0) / 1e9, 2) if out.get("load_duration") else None,
    }


def bench_model(model, runs):
    print(f"\n=== {model} ===")
    # Warm-up: pay the cold model-load once, excluded from measurements.
    print("  warming up…", flush=True)
    try:
        generate(model, "Echo.", "OK", num_predict=4)
    except Exception as e:
        print(f"  warm-up failed: {e}")
        return {"model": model, "error": str(e)}

    results = []
    for mode, system in (("translate", TRANSLATE_PROMPT), ("clean", CLEAN_PROMPT)):
        for cid, lang, text in CASES:
            # "clean" only makes sense for German same-language rewrite.
            if mode == "clean" and lang != "de":
                continue
            walls = []
            last = None
            for _ in range(runs):
                last = generate(model, system, text)
                walls.append(last["wall_s"])
            best = min(walls)
            results.append({
                "mode": mode, "case": cid, "lang": lang,
                "input": text, "output": last["response"],
                "wall_best_s": best, "wall_runs": walls,
                "eval_count": last["eval_count"], "tok_per_s":
                    round(last["eval_count"] / last["eval_s"], 1)
                    if last.get("eval_count") and last.get("eval_s") else None,
            })
            print(f"  [{mode}/{cid}] {best:.2f}s :: {last['response'][:70]}")
    walls = [r["wall_best_s"] for r in results]
    return {
        "model": model,
        "max_latency_s": max(walls),
        "avg_latency_s": round(sum(walls) / len(walls), 2),
        "under_5s": max(walls) < 5.0,
        "results": results,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", help="comma-separated model tags")
    ap.add_argument("--runs", type=int, default=2, help="timed runs per case (best is kept)")
    args = ap.parse_args()

    if args.models:
        models = [m.strip() for m in args.models.split(",") if m.strip()]
    else:
        models = [m for m in installed_models()
                  if not any(h in m.lower() for h in REASONING_HINTS)]
        skipped = [m for m in installed_models() if m not in models]
        if skipped:
            print(f"Skipping reasoning models (too slow for dictation): {skipped}")

    print(f"Benchmarking {len(models)} models, {args.runs} runs/case: {models}")
    report = [bench_model(m, args.runs) for m in models]

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    (RESULTS_DIR / "rewrite.json").write_text(json.dumps(report, indent=2, ensure_ascii=False))

    # Markdown summary table.
    lines = ["# Rewrite model benchmark", "",
             f"Host: Ollama at {OLLAMA} · best of {args.runs} runs/case · model kept warm",
             "", "## Latency summary", "",
             "| Model | max latency | avg latency | < 5 s |",
             "|---|---|---|---|"]
    ok = [r for r in report if "error" not in r]
    for r in sorted(ok, key=lambda x: x["max_latency_s"]):
        lines.append(f"| `{r['model']}` | {r['max_latency_s']:.2f}s | "
                     f"{r['avg_latency_s']:.2f}s | {'✅' if r['under_5s'] else '❌'} |")
    for r in report:
        if "error" in r:
            lines.append(f"| `{r['model']}` | — | — | error: {r['error']} |")

    lines += ["", "## Outputs (translate = DE→EN built-in, clean = DE Custom rewrite)", ""]
    for r in ok:
        lines.append(f"### `{r['model']}`\n")
        for mode in ("translate", "clean"):
            lines.append(f"**{mode}**\n")
            for x in r["results"]:
                if x["mode"] != mode:
                    continue
                lines.append(f"- `{x['case']}` ({x['wall_best_s']:.2f}s, "
                             f"{x['tok_per_s']} tok/s)")
                lines.append(f"  - in:  {x['input']}")
                lines.append(f"  - out: {x['output']}")
            lines.append("")
    (RESULTS_DIR / "rewrite.md").write_text("\n".join(lines))
    print(f"\nWrote {RESULTS_DIR/'rewrite.md'} and rewrite.json")


if __name__ == "__main__":
    main()
