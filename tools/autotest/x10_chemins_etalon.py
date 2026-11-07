"""Lot X10-CHEMINS, lecture de l'étalonnage E-CH1 (scénario x10-chemins-etalon) : coût d'une demande de chemin par classe.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/x10_chemins_etalon.py <archive> [<archive> ...]

Pour chaque phase (ligne « PHASE <rang>:<nom> debut T0 fin-emission T1 fin T2 ... » du journal) : pathFinder moyen du moteur
(--benchmark-verbose) sur les ticks [T0, T2], moins la moyenne des phases de repos ; rapporté aux demandes finies, cela donne
des µs de pathFinder par demande. Les deux tours d'une même classe sont donnés à part, puis leur moyenne (le bruit se lit sur
l'écart entre les deux tours). Une mesure de TEMPS ne vaut qu'avec --seul (CLAUDE.md, interdit n° 4).
"""
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import perf3  # noqa: E402

RE_PH = re.compile(r"PHASE (\d+):(\S+) debut (\d+) fin-emission (\d+) fin (\d+) emises (\d+) ok (\d+) echec (\d+) retry (\d+) latence ([0-9.]+) points ([0-9.]+)")
COLS = ("pathFinder", "entityUpdate", "scriptUpdate")


RE_PP = re.compile(r"PHASE (\d+):(\S+) debut (\d+) fin (\d+) persos (\d+)(.*)$")
PCOLS = ("entityUpdate", "particleUpdate", "pathFinder", "scriptUpdate", "gameUpdate")


def persos(arch, lines, rows):
    """E-CH2 (scénario x10-pnj-etalon) : µs par personnage et par état, phase moins « aucun »."""
    phases = []
    for line in lines:
        m = RE_PP.search(line)
        if m:
            g = m.groups()
            phases.append({"i": int(g[0]), "nom": g[1], "t0": int(g[2]), "t1": int(g[3]), "n": int(g[4]), "reste": g[5].strip()})
    if not phases:
        return False

    def moy(col, a, b):
        v = [rows[t][col] / 1e6 for t in range(a + 20, b + 1) if t in rows and col in rows[t]]  # 20 ticks d'entrée retirés
        return sum(v) / len(v) if v else 0.0
    base = next((p for p in phases if p["nom"] == "aucun"), None)
    if not base:
        print("  pas de phase « aucun » : pas de base")
        return True
    b = {c: moy(c, base["t0"], base["t1"]) for c in PCOLS}
    print("  base « aucun » : %s" % ", ".join("%s %.4f" % (c, b[c]) for c in PCOLS))
    n = max(p["n"] for p in phases)
    print("  %-16s %s   (µs par personnage et par tick ; %d personnages)" % ("phase", "  ".join("%14s" % c for c in PCOLS), n))
    for p in phases:
        if p["nom"] == "aucun":
            continue
        vals = [(moy(c, p["t0"], p["t1"]) - b[c]) * 1000 / n for c in PCOLS]
        print("  %-16s %s   %s" % ("%d:%s" % (p["i"], p["nom"]), "  ".join("%14.2f" % v for v in vals), p["reste"]))
    return True


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    for arch in sys.argv[1:]:
        with perf3.opn(arch, "benchmark.log") as f:
            lines = f.readlines()
        phases = []
        for line in lines:
            m = RE_PH.search(line)
            if m:
                g = m.groups()
                phases.append({"i": int(g[0]), "nom": g[1], "t0": int(g[2]), "t1": int(g[3]), "t2": int(g[4]), "emises": int(g[5]),
                               "ok": int(g[6]), "echec": int(g[7]), "retry": int(g[8]), "lat": float(g[9]), "pts": float(g[10])})
        with perf3.opn(arch, "benchmark-stdout.txt") as f:
            rows = perf3.aligner(perf3.parse_verbose(f), arch)
        calib = perf3.parse_calib(lines)
        n_bad, n_tot = perf3.controle_etalon(rows, calib)
        print("== %s : %d phase(s) ; alignement de l'étalon : %d tick(s) faux sur %d" % (arch, len(phases), n_bad, n_tot))
        etal = sorted(calib.values())
        if etal:
            print("  étalon [FO-CALIB] médiane %.2f ms (passage valide si <= 2,45 avec --seul)" % etal[len(etal) // 2])
        if persos(arch, lines, rows):
            continue

        def moy(col, a, b):
            v = [rows[t][col] / 1e6 for t in range(a, b + 1) if t in rows and col in rows[t]]
            return (sum(v) / len(v), len(v)) if v else (0.0, 0)
        repos = [p for p in phases if p["nom"] == "repos"]
        base = {}
        for col in COLS:
            vals = [moy(col, p["t0"], p["t2"])[0] for p in repos]
            base[col] = sum(vals) / len(vals) if vals else 0.0
        print("  repos : %s" % ", ".join("%s %.4f ms/tick" % (c, base[c]) for c in COLS))
        print("  %-14s %6s %5s %6s %7s %8s %9s %11s %11s" % ("phase", "ticks", "finies", "echecs", "latence", "points", "pF ms/t", "pF µs/dem.", "ent µs/dem."))
        acc = collections.defaultdict(list)
        for p in phases:
            if p["nom"] == "repos":
                continue
            pf, n = moy("pathFinder", p["t0"], p["t2"])
            en, _ = moy("entityUpdate", p["t0"], p["t2"])
            done = p["ok"] + p["echec"]
            per = (pf - base["pathFinder"]) * n / done * 1000 if done else 0.0
            per_e = (en - base["entityUpdate"]) * n / done * 1000 if done else 0.0
            acc[p["nom"]].append(per)
            print("  %-14s %6d %5d %6d %7.2f %8.1f %9.4f %11.1f %11.1f" % ("%d:%s" % (p["i"], p["nom"]), n, done, p["echec"], p["lat"], p["pts"], pf, per, per_e))
        print("  moyenne des deux tours (µs de pathFinder par demande finie) :")
        for nom, v in acc.items():
            ecart = abs(v[0] - v[1]) if len(v) == 2 else 0.0
            print("    %-12s %8.1f  (tours : %s ; écart %.1f)" % (nom, sum(v) / len(v), ", ".join("%.1f" % x for x in v), ecart))
    return 0


if __name__ == "__main__":
    sys.exit(main())
