#!/usr/bin/env python3
"""Fabrique les traductions **hors ligne** des significations et de la
grammaire, à l'aide des modèles neuronaux Argos Translate (CTranslate2 +
SentencePiece).

Les services en ligne gratuits (Google, MyMemory, DeepL) se sont révélés trop
limités : quota journalier épuisé, HTTP 429 en rafale, pages de vérification…
Les modèles Argos, eux, sont téléchargés **une seule fois** puis tournent en
local sans aucune limite. L'application, elle, reste 100 % hors ligne.

Modèles utilisés (dossier `ARGOS_DIR`, par défaut /tmp/opencode/argos) :

    en→es, en→pt, en→ru, en→ar, en→hi, en→zh   (significations)
    fr→en                                       (pivot pour la grammaire)

La grammaire est écrite en français ; on la traduit donc de français vers
anglais (modèle `fr_en`), puis de l'anglais vers la langue visée. Les exemples
en caractères chinois présents dans les règles sont **préservés tels quels**.

    python3 tools/build_i18n_local.py vocab
    python3 tools/build_i18n_local.py grammar
    python3 tools/build_i18n_local.py all
"""
import json
import os
import re
import sys
import time
from pathlib import Path

import ctranslate2
import sentencepiece as spm

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "hskhelp" / "assets"
VOCAB = ASSETS / "vocab.json"
GRAMMAR = ASSETS / "grammar.json"
MODELS = Path(os.environ.get("ARGOS_DIR", "/tmp/opencode/argos"))

LANGS = ["es", "ar", "hi", "zh", "ru", "pt"]

# Plages de caractères à ne pas traduire (idéogrammes et ponctuation pleine
# chasse) : les exemples chinois des règles de grammaire doivent rester intacts.
CJK = re.compile(r"[\u3000-\u303f\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff00-\uffef]+")


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def _clauses(text):
    """Découpe une définition en propositions séparées par « ; »."""
    parts = [p.strip() for p in text.split(";")]
    return [p for p in parts if p] or [text.strip()]


class LocalMT:
    """Traducteur local basé sur les modèles Argos."""

    def __init__(self, models_dir=MODELS, threads=None):
        self.dir = Path(models_dir)
        self.threads = threads or max(1, (os.cpu_count() or 4) - 1)
        self._engines = {}

    def _find_model(self, src, dst):
        """Repère le dossier du modèle en lisant les métadonnées."""
        # Cas simple : sous-dossier nommé `src_dst`.
        exact = [p for p in self.dir.glob(f"*/{src}_{dst}") if (p / "model" / "model.bin").exists()]
        if exact:
            return exact[0]
        # Sinon on inspecte chaque `metadata.json`.
        for meta in self.dir.glob("*/*/metadata.json"):
            try:
                data = json.loads(meta.read_text(encoding="utf-8"))
            except Exception:  # noqa: BLE001
                continue
            if data.get("from_code") == src and data.get("to_code") == dst:
                base = meta.parent
                if (base / "model" / "model.bin").exists():
                    return base
        return None

    def _engine(self, src, dst):
        key = (src, dst)
        if key in self._engines:
            return self._engines[key]
        base = self._find_model(src, dst)
        if base is None:
            raise FileNotFoundError(f"modèle {src}→{dst} introuvable dans {self.dir}")
        translator = ctranslate2.Translator(
            str(base / "model"),
            device="cpu",
            intra_threads=self.threads,
            compute_type="int8",
        )
        sp = spm.SentencePieceProcessor(model_file=str(base / "sentencepiece.model"))
        self._engines[key] = (translator, sp)
        log(f"  modèle chargé : {src}→{dst} ({base.name})")
        return self._engines[key]

    def available(self, src, dst):
        return self._find_model(src, dst) is not None

    def clear(self):
        """Libère la mémoire des modèles chargés (la machine est petite)."""
        self._engines.clear()
        import gc

        gc.collect()

    def _raw(self, texts, src, dst, beam=2, batch=64, max_len=512):
        translator, sp = self._engine(src, dst)
        out = []
        for i in range(0, len(texts), batch):
            chunk = [t for t in texts[i:i + batch]]
            tokens = [sp.encode(t, out_type=str) for t in chunk]
            # CTranslate2 refuse les listes de jetons vides.
            safe = [tok if tok else ["▁"] for tok in tokens]
            results = translator.translate_batch(
                safe,
                beam_size=beam,
                max_decoding_length=max_len,
                repetition_penalty=1.2,
            )
            for j, res in enumerate(results):
                if not tokens[j]:
                    out.append("")
                else:
                    text = sp.decode(res.hypotheses[0]).replace("\u2581", " ")
                    out.append(" ".join(text.split()))
        return out

    def translate(self, texts, src, dst, beam=2, max_len=512):
        """Traduit une liste de textes de `src` vers `dst`."""
        return self._raw(list(texts), src, dst, beam=beam, max_len=max_len)

    def translate_pivot(self, texts, src, dst, beam=2, max_len=512):
        """Traduit via l'anglais quand il n'existe pas de modèle direct."""
        if src == dst:
            return list(texts)
        if src != "en" and self.available(src, dst):
            return self._raw(list(texts), src, dst, beam=beam, max_len=max_len)
        mid = (texts if src == "en"
               else self._raw(list(texts), src, "en", beam=beam, max_len=max_len))
        return self._raw(list(mid), "en", dst, beam=beam, max_len=max_len)

    def translate_mixed(self, texts, src, dst, max_len=512):
        """Traduit en préservant les passages en caractères chinois."""
        # On éclate chaque texte en segments (chinois / non chinois).
        plan = []          # pour chaque texte : liste de (est_chinois, fragment)
        pending = []       # fragments non chinois à traduire
        index = []         # (position dans `plan`) des fragments à traduire
        for ti, text in enumerate(texts):
            parts = []
            pos = 0
            for m in CJK.finditer(text):
                if m.start() > pos:
                    parts.append((False, text[pos:m.start()]))
                parts.append((True, m.group(0)))
                pos = m.end()
            if pos < len(text):
                parts.append((False, text[pos:]))
            plan.append(parts)
            for pi, (is_cjk, frag) in enumerate(parts):
                if not is_cjk and frag.strip():
                    index.append((ti, pi))
                    pending.append(frag)
        if pending:
            translated = self.translate_pivot(pending, src, dst, max_len=max_len)
            for (ti, pi), tr in zip(index, translated):
                orig = plan[ti][pi][1]
                # On restitue les espaces de début et de fin du fragment, que
                # le traducteur a pu rogner : sans quoi les exemples chinois
                # se retrouveraient collés au texte traduit.
                lead = orig[: len(orig) - len(orig.lstrip())]
                trail = orig[len(orig.rstrip()):]
                plan[ti][pi] = (False, f"{lead}{tr.strip()}{trail}")
        return ["".join(frag for _, frag in parts).strip() for parts in plan]


# ─────────────────────────────────────────────────────────────── vocabulaire
def save_vocab(vocab):
    VOCAB.write_text(json.dumps(vocab, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def do_vocab(mt, only=None):
    langues = only or LANGS
    vocab = json.loads(VOCAB.read_text(encoding="utf-8"))
    log(f"vocabulaire : {len(vocab)} entrées")
    sources = [e.get("en") or e.get("fr") or "" for e in vocab]
    uniq = sorted({s for s in sources if s})
    log(f"significations uniques : {len(uniq)}")
    pos = sorted({e.get("posEn", "") for e in vocab if e.get("posEn")})
    log(f"natures grammaticales : {len(pos)}")

    for lang in langues:
        if not mt.available("en", lang):
            log(f"  ! pas de modèle en→{lang}, langue ignorée")
            continue
        t0 = time.time()
        # Les définitions longues sont des listes de sens séparées par « ; ».
        # Le modèle les traduit mal d'un bloc (il se répète) : on traduit
        # chaque proposition à part, puis on les recolle avec « ; ».
        clauses = sorted({c for s in uniq for c in _clauses(s)})
        clause_tr = dict(zip(clauses, mt.translate(clauses, "en", lang, max_len=96)))
        table = {s: " ; ".join(clause_tr[c] for c in _clauses(s)) for s in uniq}
        for e, s in zip(vocab, sources):
            if s and s in table:
                e[lang] = table[s]
        if pos:
            pos_tr = dict(zip(pos, mt.translate(pos, "en", lang, max_len=64)))
            for e in vocab:
                p = e.get("posEn", "")
                if p and p in pos_tr:
                    e["pos" + lang.capitalize()] = pos_tr[p]
        save_vocab(vocab)
        log(f"  {lang} : {sum(1 for e in vocab if e.get(lang))} mots traduits en {time.time() - t0:.0f}s")
        mt.clear()  # libère la mémoire avant la langue suivante


# ────────────────────────────────────────────────────────────────── grammaire
def do_grammar(mt, only=None):
    langues = only or LANGS
    grammar = json.loads(GRAMMAR.read_text(encoding="utf-8"))
    log(f"grammaire : {len(grammar)} leçons")
    lesson_titles = sorted({g.get("title", "") for g in grammar if g.get("title")})
    rule_titles = sorted({r.get("title", "") for g in grammar for r in g.get("rules", []) if r.get("title")})
    explanations = sorted({r.get("explanation", "") for g in grammar for r in g.get("rules", []) if r.get("explanation")})
    log(f"  {len(lesson_titles)} titres, {len(rule_titles)} titres de règle, {len(explanations)} explications")

    for lang in langues:
        t0 = time.time()
        lesson_tr = dict(zip(lesson_titles, mt.translate_mixed(lesson_titles, "fr", lang, max_len=256)))  # noqa: E501
        rule_tr = dict(zip(rule_titles, mt.translate_mixed(rule_titles, "fr", lang, max_len=256)))
        expl_tr = dict(zip(explanations, mt.translate_mixed(explanations, "fr", lang, max_len=256)))

        for g in grammar:
            lt = g.get("title", "")
            if lt and lesson_tr.get(lt):
                g.setdefault("titleI18n", {})[lang] = lesson_tr[lt]
            for r in g.get("rules", []):
                rt = r.get("title", "")
                if rt and rule_tr.get(rt):
                    r.setdefault("titleI18n", {})[lang] = rule_tr[rt]
                ex = r.get("explanation", "")
                if ex and expl_tr.get(ex):
                    r.setdefault("explanationI18n", {})[lang] = expl_tr[ex]
        log(f"  grammaire {lang} faite en {time.time() - t0:.0f}s")
        GRAMMAR.write_text(json.dumps(grammar, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        mt.clear()
    log("grammaire mise à jour")


def main():
    argv = sys.argv[1:]
    which = next((a for a in argv if not a.startswith("--")), "all")
    only = None
    for a in argv:
        if a.startswith("--only="):
            only = [x for x in a.split("=", 1)[1].split(",") if x]
    t0 = time.time()
    mt = LocalMT()
    missing = [l for l in LANGS if not mt.available("en", l)]
    if missing:
        log(f"ATTENTION modèles manquants : {missing}")
    if which in ("all", "vocab"):
        do_vocab(mt, only)
    if which in ("all", "grammar"):
        do_grammar(mt, only)
    log(f"terminé en {time.time() - t0:.0f}s")


if __name__ == "__main__":
    main()
