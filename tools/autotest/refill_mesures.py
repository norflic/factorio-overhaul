#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lot REMPLISSAGE : compare une archive de banc `etape1-guide` (lot) a sa base (MESURES) sur les criteres C1 a C5.

Usage :
  PYTHONUTF8=1 py -3.9 -B tools/autotest/refill_mesures.py --base <dossier base> --lot <dossier lot> [--force player]
  PYTHONUTF8=1 py -3.9 -B tools/autotest/refill_mesures.py --paire <graine> <base> <lot> [--paire ...] [--json sortie.json]

Definitions : fo-logs/2026-10-29_NUIT/REFILL/CRITERES.md (ecrites avant la mesure). Lit benchmark.log ou benchmark.log.gz.
"""
import argparse
import gzip
import json
import os
import re
import statistics
import sys

FORCES = ("player", "scarlet", "azure")
KV = re.compile(r"(\w+)=([-0-9.]+)")


def lire(dossier):
    for nom in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(dossier, nom)
        if os.path.exists(p):
            op = gzip.open if p.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as f:
                return f.read().splitlines()
    raise SystemExit("pas de benchmark.log dans " + dossier)


def kv(texte):
    return {k: float(v) for k, v in KV.findall(texte)}


def releves(dossier):
    lignes = lire(dossier)
    r = {f: {"passages": 0, "n_main": {}, "four_samples": 0, "no_fuel": 0, "no_ingr": 0, "ws_main": 0, "ns_main": 0,
             "eq_main": 0.0, "nom_main": 0.0, "plaques": {}, "smelt": []} for f in FORCES}
    coal = {}
    for ln in lignes:
        m = re.search(r"\[FO-TRACE\] (\d+) act smelt (\w+)", ln)
        if m and m.group(2) in r:
            r[m.group(2)]["passages"] += 1
            continue
        m = re.search(r"\[FO-FONCTION\] (\w+) minute (\d+) \| (\w+) \| (.*)$", ln)
        if m and m.group(3) in r:
            genre, minute, force, reste = m.group(1), int(m.group(2)), m.group(3), m.group(4)
            if minute < 10:
                continue
            d = kv(reste)
            if genre == "fours":
                r[force]["n_main"][minute] = d.get("n_main", 0)
                r[force]["ws_main"] += d.get("ws_main", 0)
                r[force]["ns_main"] += d.get("ns_main", 0)
                r[force]["eq_main"] += d.get("eq_main", 0)
                r[force]["nom_main"] += d.get("nom_main", 0)
            elif genre == "prod":
                if "plaques_min" in d:
                    r[force]["plaques"][minute] = d["plaques_min"]
            elif genre == "statut" and "classe=four " in reste + " ":
                r[force]["four_samples"] += d.get("samples", 0)
                r[force]["no_fuel"] += d.get("no_fuel", 0)
                r[force]["no_ingr"] += d.get("no_ingredients", 0)
            continue
        m = re.search(r"\[FO-ETAPE1-GUIDE\] minute (\d+) \|.*\| stock [^|]*?coal=(\d+)", ln)
        if m:
            coal[int(m.group(1))] = int(m.group(2))
            continue
        m = re.search(r"\[FO-SMELT\] (\d+) (\w+) fours=(\d+) charges=(\d+) unites=(\d+) places=(\d+) collecte=(\d+) "
                      r"charbon_avant=(\d+) charbon_ajoute=(\d+)", ln)
        if m and m.group(2) in r:
            r[m.group(2)]["smelt"].append(tuple(int(m.group(i)) for i in (1, 3, 4, 5, 6, 7, 8, 9)))
    return r, coal


def resume(r, coal):
    out = {}
    for f in FORCES:
        x = r[f]
        nm = [v for v in x["n_main"].values()]
        n_main = statistics.mean(nm) if nm else 0.0
        passages = x["passages"]
        par_four = passages / n_main / 6.0 if n_main > 0 else None
        arret = (x["no_fuel"] + x["no_ingr"]) / x["four_samples"] * 100 if x["four_samples"] else None
        pl = list(x["plaques"].values())
        out[f] = {
            "passages": passages, "n_main_moy": round(n_main, 2),
            "passages_par_four_10min": None if par_four is None else round(par_four, 2),
            "arret_pct": None if arret is None else round(arret, 2),
            "no_fuel_pct": None if not x["four_samples"] else round(x["no_fuel"] / x["four_samples"] * 100, 2),
            "no_ingr_pct": None if not x["four_samples"] else round(x["no_ingr"] / x["four_samples"] * 100, 2),
            "main_working_pct": None if not x["ns_main"] else round(x["ws_main"] / x["ns_main"] * 100, 1),
            "main_eq_pct": None if not x["nom_main"] else round(x["eq_main"] / x["nom_main"] * 100, 1),
            "plaques_min": None if not pl else round(statistics.mean(pl), 1),
        }
    ep = None
    for mn in sorted(coal):
        if mn >= 3 and coal[mn] <= 5:
            ep = mn
            break
    cs = [v for k, v in coal.items() if k >= 3]
    out["charbon"] = {"premiere_minute_epuisee": ep, "minimum": min(cs) if cs else None, "moyenne": round(statistics.mean(cs), 1) if cs else None}
    sm = r["player"]["smelt"] + r["scarlet"]["smelt"] + r["azure"]["smelt"]
    if sm:
        rates = [s[3] / s[4] for s in sm if s[4] > 0]  # unites / places, par visite qui avait de la place
        out["charge"] = {"visites": len(sm), "unites_par_place_mediane": round(statistics.median(rates), 3) if rates else None}
    return out


def comparer(graine, base, lot):
    rb, cb = releves(base)
    rl, cl = releves(lot)
    sb, sl = resume(rb, cb), resume(rl, cl)
    return {"graine": graine, "base": sb, "lot": sl}


def afficher(res):
    for g in res:
        print("== graine %s" % g["graine"])
        for f in FORCES:
            b, l = g["base"][f], g["lot"][f]
            def fx(v):
                return "-" if v is None else str(v)
            rapport = ""
            if b["passages_par_four_10min"] and l["passages_par_four_10min"] is not None:
                rapport = " rapport %.2f" % (l["passages_par_four_10min"] / b["passages_par_four_10min"])
            print("  %-8s passages %5s -> %5s | par four/10min %s -> %s%s | fours main %s -> %s" % (
                f, b["passages"], l["passages"], fx(b["passages_par_four_10min"]), fx(l["passages_par_four_10min"]), rapport,
                b["n_main_moy"], l["n_main_moy"]))
            print("           arret %s%% -> %s%% (no_fuel %s -> %s, no_ingr %s -> %s) | main working %s%% -> %s%% eq %s%% -> %s%% | plaques/min %s -> %s" % (
                fx(b["arret_pct"]), fx(l["arret_pct"]), fx(b["no_fuel_pct"]), fx(l["no_fuel_pct"]), fx(b["no_ingr_pct"]), fx(l["no_ingr_pct"]),
                fx(b["main_working_pct"]), fx(l["main_working_pct"]), fx(b["main_eq_pct"]), fx(l["main_eq_pct"]),
                fx(b["plaques_min"]), fx(l["plaques_min"])))
        print("  charbon (equipe) epuise a m%s -> m%s | min %s -> %s | moyenne %s -> %s" % (
            g["base"]["charbon"]["premiere_minute_epuisee"], g["lot"]["charbon"]["premiere_minute_epuisee"],
            g["base"]["charbon"]["minimum"], g["lot"]["charbon"]["minimum"], g["base"]["charbon"]["moyenne"], g["lot"]["charbon"]["moyenne"]))
        if "charge" in g["lot"]:
            print("  charge au moteur : %s visites, unites/place mediane %s" % (g["lot"]["charge"]["visites"], g["lot"]["charge"]["unites_par_place_mediane"]))


def verdict(res, jugement=("20261020", "123456789", "271828182", "1618033988")):
    ok = {}
    rap, ecarts, plaq, plaq_min_player = [], {f: [] for f in FORCES}, [], []
    c1 = True
    for g in res:
        if g["graine"] not in jugement:
            continue
        for f in FORCES:
            b, l = g["base"][f], g["lot"][f]
            if b["passages"] >= 30 and b["passages_par_four_10min"]:
                r = (l["passages_par_four_10min"] or 0) / b["passages_par_four_10min"]
                rap.append(r)
                if r > 0.5:
                    c1 = False
            if b["arret_pct"] is not None and l["arret_pct"] is not None:
                ecarts[f].append(l["arret_pct"] - b["arret_pct"])
            if b["plaques_min"] and l["plaques_min"] is not None:
                q = l["plaques_min"] / b["plaques_min"]
                plaq.append(q)
                if f == "player":
                    plaq_min_player.append(q)
    ok["C1"] = bool(rap) and c1 and statistics.median(rap) <= 0.5
    c2 = all(statistics.median(v) <= 2.0 for v in ecarts.values() if v) and all(e <= 10.0 for e in ecarts["player"])
    ok["C2"] = c2
    ok["C3"] = bool(plaq) and statistics.median(plaq) >= 0.97 and all(q >= 0.85 for q in plaq_min_player)
    c4 = True
    for g in res:
        if g["graine"] not in jugement:
            continue
        bb, ll = g["base"]["charbon"], g["lot"]["charbon"]
        if ll["premiere_minute_epuisee"] is not None and (bb["premiere_minute_epuisee"] is None or ll["premiere_minute_epuisee"] < bb["premiere_minute_epuisee"]):
            c4 = False
        if bb["minimum"] is not None and ll["minimum"] is not None and ll["minimum"] < 0.8 * bb["minimum"]:
            c4 = False
    ok["C4"] = c4
    print("\nVERDICT (graines de jugement presentes : %s)" % ",".join(g["graine"] for g in res if g["graine"] in jugement))
    print("  rapports de passages : %s (mediane %s)" % ([round(x, 2) for x in rap], round(statistics.median(rap), 2) if rap else "-"))
    print("  ecarts d'arret (points) : %s" % {f: [round(x, 1) for x in v] for f, v in ecarts.items()})
    print("  rapports de plaques : %s (mediane %s)" % ([round(x, 2) for x in plaq], round(statistics.median(plaq), 2) if plaq else "-"))
    for k in sorted(ok):
        print("  %s : %s" % (k, "TENU" if ok[k] else "NON TENU"))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base")
    ap.add_argument("--lot")
    ap.add_argument("--paire", nargs=3, action="append", default=[], metavar=("GRAINE", "BASE", "LOT"))
    ap.add_argument("--json")
    a = ap.parse_args()
    res = []
    if a.base and a.lot:
        res.append(comparer(os.path.basename(a.base).replace("base-", ""), a.base, a.lot))
    for g, b, l in a.paire:
        res.append(comparer(g, b, l))
    if not res:
        ap.error("rien a comparer")
    afficher(res)
    verdict(res)
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(res, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    sys.exit(main())
