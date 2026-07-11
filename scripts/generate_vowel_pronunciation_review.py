#!/usr/bin/env python3
"""Build a local review page for real-word vowel pronunciation candidates."""

import argparse
import html
import json
import re
import subprocess
from pathlib import Path

from generate_sound_review import relative_audio_url
from generate_sounds import inspect_audio


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
VOWELS_PATH = PROJECT_ROOT / "ThaiSheet" / "Resources" / "cheatsheet" / "vowels.json"
CURRENT_SOUNDS_DIR = PROJECT_ROOT / "ThaiSheet" / "Resources" / "sounds"
SCRATCHPAD_DIR = PROJECT_ROOT / "scratchpad"
DEFAULT_CANDIDATE_DIR = SCRATCHPAD_DIR / "kore-candidate"
DEFAULT_OUTPUT = SCRATCHPAD_DIR / "vowel-pronunciation-review" / "index.html"
DEFAULT_CANDIDATE_VOICE = "th-TH-Chirp3-HD-Kore"

FORM_VARIANTS = (
    ("short", "closed", "short_closed", "Short", "Closed"),
    ("short", "open", "short_open", "Short", "Open"),
    ("long", "closed", "long_closed", "Long", "Closed"),
    ("long", "open", "long_open", "Long", "Open"),
)

MAXIMUM_ONE_WORD_DURATION = 2.4
MINIMUM_INTERNAL_SILENCE = 0.18


def internal_silence_intervals(log: str, duration: float) -> list[tuple[float, float]]:
    """Return silence gaps that are neither leading nor trailing padding."""
    starts = [float(value) for value in re.findall(r"silence_start: ([0-9.]+)", log)]
    ends = [float(value) for value in re.findall(r"silence_end: ([0-9.]+)", log)]
    return [
        (start, end)
        for start, end in zip(starts, ends)
        if start > 0.15 and end < duration - 0.15
    ]


def inspect_candidate_speech(filepath: Path) -> dict:
    """Flag overlong or segmented output for a single-word synthesis request."""
    quality = inspect_audio(filepath)
    try:
        result = subprocess.run(
            [
                "ffmpeg", "-hide_banner", "-nostats", "-i", str(filepath),
                "-af", f"silencedetect=noise=-35dB:d={MINIMUM_INTERNAL_SILENCE:g}",
                "-f", "null", "-",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as error:
        raise ValueError(f"could not inspect speech boundaries for {filepath.name}") from error

    intervals = internal_silence_intervals(result.stderr, quality.duration_seconds)
    issues = []
    if quality.duration_seconds > MAXIMUM_ONE_WORD_DURATION:
        issues.append(
            f"Overlong one-word clip ({quality.duration_seconds:.3f}s > "
            f"{MAXIMUM_ONE_WORD_DURATION:.1f}s)"
        )
    if intervals:
        issues.append(
            f"{len(intervals)} internal pause{'s' if len(intervals) != 1 else ''}; "
            "possible extra or repeated speech"
        )
    return {
        "duration": round(quality.duration_seconds, 3),
        "internalPauses": len(intervals),
        "issues": issues,
    }


def load_candidates(vowels_path: Path = VOWELS_PATH) -> list[dict]:
    """Return every displayed vowel variant and its proposed pronunciation word."""
    with vowels_path.open(encoding="utf-8") as vowels_file:
        vowels = json.load(vowels_file)["vowels"]

    candidates = []
    for row_index, vowel in enumerate(vowels, start=1):
        samples = vowel.get("samples") or {}
        pronunciations = vowel.get("pronunciations") or samples
        english_notes = (vowel.get("notes") or {}).get("en") or {}
        row_note = (vowel.get("note") or {}).get("en", "")
        for duration_key, ending_key, sample_key, duration, ending in FORM_VARIANTS:
            form = vowel[duration_key].get(ending_key)
            if not form:
                continue
            sample = pronunciations.get(sample_key) or {}
            meaning = sample.get("meaning") or {}
            candidates.append({
                "id": f"vowel-{row_index:02d}-{sample_key.replace('_', '-')}",
                "form": form,
                "sound": vowel["sounds"]["en"],
                "duration": duration,
                "ending": ending,
                "variant": sample_key,
                "word": sample.get("word", ""),
                "romanization": sample.get("romanization", ""),
                "meaningEn": meaning.get("en", ""),
                "meaningFr": meaning.get("fr", ""),
                "note": english_notes.get(sample_key, row_note),
            })
    return candidates


def build_review_data(
    candidate_dir: Path,
    output: Path,
    candidate_voice: str,
    vowels_path: Path = VOWELS_PATH,
    current_sounds_dir: Path = CURRENT_SOUNDS_DIR,
) -> dict:
    candidates = load_candidates(vowels_path)
    form_counts: dict[str, int] = {}
    for candidate in candidates:
        form = candidate["form"]
        form_counts[form] = form_counts.get(form, 0) + 1

    missing_words = []
    missing_audio = []
    speech_quality_by_word = {}
    for candidate in candidates:
        word = candidate["word"]
        current_file = current_sounds_dir / f"cheat_sheet_vowel_{word}.mp3" if word else None
        candidate_file = candidate_dir / f"cheat_sheet_sample_word_{word}.mp3" if word else None
        candidate["duplicateSpelling"] = form_counts[candidate["form"]] > 1
        candidate["currentAudio"] = (
            relative_audio_url(output, current_file)
            if current_file is not None and current_file.exists()
            else ""
        )
        candidate["candidateAudio"] = (
            relative_audio_url(output, candidate_file)
            if candidate_file is not None and candidate_file.exists()
            else ""
        )
        candidate["candidateDuration"] = None
        candidate["candidateSpeechIssues"] = []
        if not word:
            missing_words.append(candidate["id"])
        elif not candidate["candidateAudio"]:
            missing_audio.append(candidate["id"])
        else:
            if word not in speech_quality_by_word:
                speech_quality_by_word[word] = inspect_candidate_speech(candidate_file)
            speech_quality = speech_quality_by_word[word]
            candidate["candidateDuration"] = speech_quality["duration"]
            candidate["candidateSpeechIssues"] = speech_quality["issues"]

    return {
        "candidateVoice": candidate_voice,
        "currentVoice": "Bundled vowel pronunciation words",
        "items": candidates,
        "counts": {
            "variants": len(candidates),
            "mapped": len(candidates) - len(missing_words),
            "missingWords": len(missing_words),
            "missingAudio": len(missing_audio),
            "duplicateSpellings": sum(item["duplicateSpelling"] for item in candidates),
            "automaticAudioFlags": sum(bool(item["candidateSpeechIssues"]) for item in candidates),
        },
    }


def render_review(data: dict) -> str:
    encoded_data = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    candidate_voice = html.escape(data["candidateVoice"])
    return REVIEW_TEMPLATE.replace("__REVIEW_DATA__", encoded_data).replace(
        "__CANDIDATE_VOICE__", candidate_voice
    )


REVIEW_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ThaiSheet vowel pronunciation-word review</title>
  <style>
    :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
    * { box-sizing: border-box; }
    body { margin: 0; background: Canvas; color: CanvasText; }
    header, main { width: min(1500px, 100%); margin: 0 auto; padding: 20px; }
    header { border-bottom: 1px solid color-mix(in srgb, CanvasText 16%, transparent); }
    h1 { margin: 0 0 6px; font-size: 24px; letter-spacing: 0; }
    p { margin: 4px 0; color: color-mix(in srgb, CanvasText 65%, transparent); }
    .notice { margin-top: 14px; padding: 10px 12px; border-left: 4px solid #0a84ff; background: color-mix(in srgb, #0a84ff 8%, Canvas); }
    .tools { position: sticky; top: 0; z-index: 2; display: flex; gap: 10px; align-items: end; flex-wrap: wrap; padding: 12px 0; background: Canvas; }
    label { display: grid; gap: 3px; font-size: 13px; font-weight: 600; }
    input, select, button { min-height: 40px; padding: 7px 10px; border: 1px solid #888; border-radius: 6px; background: Canvas; color: CanvasText; font: inherit; }
    #search { width: min(520px, 80vw); }
    button { cursor: pointer; font-weight: 600; }
    #summary { margin: 8px 0 12px; font-size: 13px; }
    .table-wrap { overflow-x: auto; border-top: 1px solid color-mix(in srgb, CanvasText 16%, transparent); }
    table { width: 100%; min-width: 1320px; border-collapse: collapse; }
    th, td { padding: 12px; border-bottom: 1px solid color-mix(in srgb, CanvasText 14%, transparent); text-align: left; vertical-align: middle; }
    thead th { color: color-mix(in srgb, CanvasText 62%, transparent); font-size: 12px; text-transform: uppercase; }
    tbody th { width: 14%; font-weight: 400; }
    .thai { display: block; font-size: 23px; letter-spacing: 0; }
    small, code { display: block; margin-top: 3px; color: color-mix(in srgb, CanvasText 62%, transparent); }
    audio { display: block; width: 245px; }
    .missing { color: #c7392f; font-weight: 700; }
    .duplicate { color: #a05a00; }
    .review-cell { min-width: 220px; }
    .review-cell select, .review-cell input { width: 100%; }
    .review-cell input { margin-top: 6px; }
    @media (max-width: 600px) {
      header, main { padding: 16px; }
      #search { width: calc(100vw - 32px); }
    }
  </style>
</head>
<body>
  <header>
    <h1>Vowel pronunciation-word review</h1>
    <p>Bundled vowel-word audio compared with real-word audio from __CANDIDATE_VOICE__.</p>
    <div class="notice">
      The proposed word is taken from the existing per-form sample data. A missing word is intentional:
      that form needs a defensible real example before it receives audio. When the pronunciation word and
      current sample are the same, the app should avoid duplicating the card until a useful second example is
      curated. Nothing on this page changes the app.
    </div>
  </header>
  <main>
    <div class="tools">
      <label>Search
        <input id="search" type="search" placeholder="Form, word, romanization, meaning, or sound">
      </label>
      <label>Show
        <select id="filter">
          <option value="all">All variants</option>
          <option value="pending">Pending review</option>
          <option value="missing">Missing word or audio</option>
          <option value="duplicate">Duplicate spellings</option>
          <option value="automatic">Automatic audio flags</option>
          <option value="attention">Needs attention</option>
        </select>
      </label>
      <button id="export" type="button">Export review</button>
    </div>
    <p id="summary" aria-live="polite"></p>
    <div class="table-wrap">
      <table>
        <thead>
          <tr><th>Table form</th><th>Proposed pronunciation word</th><th>Bundled word</th><th>Kore word</th><th>Review</th></tr>
        </thead>
        <tbody id="rows"></tbody>
      </table>
    </div>
  </main>
  <script>
    const review = __REVIEW_DATA__;
    const storageKey = "thaisheet-vowel-pronunciation-review-v1";
    const saved = JSON.parse(localStorage.getItem(storageKey) || "{}");
    const search = document.querySelector("#search");
    const filter = document.querySelector("#filter");
    const rows = document.querySelector("#rows");
    const summary = document.querySelector("#summary");

    function text(parent, tag, value, className) {
      if (!value) return;
      const element = document.createElement(tag);
      element.textContent = value;
      if (className) element.className = className;
      parent.append(element);
    }

    function player(src, label) {
      if (!src) {
        const missing = document.createElement("span");
        missing.className = "missing";
        missing.textContent = "Not available";
        return missing;
      }
      const audio = document.createElement("audio");
      audio.controls = true;
      audio.preload = "none";
      audio.src = src;
      audio.setAttribute("aria-label", label);
      audio.addEventListener("play", () => document.querySelectorAll("audio").forEach(other => {
        if (other !== audio) other.pause();
      }));
      return audio;
    }

    function persist(id, status, note) {
      saved[id] = {status, note};
      localStorage.setItem(storageKey, JSON.stringify(saved));
      render();
    }

    function row(item) {
      const tr = document.createElement("tr");
      const form = document.createElement("th");
      text(form, "strong", item.form, "thai");
      text(form, "small", `${item.duration}, ${item.ending} · ${item.sound}`);
      if (item.duplicateSpelling) text(form, "small", "Same spelling appears in another variant", "duplicate");
      if (item.note) text(form, "small", item.note);

      const word = document.createElement("td");
      if (item.word) {
        text(word, "strong", item.word, "thai");
        text(word, "small", item.romanization);
        text(word, "small", [item.meaningEn, item.meaningFr].filter(Boolean).join(" · "));
      } else {
        text(word, "span", "No real-word candidate", "missing");
      }

      const current = document.createElement("td");
      current.append(player(item.currentAudio, `Play bundled pronunciation word for ${item.form}`));
      const candidate = document.createElement("td");
      candidate.append(player(item.candidateAudio, `Play ${item.word || item.form} with ${review.candidateVoice}`));
      if (item.candidateDuration) text(candidate, "small", `${item.candidateDuration.toFixed(3)} seconds`);
      item.candidateSpeechIssues.forEach(issue => text(candidate, "small", issue, "missing"));

      const state = saved[item.id] || {status: "pending", note: ""};
      const decision = document.createElement("td");
      decision.className = "review-cell";
      const select = document.createElement("select");
      [["pending", "Pending"], ["accept", "Accept"], ["replace", "Replace word"], ["audio", "Audio issue"]].forEach(([value, label]) => {
        const option = document.createElement("option");
        option.value = value;
        option.textContent = label;
        option.selected = state.status === value;
        select.append(option);
      });
      const note = document.createElement("input");
      note.type = "text";
      note.placeholder = "Review note";
      note.value = state.note;
      select.addEventListener("change", () => persist(item.id, select.value, note.value));
      note.addEventListener("change", () => persist(item.id, select.value, note.value));
      decision.append(select, note);
      tr.append(form, word, current, candidate, decision);
      return tr;
    }

    function matchesFilter(item) {
      const state = saved[item.id]?.status || "pending";
      switch (filter.value) {
      case "pending": return state === "pending";
      case "missing": return !item.word || !item.candidateAudio;
      case "duplicate": return item.duplicateSpelling;
      case "automatic": return item.candidateSpeechIssues.length > 0;
      case "attention": return state === "replace" || state === "audio" || item.candidateSpeechIssues.length > 0;
      default: return true;
      }
    }

    function render() {
      const query = search.value.trim().toLocaleLowerCase();
      const filtered = review.items.filter(item => {
        const fields = [item.form, item.sound, item.duration, item.ending, item.word,
          item.romanization, item.meaningEn, item.meaningFr, item.note].join(" ").toLocaleLowerCase();
        return matchesFilter(item) && (!query || fields.includes(query));
      });
      rows.replaceChildren(...filtered.map(row));
      const reviewed = review.items.filter(item => (saved[item.id]?.status || "pending") !== "pending").length;
      summary.textContent = `${filtered.length} shown · ${reviewed}/${review.counts.variants} reviewed · ` +
        `${review.counts.missingWords} missing words · ${review.counts.missingAudio} missing candidate recordings · ` +
        `${review.counts.automaticAudioFlags} automatic audio flags`;
    }

    document.querySelector("#export").addEventListener("click", () => {
      const payload = {candidateVoice: review.candidateVoice, exportedAt: new Date().toISOString(), decisions: saved};
      const link = document.createElement("a");
      link.href = URL.createObjectURL(new Blob([JSON.stringify(payload, null, 2) + "\\n"], {type: "application/json"}));
      link.download = "vowel-pronunciation-review.json";
      link.click();
      URL.revokeObjectURL(link.href);
    });
    search.addEventListener("input", render);
    filter.addEventListener("change", render);
    render();
  </script>
</body>
</html>
"""


def validated_scratchpad_path(raw_path: str, *, is_file: bool) -> Path:
    path = Path(raw_path).expanduser()
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    path = path.resolve()
    container = path.parent if is_file else path
    scratchpad = SCRATCHPAD_DIR.resolve()
    if container == scratchpad or scratchpad not in container.parents:
        raise SystemExit(f"Path must be beneath {scratchpad}")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build a real-word vowel pronunciation review page"
    )
    parser.add_argument("--candidate-dir", default=str(DEFAULT_CANDIDATE_DIR))
    parser.add_argument("--candidate-voice", default=DEFAULT_CANDIDATE_VOICE)
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    args = parser.parse_args()

    candidate_dir = validated_scratchpad_path(args.candidate_dir, is_file=False)
    output = validated_scratchpad_path(args.output, is_file=True)
    if not candidate_dir.exists():
        raise SystemExit(f"Candidate directory not found: {candidate_dir}")

    data = build_review_data(candidate_dir, output, args.candidate_voice)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_review(data), encoding="utf-8")
    print(f"Wrote {output}")
    print(
        f"Variants: {data['counts']['variants']}; mapped: {data['counts']['mapped']}; "
        f"missing words: {data['counts']['missingWords']}; "
        f"missing audio: {data['counts']['missingAudio']}; "
        f"automatic audio flags: {data['counts']['automaticAudioFlags']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
