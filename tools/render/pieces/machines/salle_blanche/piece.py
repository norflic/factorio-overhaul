"""Pièce du pipeline : SALLE BLANCHE (fo-cleanroom, 5x5, âge 10, sans niveaux), lot CALC-SALLE-BLANCHE (30/10).

Format de tools/render/README.md (PIECE + build(S, C, variant)). Variantes : s1 à s4 (silhouettes d'essai, modele.py).
Une seule pose (machine à recette : le sprite ne tourne pas ; les raccords de fluide sont dessinés par le moteur).
Matières : celles de l'âge 10 du kit commun (commun/ages.py : anthracite, gris_tech, acier_tech, rivet_tech, bleu_tech,
câbles rouge et bleu, voyants bleus « emit ») + 4 matières propres : sb_panneau et sb_panneau2 (bardage gris clair,
#A8ADB3 de DESIGN_EPOQUES §5, âge 10), sb_noir (noir mat #222428) et sb_ambre (intérieur de lithographie, émissif,
éteint dans la couche principale). Rendu : rendre.py ; feuilles de jeu : feuilles.py.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.normpath(os.path.join(HERE, "..", "..", "levels", "commun"))
for p in (COMMUN, HERE):
    if p not in sys.path:
        sys.path.insert(0, p)

EPOQUE = 10
VARIANTES = ("s1", "s2", "s3", "s4", "r1", "r2", "r3", "r4", "r2b")


def _variants():
    v = {}
    for n in VARIANTES:
        v[n] = {"dest": "machines/salle-blanche/" + n, "anchor_tiles": (0.0, 0.0), "side": 5, "epoch": EPOQUE,
                "part": "machine", "level": 0, "nuit": False, "sous_vanilla": False}
    return v


PIECE = {
    "name": "sb",
    "variants": _variants(),
    "margin_px": 40,
    "calib": {"LIGHT_HOLDOUT": True},
}


def margin_px(name):
    return 40 + int(64 * 1.3)


def matieres_sb(metal, M):
    import ages
    ages.matieres(10, metal, M)
    # bardage de la salle blanche : gris clair froid (#A8ADB3), peu métallique, patiné (règle 2 de la bible : p95 ≤ 240)
    # tour 2 (30/10) : bardage assombri (médiane du corps du tour 1 : 94 à 117/255, bible 82 ± 10)
    metal("sb_panneau", (0.25, 0.262, 0.28), rough=0.42, met=0.08, grain=0.07, gscale=30.0, dirt=0.45, stain=0.3,
          sscale=6.0, wear=0.5, streak=0.35, mottle=0.15)
    metal("sb_panneau2", (0.17, 0.178, 0.19), rough=0.45, met=0.12, grain=0.07, gscale=30.0, dirt=0.45, stain=0.3,
          sscale=6.0, wear=0.6, streak=0.3, mottle=0.15)
    metal("sb_clair", (0.52, 0.53, 0.55), rough=0.3, met=0.15, grain=0.06, gscale=30.0, dirt=0.4, stain=0.2,
          wear=0.4)
    metal("sb_noir", (0.016, 0.018, 0.021), rough=0.6, met=0.1, grain=0.08, gscale=36.0, dirt=0.3, stain=0.2,
          wear=0.6)


def build(S, C, variant):
    from types import SimpleNamespace
    import ages
    import kit as K
    import modele
    import tour2
    sil = dict(modele.SILHOUETTES, **tour2.SILHOUETTES)
    K.PREFIXE = "sb"
    ep = SimpleNamespace(FOYER=ages.FOYER[EPOQUE], matieres=matieres_sb)
    M = K.materials(S, EPOQUE, ep)
    amb = S.mat_emissive("sb_e10_ambre", (1.0, 0.70, 0.22), strength=1.0, base=(0.012, 0.009, 0.004), main_scale=0.0)
    p = amb.node_tree.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in p.inputs:
        p.inputs["Specular IOR Level"].default_value = 0.0
    M["sb_ambre"] = amb
    if variant == "r2b":
        # fond des verrières en deux tons (intérieur lu comme un volume, essai du tour 2b)
        a2 = S.mat_emissive("sb_e10_ambre2", (1.0, 0.62, 0.16), strength=0.55, base=(0.008, 0.006, 0.003),
                            main_scale=0.0)
        p2 = a2.node_tree.nodes["Principled BSDF"]
        p2.inputs["Roughness"].default_value = 1.0
        if "Specular IOR Level" in p2.inputs:
            p2.inputs["Specular IOR Level"].default_value = 0.0
        M["sb_ambre2"] = a2
    g = K.Geo(S, C, M, "SB%s" % variant, 0.0, seed=1000 + VARIANTES.index(variant))
    c = modele.Ctx(g, C, M)
    sil[variant](c)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos), "leds": c.leds}
