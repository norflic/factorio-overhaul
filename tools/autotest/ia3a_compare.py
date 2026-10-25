# Lot IA3-a : critères K1, K6, K12 (docs/IA3_CERVEAU.md §6.1) AVANT / APRÈS, sur des bancs ia3d-* (réglage éteint) et
# ia3a-* (réglage fo-war-ia3-recherche allumé) de la MÊME source, archivés par ia3d_run.py (benchmark.log.gz).
# Par faction : minutes des recherches R1 à R3 (lignes « [FO-TEAM] … recherche niveau N payee »), minute de « fer II »
# (objectif atteint 'iron2'), soldats à 60 min, PNJ en fin de partie, et FABRICATION JETÉE (K6) : packs accumulés au
# coffre APRÈS R3 (le niveau 4 exige le pack chimique, impayable sans pétrole), en PNJ-minutes de fabrication à la main.
# Usage : py -3.9 -B tools/autotest/ia3a_compare.py --avant <archive> [...] --apres <archive> [...]
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ia3d_analyse import PACK_S, parse  # noqa: E402

SHORT = {"rouge": "automation-science-pack", "vert": "logistic-science-pack", "mil": "military-science-pack"}


def faction_rows(path):
    rows, research, goals, _defers, _status = parse(path)
    teams = sorted({r["team"] for r in rows if r["team"] != "player"})
    out = []
    for t in teams:
        rt = [r for r in rows if r["team"] == t]
        res = research.get(t, {})
        iron2 = None
        for m, key in goals.get(t, []):
            if key == "iron2" and iron2 is None:
                iron2 = m
        sold60 = None
        for r in rt:
            if r["min"] <= 60:
                sold60 = r["soldats"]
        last = rt[-1] if rt else None
        waste = 0.0
        if 3 in res and rt:
            r3 = res[3]
            before = None
            for r in rt:
                if r["min"] <= r3:
                    before = r
            if before and last:
                # Les fabrications à la main des PNJ n'entrent pas aux statistiques de production de la force (« produit
                # rouge=0 » dans les relevés) : on mesure, comme IA3-DIAG, les packs ACCUMULÉS au coffre après R3 (le
                # niveau 4 n'étant jamais payé, ils ne servent à rien).
                for k, p in SHORT.items():
                    d = last["stock"].get(k, 0) - before["stock"].get(k, 0)
                    waste += max(0, d) * PACK_S[p] / 60.0
        out.append({"team": t, "r1": res.get(1), "r2": res.get(2), "r3": res.get(3), "iron2": iron2, "sold60": sold60,
                    "pnj_fin": last["pnj"] if last else None, "waste": waste})
    return out


def med(values):
    v = [x for x in values if x is not None]
    return statistics.median(v) if v else None


def fmt(x, unit=""):
    return "—" if x is None else (f"{x:.1f}{unit}" if isinstance(x, float) else f"{x}{unit}")


def group(label, archives):
    print(f"== {label}")
    allr = []
    for a in archives:
        p = os.path.join(a, "benchmark.log.gz")
        if not os.path.exists(p):
            print(f"  {a} : benchmark.log.gz absent")
            continue
        for r in faction_rows(p):
            r["archive"] = os.path.basename(a.rstrip("\\/"))
            allr.append(r)
            print(f"  {r['archive']:28s} {r['team']:8s} R1 {fmt(r['r1'])} R2 {fmt(r['r2'])} R3 {fmt(r['r3'])} | fer II {fmt(r['iron2'])}"
                  f" | soldats 60 min {fmt(r['sold60'])} | PNJ fin {fmt(r['pnj_fin'])} | jeté {r['waste']:.1f} PNJ-min")
    if allr:
        never = sum(1 for r in allr if r["r3"] is None)
        print(f"  MÉDIANES ({len(allr)} factions) : R1 {fmt(med([r['r1'] for r in allr]))}, R2 {fmt(med([r['r2'] for r in allr]))},"
              f" R3 {fmt(med([r['r3'] for r in allr]))} (jamais : {never}) ; fer II {fmt(med([r['iron2'] for r in allr]))} ;"
              f" soldats à 60 min {fmt(med([r['sold60'] for r in allr]))} ; jeté {fmt(med([r['waste'] for r in allr]))} PNJ-min"
              f" (max {max(r['waste'] for r in allr):.1f}) ; factions à 0 PNJ en fin : {sum(1 for r in allr if r['pnj_fin'] == 0)}")
    return allr


def main():
    args = sys.argv[1:]
    if "--avant" not in args or "--apres" not in args:
        print(__doc__ or "usage : --avant <archive> [...] --apres <archive> [...]")
        return 2
    i, j = args.index("--avant"), args.index("--apres")
    avant = args[i + 1:j] if i < j else args[i + 1:]
    apres = args[j + 1:] if j > i else args[j + 1:i]
    group("AVANT (réglage éteint)", avant)
    group("APRÈS (fo-war-ia3-recherche)", apres)
    return 0


if __name__ == "__main__":
    sys.exit(main())
