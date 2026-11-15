#!/usr/bin/env python3
"""Fabrique les traductions des significations (et de la grammaire) pour les
six langues ajoutées aux réglages : espagnol, arabe, hindi, chinois (mandarin),
russe, portugais.

L'application reste 100 % hors ligne : ce script sert uniquement à **fabriquer
les données** une fois pour toutes.

Trois fournisseurs sont interrogés en cascade ; dès que l'un est bloqué
(HTTP 429/403, quota épuisé, page HTML de vérification), il est mis en pause et
le suivant prend le relais :

1. **MyMemory** (`api.mymemory.translated.net`) — robuste, gère les six
   langues cibles, et traduit plusieurs mots d'un coup (un mot par ligne) ;
2. **Google Translate** (`translate_a/t`) — bascule fréquemment en 429, mais
   reprend après une pause ;
3. **DeepL** (`www2.deepl.com/jsonrpc`) — excellente qualité sur es/ar/zh/ru/pt
   (l'hindi n'est pas géré), mais quota serré.

Le travail est mis en cache sur disque (`tools/_trans_cache.json`) : le script
peut être interrompu et relancé sans rien retraduire.

    python3 tools/build_i18n_langs.py vocab
    python3 tools/build_i18n_langs.py grammar
"""
import json
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "hskhelp" / "assets"
VOCAB = ASSETS / "vocab.json"
GRAMMAR = ASSETS / "grammar.json"
CACHE = Path(__file__).resolve().parent / "_trans_cache.json"

LANGS = ["es", "ar", "hi", "zh", "ru", "pt"]

UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
)


# ───────────────────────────────────────────────────────────── cache disque
def load_cache():
    if CACHE.exists():
        try:
            return json.loads(CACHE.read_text(encoding="utf-8"))
        except Exception:  # noqa: BLE001
            return {}
    return {}


def save_cache(cache):
    CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")


def _key(src, lang, text):
    return f"{src}|{lang}|{text}"


# ─────────────────────────────────────────────────────── accès HTTP brut
class ProviderDown(Exception):
    """Le fournisseur est indisponible (blocage, quota, réponse invalide)."""

    def __init__(self, message, cooldown=None):
        super().__init__(message)
        self.cooldown = cooldown


def _request(url, data=None, headers=None, method=None):
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers=headers
        or {
            "User-Agent": UA,
            "Accept": "application/json,text/plain,*/*",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        if exc.code == 429:
            raise ProviderDown("HTTP 429 (débit)", cooldown=10) from exc
        if exc.code in (403, 500, 502, 503, 504):
            raise ProviderDown(f"HTTP {exc.code}", cooldown=30) from exc
        raise ProviderDown(f"HTTP {exc.code}") from exc
    except Exception as exc:  # noqa: BLE001  (timeout, DNS, TLS…)
        raise ProviderDown(str(exc), cooldown=20) from exc


def _http_form(url, data):
    return _request(url, urllib.parse.urlencode(data, doseq=True).encode("utf-8"))


def _http_json(url, obj):
    return _request(
        url,
        json.dumps(obj).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": UA},
    )


def _json(raw):
    try:
        return json.loads(raw)
    except Exception as exc:  # noqa: BLE001
        # Une page HTML (« Just a moment… », « sorry/index ») = blocage.
        raise ProviderDown("réponse non JSON (blocage probable)", cooldown=90) from exc


# ──────────────────────────────────────────────────────────── fournisseurs
class Provider:
    name = "base"
    cooldown = 60
    max_count = 30
    max_bytes = 400

    def translate(self, texts, src, lang):
        raise NotImplementedError

    def translate_long(self, text, src, lang):
        return self.translate([text], src, lang)[0]


class MyMemoryProvider(Provider):
    """API publique MyMemory : un mot par ligne, jusqu'à ~480 octets par appel."""

    name = "mymemory"
    cooldown = 60
    max_count = 40
    max_bytes = 420

    TARGET = {"es": "es", "ar": "ar", "hi": "hi", "zh": "zh-CN", "ru": "ru", "pt": "pt-BR"}

    def translate(self, texts, src, lang):
        q = "\n".join(texts)
        if len(q.encode("utf-8")) > 490:
            raise ProviderDown("mymemory : lot trop volumineux")
        url = "https://api.mymemory.translated.net/get?" + urllib.parse.urlencode(
            {"q": q, "langpair": f"{src}|{self.TARGET.get(lang, lang)}"}
        )
        data = _json(_request(url))
        if data.get("quotaFinished"):
            raise ProviderDown("mymemory : quota épuisé", cooldown=3600)
        tr = (data.get("responseData") or {}).get("translatedText") or ""
        lines = tr.split("\n")
        if len(lines) != len(texts):
            raise ProviderDown("mymemory : nombre de lignes inattendu")
        return [ln.strip() or t for ln, t in zip(lines, texts)]


class GoogleProvider(Provider):
    name = "google"
    cooldown = 90
    max_count = 50
    max_bytes = 2000

    def translate(self, texts, src, lang):
        data = [("client", "gtx"), ("sl", src), ("tl", lang)]
        data += [("q", t) for t in texts]
        res = _json(_http_form("https://translate.googleapis.com/translate_a/t", data))
        if not isinstance(res, list) or len(res) != len(texts):
            raise ProviderDown("google : forme inattendue", cooldown=90)
        out = []
        for t, tr in zip(texts, res):
            if isinstance(tr, list):
                tr = tr[0] if tr else t
            if not isinstance(tr, str) or not tr.strip():
                tr = t
            out.append(tr.strip())
        return out

    def translate_long(self, text, src, lang):
        data = [("client", "gtx"), ("sl", src), ("tl", lang), ("dt", "t"), ("q", text)]
        res = _json(
            _http_form("https://translate.googleapis.com/translate_a/single", data)
        )
        try:
            parts = res[0]
            out = "".join(seg[0] for seg in parts if seg and seg[0])
        except Exception as exc:  # noqa: BLE001
            raise ProviderDown("google single : forme inattendue") from exc
        return out or text


class DeepLProvider(Provider):
    """Point d'accès web de DeepL : très bonne qualité, quota serré."""

    name = "deepl"
    cooldown = 600
    max_count = 25
    max_bytes = 1200

    TARGET = {"es": "ES", "ar": "AR", "zh": "ZH", "ru": "RU", "pt": "PT-BR"}
    SOURCE = {"en": "EN", "fr": "FR"}

    def translate(self, texts, src, lang):
        target = self.TARGET.get(lang)
        if not target:
            # L'hindi n'est pas pris en charge : on n'y revient pas.
            raise ProviderDown("deepl : langue non gérée", cooldown=10 ** 9)
        body = {
            "jsonrpc": "2.0",
            "method": "LMT_handle_texts",
            "params": {
                "texts": [{"text": t, "requestAlternatives": 0} for t in texts],
                "splitting": "newlines",
                "lang": {
                    "source_lang_user_selected": self.SOURCE.get(src, src.upper()),
                    "target_lang": target,
                },
                "timestamp": int(time.time() * 1000),
            },
            "id": random.randint(100000, 9999999),
        }
        data = _json(_http_json("https://www2.deepl.com/jsonrpc", body))
        if data.get("error"):
            msg = str(data["error"].get("message", ""))
            if "Too many requests" in msg:
                raise ProviderDown("deepl : trop de requêtes", cooldown=600)
            raise ProviderDown(f"deepl : {msg}", cooldown=1800)
        try:
            out = [t["text"].strip() for t in data["result"]["texts"]]
        except Exception as exc:  # noqa: BLE001
            raise ProviderDown("deepl : forme inattendue") from exc
        if len(out) != len(texts):
            raise ProviderDown("deepl : longueur inattendue")
        return [o or t for o, t in zip(out, texts)]


# ──────────────────────────────────────────────── traducteur multi-sources
class MultiTranslator:
    def __init__(self, providers, verbose=True, delay=0.6):
        self.providers = providers
        self.verbose = verbose
        self.delay = delay
        self.down = {}
        self.stats = {p.name: 0 for p in providers}

    def _log(self, msg):
        if self.verbose:
            print(msg, file=sys.stderr, flush=True)

    def _available(self):
        now = time.time()
        return [p for p in self.providers if self.down.get(p.name, 0) <= now]

    def _batch(self, texts):
        max_count = min(p.max_count for p in self.providers)
        max_bytes = min(p.max_bytes for p in self.providers)
        batches, cur, size = [], [], 0
        for t in texts:
            b = len(t.encode("utf-8")) + 1
            if cur and (len(cur) >= max_count or size + b > max_bytes):
                batches.append(cur)
                cur, size = [], 0
            cur.append(t)
            size += b
        if cur:
            batches.append(cur)
        return batches

    def _try_batch(self, texts, src, lang):
        for _ in range(40):
            for p in self._available():
                try:
                    res = p.translate(texts, src, lang)
                    if len(res) != len(texts):
                        raise ProviderDown(f"{p.name} : longueur inattendue")
                    self.stats[p.name] += 1
                    # Réussi : on redescend doucement vers le débit de pointe.
                    self.delay = max(0.45, self.delay * 0.97)
                    return res
                except ProviderDown as exc:
                    cd = exc.cooldown or p.cooldown
                    self.down[p.name] = time.time() + cd
                    # Bloqué : on ralentit pour ne pas insister.
                    self.delay = min(4.0, self.delay * 1.6)
                    self._log(
                        f"      ! {p.name} : {exc} (pause {cd}s, débit {self.delay:.2f}s)"
                    )
            if self.down:
                wait = min(self.down.values()) - time.time()
                time.sleep(max(1.0, min(wait, 20.0)))
        raise RuntimeError("aucun fournisseur de traduction disponible")

    def _try_long(self, text, src, lang):
        """Comme _try_batch, mais pour un texte long (endpoint dédié)."""
        while True:
            for p in self._available():
                try:
                    res = p.translate_long(text, src, lang)
                    if not isinstance(res, str) or not res.strip():
                        raise ProviderDown(f"{p.name} : réponse vide")
                    self.stats[p.name] = self.stats.get(p.name, 0) + 1
                    return res
                except ProviderDown as exc:
                    cd = exc.cooldown or p.cooldown
                    self.down[p.name] = time.time() + cd
                    self._log(f"    ! {p.name} indisponible ({exc}) → pause {cd}s")
            if self.down:
                wait = min(self.down.values()) - time.time()
                time.sleep(max(1.0, min(wait, 20.0)))

    def translate_many(self, texts, src, lang, cache, label=""):
        results = {}
        for t in texts:
            k = _key(src, lang, t)
            if k in cache:
                results[t] = cache[k]

        missing = [t for t in texts if t not in results]
        batches = self._batch(missing)
        for i, batch in enumerate(batches):
            try:
                res = self._try_batch(batch, src, lang)
            except RuntimeError:
                res = [self._try_batch([t], src, lang)[0] for t in batch]
            for t, tr in zip(batch, res):
                cache[_key(src, lang, t)] = tr
                results[t] = tr
            if i % 10 == 0:
                save_cache(cache)
                self._log(f"  {label} lot {i + 1}/{len(batches)}")
            time.sleep(self.delay)
        save_cache(cache)
        return results

    def translate_long(self, texts, src, lang, cache, label=""):
        results = {}
        missing = []
        for t in texts:
            k = _key(src, lang, t)
            if k in cache:
                results[t] = cache[k]
            else:
                missing.append(t)
        for i, text in enumerate(missing):
            results[text] = self._try_long(text, src, lang)
            if i % 15 == 0:
                save_cache(cache)
                self._log(f"  {label} {i + 1}/{len(missing)}")
            time.sleep(self.delay)
        save_cache(cache)
        return results


# ────────────────────────────────────────────────────────────── programmes
def save_vocab(vocab):
    VOCAB.write_text(
        json.dumps(vocab, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


def do_vocab(mt):
    cache = load_cache()
    vocab = json.loads(VOCAB.read_text(encoding="utf-8"))
    print(f"vocabulaire : {len(vocab)} entrées", file=sys.stderr)

    sources = [e.get("en") or e.get("fr") or "" for e in vocab]
    uniq = sorted({s for s in sources if s})
    print(f"significations uniques : {len(uniq)}", file=sys.stderr)

    for lang in LANGS:
        print(f"→ significations {lang}", file=sys.stderr)
        table = mt.translate_many(list(uniq), "en", lang, cache, label=f"mots {lang}")
        for e, s in zip(vocab, sources):
            if s and table.get(s):
                e[lang] = table[s]
        save_vocab(vocab)
        print(
            f"  {lang} : {sum(1 for e in vocab if e.get(lang))} mots traduits",
            file=sys.stderr,
        )

    pos = sorted({e.get("posEn", "") for e in vocab if e.get("posEn")})
    print(f"natures grammaticales : {len(pos)}", file=sys.stderr)
    for lang in LANGS:
        table = mt.translate_many(pos, "en", lang, cache, label=f"pos {lang}")
        for e in vocab:
            p = e.get("posEn", "")
            if p and table.get(p):
                e["pos" + lang.capitalize()] = table[p]
        save_vocab(vocab)
        print(f"  pos {lang} fait", file=sys.stderr)

    print(f"fournisseurs : {mt.stats}", file=sys.stderr)


def do_grammar(mt):
    cache = load_cache()
    grammar = json.loads(GRAMMAR.read_text(encoding="utf-8"))
    print(f"grammaire : {len(grammar)} leçons", file=sys.stderr)

    lesson_titles = sorted({g.get("title", "") for g in grammar if g.get("title")})
    rule_titles = sorted(
        {r.get("title", "") for g in grammar for r in g.get("rules", []) if r.get("title")}
    )
    explanations = sorted(
        {
            r.get("explanation", "")
            for g in grammar
            for r in g.get("rules", [])
            if r.get("explanation")
        }
    )
    print(
        f"  {len(lesson_titles)} titres de leçon, {len(rule_titles)} titres de règle, "
        f"{len(explanations)} explications",
        file=sys.stderr,
    )

    lesson_tr, rule_tr, expl_tr = {}, {}, {}
    for lang in LANGS:
        print(f"→ titres {lang}", file=sys.stderr)
        lesson_tr[lang] = mt.translate_many(lesson_titles, "fr", lang, cache, f"leçons {lang}")
        rule_tr[lang] = mt.translate_many(rule_titles, "fr", lang, cache, f"règles {lang}")

    for lang in LANGS:
        print(f"→ explications {lang}", file=sys.stderr)
        expl_tr[lang] = mt.translate_long(explanations, "fr", lang, cache, f"expl {lang}")

    for g in grammar:
        lt = g.get("title", "")
        if lt and any(lesson_tr[l].get(lt) for l in LANGS):
            g["titleI18n"] = {l: lesson_tr[l][lt] for l in LANGS if lesson_tr[l].get(lt)}
        for r in g.get("rules", []):
            rt = r.get("title", "")
            if rt and any(rule_tr[l].get(rt) for l in LANGS):
                r["titleI18n"] = {l: rule_tr[l][rt] for l in LANGS if rule_tr[l].get(rt)}
            ex = r.get("explanation", "")
            if ex and any(expl_tr[l].get(ex) for l in LANGS):
                r["explanationI18n"] = {
                    l: expl_tr[l][ex] for l in LANGS if expl_tr[l].get(ex)
                }

    GRAMMAR.write_text(
        json.dumps(grammar, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"grammaire mise à jour — fournisseurs : {mt.stats}", file=sys.stderr)


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    mt = MultiTranslator([MyMemoryProvider(), GoogleProvider(), DeepLProvider()])
    if which in ("all", "vocab"):
        do_vocab(mt)
    if which in ("all", "grammar"):
        do_grammar(mt)


if __name__ == "__main__":
    main()
