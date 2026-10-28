# -*- coding: utf-8 -*-
"""Lot STOCK-ECHELLE : lecture des bancs stock-plein / stock-plein-temoin (lignes [FO-STOCK-PLEIN]).

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/stock_plein_lire.py --plein <archive> --temoin <archive>
Par force : sur la 2e moitie du banc, cases portees par les PNJ (ce qu'ils n'ont pas pu deposer), objets au sol pres du QG,
plaques de fer produites par minute, inactifs de la minute ; plein contre temoin, avec les seuils de CRITERES.md (B1 a B3).
Rend le code 1 si un DEFAUT est mesure, 0 sinon.
"""
import argparse
import gzip
import os
import re
import sys

RE_S = re.compile(r"\[FO-STOCK-PLEIN\] t=(\d+) (\S+) \| qg=(\d+)/(\d+) annexes=(\d+)\((\d+)/(\d+)\) \| pnj=(\d+) portes_cases=(\d+) sol=(\d+) \| prod_fer=(\d+) prod_cuivre=(\d+) \| stock_fer=(\d+) \| top=(.*)$")
RE_M = re.compile(r"mesure minute (\d+) \| votre equipe \|.*?inactifs=(\d+)%")
CHECK = 9600


def lines(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            op = gzip.open if name.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


def load(arch):
    rows, idle = [], {}
    for l in lines(arch):
        m = RE_S.search(l)
        if m:
            g = m.groups()
            rows.append(dict(tick=int(g[0]), force=g[1], qu=int(g[2]), qs=int(g[3]), na=int(g[4]), au=int(g[5]), as_=int(g[6]),
                             n=int(g[7]), carried=int(g[8]), ground=int(g[9]), iron=int(g[10]), stock_fer=int(g[12]), top=g[13]))
        m = RE_M.search(l)
        if m:
            idle[int(m.group(1))] = int(m.group(2))
    return rows, idle


def summ(rows, force):
    r = [x for x in rows if x["force"] == force]
    h = [x for x in r if x["tick"] >= CHECK // 2]
    if not r or not h:
        return None
    avg = lambda k: sum(x[k] for x in h) / float(len(h))
    span = r[-1]["tick"] - r[0]["tick"]
    return dict(n=len(h), pnj=avg("n"), carried=avg("carried"), ground=avg("ground"), na=avg("na"),
                qfill=avg("qu") / max(1.0, avg("qs")), afill=(avg("au") / avg("as_")) if avg("as_") else 0.0,
                iron_min=(r[-1]["iron"] - r[0]["iron"]) * 3600.0 / span if span > 0 else 0.0,
                per_pnj=avg("carried") / max(1.0, avg("n")), top=h[-1]["top"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plein", required=True)
    ap.add_argument("--temoin", required=True)
    a = ap.parse_args()
    rp, ip = load(a.plein)
    rt, it = load(a.temoin)
    forces = sorted(set(x["force"] for x in rp + rt), key=lambda f: (f != "player", f))
    defect = False
    print("force      | cases portees par PNJ (plein / temoin) | sol (plein / temoin) | fer/min (plein / temoin) | annexes (plein / temoin) | QG plein | verdict")
    for f in forces:
        p, t = summ(rp, f), summ(rt, f)
        if not p or not t:
            print("%-10s | releves manquants (plein %s, temoin %s)" % (f, bool(p), bool(t)))
            continue
        b1 = p["per_pnj"] > t["per_pnj"] + 2.0
        b2 = p["ground"] > t["ground"] + 20
        b3 = t["iron_min"] > 0 and p["iron_min"] < 0.95 * t["iron_min"]
        v = []
        if b1: v.append("B1 DEFAUT (objets bloques)")
        if b2: v.append("B2 DEFAUT (objets au sol)")
        if b3: v.append("B3 DEFAUT (production)")
        defect = defect or bool(v)
        print("%-10s | %.2f / %.2f | %.1f / %.1f | %.1f / %.1f | %.1f / %.1f | %.2f | %s" % (
            f, p["per_pnj"], t["per_pnj"], p["ground"], t["ground"], p["iron_min"], t["iron_min"], p["na"], t["na"], p["qfill"],
            ", ".join(v) or "sans defaut mesure"))
        print("           top portes (plein) : %s | (temoin) : %s" % (p["top"], t["top"]))
    for tag, idle in (("plein", ip), ("temoin", it)):
        print("inactifs de votre equipe (%s), par minute : %s" % (tag, ", ".join("%d:%d%%" % (k, idle[k]) for k in sorted(idle))))
    print("DEFAUT MESURE" if defect else "SANS DEFAUT MESURE")
    sys.exit(1 if defect else 0)


if __name__ == "__main__":
    main()
