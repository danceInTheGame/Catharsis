#!/usr/bin/env python3
"""Parse les 7 PDF « New HSK Vocabulary » -> hskhelp/assets/_raw_vocab.json.

Niveaux 1 à 6 : colonnes NO. / WORD / PINYIN / PART OF SPEECH / TRANSLATION
Niveau 7-9    : colonnes NO. / WORD / PINYIN / PART OF SPEECH (sans traduction)

Chaque mot reçoit un `id` unique sur l'ensemble du lexique (la numérotation
des PDF repart à 1 dans chaque fichier) et un `level` (7 = bandeau 7-9).
Le nettoyage des accents et le calcul de `plain`/`answers` sont faits ici,
l'enrichissement i18n (traductions, natures grammaticales) est fait par
`build_i18n.py`.
"""
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NS = "{http://www.w3.org/1999/xhtml}"
TOL = 7.0  # tolérance de regroupement vertical (points)
HEADER_Y = (85.0, 130.0)  # plage verticale des en-têtes de colonnes
FOOTER_Y = 810.0  # pieds de page « MandarinBean.com / Page N / Level N »

# level -> (fichier, en-tête attendu de la colonne la plus à droite)
LEVEL_FILES = [
    (1, "New-HSK-Vocabulary-Level-1.pdf"),
    (2, "New-HSK-Vocabulary-Level-2.pdf"),
    (3, "New-HSK-Vocabulary-Level-3.pdf"),
    (4, "New-HSK-Vocabulary-Level-4.pdf"),
    (5, "New-HSK-Vocabulary-Level-5.pdf"),
    (6, "New-HSK-Vocabulary-L6.pdf"),
    (7, "New-HSK-Vocabulary-Level-7-9.pdf"),  # bandeau 7-9
]

TONE_MAP = {
    "ā": "a", "á": "a", "ǎ": "a", "à": "a",
    "ē": "e", "é": "e", "ě": "e", "è": "e",
    "ī": "i", "í": "i", "ǐ": "i", "ì": "i",
    "ō": "o", "ó": "o", "ǒ": "o", "ò": "o",
    "ū": "u", "ú": "u", "ǔ": "u", "ù": "u",
    "ǖ": "v", "ǘ": "v", "ǚ": "v", "ǜ": "v", "ü": "v",
    "ń": "n", "ň": "n", "ǹ": "n", "ḿ": "m",
}


def strip_tones(s: str) -> str:
    return "".join(TONE_MAP.get(c, c) for c in s.lower())


def get_pages(pdf: Path):
    """Retourne [(hauteur_de_page, [mots])] pour chaque page du PDF."""
    xml = subprocess.run(
        ["pdftotext", "-bbox-layout", str(pdf), "-"],
        check=True, capture_output=True, text=True,
    ).stdout
    root = ET.fromstring(xml)
    pages = []
    for page in root.iter(f"{NS}page"):
        words = []
        for w in page.iter(f"{NS}word"):
            t = (w.text or "").strip()
            if not t:
                continue
            words.append({
                "t": t,
                "x0": float(w.get("xMin")),
                "y0": float(w.get("yMin")),
            })
        pages.append((float(page.get("height")), words))
    return pages


def find_columns(pages):
    """Position X de chaque colonne, lue sur la ligne d'en-tête du tableau.

    Retourne un tuple `(colonnes, frontieres)` où `colonnes` liste les noms
    de gauche à droite et `frontieres` les abscisses de séparation.
    """
    for _height, words in pages:
        heads = {}
        for w in words:
            if not HEADER_Y[0] < w["y0"] < HEADER_Y[1]:
                continue
            t = w["t"].rstrip(".")
            if t in ("NO", "WORD", "PINYIN", "TRANSLATION"):
                heads[t] = w["x0"]
            elif t == "PART":
                heads["POS"] = w["x0"]
        if len(heads) >= 4 and "WORD" in heads and "PINYIN" in heads:
            order = ["NO", "WORD", "PINYIN"]
            if "POS" in heads:
                order.append("POS")
            if "TRANSLATION" in heads:
                order.append("TRANSLATION")
            if len(order) == len(heads):
                xs = sorted((heads[k], k) for k in order)
                names = [k for _x, k in xs]
                positions = [x for x, _k in xs]
                bounds = [
                    (positions[i] + positions[i + 1]) / 2
                    for i in range(len(positions) - 1)
                ]
                return names, bounds
    return None, None


def cluster_rows(words):
    """Regroupe les mots en lignes horizontales, dans l'ordre de lecture."""
    rows = []
    for w in sorted(words, key=lambda w: (w["y0"], w["x0"])):
        if not rows or w["y0"] > rows[-1][0] + TOL:
            rows.append([w["y0"], [w]])
        else:
            rows[-1][1].append(w)
    return [sorted(r[1], key=lambda w: w["x0"]) for r in rows]


def column_of(x0, bounds):
    for i, b in enumerate(bounds):
        if x0 < b:
            return i
    return len(bounds)


def parse_level(level: int, pdf: Path):
    pages = get_pages(pdf)
    names, bounds = find_columns(pages)
    if not bounds:
        sys.exit(f"colonnes introuvables dans {pdf.name}")
    has_trans = "TRANSLATION" in names
    i_no = names.index("NO")
    i_word = names.index("WORD")
    i_pinyin = names.index("PINYIN")
    i_pos = names.index("POS") if "POS" in names else None
    i_trans = names.index("TRANSLATION") if has_trans else None

    entries = []
    cur = None
    problems = []

    for height, words in pages:
        words = [w for w in words if w["y0"] < min(FOOTER_Y, height - 25)]
        for ws in cluster_rows(words):
            cols = [[] for _ in names]
            for w in ws:
                cols[column_of(w["x0"], bounds)].append(w["t"])
            left_only = all(not cols[i] for i in range(len(names)) if i >= i_word)
            if left_only and not cols[i_no]:
                continue  # ligne parasite

            no_txt = " ".join(cols[i_no]).strip()
            if re.fullmatch(r"\d{1,4}", no_txt):
                cur = {
                    "no": int(no_txt),
                    "hanzi": " ".join(cols[i_word]),
                    "pinyin": " ".join(cols[i_pinyin]),
                    "pos": " ".join(cols[i_pos]) if i_pos is not None else "",
                    "meaning": " ".join(cols[i_trans]) if i_trans is not None else "",
                }
                entries.append(cur)
            elif cur is None:
                continue  # page de garde / en-têtes
            else:
                # Ligne de continuation (traduction ou nature grammaticale
                # coupée au trait de page) : on complète l'entrée en cours.
                if cols[i_word]:
                    cur["hanzi"] += " " + " ".join(cols[i_word])
                if cols[i_pinyin]:
                    cur["pinyin"] += " " + " ".join(cols[i_pinyin])
                if i_pos is not None and cols[i_pos]:
                    cur["pos"] = (cur["pos"] + " " + " ".join(cols[i_pos])).strip()
                if i_trans is not None and cols[i_trans]:
                    cur["meaning"] = (
                        cur["meaning"] + " " + " ".join(cols[i_trans])
                    ).strip()
                # Une ligne de continuation sans aucun contenu exploitable
                # (numéro orphelin) ne doit pas rester rattachée à l'entrée.
                if not (cols[i_word] or cols[i_pinyin]
                        or (i_pos is not None and cols[i_pos])
                        or (i_trans is not None and cols[i_trans])):
                    if re.fullmatch(r"\d{1,4}", no_txt):
                        problems.append(
                            f"L{level} n°{cur['no']} : ligne suivante anormale {ws!r}"
                        )

    out = []
    for e in entries:
        hanzi = re.sub(r"\s+", "", e["hanzi"])
        pinyin = re.sub(r"\s+", " ", e["pinyin"]).strip()
        pos = re.sub(r"\s+", " ", e["pos"]).strip().strip("、").strip()
        meaning = re.sub(r"\s+", " ", e["meaning"]).strip()
        if not hanzi or not pinyin:
            problems.append(f"L{level} n°{e['no']} incomplet : {e!r}")
            continue
        if not meaning and has_trans:
            problems.append(f"L{level} n°{e['no']} sans traduction : {hanzi}")
        plain = strip_tones(re.sub(r"[\s'’]+", "", pinyin))
        answers = sorted(
            {
                strip_tones(re.sub(r"[\s'’]+", "", part))
                for part in re.split(r"[/、,;|]", pinyin)
                if part.strip()
            }
        )
        out.append({
            "level": level,
            "no": e["no"],
            "hanzi": hanzi,
            "pinyin": pinyin,
            "pos": pos,
            "meaning": meaning,
            "plain": plain,
            "answers": answers,
        })
    return out, problems


def main():
    all_entries = []
    problems = []
    for level, filename in LEVEL_FILES:
        pdf = ROOT / filename
        if not pdf.exists():
            sys.exit(f"PDF absent : {pdf}")
        entries, probs = parse_level(level, pdf)
        problems += probs
        nos = [e["no"] for e in entries]
        if nos != list(range(1, len(entries) + 1)):
            problems.append(f"L{level} : numérotation cassée {nos[:5]}…")
        all_entries += entries
        print(f"niveau {level}: {len(entries)} entrées", file=sys.stderr)

    # Identifiant unique sur l'ensemble du lexique.
    for i, e in enumerate(all_entries, start=1):
        e["id"] = i

    pos_by_level = {}
    for e in all_entries:
        pos_by_level.setdefault(e["level"], set()).add(e["pos"])
    for level in sorted(pos_by_level):
        vals = sorted(v for v in pos_by_level[level] if v)
        print(f"L{level} POS distincts ({len(vals)}): {vals}", file=sys.stderr)

    dest = ROOT / "hskhelp" / "assets" / "_raw_vocab.json"
    dest.write_text(
        json.dumps(all_entries, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    print(f"{len(all_entries)} entrées -> {dest}", file=sys.stderr)
    for p in problems[:40]:
        print("ATTENTION:", p, file=sys.stderr)
    print(f"{len(problems)} avertissements", file=sys.stderr)
    if len(problems) > 40:
        print("(…)", file=sys.stderr)


if __name__ == "__main__":
    main()
