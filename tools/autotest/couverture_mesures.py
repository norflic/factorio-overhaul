#!/usr/bin/env python3
"""Lecteur de mesure du lot COUVERTURE (8/11). Lit un ou plusieurs journaux de banc (benchmark.log, .gz accepte) et rend, par force :

  1. ORDRES couvrir/ouvrir : decides (lignes [FO-CAPI] "ordres=[...]"), retenus par la porte L6 ("executant refuse [...]"), avec la cause ;
  2. [FO-COUVERTURE] : lignes "PASSE ... EN BOUCLE" / "RETENU" / "PASSE la porte" ;
  3. GISEMENTS : a chaque minute choisie (--minutes, defaut 20,40,60), pour chaque gisement, la couverture en pour mille et les foreuses
     posees (derniere ligne [FO-CAPI-COUV] au plus tard a cette minute) ; part des tuiles couverte par minerai ;
  4. places de chantier ([FO-PORTES] "places de chantier K sur N").

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/couverture_mesures.py <journal> [<journal>...] [--minutes 20,40,60] [--json]
Aucune decision n'en depend (mesure seulement). Critere : fo-logs/2026-11-08_COUVERTURE/CRITERES.md.
"""
import argparse
import collections
import gzip
import json
import re
import sys


def lines_of(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            yield line


RE_CAPI = re.compile(r"\[FO-CAPI\] (\w+) minute (\d+)")
RE_REFUS = re.compile(r"(couvrir|ouvrir):([\w\-]+)(?:@[-\d,]+)? \(([^)]*)\)")
RE_COUV = re.compile(r"\[FO-COUVERTURE\] (\w+) minute (\d+) : (\S+) x(\d+) : (PASSE la porte du transport EN BOUCLE|RETENU|PASSE la porte)")
RE_GIS = re.compile(
    r"\[FO-CAPI-COUV\] (\w+) minute (\d+) \| gisement (\S+) (\S+) \| couverture (\d+)/(\d+) \((\d+) pour mille\) \| places libres (\S+) "
    r"\| foreuses posees (\d+)")
RE_PORTES = re.compile(r"\[FO-PORTES\] (\w+) minute (\d+) : transport (\w+).*places de chantier (\d+) sur (\d+)")


def analyse(paths, minutes):
    decided = collections.Counter()
    held = collections.Counter()
    why = collections.Counter()
    boucle = collections.Counter()
    gis = {}
    sites = {}
    for path in paths:
        for line in lines_of(path):
            if "[FO-CAPI] " in line:
                m = RE_CAPI.search(line)
                if not m:
                    continue
                who = m.group(1)
                j = line.find("ordres=[")
                if j >= 0:
                    seg = line[j:line.find("]", j)]
                    for kind in ("couvrir", "ouvrir"):
                        decided[(who, kind)] += len(re.findall(kind + r" [\w\-]+ x\d+", seg))
                i = line.find("executant refuse [")
                if i >= 0:
                    for mm in RE_REFUS.finditer(line[i:]):
                        held[(who, mm.group(1))] += 1
                        why[(who, mm.group(1), mm.group(3)[:48])] += 1
            elif "[FO-COUVERTURE]" in line:
                m = RE_COUV.search(line)
                if m:
                    boucle[(m.group(1), m.group(5))] += 1
            elif "[FO-CAPI-COUV]" in line:
                m = RE_GIS.search(line)
                if m:
                    who, mn = m.group(1), int(m.group(2))
                    gis.setdefault((who, m.group(3), m.group(4)), []).append(
                        (mn, int(m.group(5)), int(m.group(6)), int(m.group(7)), int(m.group(9))))
            elif "[FO-PORTES]" in line:
                m = RE_PORTES.search(line)
                if m:
                    sites.setdefault(m.group(1), []).append((int(m.group(2)), m.group(3), int(m.group(4)), int(m.group(5))))
    out = {"ordres": {}, "couverture": {}, "gisements": {}, "sites": {}}
    for who, kind in sorted(set(list(decided) + list(held))):
        out["ordres"]["%s/%s" % (who, kind)] = {"decides": decided[(who, kind)], "retenus_L6": held[(who, kind)],
                                                "causes": {k[2]: v for k, v in why.items() if k[0] == who and k[1] == kind}}
    for (who, verdict), n in sorted(boucle.items()):
        out["couverture"].setdefault(who, {})[verdict] = n
    for mn in minutes:
        tiles = collections.defaultdict(lambda: [0, 0, 0])  # (who, ressource) -> [couvertes, total, foreuses]
        per = {}
        for (who, gid, res), rows in sorted(gis.items()):
            rows = [r for r in rows if r[0] <= mn]
            if not rows:
                continue
            r = rows[-1]
            per["%s %s" % (who, gid)] = {"minute": r[0], "pour_mille": r[3], "couvertes": r[1], "tuiles": r[2], "foreuses": r[4]}
            t = tiles[(who, res)]
            t[0] += r[1]; t[1] += r[2]; t[2] += r[4]
        out["gisements"][str(mn)] = {"par_gisement": per,
                                     "par_minerai": {"%s %s" % k: {"couvertes": v[0], "tuiles": v[1], "foreuses": v[2],
                                                                   "pour_mille": (1000 * v[0] // v[1]) if v[1] else 0}
                                                     for k, v in sorted(tiles.items())}}
    for who, rows in sorted(sites.items()):
        out["sites"][who] = {"derniere": rows[-1], "limite_max": max(r[3] for r in rows), "mesures": len(rows)}
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logs", nargs="+")
    ap.add_argument("--minutes", default="20,40,60")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    res = analyse(a.logs, [int(x) for x in a.minutes.split(",") if x])
    if a.json:
        json.dump(res, sys.stdout, indent=1, sort_keys=True)
        print()
        return
    print("== ORDRES couvrir/ouvrir (decides, retenus par la porte L6)")
    for k, v in res["ordres"].items():
        print("  %-16s decides %3d  retenus L6 %3d  %s" % (k, v["decides"], v["retenus_L6"], v["causes"]))
    print("== [FO-COUVERTURE]")
    for who, d in res["couverture"].items():
        print("  %-10s %s" % (who, d))
    for mn, d in res["gisements"].items():
        print("== COUVERTURE a la minute %s (par minerai : tuiles couvertes / tuiles, pour mille, foreuses posees)" % mn)
        for k, v in d["par_minerai"].items():
            print("  %-26s %5d/%5d  %4d pour mille  %3d foreuses" % (k, v["couvertes"], v["tuiles"], v["pour_mille"], v["foreuses"]))
    print("== PLACES DE CHANTIER ([FO-PORTES])")
    for who, v in res["sites"].items():
        print("  %-10s derniere %s  limite max %d  (%d mesures)" % (who, v["derniere"], v["limite_max"], v["mesures"]))


if __name__ == "__main__":
    main()
