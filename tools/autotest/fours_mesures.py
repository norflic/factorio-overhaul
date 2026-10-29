# -*- coding: utf-8 -*-
"""Lot FOURS (29/10) : lecture comparee des scenarios provoques fours-refill / fours-mains, AVEC la regle et TEMOIN (regle coupee).

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/fours_mesures.py --refill <archive regle> <archive temoin>
                                                              [--mains <archive regle> <archive temoin>]
Chaque archive est un dossier de banc (benchmark.log ou benchmark.log.gz) ; la ligne lue est
« RESULTAT cle=valeur ... » ecrite par scenarios/fours_common.lua. Criteres : fo-logs/2026-10-29_CORR/FOURS/criteres.md.
Code de sortie 0 si tous les criteres lus sont tenus, 1 sinon.
"""
import argparse
import gzip
import os
import re
import sys

RE_RES = re.compile(r"RESULTAT (.*)$")
RE_BILAN = re.compile(r"\[FO-FOURS-[\w-]+\] BILAN : (\d+) OK, (\d+) ECHEC")


def lire(dossier):
    for nom in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(dossier, nom)
        if os.path.exists(p):
            op = gzip.open if nom.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as f:
                txt = f.read()
            res = None
            bilan = None
            for ligne in txt.splitlines():
                m = RE_RES.search(ligne)
                if m:
                    res = {}
                    for kv in m.group(1).split():
                        k, _, v = kv.partition("=")
                        res[k] = float(v)
                m = RE_BILAN.search(ligne)
                if m:
                    bilan = (int(m.group(1)), int(m.group(2)))
            if res is None:
                raise SystemExit("aucune ligne RESULTAT dans " + p)
            return res, bilan
    raise SystemExit("pas de benchmark.log dans " + dossier)


def ratio(a, b):
    return a / b if b else (0.0 if a == 0 else float("inf"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--refill", nargs=2, metavar=("REGLE", "TEMOIN"))
    ap.add_argument("--mains", nargs=2, metavar=("REGLE", "TEMOIN"))
    a = ap.parse_args()
    ok = True
    if a.refill:
        r, br = lire(a.refill[0])
        t, bt = lire(a.refill[1])
        print("== S1 fours-refill (5 min, 4 fours, coffre de 1200 minerais, plaques consommees par le banc) ==")
        print("%-28s %10s %10s" % ("", "regle", "temoin"))
        for k in ("passages", "charges_entree", "charges_combustible", "visites", "visites_a_vide", "plaques",
                  "sec_sans_entree", "sec_sans_combustible", "minerai_coffre", "minerai_fours"):
            print("%-28s %10g %10g" % (k, r[k], t[k]))
        print("bilans du scenario : regle %s, temoin %s" % (br, bt))
        c1 = r["passages"] <= 0.5 * t["passages"] and t["passages"] >= 4
        c2 = r["plaques"] >= 0.9 * t["plaques"]
        c3 = (r["sec_sans_entree"] + r["sec_sans_combustible"]) <= 2 * (t["sec_sans_entree"] + t["sec_sans_combustible"]) + 15
        print("R1 passages regle <= 50 %% du temoin (temoin >= 4) : %s  (rapport %.2f)" % ("TENU" if c1 else "NON TENU", ratio(r["passages"], t["passages"])))
        print("R2 plaques regle >= 90 %% du temoin : %s  (rapport %.2f)" % ("TENU" if c2 else "NON TENU", ratio(r["plaques"], t["plaques"])))
        print("R3 secondes a sec (entree + combustible) <= 2 x temoin + 15 s : %s" % ("TENU" if c3 else "NON TENU"))
        ok = ok and c1 and c2 and c3
    if a.mains:
        r, br = lire(a.mains[0])
        t, bt = lire(a.mains[1])
        print("== S2 fours-mains (10 min, courant coupe : minage a la main seul) ==")
        print("%-28s %10s %10s" % ("", "regle", "temoin"))
        for k in ("visites", "visites_a_vide", "charge_mod", "collecte_mod", "charbon_mod", "plaques", "minerai_porte",
                  "minerai_coffre", "minerai_fours"):
            print("%-28s %10g %10g" % (k, r[k], t[k]))
        print("bilans du scenario : regle %s, temoin %s" % (br, bt))
        m1 = r["visites_a_vide"] == 0
        prov = t["visites_a_vide"] >= 3
        m2 = r["plaques"] >= 0.95 * t["plaques"]
        print("M1 tournees a vide : regle %g, temoin %g : %s" % (r["visites_a_vide"], t["visites_a_vide"],
              ("TENU" if m1 else "NON TENU") + ("" if prov else " ; NON DEMONTRE : le temoin n'a pas au moins 3 tournees a vide")))
        print("M2 plaques/min regle >= 95 %% du temoin : %s  (rapport %.2f)" % ("TENU" if m2 else "NON TENU", ratio(r["plaques"], t["plaques"])))
        ok = ok and m1 and prov and m2
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
