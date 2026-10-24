"""Lot MOD-0 (24/10) : lecture d'un passage du scénario mod0-risques (fo-autotest\ ou son archive).

    py -3.9 tools/autotest/mod0/analyse.py "<racine>\\fo-autotest"

Imprime : BILAN, lignes VERDICT ; coûts des profils (COUT : durée totale et par appel, en µs) ; temps moyen par
tick (wholeUpdate, entityUpdate, scriptUpdate, electricNetworkUpdate) des fenêtres AVANT (ticks 700 à 999 : 1 100
machines sans balise) et APRÈS (1 300 à 1 599 : les mêmes avec 1 100 balises cachées) ; tailles des sauvegardes
mod0-995 et mod0-1295 (level.dat non compressé) si le moteur les a écrites. Valeurs BRUTES (étalon non appliqué).
"""
import os
import re
import statistics
import sys
import zipfile

AVANT = (700, 1000)
APRES = (1300, 1600)
COLS = ("wholeUpdate", "entityUpdate", "scriptUpdate", "electricNetworkUpdate")


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
        if "[FO-MOD0-RISQUES]" in l and ("BILAN" in l or "VERDICT" in l or "ECHEC" in l):
            print(l.split("[FO-MOD0-RISQUES]", 1)[1].strip())
    print("--- coûts (LuaProfiler, durée totale ; par appel = totale / n)")
    for l in log.splitlines():
        if " COUT\t" in l:
            m = re.search(r"COUT\t(.*?)\tn=(\d+)\t.*?([\d.]+)ms", l)
            if m:
                lab, n, ms = m.group(1), int(m.group(2)), float(m.group(3))
                print("  %-62s n=%5d  %9.3f ms  %8.3f µs/appel" % (lab, n, ms, 1000.0 * ms / n))
    out = os.path.join(d, "benchmark-stdout.txt")
    if os.path.exists(out):
        header, rows = verbose(lire(out))
        if header:
            cols = header[1:]
            print("--- temps par tick (moyenne, médiane ; ms)")
            for nom, (a, b) in (("AVANT (sans balise)", AVANT), ("APRES (1 100 balises)", APRES)):
                sel = [v for t, v in rows if a <= t < b]
                parts = []
                for c in COLS:
                    if c in cols and sel:
                        i = cols.index(c)
                        xs = [v[i] / 1e6 for v in sel]
                        parts.append("%s %.4f / %.4f" % (c, statistics.mean(xs), statistics.median(xs)))
                print("  %-24s %d ticks : %s" % (nom, len(sel), " ; ".join(parts)))
    saves = os.path.join(d, "write", "saves")
    for n in ("_autosave-mod0-995.zip", "_autosave-mod0-1295.zip"):
        p = os.path.join(saves, n)
        if os.path.exists(p):
            with zipfile.ZipFile(p) as z:
                lvl = [i for i in z.infolist() if i.filename.endswith("level.dat") or "level.dat" in i.filename]
                tot = sum(i.file_size for i in lvl)
            print("  sauvegarde %s : zip %d o, level.dat* non compressé %d o" % (n, os.path.getsize(p), tot))
        else:
            print("  sauvegarde %s : absente" % n)


if __name__ == "__main__":
    sys.exit(main())
