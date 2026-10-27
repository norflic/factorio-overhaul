# Lot IA3-k : résumé des archives des bancs « comportements visibles » (banc.py --out <archive>).
# Usage : py -3.9 -B tools/autotest/ia3k_bilan.py <dossier d'archives ou archive> [...]
# Pour chaque archive (dossier qui contient banc.txt et benchmark.log.gz) : scénario, graine, code, lignes « FAIT » et
# « BILAN » des journaux [FO-IA3K-*], [FO-CONTENT], [FO-PNJ-REDUIT], [FO-VERIF-GUIDE]. Code de sortie : 0 si tous les
# BILAN lus sont sans ECHEC, 1 sinon, 2 si aucune archive.
import gzip
import os
import re
import sys

TAGS = re.compile(r"\[(FO-IA3K[-A-Z]*|FO-CONTENT|FO-PNJ-REDUIT|FO-VERIF-GUIDE)\]")


def archives(paths):
    out = []
    for p in paths:
        if os.path.isfile(os.path.join(p, "banc.txt")):
            out.append(p)
            continue
        for root, dirs, files in os.walk(p):
            if "banc.txt" in files:
                out.append(root)
    return sorted(set(out))


def lire(path):
    for name in ("benchmark.log.gz", "benchmark.log"):
        f = os.path.join(path, name)
        if os.path.isfile(f):
            op = gzip.open if name.endswith(".gz") else open
            with op(f, "rt", encoding="utf-8", errors="replace") as h:
                return h.read().splitlines()
    return []


def main(argv):
    arcs = archives(argv[1:] or ["."])
    if not arcs:
        print("[IA3K-BILAN] aucune archive")
        return 2
    bad = 0
    for a in arcs:
        banc = open(os.path.join(a, "banc.txt"), encoding="utf-8", errors="replace").read()
        m = re.search(r"nopause (\d+) (\S+)", banc)
        g = re.search(r"graine (\S+)", banc)
        code = re.search(r"code (\d+)", banc)
        print("== %s : %s, %s ticks, graine %s, code %s" % (os.path.relpath(a), m.group(2) if m else "?", m.group(1) if m else "?",
                                                           g.group(1) if g else "?", code.group(1) if code else "?"))
        for line in lire(a):
            if not TAGS.search(line):
                continue
            i = line.find("[FO-")
            txt = line[i:]
            if " FAIT " in txt or "BILAN" in txt:
                print("   " + txt)
                if "BILAN" in txt and re.search(r"[1-9]\d* ECHEC", txt):
                    bad += 1
    print("[IA3K-BILAN] %d archive(s), %d BILAN avec ECHEC" % (len(arcs), bad))
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
