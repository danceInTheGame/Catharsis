#!/usr/bin/env python3
"""Fabrique les exercices de grammaire à partir des règles extraites.

Deux types d'exercices :

* **mot manquant** — une phrase avec un trou ; quatre propositions
  (la bonne + trois leurres), un indice (le sens du mot manquant) ;
* **phrase mélangée** — les morceaux d'une phrase, remis dans l'ordre.

Chaque règle reçoit ``TARGET`` exercices de chaque type (100), du plus simple
au plus complexe :

1. mot mis en rouge, phrase courte ;
2. mot mis en rouge, phrase plus longue ;
3. mot non souligné de deux sinogrammes ou plus ;
4. mot grammatical d'un seul caractère, phrases longues, leurres pris dans les
   autres règles de la même catégorie.

Les phrases, les pinyin et les traductions viennent **exclusivement** des
exemples ; seuls les leurres sont choisis dans le lexique des règles
(mots réellement attestés dans la catégorie).

Sortie compacte (tableaux d'entiers, un dictionnaire de jetons par règle) pour
que l'APK reste raisonnable :

    s[rule] = [{k: [jetons], y: pinyin, f: traduction}, …]
    t[rule] = [jeton, …]
    m[rule] = [[phrase, trou, difficile, leurre1, leurre2, leurre3], …]
    w[rule] = [[phrase, difficile, ordre…], …]

Usage : python3 tools/build_grammar_exercises.py
"""
import json
import random
import re
import sys
from pathlib import Path

try:  # segmentation des rares phrases collées
    import jieba
    jieba.setLogLevel(40)
except ImportError:  # repli : plus longue correspondance sur le lexique HSK
    jieba = None

ROOT = Path(__file__).resolve().parent.parent
RULES = ROOT / "hskhelp" / "assets" / "grammar_rules.json"
OUT = ROOT / "hskhelp" / "assets" / "grammar_exercises.json"

TARGET = 100
VOCAB = ROOT / "hskhelp" / "assets" / "vocab.json"
HANZI = re.compile(r"[\u4e00-\u9fff]")
HANZI_RUN = re.compile(r"[\u4e00-\u9fff]+|[^\u4e00-\u9fff]+")

# Rempli par main() : lexique de segmentation des phrases collées.
LEXICON = set()
MAXLEN = 5
PUNCT = "，。？！、；：,.?!;:…“”‘’「」『』《》〈〉（）()"
DIFFICULTIES = (1, 2, 3, 4)


def hanzi_count(text):
    return len(HANZI.findall(text))


def split_trailing_punct(token):
    """« 欢迎。 » → (« 欢迎 », « 。 ») ; la ponctuation finale reste affichée."""
    i = len(token)
    while i > 0 and token[i - 1] in PUNCT:
        i -= 1
    return token[:i], token[i:]


def segment(text, lexicon, max_len):
    """Découpe un passage sans espaces (les exemples sont le plus souvent espacés).

    Les 164 phrases collées sont segmentées par jieba ; à défaut, par la plus
    longue correspondance sur le lexique HSK de l'application et les mots déjà
    attestés dans les exemples espacés.
    """
    if jieba is not None:
        return [w for w in jieba.cut(text, HMM=False) if w.strip()]
    out = []
    for run in HANZI_RUN.findall(text):
        if not HANZI.match(run):
            out.extend(run)  # ponctuation ou latin : un caractère par jeton
            continue
        i = 0
        while i < len(run):
            for size in range(min(max_len, len(run) - i), 0, -1):
                word = run[i:i + size]
                if size == 1 or word in lexicon:
                    out.append(word)
                    i += size
                    break
    return out


def tokenize(zh):
    """Découpe la phrase en mots espacés, en recollant la ponctuation."""
    zh = zh.strip()
    if " " in zh or "\u3000" in zh:
        raw = [t for t in re.split(r"\s+", zh) if t]
    elif LEXICON:
        raw = segment(zh, LEXICON, MAXLEN)
    else:
        raw = [zh]
    # Certaines phrases collent deux mots autour d'une virgule
    # (« 同意，我们 ») : on sépare le jeton au niveau de la ponctuation.
    split = []
    for token in raw:
        if all(ch in PUNCT for ch in token):
            split.append(token)
            continue
        split.extend(
            p for p in re.findall(r"[^，。？！、；：,.?!;:…]+[，。？！、；：,.?!;:…]*", token) if p
        )
    out = []
    for token in split:
        if out and all(ch in PUNCT for ch in token):
            out[-1] += token
        else:
            out.append(token)
    return out


def core_of(token):
    core, _ = split_trailing_punct(token)
    return core


def example_token_positions(zh, tokens):
    """Indice de début de chaque jeton dans la phrase d'origine."""
    positions = []
    pos = 0
    for token in tokens:
        at = zh.find(token, pos)
        if at < 0:
            at = pos
        positions.append(at)
        pos = at + len(token)
    return positions


def highlighted_positions(zh, tokens, ranges):
    """Jetons touchés par un mot en rouge."""
    starts = example_token_positions(zh, tokens)
    out = set()
    for i, token in enumerate(tokens):
        a, b = starts[i], starts[i] + len(token)
        for ra, rb in ranges:
            if ra < b and a < rb:
                out.add(i)
                break
    return out


class RuleData:
    def __init__(self, rule, siblings):
        self.id = rule["id"]
        self.level = rule["level"]
        self.category = rule.get("category", "")
        self.sentences = []  # (tokens, pinyin, fr, highlighted indices)
        self.examples = []
        for block in rule["blocks"]:
            if block["t"] != "examples":
                continue
            for item in block["items"]:
                zh = item.get("zh", "").strip()
                if not zh or hanzi_count(zh) < 2:
                    continue
                tokens = tokenize(zh)
                if len(tokens) < 2:
                    continue
                hl = highlighted_positions(zh, tokens, item.get("hl", []))
                self.examples.append((tokens, hl))
                self.sentences.append({
                    "tokens": tokens,
                    "y": item.get("py", ""),
                    "f": item.get("fr", ""),
                    "hl": hl,
                })
        self.siblings = siblings  # jetons des règles de la même catégorie
        self._usable = None

    def usable(self):
        """Phrases assez longues pour un exercice (au moins 3 jetons)."""
        if self._usable is None:
            good = [s for s in self.sentences if 3 <= len(s["tokens"]) <= 30]
            self._usable = good or [
                s for s in self.sentences if len(s["tokens"]) >= 2
            ]
        return self._usable


def sibling_pools(rules):
    """Jetons attestés dans chaque (niveau, catégorie), pour les leurres."""
    pools = {}
    for rule in rules:
        key = (rule["level"], rule.get("category", ""))
        pool = pools.setdefault(key, set())
        for block in rule["blocks"]:
            if block["t"] == "structure":
                for piece in re.split(r"[+／/|()（）\[\]…、，,]", block["fr"]):
                    piece = piece.strip()
                    if piece and hanzi_count(piece) and len(piece) <= 4:
                        pool.add(piece)
            if block["t"] != "examples":
                continue
            for item in block["items"]:
                for token in tokenize(item.get("zh", "")):
                    core = core_of(token)
                    if core and hanzi_count(core) and len(core) <= 4:
                        pool.add(core)
    return pools


def pick_distractors(rng, answer, sentence_cores, own_pool, foreign_pool, difficulty):
    """Trois leurres plausibles, distincts de la réponse et absents de la phrase."""
    candidates = []
    seen = set()
    sources = [own_pool, foreign_pool] if difficulty >= 3 else [own_pool]
    for source in sources:
        for word in source:
            if (
                word == answer
                or word in sentence_cores
                or word in seen
                or not hanzi_count(word)
            ):
                continue
            if len(word) > 4:
                continue
            seen.add(word)
            candidates.append(word)
    if len(candidates) < 3:
        # Dernier recours : n'importe quel mot de la règle, même déjà présent.
        for word in own_pool:
            if (
                word != answer
                and word not in seen
                and word not in sentence_cores
                and hanzi_count(word)
            ):
                seen.add(word)
                candidates.append(word)
            if len(candidates) >= 3:
                break
    if len(candidates) < 3:
        return None
    # À longueur voisine, les leurres sont plus crédibles.
    candidates.sort(key=lambda w: (abs(len(w) - len(answer)), rng.random()))
    shortlist = candidates[: max(3, min(len(candidates), 12))]
    rng.shuffle(shortlist)
    return shortlist[:3]


def build_fill(rule, rng):
    """Exercices « mot manquant » : trou + quatre propositions."""
    sentences = rule.usable()
    candidates = []
    for si, sent in enumerate(sentences):
        tokens = sent["tokens"]
        if len(tokens) < 3:
            continue
        for bi, token in enumerate(tokens):
            core = core_of(token)
            if not hanzi_count(core):
                continue
            hl = bi in sent["hl"]
            n = len(tokens)
            if hl and n <= 5:
                difficulty = 1
            elif hl:
                difficulty = 2
            elif hanzi_count(core) >= 2:
                difficulty = 3
            else:
                difficulty = 4
            candidates.append((difficulty, n, si, bi, core))

    if not candidates:
        return [], sentences

    candidates.sort(key=lambda c: (c[0], c[1]))

    # Répartition équilibrée entre les quatre paliers, du simple au complexe.
    by_level = {d: [c for c in candidates if c[0] == d] for d in DIFFICULTIES}
    ordered = []
    queues = {d: list(v) for d, v in by_level.items()}
    while any(queues.values()) and len(ordered) < TARGET:
        for d in DIFFICULTIES:
            if queues[d] and len(ordered) < TARGET:
                ordered.append(queues[d].pop(0))

    out = []
    attempt = 0
    while len(out) < TARGET:
        for difficulty, n, si, bi, core in ordered:
            if len(out) >= TARGET:
                break
            sent = sentences[si]
            token = sent["tokens"][bi]
            _, suffix = split_trailing_punct(token)
            sentence_cores = {core_of(t) for t in sent["tokens"]}
            own_pool = sorted({
                core_of(t) for s in sentences for t in s["tokens"]
                if hanzi_count(core_of(t)) and core_of(t) not in sentence_cores
                and core_of(t) != core
            })
            # Les mots soulignés sont les meilleurs leurres.
            own_pool.sort(key=lambda w: 0 if w in {
                core_of(s["tokens"][i]) for s in sentences for i in s["hl"]
            } else 1)
            distractors = pick_distractors(
                rng, core, sentence_cores, own_pool, rule.siblings, difficulty
            )
            if distractors is None:
                continue
            out.append({
                "s": si,
                "b": bi,
                "d": difficulty,
                "o": distractors,
            })
        attempt += 1
        if attempt > 40:
            break
    return out, sentences


def build_order(rule, rng):
    """Exercices « phrase mélangée » : les jetons dans le désordre."""
    sentences = rule.usable()
    order = sorted(
        range(len(sentences)),
        key=lambda i: (len(sentences[i]["tokens"]), i),
    )
    if not order:
        return []

    out = []
    seen = set()
    last = {}
    while len(out) < TARGET:
        progressed = False
        for si in order:
            if len(out) >= TARGET:
                break
            n = len(sentences[si]["tokens"])
            perm = list(range(n))
            for _ in range(40):
                rng.shuffle(perm)
                key = (si, tuple(perm))
                if perm != list(range(n)) and key not in seen and key != last.get(si):
                    break
            else:
                # Très courte phrase : on accepte un ordre déjà vu, mais jamais
                # deux fois de suite.
                for _ in range(40):
                    rng.shuffle(perm)
                    if perm != list(range(n)) and perm != last.get(si):
                        break
                key = (si, tuple(perm))
            seen.add(key)
            last[si] = perm
            out.append({"s": si, "d": min(4, 1 + n // 4), "p": perm})
            progressed = True
        if not progressed:
            break
    return out


def main():
    data = json.loads(RULES.read_text(encoding="utf-8"))
    rules = data["rules"]

    # Lexique : les 11 000 mots HSK + tous les mots déjà découpés.
    for word in json.loads(VOCAB.read_text(encoding="utf-8")):
        hanzi = word.get("hanzi", "")
        if hanzi and HANZI.match(hanzi):
            LEXICON.add(hanzi)
    for rule in rules:
        for block in rule["blocks"]:
            if block["t"] != "examples":
                continue
            for item in block["items"]:
                zh = item.get("zh", "")
                if " " in zh:
                    LEXICON.update(
                        t for t in re.split(r"\s+", zh.strip()) if HANZI.match(t)
                    )
    global MAXLEN
    MAXLEN = max((len(w) for w in LEXICON), default=5)
    pools = sibling_pools(rules)

    out_s, out_t, out_m, out_w = {}, {}, {}, {}
    total_m = total_w = 0
    warnings = []
    for i, raw in enumerate(rules):
        rule = RuleData(raw, pools.get((raw["level"], raw.get("category", "")), set()))
        if not rule.sentences:
            warnings.append(raw["id"])
            continue
        rng = random.Random(f"hskhelp-grammar-{raw['id']}")
        usable = rule.usable()

        # Dictionnaire de jetons de la règle.
        tokens = []
        index = {}
        for sent in usable:
            for token in sent["tokens"]:
                if token not in index:
                    index[token] = len(tokens)
                    tokens.append(token)

        sentences_meta = [
            {
                "k": [index[t] for t in sent["tokens"]],
                "y": sent["y"],
                "f": sent["f"],
            }
            for sent in usable
        ]

        fills, _ = build_fill(rule, rng)
        orders = build_order(rule, rng)

        # Les leurres viennent d'autres règles : ils entrent aussi dans le
        # dictionnaire de jetons de celle-ci.
        for ex in fills:
            for word in ex["o"]:
                if word not in index:
                    index[word] = len(tokens)
                    tokens.append(word)

        out_s[raw["id"]] = sentences_meta
        out_t[raw["id"]] = tokens
        out_m[raw["id"]] = [
            [ex["s"], ex["b"], ex["d"], *[index[d] for d in ex["o"]]]
            for ex in fills
        ]
        out_w[raw["id"]] = [
            [ex["s"], ex["d"], *ex["p"]] for ex in orders
        ]
        total_m += len(fills)
        total_w += len(orders)
        if len(fills) < TARGET or len(orders) < TARGET:
            warnings.append(
                f"{raw['id']} (m={len(fills)}, w={len(orders)})"
            )

    payload = {
        "v": 1,
        "s": out_s,
        "t": out_t,
        "m": out_m,
        "w": out_w,
    }
    OUT.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"{len(rules)} règles, {total_m} « mot manquant », "
          f"{total_w} « phrase mélangée »")
    if warnings:
        print(f"règles incomplètes ({len(warnings)}) : {warnings[:12]}", file=sys.stderr)
    print(f"→ {OUT} ({OUT.stat().st_size / 1024 / 1024:.2f} Mo)")


if __name__ == "__main__":
    main()
