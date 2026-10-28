r"""Coût du lot TIRS par phase (scénario tirs-cout : phases A1 / B / A2 dans la même partie).

    py -3.9 -B tools/autotest/tirs_cout.py <archive du banc branche> [--main <archive du banc main>]

Lit benchmark-stdout.txt[.gz] (--benchmark-verbose all : une ligne par tick, en ns) et benchmark.log (lignes
« [FO-TIRS-COUT] COMPTEURS » du scénario, étalon [FO-CALIB]). Rend, par phase : moyenne et p99 de wholeUpdate,
entityUpdate, scriptUpdate, luaGarbageIncremental (ms), événements et tirs habillés par tick ; puis
  - coût de l'HABILLAGE = moyenne des phases A − phase B, rapporté au tir habillé (µs) ;
  - coût de l'ÉVÉNEMENT seul (avec --main) = phase B − main sur les mêmes ticks, rapporté à l'événement (µs) ;
  - normalisation par l'étalon [FO-CALIB] (médiane) quand les deux archives en ont un.
Un banc sans --seul donne des temps FAUX (F30, interdit n° 4) : l'outil le dit (banc.txt « genre »).
"""
import gzip
import os
import re
import sys

POSTES = ["wholeUpdate", "entityUpdate", "scriptUpdate", "luaGarbageIncremental"]
PHASES = [("A1", 600, 2600), ("B", 2600, 4600), ("A2", 4600, 6600)]


def lire(d, nom):
    for n in (nom, nom + ".gz"):
        p = os.path.join(d, n)
        if os.path.exists(p):
            if n.endswith(".gz"):
                with gzip.open(p, "rt", encoding="utf-8", errors="replace") as f:
                    return f.read()
            with open(p, encoding="utf-8", errors="replace") as f:
                return f.read()
    return ""


def verbose(texte):
    entete, lignes = None, {}
    for l in texte.splitlines():
        l = l.strip()
        if entete is None and "wholeUpdate" in l and "," in l:
            entete = [c for c in l.split(",") if c != ""]
            continue
        if entete and l.startswith("t") and "," in l:
            c = [x for x in l.split(",") if x != ""]
            try:
                t = int(c[0][1:])
                lignes[t] = [int(x) if x.lstrip("-").isdigit() else 0 for x in c[1:]]
            except ValueError:
                pass
    return entete, lignes


def p99(v):
    s = sorted(v)
    return s[min(len(s) - 1, int(0.99 * (len(s) - 1) + 0.5))] if s else 0.0


def calib(log):
    """Médiane des durées de l'étalon [FO-CALIB] (« [FO-CALIB] <tick> Duration: 2.17ms »)."""
    v = sorted(float(x) for x in re.findall(r"\[FO-CALIB\] \d+ Duration: ([\d.]+)ms", log))
    return v[len(v) // 2] if v else None


def phases(d):
    entete, lignes = verbose(lire(d, "benchmark-stdout.txt"))
    if not entete:
        raise SystemExit("pas de --benchmark-verbose dans " + d)
    idx = {p: entete.index(p) - 1 for p in POSTES if p in entete}
    out = {}
    for nom, a, b in PHASES:
        v = {p: [lignes[t][idx[p]] / 1e6 for t in range(a, b) if t in lignes] for p in idx}
        out[nom] = {p: (sum(x) / len(x) if x else 0.0, p99(x)) for p, x in v.items()}
        out[nom]["n"] = len(v.get("wholeUpdate", []))
    log = lire(d, "benchmark.log")
    for m in re.finditer(r"\[FO-TIRS-COUT\] COMPTEURS\t(\w+)\tactif=(\w+)\tticks=(\d+)\tevenements=(\d+)\t\(([\d.]+)/tick\)"
                         r"\thabilles=(\d+)\t\(([\d.]+)/tick\)", log):
        out.setdefault(m.group(1), {})
        out[m.group(1)]["evts_tick"] = float(m.group(5))
        out[m.group(1)]["hab_tick"] = float(m.group(7))
    genre = re.search(r"genre (\w+)", lire(d, "banc.txt"))
    return out, calib(log), genre.group(1) if genre else "?"


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    br, cal, genre = phases(argv[1])
    main_ = None
    if "--main" in argv:
        main_, cal_m, genre_m = phases(argv[argv.index("--main") + 1])
    print("banc branche : genre %s%s ; etalon FO-CALIB %s" % (genre, "" if genre == "seul" else
          " (SANS --seul : temps indicatifs seulement, F30)", cal))
    for nom, _, _ in PHASES:
        x = br[nom]
        print("  %-3s %5d ticks : %s ; %.3f evenements/tick, %.3f habilles/tick" % (
            nom, x.get("n", 0), ", ".join("%s %.3f (p99 %.3f)" % (p, x[p][0], x[p][1]) for p in POSTES if p in x),
            x.get("evts_tick", 0), x.get("hab_tick", 0)))
    a_moy = {p: 0.5 * (br["A1"][p][0] + br["A2"][p][0]) for p in POSTES if p in br["B"]}
    hab = 0.5 * (br["A1"].get("hab_tick", 0) + br["A2"].get("hab_tick", 0))
    for p in ("wholeUpdate", "entityUpdate"):
        d = a_moy[p] - br["B"][p][0]
        print("habillage (A - B) %s : %+.4f ms/tick%s ; derive A2 - A1 %+.4f ms" % (
            p, d, (" = %.1f us par tir habille" % (1000 * d / hab)) if hab > 0 else "", br["A2"][p][0] - br["A1"][p][0]))
    if main_:
        print("banc main : genre %s ; etalon %s" % (genre_m, cal_m))
        k = (cal / cal_m) if (cal and cal_m) else 1.0
        ev = br["A1"].get("evts_tick", 0)
        for p in ("wholeUpdate", "entityUpdate"):
            m_moy = sum(main_[n][p][0] for n, _, _ in PHASES) / 3
            d = br["B"][p][0] - m_moy * k
            print("evenement seul (B - main, main x %.3f par l'etalon) %s : %+.4f ms/tick%s" % (
                k, p, d, (" = %.1f us par evenement (%.2f evts/tick en phase A)" % (1000 * d / ev, ev)) if ev > 0 else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
