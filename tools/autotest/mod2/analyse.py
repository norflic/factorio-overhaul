"""Lot MOD-2 (25/10) : lecture d'un passage du scénario mod2-lots (fo-autotest\\ ou son archive). Copie adaptée de
tools/autotest/mod1/analyse.py (lot MOD-1).

    py -3.9 tools/autotest/mod2/analyse.py "<racine>\\fo-autotest"

Imprime : BILAN et ECHEC, lignes MESURE et STATS ; coûts des profils (COUT : durée totale et par appel, en µs) ; temps
moyen par tick (wholeUpdate, entityUpdate, scriptUpdate) des fenêtres du bloc F de 1 000 machines :
  AVANT  (ticks 1 100 à 1 399) : 1 000 machines suivies au lot 1, sans module ;
  VAGUE  (ticks 1 401 à 1 730) : 5 × P10 posés par script au tick 1 400, chaque machine relue une fois par le balayage
                                 (balise créée, modules cachés écrits) et basculée au lot 10 (set_recipe) ;
  APRES  (ticks 1 750 à 1 999) : régime établi (lot 10 tenu, rien ne change).
Les autres cellules (A à H) sont nourries par le script du banc à chaque tick, dans les trois fenêtres : leur coût est
commun. Valeurs BRUTES (étalon non appliqué ; PC partagé avec d'autres bancs).
"""
import os
import re
import statistics
import sys

FENETRES = (("AVANT (1 000 machines au lot 1)", 1100, 1400), ("VAGUE (balise + bascule au lot 10)", 1401, 1731),
            ("APRES (lot 10, regime etabli)", 1750, 2000))
COLS = ("wholeUpdate", "entityUpdate", "scriptUpdate")
TAG = "[FO-MOD2-LOTS]"


def lire(p):
    with open(p, encoding="utf-8", errors="replace") as f:
        return f.read()


def verbose(text):
    header, rows = None, []
    for line in text.splitlines():
        line = line.strip()
        if header is None and "wholeUpdate" in line and "," in line:
            header = [c for c in line.split(",") if c != ""]
            continue
        if header and line.startswith("t") and "," in line:
            cells = [c for c in line.split(",") if c != ""]
            try:
                tick = int(cells[0][1:])
            except ValueError:
                continue
            vals = []
            for c in cells[1:]:
                try:
                    vals.append(int(c))
                except ValueError:
                    vals.append(0)
            rows.append((tick, vals))
    return header, rows


def main():
    d = sys.argv[1]
    log = lire(os.path.join(d, "benchmark.log"))
    for l in log.splitlines():
        if TAG in l and ("BILAN" in l or "ECHEC" in l or "MESURE" in l or "STATS" in l):
            print(l.split(TAG, 1)[1].strip())
    for l in log.splitlines():
        for tag in ("[FO-MODMULT]", "[FO-LOTS] mise"):
            if tag in l:
                print(l[l.index(tag):].strip())
    print("--- coûts (LuaProfiler, durée totale ; par appel = totale / n)")
    for src in ("create.log", "benchmark.log"):
        p = os.path.join(d, src)
        if not os.path.exists(p):
            continue
        for l in lire(p).splitlines():
            if " COUT\t" in l:
                m = re.search(r"COUT\t(.*?)\tn=(\d+)\t.*?([\d.]+)ms", l)
                if m:
                    lab, n, ms = m.group(1), int(m.group(2)), float(m.group(3))
                    print("  [%s] %-70s n=%5d  %9.3f ms  %8.3f µs/appel" % (src, lab, n, ms, 1000.0 * ms / n))
    out = os.path.join(d, "benchmark-stdout.txt")
    if os.path.exists(out):
        header, rows = verbose(lire(out))
        if header:
            cols = header[1:]
            print("--- temps par tick (moyenne / médiane / p99 ; ms)")
            for nom, a, b in FENETRES:
                sel = [v for t, v in rows if a <= t < b]
                parts = []
                for c in COLS:
                    if c in cols and sel:
                        i = cols.index(c)
                        xs = sorted(v[i] / 1e6 for v in sel)
                        p99 = xs[min(len(xs) - 1, int(0.99 * len(xs)))]
                        parts.append("%s %.4f / %.4f / %.4f" % (c, statistics.mean(xs), statistics.median(xs), p99))
                print("  %-40s %d ticks : %s" % (nom, len(sel), " ; ".join(parts)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
