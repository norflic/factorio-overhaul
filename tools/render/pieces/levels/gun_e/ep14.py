"""Époque 14 · La Porte (ère V cosmique, 6×6, niveaux 27 et 28). Constructeur de l'ère V. S'exécute DANS Blender.

Consigne du Directeur Créatif (23/10, vers 13 h 10, option A) : 14 LA PORTE : « espace profond, noir indigo et champ
d'étoiles, l'anneau de la Porte » (le contenu « orbite » reste). Histoire du jeu : « Les archives orbitales de l'Arche
parlent enfin : le Convoi venait ancrer une Porte sur le trou noir du Cœur. » Fiche : FICHES_ERE_V.md §3 (fait foi).
L'ancien thème Orbite (feuille d'or, paraboles, pyramide dorée, rouge balise) a été REFUSÉ : réécrit au nouveau thème
(ronde 1 de l'ère V, 23/10).

Image : un fragment d'ESPACE PROFOND posé sur le sol. Corps INDIGO DE NUIT constellé d'étoiles fines ; derrière la
tourelle se dresse l'ANNEAU DE LA PORTE, dont l'horizon PLEIN montre un champ d'étoiles. L'âge du silence froid.
Palette 60/30/10 : INDIGO DE NUIT saturé et mat (capots, coupole, pont) ; BLANC LUNAIRE mat (anneau, cerclages,
arêtes, colonnade, conduits) ; BLANC D'ÉTOILE semé en points (étoiles, chevrons, horizon, pointes). Ni or ni orange.
Silhouette : anneau de la Porte au nord (à la place du radiateur), coupole basse en OBSERVATOIRE à fente étoilée d'où
sort le canon de coupole comme un télescope, jupe en COLONNADE (piliers de la Porte, la nuit entre eux), pont carré
(repli de la fiche : le pont sur pilotis n'a jamais été essayé, ronde 1 prudente), trémie en TAMBOUR à cadran d'adresse.
Canons : L 2,80 ; culasse = ANNEAU-PORTE à chevrons et horizon étoilé (pose N : un cercle vu de face au pied du
faisceau) ; cassettes orbitales à l'alimentation.
Tuyaux : OMBILICAUX blancs à rotules indigo, conduits de fibre à points d'étoile, brides à chevrons, cartes stellaires.
"""
import math
import random

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from corps import Y, at
from kit import TAU, basis

V = Vector

EPOQUE = 14
NOM = "La Porte"
# blanc stellaire #F4F6FF et horizon #BFD4FF (fiche §3 E5)
FOYER = ages.FOYER[14]
CANON = dict(L=2.8, nb=6, rb=0.072, rr=0.175)
PLATEFORME = dict(chanfrein=0.2)
HABILLAGE = dict(ages.CORPS[14],   # lot K0 : MATIÈRE du corps et du pont (capots, acier, rivets, joints,
                 # danger, peinture, plateforme) : commun/ages.py ; ici, les clés propres à la mitrailleuse
                 jupe_cerclage="blanc_lunaire", chapeau="blanc_lunaire", tremie="indigo_nuit",
                 tourelleau="blanc_lunaire",
                 grille_nacelle="blanc_lunaire",
                 munitions=("blanc_lunaire", "indigo_nuit"),
                 forme_plateforme=dict(forme="carre", flanc="blanc_lunaire", flanc2="indigo_nuit"),
                 # OBSERVATOIRE : dôme bas à côtes serrées, aucune parabole ni panneau dessus (ronde 5 : la pyramide de
                 # l'ancien 14 était couverte par les paraboles)
                 forme_coupole=dict(forme="dome_bas", mat="indigo_nuit", mat2="blanc_lunaire"),
                 # piliers de la Porte : colonnes blanc lunaire devant une âme de nuit étoilée
                 forme_jupe=dict(forme="colonnade", mat="blanc_lunaire", mat2="noir_spatial"),
                 forme_tremie=dict(forme="tambour", mat="indigo_nuit", mat2="blanc_lunaire"))
RECV = ("indigo_nuit", "noir_spatial")


def matieres(metal, M):
    """La Porte : indigo de nuit SATURÉ et mat (doit se lire BLEU au zoom 1, jamais noir : valeur remontée par rapport
    à l'albédo de la fiche, risque 2), blanc lunaire mat patiné de régolithe gris, noir spatial, horizon de la Porte
    (indigo très sombre), roche de météorite."""
    ages.matieres(14, metal, M)   # lot K0 : matières de l'âge, commun/ages.py (même ordre)
    # rôles de la mitrailleuse (alias), dans l'ordre d'origine
    M["gun"] = M["acier_bleui"]
    M["copper"] = M["blanc_lunaire"]
    M["ring"] = M["blanc_lunaire"]
    M["jacket"] = M["indigo_nuit"]
    M["trim"] = M["blanc_lunaire"]
    M["pipe"] = M["blanc_lunaire"]
    M["pipe2"] = M["indigo_nuit"]
    M["cable_a"], M["cable_b"] = M["rubber"], M["indigo_nuit"]
    M["spec"] = M["blanc_lunaire"]
    M["accent"] = M["blanc_lunaire"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Matière d'époque : le CHAMP D'ÉTOILES
# ------------------------------------------------------------------------------------------------
def etoile(g, p, nrm, r=0.02, croix=False):
    """Une étoile : point émissif de 0,03 à 0,05 t (3 à 4 px hr), posé sur la surface ; croix=True : étoile à 4
    branches (croix fine de 0,06 t)."""
    M = g.M
    p = V(p)
    n = V(nrm).normalized()
    g.cyl(p + n * 0.003, n, r, 0.004, M["emit"], n=8, style="flat", what="etoile")
    if croix:
        _, u, w = basis(n)
        Rm = Matrix((u, w, n)).transposed()
        g.box(p + n * 0.004, (0.07, 0.012, 0.004), M["emit"], "flat", R=Rm, what="etoile_branche")
        g.box(p + n * 0.004, (0.012, 0.07, 0.004), M["emit"], "flat", R=Rm, what="etoile_branche")


def etoiles_rect(g, x0, x1, y0, y1, z, dens, graine, nrm=(0, 0, 1)):
    """Sème des étoiles sur un rectangle horizontal (dens par unité², tirage à graine fixe, 1 sur 8 en croix)."""
    rng = random.Random(graine)
    n = max(1, int((x1 - x0) * (y1 - y0) * dens))
    for i in range(n):
        x = x0 + 0.04 + (x1 - x0 - 0.08) * rng.random()
        y = y0 + 0.04 + (y1 - y0 - 0.08) * rng.random()
        etoile(g, (x, y, z), nrm, 0.017 + 0.007 * rng.random(), croix=(i % 8 == 3))


def etoiles_face(g, q, n, graine):
    """Sème n étoiles sur une face quadrilatère q (4 points, normale sortante q0->q1 × q0->q3)."""
    q = [V(p) for p in q]
    nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
    rng = random.Random(graine)
    for i in range(n):
        u, v = 0.08 + 0.84 * rng.random(), 0.08 + 0.84 * rng.random()
        p = q[0] + (q[1] - q[0]) * u + (q[3] - q[0]) * v
        etoile(g, p, nrm, 0.017 + 0.007 * rng.random(), croix=(i % 8 == 3))


def chevron(g, p, d, nrm, s=1.0, lampe=True):
    """CHEVRON de la Porte : bloc trapézoïdal blanc lunaire en relief (pointe vers d), petite lampe blanche au centre."""
    M = g.M
    p, d, n = V(p), V(d).normalized(), V(nrm).normalized()
    t = n.cross(d).normalized()
    Rm = Matrix((t, d, n)).transposed()
    for sg in (-1, 1):
        Rb = Rm @ Matrix.Rotation(sg * 0.6, 3, "Z")
        g.box(p + t * sg * 0.022 * s + n * 0.012 * s, (0.024 * s, 0.075 * s, 0.024 * s), M["blanc_lunaire"], "hard",
              R=Rb, what="chevron")
    g.box(p - d * 0.025 * s + n * 0.01 * s, (0.05 * s, 0.03 * s, 0.02 * s), M["noir_spatial"], "hard", R=Rm,
          what="chevron_socle")
    if lampe:
        g.box(p + d * 0.012 * s + n * 0.026 * s, (0.018 * s, 0.018 * s, 0.004), M["emit"], "flat", R=Rm,
              what="lampe_chevron")


def anneau_porte(g, centre, Ro, prof, nchev=9, graine=1, k=1.0, axe="y"):
    """ANNEAU DE LA PORTE debout (axe y : face au sud, vers la caméra) : couronne plate blanc lunaire, gorge noire,
    HORIZON PLEIN (disque indigo très sombre, opaque : aucun sol vu au travers) semé d'étoiles, bord intérieur blanc
    bleuté lumineux, nchev CHEVRONS à lampe sur la face avant."""
    M = g.M
    C = V(centre)
    ay = V((0, 1, 0))
    ep = 0.16 * k + 0.02
    g.tube_shell(C, axe, Ro, Ro - ep, prof, M["blanc_lunaire"], n=64, what="anneau_porte")
    g.tube_shell(C, axe, Ro - ep + 0.004, Ro - ep - 0.03 * k, prof * 0.7, M["noir_spatial"], n=64, what="gorge")
    Rh = Ro - ep - 0.02 * k
    g.cyl(C, axe, Rh, prof * 0.3, M["horizon_porte"], n=64, what="horizon")
    for s in (-1, 1):
        g.tube_shell(C + ay * s * prof * 0.16, axe, Rh + 0.004, Rh - 0.02 * k - 0.006, 0.004, M["emit2"], n=64,
                     what="bord_horizon")
    # nervures blanches de la couronne (entre les chevrons) et rivets
    for i in range(nchev * 2):
        a = TAU * (i + 0.5) / (nchev * 2) + math.pi / 2
        d = V((math.cos(a), 0.0, math.sin(a)))
        for s in (-1, 1):
            g.dome(C + d * (Ro - ep * 0.5) + ay * s * (prof / 2 + 0.002), ay * s, 0.012 * k + 0.004, M["rivet"])
    for i in range(nchev):
        a = math.pi / 2 + TAU * i / nchev
        d = V((math.cos(a), 0.0, math.sin(a)))
        for s in (-1, 1):
            chevron(g, C + d * (Ro - ep * 0.45) + ay * s * prof / 2, d, ay * s, s=1.15 * k + 0.25,
                    lampe=(s < 0 or k >= 0.9))
    rng = random.Random(graine)
    nst = max(5, int(28 * k * k + 4))
    for s in (-1, 1):
        for i in range(nst):
            rr = (Rh - 0.05 * k - 0.02) * math.sqrt(rng.random())
            a = TAU * rng.random()
            p = C + V((rr * math.cos(a), 0.0, rr * math.sin(a))) + ay * s * prof * 0.15
            etoile(g, p, ay * s, (0.014 + 0.007 * rng.random()) * min(1.0, 0.6 + 0.4 * k), croix=(i % 8 == 3 and k >= 0.9))


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 27)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    # étoiles semées sur le fût de la colonne (face sud) et cerclages blancs
    rng = random.Random(1401)
    for i in range(26):
        a = math.pi + 0.15 + (math.pi - 0.3) * rng.random()
        z = 0.12 + (B["h"] - 0.24) * rng.random()
        d = V((math.cos(a), math.sin(a), 0))
        etoile(g, d * (B["R"] + 0.004) + V((0, 0, z)), d, 0.017 + 0.006 * rng.random(), croix=(i % 8 == 3))
    for zz in (B["h"] * 0.3, B["h"] * 0.75):
        g.tube_shell((0, 0, zz), "z", B["R"] + 0.025, B["R"] - 0.02, 0.05, M["blanc_lunaire"], n=64, what="cerclage")
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.52, 4, M["emit2"], a0=math.pi + 0.3, span=math.pi - 0.6)
    P2.grating(g, 1.65, 1.95, Y(-1.3), Y(1.45), 0.07, M)
    P2.grating(g, -1.95, -1.65, Y(-1.1), Y(1.1), 0.07, M)
    # sud : CONTENEURS DE FRET blanc lunaire à chevrons (à la place des caisses ouvertes)
    with at(g, -1.45, -1.95, 0.45):
        conteneur(g, 0.84, 0.74, 0.36, 1411)
    with at(g, 1.45, -1.95, -0.45):
        conteneur(g, 0.84, 0.74, 0.36, 1412)
    tremie_cadran(g, c)
    meteorite(g, 0.92, Y(-2.41), c)
    corps.collecteur(g, c, ombilical, r=0.06)
    fibre(g, [(-1.8, Y(-1.15), 0.18), (-1.8, Y(0.0), 0.22), (-1.8, Y(1.2), 0.18)], 0.045)
    fibre(g, [(1.8, Y(-1.25), 0.18), (1.8, Y(0.1), 0.22), (1.8, Y(1.35), 0.18)], 0.045)
    for s in (-1, 1):
        ombilical(g, [(s * 0.72, Y(-2.55), 0.14), (s * 1.3, Y(-2.6), 0.16), (s * 1.95, Y(-2.45), 0.14)], 0.055)
    # tourelles secondaires (3), l'une portant une antenne-relais blanche (rappel de l'orbite)
    for i, (x, yn, rz) in enumerate([(-2.4, -2.5, -0.3), (2.4, -2.5, 0.3), (2.4, 2.45, -0.7)]):
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.46, 0.0, 0.32, 8, M, [M["indigo_nuit"], M["noir_spatial"]], gussets=False)
            mini_turret(g, (0, 0, 0.32), 1.02, rz, antenne=(i == 2))
    # ouest : CENTRALE D'ANCRAGE (caissons blancs, cartes stellaires)
    centrale(g)
    fibre(g, [(-1.98, Y(0.7), 0.45), (-1.78, Y(0.75), 0.72), (-1.52, Y(0.62), 0.86)], 0.04)
    fibre(g, [(-1.98, Y(-0.6), 0.45), (-1.78, Y(-0.65), 0.72), (-1.52, Y(-0.55), 0.86)], 0.04)
    cables(g, [(-1.98, Y(0.05), 0.45), (-1.75, Y(0.02), 0.7), (-1.5, Y(0.0), 0.8)])
    # nord-ouest : batterie de relais (réserve d'énergie de la Porte)
    with at(g, -2.05, 2.25, -0.6):
        PT.hull(g, -0.62, 0.62, -0.5, 0.5, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3,
                mats=[M["indigo_nuit"], M["blanc_lunaire"]], rivet_step=0.13)
        etoiles_rect(g, -0.6, 0.6, -0.48, 0.48, 0.145, 6.0, 1421)
        PT.capacitors(g, (0.0, 0.05, 0.14), 3, 2, 0.13, 0.42, M["emit2"])
        P3.lamp_group(g, (-0.5, -0.52, 0.09), (1, 0, 0), (0, -1, 0), E, M, n=3)
    ombilical(g, [(-1.6, Y(1.95), 0.5), (-1.35, Y(1.6), 0.8), (-1.1, Y(1.25), 0.95)], 0.045)
    # est : deux SPHÈRES INDIGO CONSTELLÉES à cerclages blancs
    sphere_constellee(g, 2.4, Y(1.0), 0.44, 1431)
    sphere_constellee(g, 2.4, Y(-0.55), 0.44, 1432)
    P3.cabinet(g, -2.85, -2.08, -2.85, -2.2, 0.0, 0.55, M, E)
    # sud-est : boîte ombilicale (à la place de la vanne à volants)
    boite_ombilicale(g, 1.98, 2.85, Y(-1.55), Y(-1.18), 0.3)
    ombilical(g, [(1.98, Y(-1.35), 0.34), (1.75, Y(-1.4), 0.4), (1.55, Y(-1.15), 0.56)], 0.05)
    ombilical(g, [(1.98, Y(1.0), 0.7), (1.68, Y(0.95), 1.05), (1.4, Y(0.8), 0.95)], 0.05)
    ombilical(g, [(1.98, Y(-0.55), 0.7), (1.68, Y(-0.55), 1.02), (1.42, Y(-0.4), 0.95)], 0.05)
    # NORD : L'ANNEAU DE LA PORTE (à la place du radiateur), sur son berceau à deux pieds massifs
    porte_nord(g, c)
    # consoles basses à cartes stellaires de part et d'autre (les armoires hautes cachaient le pied de l'anneau)
    for (x0, x1) in ((-1.25, -0.78), (0.78, 1.25)):
        PT.hull(g, x0, x1, Y(1.62), Y(1.95), 0.0, 0.26, ins=(0.015, 0.015, 0.015), panel=0.24,
                mats=[M["indigo_nuit"], M["blanc_lunaire"]], rivet_step=0.11)
        for f in (0.25, 0.5, 0.8):
            carte_stellaire(g, (x0 + (x1 - x0) * f, Y(1.62) - 0.005, 0.15), (0, -1, 0), 0.045, int(1440 + 10 * f + x0))
    P2.anchor(g, -2.6, Y(0.0), 0.26, M)
    for x in (-0.8, 0.8):
        PT.lamp(g, (x, Y(-2.75) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    P3.lamp_group(g, (-0.4, Y(-2.75) - 0.03, 0.58), (1, 0, 0), (0, -1, 0), E, M, n=3)
    _halo(g, [(-2.4, Y(-1.2), 0.6), (2.4, Y(-2.7), 0.7), (-2.4, Y(-2.7), 0.7), (0.0, Y(-2.85), 0.5),
              (-2.05, Y(2.25), 0.8), (2.4, Y(0.2), 0.6)], 18.0)
    _halo(g, [(0.0, Y(2.42) - 0.3, 0.8)], 24.0, g.M["_emit2_rgb"])


def porte_nord(g, c):
    """L'ANNEAU DE LA PORTE (organe signature du socle) : diamètre extérieur 1,26, section 0,18 × 0,22, 9 chevrons à
    lampe, horizon PLEIN étoilé (h_ajour 0,03 au nord : un anneau ouvert enfermerait du sol), sur un berceau à deux
    pieds massifs d'indigo et une poutre de base (rien ne flotte). Sommet à 1,41, sous le h_max du nord."""
    M = g.M
    yc = Y(2.42)
    Ro = 0.63
    zc = 0.15 + Ro
    PT.hull(g, -0.75, 0.75, yc - 0.2, yc + 0.2, 0.0, 0.12, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["indigo_nuit"], M["noir_spatial"]], rivet_step=0.12)
    for s in (-1, 1):
        # pieds massifs qui embrassent la couronne au bas de l'anneau
        q0 = V((s * 0.62, yc, 0.12))
        PT.hull(g, s * 0.36 - 0.13, s * 0.36 + 0.13, yc - 0.16, yc + 0.16, 0.12, 0.42, ins=(0.015, 0.015, 0.015),
                panel=0.24, mats=[M["indigo_nuit"], M["blanc_lunaire"]], rivet_step=0.1)
        P2.wedge(g, q0 + V((-s * 0.13, 0, 0)), q0 + V((s * 0.1, 0, 0)), q0 + V((-s * 0.13, 0, 0.36)),
                 V((0, 0.3, 0)), M["indigo_nuit"], what="gousset")
        etoile(g, (s * 0.36, yc - 0.165, 0.3), (0, -1, 0), 0.018)
    anneau_porte(g, (0.0, yc, zc), Ro, 0.22, nchev=9, graine=1450, k=1.0)
    ombilical(g, [(-0.7, yc - 0.1, 0.1), (-1.0, yc - 0.45, 0.25), (-1.15, Y(1.3), 0.9)], 0.04)
    ombilical(g, [(0.7, yc - 0.1, 0.1), (1.0, yc - 0.45, 0.25), (1.15, Y(1.3), 0.9)], 0.04)


def conteneur(g, w, d, h, graine):
    """CONTENEUR DE FRET blanc lunaire à chevrons : caisson à nervures, portes indigo, chevrons en relief, étoiles sur le
    toit indigo, poignées."""
    M = g.M
    PT.hull(g, -w / 2, w / 2, -d / 2, d / 2, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.26,
            mats=[M["blanc_lunaire"], M["indigo_nuit"]], rivet_step=0.12)
    g.box((0, 0, h + 0.015), (w - 0.08, d - 0.08, 0.03), M["indigo_nuit"], "hard", what="toit")
    etoiles_rect(g, -w / 2 + 0.04, w / 2 - 0.04, -d / 2 + 0.04, d / 2 - 0.04, h + 0.031, 14.0, graine)
    for f in (-0.3, 0.0, 0.3):
        g.box((f * w, -d / 2 - 0.01, h * 0.5), (0.025, 0.02, h * 0.9), M["noir_spatial"], "hard", what="nervure")
    for f in (-0.15, 0.15):
        chevron(g, (f * w, -d / 2 - 0.012, h * 0.62), (0, 0, 1), (0, -1, 0), s=1.0, lampe=(f < 0))
    for s in (-1, 1):
        g.box((s * (w / 2 + 0.012), 0, h * 0.7), (0.02, d * 0.4, 0.02), M["noir_spatial"], "hard", what="poignee")


def centrale(g):
    """Groupe de l'ouest : CENTRALE D'ANCRAGE (deux caissons blancs à bandes indigo étoilées, cartes stellaires, brides
    à chevrons, conduits de fibre)."""
    M = g.M
    x0, x1, y0, y1 = -2.88, -1.98, Y(-1.35), Y(1.35)
    cy = (y0 + y1) / 2
    for (ya, yb_, h) in ((y0, cy - 0.06, 0.55), (cy + 0.06, y1, 0.48)):
        PT.hull(g, x0, x1, ya, yb_, 0.0, h, ins=(0.02, 0.02, 0.03), panel=0.28,
                mats=[M["blanc_lunaire"], M["blanc_lunaire"], M["indigo_nuit"]], rivet_step=0.12)
        g.box(((x0 + x1) / 2, (ya + yb_) / 2, h + 0.02), (x1 - x0 - 0.1, yb_ - ya - 0.1, 0.04), M["indigo_nuit"], "hard",
              what="toit")
        etoiles_rect(g, x0 + 0.06, x1 - 0.06, ya + 0.06, yb_ - 0.06, h + 0.041, 9.0, int(1460 + 100 * h))
        for f in (0.22, 0.5, 0.86):
            carte_stellaire(g, (x1 + 0.005, ya + (yb_ - ya) * f, h * 0.55), (1, 0, 0), 0.05, int(1470 + 40 * f + 10 * h))
        g.box((x1 + 0.012, (ya + yb_) / 2, h * 0.2), (0.012, yb_ - ya - 0.1, 0.05), M["indigo_nuit"], "hard",
              what="bande")
    fibre(g, [((x0 + x1) / 2, cy - 0.3, 0.58), ((x0 + x1) / 2, cy, 0.7), ((x0 + x1) / 2, cy + 0.3, 0.52)], 0.04)


def sphere_constellee(g, x, y, r, graine):
    """SPHÈRE INDIGO CONSTELLÉE sur trépied court (même place et même masse que le réservoir debout) : cerclages blancs,
    étoiles semées, hublot blanc bleuté, ombilical vers la colonne."""
    M = g.M
    rs = r * 1.08
    zc = 0.12 + rs * 0.95
    for k in range(3):
        a = TAU * k / 3 + 0.5
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, zc * 0.5)) + d * rs * 0.55, (0.07, 0.07, zc - 0.05), M["blanc_lunaire"], "hard",
              R=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(-0.25, 3, "Y"), what="pied")
        g.box(V((x, y, 0.04)) + d * rs * 0.72, (0.16, 0.16, 0.08), M["noir_spatial"], "hard", what="semelle")
    g.cyl((x, y, 0.06), "z", r * 0.8, 0.12, M["noir_spatial"], n=24, style="soft", what="socle")
    g.sphere((x, y, zc), rs, M["indigo_nuit"], n=32, m=16, what="sphere")
    for zz in (-0.35, 0.05, 0.45):
        rr = rs * math.cos(math.asin(zz))
        g.torus((x, y, zc + rs * zz), "z", rr + 0.006, 0.018, M["blanc_lunaire"], n=48, m=6, what="cerclage")
    rng = random.Random(graine)
    for i in range(18):
        a = math.pi + 0.1 + (math.pi - 0.2) * rng.random() + (0.0 if rng.random() < 0.8 else math.pi)
        e = -0.2 + 1.0 * rng.random()
        d = V((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        etoile(g, V((x, y, zc)) + d * (rs + 0.002), d, 0.017 + 0.006 * rng.random(), croix=(i % 8 == 3))
    d = V((math.cos(-1.9), math.sin(-1.9), 0.2)).normalized()
    p = V((x, y, zc)) + d * rs
    g.cyl(p, d, 0.08, 0.04, M["blanc_lunaire"], n=16, what="hublot")
    g.cyl(p + d * 0.022, d, 0.055, 0.006, M["horizon_porte"], n=16, style="flat", what="hublot_fond")
    g.tube_shell(p + d * 0.025, d, 0.06, 0.05, 0.004, M["emit2"], n=16, what="hublot_bord")
    g.cyl((x, y, zc + rs + 0.03), "z", rs * 0.28, 0.07, M["blanc_lunaire"], n=18, what="bride")
    for k in range(3):
        a = TAU * k / 3
        chevron(g, (x + rs * 0.28 * math.cos(a), y + rs * 0.28 * math.sin(a), zc + rs + 0.065),
                (math.cos(a), math.sin(a), 0), (0, 0, 1), s=0.8, lampe=False)
    ombilical(g, [tuple(V((x, y, zc)) + V((-1, 0, 0)) * rs * 0.9), (x - rs - 0.25, y, zc * 0.6),
                  (x - rs - 0.4, y, 0.3)], 0.045)


def boite_ombilicale(g, x0, x1, y0, y1, h):
    """Boîte ombilicale (sud-est) : caisson blanc à bande indigo étoilée, 3 cartes stellaires à espacements inégaux,
    2 ombilicaux debout à rotules."""
    M = g.M
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.22, mats=[M["blanc_lunaire"], M["indigo_nuit"]],
            rivet_step=0.12)
    w = x1 - x0
    for f in (0.16, 0.4, 0.82):
        carte_stellaire(g, (x0 + w * f, y0 - 0.005, h * 0.55), (0, -1, 0), 0.045, int(1480 + 50 * f))
    yc = (y0 + y1) / 2
    for f in (0.3, 0.7):
        x = x0 + w * f
        ombilical(g, [(x, yc, h), (x, yc, h + 0.18), (x - 0.06, yc + 0.2, h + 0.26)], 0.038)


def carte_stellaire(g, p, nrm, r, graine):
    """CARTE STELLAIRE : petit écran rond noir cerclé de blanc, 3 à 6 points blancs (≤ 0,02 t²)."""
    M = g.M
    p = V(p)
    n = V(nrm).normalized()
    g.cyl(p + n * 0.01, n, r, 0.02, M["blanc_lunaire"], n=16, style="hard", what="carte")
    g.cyl(p + n * 0.021, n, r * 0.8, 0.004, M["horizon_porte"], n=16, style="flat", what="ecran")
    _, u, w = basis(n)
    rng = random.Random(graine)
    for i in range(3 + rng.randrange(4)):
        rr = r * 0.6 * math.sqrt(rng.random())
        a = TAU * rng.random()
        g.cyl(p + n * 0.024 + (u * math.cos(a) + w * math.sin(a)) * rr, n, 0.008, 0.003, M["emit"], n=6, style="flat",
              what="point_carte")


def meteorite(g, x, y, c):
    """FRAGMENT DE MÉTÉORITE sombre (roche noire à éclats ternes, sans lumière) tenu dans un berceau à 3 pinces
    blanches sur un socle indigo (rappel des pluies de météorites)."""
    M = g.M
    g.cyl((x, y, 0.06), "z", 0.25, 0.12, M["indigo_nuit"], n=24, style="soft", what="socle")
    g.tube_shell((x, y, 0.11), "z", 0.26, 0.2, 0.03, M["blanc_lunaire"], n=24, what="cerclage")
    F.lump(g, (x, y, 0.3), 0.2, M["roche"], sz=0.8, n=12, m=7, jit=0.3, what="meteorite")
    for k in range(3):
        a = TAU * k / 3 + 0.4
        d = V((math.cos(a), math.sin(a), 0))
        q = V((x, y, 0.12)) + d * 0.2
        P2.wedge(g, q, q + d * 0.06, q + d * 0.02 + V((0, 0, 0.3)), V((-d.y, d.x, 0)) * 0.05, M["blanc_lunaire"],
                 what="pince")
        P2.wedge(g, q + d * 0.02 + V((0, 0, 0.3)), q + d * 0.04 + V((0, 0, 0.26)), q - d * 0.06 + V((0, 0, 0.36)),
                 V((-d.y, d.x, 0)) * 0.05, M["blanc_lunaire"], what="pince")


def mini_turret(g, c, s, rz, antenne=False):
    """Tourelle secondaire LA PORTE : couronne rivetée de la lignée, caisson indigo étoilé à cerclage blanc, petit
    ANNEAU-PORTE debout sur le dos ; deux petits canons de l'époque ; antenne=True : coupelle-relais blanche (pas
    d'or)."""
    M = g.M
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["armor2"], n=32, style="soft", what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    PT.hull(g, -0.24 * s, 0.24 * s, -0.3 * s, 0.24 * s, 0.1 * s, 0.3 * s, ins=(0.03 * s, 0.03 * s, 0.05 * s),
            panel=0.22, mats=[M["indigo_nuit"], M["blanc_lunaire"]])
    etoiles_rect(g, -0.2 * s, 0.2 * s, -0.26 * s, 0.2 * s, 0.302 * s, 20.0, int(1490 + 100 * rz))
    if antenne:
        cc = V((0.0, -0.12 * s, 0.3 * s))
        g.cyl(cc + V((0, 0, 0.12)), "z", 0.018, 0.24, M["blanc_lunaire"], n=10, what="mat")
        F.dish(g, cc + V((0, 0, 0.26)), 0.13, 0.05, M["blanc_lunaire"], M["blanc_lunaire"], rx=0.5, rz=0.4, horn=True)
    else:
        anneau_porte(g, (0.0, -0.08 * s, 0.3 * s + 0.15), 0.15, 0.06, nchev=5, graine=int(1495 + 10 * rz), k=0.4)
        g.box((0.0, -0.08 * s, 0.3 * s + 0.01), (0.2, 0.08, 0.03), M["noir_spatial"], "hard", what="pied_anneau")
    for sx in (-1, 1):
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=[M[k] for k in RECV])
        _gun14(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    g.pop()


def tremie_cadran(g, c):
    """Trémie de l'époque (TAMBOUR du kit) : sa face ronde devient le CADRAN D'ADRESSE de la Porte, 9 glyphes en relief
    blanc lunaire et 9 points d'étoile ; ombilicaux vers la colonne."""
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    z0 = c.tremie_z0
    W = x1 - x0
    xc = (x0 + x1) / 2
    r = min(W / 2 - 0.01, (h - z0) / 2 - 0.01)
    zc = z0 + r + 0.012
    yf = y0 + 0.03 - 0.012 - 0.03
    for i in range(9):
        a = math.pi / 2 + TAU * i / 9
        d = V((math.cos(a), 0.0, math.sin(a)))
        p = V((xc, yf, zc)) + d * (r * 0.8)
        g.box(p, (0.05, 0.02, 0.022), M["blanc_lunaire"], "hard", R=Matrix.Rotation(-a, 3, "Y"), what="glyphe")
        etoile(g, p + d * 0.05 + V((0, -0.012, 0)), (0, -1, 0), 0.014)
    for s in (-1, 1):
        ombilical(g, [(s * (W / 2 + 0.05), y1 - 0.3, h * 0.6), (s * (W / 2 + 0.15), y1 + 0.2, h + 0.2),
                      (s * 0.4, y1 + 0.5, c.rt + 0.04)], 0.045)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : OMBILICAUX à rotules, conduits de FIBRE, câbles
# ------------------------------------------------------------------------------------------------
def ombilical(g, ctrl, r, sol=True):
    """OMBILICAL : tuyau blanc lunaire en segments courts (0,10 t) articulés par des ROTULES indigo (connecteurs de
    station), brides à 3 chevrons aux extrémités ; berceaux sur le pont (rien ne flotte)."""
    M = g.M
    P = g.spline(ctrl, 12)
    R = g.resample(P, 0.1)
    T2, _ = g.frames(R)
    for i in range(len(R) - 1):
        a, b = R[i], R[i + 1]
        d = b - a
        if d.length < 1e-4:
            continue
        g.cyl((a + b) / 2, d, r, d.length * 0.82, M["blanc_lunaire"], n=12, what="ombilical")
        g.sphere(b if i < len(R) - 2 else b, r * 1.12, M["indigo_nuit"], n=10, m=6, what="rotule")
    g.sphere(R[0], r * 1.12, M["indigo_nuit"], n=10, m=6, what="rotule")
    for i in (0, len(R) - 1):
        g.cyl(R[i], T2[i], r * 1.5, 0.03, M["blanc_lunaire"], n=16, style="hard", what="bride")
        for k in range(3):
            a = TAU * k / 3
            _, u, w = basis(T2[i])
            d = u * math.cos(a) + w * math.sin(a)
            g.box(R[i] + d * r * 1.5 + T2[i] * 0.01, (0.022, 0.022, 0.022), M["noir_spatial"], "hard", what="chevron")
    for i in range(0, len(R), 3):
        if sol and R[i].z - r > 0.03:
            g.box(V((R[i].x, R[i].y, (R[i].z - r) / 2)), (0.045, 0.045, R[i].z - r), M["noir_spatial"], "hard",
                  what="berceau")


def fibre(g, ctrl, r, sol=True):
    """Conduit de FIBRE : tube fin indigo où courent des points d'étoile (chenillard), colliers blancs."""
    M = g.M
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["indigo_nuit"], n=10, what="fibre")
    R = g.resample(P, 0.08)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 3 == 0:
            g.tube_shell(R[i], T2[i], r + 0.012, r * 0.5, 0.025, M["blanc_lunaire"], n=10, what="collier")
        elif i % 3 == 1:
            _, u, w = basis(T2[i])
            g.sphere(R[i] + w * r * 0.85, 0.012, M["emit"], n=8, m=5, what="point_fibre")
    for i in range(len(R)):
        if sol and i % 4 == 0 and R[i].z - r > 0.03:
            g.box(V((R[i].x, R[i].y, (R[i].z - r) / 2)), (0.04, 0.04, R[i].z - r), M["noir_spatial"], "hard",
                  what="berceau")


def cables(g, ctrl, n=3):
    M = g.M
    PT.cable_run(g, ctrl, n, 0.02, 0.045, [M["rubber"], M["blanc_lunaire"], M["rubber"]])


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 28 : 2 RELAIS DE LA PORTE
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.22, Y(-2.97), sx)
    _halo(g, [(-1.22, Y(-3.3), 0.4), (1.22, Y(-3.3), 0.4)], 14.0, g.M["_emit2_rgb"])


def even_piece(g, x, yb, sx):
    """RELAIS DE LA PORTE : petit anneau debout de 0,36 de diamètre (5 chevrons, horizon étoilé PLEIN) sur un affût
    blindé indigo à caisson de batterie blanc lunaire ; ombilical vers le pont."""
    M = g.M
    E = M["emit"]
    w, d = 0.62, 0.6
    PT.hull(g, x - w / 2, x + w / 2, yb - d / 2, yb + d / 2, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["indigo_nuit"], M["noir_spatial"]], rivet_step=0.12)
    g.hazard([V((x - w / 2, yb - d / 2 - 0.02, 0.02)), V((x + w / 2, yb - d / 2 - 0.02, 0.02)),
              V((x + w / 2, yb - d / 2 - 0.02, 0.12)), V((x - w / 2, yb - d / 2 - 0.02, 0.12))], 6, t=0.012, skew=0.6)
    P3.lamp_group(g, (x - w / 2 + 0.06, yb - d / 2 - 0.025, 0.07), (1, 0, 0), (0, -1, 0), E, M, n=2,
                  shapes=("rond", "fente"))
    PT.hull(g, x + sx * 0.05 - 0.2, x + sx * 0.05 + 0.2, yb + 0.05, yb + 0.27, 0.14, 0.34, ins=(0.015, 0.015, 0.015),
            panel=0.2, mats=[M["blanc_lunaire"], M["indigo_nuit"]], rivet_step=0.1)
    etoiles_rect(g, x + sx * 0.05 - 0.18, x + sx * 0.05 + 0.18, yb + 0.07, yb + 0.25, 0.342, 30.0, int(1500 + 10 * sx))
    zc = 0.14 + 0.06 + 0.2
    g.box((x, yb - 0.12, 0.17), (0.3, 0.12, 0.06), M["indigo_nuit"], "hard", what="affut")
    for s in (-1, 1):
        g.box((x + s * 0.13, yb - 0.12, 0.25), (0.06, 0.1, 0.16), M["indigo_nuit"], "hard", what="pied")
    anneau_porte(g, (x, yb - 0.12, zc), 0.2, 0.08, nchev=5, graine=int(1510 + 10 * sx), k=0.55)
    ombilical(g, [(x - sx * 0.2, yb + 0.2, 0.3), (x - sx * 0.35, yb + 0.4, 0.22), (x - sx * 0.42, yb + 0.6, 0.1)],
              0.035)


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon effilé à ANNEAU-PORTE
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse indigo étoilée, moteur arrière, canon de l'époque,
    masque de canon, CASSETTES ORBITALES à l'alimentation, voyants."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun14(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["indigo_nuit"], M["blanc_lunaire"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    zt = zg + hr + 0.012
    etoiles_rect(g, x - wr * 0.42, x + wr * 0.42, y0 + 0.1, y1 - 0.12, zt, 12.0, int(1520 + 10 * sx))
    for f in (0.35, 0.7):
        g.box((x, y0 + (y1 - y0) * f, zt + 0.012), (wr * 0.9, 0.035, 0.024), M["blanc_lunaire"], "hard",
              what="cerclage")


def _gun14(g, x, y0, z, L, nb, rb, rr):
    """Canon effilé du kit (bague et manchon blanc lunaire, pointes blanches : une étoile au bout de chaque tube) +
    ANNEAU-PORTE à la culasse : couronne blanc lunaire à 9 chevrons enfilée sur la base du faisceau, horizon indigo
    étoilé PLEIN entre le faisceau et la couronne (les tubes le traversent). Il s'AJOUTE à la rosette (règle d'or 1).
    En pose E : un collier épais à chevrons ; en pose N : un CERCLE vu de face au pied du faisceau."""
    M = g.M
    k = F.k_arme(rb, rr)
    R0 = rr + rb
    corps.canon_effile(g, x, y0, z, L, nb, rb, rr, jaquette=0.3, bague_mat="blanc_lunaire", conv=0.58,
                       frein=(0.66, 0.8))
    cy = y0 + 0.13 * k + 0.07
    Ro = R0 + 0.13 * k + 0.01
    ep = 0.06 * k + 0.012
    prof = 0.07 * k + 0.02
    g.tube_shell((x, cy, z), "y", Ro, Ro - ep, prof, M["blanc_lunaire"], n=48, what="anneau_porte")
    g.tube_shell((x, cy, z), "y", Ro - ep + 0.002, R0 * 0.96, prof * 0.4, M["horizon_porte"], n=48, what="horizon")
    for s in (-1, 1):
        g.tube_shell((x, cy + s * prof * 0.21, z), "y", Ro - ep + 0.004, Ro - ep - 0.014 * k - 0.004, 0.004, M["emit2"],
                     n=48, what="bord_horizon")
    nchev = 9 if k >= 0.9 else 5
    for i in range(nchev):
        a = math.pi / 2 + TAU * i / nchev
        d = V((math.cos(a), 0.0, math.sin(a)))
        for s in (-1, 1):
            chevron(g, V((x, cy + s * prof / 2, z)) + d * (Ro - ep * 0.45), d, V((0, s, 0)), s=0.55 * k + 0.2,
                    lampe=(k >= 0.9))
    if k >= 0.9:
        rng = random.Random(int(1530 + 100 * x))
        for s in (-1, 1):
            for i in range(7):
                a = TAU * rng.random()
                rr_ = R0 * 1.02 + (Ro - ep - R0 * 1.04) * rng.random()
                etoile(g, V((x + rr_ * math.cos(a), cy + s * prof * 0.21, z + rr_ * math.sin(a))), V((0, s, 0)), 0.013)
    return y0 + L


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisson indigo (volume de la lignée), 3 CASSETTES ORBITALES blanc lunaire à poignées et
    chevrons, goulotte, voyants."""
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
            mats=[M["indigo_nuit"], M["noir_spatial"]], rivet_step=0.11)
    ztop = zb1 + 0.015
    for kk in range(3):
        yy = yb0 + bl * (0.2 + 0.24 * kk)
        PT.hull(g, bc - bw * 0.4, bc + bw * 0.4, yy - 0.09, yy + 0.09, ztop - 0.01, ztop + 0.1, ins=(0.01, 0.01, 0.01),
                panel=0.2, mats=[M["blanc_lunaire"], M["indigo_nuit"]], rivet_step=0.08)
        g.box((bc, yy, ztop + 0.12), (bw * 0.5, 0.02, 0.02), M["noir_spatial"], "hard", what="poignee")
        for s in (-1, 1):
            g.box((bc + s * bw * 0.25, yy, ztop + 0.11), (0.02, 0.02, 0.03), M["noir_spatial"], "hard", what="poignee")
        chevron(g, (bc, yy - 0.092, ztop + 0.045), (0, 0, 1), (0, -1, 0), s=0.7, lampe=(kk == 1))
    P2.feed_chute(g, [(bc, yb0 + bl * 0.88, ztop + 0.01), (bc - sx * 0.05, y0 + bl * 0.75, zg + bh * 0.55),
                      (x + sx * wr * 0.25, y0 + bl * 0.6, zg + hr + 0.06)], 0.12 * wr / 0.4 + 0.04, M)
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.06, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=3, shapes=("rond", "carre", "fente"))
    return bc


def dome_gun(g, c, nb, L, s=1.0):
    """TÉLESCOPE de l'observatoire : canon de coupole posé dans la fente du dôme bas (corps.z_coque), berceau indigo à
    cerclages blancs, canon de l'époque à anneau-porte."""
    M = g.M
    yb = -0.35 * s
    zr = max(corps.z_coque(c, xx, yy) for xx in (-0.32 * s, 0.0, 0.32 * s)
             for yy in (yb - 0.2 * s, yb, yb + 0.3 * s, yb + 0.62 * s)) + 0.02
    zc = zr + 0.3 * s
    zs_ = corps.z_coque(c, 0.0, yb + 0.22 * s) - 0.05
    g.cyl((0.0, yb + 0.22 * s, (zs_ + zr) / 2), "z", 0.2 * s, zr - zs_, M["indigo_nuit"], n=24, what="pivot")
    g.tube_shell((0.0, yb + 0.22 * s, zr - 0.04), "z", 0.22 * s, 0.18 * s, 0.04, M["blanc_lunaire"], n=24, what="cerclage")
    PT.hull(g, -0.34 * s, 0.34 * s, yb - 0.2 * s, yb + 0.62 * s, zr - 0.04, zr + 0.18 * s, ins=(0.04, 0.04, 0.08),
            panel=0.22, mats=[M["indigo_nuit"], M["blanc_lunaire"]], rivet_step=0.11)
    etoiles_rect(g, -0.3 * s, 0.3 * s, yb - 0.16 * s, yb + 0.1 * s, zr + 0.18 * s + 0.002, 20.0, 1540)
    PT.receiver(g, 0.0, yb - 0.2 * s, yb + 0.62 * s, zc - 0.16 * s, zc + 0.14 * s, 0.34 * s, mats=[M[k] for k in RECV])
    _gun14(g, 0.0, yb + 0.62 * s, zc, L, nb, 0.05 * s, 0.12 * s)
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.24 * s, yb + 0.25 * s, zr + 0.02), (sx * 0.3 * s, yb + 0.55 * s, zr + 0.18 * s), 0.024)
    return zc


# ------------------------------------------------------------------------------------------------
# Masque et tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=("blanc_lunaire", "indigo_nuit"), fentes=((-0.42, 0.34), (0.42, 0.22)),
                        visiere=("blanc_lunaire", 0.13),
                        coax=dict(fut="noir_spatial", manchon="blanc_lunaire", manchon_y=0.28, manchon_r=0.045,
                                  manchon_L=0.16))


def tete(g, c):
    M = g.M
    E = M["emit"]
    H = c.H
    R = H["R"]
    z0 = c.rt
    zs = H["zs"]
    # la NUIT entre les piliers : étoiles sur l'âme sombre de la colonnade (entre deux colonnes)
    ncol = max(12, int(TAU * R * 0.93 / 0.16))
    rng = random.Random(1550)
    for k in range(ncol):
        if rng.random() < 0.45:
            continue
        a = TAU * k / ncol
        d = V((math.cos(a), math.sin(a), 0))
        z = z0 + 0.16 + (zs - z0 - 0.3) * rng.random()
        etoile(g, d * (R * 0.82 + 0.003) + V((0, 0, z)), d, 0.016 + 0.006 * rng.random(), croix=(k % 8 == 3))
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, zs + 0.15), (sx * R * 0.62, -R * 0.42, zs + 0.3), (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
        fibre(g, [(sx * 0.6, -R - 0.3, zs + 0.1), (sx * R * 0.78, -R * 0.5, zs + 0.2),
                  (xe, ye + 0.2, H["zg"] + H["hr"] * 0.55)], 0.032, sol=False)
    # coupole OBSERVATOIRE : plaques indigo à liseré blanc sur le pourtour, ÉTOILES semées sur la coque
    row1 = (0.35, 0.8, 2.35, 2.8, -0.35, -0.8, -2.35, -2.8)
    for i, th in enumerate(row1):
        P2.applique(g, c.Pf, c.Nf, th, 0.3, 0.3, 0.22, M["indigo_nuit2"] if i % 2 else M["blanc_lunaire"], M)
    for i in range(40):
        th = TAU * rng.random()
        if abs(math.cos(th)) < 0.18:      # la fente (avant et arrière) reste libre
            continue
        ph = 0.15 + 1.25 * rng.random()
        p = c.Pf(th, ph, 1.0)
        n = c.Nf(th, ph)
        etoile(g, p + n * 0.006, n, 0.017 + 0.006 * rng.random(), croix=(i % 8 == 3))
    # FENTE D'OBSERVATION de 0,12 t de large, du masque à la nacelle : noire, semée d'étoiles, rails blancs
    for th in (math.pi / 2, -math.pi / 2):
        n_ = 14
        for i in range(n_):
            ph0, ph1 = 0.12 + 1.38 * i / n_, 0.12 + 1.38 * (i + 1) / n_
            p0, p1 = c.Pf(th, ph0, 1.01), c.Pf(th, ph1, 1.01)
            pm = (p0 + p1) / 2
            nm = c.Nf(th, (ph0 + ph1) / 2)
            tg = (p1 - p0).normalized()
            sd = nm.cross(tg).normalized()
            Rm = Matrix((sd, tg, nm)).transposed()
            g.box(pm, (0.13, (p1 - p0).length + 0.004, 0.012), M["horizon_porte"], "hard", R=Rm, what="fente_obs")
            for s in (-1, 1):
                g.box(pm + sd * s * 0.078 + nm * 0.006, (0.026, (p1 - p0).length + 0.004, 0.024), M["blanc_lunaire"],
                      "hard", R=Rm, what="rail_fente")
            if i % 2 == 0:
                etoile(g, pm + nm * 0.008 + sd * (0.03 if i % 4 else -0.03), nm, 0.014)
    dome_gun(g, c, 6, 1.75, 1.0)
    # nacelle : console de cartes stellaires et petite antenne-relais blanche
    bx, yb0, yb1 = c.nac[:3]
    znac = zs + H["rz"] * 0.42
    PT.hull(g, -0.3, 0.3, yb0 + 0.1, yb0 + 0.42, znac, znac + 0.16, ins=(0.015, 0.015, 0.015), panel=0.2,
            mats=[M["blanc_lunaire"], M["indigo_nuit"]], rivet_step=0.1)
    for f in (-0.18, 0.0, 0.18):
        carte_stellaire(g, (f, yb0 + 0.1 - 0.004, znac + 0.08), (0, -1, 0), 0.05, int(1560 + 100 * f))
    PT.capacitors(g, (0.0, -R - 0.14, zs + H["rz"] * 0.42), 4, 1, 0.1, 0.22, M["emit2"])
    xs_, ys_ = -R * 0.64, R * 0.3
    PT.sight(g, (xs_, ys_, corps.z_coque(c, xs_, ys_) - 0.18), 0.26, 0.26, 0.15, E, lenses=2)


def _dans_habillage(f):
    def w(g, c, *a, **k):
        with corps.habille(g, c):
            return f(g, c, *a, **k)
    w.__name__, w.__doc__ = f.__name__, f.__doc__
    return w


socle, piece, arme, tete, masque = [_dans_habillage(_f) for _f in (socle, piece, arme, tete, masque)]
