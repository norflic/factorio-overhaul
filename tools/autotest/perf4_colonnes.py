"""Lot PERF4 : tableau PAR COLONNE de --benchmark-verbose all (demande du lead, 5/11) : médiane, p99, p99,9, max et moyenne de chaque
poste du moteur, puis les ticks au-dessus d'un seuil (16 ms par défaut) avec la colonne qui domine, leur phase et leur période.

    PYTHONUTF8=1 py -3.9 -B tools/autotest/perf4_colonnes.py <archive banc.py> [--seuil 16] [--top 40]

- Les ticks sont ceux du JEU (banc sur une sauvegarde : perf3.aligner) ; l'étalon [FO-CALIB] du mod de test (tick % 600) est
  retiré de scriptUpdate et de wholeUpdate ; le rapport du mod de test (tick % 3600) est compté à part.
- Colonne dominante d'un tick : le plus grand des postes FEUILLES (gameUpdate et wholeUpdate, qui les contiennent, exclus ;
  « reste » = wholeUpdate moins la somme des feuilles, s'il domine).
"""
import argparse
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import perf3  # noqa: E402

AGREGATS = ("wholeUpdate", "gameUpdate", "timestamp")


def charger(d):
    with perf3.opn(d, "benchmark-stdout.txt") as f:
        rows = perf3.parse_verbose(f)
    rows = perf3.aligner(rows, d)
    with perf3.opn(d, "benchmark.log") as f:
        calib = perf3.parse_calib(f)
    ms = {}
    for t, r in rows.items():
        c = calib.get(t, 0.0)
        m = {k: v / 1e6 for k, v in r.items() if k != "timestamp"}
        m["scriptUpdate"] = m.get("scriptUpdate", 0.0) - c
        m["wholeUpdate"] = m.get("wholeUpdate", 0.0) - c
        ms[t] = m
    return ms, calib


def stats(v):
    v = sorted(v)
    n = len(v)
    if not n:
        return None
    return {"moy": sum(v) / n, "med": perf3.pct(v, 0.5), "p99": perf3.pct(v, 0.99), "p999": perf3.pct(v, 0.999), "max": v[-1]}


def periode_de(ticks):
    """Période dominante d'une suite de ticks (écart le plus fréquent entre pics successifs, à ±2 ticks) et sa part."""
    if len(ticks) < 3:
        return None, 0.0
    ec = [b - a for a, b in zip(ticks, ticks[1:]) if b - a > 2]
    if not ec:
        return None, 0.0
    c = collections.Counter(ec)
    best, n = None, 0
    for e in c:
        m = sum(c[x] for x in c if abs(x - e) <= 2)
        if m > n or (m == n and best is not None and e < best):
            best, n = e, m
    return best, n / len(ec)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("archive")
    ap.add_argument("--seuil", type=float, default=16.0)
    ap.add_argument("--top", type=int, default=40)
    a = ap.parse_args()
    ms, calib = charger(a.archive)
    ticks = sorted(ms)
    t0 = ticks[0]
    sel = [t for t in ticks if t - t0 >= 60 and t % 3600 != 0]
    banc = [t for t in ticks if t - t0 >= 60 and t % 3600 == 0]
    cols = [k for k in ms[ticks[0]] if k not in ("timestamp",)]
    print("== %s : ticks %d à %d (%d ; %d analysés hors lancement et hors rapport du banc, %d ticks %% 3600 à part) ; étalon %d mesures, médiane %.2f ms"
          % (a.archive, ticks[0], ticks[-1], len(ticks), len(sel), len(banc), len(calib),
             perf3.pct(sorted(calib.values()), 0.5) if calib else 0))
    print("   %-34s %9s %9s %9s %9s %9s" % ("colonne (ms par tick)", "moyenne", "médiane", "p99", "p99,9", "max"))
    rows = []
    for k in cols:
        s = stats([ms[t].get(k, 0.0) for t in sel])
        if s and (s["max"] >= 0.05 or k in ("wholeUpdate", "scriptUpdate", "entityUpdate")):
            rows.append((k, s))
    rows.sort(key=lambda x: -x[1]["moy"])
    for k, s in rows:
        print("   %-34s %9.3f %9.3f %9.2f %9.2f %9.1f" % (k, s["moy"], s["med"], s["p99"], s["p999"], s["max"]))
    vit = 1000.0 / max(1e-9, stats([ms[t]["wholeUpdate"] for t in sel])["moy"]) / 60.0
    print("   vitesse que permettrait wholeUpdate seul (sans rendu) : x%.1f" % vit)
    # ticks au-dessus du seuil (wholeUpdate, étalon retiré)
    feuilles = [k for k in cols if k not in AGREGATS]
    hauts = [t for t in sel if ms[t]["wholeUpdate"] > a.seuil]
    print("   ticks > %g ms (wholeUpdate) : %d sur %d ; par colonne dominante :" % (a.seuil, len(hauts), len(sel)))
    dom = {}
    for t in hauts:
        m = ms[t]
        k = max(feuilles, key=lambda x: m.get(x, 0.0))
        reste = m["wholeUpdate"] - sum(max(0.0, m.get(x, 0.0)) for x in feuilles if x != "gameUpdate")
        dom[t] = "reste" if reste > m.get(k, 0.0) else k
    par = collections.defaultdict(list)
    for t in hauts:
        par[dom[t]].append(t)
    for k in sorted(par, key=lambda x: -len(par[x])):
        ts = par[k]
        e, part = periode_de(ts)
        ph300 = collections.Counter(t % 300 for t in ts).most_common(5)
        ph600 = collections.Counter(t % 600 for t in ts).most_common(3)
        tot = sum(ms[t]["wholeUpdate"] for t in ts)
        print("      %-24s %6d ticks, %8.0f ms en tout, max %7.1f ms ; période %s ; phases %%300 %s ; %%600 %s" % (
            k, len(ts), tot, max(ms[t]["wholeUpdate"] for t in ts),
            ("%d ticks (%.0f %%)" % (e, 100 * part)) if e else "-",
            ", ".join("%d×%d" % x for x in ph300), ", ".join("%d×%d" % x for x in ph600)))
    # groupes de ticks consécutifs au-dessus du seuil (un gel = plusieurs ticks lourds de suite)
    grp, cur = [], []
    for t in hauts:
        if cur and t - cur[-1] <= 2:
            cur.append(t)
        else:
            if cur:
                grp.append(cur)
            cur = [t]
    if cur:
        grp.append(cur)
    gt = [(sum(ms[t]["wholeUpdate"] for t in g), g) for g in grp]
    gt.sort(key=lambda x: -x[0])
    e, part = periode_de([g[0] for _, g in sorted(gt, key=lambda x: x[1][0])])
    print("   gels (ticks > %g ms à 2 ticks près, d'un bloc) : %d ; période des débuts %s ; les %d plus longs :" % (
        a.seuil, len(grp), ("%d ticks (%.0f %%)" % (e, 100 * part)) if e else "-", min(a.top, len(gt))))
    for tot, g in gt[:a.top]:
        print("      t%-8d (%%300 = %3d) %2d tick(s) %8.1f ms : %s" % (g[0], g[0] % 300, len(g), tot, ", ".join(
            "%s %.0f" % (dom[t], ms[t]["wholeUpdate"]) for t in g[:6])))
    if banc:
        s = stats([ms[t]["wholeUpdate"] for t in banc])
        print("   (rapport du mod de test, tick %% 3600 : %d ticks, wholeUpdate moyen %.1f ms, max %.1f : hors analyse)" % (
            len(banc), s["moy"], s["max"]))


if __name__ == "__main__":
    main()
