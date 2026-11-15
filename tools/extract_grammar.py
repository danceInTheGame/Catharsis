#!/usr/bin/env python3
"""Extrait les leçons de grammaire (leçons + règles + exemples).

Deux sources d'exemples sont récoltées :
  * le dialogue de la leçon (``lecon-replique``), mot à mot, avec pinyin et
    traduction française ;
  * les phrases chinoises citées **dans le texte des règles** (« Points de
    langue »), qui sont directement liées à la règle concernée.

Ces dernières enrichissent nettement le nombre d'exercices par règle.
"""
import json
import re
from pathlib import Path

from bs4 import BeautifulSoup

ROOT = Path('/home/sah/chine-grammaire/mandarin/lecons')
OUT = Path('/home/sah/HskHelp/hskhelp/assets/grammar.json')

LEVEL_MAP = {
    'niveau-a': 1,
    'niveau-b': 2,
    'niveau-c': 3,
    'niveau-d': 4,
    'niveau-e': 5,
}

# Une phrase chinoise : au moins deux sinogrammes, éventuellement entrecoupés
# de ponctuation chinoise. On évite d'avaler le texte latin qui suit.
HANZI_SENTENCE = re.compile(
    r'[\u4e00-\u9fff]+(?:[，。？！、；：""''（）《》][\u4e00-\u9fff]+)*'
)


def extract_rule_examples(text):
    """Relève les phrases chinoises citées dans l'explication d'une règle."""
    found = []
    seen = set()
    for match in HANZI_SENTENCE.finditer(text):
        phrase = match.group(0)
        # Au moins deux sinogrammes et pas déjà vu.
        if len(re.findall(r'[\u4e00-\u9fff]', phrase)) < 2:
            continue
        if phrase in seen:
            continue
        seen.add(phrase)
        found.append(phrase)
    return found


def extract_lesson(path):
    try:
        html = path.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        return None
    soup = BeautifulSoup(html, 'html.parser')

    title = soup.find('h1')
    title_text = title.get_text(strip=True) if title else path.stem

    rules = []
    notes = soup.find('section', class_='lecon-notes')
    if notes:
        for article in notes.find_all('article', class_='lecon-note'):
            h3 = article.find('h3')
            rule_title = h3.get_text(strip=True) if h3 else ''
            if h3:
                h3.decompose()
            content = article.get_text(separator='\n', strip=True)
            if rule_title or content:
                rules.append({
                    'title': rule_title,
                    'explanation': content,
                    'examples': extract_rule_examples(content),
                })

    examples = []
    dialogue = soup.find('ol', class_='lecon-dialogue')
    if dialogue:
        for rep in dialogue.find_all('li', class_='lecon-replique'):
            zh = rep.find(class_='lecon-replique__zh')
            fr = rep.find(class_='lecon-replique__fr')
            py = rep.find(class_='lecon-replique__py')
            if zh:
                examples.append({
                    'zh': zh.get_text(separator=' ', strip=True),
                    'pinyin': py.get_text(strip=True) if py else '',
                    'fr': fr.get_text(strip=True) if fr else '',
                })

    return {
        'id': path.stem,
        'title': title_text,
        'rules': rules,
        'examples': examples,
        'path': str(path),
    }


def main():
    data = []
    rule_example_count = 0
    for lvl_dir, hsk in LEVEL_MAP.items():
        d = ROOT / lvl_dir
        if not d.exists():
            continue
        for html in sorted(d.glob('*.html')):
            if html.name == 'index.html':
                continue
            les = extract_lesson(html)
            if les:
                les['level'] = hsk
                rule_example_count += sum(
                    len(r['examples']) for r in les['rules']
                )
                data.append(les)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f'Extracted {len(data)} lessons → {OUT}')
    print(f'{rule_example_count} phrases citées dans les règles')


if __name__ == '__main__':
    main()
