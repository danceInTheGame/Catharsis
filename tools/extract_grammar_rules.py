#!/usr/bin/env python3
"""Extrait la grammaire du corpus hors ligne (``/home/sah/chine-grammaire``).

Le contenu présente ses 513 règles de grammaire ainsi :

* 5 pages de niveau (``pages/RGL*.html``) : A1 (HSK1), A2 (HSK2), B1 (HSK3),
  B2 (HSK4), C1 (HSK5-6), chacune découpée en 3 sections — *Catégories
  grammaticales*, *Structures grammaticales*, *Comparaisons* — puis en
  catégories (Adverbes, Verbes, Particules…), chaque catégorie étant un tableau
  « Règles de grammaire | Structure | Exemples ».
* 513 pages de règle (``pages/ASG*.html``), qui sont la fiche complète :
  titre, niveau, introduction, puis des blocs de texte, des *Structures* et des
  *Exemples* (hanzi + pinyin + traduction française, avec le mot clé de la
  règle en rouge).

Ce module reproduit fidèlement cette structure dans un JSON français servi
par l'application :

    levels[]  →  sections[]  →  categories[]  →  rules[]
    rules[]   →  blocks[] (paragraphe, titre, structure, exemples)

Les exemples sont conservés tels quels (hanzi espacés, pinyin, traduction) et
les mots mis en rouge sont notés par des index de caractères
(``hl``), afin que l'application puisse les afficher — et les cacher — exactement
comme dans le corpus.

Usage : python3 tools/extract_grammar_rules.py
"""
import html
import json
import re
import sys
from pathlib import Path

from bs4 import BeautifulSoup, NavigableString, Tag

SOURCE = Path("/home/sah/chine-grammaire")
PAGES = SOURCE / "pages"
OUT = Path("/home/sah/HskHelp/hskhelp/assets/grammar_rules.json")

# Les 5 pages de niveau, dans l'ordre.
LEVELS = [
    ("RGLA1", "A1", 1, "Grammaire chinoise niveau A1 (HSK1)"),
    ("RGLA2", "A2", 2, "Grammaire chinoise niveau A2 (HSK2) — élémentaire"),
    ("RGLB1", "B1", 3, "Grammaire chinoise niveau B1 (HSK3) — intermédiaire"),
    ("RGLB2", "B2", 4, "Grammaire chinoise niveau B2 (HSK4) — avancé"),
    ("RGLC1", "C1", 5, "Grammaire chinoise niveau C1 (HSK5-6) — confirmé"),
]

LEVEL_MAP = {"A1": 1, "A2": 2, "B1": 3, "B2": 4, "C1": 5}

WS = re.compile(r"[ \t  ]+")
MULTI_NL = re.compile(r"\n\s*\n+")


def clean_text(fragment, keep_newlines=False):
    """Texte lisible d'un fragment HTML : entités décodées, espaces normalisés."""
    fragment = re.sub(r"(?is)<(script|style)[^>]*>.*?</\1>", " ", fragment)
    fragment = re.sub(r"(?i)<br\s*/?>", "\n" if keep_newlines else " ", fragment)
    fragment = re.sub(r"(?s)<[^>]+>", "", fragment)
    fragment = html.unescape(fragment)
    fragment = fragment.replace("\xa0", " ").replace("​", "")
    if keep_newlines:
        return MULTI_NL.sub("\n", WS.sub(" ", fragment)).strip()
    return WS.sub(" ", fragment).strip()


# ────────────────────────────────────────────────────────────── exemples (liju)
def _normalize(chars):
    """(caractère, en_rouge)[] → (texte, plages rouges indexées sur le texte)."""
    out, hl = [], []
    pending_space = False
    red_start = None
    for char, red in chars:
        if char.isspace() or char == "\xa0":
            pending_space = True
            continue
        if pending_space and out:
            out.append(" ")
        pending_space = False
        if red and red_start is None:
            red_start = len(out)
        if not red and red_start is not None:
            hl.append([red_start, len(out)])
            red_start = None
        out.append(char)
    if red_start is not None:
        hl.append([red_start, len(out)])
    # Une espace de séparation peut tomber à l'intérieur d'une plage rouge
    # (« <span class=red> 受 </span> ») : on la retire pour ne garder que le mot.
    trimmed = []
    for a, b in hl:
        while a < b and out[a] == " ":
            a += 1
        while a < b and out[b - 1] == " ":
            b -= 1
        if a < b:
            trimmed.append([a, b])
    return "".join(out), trimmed


def _collect(node, out, red=False):
    """Récolte le contenu textuel d'un <li>, en marquant les mots en rouge."""
    for child in node.children:
        if isinstance(child, NavigableString):
            out.extend((c, red) for c in str(child))
        elif isinstance(child, Tag):
            classes = child.get("class") or []
            lang = child.get("lang") or ""
            # Pinyin et traduction : ce ne sont pas des hanzi.
            if "pinyin" in classes or "trans" in classes or lang in ("pny", "fr"):
                continue
            _collect(child, out, red or "red" in classes)


def parse_example_li(li_tag):
    item = {}
    out = []
    _collect(li_tag, out)
    zh, hl = _normalize(out)
    if not zh:
        return None
    item["zh"] = zh
    if hl:
        item["hl"] = hl
    py = li_tag.find("span", class_="pinyin")
    if py:
        text = WS.sub(" ", " ".join(py.stripped_strings)).strip()
        if text:
            item["py"] = text
    trans = li_tag.find("span", class_="trans")
    if trans:
        text = clean_text(" ".join(trans.stripped_strings))
        if text:
            item["fr"] = text
    if "x" in (li_tag.get("class") or []):
        item["ok"] = False  # forme incorrecte, à éviter
    return item


def parse_liju(div_html):
    soup = BeautifulSoup(f"<ul>{div_html}</ul>", "html.parser")
    items = []
    for li in soup.find_all("li"):
        item = parse_example_li(li)
        if item:
            items.append(item)
    if not items:  # quelques blocs citent une phrase sans <li>
        text = clean_text(div_html)
        if text:
            items.append({"zh": text})
    return items


# ──────────────────────────────────────────────────────────────── page de règle
def read_html(path):
    raw = path.read_bytes()
    for enc in ("utf-8", "cp1252", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


CUT_RE = re.compile(
    r"(?is)<h2[^>]*>\s*(?:Articles\s+connexes|Infos\s+suppl[ée]mentaires)\s*</h2>"
)


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
    """Retire les libellés de navigation collés en fin de paragraphe.

    Sur quelques pages, le « sommaire » et les liens de fin ne sont pas des
    titres : leur texte se retrouve collé à la fin du dernier paragraphe
    (« … à l'écrit.SommaireStructureExemplesArticles connexes… »).
    """
    for marker in NAV_MARKERS:
        index = text.find(marker)
        if index != -1 and len(text) - index <= 140:
            return text[:index].strip()
    return text


def cut_navigation(body):
    """Retire la navigation de fin (« Articles connexes », « Infos supplémentaires »)."""
    m = CUT_RE.search(body)
    return body[: m.start()] if m else body


def article_body(html_src):
    m = re.search(r'(?is)<div class="article__body">(.*?)</article>', html_src)
    if m:
        return cut_navigation(m.group(1))
    # Pages héritées : le corps va du <h1> à la navigation de fin.
    start = re.search(r"(?is)<h1[^>]*>", html_src)
    if not start:
        return ""
    return cut_navigation(html_src[start.end():])


BLOCK_RE = re.compile(
    r"(?is)<h2[^>]*>(.*?)</h2>"
    r"|<h3[^>]*>(.*?)</h3>"
    r"|<div[^>]*class=\"?jiegou\"?[^>]*>(.*?)</div>"
    r"|<div[^>]*class=\"?liju[^\"'>]*\"?[^>]*>(.*?)</div>"
    r"|<table[^>]*>(.*?)</table>"
)


def _cells(row_html):
    return [clean_text(c) for c in re.findall(r"(?is)<t[hd][^>]*>(.*?)</t[hd]>", row_html)]


def parse_example_table(table_html):
    """Certains tableaux listent des exemples (colonnes « Pinyin » et « Traduction »).

    Les tableaux de conjugaison (Sujet | 把 | Objet | Verbe…) n'ont pas ces
    colonnes et sont donc laissés de côté.
    """
    rows = re.findall(r"(?is)<tr[^>]*>(.*?)</tr>", table_html)
    if len(rows) < 2:
        return []
    header = [h.lower() for h in _cells(rows[0])]
    py_i = next((i for i, h in enumerate(header) if "pinyin" in h), None)
    fr_i = next(
        (i for i, h in enumerate(header)
         if h.startswith("traduction") or "fran" in h),
        None,
    )
    if py_i is None or fr_i is None:
        return []
    items = []
    for row in rows[1:]:
        cs = _cells(row)
        if len(cs) < 2:
            continue
        zh = " ".join(c for i, c in enumerate(cs) if i not in (py_i, fr_i) and c)
        if len(re.findall(r"[一-鿿]", zh)) < 2:
            continue
        item = {"zh": zh}
        if py_i < len(cs) and cs[py_i]:
            item["py"] = cs[py_i]
        if fr_i < len(cs) and cs[fr_i]:
            item["fr"] = cs[fr_i]
        items.append(item)
    return items


def parse_rule(path):
    src = read_html(path)
    title_m = re.search(r"(?is)<h1[^>]*>(.*?)</h1>", src)
    if not title_m:
        return None
    title = clean_text(title_m.group(1))

    level = None
    meta = re.search(r'(?is)<div class="article__meta">(.*?)</div>', src)
    if meta:
        m = re.search(r"[A-C][12]", clean_text(meta.group(1)))
        if m:
            level = m.group(0)

    body = article_body(src)
    blocks = []
    pos = 0
    for m in BLOCK_RE.finditer(body):
        between = clean_text(body[pos:m.start()])
        if between:
            blocks.append({"t": "p", "fr": strip_nav_tail(between)})
        pos = m.end()
        if m.group(1) is not None:
            txt = clean_text(m.group(1))
            if txt:
                blocks.append({"t": "h2", "fr": txt})
        elif m.group(2) is not None:
            txt = clean_text(m.group(2))
            if txt:
                blocks.append({"t": "h3", "fr": txt})
        elif m.group(3) is not None:
            txt = clean_text(m.group(3))
            if txt:
                blocks.append({"t": "structure", "fr": txt})
        elif m.group(5) is not None:
            items = parse_example_table(m.group(5))
            if items:
                blocks.append({"t": "examples", "items": items})
        else:
            items = parse_liju(m.group(4))
            if items:
                blocks.append({"t": "examples", "items": items})
    tail = clean_text(body[pos:])
    if tail and len(tail) > 3:
        blocks.append({"t": "p", "fr": strip_nav_tail(tail)})

    return {
        "id": path.stem,
        "title": title,
        "level": level,
        "blocks": blocks,
        "hasExamples": any(b["t"] == "examples" for b in blocks),
    }


# ─────────────────────────────────────────────────────────── page de niveau
def flush_tables(chunk, sections, category):
    for table in re.findall(r"(?is)<table[^>]*>(.*?)</table>", chunk):
        for row in re.findall(r"(?is)<tr[^>]*>(.*?)</tr>", table):
            cells = re.findall(r"(?is)<t[hd][^>]*>(.*?)</t[hd]>", row)
            if len(cells) < 2:
                continue
            link = re.search(
                r'(?is)<a[^>]*href="(ASG[0-9A-Z]+\.html)"[^>]*>(.*?)</a>', cells[0]
            )
            if not link:
                continue  # ligne d'en-tête
            entry = {
                "id": link.group(1).split(".")[0],
                "title": clean_text(link.group(2)) or clean_text(cells[0]),
            }
            if len(cells) > 1:
                structure = clean_text(cells[1])
                if structure and structure.lower() != "structure":
                    entry["structure"] = structure
            if len(cells) > 2:
                span = re.search(r"(?is)<span[^>]*>(.*?)</span>", cells[2])
                example = clean_text(span.group(1) if span else cells[2])
                if example:
                    entry["example"] = example
            if category is not None:
                category.setdefault("rules", []).append(entry)
            elif sections:
                sections[-1].setdefault("rules", []).append(entry)


def parse_level_page(stem, code, app_level, label):
    src = read_html(PAGES / f"{stem}.html")
    body_m = re.search(r'(?is)<div class="article__body">(.*?)</article>', src)
    body = body_m.group(1) if body_m else src

    intro = []
    intro_m = re.search(r'(?is)<div id="mw-content-text"[^>]*>(.*?)(<h2)', body)
    if intro_m:
        intro = [
            clean_text(p)
            for p in re.findall(r"(?is)<p[^>]*>(.*?)</p>", intro_m.group(1))
        ]
        intro = [p for p in intro if len(p) > 3]
    body = re.sub(r'(?is)<div id="mw-content-text"[^>]*>', "", body)

    sections, current, category = [], None, None
    pos = 0
    for m in re.finditer(
        r"(?is)<h2[^>]*>(.*?)</h2>|<h3[^>]*>(.*?)</h3>|<h4[^>]*>(.*?)</h4>", body
    ):
        flush_tables(body[pos:m.start()], sections, category)
        pos = m.end()
        if m.group(1) is not None:
            name = clean_text(m.group(1))
            current = {"name": name, "categories": []}
            sections.append(current)
            category = None
        else:
            # h3 = catégorie ; h4 = sous-catégorie (« Verbes auxiliaires »).
            name = clean_text(m.group(2) if m.group(2) is not None else m.group(3))
            if current is None:
                current = {"name": "", "categories": []}
                sections.append(current)
            category = {"name": name}
            current["categories"].append(category)
    flush_tables(body[pos:], sections, category)

    for sec in sections:
        sec["categories"] = [c for c in sec["categories"] if c.get("rules")]
    sections = [s for s in sections if s["categories"]]
    return {
        "code": code,
        "appLevel": app_level,
        "title": label,
        "intro": intro,
        "sections": sections,
    }


def main():
    if not SOURCE.exists():
        sys.exit(f"corpus introuvable : {SOURCE}")

    levels = [
        parse_level_page(stem, code, lv, label) for stem, code, lv, label in LEVELS
    ]

    index = {}
    for lev in levels:
        for sec in lev["sections"]:
            for cat in sec["categories"]:
                for rule in cat.get("rules", []):
                    index[rule["id"]] = {
                        "level": lev["appLevel"],
                        "levelCode": lev["code"],
                        "section": sec["name"],
                        "category": cat["name"],
                    }

    rules, extras = [], []
    for path in sorted(PAGES.glob("ASG*.html")):
        rule = parse_rule(path)
        if rule is None:
            print(f"  ! page sans titre : {path.name}", file=sys.stderr)
            continue
        meta = index.get(rule["id"])
        if meta:
            rule.update(meta)
            rules.append(rule)
        else:
            extras.append(rule)

    # Pages non référencées par un tableau de niveau : doublons ou annexes.
    titles = {r["title"] for r in rules}
    for rule in extras:
        if rule["title"] in titles:
            print(f"  · doublon ignoré : {rule['id']} ({rule['title']})", file=sys.stderr)
            continue
        level = LEVEL_MAP.get(rule["level"] or "", 5)
        rule.update({
            "level": level,
            "levelCode": "C1" if level == 5 else "A1",
            "section": "Catégories grammaticales",
            "category": "Divers",
        })
        rules.append(rule)
        titles.add(rule["title"])
        print(f"  ! {rule['id']} absent des tableaux "
              f"(rattaché au niveau {level})", file=sys.stderr)


    data = {"levels": levels, "rules": rules}
    OUT.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )

    nb_ex = sum(
        len(b["items"]) for r in rules for b in r["blocks"] if b["t"] == "examples"
    )
    nb_struct = sum(1 for r in rules for b in r["blocks"] if b["t"] == "structure")
    nb_hl = sum(1 for r in rules for b in r["blocks"]
                if b["t"] == "examples" for it in b["items"] if it.get("hl"))
    no_ex = [r["id"] for r in rules if not r["hasExamples"]]
    print(f"{len(levels)} niveaux, {len(rules)} règles, {nb_struct} structures, "
          f"{nb_ex} exemples ({nb_hl} avec mot en rouge)")
    print(f"sans aucun exemple : {len(no_ex)} {no_ex[:12]}")
    per_level = {}
    for r in rules:
        per_level.setdefault(r["level"], []).append(r)
    for lv in sorted(per_level):
        print(f"  niveau {lv} : {len(per_level[lv])} règles")
    print(f"→ {OUT} ({OUT.stat().st_size // 1024} Ko)")


if __name__ == "__main__":
    main()
