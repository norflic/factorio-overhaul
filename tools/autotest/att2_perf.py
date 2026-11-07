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
    # chronomètres du script aux 4 pires ticks de chaque grande attaque (remote fo-att2 « profil »)
    wi = header[1:].index("wholeUpdate")
    gi = header[1:].index("luaGarbageIncremental")
    pi = header[1:].index("particleUpdate")
    T = {t: x for t, x in rows}
    prof = {int(m.group(1)): m.group(2) for m in re.finditer(r"\[FO-ATT2-PROFIL\] tick (\d+) (.*)", log)}
    if prof:
        print()
        print("PIRES TICKS (tick entier) et chronomètres du script :")
        for g in IDS:
            if g not in frappe or g not in fin:
                continue
            v = sorted([t for t in range(frappe[g] - CHARGE[g], fin[g] + 1) if t in T and t % 600 != 0], key=lambda t: -T[t][wi])[:4]
            for t in v:
                x = T[t]
                print("  %-9s %+5d  entier %6.2f  script %5.2f  GC %5.2f  particules %5.2f | %s" % (g, t - frappe[g], x[wi] / 1e6, x[si] / 1e6,
                      x[gi] / 1e6, x[pi] / 1e6, prof.get(t, "(pas de chrono)")[:640]))
    ramasse_miettes(log)
    return 0


KO_RE = re.compile(r"\[FO-ATT2-PROFIL\] tick (\d+) (\w+) rt (-?\d+) .*? ; pas Duration: ([0-9.]+)\s*ms.*?Ko nets : preparation ([-+0-9.]+), "
                   r"pas ([-+0-9.]+) \(tuiles ([-+0-9.]+), plan ([-+0-9.]+)\), coups ([-+0-9.]+), attaque ([-+0-9.]+)")


def ramasse_miettes(log):
    """Preuve du ramasse-miettes (demande du lead, 7/11) : mémoire Lua NETTE par section, écrite par le profil depuis la v8. Un pas lent
    dont la mémoire nette est NÉGATIVE (ou très en dessous des autres pas) a vu le ramasse-miettes travailler dans le pas ; un pas lent
    à mémoire nette normale vient d'autre chose. Rien si le banc est plus ancien que la v8."""
    L = [(int(m.group(1)), m.group(2), int(m.group(3)), float(m.group(4)), float(m.group(6))) for m in KO_RE.finditer(log)]
    if not L:
        print("\n(mémoire nette par section absente : profil antérieur à la v8)")
        return
    if all(r[4] == 0 for r in L):
        print("\n(mémoire nette toujours nulle : collectgarbage(\"count\") indisponible dans le jeu ; pas de preuve par cette voie)")
        return
    print("\nRAMASSE-MIETTES : pas lents et mémoire Lua nette du pas (Ko), par géant")
    for g in IDS:
        v = [r for r in L if r[1] == g and r[2] >= 0]
        if not v:
            continue
        pas = sorted(r[3] for r in v)
        med = pas[len(pas) // 2]
        kos = sorted(r[4] for r in v)
        kmed = kos[len(kos) // 2]
        neg = [r for r in v if r[4] < 0]
        lents = sorted([r for r in v if r[3] >= max(3 * med, 1.0)], key=lambda r: -r[3])
        print("  %-9s pas médian %.3f ms, Ko net médian %+.1f ; %d pas à Ko net négatif ; %d pas lents (>= 3 x médiane et >= 1 ms)"
              % (g, med, kmed, len(neg), len(lents)))
        for r in lents[:6]:
            print("    lent      rt %+5d  pas %6.3f ms  Ko net %+9.1f%s" % (r[2], r[3], r[4], "  <- ramasse-miettes dans le pas" if r[4] < 0 else ""))
        for r in sorted(neg, key=lambda r: r[4])[:6]:
            print("    négatif   rt %+5d  pas %6.3f ms  Ko net %+9.1f" % (r[2], r[3], r[4]))


if __name__ == "__main__":
    sys.exit(main())
