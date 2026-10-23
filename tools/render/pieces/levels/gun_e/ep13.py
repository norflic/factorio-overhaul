"""Époque 13 · Antimatière (ère V cosmique, 6×6, niveaux 25 et 26). Constructeur de l'ère V. S'exécute DANS Blender.

Consigne du Directeur Créatif (23/10, vers 13 h 10, option A) : une ère V COSMIQUE qui suit l'histoire du jeu ;
13 ANTIMATIÈRE : « bouteilles magnétiques, lueur d'annihilation violette et bleue sur métal sombre » (le contenu reste :
fusion D-³He, antimatière, strangelets). Fiche : fo-logs/2026-10-23_V3E-ereV/FICHES_ERE_V.md §2 (fait foi).
L'ancien thème Fusion (céramique blanche, laque et plasma magenta, injecteurs) a été REFUSÉ (« la couleur ne me va
pas ») : ce fichier est réécrit au nouveau thème (ronde 1 de l'ère V, 23/10).

Image : un arsenal de CONFINEMENT. Chaque organe est une bouteille magnétique : un cylindre d'acier sombre serré dans
des bobinages de cuivre rouge, une fente où l'on voit un point violet suspendu. La lumière est ENFERMÉE.
Palette 60/30/10 : ACIER CANON gris froid à reflet prune (capots, pont, tours) ; CUIVRE ROUGE en bobinages serrés
(cerces, bagues, plaques) ; LUEUR D'ANNIHILATION violette (2/3) et bleue (1/3) en points.
Silhouette : cloche de verre fumé violet-noir cerclée de cuivre (bouteille géante) ; jupe conique ; pont à deux TOURS DE
CONFINEMENT (bastions) portant des batteries de bouteilles COUCHÉES ; trémie en silo trapu.
Canons : L 2,60 ; culasse = BOUTEILLE DE TIR couchée en travers, plus large que le faisceau (pose N : barre cuivrée au
pied du faisceau, jamais le pied d'un fût) ; capsules de confinement à l'alimentation.
Tuyaux : conduits SOLÉNOÏDES (manchon de bobinage tous les 0,25 t), brides de chrome, jauges de confinement.
"""
import math

from mathutils import Matrix, Vector

import corps
import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from corps import Y, at
from kit import TAU, basis

V = Vector

EPOQUE = 13
NOM = "Antimatière"
# violet d'annihilation #8F4BFF (2/3 au moins de la lumière) et bleu #4A7BFF (fiche §2 E5)
FOYER = dict(rgb=(0.561, 0.294, 1.0), rgb2=(0.29, 0.482, 1.0))
# fiche §2 E1 : 2,30 -> 2,60 (marge de +6 à 8 % laissée à 14 et 15)
CANON = dict(L=2.6, nb=6, rb=0.072, rr=0.175)
PLATEFORME = dict(chanfrein=1.3)
HABILLAGE = dict(jupe_cerclage="cuivre_bobine", chapeau="cuivre_bobine", tremie="acier_canon",
                 tourelleau="acier_canon", capots=("acier_canon", "cuivre_plaque"),
                 acier=("acier_noir", "chrome_fin"), rivets="chrome_fin", joints="acier_noir",
                 danger=("cuivre_bobine", "acier_noir"), peinture="cuivre_bobine", grille_nacelle="chrome_fin",
                 munitions=("chrome_fin", "verre_fume"),
                 plateforme=dict(motif="toles", mat="acier_canon", mat2="acier_canon2", fond="acier_noir",
                                 bord="acier_noir", boulons="chrome_fin", lisere="emit_soft"),
                 # pont à deux TOURS DE CONFINEMENT (bastions de la ronde 4, gardés : seule forme de pont qui se lit au
                 # zoom 1), cerclées de cuivre
                 forme_plateforme=dict(forme="bastions", flanc="acier_canon", flanc2="cuivre_bobine"),
                 # la tête devient une BOUTEILLE MAGNÉTIQUE géante : cloche de verre fumé violet-noir, meneaux et
                 # cerces de cuivre (bandes de bobinage), bouton d'annihilation
                 # ronde 2 : meneaux et cerces en VERRE VIOLET plus sombre (les meneaux radiaux noirs dessinaient un
                 # « vortex » vu de dessus : 13 pris pour le Néant) ; la cloche se lit en bulbe de verre lisse
                 forme_coupole=dict(forme="cloche", verre="verre_fume", mat="acier_canon", mat2="verre_meneau",
                                    lisere="emit"),
                 forme_jupe=dict(forme="conique", mat="acier_canon", mat2="acier_noir"),
                 forme_tremie=dict(forme="silo", mat="acier_canon", mat2="acier_noir"))
RECV = ("acier_canon", "acier_noir")


def matieres(metal, M):
    """Antimatière : acier canon gris froid à reflet prune (60), cuivre rouge de bobinage (30), verre fumé violet-noir,
    chrome fin, acier noir. Albédos de la fiche convertis en linéaire ; l'acier canon est remonté d'un cran (risque 1
    de la fiche : trois corps sombres de suite, éclaircir 13 d'abord)."""
    # ronde 2 (test à l'aveugle : 13 lu « disque violet sombre, vortex » et pris pour le Néant ; « même squelette » que
    # 14) : acier canon ÉCLAIRCI d'un cran (risque 1 de la fiche : éclaircir 13 d'abord) ; l'ère V descend désormais
    # nettement en valeur, 13 gris moyen, 14 indigo sombre, 15 noir
    metal("acier_canon", (0.2, 0.19, 0.245), rough=0.35, met=0.4, grain=0.1, gscale=34.0, rust=(0.1, 0.06, 0.08),
          ra=0.08, dirt=0.55, stain=0.35, sscale=5.0, wear=1.4, streak=0.35, mottle=0.25)
    metal("acier_canon2", (0.17, 0.16, 0.21), rough=0.36, met=0.4, grain=0.1, gscale=34.0, dirt=0.55, stain=0.35,
          sscale=5.0, wear=1.2, mottle=0.25)
    metal("acier_noir", (0.02, 0.02, 0.028), rough=0.4, met=0.5, grain=0.12, dirt=0.5, stain=0.2, wear=1.6)
    # cuivre de bobinage : métallicité 0,6 au plus (un cuivre à 0,9 sort sombre de dessus, ronde 3)
    metal("cuivre_bobine", (0.46, 0.14, 0.05), rough=0.35, met=0.6, grain=0.16, gscale=60.0, rust=(0.06, 0.12, 0.08),
          ra=0.06, dirt=0.55, stain=0.25, sscale=6.0, wear=0.9)
    metal("cuivre_plaque", (0.36, 0.115, 0.045), rough=0.4, met=0.5, grain=0.12, gscale=36.0, rust=(0.06, 0.12, 0.08),
          ra=0.1, dirt=0.7, stain=0.4, sscale=5.0, wear=1.4, streak=0.4)
    metal("chrome_fin", (0.33, 0.35, 0.4), rough=0.22, met=0.7, grain=0.08, dirt=0.35, stain=0.0, reflet="fin")
    # verre fumé de la cloche : violet-noir, lisse, OPAQUE (aucun sol vu au travers)
    # ronde 1 (aperçu r1a : la cloche se lisait « dôme de cuivre ») : verre plus VIOLET et un peu plus clair
    metal("verre_fume", (0.075, 0.03, 0.17), rough=0.08, met=0.0, grain=0.04, dirt=0.2, stain=0.12, sscale=4.0)
    metal("verre_meneau", (0.055, 0.022, 0.125), rough=0.12, met=0.0, grain=0.04, dirt=0.2, stain=0.1, sscale=4.0)
    # couronne d'isolateurs de la cloche (matière « ceramique » du kit) : acier noir, pour ne pas rappeler l'Électricité
    metal("ceramique", (0.02, 0.02, 0.028), rough=0.4, met=0.5, grain=0.12, dirt=0.5, stain=0.2)
    M["copper"] = M["cuivre_bobine"]
    M["ring"] = M["cuivre_bobine"]
    M["jacket"] = M["acier_canon"]
    M["trim"] = M["chrome_fin"]
    M["pipe"] = M["acier_canon"]
    M["pipe2"] = M["cuivre_bobine"]
    M["cable_a"], M["cable_b"] = M["rubber"], M["cuivre_bobine"]
    M["spec"] = M["chrome_fin"]
    M["accent"] = M["cuivre_bobine"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


def _Rd(d):
    """Repère dont l'axe y suit la direction horizontale d (pièces radiales)."""
    return Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()


# ------------------------------------------------------------------------------------------------
# Organe signature : la BOUTEILLE MAGNÉTIQUE (couchée)
# ------------------------------------------------------------------------------------------------
def bouteille(g, c, axis, r, L, nb=5, fente=True, rotfente=0.0, k=1.0):
    """Bouteille magnétique COUCHÉE : fût d'acier canon, bobinages de cuivre serrés (nb bandes en relief), calottes
    bombées d'acier noir à bride chromée, UNE fente longue sur le dessus où brille le point violet (cerclé de bleu). axis :
    "x" ou "y" (axe de la bouteille). Rend rien ; tout est plein (aucun jour)."""
    M = g.M
    c = V(c)
    ax = V((1, 0, 0)) if axis == "x" else V((0, 1, 0))
    g.cyl(c, axis, r, L * 0.86, M["acier_canon"], n=24, what="bouteille")
    for s in (-1, 1):
        p = c + ax * s * L * 0.43
        g.sphere(p, r * 0.98, M["acier_noir"], n=20, m=10, scale=(0.42 if axis == "x" else 1.0,
                                                                   0.42 if axis == "y" else 1.0, 1.0),
                 what="calotte")
        g.tube_shell(p, axis, r + 0.012, r - 0.01, 0.03 * k + 0.01, M["chrome_fin"], n=24, what="bride")
    # bobinages : bandes de cuivre serrées en relief (spires)
    for i in range(nb):
        f = -0.33 + 0.66 * i / max(1, nb - 1)
        p = c + ax * f * L
        g.tube_shell(p, axis, r + 0.016, r - 0.01, 0.06 * k + 0.012, M["cuivre_bobine"], n=24, what="bobinage")
        for j in (-1, 1):
            g.tube_shell(p + ax * j * (0.03 * k + 0.008), axis, r + 0.022, r + 0.01, 0.008, M["cuivre_plaque"], n=24,
                         what="spire")
    if fente:
        up = V((0, math.sin(rotfente), math.cos(rotfente))) if axis == "x" else V((math.sin(rotfente), 0,
                                                                                   math.cos(rotfente)))
        # fente : cadre noir, cœur violet, liseré bleu (cerclé de bleu de 2 à 3 px hr)
        lf = L * 0.18
        for f in (-0.165, 0.165):
            p = c + ax * f * L + up * (r + 0.004)
            size = (lf, 0.05 * k + 0.02, 0.012) if axis == "x" else (0.05 * k + 0.02, lf, 0.012)
            g.box(p, size, M["acier_noir"], "hard", what="cadre_fente")
            size2 = (lf * 0.8, 0.024 * k + 0.008, 0.006) if axis == "x" else (0.024 * k + 0.008, lf * 0.8, 0.006)
            g.box(p + up * 0.008, size2, M["emit2"], "flat", what="fente_bleue")
            g.sphere(p + up * 0.012, 0.012 * k + 0.008, M["emit"], n=10, m=6, what="point_violet")


def berceaux(g, c, axis, r, L, z0, mat=None):
    """Deux berceaux d'acier canon sous une bouteille couchée (rien ne flotte), boulons chromés."""
    M = g.M
    c = V(c)
    ax = V((1, 0, 0)) if axis == "x" else V((0, 1, 0))
    for s in (-1, 1):
        p = c + ax * s * L * 0.28
        hh = p.z - z0
        size = (0.06, r * 1.6, hh) if axis == "x" else (r * 1.6, 0.06, hh)
        g.box(V((p.x, p.y, z0 + hh / 2)), size, mat or M["acier_noir"], "hard", what="berceau")
        g.bolt(V((p.x, p.y, z0 + 0.02)) + (V((0, -1, 0)) if axis == "x" else V((-1, 0, 0))) * (r * 0.8 + 0.005),
               V((0, -1, 0)) if axis == "x" else V((-1, 0, 0)), 0.012, M["chrome_fin"])


def batterie(g, c, n, r, L, z0):
    """BATTERIE de n bouteilles COUCHÉES (axe x) côte à côte sur berceaux, sur un plateau d'acier noir : jamais un
    cylindre debout (pose N : aucune cheminée)."""
    M = g.M
    c = V(c)
    w = n * (2 * r + 0.04)
    PT.hull(g, c.x - L * 0.5, c.x + L * 0.5, c.y - w / 2, c.y + w / 2, z0, z0 + 0.06, ins=(0.012, 0.012, 0.012),
            panel=0.3, mats=[M["acier_noir"], M["acier_canon"]], rivet_step=0.12)
    for i in range(n):
        yy = c.y - w / 2 + (2 * r + 0.04) * (i + 0.5)
        cc = V((c.x, yy, z0 + 0.06 + r + 0.03))
        berceaux(g, cc, "x", r, L, z0 + 0.06)
        bouteille(g, cc, "x", r, L, nb=4, rotfente=-0.35)


def jauge(g, p, nrm, r):
    """Jauge de CONFINEMENT : hublot rond cerclé de chrome, mire sombre, point violet qui doit rester au centre."""
    M = g.M
    p = V(p)
    n = V(nrm).normalized()
    g.cyl(p + n * 0.012, n, r, 0.024, M["chrome_fin"], n=16, style="hard", what="jauge")
    g.cyl(p + n * 0.026, n, r * 0.78, 0.004, M["acier_noir"], n=16, style="flat", what="mire")
    g.tube_shell(p + n * 0.029, n, r * 0.5, r * 0.42, 0.003, M["emit2"], n=16, what="mire_bleue")
    g.cyl(p + n * 0.031, n, r * 0.2, 0.004, M["emit"], n=10, style="flat", what="point_violet")


def trefle(g, p, nrm, r):
    """Pochoir du trèfle d'annihilation : deux disques de cuivre opposés barrés, sur acier noir (≤ 0,02 t²)."""
    M = g.M
    p = V(p)
    n = V(nrm).normalized()
    g.cyl(p + n * 0.003, n, r * 1.25, 0.004, M["acier_noir"], n=16, style="flat", what="pochoir")
    _, u, w = basis(n)
    for s in (-1, 1):
        g.cyl(p + n * 0.006 + u * s * r * 0.5, n, r * 0.36, 0.004, M["cuivre_bobine"], n=12, style="flat",
              what="pochoir")
    g.box(p + n * 0.007, (r * 1.8, r * 0.16, 0.004), M["cuivre_bobine"], "flat",
          R=Matrix((w, u, n)).transposed(), what="pochoir")


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 25)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, 5, E, a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, 4, M["emit2"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    # bobinages de cuivre serrés autour de la colonne (la colonne est elle-même une bouteille)
    for zz in (B["h"] * 0.5,):
        g.tube_shell((0, 0, zz), "z", B["R"] + 0.03, B["R"] - 0.02, 0.07, M["cuivre_bobine"], n=64, what="bobinage")
        for j in (-1, 1):
            g.tube_shell((0, 0, zz + j * 0.045), "z", B["R"] + 0.036, B["R"] + 0.01, 0.01, M["cuivre_plaque"], n=64,
                         what="spire")
    P2.grating(g, 1.65, 1.95, Y(-1.3), Y(1.45), 0.07, M)
    P2.grating(g, -1.95, -1.65, Y(-1.1), Y(1.1), 0.07, M)
    # sud : RÂTELIERS DE CAPSULES (à la place des caisses ouvertes)
    with at(g, -1.45, -1.95, 0.45):
        rack_capsules(g, 0.84, 0.74)
    with at(g, 1.45, -1.95, -0.45):
        rack_capsules(g, 0.84, 0.74)
    tremie_bouteille(g, c)
    corps.collecteur(g, c, solenoide, r=0.07)
    # conduits solénoïdes longitudinaux sur les caillebotis (alimentation des cuves et du convertisseur)
    solenoide(g, [(-1.8, Y(-1.15), 0.2), (-1.8, Y(0.0), 0.24), (-1.8, Y(1.2), 0.2)], 0.065)
    solenoide(g, [(1.8, Y(-1.25), 0.2), (1.8, Y(0.1), 0.24), (1.8, Y(1.35), 0.2)], 0.065)
    for s in (-1, 1):
        solenoide(g, [(s * 0.72, Y(-2.55), 0.15), (s * 1.3, Y(-2.6), 0.17), (s * 1.95, Y(-2.45), 0.15)], 0.06)
    solenoide(g, [(2.05, Y(-0.95), 0.2), (2.15, Y(-1.15), 0.24), (2.4, Y(-1.3), 0.38)], 0.06)
    # tourelles secondaires sur trépied : bouteille couchée en guise de tourelleau
    for (x, yn, rz) in [(-2.4, -2.5, -0.3), (2.4, -2.5, 0.3)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.46, 0.0, 0.32, 8, M, [M["acier_canon"], M["acier_noir"]], gussets=False)
            mini_turret(g, (0, 0, 0.32), 1.02, rz)
    # ouest : CONVERTISSEUR D'ANNIHILATION
    convertisseur(g)
    solenoide(g, [(-1.98, Y(0.7), 0.45), (-1.78, Y(0.75), 0.72), (-1.52, Y(0.62), 0.86)], 0.045)
    solenoide(g, [(-1.98, Y(-0.6), 0.45), (-1.78, Y(-0.65), 0.72), (-1.52, Y(-0.55), 0.86)], 0.045)
    cables(g, [(-1.98, Y(0.05), 0.45), (-1.75, Y(0.02), 0.7), (-1.5, Y(0.0), 0.8)])
    # TOURS DE CONFINEMENT (bastions) : batteries de 3 bouteilles COUCHÉES sur le toit, fentes violettes aux flancs,
    # LIGNES DE CHAMP en arc de cuivre vers la colonne
    for sx in (-1, 1):
        xb, yb = sx * 2.4, 2.4
        zb = max(0.0, corps.z_pont(c, xb, yb) - 0.045)
        batterie(g, V((xb, Y(yb), 0.0)), 3, 0.085, 0.62, zb + 0.045)
        for j, (dy, h) in enumerate(((-0.2, 0.55), (0.15, 0.75))):
            # de la batterie (bout de bouteille) au flanc de la colonne (rayon 1,5 < 1,6 : l'arc entre dans la colonne)
            p0 = V((xb - sx * 0.3, Y(yb) + dy, zb + 0.3))
            p2 = V((sx * 0.92, 1.2 + dy * 0.3, 0.95))
            p1 = (p0 + p2) / 2 + V((0, 0, h))
            ligne_champ(g, [p0, p1, p2], 0.022)
    # est : deux CUVES À STRANGELETS
    cuve_strangelets(g, 2.4, Y(1.0), 0.42, 0.82)
    cuve_strangelets(g, 2.4, Y(-0.55), 0.42, 0.82)
    P3.cabinet(g, -2.85, -2.08, -2.85, -2.2, 0.0, 0.55, M, E)
    # sud-est : banc de JAUGES DE CONFINEMENT (à la place de la vanne à volants)
    banc_jauges(g, 1.98, 2.85, Y(-1.55), Y(-1.18), 0.3)
    solenoide(g, [(1.98, Y(-1.35), 0.34), (1.75, Y(-1.4), 0.4), (1.55, Y(-1.15), 0.56)], 0.05)
    solenoide(g, [(1.98, Y(1.0), 0.7), (1.68, Y(0.95), 1.05), (1.4, Y(0.8), 0.95)], 0.05)
    solenoide(g, [(1.98, Y(-0.55), 0.7), (1.68, Y(-0.55), 1.02), (1.42, Y(-0.4), 0.95)], 0.05)
    # nord : RADIATEUR À RAYONNEMENT (ailettes fines d'acier canon, sans ventilateur) ; armoires
    radiateur_nord(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.42)
    P3.cabinet(g, -1.15, -0.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    P3.cabinet(g, 0.35, 1.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    for x in (-0.7, 0.8):
        trefle(g, (x, Y(1.6) - 0.005, 0.32), (0, -1, 0), 0.05)
    P2.anchor(g, -2.6, Y(0.0), 0.26, M)
    for x in (-0.8, 0.8):
        PT.lamp(g, (x, Y(-2.75) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    P3.lamp_group(g, (-0.4, Y(-2.75) - 0.03, 0.58), (1, 0, 0), (0, -1, 0), E, M, n=3)
    P3.lamp_group(g, (0.2, Y(-2.75) - 0.03, 0.47), (1, 0, 0), (0, -1, 0), M["emit2"], M, n=2,
                  shapes=("fente", "rond"))
    _halo(g, [(-2.4, Y(-1.2), 0.6), (2.4, Y(-2.7), 0.7), (-2.4, Y(-2.7), 0.7), (0.0, Y(-2.85), 0.5),
              (-2.4, Y(2.4), 0.8), (2.4, Y(2.4), 0.8)], 20.0)
    _halo(g, [(2.4, Y(1.0), 0.9), (2.4, Y(-0.55), 0.9)], 9.0, g.M["_emit2_rgb"])


def rack_capsules(g, w, d):
    """RÂTELIER DE CAPSULES de confinement : plateau blindé, rangées de capsules chromées COUCHÉES dans des berceaux,
    chacune avec son point violet ; bobinage de cuivre en travers."""
    M = g.M
    PT.hull(g, -w / 2, w / 2, -d / 2, d / 2, 0.0, 0.12, ins=(0.015, 0.015, 0.015), panel=0.24,
            mats=[M["acier_canon"], M["acier_noir"]], rivet_step=0.12)
    nr, nc = 4, 3
    for j in range(nr):
        yy = -d / 2 + d * (j + 0.5) / nr
        g.box((0, yy, 0.135), (w - 0.06, d / nr * 0.7, 0.03), M["acier_noir"], "hard", what="berceau_capsules")
        for i in range(nc):
            xx = -w / 2 + w * (i + 0.5) / nc
            cc = V((xx, yy, 0.18))
            g.cyl(cc, "x", 0.042, w / nc * 0.78, M["chrome_fin"], n=14, what="capsule")
            g.tube_shell(cc, "x", 0.05, 0.035, 0.03, M["cuivre_bobine"], n=14, what="bague")
            g.sphere(cc + V((0, -0.02, 0.036)), 0.012, M["emit"], n=8, m=5, what="point_violet")
    for s in (-1, 1):
        g.box((s * (w / 2 - 0.04), 0, 0.2), (0.05, d - 0.04, 0.1), M["acier_canon"], "hard", what="joue")
    P3.lamp_group(g, (-w / 2 + 0.06, -d / 2 - 0.02, 0.06), (1, 0, 0), (0, -1, 0), M["emit"], M, n=2,
                  shapes=("rond", "fente"))


def convertisseur(g):
    """Groupe de l'ouest : CONVERTISSEUR D'ANNIHILATION (caisson d'acier canon à ailettes, 3 fentes violettes groupées,
    bouteille couchée sur le dos, petit TORE DE CUIVRE : rappel discret de la fusion D-³He)."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = -2.88, -1.98, Y(-1.35), Y(1.35), 0.5
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.03), panel=0.28,
            mats=[M["acier_canon"], M["acier_canon2"], M["acier_noir"]], rivet_step=0.12)
    # ailettes de rayonnement sur les flancs est et ouest
    for xx, s in ((x0 - 0.02, -1), (x1 + 0.02, 1)):
        for i in range(14):
            yy = y0 + 0.12 + (y1 - y0 - 0.24) * i / 13
            g.box((xx, yy, h * 0.55), (0.04, 0.014, h * 0.7), M["acier_noir"], "hard", what="ailette")
    # 3 fentes violettes groupées, face est (vers la colonne)
    for k in range(3):
        g.box((x1 + 0.045, cy - 0.5 + 0.12 * k, h * 0.62), (0.006, 0.07, 0.16), E, "flat", what="fente")
    bouteille(g, V((cx, cy + 0.55, h + 0.16)), "y", 0.13, 1.05, nb=5, rotfente=0.0)
    berceaux(g, V((cx, cy + 0.55, h + 0.16)), "y", 0.13, 1.05, h)
    # tore de cuivre (fusion D-³He)
    zt = h + 0.05
    g.torus((cx, cy - 0.85, zt + 0.05), "z", 0.13, 0.045, M["cuivre_bobine"], n=28, m=10, what="tore_d3he")
    g.cyl((cx, cy - 0.85, zt), "z", 0.14, 0.04, M["acier_noir"], n=24, what="embase")
    g.cyl((cx, cy - 0.85, zt + 0.05), "z", 0.07, 0.1, M["acier_canon"], n=16, what="noyau")
    for k in range(6):
        a = TAU * (k + 0.5) / 6
        d = V((math.cos(a), math.sin(a), 0))
        g.torus(V((cx, cy - 0.85, zt + 0.05)) + d * 0.13, d.cross(V((0, 0, 1))), 0.052, 0.008, M["cuivre_plaque"],
                n=12, m=4, what="spire")
    for yy in (cy - 0.3, cy + 0.05):
        jauge(g, (x1 + 0.005, yy, h * 0.3), (1, 0, 0), 0.045)


def cuve_strangelets(g, x, y, r, h):
    """CUVE À STRANGELETS (même place et même masse que le réservoir debout) : cuve blindée TRAPUE d'acier noir,
    cerclée de cuivre, hublot épais où la matière étrange se lit gris-violet terne (l'arête seule est lumineuse)."""
    M = g.M
    P3.vtank(g, x, y, r, h, M, paint=M["acier_canon2"], emat=M["emit"], ladder_dir=(1, 0.2), stub_dir=(-1, 0),
             gauges=2, glow_gauges=False, glow_rings=0, band=M["cuivre_bobine"])
    for zz in (0.22, 0.42, 0.62):
        g.tube_shell((x, y, h * zz + 0.08), "z", r + 0.02, r - 0.01, 0.06, M["cuivre_bobine"], n=40, what="bobinage")
    a = -1.75
    d = V((math.cos(a), math.sin(a), 0))
    p = V((x, y, h * 0.52)) + d * r
    g.cyl(p, d, 0.11, 0.06, M["acier_noir"], n=20, what="hublot")
    g.cyl(p + d * 0.032, d, 0.085, 0.006, M["verre_fume"], n=20, style="flat", what="matiere_etrange")
    g.tube_shell(p + d * 0.034, d, 0.092, 0.08, 0.004, M["emit"], n=20, what="arete_lum")
    jauge(g, V((x, y, h * 0.3)) + V((math.cos(-1.2), math.sin(-1.2), 0)) * r, V((math.cos(-1.2), math.sin(-1.2), 0)),
          0.04)


def banc_jauges(g, x0, x1, y0, y1, h):
    """Banc de JAUGES DE CONFINEMENT (sud-est) : caisson d'acier canon, 3 jauges à espacements inégaux, 2 conduits
    solénoïdes debout coudés vers la colonne."""
    M = g.M
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.22, mats=[M["acier_canon"], M["acier_noir"]],
            rivet_step=0.12)
    w = x1 - x0
    for f in (0.18, 0.42, 0.8):
        jauge(g, (x0 + w * f, y0 - 0.005, h * 0.55), (0, -1, 0), 0.05)
    yc = (y0 + y1) / 2
    for f in (0.3, 0.7):
        x = x0 + w * f
        solenoide(g, [(x, yc, h), (x, yc, h + 0.18), (x - 0.06, yc + 0.2, h + 0.26)], 0.04)


def radiateur_nord(g, x0, x1, y0, y1, h):
    """RADIATEUR À RAYONNEMENT (nord) : plinthe, ailettes fines d'acier canon serrées, collecteurs de cuivre bobinés,
    aucune pale."""
    M = g.M
    F.plinth(g, x0, x1, y0, y1, 0.1)
    w = x1 - x0
    PT.radiator(g, ((x0 + x1) / 2, (y0 + y1) / 2 + 0.15, 0.1), w - 0.1, h, 0.3, fin_mat=M["acier_canon"], step=0.04)
    for zz in (0.14, 0.1 + h - 0.02):
        g.cyl(((x0 + x1) / 2, (y0 + y1) / 2 - 0.02, zz), "x", 0.045, w - 0.04, M["acier_noir"], n=14, what="collecteur")
        for i in range(9):
            g.tube_shell((x0 + 0.12 + (w - 0.24) * i / 8, (y0 + y1) / 2 - 0.02, zz), "x", 0.055, 0.04, 0.03,
                         M["cuivre_bobine"], n=14, what="bobinage")


def mini_turret(g, c, s, rz):
    """Tourelle secondaire ANTIMATIÈRE : couronne rivetée de la lignée, caisson d'acier canon, BOUTEILLE couchée sur le
    dos (bobinages, fente violette) ; deux petits canons de l'époque à bouteille de tir."""
    M = g.M
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["armor2"], n=32, style="soft", what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    PT.hull(g, -0.24 * s, 0.24 * s, -0.3 * s, 0.24 * s, 0.1 * s, 0.28 * s, ins=(0.03 * s, 0.03 * s, 0.05 * s),
            panel=0.22, mats=[M["acier_canon"], M["cuivre_plaque"]])
    bouteille(g, V((0, -0.05 * s, 0.38 * s)), "x", 0.09 * s, 0.42 * s, nb=4)
    berceaux(g, V((0, -0.05 * s, 0.38 * s)), "x", 0.09 * s, 0.42 * s, 0.28 * s)
    for sx in (-1, 1):
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=[M[k] for k in RECV])
        _gun13(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    g.pop()


def tremie_bouteille(g, c):
    """Trémie de l'époque (SILO trapu du kit) : deux BOUTEILLES couchées sur berceaux en travers de l'arrière de la
    trémie, conduits solénoïdes vers la colonne."""
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    w = x1 - x0
    for s in (-1, 1):
        cc = V((s * (w / 2 + 0.2), y1 - 0.32, 0.26))
        bouteille(g, cc, "y", 0.12, 0.62, nb=4, rotfente=s * 0.6)
        berceaux(g, cc, "y", 0.12, 0.62, 0.0)
        solenoide(g, [(s * (w / 2 + 0.2), y1, 0.3), (s * (w / 2 + 0.25), y1 + 0.25, 0.5),
                      (s * 0.45, y1 + 0.5, c.rt + 0.02)], 0.045)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : CONDUITS SOLÉNOÏDES, lignes de champ, câbles supraconducteurs
# ------------------------------------------------------------------------------------------------
def solenoide(g, ctrl, r, sol=True):
    """CONDUIT SOLÉNOÏDE : tube d'acier canon, tous les 0,25 t un MANCHON DE BOBINAGE de cuivre (6 spires en relief),
    brides de chrome à 6 boulons aux extrémités, berceaux posés sur le pont (rien ne flotte)."""
    M = g.M
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["acier_canon"], n=14, what="solenoide")
    R = g.resample(P, 0.25)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        g.tube_shell(R[i], T2[i], r + 0.016, r - 0.005, 0.08, M["cuivre_bobine"], n=14, what="manchon_bobinage")
        for j in range(-2, 3):
            g.tube_shell(R[i] + T2[i] * (j * 0.016), T2[i], r + 0.024, r + 0.012, 0.007, M["cuivre_plaque"], n=14,
                         what="spire")
    for i in (0, len(R) - 1):
        g.cyl(R[i], T2[i], r * 1.45, 0.03, M["chrome_fin"], n=16, style="hard", what="bride")
        F.bolts_ring(g, R[i] + T2[i] * 0.016, T2[i], r * 1.3, 6, M["rivet"], r=0.01)
    for i in range(len(R)):
        if sol and R[i].z - r > 0.03:
            g.box(V((R[i].x, R[i].y, (R[i].z - r) / 2)), (0.05, 0.05, R[i].z - r), M["acier_noir"], "hard",
                  what="berceau")


def ligne_champ(g, ctrl, r):
    """LIGNE DE CHAMP : tube de cuivre fin en ARC, bagues de chrome, chenillard de points violets (nuit)."""
    M = g.M
    P = g.spline(ctrl, 14)
    P, T = g.tube(P, r, M["cuivre_bobine"], n=10, what="ligne_champ")
    R = g.resample(P, 0.18)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 2:
            g.tube_shell(R[i], T2[i], r + 0.012, r * 0.5, 0.02, M["chrome_fin"], n=10, what="bague")
        else:
            g.tube_shell(R[i], T2[i], r + 0.008, r * 0.5, 0.016, M["emit"], n=10, what="chenillard")


def cables(g, ctrl, n=3):
    """Câbles SUPRACONDUCTEURS noirs épais, tresse de cuivre apparente."""
    M = g.M
    PT.cable_run(g, ctrl, n, 0.022, 0.05, [M["rubber"], M["cuivre_bobine"], M["rubber"]])


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 26 : 2 PIÈGES DE PENNING sur affût
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.22, Y(-2.97), sx)
    _halo(g, [(-1.22, Y(-3.3), 0.35), (1.22, Y(-3.3), 0.35)], 16.0)


def even_piece(g, x, yb, sx):
    """PIÈGE DE PENNING sur affût : bouteille couchée (diamètre 0,30, longueur 0,55), 4 bandes de bobinage, calottes
    noires, fente violette ; affût blindé d'acier canon à 2 berceaux, câble supraconducteur vers le pont."""
    M = g.M
    E = M["emit"]
    w, d = 0.62, 0.6
    PT.hull(g, x - w / 2, x + w / 2, yb - d / 2, yb + d / 2, 0.0, 0.16, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["acier_canon"], M["acier_noir"]], rivet_step=0.12)
    g.hazard([V((x - w / 2, yb - d / 2 - 0.02, 0.02)), V((x + w / 2, yb - d / 2 - 0.02, 0.02)),
              V((x + w / 2, yb - d / 2 - 0.02, 0.13)), V((x - w / 2, yb - d / 2 - 0.02, 0.13))], 6, t=0.012, skew=0.6)
    P3.lamp_group(g, (x - w / 2 + 0.06, yb - d / 2 - 0.025, 0.08), (1, 0, 0), (0, -1, 0), E, M, n=2,
                  shapes=("rond", "fente"))
    cc = V((x, yb + 0.02, 0.16 + 0.11 + 0.15))
    PT.hull(g, x - 0.26, x + 0.26, yb - 0.2, yb + 0.24, 0.16, 0.27, ins=(0.015, 0.015, 0.015), panel=0.24,
            mats=[M["acier_canon"], M["cuivre_plaque"]], rivet_step=0.1)
    berceaux(g, cc, "x", 0.15, 0.55, 0.27)
    bouteille(g, cc, "x", 0.15, 0.55, nb=4, rotfente=-0.5)
    jauge(g, (x + sx * 0.18, yb - 0.205, 0.215), (0, -1, 0), 0.035)
    PT.cable_run(g, [tuple(cc + V((-sx * 0.3, 0.05, -0.1))), tuple(cc + V((-sx * 0.42, 0.3, -0.25))),
                     tuple(cc + V((-sx * 0.45, 0.55, -0.4)))], 2, 0.02, 0.045, [M["rubber"], M["cuivre_bobine"]])


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon effilé à BOUTEILLE DE TIR
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, canon de l'époque, masque de canon,
    alimentation à CAPSULES DE CONFINEMENT, voyants d'état."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun13(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["acier_canon"], M["cuivre_plaque"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit2"],
              "flat", what="etat")
    # bobinage de cuivre en travers du dos de la culasse
    zt = zg + hr + 0.012
    for f in (0.3, 0.45, 0.6):
        g.box((x, y0 + (y1 - y0) * f, zt + 0.015), (wr * 0.8, 0.05, 0.03), M["cuivre_bobine"], "hard", what="bobinage")
    jauge(g, (x, y0 + (y1 - y0) * 0.78, zt), (0, 0, 1), 0.05)


def _gun13(g, x, y0, z, L, nb, rb, rr):
    """Canon effilé du kit (faisceau qui converge, jaquette conique perforée, une bague de cuivre, manchon à fentes
    reculé au ras du faisceau, dernier cinquième nu, pointes éclairées) + BOUTEILLE DE TIR couchée en travers à la base
    du faisceau (diamètre 0,30 au canon de flanc, débord de 0,08 de chaque côté du faisceau) : elle s'AJOUTE à la
    rosette (règle d'or 1). En pose N, la base de chaque canon est une barre horizontale cuivrée, jamais le pied d'un
    fût. Fentes violettes au manchon (visibles en pose E)."""
    M = g.M
    k = F.k_arme(rb, rr)
    R0 = rr + rb
    corps.canon_effile(g, x, y0, z, L, nb, rb, rr, jaquette=0.3, bague_mat="cuivre_bobine", conv=0.6,
                       frein=(0.66, 0.8))
    # fentes violettes du manchon (posées sur les fentes noires du kit)
    yf0, yf1 = y0 + 0.66 * L, y0 + 0.8 * L
    lf = yf1 - yf0
    rm = (rr * (1 + (0.6 - 1) * 0.66) + rb * (1 - 0.14 * 0.66) + rr * (1 + (0.6 - 1) * 0.8) + rb * (1 - 0.14 * 0.8)) / 2
    for sx_ in (-1, 1):
        for kk in range(3):
            yk = yf0 + lf * (0.22 + 0.28 * kk)
            g.box((x + sx_ * (rm + 0.012), yk, z), (0.004, lf * 0.1, rm * 0.8), M["emit"], "flat", what="fente_lum")
    # bouteille de tir couchée en travers (axe x), plus large que le faisceau
    rbt = 0.15 * k if k >= 0.9 else max(0.03, 0.15 * k)
    Lb = 2 * R0 + 2 * 0.08 * k + 0.1 * k
    cy = y0 + 0.22 * k + 0.06
    bouteille(g, V((x, cy, z)), "x", rbt, Lb, nb=5 if k >= 0.9 else 3, k=k)
    return y0 + L


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisson d'acier canon (volume de la lignée), CHARGEUR À CAPSULES DE CONFINEMENT : bande
    de capsules chromées couchées, chacune avec son point violet, qui monte vers la culasse ; voyants."""
    M = g.M
    E = M["emit"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    y0, y1 = H["recv"]
    bw, bl, bh = 0.32 * wr / 0.4, 0.75 * H["L"] / 1.95, 0.5 * hr / 0.23
    bl = min(bl, 0.95)
    bx0, bx1 = sorted((xo + sx * 0.02, xo + sx * (0.02 + bw)))
    bc = (bx0 + bx1) / 2
    yb0, yb1 = y0 - 0.1, y0 - 0.1 + bl
    zb0, zb1 = zg - bh * 0.62, zg + bh * 0.42
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24,
            mats=[M["acier_canon"], M["acier_noir"]], rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    # rangée de capsules couchées dans le caisson ouvert
    for kk in range(6):
        yy = yb0 + bl * (0.28 + 0.11 * kk)
        cc = V((bc, yy, ztop + 0.035))
        g.cyl(cc, "x", 0.032, bw * 0.8, M["chrome_fin"], n=12, what="capsule")
        g.tube_shell(cc, "x", 0.038, 0.026, 0.025, M["cuivre_bobine"], n=12, what="bague")
        g.sphere(cc + V((0, 0, 0.03)), 0.011, E, n=8, m=5, what="point_violet")
    g.box((bc, yb0 + bl * 0.6, ztop + 0.005), (bw * 0.9, bl * 0.75, 0.01), M["acier_noir"], "hard", what="lit")
    P2.feed_chute(g, [(bc, yb0 + bl * 0.88, ztop + 0.01), (bc - sx * 0.05, y0 + bl * 0.75, zg + bh * 0.55),
                      (x + sx * wr * 0.25, y0 + bl * 0.6, zg + hr + 0.06)], 0.12 * wr / 0.4 + 0.04, M)
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=3, shapes=("rond", "carre", "fente"))
    return bc


def dome_gun(g, c, nb, L, s=1.0):
    """Canon de coupole posé SUR LA CLOCHE (corps.z_coque) : fût-pivot d'acier canon cerclé de cuivre, berceau blindé,
    canon de l'époque à bouteille de tir. La couronne d'isolateurs de la cloche reste visible devant le berceau."""
    M = g.M
    H = c.H
    # berceau en arrière de la couronne d'isolateurs (qui reste dégagée devant lui), posé au-dessus du point le plus
    # haut de la cloche sous son emprise
    yb = -0.75 * s
    zr = max(corps.z_coque(c, xx, yy) for xx in (-0.34 * s, 0.0, 0.34 * s)
             for yy in (yb - 0.2 * s, yb, yb + 0.3 * s, yb + 0.62 * s)) + 0.03
    zc = zr + 0.3 * s
    zs_ = corps.z_coque(c, 0.0, yb + 0.22 * s) - 0.06
    g.cyl((0.0, yb + 0.22 * s, (zs_ + zr) / 2), "z", 0.2 * s, zr - zs_, M["acier_canon"], n=24, what="pivot")
    for zz in (zs_ + 0.06, (zs_ + zr) / 2, zr - 0.04):
        g.tube_shell((0.0, yb + 0.22 * s, zz), "z", 0.22 * s, 0.18 * s, 0.04, M["cuivre_bobine"], n=24, what="cerce")
    PT.hull(g, -0.34 * s, 0.34 * s, yb - 0.2 * s, yb + 0.62 * s, zr - 0.04, zr + 0.18 * s, ins=(0.04, 0.04, 0.08),
            panel=0.22, mats=[M["acier_canon"], M["cuivre_plaque"]], rivet_step=0.11)
    PT.receiver(g, 0.0, yb - 0.2 * s, yb + 0.62 * s, zc - 0.16 * s, zc + 0.14 * s, 0.34 * s, mats=[M[k] for k in RECV])
    rb, rr = 0.05 * s, 0.12 * s
    _gun13(g, 0.0, yb + 0.62 * s, zc, L, nb, rb, rr)
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.24 * s, yb + 0.25 * s, zr + 0.02), (sx * 0.3 * s, yb + 0.55 * s, zr + 0.18 * s), 0.024)
    return zc


# ------------------------------------------------------------------------------------------------
# Masque et tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=("cuivre_plaque", "acier_canon"), fentes=((-0.42, 0.34), (0.42, 0.22)),
                        visiere=("chrome_fin", 0.13),
                        coax=dict(fut="acier_noir", manchon="cuivre_bobine", manchon_y=0.28, manchon_r=0.045,
                                  manchon_L=0.16))


def tete(g, c):
    M = g.M
    E = M["emit"]
    H = c.H
    R = H["R"]
    z0 = c.rt
    F.slits_grouped(g, R * 0.86, z0 + 0.2, 5, E)
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.15), (sx * R * 0.62, -R * 0.42, H["zs"] + 0.3),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
        solenoide(g, [(sx * 0.6, -R - 0.3, H["zs"] + 0.1), (sx * R * 0.78, -R * 0.5, H["zs"] + 0.2),
                      (xe, ye + 0.2, H["zg"] + H["hr"] * 0.55)], 0.036, sol=False)
    # cloche : 6 FENÊTRES DE CONFINEMENT à mi-hauteur (points violets cerclés de bleu, la cloche s'éclaire de l'intérieur
    # la nuit) et reflet net du verre (matière lisse)
    for k in range(8):
        th = TAU * (k + 0.25) / 8
        p = c.Pf(th, 0.55, 1.0)
        n = c.Nf(th, 0.55)
        g.cyl(p + n * 0.006, n, 0.075, 0.012, M["acier_noir"], n=16, style="hard", what="fenetre")
        g.cyl(p + n * 0.014, n, 0.058, 0.004, M["emit2"], n=16, style="flat", what="fenetre_bleue")
        g.cyl(p + n * 0.017, n, 0.036, 0.004, E, n=12, style="flat", what="point_violet")
    # fentes de confinement violettes en anneau segmenté (lumière en orifices, jamais une nappe)
    nseg = 28
    for k in range(nseg):
        th0, th1 = TAU * (k + 0.15) / nseg, TAU * (k + 0.85) / nseg
        for ph in (0.25, 0.95):
            p0, p1 = c.Pf(th0, ph, 1.004), c.Pf(th1, ph, 1.004)
            nm = c.Nf((th0 + th1) / 2, ph)
            tg = (p1 - p0).normalized()
            sd = nm.cross(tg).normalized()
            g.box((p0 + p1) / 2, ((p1 - p0).length, 0.03, 0.006), E if ph < 0.5 else M["emit2"], "flat",
                  R=Matrix((tg, sd, nm)).transposed(), what="fente_cloche")
    # ronde 2 : DEUX BOBINES ÉPAISSES (bouteille magnétique à MIROIRS : la lumière est enfermée entre deux bobines),
    # chacune 4 spires de cuivre serrées entre deux joues de chrome ; la cloche reste du verre entre elles
    # bobine basse : sur c.Pf (au bas de la cloche, Pf suit la coque) ; bobine HAUTE : anneaux horizontaux posés à la
    # hauteur réelle de la coque (corps.z_coque : plus haut, Pf passe SOUS le verre de la cloche, constaté sur l'aperçu)
    ph0 = 0.06
    for kk in range(4):
        pts = [c.Pf(TAU * i / 72, ph0 + 0.035 * kk, 1.02) for i in range(73)]
        g.tube(pts, 0.026, M["cuivre_bobine"], n=8, caps=False, what="bobinage_cloche")
    for ph in (ph0 - 0.022, ph0 + 0.035 * 3 + 0.022):
        pts = [c.Pf(TAU * i / 72, ph, 1.034) for i in range(73)]
        g.tube(pts, 0.014, M["chrome_fin"], n=8, caps=False, what="joue_bobine")
    R_ = H["R"]
    # aperçu r2 : 5 anneaux espacés faisaient une CIBLE (rappel du vortex) : une seule bande serrée de 3 spires
    for kk, (fr, rt_, mt) in enumerate(((0.56, 0.026, "cuivre_bobine"), (0.592, 0.026, "cuivre_bobine"),
                                       (0.624, 0.026, "cuivre_bobine"))):
        rr_ = R_ * fr
        pts = [V((rr_ * math.cos(TAU * i / 72), rr_ * math.sin(TAU * i / 72), 0.0)) for i in range(73)]
        for p in pts:
            p.z = corps.z_coque(c, p.x, p.y) + rt_ * 0.6
        g.tube(pts, rt_, M[mt], n=8, caps=False, what="bobine_haute")
    dome_gun(g, c, 6, 1.6, 0.95)
    # nacelle : batterie de 2 bouteilles couchées (réserve d'antimatière de la tête)
    bx, yb0, yb1 = c.nac[:3]
    znac = H["zs"] + H["rz"] * 0.42
    for i, xx in enumerate((-0.22, 0.22)):
        cc = V((xx, (yb0 + yb1) / 2 - 0.05, znac + 0.2))
        bouteille(g, cc, "y", 0.13, 0.6, nb=4, rotfente=(-0.5 if xx < 0 else 0.5))
        berceaux(g, cc, "y", 0.13, 0.6, znac)
    PT.capacitors(g, (0.0, -R - 0.14, H["zs"] + H["rz"] * 0.42), 4, 1, 0.1, 0.22, M["emit2"])
    xs_, ys_ = -R * 0.64, R * 0.3
    PT.sight(g, (xs_, ys_, corps.z_coque(c, xs_, ys_) - 0.18), 0.26, 0.26, 0.15, E, lenses=2)


# ------------------------------------------------------------------------------------------------
# Ce que l'époque dessine (socle, pièce paire, arme, tête, masque) est posé dans la palette HABILLÉE de la lignée.
# ------------------------------------------------------------------------------------------------
def _dans_habillage(f):
    def w(g, c, *a, **k):
        with corps.habille(g, c):
            return f(g, c, *a, **k)
    w.__name__, w.__doc__ = f.__name__, f.__doc__
    return w


socle, piece, arme, tete, masque = [_dans_habillage(_f) for _f in (socle, piece, arme, tete, masque)]
