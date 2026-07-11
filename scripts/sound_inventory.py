#!/usr/bin/env python3
"""Canonical inventory of every bundled ThaiSheet sound."""

from dataclasses import asdict, dataclass
import json
from pathlib import Path


SOUND_TYPE_ORDER = (
    "tone_mark",
    "tone_rule",
    "consonant",
    "vowel",
    "cluster",
    "sample_word",
)
SOUND_TYPE_LABELS = {
    "tone_mark": "Tone marks",
    "tone_rule": "Tone rules",
    "consonant": "Consonants",
    "vowel": "Vowels",
    "cluster": "Clusters",
    "sample_word": "Sample words",
}


@dataclass(frozen=True)
class SoundItem:
    """One generated MP3 and the teaching metadata used to review it."""

    id: str
    sound_type: str
    key: str
    display: str
    synthesis_text: str
    filename: str
    description: str = ""
    romanization: str = ""
    meaning_en: str = ""
    meaning_fr: str = ""
    example_word: str = ""
    example_romanization: str = ""
    example_meaning_en: str = ""
    example_meaning_fr: str = ""
    sources: tuple[str, ...] = ()

    def catalog_dict(self) -> dict:
        data = asdict(self)
        data["sources"] = list(self.sources)
        return data


def load_sound_inventory(cheatsheet_dir: Path) -> list[SoundItem]:
    """Build the complete inventory in the same order as sound generation."""
    items = [
        *_tone_mark_items(cheatsheet_dir),
        *_tone_rule_items(cheatsheet_dir),
        *_consonant_items(cheatsheet_dir),
        *_vowel_items(cheatsheet_dir),
        *_cluster_items(cheatsheet_dir),
        *_sample_word_items(cheatsheet_dir),
    ]
    _validate_inventory(items)
    return items


def inventory_by_type(items: list[SoundItem]) -> dict[str, list[SoundItem]]:
    grouped = {sound_type: [] for sound_type in SOUND_TYPE_ORDER}
    for item in items:
        grouped[item.sound_type].append(item)
    return grouped


def _load(cheatsheet_dir: Path, filename: str) -> dict:
    with (cheatsheet_dir / filename).open(encoding="utf-8") as data_file:
        return json.load(data_file)


def _sample_fields(sample: dict | None) -> dict[str, str]:
    if not sample:
        return {
            "word": "",
            "romanization": "",
            "meaning_en": "",
            "meaning_fr": "",
        }
    meaning = sample.get("meaning") or {}
    return {
        "word": sample.get("word", ""),
        "romanization": sample.get("romanization", ""),
        "meaning_en": meaning.get("en", ""),
        "meaning_fr": meaning.get("fr", ""),
    }


def _tone_mark_items(cheatsheet_dir: Path) -> list[SoundItem]:
    data = _load(cheatsheet_dir, "tone-marks.json")
    classes = (
        ("onLow", "low", "ค", "low class"),
        ("onMid", "mid", "ก", "mid class"),
        ("onHigh", "high", "ข", "high class"),
    )
    items = []
    for tone_mark in data["toneMarks"]:
        mark = tone_mark["mark"]
        for tone_key, sample_key, consonant, class_label in classes:
            tone = tone_mark.get(tone_key)
            if not tone:
                continue
            display = consonant + mark + "า"
            sample = _sample_fields((tone_mark.get("samples") or {}).get(sample_key))
            items.append(SoundItem(
                id=f"tone-mark:{display}",
                sound_type="tone_mark",
                key=display,
                display=display,
                synthesis_text=display,
                filename=f"cheat_sheet_tone_mark_{display}.mp3",
                description=f"{tone} tone ({class_label})",
                example_word=sample["word"],
                example_romanization=sample["romanization"],
                example_meaning_en=sample["meaning_en"],
                example_meaning_fr=sample["meaning_fr"],
            ))
    return items


def _tone_rule_items(cheatsheet_dir: Path) -> list[SoundItem]:
    data = _load(cheatsheet_dir, "tone-rules.json")
    items = []
    seen = set()
    for rule in data["toneRules"]:
        for sample in rule.get("samples") or []:
            word = sample["full"]
            if word in seen:
                continue
            seen.add(word)
            items.append(SoundItem(
                id=f"tone-rule:{word}",
                sound_type="tone_rule",
                key=word,
                display=word,
                synthesis_text=word,
                filename=f"cheat_sheet_tone_rule_{word}.mp3",
                description=f"{rule['tone']} tone",
            ))
    return items


def _consonant_items(cheatsheet_dir: Path) -> list[SoundItem]:
    data = _load(cheatsheet_dir, "consonants.json")
    items = []
    for consonant in data["consonants"]:
        char = consonant["character"]
        name = consonant["name"]
        sample = _sample_fields(consonant.get("sample"))
        items.append(SoundItem(
            id=f"consonant:{char}",
            sound_type="consonant",
            key=char,
            display=f"{char} · {name}",
            synthesis_text=name,
            filename=f"cheat_sheet_consonant_{char}.mp3",
            description=f"{consonant['class']} class, {consonant['usage']}",
            romanization=consonant.get("transcription", ""),
            example_word=sample["word"],
            example_romanization=sample["romanization"],
            example_meaning_en=sample["meaning_en"],
            example_meaning_fr=sample["meaning_fr"],
        ))
    return items


def _vowel_items(cheatsheet_dir: Path) -> list[SoundItem]:
    data = _load(cheatsheet_dir, "vowels.json")
    items = []
    form_paths = (
        ("short", "closed", "short_closed"),
        ("short", "open", "short_open"),
        ("long", "closed", "long_closed"),
        ("long", "open", "long_open"),
    )
    for vowel in data["vowels"]:
        pronunciations = vowel.get("pronunciations") or vowel.get("samples") or {}
        for duration, ending, sample_key in form_paths:
            form = vowel[duration].get(ending)
            if not form:
                continue
            sample = _sample_fields(pronunciations.get(sample_key))
            word = sample["word"]
            if not word:
                continue
            items.append(SoundItem(
                id=f"vowel:{form}:{sample_key}",
                sound_type="vowel",
                key=word,
                display=form,
                synthesis_text=word,
                filename=f"cheat_sheet_vowel_{word}.mp3",
                description=f"{duration}, {ending}",
                romanization=vowel["sounds"]["en"],
                meaning_en=sample["meaning_en"],
                meaning_fr=sample["meaning_fr"],
                example_romanization=sample["romanization"],
            ))
    return items


def _cluster_items(cheatsheet_dir: Path) -> list[SoundItem]:
    data = _load(cheatsheet_dir, "clusters.json")
    items = []
    for cluster in data["clusters"]:
        cluster_text = cluster["cluster"]
        display = cluster_text if cluster_text.startswith("-") else cluster_text.strip("-") + "า"
        sample = _sample_fields(cluster.get("sample"))
        items.append(SoundItem(
            id=f"cluster:{cluster_text}",
            sound_type="cluster",
            key=display,
            display=cluster_text,
            synthesis_text=display,
            filename=f"cheat_sheet_cluster_{display}.mp3",
            description=cluster.get("type", ""),
            romanization=cluster.get("sound", ""),
            example_word=sample["word"],
            example_romanization=sample["romanization"],
            example_meaning_en=sample["meaning_en"],
            example_meaning_fr=sample["meaning_fr"],
        ))
    return items


def _sample_word_items(cheatsheet_dir: Path) -> list[SoundItem]:
    words: dict[str, dict] = {}

    def add(sample: dict | None, source: str) -> None:
        if not sample or not sample.get("word"):
            return
        word = sample["word"]
        entry = words.setdefault(word, {**_sample_fields(sample), "sources": set()})
        entry["sources"].add(source)
        if not entry["romanization"] and sample.get("romanization"):
            entry.update(_sample_fields(sample))

    consonants = _load(cheatsheet_dir, "consonants.json")["consonants"]
    for consonant in consonants:
        sample = consonant.get("sample")
        if sample is None:
            name_parts = consonant["name"].split(" ", 1)
            sample = {"word": name_parts[1]} if len(name_parts) == 2 else None
        add(sample, "consonant")

    vowels = _load(cheatsheet_dir, "vowels.json")["vowels"]
    for vowel in vowels:
        for sample in (vowel.get("samples") or {}).values():
            add(sample, "vowel")

    tone_marks = _load(cheatsheet_dir, "tone-marks.json")["toneMarks"]
    for tone_mark in tone_marks:
        for sample in (tone_mark.get("samples") or {}).values():
            add(sample, "tone mark")

    clusters = _load(cheatsheet_dir, "clusters.json")["clusters"]
    for cluster in clusters:
        add(cluster.get("sample"), "cluster")

    return [
        SoundItem(
            id=f"sample-word:{word}",
            sound_type="sample_word",
            key=word,
            display=word,
            synthesis_text=word,
            filename=f"cheat_sheet_sample_word_{word}.mp3",
            description=", ".join(sorted(entry["sources"])),
            romanization=entry["romanization"],
            meaning_en=entry["meaning_en"],
            meaning_fr=entry["meaning_fr"],
            sources=tuple(sorted(entry["sources"])),
        )
        for word, entry in sorted(words.items())
    ]


def _validate_inventory(items: list[SoundItem]) -> None:
    ids = [item.id for item in items]
    filenames = [item.filename for item in items]
    if len(ids) != len(set(ids)):
        raise ValueError("Sound inventory contains duplicate IDs")
    if len(filenames) != len(set(filenames)):
        raise ValueError("Sound inventory contains duplicate filenames")
    unknown_types = {item.sound_type for item in items} - set(SOUND_TYPE_ORDER)
    if unknown_types:
        raise ValueError(f"Sound inventory contains unknown types: {sorted(unknown_types)}")
