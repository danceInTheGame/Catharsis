#!/usr/bin/env python3
"""Répare les rares déchets produits par les modèles Argos.

Les modèles neuronaux échouent parfois sur les entrées très courtes
(interjections) ou sur celles contenant un motif en caractères chinois : ils
émettent alors des points de code de la zone à usage privé (U+E000–U+F8FF),
voire des caractères d'une autre écriture (cyrillique/hébreu dans l'espagnol).

Ces cas sont trop peu nombreux pour justifier une nouvelle passe de traduction
(coûteuse et non déterministe) : on les corrige ici, une fois pour toutes, avec
des valeurs écrites à la main. Le script est idempotent : chaque remplacement
vérifie la valeur attendue avant d'écrire, et signale si la donnée a changé.

Usage : python3 tools/fix_i18n_garbage.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VOCAB = ROOT / "hskhelp" / "assets" / "vocab.json"

# index -> (langue, ancienne valeur, nouvelle valeur)
FIXES = {
    201: [("zh", "\ue6d5", "她")],
    284: [("zh", "痷\ue019 ; (真实的)", "真的 ; (真实的)")],
    300: [("zh", "瓳\ue4c7瓳", "啊，哦")],
    357: [("zh", "花开 ; (多彩) ⁇ .", "花 ; (多彩的)")],
    543: [("zh", "\ue67b琌\ue4d1", "只是，仅仅")],
    1000: [("zh", "瓳\ue4c7瓳", "啊，哦")],
    1533: [("zh", "垛\ue4c7垛", "嗯，嗯")],
    1762: [("zh", "边\ue6dd", "晚安")],
    2001: [("zh", "瓳\ue4c7ぱ摆", "哎呀，啊")],
    2933: [("zh", "\ue0a4或快\ue4ce", "怎么，什么")],
    3319: [("zh", "瓳\ue4c7瓳", "啊，哦")],
    1326: [(
        "es",
        "ya, desde; tanto ... como ..., así como (utilizado en el patrón э...",
        "ya, desde; tanto ... como ..., así como (utilizado en el patrón 既...又/ 也...)",
    )],
    1388: [(
        "es",
        "sentirse libre, no dudar en (a menudo en el patrón יино + verb); aunque, a pesar de",
        "siéntete libre, no dudes en (a menudo en el patrón 尽管 + verbo); aunque, a pesar de",
    )],
    1407: [(
        "es",
        None,  # valeur tronquée en sortie : on remplace tout le champ
        "precisamente, exactamente (utilizado para el énfasis); sólo, simplemente; "
        "incluso si, incluso (como en 就是...也...)",
    )],
}


def main():
    vocab = json.loads(VOCAB.read_text(encoding="utf-8"))
    changed = 0
    for idx, fixes in FIXES.items():
        entry = vocab[idx]
        for lang, old, new in fixes:
            cur = entry.get(lang)
            if cur == new:
                continue  # déjà corrigé
            if old is not None and cur != old:
                print(f"! entrée {idx} [{lang}] inattendue : {cur!r}", file=sys.stderr)
                continue
            entry[lang] = new
            changed += 1
    VOCAB.write_text(
        json.dumps(vocab, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    print(f"{changed} valeur(s) corrigée(s) dans {VOCAB}")


if __name__ == "__main__":
    main()
