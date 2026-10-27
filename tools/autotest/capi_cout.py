# -*- coding: utf-8 -*-
"""Lot CAPIB : coût d'une DÉCISION de la capitalisation dans son tick (moteur réel).

Usage : py -3.9 -B tools/autotest/capi_cout.py <archive> [<archive> ...]
Lit benchmark-stdout.txt(.gz) (--benchmark-verbose : temps du script par tick, ns) et les lignes
« [FO-CAPI] <faction> minute M | tick T | ... » (journal du mod). Pour chaque décision au tick T, le temps du script
au tick T est comparé à celui de la pensée suivante de la même faction (T + 300 : même pensée, sans l'étape de
décision ; l'étape 11 du cycle ne lit pas la carte). Écart = coût de la décision (relevé, puis envoi des ordres),
au bruit des autres scripts du même tick près. Rend : nombre de décisions, médiane, p90, max de l'écart et du temps
du tick T, et la part des décisions au-dessus de 2 ms.
Mesure valable seulement banc seul (--seul) ; sinon indicative (les bancs voisins partagent les cœurs, F30).
"""
import gzip
import os
import re
import sys

RE_DEC = re.compile(r"\[FO-CAPI\] (\S+) minute (\d+) \| tick (\d+) \|")


def lines_of(arch, name):
    for n in (name + ".gz", name):
        p = os.path.join(arch, n)
        if os.path.exists(p):
            if n.endswith(".gz"):
                with gzip.open(p, "rt", encoding="utf-8", errors="replace") as fh:
                    for ln in fh:
                        yield ln
            else:
                with open(p, encoding="utf-8", errors="replace") as fh:
                    for ln in fh:
                        yield ln
            return


def pct(v, q):
    if not v:
        return 0.0
    s = sorted(v)
    return s[min(len(s) - 1, int(q * (len(s) - 1) + 0.5))]


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    for arch in argv:
        decisions = []
        for ln in lines_of(arch, "benchmark.log"):
            m = RE_DEC.search(ln)
            if m:
                decisions.append((m.group(1), int(m.group(2)), int(m.group(3))))
        want = set()
        for _, _, t in decisions:
            want.add(t)
            want.add(t + 300)
        header, col, script = None, None, {}
        for ln in lines_of(arch, "benchmark-stdout.txt"):
            if header is None and "wholeUpdate" in ln and "," in ln:
                header = [c for c in ln.strip().split(",") if c != ""]
                col = header.index("scriptUpdate") if "scriptUpdate" in header else None
                continue
            if col is not None and ln.startswith("t"):
                cells = ln.strip().split(",")
                try:
                    tick = int(cells[0][1:])
                except ValueError:
                    continue
                if tick in want:
                    try:
                        script[tick] = int(cells[col]) / 1e6
                    except (ValueError, IndexError):
                        pass
        # La colonne 0 du CSV est « tick » : son index décale celui des valeurs d'une case
        diffs, at = [], []
        for fk, minute, t in decisions:
            if t in script and (t + 300) in script:
                at.append(script[t])
                diffs.append(script[t] - script[t + 300])
        n = len(diffs)
        print("ARCHIVE %s : %d decisions, %d mesurees" % (os.path.basename(os.path.normpath(arch)), len(decisions), n))
        if n:
            print("  temps du script au tick de la decision (ms) : mediane %.3f, p90 %.3f, max %.3f" % (pct(at, 0.5), pct(at, 0.9), max(at)))
            print("  ecart a la pensee suivante (ms)            : mediane %.3f, p90 %.3f, max %.3f ; au-dessus de 2 ms : %d (%.1f %%)" % (
                pct(diffs, 0.5), pct(diffs, 0.9), max(diffs), sum(1 for d in diffs if d > 2.0), 100.0 * sum(1 for d in diffs if d > 2.0) / n))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
