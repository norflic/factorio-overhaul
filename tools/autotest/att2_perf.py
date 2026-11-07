"""Lot DESIGN-ATTAQUES (7/11) : pire temps de script par tick de chaque grande attaque, lu sur un banc att2-perf lancé avec --seul.

    py -3.9 -B tools/autotest/att2_perf.py <archive du banc att2-perf>

Lit benchmark-stdout.txt (--benchmark-verbose, une ligne par tick, en ns) avec le lecteur d'analyze.py, et le journal benchmark.log
([FO-ATT2] ... lance ... frappe au tick T ; ... fin #N (tick T2, ...)). Pour chaque géant : la GRANDE ATTAQUE seule, du lancement (frappe
moins la charge) à la fin lue au journal ; puis toute sa fenêtre (la 1re attaque du géant y reprend après la grande). Fenêtre témoin :
ticks 610 à 1 590, sans rien. Les ticks multiples de 600 (étalon machine) sont exclus, comme dans analyze.py --spikes.
Rend : max, p99, moyenne de scriptUpdate (ms), ticks au-dessus de 1 ms, et le pire tick (décalage depuis la frappe).
"""
import gzip
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyze  # noqa: E402

IDS = ["cairn", "stylet", "trombe", "ixion", "tournesol"]
CHARGE = {"cairn": 90, "stylet": 60, "trombe": 100, "ixion": 120, "tournesol": 150}
FEN = 1200


def lire(d, nom):
    p = os.path.join(d, nom)
    if os.path.exists(p):
        return open(p, encoding="utf-8", errors="replace").read()
    if os.path.exists(p + ".gz"):
        return gzip.open(p + ".gz", "rt", encoding="utf-8", errors="replace").read()
    return None


def ligne(nom, v, ref):
    if not v:
        return "%-18s aucun tick" % nom
    ms = [m for _, m in v]
    tmax, mmax = max(v, key=lambda tv: tv[1])
    n1 = sum(1 for m in ms if m >= 1.0)
    return "%-18s %6d %8.3f %8.3f %8.3f %6d  %d (%+d)" % (nom, len(v), mmax, analyze.pct(ms, 0.99), sum(ms) / len(ms), n1, tmax, tmax - ref)


def main():
    d = sys.argv[1]
    out = lire(d, "benchmark-stdout.txt")
    log = lire(d, "benchmark.log") or ""
    if not out:
        print("benchmark-stdout.txt introuvable")
        return 2
    header, rows = analyze.parse_verbose(out)
    si = header[1:].index("scriptUpdate")
    frappe, fin = {}, {}
    for m in re.finditer(r"\[FO-ATT2\] (\w+) \S+ lance #\d+ .*?frappe au tick (\d+)", log):
        frappe.setdefault(m.group(1), int(m.group(2)))
    for m in re.finditer(r"\[FO-ATT2\] (\w+) \S+ fin #\d+ \(tick (\d+)", log):
        fin.setdefault(m.group(1), int(m.group(2)))

    def ticks(a, b):
        return [(t, x[si] / 1e6) for t, x in rows if a <= t <= b and t % 600 != 0]

    print("%-18s %6s %8s %8s %8s %6s  %s" % ("fenetre", "ticks", "max ms", "p99 ms", "moy ms", ">=1ms", "pire tick (depuis la frappe)"))
    print(ligne("temoin", ticks(610, 1590), 610))
    for k, g in enumerate(IDS):
        a = 1600 + k * FEN
        if g in frappe and g in fin:
            print(ligne(g + " (grande)", ticks(frappe[g] - CHARGE[g], fin[g]), frappe[g]))
        else:
            print("%-18s journal incomplet (frappe %s, fin %s)" % (g + " (grande)", frappe.get(g), fin.get(g)))
        print(ligne(g + " (fenetre)", ticks(a, a + FEN - 1), frappe.get(g, a)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
