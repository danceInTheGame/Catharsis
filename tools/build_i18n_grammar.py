#!/usr/bin/env python3
"""Traduit en anglais et en chinois le contenu de grammaire extrait.

Le contenu source n'existe qu'en français. L'application propose trois langues
(français, anglais, chinois) : les titres, les explications, les structures et
les traductions d'exemples sont donc traduits ici, **hors ligne**, avec les
modèles Argos (fr→en puis en→zh).

Les passages en caractères chinois sont préservés tels quels
(``translate_mixed``) : on traduit le texte français qui les entoure, jamais
les exemples hanzi.

Le travail est mis en cache dans ``tools/_grammar_cache.json`` et reprend
là où il s'est arrêté : relancer la commande ne retraduit que le manquant.

    python3 tools/build_i18n_grammar.py            # en puis zh
    python3 tools/build_i18n_grammar.py --only=en  # anglais seulement
"""
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_i18n_local import LocalMT  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
RULES = ROOT / "hskhelp" / "assets" / "grammar_rules.json"
CACHE = ROOT / "tools" / "_grammar_cache.json"


def log(*a):
    print(*a, file=sys.stderr, flush=True)


NAV_MARKERS = (
    "Sommaire",
    "Summary",
    "Table of contents",
    "Articles connexes",
    "Related articles",
    "Infos supplémentaires",
    "Additional information",
)


def strip_nav_tail(text):
    """Retire les libellés de navigation collés en fin de paragraphe."""
    for marker in NAV_MARKERS:
        index = text.find(marker)
        if index != -1 and len(text) - index <= 140:
            return text[:index].strip()
    return text


def clean_blocks(data):
    """Retire les libellés de navigation collés aux paragraphes."""
    for rule in data["rules"]:
        for block in rule["blocks"]:
            if block["t"] == "p":
                block["fr"] = strip_nav_tail(block.get("fr", ""))


def collect(data):
    """Tous les textes français à traduire, par nature."""
    texts = {"title": set(), "p": set(), "h2": set(), "h3": set(),
             "structure": set(), "example": set(), "category": set()}
    for level in data.get("levels", []):
        for section in level.get("sections", []):
            for category in section.get("categories", []):
                if category.get("name"):
                    texts["category"].add(category["name"])
    for rule in data["rules"]:
        if rule.get("title"):
            texts["title"].add(rule["title"])
        for block in rule["blocks"]:
            if block["t"] == "examples":
                for item in block["items"]:
                    if item.get("fr"):
                        texts["example"].add(item["fr"])
            elif block.get("fr"):
                texts[block["t"]].add(block["fr"])
    return {k: sorted(v) for k, v in texts.items()}


def load_cache():
    if CACHE.exists():
        try:
            return json.loads(CACHE.read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001
            pass
    return {"en": {}, "zh": {}}


def save_cache(cache):
    tmp = CACHE.with_suffix(".tmp")
    tmp.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    tmp.replace(CACHE)


def translate_set(mt, cache, lang, texts, max_len=256):
    """Traduit les textes absents du cache ; renvoie le nombre ajouté.

    Pour le chinois, on part de l'anglais déjà traduit (cache ``en``) : le
    pivot fr→en n'est ainsi calculé qu'une fois.
    """
    table = cache.setdefault(lang, {})
    pending = [t for t in texts if t and t not in table]
    if not pending:
        return 0
    total = sum(len(t) for t in pending)
    log(f"  {lang} : {len(pending)} textes à traduire ({total} car.)")
    done_chars = 0
    t0 = time.time()
    step = 250
    src_lang = "fr"
    for i in range(0, len(pending), step):
        chunk = pending[i:i + step]
        if lang == "zh":
            chunk = [cache.get("en", {}).get(t, t) for t in chunk]
            src_lang = "en"
        out = mt.translate_mixed(chunk, src_lang, lang, max_len=max_len)
        keys = pending[i:i + step]
        for src, dst in zip(keys, out):
            table[src] = dst
        done_chars += sum(len(t) for t in keys)
        save_cache(cache)
        elapsed = time.time() - t0
        rate = done_chars / elapsed if elapsed else 0
        eta = (total - done_chars) / rate if rate else 0
        log(f"    {done_chars}/{total} car. — {rate:.0f} car/s — "
            f"reste ~{eta / 60:.0f} min")
    return len(pending)


def apply(data, cache):
    """Recopie les traductions dans le JSON des règles."""
    filled = 0

    def tr(text):
        nonlocal filled
        out = {}
        for lang in ("en", "zh"):
            value = cache.get(lang, {}).get(text)
            if value:
                out[lang] = value
                filled += 1
        return out

    for level in data.get("levels", []):
        for section in level.get("sections", []):
            for category in section.get("categories", []):
                if category.get("name"):
                    category["nameI18n"] = tr(category["name"])

    for rule in data["rules"]:
        if rule.get("title"):
            rule["titleI18n"] = tr(rule["title"])
        for block in rule["blocks"]:
            if block["t"] == "examples":
                for item in block["items"]:
                    if item.get("fr"):
                        item["frI18n"] = tr(item["fr"])
            elif block.get("fr"):
                block["i18n"] = tr(block["fr"])
    return filled


def main():
    argv = sys.argv[1:]
    only = None
    for a in argv:
        if a.startswith("--only="):
            only = [x for x in a.split("=", 1)[1].split(",") if x]
    langs = only or ["en", "zh"]

    data = json.loads(RULES.read_text(encoding="utf-8"))
    clean_blocks(data)
    texts = collect(data)
    log("textes à traduire : " + ", ".join(f"{k}={len(v)}" for k, v in texts.items()))
    cache = load_cache()

    mt = LocalMT(threads=2)
    t0 = time.time()
    for lang in langs:
        for kind, values in texts.items():
            # Les titres et libellés courts sont bornés court ; les
            # explications ont besoin de plus de place.
            max_len = 256
            translate_set(mt, cache, lang, values, max_len=max_len)
        log(f"  {lang} terminé en {(time.time() - t0) / 60:.0f} min")
        mt.clear()

    filled = apply(data, cache)
    RULES.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    log(f"{filled} traductions appliquées → {RULES}")


if __name__ == "__main__":
    main()
