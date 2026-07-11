#!/usr/bin/env python3
"""Build a local side-by-side review page for a complete candidate sound set."""

import argparse
import json
import os
from pathlib import Path
from urllib.parse import quote

from generate_sounds import inspect_audio
from sound_inventory import SOUND_TYPE_LABELS, load_sound_inventory


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
CHEATSHEET_DIR = PROJECT_ROOT / "ThaiSheet" / "Resources" / "cheatsheet"
CURRENT_DIR = PROJECT_ROOT / "ThaiSheet" / "Resources" / "sounds"
SCRATCHPAD_DIR = PROJECT_ROOT / "scratchpad"
RECORDED_AUDIO_METADATA = SCRIPT_DIR / "recorded_audio_metadata.json"


def validate_complete_set(audio_dir: Path, expected_files: set[str], label: str) -> None:
    existing_files = {path.name for path in audio_dir.glob("*.mp3")}
    missing = sorted(expected_files - existing_files)
    stale = sorted(existing_files - expected_files)
    if missing or stale:
        lines = [f"{label} does not match the canonical sound inventory."]
        if missing:
            lines.append(f"Missing ({len(missing)}): {', '.join(missing)}")
        if stale:
            lines.append(f"Stale ({len(stale)}): {', '.join(stale)}")
        raise SystemExit("\n".join(lines))


def relative_audio_url(page: Path, audio_file: Path) -> str:
    relative = os.path.relpath(audio_file, page.parent)
    return quote(relative, safe="/.-_")


def current_voice_label() -> str:
    metadata = json.loads(RECORDED_AUDIO_METADATA.read_text())
    return metadata["voice"]


def build_review_data(candidate_dir: Path, output: Path, candidate_voice: str) -> dict:
    inventory = load_sound_inventory(CHEATSHEET_DIR)
    expected_files = {item.filename for item in inventory}
    validate_complete_set(CURRENT_DIR, expected_files, "Current sound set")
    validate_complete_set(candidate_dir, expected_files, "Candidate sound set")

    items = []
    failed_quality = []
    for item in inventory:
        candidate_file = candidate_dir / item.filename
        quality = inspect_audio(candidate_file)
        issues = quality.issues(0.35, -24.0)
        item_data = item.catalog_dict()
        item_data.update({
            "currentAudio": relative_audio_url(output, CURRENT_DIR / item.filename),
            "candidateAudio": relative_audio_url(output, candidate_file),
            "duration": round(quality.duration_seconds, 3),
            "peakDb": quality.max_volume_db,
            "qualityIssues": issues,
        })
        items.append(item_data)
        if issues:
            failed_quality.append({"id": item.id, "filename": item.filename, "issues": issues})

    return {
        "candidateVoice": candidate_voice,
        "currentVoice": current_voice_label(),
        "counts": {
            sound_type: sum(item.sound_type == sound_type for item in inventory)
            for sound_type in SOUND_TYPE_LABELS
        },
        "typeLabels": SOUND_TYPE_LABELS,
        "failedQuality": failed_quality,
        "items": items,
    }


def render_review(data: dict) -> str:
    encoded_data = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ThaiSheet recorded-voice review</title>
  <style>
    :root {{ color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }}
    * {{ box-sizing: border-box; }}
    body {{ margin: 0; background: Canvas; color: CanvasText; }}
    header, main {{ width: min(1440px, 100%); margin: 0 auto; padding: 20px; }}
    header {{ border-bottom: 1px solid color-mix(in srgb, CanvasText 16%, transparent); }}
    h1 {{ margin: 0 0 6px; font-size: 24px; letter-spacing: 0; }}
    p {{ margin: 0; color: color-mix(in srgb, CanvasText 65%, transparent); }}
    .tools {{ position: sticky; top: 0; z-index: 2; padding: 12px 0; background: Canvas; }}
    input {{ width: min(560px, 100%); min-height: 42px; padding: 8px 10px; border: 1px solid #888; border-radius: 6px; background: Canvas; color: CanvasText; font: inherit; }}
    .tabs {{ display: flex; margin-top: 10px; overflow-x: auto; border: 1px solid #888; border-radius: 6px; }}
    .tabs button {{ flex: 1 0 auto; min-height: 38px; padding: 6px 10px; border: 0; border-right: 1px solid #888; background: Canvas; color: CanvasText; font: inherit; cursor: pointer; }}
    .tabs button:last-child {{ border-right: 0; }}
    .tabs button[aria-selected="true"] {{ background: CanvasText; color: Canvas; }}
    #summary {{ margin: 9px 0; font-size: 13px; }}
    .table-wrap {{ overflow-x: auto; border-top: 1px solid color-mix(in srgb, CanvasText 16%, transparent); }}
    table {{ width: 100%; min-width: 1130px; border-collapse: collapse; }}
    th, td {{ padding: 12px; border-bottom: 1px solid color-mix(in srgb, CanvasText 14%, transparent); text-align: left; vertical-align: middle; }}
    thead th {{ color: color-mix(in srgb, CanvasText 62%, transparent); font-size: 12px; text-transform: uppercase; }}
    tbody th {{ width: 20%; font-weight: 400; }}
    strong, .thai {{ display: block; font-size: 21px; letter-spacing: 0; }}
    code, small {{ display: block; margin-top: 4px; color: color-mix(in srgb, CanvasText 62%, transparent); }}
    audio {{ display: block; width: 260px; }}
    .quality-pass {{ color: #16833b; font-weight: 700; }}
    .quality-fail {{ color: #d83b32; font-weight: 700; }}
  </style>
</head>
<body>
  <header>
    <h1>ThaiSheet recorded-voice review</h1>
    <p>{data['currentVoice']} compared with {data['candidateVoice']}</p>
  </header>
  <main>
    <div class="tools">
      <input id="search" type="search" aria-label="Search" placeholder="Thai, romanization, meaning, or sound ID">
      <div id="tabs" class="tabs" role="tablist" aria-label="Sound type"></div>
    </div>
    <p id="summary"></p>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Entry</th><th>Synthesis</th><th>Current</th><th>Candidate</th><th>Quality</th></tr></thead>
        <tbody id="rows"></tbody>
      </table>
    </div>
  </main>
  <script>
    const review = {encoded_data};
    const typeOrder = ["consonant", "vowel", "cluster", "tone_mark", "tone_rule", "sample_word"];
    const search = document.querySelector("#search");
    const tabs = document.querySelector("#tabs");
    const rows = document.querySelector("#rows");
    const summary = document.querySelector("#summary");
    let selectedType = "consonant";

    function tab(type, label, count) {{
      const button = document.createElement("button");
      button.type = "button";
      button.role = "tab";
      button.dataset.type = type;
      button.textContent = `${{label}} (${{count}})`;
      button.setAttribute("aria-selected", type === selectedType ? "true" : "false");
      button.addEventListener("click", () => {{
        selectedType = type;
        tabs.querySelectorAll("button").forEach(item => item.setAttribute("aria-selected", item.dataset.type === type ? "true" : "false"));
        render();
      }});
      tabs.append(button);
    }}
    tab("all", "All", review.items.length);
    typeOrder.forEach(type => tab(type, review.typeLabels[type], review.counts[type]));

    function addText(parent, element, value, className) {{
      if (!value) return;
      const child = document.createElement(element);
      child.textContent = value;
      if (className) child.className = className;
      parent.append(child);
    }}

    function audio(src, label) {{
      const player = document.createElement("audio");
      player.controls = true;
      player.preload = "none";
      player.src = src;
      player.setAttribute("aria-label", label);
      player.addEventListener("play", () => document.querySelectorAll("audio").forEach(other => {{ if (other !== player) other.pause(); }}));
      return player;
    }}

    function row(item) {{
      const tr = document.createElement("tr");
      const entry = document.createElement("th");
      addText(entry, "strong", item.display);
      addText(entry, "small", item.romanization);
      addText(entry, "code", item.id);
      const synthesis = document.createElement("td");
      addText(synthesis, "span", item.synthesis_text, "thai");
      addText(synthesis, "small", item.description);
      const current = document.createElement("td");
      current.append(audio(item.currentAudio, `Play current ${{item.display}}`));
      const candidate = document.createElement("td");
      candidate.append(audio(item.candidateAudio, `Play candidate ${{item.display}}`));
      const quality = document.createElement("td");
      const passed = item.qualityIssues.length === 0;
      addText(quality, "span", passed ? "Pass" : "Flag", passed ? "quality-pass" : "quality-fail");
      addText(quality, "small", `${{item.duration.toFixed(3)}}s · ${{item.peakDb.toFixed(1)}} dBFS`);
      if (!passed) addText(quality, "small", item.qualityIssues.join("; "));
      tr.append(entry, synthesis, current, candidate, quality);
      return tr;
    }}

    function render() {{
      const query = search.value.trim().toLocaleLowerCase();
      const filtered = review.items.filter(item => {{
        const fields = [item.id, item.display, item.synthesis_text, item.romanization, item.meaning_en, item.meaning_fr, item.example_word, item.example_romanization].join(" ").toLocaleLowerCase();
        return (selectedType === "all" || item.sound_type === selectedType) && (!query || fields.includes(query));
      }});
      rows.replaceChildren(...filtered.map(row));
      summary.textContent = `${{filtered.length}} of ${{review.items.length}} recordings · ${{review.failedQuality.length}} quality flags`;
    }}
    search.addEventListener("input", render);
    render();
  </script>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a local current-versus-candidate review page")
    parser.add_argument("--candidate-dir", required=True)
    parser.add_argument("--candidate-voice", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()

    candidate_dir = Path(args.candidate_dir).expanduser()
    if not candidate_dir.is_absolute():
        candidate_dir = PROJECT_ROOT / candidate_dir
    candidate_dir = candidate_dir.resolve()
    scratchpad = SCRATCHPAD_DIR.resolve()
    if candidate_dir == scratchpad or scratchpad not in candidate_dir.parents:
        parser.error(f"--candidate-dir must be beneath {scratchpad}")

    output = Path(args.output).expanduser() if args.output else candidate_dir / "review.html"
    if not output.is_absolute():
        output = PROJECT_ROOT / output
    output = output.resolve()
    if output == scratchpad or scratchpad not in output.parents:
        parser.error(f"--output must be beneath {scratchpad}")

    data = build_review_data(candidate_dir, output, args.candidate_voice)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_review(data), encoding="utf-8")
    report_path = output.with_name("quality-report.json")
    report = {
        "candidateVoice": data["candidateVoice"],
        "totalFiles": len(data["items"]),
        "qualityFlagCount": len(data["failedQuality"]),
        "items": [
            {
                "id": item["id"],
                "filename": item["filename"],
                "duration": item["duration"],
                "peakDb": item["peakDb"],
                "qualityIssues": item["qualityIssues"],
            }
            for item in data["items"]
        ],
    }
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {output}")
    print(f"Quality flags: {len(data['failedQuality'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
