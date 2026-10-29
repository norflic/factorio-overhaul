#!/usr/bin/env python3
"""Lot RESEAU-VIVANT : tableau lot contre témoin, critères C1, C5 et C6 (fo-logs/2026-10-29_NUIT/RESEAU/CRITERES.md).

Usage : py -3.9 -B tools/autotest/reseau_tableau.py <dossier d'archives> <préfixe lot> <préfixe témoin> [--graines 20261020,...]
Les archives sont <dossier>/<préfixe>-<graine>/benchmark.log(.gz). Rend un tableau par graine et les verdicts poolés.
"""
import argparse
import collections
import glob
import gzip
import os
import re
import statistics
import sys

PE = re.compile(r"\[FO-FONCTION\] elec minute (\d+) \| (\w+) \| (.*)$")
PR = re.compile(r"\[FO-FONCTION\] reseau minute (\d+) \| (\w+) \| (.*)$")
PS = re.compile(r"\[FO-FONCTION\] statut minute (\d+) \| (\w+) \| classe=(\w+) n=(\d+) samples=(\d+) (.*)$")
PT = re.compile(r"\[FO-FONCTION\] tourelles minute (\d+) \| (\w+) \| (.*)$")
PP = re.compile(r"\[FO-FONCTION\] prod minute (\d+) \| (\w+) \| (.*)$")
POSE = re.compile(r"\[FO-(?:POSE|POLE)\] .*ennemi a 28 tuiles : (OUI|non)")
RES = re.compile(r"\[FO-RESEAU\] (\w+) : (.*) a ([\d.]+) min")


def kvs(s):
    return dict(x.split("=", 1) for x in s.split() if "=" in x)


def lines(d):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(d, name)
        if os.path.exists(p):
            op = gzip.open if name.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as f:
                for line in f:
                    yield line
            return


def read(d):
    R = dict(deficit={}, red={}, tour={}, prod={}, pnj={}, feu=0, poses=0, decisions=collections.Counter(), reopen=0, dec_lines=[],
             bad=collections.Counter(), samples=collections.Counter(), nopow=collections.Counter(), lowpow=collections.Counter())
    performed = False
    for line in lines(d):
        m = PE.search(line)
        if m:
            kv = kvs(m.group(3))
            pose = sum(int(kv[c + "_pose"]) for c in ("foreuse_elec", "bras_elec", "assembleur"))
            al = sum(int(kv[c + "_alimentes"]) for c in ("foreuse_elec", "bras_elec", "assembleur"))
            R["deficit"][(int(m.group(1)), m.group(2))] = (pose - al, pose)
            continue
        m = PR.search(line)
        if m:
            kv = kvs(m.group(3))
            if "poteaux" in kv:
                R["red"][(int(m.group(1)), m.group(2))] = dict(pot=int(kv["poteaux"]), svc=int(kv["en_service"]), p2=int(kv["paires_lt2"]),
                                                               glou=int(kv["redondants_glouton"]), ilots=int(kv["ilots"]),
                                                               alim=int(kv["alimentes"]))
            continue
        m = PS.search(line)
        if m:
            if m.group(3) in ("foreuse_elec", "bras_elec", "assembleur") and int(m.group(1)) in (40, 50, 60):
                kv = kvs(m.group(6))
                ns = int(m.group(5)) * max(1, int(m.group(4)))
                R["samples"]["all"] += int(m.group(5)) * int(m.group(4))
                R["bad"]["all"] += sum(int(v) for k, v in kv.items() if k in ("no_power", "not_plugged_in_electric_network", "low_power")) * int(m.group(4))
                R["nopow"]["all"] += sum(int(v) for k, v in kv.items() if k in ("no_power", "not_plugged_in_electric_network")) * int(m.group(4))
                R["lowpow"]["all"] += int(kv.get("low_power", 0)) * int(m.group(4))
            continue
        m = PT.search(line)
        if m:
            kv = kvs(m.group(3))
            R["tour"][(int(m.group(1)), m.group(2))] = int(kv.get("armees", 0))
            continue
        m = PP.search(line)
        if m:
            kv = kvs(m.group(3))
            R["prod"][(int(m.group(1)), m.group(2))] = float(kv.get("plaques_min", 0))
            R["pnj"][(int(m.group(1)), m.group(2))] = int(kv.get("pnj", 0))
            continue
        m = POSE.search(line)
        if m:
            R["poses"] += 1
            if m.group(1) == "OUI":
                R["feu"] += 1
            continue
        m = RES.search(line)
        if m:
            txt = m.group(2)
            kind = txt.split(":")[0].split(" ")[0]
            R["decisions"][kind] += 1
            mm = re.search(r"(\d+) (?:piece|poteau)\S* rouverte?\(s\)|(\d+) rouvert", txt)
            if mm:
                R["reopen"] += int(mm.group(1) or mm.group(2))
            if len(R["dec_lines"]) < 40 and not txt.startswith("synthese"):
                R["dec_lines"].append(f"{m.group(1)} {m.group(3)} min : {txt}")
    sp = os.path.join(d, "benchmark-stdout.txt.gz")
    if os.path.exists(sp):
        with gzip.open(sp, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 22), b""):
                if b"Performed 216" in chunk:
                    performed = True
                    break
    R["performed"] = performed
    return R


def agg_def(R, minutes=(40, 50, 60)):
    return sum(v[0] for (m, f), v in R["deficit"].items() if m in minutes)


def agg_red(R, m=60):
    rows = [v for (mm, f), v in R["red"].items() if mm == m]
    return (sum(v["p2"] for v in rows), sum(v["glou"] for v in rows), sum(v["svc"] for v in rows), sum(v["alim"] for v in rows),
            sum(v["ilots"] for v in rows), sum(v["pot"] for v in rows))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("lot")
    ap.add_argument("temoin")
    ap.add_argument("--graines", default="20261020,123456789,271828182,1618033988")
    a = ap.parse_args()
    seeds = a.graines.split(",")
    L, T = {}, {}
    for s in seeds:
        for pre, dst in ((a.lot, L), (a.temoin, T)):
            d = os.path.join(a.root, f"{pre}-{s}")
            if os.path.isdir(d):
                dst[s] = read(d)
    print("graine      | C1 deficit(m40+m50+m60) lot / temoin | C5 paires<2 m60 lot / temoin | glouton/en_service m60 lot / temoin | "
          "poteaux/alimente lot / temoin | ilots m60 lot / temoin")
    pd = [0, 0]
    pr = [[0] * 6, [0] * 6]
    pt = [collections.Counter(), collections.Counter()]
    for s in seeds:
        if s not in L or s not in T:
            print(f"{s:11} | manque (lot={'oui' if s in L else 'non'}, temoin={'oui' if s in T else 'non'})")
            continue
        dl, dt = agg_def(L[s]), agg_def(T[s])
        rl, rt = agg_red(L[s]), agg_red(T[s])
        pd[0] += dl
        pd[1] += dt
        for i in range(6):
            pr[0][i] += rl[i]
            pr[1][i] += rt[i]
        for k, (R, c) in enumerate(((L[s], pt[0]), (T[s], pt[1]))):
            for m in (40, 60):
                c[f"pnj{m}"] += sum(v for (mm, f), v in R["pnj"].items() if mm == m)
                c[f"tour{m}"] += sum(v for (mm, f), v in R["tour"].items() if mm == m)
            c["plaques60"] += sum(v for (mm, f), v in R["prod"].items() if mm == 60)
        print(f"{s:11} | {dl:4} / {dt:4}                           | {rl[0]:3} / {rt[0]:3}                     | "
              f"{rl[1]}/{rl[2]} / {rt[1]}/{rt[2]}                   | "
              f"{(rl[5] / max(1, rl[3])):.2f} / {(rt[5] / max(1, rt[3])):.2f}          | {rl[4]} / {rt[4]}")
        print(f"            lot: decisions {dict(L[s]['decisions'])} rouverts {L[s]['reopen']} poses sous le feu {L[s]['feu']}/{L[s]['poses']} "
              f"Performed={L[s]['performed']} ; temoin Performed={T[s]['performed']}")
    print()
    print(f"POOLE deficit : lot {pd[0]} / temoin {pd[1]}  -> rapport {pd[0] / max(1, pd[1]):.2f}  (C1 : <= 0.50)")
    print(f"POOLE paires<2 m60 : lot {pr[0][0]} / temoin {pr[1][0]}  -> rapport {pr[0][0] / max(1, pr[1][0]):.2f}  (C5 : <= 0.40)")
    sh = [pr[i][1] / max(1, pr[i][2]) for i in (0, 1)]
    print(f"POOLE part redondante (glouton/en_service) m60 : lot {sh[0]:.3f} / temoin {sh[1]:.3f} -> rapport {sh[0] / max(1e-9, sh[1]):.2f}  (C5 : <= 0.75)")
    pp = [pr[i][5] / max(1, pr[i][3]) for i in (0, 1)]
    print(f"POOLE poteaux par consommateur alimente m60 : lot {pp[0]:.2f} / temoin {pp[1]:.2f} -> rapport {pp[0] / max(1e-9, pp[1]):.2f}  (C5 : <= 1.05)")
    for k in sorted(pt[0]):
        print(f"POOLE C6 {k} : lot {pt[0][k]:.0f} / temoin {pt[1][k]:.0f} -> rapport {pt[0][k] / max(1, pt[1][k]):.2f}  (C6 : >= 0.85)")
    sb = [sum(R[s]["bad"]["all"] for s in R) / max(1, sum(R[s]["samples"]["all"] for s in R)) for R in (L, T)]
    print(f"SUPPL. part des releves (30 s) 'sans courant / courant faible' des foreuses et bras electriques et assembleurs, fenetres 30 a 60 min : lot {sb[0]:.3f} / temoin {sb[1]:.3f}")
    den = [max(1, sum(R[s]["samples"]["all"] for s in R)) for R in (L, T)]
    npw = [sum(R[s]["nopow"]["all"] for s in R) / den[i] for i, R in enumerate((L, T))]
    lpw = [sum(R[s]["lowpow"]["all"] for s in R) / den[i] for i, R in enumerate((L, T))]
    print(f"SUPPL. dont SANS COURANT (reseau / centrale a l'arret) : lot {npw[0]:.3f} / temoin {npw[1]:.3f} ; dont COURANT FAIBLE (centrale saturee : capacite, hors lot) : lot {lpw[0]:.3f} / temoin {lpw[1]:.3f}")
    feu = sum(L[s]["feu"] for s in L)
    print(f"C6 poses (poteaux, pieces de centrale) avec un ennemi a 28 tuiles : {feu}  (C6 : 0)")
    for s in L:
        for t in L[s]["dec_lines"][:8]:
            print(f"   [{s}] {t}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
