# -*- coding: utf-8 -*-
"""Lot CAPITAL, correction après revue : deux archives de banc rendent-elles le MÊME journal de décisions ?

Usage : py -3.9 -B tools/autotest/capital_egal.py <archive A> <archive B> [--tag-a FO-X --tag-b FO-Y]
Lignes comparées : celles de benchmark.log(.gz) qui portent une balise [FO-...] du mod ou du scénario, sans l'horodatage
ni l'origine « Script @__mod__/fichier.lua:ligne: » (les numéros de ligne changent avec le code) ; écartées : les
balises de MESURE de temps et du banc ([FO-CALIB], [FO-BENCH], [FO-AUTOTEST] : source, version, durées ; profileur
« Duration ») ; les lignes [FO-CAPITAL] sont comparées à part (leur suite doit être identique aussi) ; le contrôle
« reglage fo-war-capital » d'une variante (create.log) est retiré du BILAN de A. --tag-a/--tag-b : la balise du scénario
de A est récrite en celle de B (variante greffée : [FO-CAPITAL-VERIF-GUIDE] -> [FO-VERIF-GUIDE]). Rend 0 si les suites
sont identiques, 1 sinon (première différence affichée).
"""
import gzip
import os
import re
import sys

SKIP = ("[FO-CALIB]", "[FO-BENCH]", "[FO-AUTOTEST]")
PREFIX = re.compile(r"^\s*[\d.]+ Script @__[^_]+(?:_[^_]+)*__/[^:]+:\d+: ")


def lines(arch, tag_from=None, tag_to=None):
    p = os.path.join(arch, "benchmark.log")
    if os.path.exists(p + ".gz"):
        f = gzip.open(p + ".gz", "rt", encoding="utf-8", errors="replace")
    else:
        f = open(p, "r", encoding="utf-8", errors="replace")
    out, cap = [], []
    with f:
        for raw in f:
            if "[FO-" not in raw:
                continue
            s = PREFIX.sub("", raw.rstrip("\n"))
            if s == raw.rstrip("\n"):
                s = re.sub(r"^\s*[\d.]+ ", "", s)
            if any(t in s for t in SKIP) or "Duration" in s:
                continue
            if "[FO-CAPITAL]" in s:
                cap.append(s)
                continue
            if tag_from:
                s = s.replace("[" + tag_from + "]", "[" + tag_to + "]")
            out.append(s)
    return out, cap


def main(a):
    args = [x for x in a if not x.startswith("--")]
    ta = tb = None
    if "--tag-a" in a:
        ta = a[a.index("--tag-a") + 1]
        tb = a[a.index("--tag-b") + 1]
        args = [x for x in args if x not in (ta, tb)]
    A, B = args[0], args[1]
    la, ca = lines(A, ta, tb)
    lb, cb = lines(B)
    # Contrôles ajoutés par la variante (réglage écrit) : retirés de A avant comparaison.
    extra = [s for s in la if "reglage fo-war-capital" in s]
    # Le contrôle du réglage est écrit à l'init (création de la carte) : sa ligne est dans create.log, pas dans
    # benchmark.log, mais il compte au BILAN du benchmark (résultats rangés dans global).
    cpath = os.path.join(A, "create.log")
    if os.path.exists(cpath):
        with open(cpath, "r", encoding="utf-8", errors="replace") as fc:
            for raw in fc:
                if "reglage fo-war-capital" in raw and " OK " in raw:
                    extra.append(raw.strip())
                    print("controle du reglage (create.log) : " + PREFIX.sub("", raw.strip())[:160])
    la = [s for s in la if "reglage fo-war-capital" not in s]
    # BILAN : le nombre d'OK de la variante compte ses contrôles en plus.
    def norm_bilan(s, k):
        m = re.search(r"BILAN : (\d+) OK", s)
        return s.replace(m.group(0), "BILAN : %d OK" % (int(m.group(1)) - k)) if m else s
    la = [norm_bilan(s, len(extra)) if " BILAN : " in s else s for s in la]
    print("A %s : %d lignes comparees, %d ligne(s) [FO-CAPITAL], %d controle(s) du reglage retire(s)" % (
        os.path.basename(A), len(la), len(ca), len(extra)))
    print("B %s : %d lignes comparees, %d ligne(s) [FO-CAPITAL]" % (os.path.basename(B), len(lb), len(cb)))
    print("lignes [FO-CAPITAL] : %s" % ("IDENTIQUES" if ca == cb else "DIFFERENTES"))
    n = min(len(la), len(lb))
    for i in range(n):
        if la[i] != lb[i]:
            print("PREMIERE DIFFERENCE a la ligne %d :\n  A: %s\n  B: %s" % (i + 1, la[i][:300], lb[i][:300]))
            same = sum(1 for x, y in zip(la, lb) if x == y)
            print("lignes egales a la meme place : %d sur %d" % (same, n))
            return 1
    if len(la) != len(lb):
        print("DIFFERENCE : longueurs %d et %d (prefixe commun identique)" % (len(la), len(lb)))
        return 1
    print("IDENTIQUES : %d lignes" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
