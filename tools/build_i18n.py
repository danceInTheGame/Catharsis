#!/usr/bin/env python3
"""Construit hskhelp/assets/vocab.json à partir de _raw_vocab.json.

Pour chaque entrée :
  * `level`  1..7 (7 = bandeau 7-9) et `id` unique ;
  * `posEn` / `posFr` : nature grammaticale normalisée, en anglais et en
    français. Le niveau 7-9 n'en a pas (voir plus bas) ;
  * `en` : traduction anglaise fournie par le PDF (niveaux 1-6) ;
  * `fr` : traduction française, générée via Google Translate puis mise en
    cache dans tools/translate_cache.json — l'application reste hors ligne,
    seuls ces fichiers d'assets sont embarqués ;
  * `plain` / `answers` : graphies atones déjà normalisées.

Niveau 7-9 : le PDF ne contient ni traduction ni nature grammaticale
exploitable ; d'après le choix de l'utilisateur, la zone « signification »
y affiche le pinyin, donc `en`, `fr`, `posEn` et `posFr` restent vides.
"""
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "hskhelp" / "assets" / "_raw_vocab.json"
DEST = ROOT / "hskhelp" / "assets" / "vocab.json"
CACHE = Path(__file__).resolve().parent / "translate_cache.json"
BATCH = 40
LEVEL_LAST = 7  # au-delà : pas de traduction

# Nature grammaticale : atome canonique -> (anglais, français).
POS_ATOMS = {
    # Sources anglaises (niveaux 1-5)
    "adjective": ("adjective", "adjectif"),
    "adverb": ("adverb", "adverbe"),
    "auxiliary": ("auxiliary", "auxiliaire"),
    "classifier": ("classifier", "classificateur"),
    "conjunction": ("conjunction", "conjonction"),
    "interjection": ("interjection", "interjection"),
    "noun": ("noun", "nom"),
    "number": ("numeral", "numéral"),
    "numberclassifier": ("numeral, classifier", "numéral, classificateur"),
    "prefix": ("prefix", "préfixe"),
    "preposition": ("preposition", "préposition"),
    "pronoun": ("pronoun", "pronom"),
    "suffix": ("suffix", "suffixe"),
    "verb": ("verb", "verbe"),
    "onomatopoeia": ("onomatopoeia", "onomatopée"),
    # Sources chinoises (niveaux 6-9)
    "名": ("noun", "nom"),
    "动": ("verb", "verbe"),
    "形": ("adjective", "adjectif"),
    "副": ("adverb", "adverbe"),
    "量": ("classifier", "classificateur"),
    "连": ("conjunction", "conjonction"),
    "介": ("preposition", "préposition"),
    "代": ("pronoun", "pronom"),
    "助": ("particle", "particule"),
    "数量": ("numeral, classifier", "numéral, classificateur"),
    "后缀": ("suffix", "suffixe"),
    "数": ("numeral", "numéral"),
    "叹": ("interjection", "interjection"),
    "前缀": ("prefix", "préfixe"),
    "拟声": ("onomatopoeia", "onomatopée"),
}


def canon_atom(atom: str) -> str:
    """Ramène un atome de nature grammaticale à sa forme canonique."""
    a = atom.strip().strip("（）()").strip()
    a = re.sub(r"\s+", "", a).lower()
    if a in ("number-classifier", "numberclassifier"):
        return "numberclassifier"
    return a


def split_pos(raw: str) -> list:
    if not raw:
        return []
    return [t for t in (canon_atom(x) for x in re.split(r"[、,]", raw)) if t]


def build_pos(raw: str, level: int):
    if level >= LEVEL_LAST:
        return "", ""
    atoms = split_pos(raw)
    unknown = [a for a in atoms if a not in POS_ATOMS]
    if unknown:
        sys.exit(f"nature grammaticale inconnue : {unknown} (dans {raw!r})")
    return (
        ", ".join(POS_ATOMS[a][0] for a in atoms),
        ", ".join(POS_ATOMS[a][1] for a in atoms),
    )


# ---------------------------------------------------------------- traductions

def translate_batch(texts: list) -> list:
    """Traduit une liste de chaînes en français (EN -> FR), lot par lot."""
    out = []
    for i in range(0, len(texts), BATCH):
        chunk = texts[i:i + BATCH]
        out.extend(_translate_chunk(chunk))
        time.sleep(0.12)
    return out


def _translate_chunk(chunk: list) -> list:
    query = urllib.parse.urlencode({
        "client": "gtx", "sl": "en", "tl": "fr", "dt": "t",
        "q": "\n".join(chunk),
    })
    url = "https://translate.googleapis.com/translate_a/single?" + query
    last_error = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=40) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            joined = "".join(
                seg[0] for seg in data[0] if seg and isinstance(seg[0], str)
            )
            lines = joined.split("\n")
            while len(lines) > len(chunk) and lines[-1] == "":
                lines.pop()
            if len(lines) == len(chunk):
                return lines
            last_error = f"{len(lines)} lignes pour {len(chunk)}"
        except (urllib.error.URLError, OSError, ValueError, IndexError) as exc:
            last_error = str(exc)
        time.sleep(1.5 * (attempt + 1))
    # Le lot ne se segmente pas proprement : on retente entrée par entrée.
    print(f"  lot difficile ({last_error}), requêtes unitaires", file=sys.stderr)
    return [_translate_one(text) for text in chunk]


def _translate_one(text: str) -> str:
    query = urllib.parse.urlencode({
        "client": "gtx", "sl": "en", "tl": "fr", "dt": "t", "q": text,
    })
    url = "https://translate.googleapis.com/translate_a/single?" + query
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=40) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            return "".join(
                seg[0] for seg in data[0] if seg and isinstance(seg[0], str)
            )
        except (urllib.error.URLError, OSError, ValueError, IndexError) as exc:
            print(f"  échec ({exc})", file=sys.stderr)
            time.sleep(1.5 * (attempt + 1))
    sys.exit(f"traduction impossible pour {text!r}")


def load_cache() -> dict:
    if CACHE.exists():
        return json.loads(CACHE.read_text(encoding="utf-8"))
    return {}


def save_cache(cache: dict) -> None:
    CACHE.write_text(
        json.dumps(cache, ensure_ascii=False, indent=1, sort_keys=True),
        encoding="utf-8",
    )


# ---------------------------------------------------------------------- main

def main():
    entries = json.loads(RAW.read_text(encoding="utf-8"))

    # Corrections de l'extraction PDF : « verb » est parfois rendu par 动
    # (3 occurrences), et une nature grammaticale anglaise par 拟声.
    for e in entries:
        if e["level"] < LEVEL_LAST:
            e["meaning"] = e["meaning"].replace("动", "verb")

    cache = load_cache()
    wanted = [
        e["meaning"] for e in entries
        if e["level"] < LEVEL_LAST and e["meaning"] not in cache
    ]
    wanted = list(dict.fromkeys(wanted))  # ordre, sans doublons
    if wanted:
        print(f"traduction de {len(wanted)} significations…", file=sys.stderr)
        for i in range(0, len(wanted), 400):
            part = wanted[i:i + 400]
            for src, dst in zip(part, translate_batch(part)):
                cache[src] = dst
            save_cache(cache)
            print(f"  {min(i + 400, len(wanted))}/{len(wanted)}", file=sys.stderr)

    out = []
    missing = []
    for e in entries:
        pos_en, pos_fr = build_pos(e["pos"], e["level"])
        if e["level"] >= LEVEL_LAST:
            en = fr = ""
        else:
            en = e["meaning"]
            fr = cache.get(en, "")
            if not fr:
                missing.append(en)
        out.append({
            "id": e["id"],
            "level": e["level"],
            "hanzi": e["hanzi"],
            "pinyin": e["pinyin"],
            "posEn": pos_en,
            "posFr": pos_fr,
            "en": en,
            "fr": fr,
            "plain": e["plain"],
            "answers": e["answers"],
        })

    if missing:
        sys.exit(f"{len(missing)} significations sans traduction : {missing[:5]}")

    DEST.write_text(
        json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    size = DEST.stat().st_size / 1024
    print(f"{len(out)} entrées -> {DEST} ({size:.0f} Ko)", file=sys.stderr)


if __name__ == "__main__":
    main()
