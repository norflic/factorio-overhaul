"""Pièce Blender : ICÔNES de la monazite (lot design-icone-monazite, 30/10).

Retour du DC (30/10, vers 10 h 40) : « je viens de revoir les minerais, changez les icones mais si non c est pas mal ».
La forme M1 (rognons anguleux miel et résine, directions.py) est acceptée ; l'icône d'avant (galets ronds jaune pâle
de Z3) ne lui ressemble plus. Les icônes vanilla (icons/iron-ore.png, copper-ore, stone, coal, uranium-ore et leurs
images -1 à -3) sont un TAS de 3 à 5 morceaux DISTINCTS vus de 3/4, séparés par des jours, qui remplissent le cadre de
64 px ; l'icône tirée de cellule_icone (gisement.py) posait ses rognons au hasard sur un cercle : ils se touchaient et
se lisaient en une seule galette orange à 32 px.

Ici : le MÊME modèle de rognon que le gisement M1 (gisement.roche : 7 coupes, cassure (0,45 ; 0,80), 3 encoches,
lissage 34° ; matières de directions.MAT ; réglage CALIB["M1"]), mais des tas COMPOSÉS à la main (positions, tailles
et matières écrites dans COMPOS), à l'échelle K (rendu plus fin, réduit ensuite à 64 px). Une rangée de 4 tas espacés
de PAS tuiles : icône, puis les 3 images au sol (`pictures`). Aucun fichier du kit n'est modifié.

    python tools/render/with_render_lock.py -- py -3.9 tools/render/pieces/ressources/icones_monazite.py ...
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import directions as D  # noqa: E402
import gisement as G  # noqa: E402

PAS = 4.0          # tuiles entre deux tas (recadrage : la moitié de chaque côté)
K = 2.2            # échelle du tas : environ 2,6 tuiles de large, 170 px HR, réduits à 61 px
SERRE = 1.10       # positions × SERRE : des jours étroits entre les rognons, comme les icônes vanilla (essai 16 éch.)
# Relief de l'icône (essai 16 éch. : facettes planes et lisses, « plastique », à côté du relief grenu des morceaux
# vanilla) : bosselage par bruit, en coordonnées d'objet, sur la normale du Principled ; la couleur ne change pas.
RELIEF = dict(echelle=12.0, force=0.5, distance=0.03)
# Éclat résineux (essai 16c : faces mates et pâles, sans les reflets francs des icônes vanilla) : rugosité × LUSTRE
LUSTRE = 0.45
# Mesure contre les icônes vanilla (fer, cuivre, pierre : luminance moyenne 0,38 à 0,41, 5e centile 0,08 à 0,11,
# 95e 0,81 à 0,87, couverture 0,58 à 0,62 ; essai 32e : 0,55, 0,25, 0,76, 0,45) : couleur de base × SOMBRE (les
# reflets et le soleil font le clair)
SOMBRE = 0.92
# (essai 32f, SOMBRE 0,62 : un jaune sombre tourne à l'olive ; le sombre doit venir du côté d'ombre, pas de la couleur)
GRAIN = 1.6         # grain de couleur × GRAIN : le marbré des morceaux vanilla
# Taille × TAILLE (essai 16 éch. : les coupes de roche() rognent la sphère à 0,6 de « taille » environ ; les rognons
# flottaient dans des jours deux fois trop larges)
TAILLE = 1.65

# Un rognon : (x, y) en tuiles de jeu (y vers le sud, donc vers l'avant), taille (gisement.roche), matière, graine.
# Disposition des icônes vanilla : 2 morceaux derrière, 2 ou 3 devant, le plus gros devant à gauche, des jours entre.
COMPOS = {
    "A": dict(
        icone=[(-0.215, -0.185, 0.165, "monazite_or", 11), (0.205, -0.215, 0.150, "monazite_miel", 12),
               (-0.200, 0.175, 0.205, "monazite_or", 13), (0.235, 0.160, 0.185, "monazite_soufre", 14)],
        p1=[(-0.25, -0.12, 0.175, "monazite_miel", 21), (0.18, -0.24, 0.140, "monazite_or", 22),
            (0.27, 0.10, 0.160, "monazite_or", 23), (-0.10, 0.25, 0.180, "monazite_soufre", 24)],
        p2=[(-0.20, -0.17, 0.200, "monazite_or", 31), (0.22, -0.05, 0.215, "monazite_miel", 32),
            (-0.17, 0.25, 0.140, "monazite_or", 33)],
        p3=[(-0.28, -0.20, 0.130, "monazite_soufre", 41), (0.10, -0.25, 0.165, "monazite_or", 42),
            (-0.24, 0.13, 0.175, "monazite_miel", 43), (0.25, 0.12, 0.195, "monazite_or", 44),
            (0.00, 0.33, 0.115, "monazite_resine", 45)],
    ),
}
# B (essai 32g : rognons bas vus de dessus, presque tout le visible est éclairé, aucun côté d'ombre ; images au sol
# couvrant 0,33 du cadre contre 0,44 à 0,50 pour l'icône) : rognons plus hauts et un peu basculés, images au sol
# plus grosses.
COMPOS["B"] = dict(COMPOS["A"])
# C (planche de l'essai 32h : à 32 px, le rognon miel (orange-brun) tire l'icône vers la blende et la bauxite, et au
# sol, à 16 px, le tas se lit en miettes brunes moins nettes que l'or pâle d'avant) : or et soufre dominants, un seul
# petit rognon de résine par image au sol, couleur de base pleine (SOMBRE de C : 1,0).
def _dore(liste):
    out = []
    for x, y, t, m, g in liste:
        out.append((x, y, t, {"monazite_miel": "monazite_or", "monazite_resine": "monazite_miel"}.get(m, m), g))
    return out


COMPOS["C"] = {k: _dore(v) for k, v in COMPOS["A"].items()}
COMPOS["C"]["icone"][1] = COMPOS["C"]["icone"][1][:3] + ("monazite_soufre", 12)
COMPOS["C"]["p2"][2] = COMPOS["C"]["p2"][2][:3] + ("monazite_miel", 33)
REGLAGES = {"A": dict(aplat=0.95, bascule=0.0, images=1.0), "B": dict(aplat=1.25, bascule=0.30, images=1.15),
            "C": dict(aplat=1.25, bascule=0.30, images=1.15, sombre=1.0)}
# D (mesures de C, avec liseré : icône couverture 0,50, images au sol 0,37 à 0,46, contre 0,58 à 0,62 et 0,50 à 0,60
# pour fer, cuivre et pierre ; le gros rognon avant gauche se lit en galette et l'avant droit en corne) : rognons plus
# gros à positions égales (taille × 1,12 pour l'icône, × 1,40 pour les images), autres graines pour les deux rognons
# de devant de l'icône, bascule réduite.
COMPOS["D"] = {k: list(v) for k, v in COMPOS["C"].items()}
COMPOS["D"]["icone"][2] = COMPOS["D"]["icone"][2][:4] + (17,)
COMPOS["D"]["icone"][3] = COMPOS["D"]["icone"][3][:3] + ("monazite_or", 18)
REGLAGES["D"] = dict(aplat=1.15, bascule=0.20, images=1.0, taille_icone=1.12, taille_images=1.40, sombre=1.0)
# E (essai 32k, D : les images au sol se soudent en une masse, les morceaux ne se distinguent plus ; l'icône, serrée,
# touche presque) : entre C et D, positions des images × 1,10 et tailles × 1,27 ; icône × 1,06.
COMPOS["E"] = COMPOS["D"]
REGLAGES["E"] = dict(aplat=1.15, bascule=0.20, images=1.10, taille_icone=1.06, taille_images=1.15, sombre=1.0)
# F (essai 32l, E : quatre rognons distincts, mais un tas plus large que haut (le recul de 45° écrase la profondeur) :
# icône couverture 0,48 contre 0,58 à 0,62, l'icône carrée laisse du vide en haut et en bas ; image 1 encore soudée) :
# profondeur de l'icône × 1,30, image 1 écartée × 1,12.
COMPOS["F"] = dict(COMPOS["E"])
COMPOS["F"]["icone"] = [(x, y * 1.30, t, m, g) for x, y, t, m, g in COMPOS["E"]["icone"]]
COMPOS["F"]["p1"] = [(x * 1.12, y * 1.12, t, m, g) for x, y, t, m, g in COMPOS["E"]["p1"]]
REGLAGES["F"] = REGLAGES["E"]
# G (critique indépendante de l'icône, 30/10 vers 12 h, fo-logs/.../ICONES-MINERAIS/monazite/CRITIQUE.md) : F porte un
# rognon « soufre » jaune citron (le plus clair, arrière droit) et aucun rognon miel ou ambre, alors que la critique du
# gisement M1 (même matin, worktree minerai-monazite, non commitée à 12 h) retire le soufre et le brun-rouge pour UNE
# famille or-miel-ambre à éclat résineux (rugosité 0,24 à 0,28). Mêmes positions, tailles et graines que F (même
# géométrie) ; seules les matières changent : or_v / ambre / miel_v, copiées ici (MAT_ICONE) pour ne pas dépendre de
# l'état non commité de directions.py. Le miel franc reste hors de l'icône (32 px : blende, bauxite) ; l'ambre, entre
# l'or et le miel, donne la profondeur sans tirer vers le rouille.
MAT_ICONE = {
    "monazite_or_v": dict(color=(0.62, 0.40, 0.035), rough=0.24, met=0.0, grain=0.22, gscale=36.0, dirt=0.3),
    "monazite_miel_v": dict(color=(0.50, 0.25, 0.040), rough=0.26, met=0.0, grain=0.25, gscale=36.0, dirt=0.35),
    "monazite_ambre": dict(color=(0.58, 0.33, 0.035), rough=0.24, met=0.0, grain=0.22, gscale=36.0, dirt=0.3),
}
_VERS_G = {"monazite_or": "monazite_or_v", "monazite_soufre": "monazite_ambre", "monazite_miel": "monazite_miel_v"}
COMPOS["G"] = {k: [(x, y, t, _VERS_G.get(m, m), g) for x, y, t, m, g in v] for k, v in COMPOS["F"].items()}
REGLAGES["G"] = REGLAGES["F"]
ORDRE = ("icone", "p1", "p2", "p3")
FORME = dict(aplat=0.95, n_coupes=D.ROCHE_COUPES["M1"], cassure=D.ROCHE_CASSURE["M1"], creux=D.ROCHE_CREUX["M1"],
             lisse=D.ROCHE_LISSE["M1"])

PIECE = {"name": "icones-monazite", "variants": {k: {} for k in sorted(COMPOS)}, "margin_px": 32}
REGLAGES_DEFAUT = dict(aplat=FORME["aplat"], bascule=0.0, images=1.0, sombre=SOMBRE, taille_icone=1.0, taille_images=1.0)


def centre(i):
    return (PAS * (i - 1.5), 0.0)


def relief(mat):
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    n = N.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = RELIEF["echelle"]
    n.inputs["Detail"].default_value = 8.0
    n.inputs["Roughness"].default_value = 0.62
    L.new(tc.outputs["Object"], n.inputs["Vector"])
    b = N.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = RELIEF["force"]
    b.inputs["Distance"].default_value = RELIEF["distance"]
    L.new(n.outputs["Fac"], b.inputs["Height"])
    L.new(b.outputs["Normal"], p.inputs["Normal"])


def build(S, C, variant):
    rg = dict(REGLAGES_DEFAUT, **REGLAGES.get(variant, {}))
    mats = {}
    toutes = dict(D.MAT, **MAT_ICONE)
    for nom in sorted(toutes):
        m = toutes[nom]
        mats[nom] = S.mat_metal("ic_" + nom, tuple(c * rg["sombre"] for c in m["color"]), rough=m["rough"] * LUSTRE, metallic=m["met"], grain=m["grain"] * GRAIN,
                                grain_scale=m["gscale"] / K, dirt=m["dirt"], dirt_distance=0.08 * K)
        relief(mats[nom])
    comp = COMPOS[variant]
    for i, cle in enumerate(ORDRE):
        cx, cy = centre(i)
        ech = 1.0 if cle == "icone" else rg["images"]
        ech_t = ech * (rg["taille_icone"] if cle == "icone" else rg["taille_images"])
        for j, (x, y, t, mat, graine) in enumerate(comp[cle]):
            rng = random.Random(D.GRAINE["M1"] * 100 + graine)
            v, f = G.roche(rng, t * K * TAILLE * ech_t, aplat=rg["aplat"], n_coupes=FORME["n_coupes"],
                           cassure=FORME["cassure"], creux=FORME["creux"])
            bx, by, _ = C.tile_to_blender(cx + x * K * SERRE * ech, cy + y * K * SERRE * ech)
            bascule = rng.uniform(-rg["bascule"], rg["bascule"])
            vv = G._transforme(v, bascule, rng.uniform(0, 2 * math.pi), bx, by, -abs(bascule) * 0.12 * t * K)
            G._objet("ic_%s_%s_%d" % (variant, cle, j), vv, f, mats[mat], S, FORME["lisse"])
