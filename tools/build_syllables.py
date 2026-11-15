#!/usr/bin/env python3
"""Génère hskhelp/lib/data/syllables.dart : la table des syllabes valides.

La table est celle du pinyin mandarin standard. Elle sert à segmenter une
saisie en syllabes (DP) afin de comparer les tons syllabe par syllabe.

Le « ü » y est noté « u » : toute saisie est ramenée à cette graphie avant
segmentation, donc `nver`, `nu:er`, `nüer` et `nuer` sont équivalents.

Usage :
    python3 tools/build_syllables.py            # écrit le fichier Dart
    python3 tools/build_syllables.py --check    # vérifie sans écrire
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Table standard des syllabes du pinyin mandarin.
SYLLABLES = set("""
a o e ai ei ao ou an en ang eng er
yi ya yo ye yai yao you yan yin yang ying yong yu yue yuan yun
wu wa wo wai wei wan wen wang weng
ba bo bai bei bao ban ben bang beng bi bie biao bian bin bing bu
pa po pai pei pao pou pan pen pang peng pi pie piao pian pin ping pu
ma mo me mai mei mao mou man men mang meng mi mie miao miu mian min ming mu
fa fo fei fou fan fen fang feng fu
da de dai dei dao dou dan den dang deng dong di die diao diu dian ding du duo dui duan dun
ta te tai tao tou tan tang teng tong ti tie tiao tian ting tu tuo tui tuan tun
na ne nai nei nao nou nan nen nang neng nong ni nie niao niu nian nin niang ning nu nuo nuan nue
la le lai lei lao lou lan lang leng long li lia lie liao liu lian lin liang ling lu luo luan lun lue
ga ge gai gei gao gou gan gen gang geng gong gu gua guo guai gui guan gun guang
ka ke kai kei kao kou kan ken kang keng kong ku kua kuo kuai kui kuan kun kuang
ha he hai hei hao hou han hen hang heng hong hu hua huo huai hui huan hun huang
ji jia jie jiao jiu jian jin jiang jing jiong ju jue juan jun
qi qia qie qiao qiu qian qin qiang qing qiong qu que quan qun
xi xia xie xiao xiu xian xin xiang xing xiong xu xue xuan xun
zha zhe zhi zhai zhei zhao zhou zhan zhen zhang zheng zhong zhu zhua zhuo zhuai zhui zhuan zhun zhuang
cha che chi chai chao chou chan chen chang cheng chong chu chua chuo chuai chui chuan chun chuang
sha she shi shai shei shao shou shan shen shang sheng shu shua shuo shuai shui shuan shun shuang
re ri rao rou ran ren rang reng rong ru rua ruo rui ruan run
za ze zi zai zei zao zou zan zen zang zeng zong zu zuo zui zuan zun
ca ce ci cai cao cou can cen cang ceng cong cu cuo cui cuan cun
sa se si sai sao sou san sen sang seng song su suo sui suan sun
m n ng hm hng
""".split())

OUT = Path(__file__).resolve().parent.parent / "hskhelp/lib/data/syllables.dart"

HEADER = """\
/// Table des syllabes valides du pinyin mandarin ({n} entrées).
///
/// Sert à segmenter une saisie en syllabes afin de comparer les tons
/// syllabe par syllabe (ex. `nu3` + `er2` contre `nv3er2`).
///
/// Le « ü » y est noté « u » : toute saisie est ramenée à cette graphie
/// avant segmentation, donc `nver`, `nu:er`, `nüer` et `nuer` sont équivalents.
///
/// Généré par `tools/build_syllables.py` — ne pas éditer à la main.
const Set<String> kPinyinSyllables = {{
"""

WIDTH = 98  # largeur maximale des lignes de données, indent comprise.


def render() -> str:
    syllables = sorted(SYLLABLES)
    lines = [HEADER.format(n=len(syllables))]

    # Regroupe les entrées par ligne sans dépasser WIDTH caractères.
    current = " "
    for syl in syllables:
        entry = f" '{syl}',"
        if current.strip() and len(current) + len(entry) > WIDTH:
            lines.append(current.rstrip() + "\n")
            current = " "
        current += entry
    if current.strip():
        lines.append(current.rstrip() + "\n")

    lines.append("};\n")
    return "".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="échoue si le fichier Dart n'est pas à jour, sans l'écrire",
    )
    args = parser.parse_args()

    text = render()

    if args.check:
        if not OUT.exists():
            print(f"manquant : {OUT}", file=sys.stderr)
            return 1
        if OUT.read_text(encoding="utf-8") != text:
            print(f"périmé : {OUT}", file=sys.stderr)
            return 1
        print(f"à jour : {OUT} ({len(SYLLABLES)} syllabes)")
        return 0

    OUT.write_text(text, encoding="utf-8")
    print(f"{OUT} : {len(SYLLABLES)} syllabes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
