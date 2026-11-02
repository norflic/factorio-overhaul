"""Lot RB-FLUIDE : mesure de la recherche impayable sur un journal de partie (benchmark.log ou factorio.log).

Par faction : technologies FINIES, recherches COMMENCEES, plus longue durée sur une même recherche (du début à l'arrêt, au changement ou à la fin de
la partie), arrêts de la garde, retours. Usage : py -3.9 tools/autotest/impayable_mesures.py <journal[.gz]> [--fin <minutes>]
"""
import gzip
import re
import sys

START = re.compile(r"\[FO-IA3C\] (\w+) : recherche '([^']+)' commencee .* a ([\d.]+) min")
DONE = re.compile(r"\[FO-IA3C\] (\w+) : recherche '([^']+)' terminee a ([\d.]+) min")
STALL = re.compile(r"\[FO-CERVEAU\] (\w+) : recherche '([^']+)' sans progres")
BACK = re.compile(r"\[FO-CERVEAU\] (\w+) : rien d'autre de payable : la recherche '([^']+)' revient")
ABANDON = re.compile(r"\[FO-CERVEAU\] (\w+) : but '([^']+)' abandonne")


def main():
    path = sys.argv[1]
    fin = None
    if "--fin" in sys.argv:
        fin = float(sys.argv[sys.argv.index("--fin") + 1])
    op = gzip.open if path.endswith(".gz") else open
    teams = {}
    with op(path, "rt", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            for rx, kind in ((START, "start"), (DONE, "done"), (STALL, "stall"), (BACK, "back"), (ABANDON, "abandon")):
                m = rx.search(line)
                if not m:
                    continue
                t = teams.setdefault(m.group(1), {"starts": [], "done": [], "stall": 0, "back": 0, "abandon": 0, "last": 0.0})
                if kind == "start":
                    t["starts"].append((float(m.group(3)), m.group(2)))
                    t["last"] = max(t["last"], float(m.group(3)))
                elif kind == "done":
                    t["done"].append((float(m.group(3)), m.group(2)))
                    t["last"] = max(t["last"], float(m.group(3)))
                else:
                    t[kind] += 1
    if not teams:
        print("[IMPAYABLE] aucune ligne de recherche lue")
        return 1
    for key in sorted(teams):
        t = teams[key]
        end = fin if fin is not None else t["last"]
        durs = []
        starts = t["starts"]
        for i, (a, name) in enumerate(starts):
            b = starts[i + 1][0] if i + 1 < len(starts) else end
            durs.append((max(0.0, b - a), name))
        longest = max(durs) if durs else (0.0, "-")
        print("[IMPAYABLE] %-8s : finies %3d, commencees %3d, plus longue sur une meme recherche %6.1f min ('%s'), arrets %d, retours %d, abandons %d" % (
            key, len(t["done"]), len(starts), longest[0], longest[1], t["stall"], t["back"], t["abandon"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
