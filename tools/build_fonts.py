#!/usr/bin/env python3
"""Construit les polices embarquées de l'app.

Une seule famille est produite : ``HskHelp`` — latin + CJK (Noto Sans SC),
sous-ensemble limité aux caractères réellement utilisés par l'application.
Les trois langues (français, anglais, chinois) sont couvertes.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "hskhelp" / "assets"
FONTS = ASSETS / "fonts"

# Polices sources. Noto Sans SC est variable ; les deux autres sont statiques
# et présentes dans /usr/share/fonts/truetype/noto sur la machine de build.
SRC_SC = Path("/tmp/fonts/NotoSansSC.ttf")

UI_EXTRA = (
    "".join(chr(c) for c in range(0x20, 0x7F))  # ASCII
    + "ÀÂÄÇÉÈÊËÎÏÔÖÙÛÜàâäçéèêëîïôöùûüÿ"
    + "’‘“”–—…→←↑↓°·×÷§«»€"
    + "汉字词复习记错对好加油再见谢谢请问一二三四五"
)

# Voyelles toniques du pavé de tons (`_toneGroups` dans quiz_screen.dart).
TONE_PAD = "āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ"

def _download_sources():
    if not SRC_SC.exists():
        SRC_SC.parent.mkdir(parents=True, exist_ok=True)
        url = (
            "https://raw.githubusercontent.com/google/fonts/main/"
            "ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"
        )
        print(f"téléchargement de la police source: {url}", file=sys.stderr)
        subprocess.run(["curl", "-sL", "-o", str(SRC_SC), url], check=True)
    if not SRC_SC.exists() or SRC_SC.stat().st_size < 1000:
        sys.exit(f"police source manquante: {SRC_SC}")


def _collect_chars():
    d = json.loads((ASSETS / "vocab.json").read_text(encoding="utf-8"))
    chars = set(UI_EXTRA) | set(TONE_PAD)
    # Trois langues seulement : français, anglais, chinois.
    lang_keys = ("zh",)
    pos_keys = tuple(f"pos{k[0].upper()}{k[1:]}" for k in lang_keys)
    for e in d:
        for key in ("hanzi", "pinyin", "en", "fr", "posEn", "posFr", *lang_keys, *pos_keys):
            chars.update(e.get(key, ""))

    # Grammaire : titres, explications, exemples, dans toutes les langues.
    grammar_path = ASSETS / "grammar_rules.json"
    if grammar_path.exists():
        def _add(value):
            if isinstance(value, str):
                chars.update(value)
            elif isinstance(value, dict):
                for v in value.values():
                    _add(v)
            elif isinstance(value, list):
                for v in value:
                    _add(v)

        _add(json.loads(grammar_path.read_text(encoding="utf-8")))

    for src in list((ROOT / "hskhelp" / "lib").rglob("*.dart")) + list(
        (ROOT / "hskhelp" / "test").rglob("*.dart")
    ):
        chars.update(c for c in src.read_text(encoding="utf-8") if ord(c) > 0x7F)

    # Contrôle : le pavé de tons doit être repris tel quel dans l'interface.
    quiz = (ROOT / "hskhelp" / "lib" / "screens" / "quiz_screen.dart").read_text(
        encoding="utf-8"
    )
    block = quiz.split("_toneGroups", 1)[1].split("];", 1)[0]
    pad_in_ui = "".join(c for c in block if ord(c) > 0x7F)
    if set(pad_in_ui) != set(TONE_PAD):
        missing, extra = set(TONE_PAD) - set(pad_in_ui), set(pad_in_ui) - set(TONE_PAD)
        sys.exit(f"_toneGroups diverge de TONE_PAD: manquant={sorted(missing)} "
                 f"en trop={sorted(extra)}")
    chars.update(pad_in_ui)
    return chars


def _subset(src, dest, text_file):
    subprocess.run(
        [
            sys.executable, "-m", "fontTools.subset", str(src),
            f"--text-file={text_file}",
            f"--output-file={dest}",
            "--layout-features=*",
            "--name-IDs=*",
            "--notdef-outline",
        ],
        check=True, capture_output=True, text=True,
    )
    print(f"{dest} ({dest.stat().st_size // 1024} Ko)", file=sys.stderr)


def main():
    _download_sources()
    chars = _collect_chars()
    text_file = Path(tempfile.mkdtemp()) / "chars.txt"
    text_file.write_text("".join(sorted(chars)), encoding="utf-8")

    FONTS.mkdir(parents=True, exist_ok=True)

    # Famille principale : Noto Sans SC (variable → deux graisses instanciées).
    for weight, out_name in ((400, "HskHelp-Regular.ttf"), (700, "HskHelp-Bold.ttf")):
        inst = Path(tempfile.mkdtemp()) / "inst.ttf"
        subprocess.run(
            [
                sys.executable, "-m", "fontTools.varLib.instancer",
                str(SRC_SC), f"wght={weight}", "-o", str(inst),
            ],
            check=True, capture_output=True, text=True,
        )
        _subset(inst, FONTS / out_name, text_file)

    # Contrôle final : chaque écriture doit être couverte.
    from fontTools.ttLib import TTFont

    def cmap_of(path):
        cmap = set()
        for table in TTFont(str(path))["cmap"].tables:
            cmap.update(table.cmap.keys())
        return cmap

    checks = [
        (FONTS / "HskHelp-Regular.ttf", TONE_PAD, "pavé de tons"),
    ]
    for path, sample, label in checks:
        cmap = cmap_of(path)
        missing = [c for c in set(sample) if ord(c) not in cmap]
        if missing:
            sys.exit(f"{path.name}: {label} incomplet, manquant {missing}")

    # Contrôle global : tout caractère collecté doit être présent.
    covered = cmap_of(FONTS / "HskHelp-Regular.ttf")
    uncovered = sorted(c for c in chars if ord(c) not in covered)
    if uncovered:
        sys.exit(
            f"{len(uncovered)} caractères non couverts par les polices : "
            f"{''.join(uncovered[:40])!r}"
        )
    print("polices complètes (latin, tons, chinois)", file=sys.stderr)


if __name__ == "__main__":
    main()
