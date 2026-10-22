# -*- coding: utf-8 -*-
"""Seuils de la charte DA_FACTORIO (planchers = refus automatique ; cibles = médiane vanilla).
Calibrés le 22/10/2026 sur 28 bâtiments vanilla 1.1.91 et la cheminée V0 validée.
Usage : python seuils.py <mesures_vanilla.json> <mesures_apercus.json>"""
import json, sys
import numpy as np

def big(r):
    w, h = [float(x) for x in r["cote_emprise"].split("x")]
    return w * h >= 16

# (identifiant, clé, opérateur, plancher petit (<= 3x3), plancher grand (>= 4x4), cible)
SEUILS = [
    ("D1", "laplacien_moyen", ">=", 27, 22, 31),
    ("D2", "laplacien_zoom1", ">=", 40, 33, 47),
    ("D3", "petites_pieces_par_tuile2", ">=", 24, 24, 29),
    ("D4", "contraste_local_7px", ">=", 22, 18, 27),
    ("D5", "part_contours", ">=", 0.30, 0.24, 0.40),
    ("P1", "grain_surfaces", ">=", 3.4, 3.4, 4.7),
    ("P2", "variance_basse_freq", ">=", 16, 16, 20),
    ("P3", "part_creux_sombres", ">=", 0.10, 0.10, 0.18),
    ("P4", "part_surfaces_planes", "<=", 0.45, 0.48, 0.34),
    ("C1", "lum_p50", "<=", 76, 76, 60),
    ("C1b", "lum_p50", ">=", 43, 43, 50),
    ("C2", "lum_p95", "<=", 216, 216, 185),
    ("C3", "part_teinte_chaude_corps", ">=", 0.70, 0.70, 0.95),
    ("C4", "part_saturee", "<=", 0.13, 0.13, 0.04),
    ("C5", "part_saturee_hors_lumineux", "<=", 0.04, 0.04, 0.02),
    ("C6", "plus_grande_plage_saturee_toutes_tuiles2", "<=", 0.35, 0.35, 0.10),
    ("C7", "part_peinte_froide_hors_lumineux", "<=", 0.06, 0.06, 0.00),
    ("C8", "part_quasi_blanc", "<=", 0.04, 0.04, 0.015),
    ("L1", "zone_lumineuse_part", "<=", 0.15, 0.15, 0.06),
    ("L2", "plus_grand_foyer_lumineux_tuiles2", "<=", 0.45, 0.45, 0.15),
    ("M1", "remplissage_emprise", ">=", 0.60, 0.60, 0.80),
    ("M2", "masse_par_tuile_emprise", ">=", 0.65, 0.65, 0.87),
    ("M3", "part_massive", ">=", 0.88, 0.88, 0.97),
]

def verdict(r):
    out = []
    for sid, k, op, ps, pg, cible in SEUILS:
        p = pg if big(r) else ps
        v = r[k]
        ok = v >= p if op == ">=" else v <= p
        out.append((sid, k, v, op, p, ok))
    return out

if __name__ == "__main__":
    V = json.load(open(sys.argv[1], encoding="utf-8"))
    A = json.load(open(sys.argv[2], encoding="utf-8"))
    print("Vanilla : seuils échoués par bâtiment")
    for r in V:
        f = [s[0] for s in verdict(r) if not s[5]]
        print("  %-22s %-5s %d %s" % (r["nom"], r["cote_emprise"], len(f), ",".join(f)))
    print("Taux d'échec par seuil (vanilla / V3 phase 1 / cheminées)")
    P = [a for a in A if not a["famille"].startswith("chem")]
    Ch = [a for a in A if a["famille"].startswith("chem")]
    for i, s in enumerate(SEUILS):
        fv = sum(1 for r in V if not verdict(r)[i][5])
        fp = sum(1 for r in P if not verdict(r)[i][5])
        fc = [r["famille"] for r in Ch if not verdict(r)[i][5]]
        print("  %-4s %-42s %s plancher %s/%s cible %s : vanilla %2d/%d  V3p1 %3d/%d  cheminées en échec : %s" % (
            s[0], s[1], s[2], s[3], s[4], s[5], fv, len(V), fp, len(P), ",".join(fc) or "aucune"))
    print("V3 phase 1 : seuils échoués par niveau")
    for f in ("mitrailleuse", "laser", "assembleur", "centre"):
        rows = [r for r in P if r["famille"] == f]
        print("  %-12s " % f + " ".join("n%02d:%d" % (r["niveau"], sum(1 for s in verdict(r) if not s[5])) for r in rows))
    tot = [sum(1 for s in verdict(r) if not s[5]) for r in P]
    print("  niveaux V3p1 sans aucun échec : %d/%d ; médiane des échecs : %.1f" % (sum(1 for t in tot if t == 0), len(P), np.median(tot)))
    tv = [sum(1 for s in verdict(r) if not s[5]) for r in V]
    print("  vanilla : médiane des échecs %.1f, max %d, sans échec %d/%d" % (np.median(tv), max(tv), sum(1 for t in tv if t == 0), len(V)))
    for r in Ch:
        f = [s[0] for s in verdict(r) if not s[5]]
        print("  %-26s échecs : %d %s" % (r["famille"], len(f), ",".join(f)))
