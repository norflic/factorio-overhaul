#!/usr/bin/env python
"""Lot AMELIORATION-CONTINUE : plaques par minute (lignes [FO-FONCTION] « prod minute N | equipe | ... plaques_min=X ») d'une ou deux parties,
moyenne par tranche de 20 min et par equipe. Sert a verifier qu'un lot de tapis plus grand ne baisse pas le debit de plaques.

    PYTHONUTF8=1 py -3.9 -B tools/autotest/amelioration_continue_plaques.py <journal> [<journal de comparaison>]
"""
import gzip
import re
import sys

PROD = re.compile(r"\[FO-FONCTION\] prod minute (\d+) \| ([^|]+?) \|.*? plaques_min=([0-9.]+)")


def lire(path):
    op = gzip.open if path.endswith(".gz") else open
    with op(path, "rt", encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def tranches(path):
    out = {}
    for ln in lire(path):
        m = PROD.search(ln)
        if m:
            minute, team, v = int(m.group(1)), m.group(2).strip(), float(m.group(3))
            out.setdefault(team, {}).setdefault(minute // 20, []).append(v)
    return out


def main():
    paths = sys.argv[1:3]
    if not paths:
        print(__doc__)
        return 2
    res = [tranches(p) for p in paths]
    teams = sorted(set(t for r in res for t in r))
    for t in teams:
        print("== %s" % t)
        bins = sorted(set(b for r in res for b in r.get(t, {})))
        for b in bins:
            cells = []
            for r in res:
                v = r.get(t, {}).get(b)
                cells.append("%8.1f (n=%d)" % (sum(v) / len(v), len(v)) if v else "       -        ")
            print("  %3d-%3d min : %s" % (b * 20, b * 20 + 20, "  |  ".join(cells)))
        tot = []
        for r in res:
            v = [x for l in r.get(t, {}).values() for x in l]
            tot.append("%8.1f" % (sum(v) / len(v)) if v else "       -")
        print("  moyenne     : %s" % "  |  ".join(tot))
    return 0


if __name__ == "__main__":
    sys.exit(main())
