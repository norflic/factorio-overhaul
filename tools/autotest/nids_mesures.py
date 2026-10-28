# -*- coding: utf-8 -*-
"""Lot NIDS : lecture des archives des bancs nids-guide / nids-guide-temoin et comparaison a la base commune.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/nids_mesures.py --lot <archive> [...] --temoin <archive> [...] --base <archive> [...]
Chaque archive est un dossier rendu par banc.py (benchmark.log.gz ou benchmark.log, seed.txt). Les archives sont appariees par
graine (seed.txt). Criteres : fo-logs/2026-10-29_NUIT/NIDS/CRITERES.md (N1 a N6).

Lignes lues :
  [FO-NIDS-MES] minute N | <faction> | soldats=.. tourelles=.. nids_detruits_moteur=.. soldats_morts=.. | mod : ops=.. ...
  [FO-NIDS-MES] echantillon tick T | <faction> | soldats=.. inactifs=.. nids_moteur_250=.. sites_connus=.. sites_menacants=..
  [FO-NIDS] <faction> : operation lancee en (x, y) ... secteur vu au tick <t|nil>   /   ... operation en (x, y) <fin> : ...
  base commune : [FO-ETAPE1-GUIDE] minute N | ... <faction> soldats X ...  et  mesure minute N | <faction> | ... tourelles=Y
"""
import argparse
import gzip
import os
import re
import sys

MINUTES = (12, 40, 60)


def read_log(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            opener = gzip.open if name.endswith(".gz") else open
            with opener(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


def read_seed(arch):
    try:
        with open(os.path.join(arch, "seed.txt"), encoding="utf-8") as fh:
            return fh.read().strip().splitlines()[0]
    except (OSError, IndexError):
        return "?"


RE_MIN = re.compile(r"\[FO-NIDS-MES\] minute (\d+) \| (\w+) \| (.*)$")
RE_SAMPLE = re.compile(r"\[FO-NIDS-MES\] echantillon tick (\d+) \| (\w+) \| (.*)$")
RE_KV = re.compile(r"(\w+)=(-?\d+)")
RE_LAUNCH = re.compile(r"\[FO-NIDS\] (\w+) : operation lancee en \((-?\d+), (-?\d+)\) a (\d+) tuiles du QG : (\d+) nid\(s\), (\d+) ver\(s\), "
                       r"menace (\d+) \(biens (\d+), incidents (\d+)\), (\d+) soldat\(s\) engages \(besoin (\d+), garnison gardee (\d+), "
                       r"echecs (\d+)\), secteur vu au tick (\S+)")
RE_END = re.compile(r"\[FO-NIDS\] (\w+) : operation en \((-?\d+), (-?\d+)\) (done|retreat|timeout) : engages (\d+), vivants (\d+), "
                    r"sur place \(max\) (\d+), nids restants au moteur (\d+), duree (\d+) min")
RE_BASE_MIN = re.compile(r"\[FO-[\w-]+\] minute (\d+) \| vivantes \d+ \| (.*?) \| ouvriers du joueur")
RE_BASE_MES = re.compile(r"\[FO-[\w-]+\] mesure minute (\d+) \| (\w+) \| (.*)$")


def kv(body):
    return {k: int(v) for k, v in RE_KV.findall(body)}


def parse_run(arch):
    out = {"seed": read_seed(arch), "min": {}, "samples": [], "launch": [], "end": [], "soldats": {}, "tourelles": {}}
    for line in read_log(arch):
        m = RE_MIN.search(line)
        if m:
            out["min"][(int(m.group(1)), m.group(2))] = kv(m.group(3).split("| mod :")[0] + " " + m.group(3).split("| mod :")[-1])
            continue
        m = RE_SAMPLE.search(line)
        if m:
            d = kv(m.group(3))
            d["tick"], d["f"] = int(m.group(1)), m.group(2)
            out["samples"].append(d)
            continue
        m = RE_LAUNCH.search(line)
        if m:
            g = m.groups()
            out["launch"].append({"f": g[0], "x": int(g[1]), "y": int(g[2]), "dist": int(g[3]), "sp": int(g[4]), "wm": int(g[5]),
                                  "menace": int(g[6]), "engages": int(g[9]), "besoin": int(g[10]), "garnison": int(g[11]),
                                  "echecs": int(g[12]), "seen": g[13]})
            continue
        m = RE_END.search(line)
        if m:
            g = m.groups()
            out["end"].append({"f": g[0], "res": g[3], "engages": int(g[4]), "vivants": int(g[5]), "onsite": int(g[6]), "restants": int(g[7]),
                               "duree": int(g[8])})
            continue
        m = RE_BASE_MIN.search(line)
        if m:
            n = int(m.group(1))
            for f, c in re.findall(r"(\w+) soldats (\d+)", m.group(2)):
                out["soldats"][(n, f)] = int(c)
            continue
        m = RE_BASE_MES.search(line)
        if m and m.group(2) != "votre":
            d = kv(m.group(3))
            if "tourelles" in d:
                out["tourelles"][(int(m.group(1)), m.group(2))] = d["tourelles"]
    return out


def part_inactive(run):
    """N3 : soldats inactifs quand la faction connait un site menacant, sur tous les soldats (echantillons avec soldats > 0)."""
    num = den = 0
    for s in run["samples"]:
        if s.get("soldats", 0) > 0 and s["tick"] >= 10 * 3600:
            den += s["soldats"]
            if s.get("sites_menacants", 0) > 0:
                num += s["inactifs"]
    return (100.0 * num / den) if den else None


def final_cumul(run, key):
    tot = 0
    facs = sorted({f for (_, f) in run["min"]})
    for f in facs:
        mins = [n for (n, ff) in run["min"] if ff == f]
        if mins:
            tot += run["min"][(max(mins), f)].get(key, 0)
    return tot


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lot", nargs="*", default=[])
    ap.add_argument("--temoin", nargs="*", default=[])
    ap.add_argument("--base", nargs="*", default=[])
    a = ap.parse_args()
    lot = {r["seed"]: r for r in map(parse_run, a.lot)}
    tem = {r["seed"]: r for r in map(parse_run, a.temoin)}
    base = {r["seed"]: r for r in map(parse_run, a.base)}
    seeds = sorted(set(lot) | set(tem))
    print("== N1 nids detruits (etat moteur : nids tues par la force d'une faction), cumul fin de partie")
    n1_lot = n1_tem = 0
    seeds_with = 0
    for s in seeds:
        l = final_cumul(lot[s], "nids_detruits_moteur") if s in lot else None
        t = final_cumul(tem[s], "nids_detruits_moteur") if s in tem else None
        print("  graine %s : lot %s, temoin %s, selon le mod (lot) %s" % (s, l, t, final_cumul(lot[s], "detruits") if s in lot else "-"))
        n1_lot += l or 0
        n1_tem += t or 0
        if l:
            seeds_with += 1
    print("  somme : lot %d, temoin %d ; graines avec >= 1 nid detruit : %d -> N1 %s" % (
        n1_lot, n1_tem, seeds_with, "OK" if n1_lot > n1_tem and seeds_with >= 2 else "NON ATTEINT"))
    print("== N2 soldats morts (moteur, toutes causes), cumul fin de partie")
    d_lot = d_tem = 0
    for s in seeds:
        l = final_cumul(lot[s], "soldats_morts") if s in lot else 0
        t = final_cumul(tem[s], "soldats_morts") if s in tem else 0
        d_lot += l
        d_tem += t
        print("  graine %s : lot %d, temoin %d ; perdus en operation (mod) %s" % (s, l, t, final_cumul(lot[s], "perdus_en_op") if s in lot else "-"))
    print("  somme : lot %d, temoin %d -> N2 %s" % (d_lot, d_tem, "OK" if d_lot <= d_tem + 6 else "NON ATTEINT"))
    print("== N3 part de soldats inactifs avec un site menacant connu (%% des soldats, minutes 10 a 60)")
    pl, pt = [], []
    for s in seeds:
        l = part_inactive(lot[s]) if s in lot else None
        t = part_inactive(tem[s]) if s in tem else None
        print("  graine %s : lot %s, temoin %s" % (s, "%.1f" % l if l is not None else "-", "%.1f" % t if t is not None else "-"))
        if l is not None:
            pl.append(l)
        if t is not None:
            pt.append(t)
    if pl and pt:
        ml, mt = sum(pl) / len(pl), sum(pt) / len(pt)
        print("  moyenne : lot %.1f, temoin %.1f -> N3 %s" % (ml, mt, "OK" if ml < mt else "NON ATTEINT"))
    print("== N4 non-degradation aux minutes %s (soldats >= base - 2, tourelles >= base - 1), par faction" % ",".join(map(str, MINUTES)))
    viol = tot = 0
    for s in seeds:
        if s not in lot or s not in base:
            continue
        for (n, f), bs in sorted(base[s]["soldats"].items()):
            if n not in MINUTES:
                continue
            ls = lot[s]["soldats"].get((n, f))
            bt, lt = base[s]["tourelles"].get((n, f)), lot[s]["tourelles"].get((n, f))
            if ls is None:
                continue
            tot += 1
            ts = tem[s]["soldats"].get((n, f)) if s in tem else None
            bad = ls < bs - 2 or (bt is not None and lt is not None and lt < bt - 1)
            viol += 1 if bad else 0
            print("  %s min %2d %-8s soldats base %3d temoin %s lot %3d | tourelles base %s lot %s %s" % (
                s, n, f, bs, ts if ts is not None else "-", ls, bt, lt, "VIOLATION" if bad else ""))
    print("  violations : %d sur %d -> N4 %s" % (viol, tot, "OK" if viol == 0 else "NON ATTEINT (voir lignes)"))
    print("== A/A : soldats du temoin = soldats de la base commune")
    for s in seeds:
        if s in tem and s in base:
            diff = [(k, v, tem[s]["soldats"].get(k)) for k, v in sorted(base[s]["soldats"].items()) if tem[s]["soldats"].get(k) != v]
            print("  graine %s : %d ecart(s) sur %d releves" % (s, len(diff), len(base[s]["soldats"])), diff[:3])
    print("== N5/N6 operations de nid (lot)")
    n5_bad = n6_bad = ops = 0
    for s in seeds:
        if s not in lot:
            continue
        for l in lot[s]["launch"]:
            ops += 1
            if l["seen"] in ("nil", "false"):
                n5_bad += 1
            if l["engages"] < l["besoin"]:
                n6_bad += 1
        for e in lot[s]["end"]:
            if e["res"] == "done" and e["restants"] != 0:
                n6_bad += 1
        print("  graine %s : %d lancee(s), fins %s" % (s, len(lot[s]["launch"]), [(e["res"], "%d/%d" % (e["vivants"], e["engages"])) for e in lot[s]["end"]]))
    print("  operations %d ; sans secteur vu %d -> N5 %s ; fautes d'exactitude %d -> N6 %s" % (
        ops, n5_bad, "OK" if n5_bad == 0 else "NON ATTEINT", n6_bad, "OK" if n6_bad == 0 else "NON ATTEINT"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
