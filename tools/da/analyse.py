# -*- coding: utf-8 -*-
"""
Synthèse des mesures : statistiques vanilla (tous, basiques, avancés), cheminée V0, aperçus V3 phase 1
par famille et par ère, écarts chiffrés, tendance avec l'époque (Spearman).

    python analyse.py <mesures_vanilla.json> <mesures_apercus_v3p1.json> > analyse.txt
"""
import json
import sys

import numpy as np

V = json.load(open(sys.argv[1], encoding="utf-8"))
A = json.load(open(sys.argv[2], encoding="utf-8"))

KEYS = [
    ("laplacien_moyen", "Laplacien moyen |∇²L| (lum/px)", 1),
    ("laplacien_zoom1", "Laplacien au zoom 1 (32 px/t)", 1),
    ("part_contours", "Part de pixels de contour (Sobel>12)", 3),
    ("contours_par_tuile", "Pixels de contour par tuile²", 0),
    ("petites_pieces_par_tuile2", "Petites pièces (DoG) par tuile² de corps", 1),
    ("petites_pieces", "Petites pièces (total)", 0),
    ("contraste_local_7px", "Contraste local (σ 7×7, lum)", 1),
    ("lum_p5", "Luminance p5", 0),
    ("lum_p50", "Luminance p50", 0),
    ("lum_p95", "Luminance p95", 0),
    ("saturation_moyenne", "Saturation moyenne du corps", 2),
    ("part_saturee", "Part saturée (S≥0,5 et V≥0,5)", 3),
    ("part_saturee_hors_lumineux", "Part saturée hors lumineux", 3),
    ("part_des_satures_qui_sont_lumineux", "Part des saturés situés sur un lumineux", 2),
    ("part_saturee_froide_toutes", "Part saturée froide (70-330°)", 3),
    ("plus_grande_plage_saturee_toutes_part", "Plus grande plage saturée (part du corps)", 3),
    ("plus_grande_plage_saturee_toutes_tuiles2", "Plus grande plage saturée (tuiles²)", 3),
    ("part_peinte_hors_lumineux", "Part peinte (S≥0,35, V≥0,3) hors lumineux", 3),
    ("part_peinte_froide_hors_lumineux", "Part peinte froide hors lumineux", 3),
    ("part_teinte_chaude_corps", "Part de teinte chaude du corps (chroma≥0,08)", 2),
    ("zone_lumineuse_part", "Zone lumineuse (part du corps)", 3),
    ("foyers_lumineux", "Foyers lumineux (≥16 px)", 0),
    ("plus_grand_foyer_lumineux_tuiles2", "Plus grand foyer lumineux (tuiles²)", 3),
    ("halo_nuit_tuiles2", "Halo de nuit (draw_as_light > 0,25, tuiles²)", 2),
    ("part_quasi_blanc", "Part quasi blanche (L≥220) hors lumineux", 3),
    ("grain_surfaces", "Grain des surfaces planes |L-G1| (lum)", 2),
    ("variance_basse_freq", "Variance basse fréquence σ(G2-G8) (lum)", 2),
    ("part_creux_sombres", "Part de creux sombres (L<G3-20)", 3),
    ("part_aretes_claires", "Part d'arêtes claires (L>G3+20)", 3),
    ("part_surfaces_planes", "Part de surfaces planes (Sobel<6)", 3),
    ("remplissage_emprise", "Remplissage de l'emprise", 2),
    ("masse_par_tuile_emprise", "Masse (tuiles² de corps / tuile d'emprise)", 2),
    ("masse_tuiles2", "Masse (tuiles² de corps)", 1),
    ("O_depassement_haut", "O : dépassement au-dessus de l'emprise (tuiles)", 2),
    ("part_massive", "Part massive (ouverture 17 px)", 2),
    ("part_tres_massive", "Part très massive (ouverture 33 px)", 2),
    ("remplissage_boite", "Remplissage de la boîte englobante", 2),
]


def st(rows, k):
    x = np.array([r[k] for r in rows], float)
    return x.min(), np.percentile(x, 25), np.median(x), np.percentile(x, 75), x.max()


def fmt(v, d):
    return ("%." + str(d) + "f") % v


print("=" * 110)
print("1. VANILLA 1.1.91 : %d bâtiments (hr, image 0, tourelles en pose E)" % len(V))
print("   basiques : " + ", ".join(r["nom"] for r in V if r["groupe"] == "basique"))
print("   avancés  : " + ", ".join(r["nom"] for r in V if r["groupe"] == "avance"))
print("=" * 110)
grp = {"tous": V, "basiques": [r for r in V if r["groupe"] == "basique"],
       "avances": [r for r in V if r["groupe"] == "avance"]}
print("%-50s | %-34s | %-9s | %-9s" % ("indicateur", "tous : min / p25 / méd / p75 / max", "méd bas.", "méd av."))
for k, lab, d in KEYS:
    a = st(grp["tous"], k)
    print("%-50s | %-34s | %-9s | %-9s" % (lab, " / ".join(fmt(x, d) for x in a), fmt(st(grp["basiques"], k)[2], d),
                                           fmt(st(grp["avances"], k)[2], d)))

print()
print("1 bis. Tableau par bâtiment (vanilla)")
cols = ["cote_emprise", "laplacien_moyen", "part_contours", "petites_pieces_par_tuile2", "petites_pieces",
        "contraste_local_7px", "grain_surfaces", "part_creux_sombres", "lum_p50", "saturation_moyenne",
        "part_saturee", "zone_lumineuse_part", "foyers_lumineux", "remplissage_emprise", "masse_tuiles2",
        "O_depassement_haut", "part_massive"]
print("%-22s " % "nom" + " ".join("%8s" % c[:8] for c in cols))
for r in sorted(V, key=lambda r: (r["palier_vanilla"], r["nom"])):
    vals = []
    for c in cols:
        v = r[c]
        vals.append("%8s" % (v if isinstance(v, str) else ("%.3f" % v if abs(v) < 1 else "%.1f" % v)))
    print("%-22s " % ("%s(T%d)" % (r["nom"], r["palier_vanilla"])) + " ".join(vals))

# progression interne au vanilla
print()
print("1 ter. Chaînes de progression vanilla (rapport palier haut / palier bas)")
chains = [("assembling-machine-1", "assembling-machine-2", "assembling-machine-3"),
          ("stone-furnace", "steel-furnace", "electric-furnace"),
          ("gun-turret", "laser-turret", "artillery-turret"),
          ("steam-engine", "steam-turbine"), ("boiler", "heat-exchanger"),
          ("electric-mining-drill", "pumpjack", "oil-refinery"),
          ("lab", "beacon", "roboport", "nuclear-reactor", "rocket-silo")]
byname = {r["nom"]: r for r in V}
for ch in chains:
    print("  " + " -> ".join("%s [%s]" % (n, byname[n]["cote_emprise"]) for n in ch))
    for k in ("laplacien_moyen", "petites_pieces_par_tuile2", "petites_pieces", "masse_tuiles2", "lum_p50",
              "part_saturee", "zone_lumineuse_part", "O_depassement_haut"):
        print("     %-28s " % k + "  ".join("%9.3f" % byname[n][k] for n in ch))

print()
print("=" * 110)
print("2. CHEMINÉE V0 validée (21/10) et V0b finale")
print("=" * 110)
ch = [r for r in A if r["famille"].startswith("cheminee")]
for k, lab, d in KEYS:
    print("%-50s | " % lab + " | ".join("%s=%s" % (r["famille"], fmt(r[k], d)) for r in ch))

print()
print("=" * 110)
print("3. APERÇUS V3 PHASE 1 (rejetés le 22/10) : par famille, par ère (moyenne des niveaux de l'ère)")
print("=" * 110)
fams = ["mitrailleuse", "laser", "assembleur", "centre"]
vref = {"mitrailleuse": "gun-turret", "laser": "laser-turret", "assembleur": "assembling-machine-2", "centre": None}
med_all = {k: st(V, k)[2] for k, _, _ in KEYS}
med_adv = {k: st(grp["avances"], k)[2] for k, _, _ in KEYS}
focus = ["laplacien_moyen", "petites_pieces_par_tuile2", "contraste_local_7px", "grain_surfaces", "part_creux_sombres",
         "lum_p50", "lum_p95", "saturation_moyenne", "part_teinte_chaude_corps", "part_saturee",
         "plus_grande_plage_saturee_toutes_part", "plus_grande_plage_saturee_toutes_tuiles2", "part_peinte_froide_hors_lumineux",
         "zone_lumineuse_part", "plus_grand_foyer_lumineux_tuiles2", "halo_nuit_tuiles2", "part_quasi_blanc", "laplacien_zoom1", "petites_pieces",
         "remplissage_emprise", "masse_par_tuile_emprise", "part_massive", "O_depassement_haut"]
for f in fams:
    rows = [r for r in A if r["famille"] == f]
    print()
    print("--- %s (%d niveaux mesurés) ; référence vanilla : %s" % (f, len(rows), vref[f]))
    print("%-38s %8s %8s %8s %8s %8s | %8s %8s %8s" % ("indicateur", "ère I", "ère II", "ère III", "ère IV", "ère V",
                                                       "vanilla", "méd van", "rho ép."))
    for k in focus:
        vals = []
        for era in range(5):
            rr = [r[k] for r in rows if era * 3 < r["epoque"] <= era * 3 + 3]
            vals.append("%8.3f" % np.mean(rr) if rr else "%8s" % "-")
        ref = "%8.3f" % byname[vref[f]][k] if vref[f] else "%8s" % "-"
        # corrélation de rang avec l'époque
        ep = np.array([r["epoque"] for r in rows], float)
        x = np.array([r[k] for r in rows], float)
        rk = lambda a: np.argsort(np.argsort(a)).astype(float)
        rho = np.corrcoef(rk(ep), rk(x))[0, 1] if x.std() > 0 else 0.0
        print("%-38s %s | %s %8.3f %8.2f" % (k, " ".join(vals), ref, med_all[k], rho))

print()
print("=" * 110)
print("4. ÉCARTS : part des niveaux V3 phase 1 sous le minimum vanilla (ou au-dessus du maximum)")
print("=" * 110)
tests = [("laplacien_moyen", "<", st(V, "laplacien_moyen")[0]),
         ("petites_pieces_par_tuile2", "<", st(V, "petites_pieces_par_tuile2")[0]),
         ("contraste_local_7px", "<", st(V, "contraste_local_7px")[0]),
         ("grain_surfaces", "<", st(V, "grain_surfaces")[0]),
         ("part_creux_sombres", "<", st(V, "part_creux_sombres")[0]),
         ("lum_p50", ">", st(V, "lum_p50")[4]),
         ("lum_p95", ">", st(V, "lum_p95")[4]),
         ("part_saturee", ">", st(V, "part_saturee")[4]),
         ("plus_grande_plage_saturee_toutes_part", ">", st(V, "plus_grande_plage_saturee_toutes_part")[4]),
         ("plus_grande_plage_saturee_toutes_tuiles2", ">", st(V, "plus_grande_plage_saturee_toutes_tuiles2")[4]),
         ("plus_grand_foyer_lumineux_tuiles2", ">", st(V, "plus_grand_foyer_lumineux_tuiles2")[4]),
         ("halo_nuit_tuiles2", ">", st(V, "halo_nuit_tuiles2")[4]),
         ("part_teinte_chaude_corps", "<", st(V, "part_teinte_chaude_corps")[0]),
         ("zone_lumineuse_part", ">", st(V, "zone_lumineuse_part")[4]),
         ("part_quasi_blanc", ">", st(V, "part_quasi_blanc")[4]),
         ("part_massive", "<", st(V, "part_massive")[0]),
         ("remplissage_emprise", "<", st(V, "remplissage_emprise")[0])]
for f in fams + ["tous"]:
    rows = [r for r in A if (r["famille"] == f or (f == "tous" and not r["famille"].startswith("cheminee")))]
    out = []
    for k, op, thr in tests:
        n = sum(1 for r in rows if (r[k] < thr if op == "<" else r[k] > thr))
        out.append("%s%s%.3f: %d/%d" % (k[:18], op, thr, n, len(rows)))
    print("%-13s " % f + " ; ".join(out))

print()
print("=" * 110)
print("5. NIVEAUX TÉMOINS (rapport au vanilla de la famille et à la médiane vanilla avancée)")
print("=" * 110)
wit = [("mitrailleuse", 11), ("mitrailleuse", 21), ("mitrailleuse", 29), ("laser", 11), ("laser", 21),
       ("laser", 29), ("assembleur", 11), ("assembleur", 21), ("assembleur", 29), ("centre", 6), ("centre", 11),
       ("centre", 15)]
for f, n in wit:
    r = [x for x in A if x["famille"] == f and x["niveau"] == n]
    if not r:
        continue
    r = r[0]
    ref = byname[vref[f]] if vref[f] else None
    parts = []
    for k in ("laplacien_moyen", "petites_pieces_par_tuile2", "grain_surfaces", "part_creux_sombres",
              "lum_p50", "part_saturee", "part_massive", "remplissage_emprise", "masse_tuiles2"):
        rv = r[k]
        parts.append("%s=%.3f (x%.2f van.fam, x%.2f méd.av.)" % (k, rv, rv / ref[k] if ref and ref[k] else float("nan"),
                                                               rv / med_adv[k] if med_adv[k] else float("nan")))
    print("%s n%02d (ép. %d) : " % (f, n, r["epoque"]) + " ; ".join(parts))

print()
print("=" * 110)
print("6. LOI D'ÉCHELLE VANILLA : petites pièces totales en fonction de la masse (tuiles²)")
print("=" * 110)
m = np.array([r["masse_tuiles2"] for r in V]); p = np.array([r["petites_pieces"] for r in V], float)
a, b = np.polyfit(np.log(m), np.log(p), 1)
print("log(pièces) = %.3f * log(masse) + %.3f  -> pièces ≈ %.1f × masse^%.2f" % (a, b, np.exp(b), a))
print("densité (pièces/tuile²) : méd. 2×2 = %.1f ; 3×3 = %.1f ; ≥ 4×4 = %.1f" % (
    np.median([r["petites_pieces_par_tuile2"] for r in V if r["cote_emprise"] in ("2x2",)]),
    np.median([r["petites_pieces_par_tuile2"] for r in V if r["cote_emprise"] in ("3x3",)]),
    np.median([r["petites_pieces_par_tuile2"] for r in V if r["cote_emprise"] in ("4x4", "5x5", "9x9", "5x3")])))
print("laplacien : méd. 2×2 = %.1f ; 3×3 = %.1f ; ≥ 4×4 = %.1f" % (
    np.median([r["laplacien_moyen"] for r in V if r["cote_emprise"] in ("2x2",)]),
    np.median([r["laplacien_moyen"] for r in V if r["cote_emprise"] in ("3x3",)]),
    np.median([r["laplacien_moyen"] for r in V if r["cote_emprise"] in ("4x4", "5x5", "9x9", "5x3")])))
for f in ("mitrailleuse", "laser", "assembleur", "centre"):
    rows = [r for r in A if r["famille"] == f]
    print("%-13s pièces totales par ère : " % f + " ; ".join(
        "%s=%.0f" % (e, np.mean([r["petites_pieces"] for r in rows if k * 3 < r["epoque"] <= k * 3 + 3]))
        for k, e in enumerate(["I", "II", "III", "IV", "V"]) if any(k * 3 < r["epoque"] <= k * 3 + 3 for r in rows)))
