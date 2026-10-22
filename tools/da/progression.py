# -*- coding: utf-8 -*-
"""Règle de dominance de puissance (charte §5) appliquée aux aperçus V3 phase 1, niveaux impairs (époques).
Usage : python progression.py <mesures_apercus.json>"""
import json, sys
A = json.load(open(sys.argv[1], encoding="utf-8"))
KEYS = ("masse_tuiles2", "petites_pieces", "foyers_lumineux", "part_massive", "laplacien_moyen", "petites_pieces_par_tuile2")
def emprise(r):
    w, h = [float(x) for x in r["cote_emprise"].split("x")]
    return w * h
for f in ("mitrailleuse", "laser", "assembleur", "centre"):
    rows = sorted([r for r in A if r["famille"] == f and (f == "centre" or r["niveau"] % 2 == 1)], key=lambda r: r["epoque"])
    dom = 0; pairs = 0; mass_up = 0; pieces_up = 0; dens_up = 0; massive_ok = 0
    lines = []
    for a, b in zip(rows, rows[1:]):
        pairs += 1
        q = [(emprise(b), emprise(a)), (b["masse_tuiles2"], a["masse_tuiles2"]), (b["petites_pieces"], a["petites_pieces"]),
             (b["foyers_lumineux"], a["foyers_lumineux"])]
        ge = all(x >= y for x, y in q); gt = sum(1 for x, y in q if x > y)
        d = ge and gt >= 2
        dom += d
        mass_up += b["masse_tuiles2"] > a["masse_tuiles2"]
        pieces_up += b["petites_pieces"] > a["petites_pieces"]
        dens_up += b["petites_pieces_par_tuile2"] >= a["petites_pieces_par_tuile2"] * 0.95
        massive_ok += b["part_massive"] >= 0.88
        lines.append("ép.%d->%d masse %.1f->%.1f pièces %d->%d foyers %d->%d massive %.2f->%.2f : %s" % (
            a["epoque"], b["epoque"], a["masse_tuiles2"], b["masse_tuiles2"], a["petites_pieces"], b["petites_pieces"],
            a["foyers_lumineux"], b["foyers_lumineux"], a["part_massive"], b["part_massive"], "DOMINE" if d else "non"))
    print("%s : dominance %d/%d ; masse en hausse %d/%d ; pièces totales en hausse %d/%d ; densité maintenue %d/%d ; part massive >= 0,88 : %d/%d"
          % (f, dom, pairs, mass_up, pairs, pieces_up, pairs, dens_up, pairs, massive_ok, pairs))
    first, last = rows[0], rows[-1]
    print("   première époque mesurée (%d) -> époque 15 : masse x%.2f, pièces x%.2f, densité x%.2f, foyers %d -> %d"
          % (first["epoque"], last["masse_tuiles2"] / first["masse_tuiles2"], last["petites_pieces"] / max(1, first["petites_pieces"]),
             last["petites_pieces_par_tuile2"] / first["petites_pieces_par_tuile2"], first["foyers_lumineux"], last["foyers_lumineux"]))
    for l in lines:
        print("     " + l)
