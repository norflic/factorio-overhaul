"""Lot DESIGN-ATTAQUES (7/11) : pire temps de script par tick de chaque grande attaque, lu sur un banc att2-perf lancé avec --seul.

    py -3.9 -B tools/autotest/att2_perf.py <archive du banc att2-perf>

Lit benchmark-stdout.txt (--benchmark-verbose, une ligne par tick, en ns) avec le lecteur d'analyze.py. Fenêtres : témoin 610 à 1 590 (rien),
puis une fenêtre de 1 000 ticks par géant à partir du tick 1 600 (ordre de scenarios/att2-perf.lua). Les ticks multiples de 600 (étalon
machine) sont exclus, comme dans analyze.py --spikes. Rend : max, p99, moyenne de scriptUpdate (ms), et le pire tick.
"""
import gzip
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyze  # noqa: E402

IDS = ["cairn", "stylet", "trombe", "ixion", "tournesol"]


def lire(d, nom):
    p = os.path.join(d, nom)
    if os.path.exists(p):
        return open(p, encoding="utf-8", errors="replace").read()
    if os.path.exists(p + ".gz"):
        return gzip.open(p + ".gz", "rt", encoding="utf-8", errors="replace").read()
    return None


def main():
    d = sys.argv[1]
    out = lire(d, "benchmark-stdout.txt")
    if not out:
        print("benchmark-stdout.txt introuvable")
        return 2
    header, rows = analyze.parse_verbose(out)
    si = header[1:].index("scriptUpdate")
    fen = [("temoin", 610, 1590)] + [(g, 1600 + k * 1000, 1600 + k * 1000 + 999) for k, g in enumerate(IDS)]
    print(f"{'fenetre':10s} {'ticks':>6s} {'max ms':>8s} {'p99 ms':>8s} {'moy ms':>8s}  pire tick")
    for nom, a, b in fen:
        v = [(t, x[si] / 1e6) for t, x in rows if a <= t <= b and t % 600 != 0]
        if not v:
            print(f"{nom:10s} aucun tick")
            continue
        ms = [m for _, m in v]
        tmax, mmax = max(v, key=lambda tv: tv[1])
        print(f"{nom:10s} {len(v):6d} {mmax:8.3f} {analyze.pct(ms, 0.99):8.3f} {sum(ms) / len(ms):8.3f}  {tmax} (+{tmax - a})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
