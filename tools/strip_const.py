#!/usr/bin/env python3
"""Retire les mots-clés `const` devenus invalides.

`AppColors` passe de constantes compile-time à une palette choisie à
l'exécution (bascule clair/sombre, plusieurs nuances). Toute création
`const` qui référence `AppColors` devient alors une erreur de compilation
(`const_with_non_const`) : ce script les détecte en équilibrant les
parenthèses/acrochets et supprime le `const` concerné.

    python3 tools/strip_const.py            # analyse seule
    python3 tools/strip_const.py --apply    # modifie les fichiers
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGETS = sorted((ROOT / "hskhelp" / "lib").rglob("*.dart")) + sorted(
    (ROOT / "hskhelp" / "test").rglob("*.dart")
)
OPENERS = {"(": ")", "[": "]", "{": "}"}
CLOSERS = {v: k for k, v in OPENERS.items()}


def _string_end(src: str, start: int) -> int:
    """Fin du littéral de chaîne ouvrant à `start` (quote incluse)."""
    quote = src[start]
    i = start + 1
    n = len(src)
    while i < n:
        c = src[i]
        if c == "\\":
            i += 2
            continue
        if c == "$" and i + 1 < n and src[i + 1] == "{":
            # Interpolation `${...}` : on va jusqu'à l'accolade équilibrée.
            depth = 1
            i += 2
            while i < n and depth:
                d = src[i]
                if d == "'" or d == '"':
                    i = _string_end(src, i)
                    continue
                if d == "/" and i + 1 < n and src[i + 1] == "/":
                    nl = src.find("\n", i)
                    i = n if nl < 0 else nl
                    continue
                if d == "{":
                    depth += 1
                elif d == "}":
                    depth -= 1
                i += 1
            continue
        if c == quote:
            return i + 1
        i += 1
    return n


def _mask(src: str):
    """Marque les positions qui sont littéraux de chaîne ou commentaires."""
    mask = bytearray(len(src))  # 0 = code, 1 = chaîne/commentaire
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            nl = src.find("\n", i)
            end = n if nl < 0 else nl
            for k in range(i, end):
                mask[k] = 1
            i = end
        elif c == "/" and i + 1 < n and src[i + 1] == "*":
            close = src.find("*/", i + 2)
            end = n if close < 0 else close + 2
            for k in range(i, end):
                mask[k] = 1
            i = end
        elif c == "r" and i + 1 < n and src[i + 1] in "'\"":
            end = _string_end(src, i + 1)
            for k in range(i, end):
                mask[k] = 1
            i = end
        elif c in "'\"":
            end = _string_end(src, i)
            for k in range(i, end):
                mask[k] = 1
            i = end
        else:
            i += 1
    return mask


def _match(src: str, mask, start: int, opener: str) -> int:
    """Index juste après la parenthèse/acrochette fermante."""
    depth = 0
    i = start
    n = len(src)
    while i < n:
        if not mask[i] and src[i] in OPENERS:
            depth += 1
        elif not mask[i] and src[i] in CLOSERS:
            depth -= 1
            if depth == 0:
                return i + 1
        elif mask[i] and src[i] in "'\"":
            i = _string_end(src, i) - 1
        i += 1
    return n


def _const_expressions(src: str, mask):
    """`(début_du_const, fin_de_l_expression_const)` potentiels."""
    out = []
    for m in re.finditer(r"\bconst\b", src):
        i = m.start()
        if i and (src[i - 1].isalnum() or src[i - 1] in "_$"):
            continue  # en fait un identifiant
        if mask[i]:
            continue
        j = m.end()
        # Espaces puis nom de type facultatif (TextTheme, Map<…>, …).
        while j < len(src) and src[j] in " \t\n\r":
            j += 1
        if j >= len(src) or mask[j]:
            continue
        if src[j].isalpha() or src[j] == "_":
            while j < len(src) and (src[j].isalnum() or src[j] in "_$"):
                j += 1
            while j < len(src) and src[j] in " \t\n\r":
                j += 1
        if j >= len(src) or mask[j]:
            continue
        # Arguments de génériques éventuels : <Widget>[…]
        if src[j] == "<":
            depth = 0
            while j < len(src):
                if mask[j]:
                    j += 1
                    continue
                if src[j] == "<":
                    depth += 1
                elif src[j] == ">":
                    depth -= 1
                    if depth == 0:
                        j += 1
                        break
                j += 1
            while j < len(src) and src[j] in " \t":
                j += 1
        # Une affectation (`const paper = …`) n'est pas une création `const`.
        if j >= len(src) or mask[j] or src[j] not in OPENERS:
            continue
        opener = src[j]
        end = _match(src, mask, j, opener)
        out.append((i, end))
    return out


def process(path: Path, apply: bool) -> int:
    src = path.read_text(encoding="utf-8")
    mask = _mask(src)
    removals = []
    for start, end in _const_expressions(src, mask):
        body = src[start:end]
        if "AppColors." not in body:
            continue
        # On ne supprime que le mot-clé, plus l'espace qui le suit.
        stop = start + 5
        while stop < len(src) and src[stop] in " \t":
            stop += 1
        removals.append((start, stop))
    if not removals:
        return 0
    if apply:
        for start, stop in sorted(removals, reverse=True):
            src = src[:start] + src[stop:]
        path.write_text(src, encoding="utf-8")
    rel = path.relative_to(ROOT)
    for start, _stop in removals:
        line = src.count("\n", 0, start) + 1
        print(f"  {rel}:{line}")
    return len(removals)


def main():
    apply = "--apply" in sys.argv
    total = 0
    for path in TARGETS:
        total += process(path, apply)
    print(f"{total} mot-clé(s) `const` à retirer"
          f"{' (appliqué)' if apply else ' (analyse seule)'}")


if __name__ == "__main__":
    main()
