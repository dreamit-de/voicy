import Foundation
import WhisperKit

// Reads audio/manifest.json: [{ "file": "...", "lang": "de"|"en", "reference": "..." }]
// For each model variant (CLI arg, comma-separated) transcribes every sample
// and reports load time, per-sample latency, words-per-second, and a rough
// word error rate (WER) against the reference, plus the raw transcript.

struct Sample: Decodable {
    let file: String
    let lang: String
    let reference: String
}

func normalise(_ s: String) -> [String] {
    let lowered = s.lowercased()
    let stripped = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == " " ? Character($0) : " " }
    return String(stripped).split(separator: " ").map(String.init)
}

// Levenshtein word distance → WER.
func wer(reference: String, hypothesis: String) -> Double {
    let r = normalise(reference)
    let h = normalise(hypothesis)
    if r.isEmpty { return h.isEmpty ? 0 : 1 }
    var prev = Array(0...h.count)
    var cur = [Int](repeating: 0, count: h.count + 1)
    for i in 1...r.count {
        cur[0] = i
        for j in 1...h.count {
            let cost = r[i - 1] == h[j - 1] ? 0 : 1
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
        }
        swap(&prev, &cur)
    }
    return Double(prev[h.count]) / Double(r.count)
}

let args = CommandLine.arguments
let variants: [String] = args.count > 1
    ? args[1].split(separator: ",").map(String.init)
    : ["openai_whisper-base", "openai_whisper-small", "openai_whisper-large-v3-v20240930_626MB"]

// Load from the SAME on-disk location the app uses
// (~/Library/Application Support/Voice Transcript/Models/<variant>/), so we
// reuse models the app already downloaded and never hit Hugging Face.
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
let modelsRoot = appSupport.appendingPathComponent("Voice Transcript/Models", isDirectory: true)
let tokenizersRoot = modelsRoot.appendingPathComponent("Tokenizers", isDirectory: true)

let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let audioDir = here.appendingPathComponent("audio")
let manifestURL = audioDir.appendingPathComponent("manifest.json")
guard let manifestData = try? Data(contentsOf: manifestURL),
      let samples = try? JSONDecoder().decode([Sample].self, from: manifestData) else {
    FileHandle.standardError.write("Missing or invalid audio/manifest.json — run ./run.sh\n".data(using: .utf8)!)
    exit(1)
}

struct Row { let variant: String; let lang: String; let file: String; let seconds: Double; let wer: Double; let text: String }
var rows: [Row] = []
var loadTimes: [String: Double] = [:]

for variant in variants {
    FileHandle.standardError.write("\n=== \(variant) ===\n".data(using: .utf8)!)
    let t0 = Date()
    let pipe: WhisperKit
    do {
        let modelFolder = modelsRoot.appendingPathComponent(variant, isDirectory: true).path
        pipe = try await WhisperKit(WhisperKitConfig(
            model: variant,
            modelFolder: modelFolder,
            tokenizerFolder: tokenizersRoot,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true
        ))
    } catch {
        FileHandle.standardError.write("  load failed: \(error)\n".data(using: .utf8)!)
        continue
    }
    loadTimes[variant] = Date().timeIntervalSince(t0)
    FileHandle.standardError.write("  loaded in \(String(format: "%.1f", loadTimes[variant]!))s\n".data(using: .utf8)!)

    for s in samples {
        let path = audioDir.appendingPathComponent(s.file).path
        let opts = DecodingOptions(task: .transcribe, language: s.lang, temperature: 0,
                                   usePrefillPrompt: true, withoutTimestamps: true)
        let start = Date()
        var text = ""
        do {
            let results = try await pipe.transcribe(audioPath: path, decodeOptions: opts)
            text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            FileHandle.standardError.write("  [\(s.file)] error: \(error)\n".data(using: .utf8)!)
            continue
        }
        let dt = Date().timeIntervalSince(start)
        let e = wer(reference: s.reference, hypothesis: text)
        rows.append(Row(variant: variant, lang: s.lang, file: s.file, seconds: dt, wer: e, text: text))
        FileHandle.standardError.write("  [\(s.lang)/\(s.file)] \(String(format: "%.2f", dt))s  WER \(String(format: "%.0f", e * 100))%  :: \(text)\n".data(using: .utf8)!)
    }
}

// Markdown report to stdout (run.sh redirects it to bench-results/transcription.md).
print("# Transcription model benchmark\n")
print("WhisperKit on Apple Neural Engine · `say`-synthesised DE/EN samples · WER vs reference text\n")
print("## Summary\n")
print("| Model | load | DE avg | EN avg | DE WER | EN WER |")
print("|---|---|---|---|---|---|")
for v in variants {
    let vr = rows.filter { $0.variant == v }
    if vr.isEmpty { continue }
    func avg(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }
    let de = vr.filter { $0.lang == "de" }, en = vr.filter { $0.lang == "en" }
    let load = loadTimes[v].map { String(format: "%.1fs", $0) } ?? "—"
    print("| `\(v)` | \(load) | \(String(format: "%.2fs", avg(de.map(\.seconds)))) | \(String(format: "%.2fs", avg(en.map(\.seconds)))) | \(String(format: "%.0f%%", avg(de.map(\.wer)) * 100)) | \(String(format: "%.0f%%", avg(en.map(\.wer)) * 100)) |")
}
print("\n## Transcripts\n")
for v in variants {
    let vr = rows.filter { $0.variant == v }
    if vr.isEmpty { continue }
    print("### `\(v)`\n")
    for r in vr {
        print("- `\(r.lang)/\(r.file)` (\(String(format: "%.2fs", r.seconds)), WER \(String(format: "%.0f%%", r.wer * 100))): \(r.text)")
    }
    print("")
}
