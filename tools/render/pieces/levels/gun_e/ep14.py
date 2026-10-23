"""Époque 14 · Orbite (ère V, 6×6, niveaux 27 et 28). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 14) : « or, paraboles, balises ».
Bien lue à l'aveugle en passe 3 : identité GARDÉE. Quatrième passe (23/10), corrections du constructeur de la plage
haute :
  - ARME (règle d'or 1) : l'émetteur s'AJOUTE à la rosette de la lignée : corps en feuille d'or sanglé et panneau
    replié sur la moitié arrière seulement, PARABOLE dorée déplacée sur le DOS du corps (elle ne masque plus la
    bouche), 6 tubes à colliers isolants sur la moitié avant, FREIN À CAPTEUR ANNULAIRE (catalogue) plus large que le
    faisceau, rosace éclairée au centre, balise rouge ;
  - MOITIÉ SUD propre à l'époque : trémie blanc cassé à flancs de COUVERTURE THERMIQUE NOIRE sanglée et BRAS ARTICULÉ
    de chargement à vérin, CONTENEURS SOUS COUVERTURE THERMIQUE noire à la place des caisses ouvertes, tourelles
    secondaires sous couverture noire à petite PARABOLE, BOÎTE OMBILICALE à câbles dorés au sud-est (à la place des
    volants), balises rouges de bordure ;
  - 2e matière d'époque : couverture thermique (kapton) NOIRE ; couvertures multicouches blanc cassé sur la coupole
    (12 plaques) ; canons longue portée (L 2,85) ; paraboles de l'est relevées sur mât et paraboles en PÉTALES
    (nervures, moyeu, raidisseurs : jamais une grande plage d'or lisse, C6 de la charte) ; champ de panneaux du nord
    dressé sur mâts ; batterie de l'ouest alternée or et noir.
Inchangés de la passe 3 : canon de coupole, 3 tourelles secondaires, liaisons (câbles gainés de feuille d'or,
sangles), grande parabole au sommet (en pétales), panneaux repliés sur la nacelle, pièce paire (2 paraboles de
conduite de tir).
"""
import math

from mathutils import Matrix, Vector

import corps
import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from corps import Y, at
from kit import SQ2, TAU, axv, basis

V = Vector

EPOQUE = 14
NOM = "Orbite"
FOYER = dict(rgb=(1.0, 0.165, 0.165), rgb2=(0.184, 0.42, 1.0))
CANON = dict(L=2.85, nb=6, rb=0.072, rr=0.175)
PLATEFORME = dict(chanfrein=0.2)
HABILLAGE = dict(jupe_cerclage="ring", chapeau="ring", tremie="ring", munitions=("jacket", "steel_hi"))
RECV = ("ring", "olive")


def matieres(metal, M):
    """Orbite : feuille d'or froissée, blanc cassé patiné, cellules bleu nuit (≤ 5 %)."""
    metal("jacket", (0.6, 0.4, 0.08), rough=0.3, met=1.0, grain=0.45, gscale=22.0, rust=(0.25, 0.14, 0.04),
          ra=0.12, dirt=0.75, stain=0.5, sscale=7.0, wear=0.4)
    metal("ring", (0.44, 0.42, 0.37), rough=0.5, met=0.05, grain=0.14, gscale=30.0, rust=(0.2, 0.1, 0.05),
          ra=0.12, dirt=0.95, stain=0.7, sscale=5.0, wear=0.8, streak=0.6)
    M["trim"] = M["jacket"]
    M["pipe"] = M["jacket"]
    M["pipe2"] = M["ring"]
    M["cable_a"], M["cable_b"] = M["rubber"], M["redcable"]
    metal("spec", (0.012, 0.02, 0.075), rough=0.14, met=0.6, grain=0.05, dirt=0.3, stain=0.0)      # cellules
    # couverture thermique NOIRE (kapton) froissée, quatrième passe : 2e matière d'époque, sur les conteneurs, les
    # tourelles secondaires et les flancs de trémie (l'or reste sur les canons, les paraboles et la batterie)
    metal("kapton", (0.03, 0.026, 0.022), rough=0.42, met=0.3, grain=0.2, gscale=30.0, dirt=0.6, stain=0.4,
          sscale=6.0, wear=1.2)
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 29 de l'industriel ; 14 : 3 tourelles secondaires)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    ring_lights(g, B["R"] - 0.08, B["h"] + B["rh"] + 0.02)
    ng = 9
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    P2.grating(g, 1.65, 1.95, Y(-1.3), Y(1.45), 0.07, M)
    P2.grating(g, -1.95, -1.65, Y(-1.1), Y(1.1), 0.07, M)
    with at(g, -1.45, -1.95, 0.45):
        foil_crate(g, 0.84, 0.78, 0.34)
    with at(g, 1.45, -1.95, -0.45):
        foil_crate(g, 0.84, 0.78, 0.34)
    tremie_arm(g, c)
    # balises rouges de bordure (feux de position) sur le pourtour libre de la plateforme, espacées (chacune un foyer)
    for x in (-1.95, -1.05, 0.95, 1.85):
        balise(g, (x, Y(-2.66), 0.03))
    for yn in (-1.0, 0.25, 1.5):
        balise(g, (2.72, Y(yn), 0.03))
        balise(g, (-2.72, Y(yn) + 0.3, 0.03))
    for (x, yn, rz) in [(-2.4, -2.5, -0.3), (2.4, -2.5, 0.3), (2.4, 2.45, -0.7)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.46, 0.0, 0.32, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            mini_turret(g, (0, 0, 0.32), 1.02, rz)
            signature(g, (0.18, 0.2, 0.32 + 0.4 * 1.02 - 0.02))
    # ouest : batterie dorée et panneaux ; liaisons
    west(g)
    conduit(g, [(-1.98, Y(0.7), 0.45), (-1.78, Y(0.75), 0.72), (-1.52, Y(0.62), 0.86)], 0.05)
    conduit(g, [(-1.98, Y(-0.6), 0.45), (-1.78, Y(-0.65), 0.72), (-1.52, Y(-0.55), 0.86)], 0.05)
    cables(g, [(-1.98, Y(0.05), 0.45), (-1.75, Y(0.02), 0.7), (-1.5, Y(0.0), 0.8)])
    # nord-ouest : banc de condensateurs en biais (réserve d'énergie visible)
    with at(g, -2.05, 2.25, -0.6):
        PT.hull(g, -0.62, 0.62, -0.5, 0.5, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3, mats=[M["steel_dk"]],
                rivet_step=0.13)
        PT.capacitors(g, (0.0, 0.0, 0.14), 3, 2, 0.14, 0.48, E)
        P3.lamp_group(g, (-0.5, -0.52, 0.09), (1, 0, 0), (0, -1, 0), E, M, n=3)
        P3.lamp_group(g, (0.2, -0.52, 0.09), (1, 0, 0), (0, -1, 0), M["amber"], M, n=2, shapes=("carre", "fente"))
    conduit(g, [(-1.6, Y(1.95), 0.5), (-1.35, Y(1.6), 0.8), (-1.1, Y(1.25), 0.95)], 0.05)
    east(g)
    P3.cabinet(g, -2.85, -2.08, -2.85, -2.2, 0.0, 0.55, M, E)
    P3.cabinet(g, 1.95, 2.85, 2.02, 2.5, 0.0, 0.5, M, E)
    # sud-est : boîte ombilicale à câbles gainés de feuille d'or (à la place de la vanne à volants)
    foil_junction(g, 1.98, 2.85, Y(-1.55), Y(-1.18), 0.3)
    hose(g, [(1.98, Y(-1.35), 0.34), (1.75, Y(-1.4), 0.4), (1.55, Y(-1.15), 0.56)], 0.055)
    hose(g, [(1.95, Y(1.0), 0.95), (1.68, Y(0.95), 1.15), (1.4, Y(0.8), 0.95)], 0.06)
    hose(g, [(1.95, Y(-0.55), 0.95), (1.68, Y(-0.55), 1.12), (1.42, Y(-0.4), 0.95)], 0.06)
    # nord : champ de panneaux ; armoires de commande
    solar_array(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.42)
    P3.cabinet(g, -1.15, -0.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    P3.cabinet(g, 0.35, 1.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    signature(g, (-0.7, Y(1.79), 0.54))
    signature(g, (0.8, Y(1.79), 0.54), 1)
    P2.anchor(g, -2.6, Y(0.0), 0.26, M)
    for x in (-0.8, 0.8):
        PT.lamp(g, (x, Y(-2.75) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    P3.lamp_group(g, (-0.4, Y(-2.75) - 0.03, 0.58), (1, 0, 0), (0, -1, 0), E, M, n=3)
    P3.lamp_group(g, (0.2, Y(-2.75) - 0.03, 0.47), (1, 0, 0), (0, -1, 0), E, M, n=2, shapes=("fente", "rond"))
    _halo(g, [(-2.4, Y(-1.2), 0.6), (2.4, Y(-2.7), 0.7), (-2.4, Y(-2.7), 0.7), (0.0, Y(-2.85), 0.5),
              (-2.05, Y(2.25), 0.8), (2.4, Y(0.2), 0.6)], 22.0)


def ring_lights(g, R, z):
    """Feux de couronne (face sud de la couronne d'orientation) : BALISES rouges, chaque feu un foyer séparé."""
    n = 20
    M = g.M
    for k in range(n):
        a = math.pi + math.pi * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0))
        p = V((0, 0, z)) + d * R
        g.cyl(p + V((0, 0, 0.02)), "z", 0.028, 0.04, M["steel_dk"], n=10, what="balise_pied")
        g.cyl(p + V((0, 0, 0.048)), "z", 0.019, 0.018, M["emit"], n=10, style="flat", what="balise")


def west(g):
    """Groupe de l'ouest : BATTERIE en feuille d'or et 2 PANNEAUX solaires inclinés (cellules ≤ 5 %), balises."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = -2.88, -1.98, Y(-1.35), Y(1.35), 0.6
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    F.plinth(g, x0, x1, y0, y1, 0.16)
    r = (x1 - x0) * 0.26
    zc = 0.16 + r + 0.02
    for i in range(4):
        g.crumple((cx - (x1 - x0) * 0.18, y0 + 0.2 + (y1 - y0 - 0.4) * (i + 0.5) / 4, zc), "y", r,
                  (y1 - y0 - 0.4) / 4 - 0.02, M["kapton"] if i % 2 == 0 else M["jacket"], n=20, k=3, amp=0.014)
    for i in range(5):
        yy = y0 + 0.2 + (y1 - y0 - 0.4) * i / 4
        g.tube_shell((cx - (x1 - x0) * 0.18, yy, zc), "y", r + 0.02, r - 0.03, 0.04, M["ring"], n=24, what="sangle")
        for kk in range(7):
            a = TAU * (kk + 0.5) / 7
            d = V((math.cos(a), 0, math.sin(a)))
            if d.z < -0.3:
                continue
            g.dome(V((cx - (x1 - x0) * 0.18, yy, zc)) + d * (r + 0.022), d, 0.012, M["rivet"])
    F.hatches(g, (cx - (x1 - x0) * 0.18 - r * 0.45, y0 + 0.2, zc + r * 0.92),
              (cx - (x1 - x0) * 0.18 - r * 0.45, y1 - 0.2, zc + r * 0.92), 14, (-0.4, 0, 0.92), M["steel_hi"],
              size=(0.05, 0.06))
    F.hatches(g, (x0 + 0.05, y0 + 0.3, 0.16), (x0 + 0.05, y1 - 0.3, 0.16), 14, (0, 0, 1), M["ring"],
              size=(0.06, 0.06), frame=M["steel_dk"])
    P3.lamp_group(g, (x0 + 0.08, y0 - 0.02, 0.1), (1, 0, 0), (0, -1, 0), E, M, n=3)
    for (bx_, by_) in ((x1 - 0.06, y0 + 0.08), (x1 - 0.06, y1 - 0.08), (x1 - 0.06, cy)):
        g.cyl((bx_, by_, 0.19), "z", 0.024, 0.06, M["steel_dk"], n=10, what="balise_pied")
        g.cyl((bx_, by_, 0.226), "z", 0.018, 0.014, E, n=10, style="flat", what="balise")
    P3.lamp_group(g, (x0 + 0.08, y1 + 0.02, 0.1), (1, 0, 0), (0, 1, 0), M["emit2"], M, n=2)
    for j, (ya, yb) in enumerate(((y0 + 0.15, cy - 0.06), (cy + 0.06, y1 - 0.15))):
        xp = cx + (x1 - x0) * 0.24
        Rr = Matrix.Rotation(0.5, 3, "Y")
        g.box((xp, (ya + yb) / 2, 0.42), (0.34, yb - ya, 0.035), M["ring"], "hard", R=Rr, what="panneau_cadre")
        for k in range(3):
            yy0 = ya + 0.04 + (yb - ya - 0.08) * k / 3
            yy1 = yy0 + (yb - ya - 0.08) / 3 - 0.03
            g.box((xp - 0.002, (yy0 + yy1) / 2, 0.44), (0.27, yy1 - yy0, 0.006),
                  M["spec"] if k != 1 else M["jacket"], "flat", R=Rr, what="cellules")
        g.box((xp + 0.12, (ya + yb) / 2, 0.24), (0.06, 0.06, 0.24), M["steel_dk"], "hard", what="pied")
    for yy in (y0 + 0.12, cy - 0.5, cy + 0.5, y1 - 0.12):
        g.cyl((cx - (x1 - x0) * 0.18, yy, zc + r + 0.04), "z", 0.025, 0.05, M["steel_dk"], n=10, what="balise_pied")
        g.cyl((cx - (x1 - x0) * 0.18, yy, zc + r + 0.07), "z", 0.018, 0.016, E, n=10, style="flat", what="balise")


def east(g):
    """Est : deux GRANDES PARABOLES dorées sur affût blindé haut (à la place des réservoirs), tournées vers le sud et le
    haut (intérieur doré visible) ; coffre et balises."""
    M = g.M
    for (x, y, rz) in ((2.4, Y(1.0), 0.35), (2.4, Y(-0.55), -0.25)):
        PT.hull(g, x - 0.4, x + 0.4, y - 0.4, y + 0.4, 0.0, 0.3, ins=(0.04, 0.04, 0.04), panel=0.26,
                mats=[M["steel_dk"], M["olive"]], rivet_step=0.12)
        F.hatches(g, (x - 0.32, y - 0.405, 0.15), (x + 0.32, y - 0.405, 0.15), 6, (0, -1, 0), M["ring"],
                  size=(0.08, 0.06), frame=M["steel_dk"])
        g.cyl((x, y, 0.36), "z", 0.22, 0.12, M["ring"], n=28, what="pivot")
        g.cyl((x, y, 0.72), "z", 0.08, 0.66, M["steel_dk"], n=16, what="mat")
        for sx in (-1, 1):
            g.box((x + sx * 0.12, y, 1.0), (0.04, 0.12, 0.2), M["ring"], "hard", what="etrier")
        F.dish(g, (x, y, 1.12), 0.62, 0.16, M["jacket"], M["ring"], rx=0.62, rz=rz, horn=False)
        g.push((x, y, 1.12), rz=rz, rx=0.62)
        # 8 nervures radiales sombres : la coupelle se lit en PÉTALES de feuille d'or (pas de grande plage d'or lisse,
        # catalogue §B époque 14 ; C6 et L2 de la charte)
        for k_ in range(8):
            a = TAU * (k_ + 0.5) / 8
            for i_ in range(6):
                rf = 0.18 + 0.78 * (i_ + 0.5) / 6
                g.box((0.62 * rf * math.cos(a), 0.62 * rf * math.sin(a), 0.16 * rf * rf + 0.008),
                      (0.62 * 0.78 / 6 + 0.004, 0.04, 0.014), M["steel_dk"], "hard",
                      R=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(-math.atan(0.32 * rf), 3, "Y"), what="nervure")
        g.cyl((0, 0, 0.012), "z", 0.62 * 0.22, 0.03, M["steel_dk"], n=20, what="moyeu")
        for rf in (0.5, 0.78):
            g.torus((0, 0, 0.16 * rf * rf + 0.01), "z", 0.62 * rf, 0.022, M["steel_dk"], n=48, m=6, what="raidisseur")
        g.cyl((0, 0, 0.16 + 0.14), "z", 0.035, 0.28, M["steel_dk"], n=12, what="emetteur")
        g.cyl((0, 0, 0.16 + 0.3), "z", 0.06, 0.05, M["ring"], n=14, what="emetteur_tete")
        g.cyl((0, 0, 0.16 + 0.33), "z", 0.03, 0.006, M["emit2"], n=10, style="flat", what="lentille")
        g.pop()
        for s_ in (-1, 1):
            F.hatches(g, (x + s_ * 0.405, y - 0.3, 0.15), (x + s_ * 0.405, y + 0.3, 0.15), 5, (s_, 0, 0),
                      M["ring"], size=(0.07, 0.06), frame=M["steel_dk"])
        F.hatches(g, (x - 0.3, y - 0.3, 0.305), (x + 0.3, y - 0.3, 0.305), 5, (0, 0, 1), M["steel_hi"],
                  size=(0.05, 0.05))
        P3.lamp_group(g, (x - 0.3, y - 0.42, 0.24), (1, 0, 0), (0, -1, 0), M["emit"], M, n=2,
                      shapes=("rond", "fente"))
        balise(g, (x - 0.33, y - 0.33, 0.3))
        balise(g, (x - 0.33, y + 0.33, 0.3))
        g.cyl((x + 0.33, y - 0.33, 0.33), "z", 0.024, 0.06, M["steel_dk"], n=10, what="balise_pied")
        g.cyl((x + 0.33, y - 0.33, 0.37), "z", 0.018, 0.014, M["emit"], n=10, style="flat", what="balise")
    x, y = 2.74, Y(0.22)
    g.box((x, y, 0.06), (0.24, 0.24, 0.12), M["steel_dk"], "hard", what="semelle")
    g.box((x - 0.2, y, 0.1), (0.3, 0.6, 0.2), M["steel_dk"], "hard", what="coffre")
    g.cyl((x - 0.2, y - 0.31, 0.12), "z", 0.018, 0.014, M["emit"], n=10, style="flat", what="balise")


def solar_array(g, x0, x1, y0, y1, h):
    """Champ de panneaux (orbite) : cadres blanc cassé, feuille d'or, cellules bleu nuit en petites bandes."""
    M = g.M
    E = M["emit"]
    F.plinth(g, x0, x1, y0, y1, 0.12)
    F.hatches(g, (x0 + 0.1, y0 - 0.005, 0.06), (x1 - 0.1, y0 - 0.005, 0.06), 14, (0, -1, 0), M["ring"], size=(0.06, 0.05),
            frame=M["steel_dk"])
    n = 3
    for i in range(n):
        xa = x0 + 0.05 + (x1 - x0 - 0.1) * i / n
        xb = xa + (x1 - x0 - 0.1) / n - 0.06
        # panneaux DRESSÉS sur mâts (quatrième passe : silhouette propre à l'époque au nord du socle)
        Rr = Matrix.Rotation(-0.95, 3, "X")
        c = V(((xa + xb) / 2, (y0 + y1) / 2 + 0.05, 1.08))
        g.box(c, (xb - xa, (y1 - y0) * 1.1, 0.035), M["ring"], "hard", R=Rr, what="panneau_cadre")
        for j in range(4):
            v = -0.4 + 0.27 * j
            q = c + Rr @ V((0, v * (y1 - y0), 0.022))
            g.box(q, ((xb - xa) * 0.86, (y1 - y0) * 0.22, 0.006), M["spec"] if (i + j) % 3 == 0 else M["jacket"],
                  "flat", R=Rr, what="cellules")
        g.box(((xa + xb) / 2, (y0 + y1) / 2 + 0.12, 0.58), (0.08, 0.08, 0.94), M["steel_dk"], "hard", what="pied")
        g.cyl(((xa + xb) / 2, (y0 + y1) / 2 + 0.12, 1.04), "x", 0.045, 0.12, M["ring"], n=12, what="rotule")
        g.cyl((xb - 0.04, y0 + 0.06, 0.16), "z", 0.018, 0.014, E, n=8, style="flat", what="balise")
        g.cyl((xa + 0.04, y1 - 0.06, 0.16), "z", 0.018, 0.014, E, n=8, style="flat", what="balise")


def signature(g, p, kind=0):
    """Petite pièce de signature : petit panneau solaire bleu nuit encadré (≤ 5 %), balise rouge."""
    M = g.M
    p = V(p)
    R = Matrix.Rotation(-0.5, 3, "X")
    g.box(p + V((0, 0, 0.06)), (0.2, 0.16, 0.02), M["ring"], "hard", R=R, what="cadre")
    g.box(p + V((0, -0.004, 0.072)), (0.17, 0.13, 0.006), M["spec"], "flat", R=R, what="cellules")
    g.cyl(p + V((0, 0.04, 0.03)), "z", 0.012, 0.06, M["steel_dk"], n=6, what="pied")
    g.cyl(p + V((0.12, 0.05, 0.03)), "z", 0.016, 0.06, M["steel_dk"], n=8, what="balise_pied")
    g.cyl(p + V((0.12, 0.05, 0.07)), "z", 0.014, 0.02, M["emit"], n=8, style="flat", what="balise")


def mini_turret(g, c, s, rz):
    """Tourelle secondaire ORBITE : couronne rivetée de la lignée, caisson enveloppé de FEUILLE D'OR sanglée, petite
    PARABOLE dorée sur le dos, balise rouge ; les DEUX ARMES sont celles de l'époque (petits émetteurs à rosette)."""
    M = g.M
    E = M["emit"]
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["armor2"], n=32, style="soft", what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    PT.hull(g, -0.24 * s, 0.24 * s, -0.3 * s, 0.24 * s, 0.1 * s, 0.22 * s, ins=(0.02 * s, 0.02 * s, 0.02 * s),
            panel=0.22, mats=[M["ring"], M["olive"]])
    g.crumple((0.0, -0.03 * s, 0.3 * s), "y", 0.15 * s, 0.46 * s, M["kapton"], n=18, k=3, amp=0.012)
    for yy in (-0.2 * s, -0.03 * s, 0.14 * s):
        g.tube_shell((0.0, yy, 0.3 * s), "y", 0.165 * s, 0.12 * s, 0.03, M["ring"], n=20, what="sangle")
    # petite parabole sur le dos (la tourelle du nord-est est tournée vers le nord-est : tournée vers l'ouest, ses
    # petits canons fermaient un jour de 14 px hr avec le canon de flanc, poses E et N)
    g.cyl((0.0, -0.14 * s, 0.46 * s), "z", 0.04, 0.06 * s, M["steel_dk"], n=10, what="mat")
    F.dish(g, (0.0, -0.12 * s, 0.5 * s), 0.14 * s, 0.05 * s, M["jacket"], M["steel_dk"], rx=-0.35, horn=True)
    g.cyl((0.18 * s, -0.25 * s, 0.24 * s), "z", 0.016, 0.016, E, n=8, style="flat", what="balise")
    for a in (0.9, 2.3, 4.0):
        balise(g, (0.32 * s * math.cos(a), 0.32 * s * math.sin(a), 0.1 * s))
    for sx in (-1, 1):
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=[M[k] for k in RECV])
        _gun14(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    g.pop()


def balise(g, p, r=0.026):
    """Balise rouge clignotante (catalogue : petites, <= 0,01 t²) : pied sombre boulonné, verre rouge."""
    M = g.M
    p = V(p)
    g.cyl(p + V((0, 0, 0.02)), "z", r * 1.3, 0.04, M["steel_dk"], n=10, what="balise_pied")
    g.cyl(p + V((0, 0, 0.048)), "z", r, 0.018, M["emit"], n=10, style="flat", what="balise")


def foil_crate(g, w, d, h):
    """CONTENEUR SOUS COUVERTURE THERMIQUE (à la place de la caisse ouverte) : caisse blanc cassé enveloppée de
    couverture thermique NOIRE froissée, sangles blanc cassé à boucles, petit panneau de cellules bleu nuit, balise rouge."""
    M = g.M
    E = M["emit"]
    PT.hull(g, -w / 2, w / 2, -d / 2, d / 2, 0.0, 0.08, ins=(0.01, 0.01, 0.01), panel=0.3, mats=[M["ring"]],
            rivet_step=0.12)
    g.crumple((0.0, 0.0, 0.08 + h / 2), "x", min(d, h) * 0.5, w * 0.92, M["kapton"], n=16, k=4, amp=0.018)
    for f in (-0.32, 0.0, 0.32):
        g.tube_shell((f * w, 0.0, 0.08 + h / 2), "x", min(d, h) * 0.5 + 0.02, min(d, h) * 0.5 - 0.03, 0.04, M["ring"],
                     n=16, what="sangle")
        g.box((f * w, -min(d, h) * 0.3, 0.08 + h * 0.92), (0.05, 0.04, 0.03), M["steel_hi"], "hard", what="boucle")
    R = Matrix.Rotation(-0.4, 3, "X")
    g.box((w * 0.28, d * 0.38, 0.08 + h + 0.05), (w * 0.34, d * 0.3, 0.02), M["ring"], "hard", R=R, what="cadre")
    g.box((w * 0.28, d * 0.37, 0.08 + h + 0.062), (w * 0.3, d * 0.26, 0.006), M["spec"], "flat", R=R, what="cellules")
    g.cyl((-w * 0.38, -d * 0.3, 0.1), "z", 0.018, 0.014, E, n=8, style="flat", what="balise")
    for sxx, syy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        balise(g, (sxx * (w / 2 - 0.05), syy * (d / 2 - 0.05), 0.08))


def tremie_arm(g, c):
    """Trémie de l'époque : flancs couverts de FEUILLE D'OR froissée sanglée, BRAS ARTICULÉ de chargement à vérin
    (embase blanc cassé, 3 articulations, pince) qui va de la trémie à la couronne de la colonne, balises."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = c.tremie_box
    for s in (-1, 1):
        xb = (x1 if s > 0 else x0) + s * 0.07
        g.crumple((xb, (y0 + y1) / 2, h * 0.35), "y", 0.1, (y1 - y0) * 0.9, M["kapton"], n=14, k=4, amp=0.012)
        for f in (0.2, 0.5, 0.8):
            g.tube_shell((xb, y0 + (y1 - y0) * f, h * 0.35), "y", 0.115, 0.07, 0.035, M["ring"], n=14, what="sangle")
        for f in (0.08, 0.35, 0.65, 0.92):
            balise(g, (xb + s * 0.06, y0 + (y1 - y0) * f, 0.0))
    xa = x1 + 0.22
    pa = V((xa, y0 + 0.4, 0.3))
    g.cyl((xa, y0 + 0.4, 0.15), "z", 0.12, 0.3, M["ring"], n=20, what="embase")
    pm = V((xa - 0.05, y1 - 0.1, h + 0.55))
    pb = V((0.25, y1 + 0.4, c.rt + 0.18))
    for (p, q) in ((pa, pm), (pm, pb)):
        d = q - p
        g.cyl((p + q) / 2, d, 0.04, d.length, M["ring"], n=12, what="bras")
        g.crumple((p + q) / 2, d, 0.05, d.length * 0.5, M["jacket"], n=12, k=2, amp=0.008)
    for p in (pa, pm, pb):
        g.cyl(p, (1, 0, 0), 0.06, 0.09, M["steel_dk"], n=14, what="articulation")
    PT.piston(g, tuple(pa + V((0.0, 0.15, 0.05))), tuple(pm + V((0.0, -0.1, -0.12))), 0.024)
    g.box(pb + V((0, 0.06, -0.06)), (0.12, 0.1, 0.08), M["steel_dk"], "hard", what="pince")
    g.cyl((xa, y0 + 0.4, 0.31), "z", 0.018, 0.014, E, n=8, style="flat", what="balise")


def foil_junction(g, x0, x1, y0, y1, h):
    """Boîte ombilicale (sud-est) : caisson blanc cassé, connecteurs ombilicaux, câbles gainés de feuille d'or."""
    M = g.M
    E = M["emit"]
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.22, mats=[M["ring"], M["olive"]],
            rivet_step=0.12)
    w = x1 - x0
    yc = (y0 + y1) / 2
    for i in range(3):
        x = x0 + w * (0.2 + 0.3 * i)
        g.cyl((x, yc, h + 0.03), "z", 0.06, 0.06, M["steel_dk"], n=14, what="connecteur")
        g.crumple((x, yc + 0.08, h + 0.12), (0, 0.6, 0.8), 0.04, 0.22, M["jacket"], n=10, k=3, amp=0.008)
    g.cyl((x0 + 0.06, y0 + 0.06, h + 0.02), "z", 0.018, 0.014, E, n=8, style="flat", what="balise")
    for xx in (x1 - 0.06, x0 + w * 0.5):
        balise(g, (xx, y0 + 0.06, h))


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : câbles gainés de feuille d'or et sanglés, conduits isolés
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    """Gaine de feuille d'or (facettes plates) sanglée de blanc cassé."""
    M = g.M
    P, T = g.tube(g.spline(ctrl, 10), r * 1.05, M["jacket"], n=10, style="flat", what="gaine_or")
    for i in range(2, len(P) - 1, 5):
        g.cyl(P[i], T[i], r * 1.05 + 0.014, 0.03, M["ring"], n=12, style="hard", what="sangle")


def cables(g, ctrl, n=3):
    M = g.M
    PT.cable_run(g, ctrl, n, 0.02, 0.045, [M["jacket"], M["rubber"], M["jacket"]])


def conduit(g, ctrl, r):
    """Conduit d'énergie en feuille d'or : bagues lumineuses PAR GROUPES, colliers blanc cassé."""
    M = g.M
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["jacket"], n=10, what="conduit")
    R = g.resample(P, 0.075)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 4 in (1, 2):
            g.tube_shell(R[i], T2[i], r + 0.008, r * 0.5, 0.03, M["emit"], n=12, what="bague_lum")
        elif i % 4 == 3:
            g.tube_shell(R[i], T2[i], r + 0.016, r * 0.5, 0.03, M["pipe2"], n=12, what="collier")


def pipe(g, ctrl, r, valve_at=None):
    M = g.M
    g.pipe(ctrl, r, M["ring"], fl_mat=M["pipe2"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 28 : 2 paraboles de conduite de tir dorées sur affût blindé
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.22, Y(-2.97), sx)
    _halo(g, [(-1.22, Y(-3.1), 0.4), (1.22, Y(-3.1), 0.4)], 18.0)


def even_piece(g, x, yb, sx):
    """PARABOLE DE CONDUITE DE TIR DORÉE sur affût blindé : coupelle 0,30, bras, armoire, sur la plinthe commune
    (caisson blindé bas à bande de danger)."""
    M = g.M
    E = M["emit"]
    w, d = 0.62, 0.6
    PT.hull(g, x - w / 2, x + w / 2, yb - d / 2, yb + d / 2, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["steel_dk"]], rivet_step=0.12)
    g.hazard([V((x - w / 2, yb - d / 2 - 0.02, 0.02)), V((x + w / 2, yb - d / 2 - 0.02, 0.02)),
              V((x + w / 2, yb - d / 2 - 0.02, 0.12)), V((x - w / 2, yb - d / 2 - 0.02, 0.12))], 6, t=0.012, skew=0.6)
    z0 = 0.14
    P3.lamp_group(g, (x - w / 2 + 0.06, yb - d / 2 - 0.025, 0.07), (1, 0, 0), (0, -1, 0), E, M, n=2,
                  shapes=("rond", "fente"))
    PT.hull(g, x - 0.2, x + 0.2, yb - 0.2, yb + 0.2, z0, z0 + 0.22, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["ring"], M["olive"]], rivet_step=0.11)
    g.cyl((x, yb, z0 + 0.34), "z", 0.045, 0.24, M["steel_dk"], n=12, what="mat")
    for s_ in (-1, 1):
        g.cyl((x + s_ * 0.17, yb - 0.17, z0 + 0.25), "z", 0.018, 0.014, E, n=8, style="flat", what="balise")
    g.push((x, yb - 0.02, z0 + 0.5), rx=-0.7)
    n = 28
    vs, fs = [], []
    for i in range(5):
        rr = 0.29 * i / 4
        zz = 0.15 * (rr / 0.29) ** 2
        for j in range(n):
            a = TAU * j / n
            vs.append((rr * math.cos(a), rr * math.sin(a), zz))
    for i in range(4):
        for j in range(n):
            j2 = (j + 1) % n
            fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
    g._add(M["jacket"], "flat", vs, fs, "coupelle")
    vs2 = [(v[0], v[1], v[2] - 0.02) for v in vs]
    g._add(M["steel_dk"], "smooth", vs2, [f[::-1] for f in fs], "coupelle_dos")
    g.torus((0, 0, 0.15), "z", 0.29, 0.016, M["ring"], n=40, m=6, what="levre")
    for k in range(3):
        a = TAU * k / 3
        g.cyl((0.15 * math.cos(a), 0.15 * math.sin(a), 0.2), (-math.cos(a), -math.sin(a), 1.3), 0.008, 0.26,
              M["steel_dk"], n=6, what="hauban")
    g.cyl((0, 0, 0.31), "z", 0.03, 0.05, M["steel_dk"], n=10, what="cornet")
    g.cyl((0, 0, 0.338), "z", 0.02, 0.008, E, n=8, style="flat", what="balise")
    g.pop()


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon-émetteur
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    alimentation, voyants d'état, couverture d'or sur la culasse."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun14(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # couverture d'or froissée sur la culasse, sangles
    zt = zg + hr + 0.012
    g.crumple((x, (y0 + y1) / 2, zt + 0.04), "y", wr * 0.32, (y1 - y0) * 0.7, M["jacket"], n=14, k=3,
              amp=0.012)
    for f in (0.25, 0.75):
        g.box((x, y0 + (y1 - y0) * (0.15 + 0.7 * f), zt + 0.04), (wr * 0.7, 0.035, 0.05), M["ring"], "hard",
              what="sangle")


def _gun14(g, x, y0, z, L, nb, rb, rr):
    """Quatrième passe (règle d'or 1) : l'ÉMETTEUR s'AJOUTE à la rosette de la lignée. Moitié arrière : corps enveloppé
    de FEUILLE D'OR froissée et sanglé (corps.JAQUETTE_MAX), flanqué d'un PANNEAU doré replié (cellules bleu nuit en
    petites bandes) ; sur son dos, une PARABOLE dorée sur rotule et étrier, tournée vers l'avant et le haut (de dessus,
    on voit son intérieur doré). Moitié avant : les 6 tubes séparés de la rosette à COLLIERS ISOLANTS blanc cassé.
    Bouche : FREIN À CAPTEUR ANNULAIRE (grand anneau blanc cassé à capteurs sombres, plus large que le faisceau : pose N
    sans chapeau rond), rosace éclairée au centre, balise rouge."""
    M = g.M
    E, E2 = M["emit"], M["emit2"]
    k = F.k_arme(rb, rr)
    R0 = rr + rb
    pos = corps.rosette(g, x, y0, z, L, nb, rb, rr, colliers=(0.56, 0.65, 0.74, 0.83, 0.92), collier_mat=M["ring"],
                        bouts=False)
    g.cyl((x, y0 + L * 0.99, z), "y", max(rr - rb * 0.55, rr * 0.55), L * 0.04 + 0.03, M["steel_dk"], n=14,
          what="ame_bout")
    rbody = R0 + 0.05 * k
    Lb = min(0.48, corps.JAQUETTE_MAX) * L
    nseg = 4
    for i in range(nseg):
        g.crumple((x, y0 + Lb * (i + 0.5) / nseg, z), "y", rbody, Lb / nseg - 0.015, M["jacket"], n=22, k=3,
                  amp=0.016 * max(0.5, k))
    g.cyl((x, y0 + Lb / 2, z), "y", rbody - 0.02, Lb, M["steel_dk"], n=20, what="ame")
    for i in range(nseg + 1):
        yy = y0 + Lb * i / nseg
        g.tube_shell((x, yy, z), "y", rbody + 0.022, rbody - 0.03, 0.04, M["ring"], n=30, what="sangle")
        if k >= 0.9:
            g.box((x + rbody * 0.5, yy, z + rbody * 0.84), (0.04, 0.055, 0.03), M["steel_hi"], "hard", what="boucle")
    sx = 1.0 if x >= 0 else -1.0
    if k >= 0.9:
        # panneau doré replié côté extérieur, charnières sur le corps
        span = 0.32 * k
        x_in = x + sx * (rbody + 0.01)
        x_out = x_in + sx * span
        ya, yb = y0 + 0.06, y0 + Lb - 0.04
        zz = z + 0.02
        g.box(((x_in + x_out) / 2, (ya + yb) / 2, zz), (span, yb - ya, 0.035), M["ring"], "hard", what="panneau_cadre")
        for j in range(4):
            yy0 = ya + 0.03 + (yb - ya - 0.06) * j / 4
            yy1 = ya + 0.03 + (yb - ya - 0.06) * (j + 1) / 4 - 0.025
            g.box(((x_in + x_out) / 2, (yy0 + yy1) / 2, zz + 0.02), (span * 0.82, yy1 - yy0, 0.006),
                  M["spec"] if j % 2 == 0 else M["jacket"], "flat", what="cellules")
        for f in (0.2, 0.8):
            g.cyl((x_in, ya + (yb - ya) * f, zz), "y", 0.03, 0.08, M["steel_dk"], n=10, what="charniere")
    # parabole dorée sur le dos du corps (rotule, étrier, pointe d'émission)
    rd = 0.3 * k
    dd = 0.1 * k
    yd = y0 + Lb * 0.42
    zd = z + rbody + 0.07 * k
    g.cyl((x, yd, z + rbody + 0.02 * k), "z", 0.06 * k, 0.1 * k, M["steel_dk"], n=12, what="mat")
    # berceau plein sous la parabole (de la rotule au corps) : aucun jour entre la coupelle et le corps
    g.box((x, yd + 0.04 * k, z + rbody + 0.02 * k), (0.09 * k, 0.26 * k, 0.1 * k), M["steel_dk"], "hard",
          what="berceau")
    # coffret de pointage entre le masque et la parabole (ferme le jour au pied de la coupelle)
    g.box((x, (y0 + yd) / 2, z + rbody + 0.08 * k), (0.18 * k, yd - y0 + 0.08, 0.22 * k), M["ring"], "hard",
          what="coffret")
    g.box((x, (y0 + yd) / 2, z + rbody + 0.195 * k), (0.1 * k, (yd - y0) * 0.6, 0.012), M["steel_dk"], "flat",
          what="couvercle")
    g.sphere((x, yd, zd), 0.05 * k, M["steel_dk"], n=14, m=8, what="rotule")
    F.dish(g, (x, yd + 0.02, zd + 0.04 * k), rd, dd, M["jacket"], M["steel_dk"], rx=-0.75, horn=False)
    ax = V((0, 0.68, 0.73))
    g.cyl(V((x, yd + 0.02, zd + 0.04 * k)) + ax * (dd + 0.09 * k), ax, 0.022 * k, 0.18 * k, M["steel_dk"], n=10,
          what="emetteur")
    g.cyl(V((x, yd + 0.02, zd + 0.04 * k)) + ax * (dd + 0.18 * k), ax, 0.035 * k, 0.025, M["ring"], n=12,
          what="emetteur_tete")
    g.cyl(V((x, yd + 0.02, zd + 0.04 * k)) + ax * (dd + 0.195 * k), ax, 0.02 * k, 0.005, E2, n=10, style="flat",
          what="lentille")
    if k >= 0.9:
        for s in (-1, 1):
            g.cyl((x + s * (rbody + 0.02), y0 + Lb * 0.3, z + rbody * 0.3), "z", 0.018, 0.016, E, n=8, style="flat",
                  what="balise")
        # feux de position le long des sangles (espacés : chacun un foyer)
        for f in (0.12, 0.88):
            for s in (-1, 1):
                balise(g, (x + s * rbody * 0.62, y0 + Lb * f, z + rbody * 0.72), r=0.022)
        for f in (0.35, 0.7):
            balise(g, (x, y0 + L * (0.5 + 0.5 * f), z + R0 + 0.02), r=0.02)
    # frein à CAPTEUR ANNULAIRE : grand anneau blanc cassé, 6 capteurs sombres, balise rouge sur le dessus
    yb_ = y0 + L
    lb = 0.16 * k
    Ra = R0 + 0.13 * k
    g.tube_shell((x, yb_ + lb / 2, z), "y", Ra, R0 - 0.005, lb, M["ring"], n=36, what="anneau_capteur")
    g.tube_shell((x, yb_ + lb / 2, z), "y", Ra + 0.012, Ra - 0.02, lb * 0.4, M["steel_dk"], n=36, what="jonc")
    g.cyl((x, yb_ + lb * 0.5, z), "y", max(rr - rb * 0.55, rr * 0.55), lb, M["steel_dk"], n=14, what="ame_bout")
    F.stub_tips(g, x, yb_ - 0.01, yb_ + lb, z, nb, rb, rr)
    for d in F.ring_dirs(6, 0.0, -0.6):
        g.box(V((x, yb_ + lb / 2, z)) + d * (Ra + 0.01), (0.05 * k, lb * 0.7, 0.03 * k), M["steel_dk"], "hard",
              R=F.Rax(d), what="capteur")
    g.cyl((x, yb_ + lb / 2, z + Ra + 0.03), "z", 0.02, 0.04, M["steel_dk"], n=8, what="balise_pied")
    g.cyl((x, yb_ + lb / 2, z + Ra + 0.055), "z", 0.016, 0.014, E, n=8, style="flat", what="balise")
    corps.bouche(g, x, yb_ + lb + 0.002, z, pos, rb, M["ring"], R0 + 0.05 * k, w=0.02 if k >= 0.9 else 0.01)
    if k >= 0.9:
        # oreilles latérales blanc cassé à évents sur le capteur annulaire : en pose N, un « T » plat
        F.ears(g, x, yb_ + lb * 0.5, z, Ra + 0.03, lb * 1.1, 0.14 * k, M["ring"])
    return yb_ + lb


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) blanc cassé et kaki, BRAS ARTICULÉ de chargement à vérin,
    plaque de feuille d'or, goulotte, voyants."""
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
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["ring"], M["olive"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    cw = 0.12 * wr / 0.4 + 0.04
    pa = V((bc, yb0 + bl * 0.55, ztop + 0.02))
    pm = V((bc - sx * 0.04, y0 + bl * 0.45, zg + hr + 0.32))
    pb = V((x + sx * wr * 0.2, y0 + bl * 0.4, zg + hr + 0.06))
    for (p, q) in ((pa, pm), (pm, pb)):
        d = q - p
        g.cyl((p + q) / 2, d, 0.03, d.length, M["ring"], n=12, what="bras")
    for p in (pa, pm, pb):
        g.cyl(p, (1, 0, 0), 0.045, 0.07, M["steel_dk"], n=14, what="articulation")
    PT.piston(g, tuple(pa + V((0, 0.1, 0))), tuple(pm + V((0, 0.06, -0.08))), 0.018)
    g.crumple((bc, yb0 + bl * 0.25, ztop + 0.03), "x", 0.05, bw * 0.8, M["jacket"], n=12, k=3, amp=0.01)
    P2.feed_chute(g, [(bc, yb0 + bl * 0.75, ztop + 0.005), (bc - sx * 0.05, y0 + bl * 0.7, zg + bh * 0.62),
                      (x + sx * wr * 0.3, y0 + bl * 0.62, zg + hr + 0.06)], cw * 0.8, M)
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=3, shapes=("rond", "carre", "fente"))
    return bc


def dome_gun(g, H, nb, L, s=1.0):
    """Canon de coupole sur berceau blindé (lignée _tete15), arme de l'époque."""
    M = g.M
    zr = H["zs"] + H["rz"] * 0.92
    zc = zr + 0.3 * s
    PT.hull(g, -0.38 * s, 0.38 * s, -0.22 * s, 0.66 * s, zr - 0.04, zr + 0.2 * s, ins=(0.04, 0.04, 0.1),
            panel=0.22, mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    PT.receiver(g, 0.0, -0.22 * s, 0.66 * s, zc - 0.18 * s, zc + 0.16 * s, 0.36 * s, mats=[M[k] for k in RECV])
    rb, rr = 0.052 * s, 0.125 * s * (1.0 if nb == 6 else 0.85)
    _gun14(g, 0.0, 0.66 * s, zc, L, nb, rb, rr)
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.26 * s, 0.3 * s, zr + 0.02), (sx * 0.32 * s, 0.6 * s, zr + 0.2 * s), 0.026)
    P2.feed_chute(g, [(0.45 * s, -0.38 * s, zr + 0.05), (0.4 * s, -0.06 * s, zc + 0.12 * s),
                      (0.15 * s, 0.1 * s, zc + 0.17 * s)], 0.12 * s, M)
    return zc


# ------------------------------------------------------------------------------------------------
# Masque et tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=("ochre", "olive"), fentes=((-0.42, 0.34), (0.42, 0.22)), visiere=("steel_hi", 0.13),
                        coax=dict(fut="steel_dk", manchon="ring", manchon_y=0.28, manchon_r=0.045, manchon_L=0.16))


def tete(g, c):
    M = g.M
    E = M["emit"]
    H = c.H
    R = H["R"]
    z0 = c.rt
    F.slits_grouped(g, R, z0 + 0.2, 10, M["emit"])
    F.slits_grouped(g, R, z0 + 0.36, 10, M["emit"], a0=0.3, per=(3, 2))
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
        conduit(g, [(sx * 0.6, -R - 0.3, H["zs"] + 0.2), (sx * R * 0.72, -R * 0.5, H["zs"] + H["rz"] * 0.4),
                    (xe, ye + 0.2, H["zg"] + H["hr"] * 0.55)], 0.04)
    row1 = (0.35, 0.75, 1.15, 1.6, 2.0, 2.4, 2.8, -0.35, -0.75, -2.4, -2.8)
    ph1, w1, h1 = (0.3, 0.32, 0.26)
    for i, th in enumerate(row1):
        mat = M["trim"] if i % 3 == 1 else (M["ochre"] if i % 2 else M["steel_dk"])
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    # 2e et 3e rangées : COUVERTURES THERMIQUES multicouches blanc cassé patiné sur la coupole, sanglées de feuille d'or
    # (12 plaques en quinconce : la coupole olive se voit entre elles, jamais couverte en entier)
    for th, ph in [(t, 0.72) for t in (0.55, 1.2, 1.95, 2.6, -0.6, -2.55)] + \
                  [(t, 0.52) for t in (0.2, 0.9, 1.6, 2.3, 3.0, -1.3)]:
        P2.applique(g, c.Pf, c.Nf, th, ph, 0.42, 0.34, M["ring"], M)
        p = c.Pf(th, ph, 1.0)
        n = c.Nf(th, ph)
        g.push_frame(p + n * 0.066, n, V((-math.sin(th), math.cos(th), 0)))
        g.box((0, 0.0, 0), (0.035, 0.3, 0.012), M["jacket"], "hard", what="sangle")
        g.pop()
    # balises rouges posées entre les couvertures de la coupole
    for th in (0.85, 1.55, 2.25, 2.95, -0.3, -1.0, -1.9, -2.6):
        g.push_frame(c.Pf(th, 0.62, 1.0), c.Nf(th, 0.62))
        balise(g, (0, 0, 0), r=0.024)
        g.pop()
    dome_gun(g, H, 6, 1.7, 1.0)
    # 2 panneaux dorés repliés le long de la nacelle
    bx, yb0, yb1 = c.nac[:3]
    for sx in (-1, 1):
        xx = sx * (bx + 0.03)
        Rr = Matrix.Rotation(sx * 0.25, 3, "Y")
        g.box((xx, (yb0 + yb1) / 2, H["zs"] + 0.05), (0.03, (yb1 - yb0) * 0.9, 0.3), M["ring"], "hard", R=Rr,
              what="panneau_cadre")
        for k in range(3):
            g.box((xx + sx * 0.018, yb0 + (yb1 - yb0) * (0.2 + 0.3 * k), H["zs"] + 0.05),
                  (0.006, (yb1 - yb0) * 0.25, 0.24), M["spec"] if k != 1 else M["jacket"], "flat", R=Rr,
                  what="cellules")
        g.cyl((xx, yb0 + 0.05, H["zs"] + 0.24), "z", 0.016, 0.03, M["emit"], n=8, style="flat", what="balise")
    # sommet de la tête : GRANDE PARABOLE dorée sur mât, au-dessus du tourelleau
    cx, cy, ztop = c.tour
    g.cyl((cx, cy, ztop + 0.16), "z", 0.06, 0.32, M["ring"], n=16, what="mat")
    g.cyl((cx, cy, ztop + 0.03), "z", 0.13, 0.06, M["steel_dk"], n=24, what="pivot")
    F.dish(g, (cx, cy, ztop + 0.36), 0.62, 0.16, M["jacket"], M["ring"], rx=-0.75, horn=False)
    g.push((cx, cy, ztop + 0.36), rx=-0.75)
    # 8 nervures radiales sombres : la grande parabole se lit en PÉTALES de feuille d'or (en pose N, sa face dorée
    # faisait une plage lumineuse de 0,40 t², au-delà du plafond C6 de 0,35)
    for k_ in range(8):
        a = TAU * (k_ + 0.5) / 8
        for i_ in range(6):
            rf = 0.18 + 0.78 * (i_ + 0.5) / 6
            g.box((0.62 * rf * math.cos(a), 0.62 * rf * math.sin(a), 0.16 * rf * rf + 0.008),
                  (0.62 * 0.78 / 6 + 0.004, 0.04, 0.014), M["steel_dk"], "hard",
                  R=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(-math.atan(0.32 * rf), 3, "Y"), what="nervure")
    g.cyl((0, 0, 0.012), "z", 0.62 * 0.22, 0.03, M["steel_dk"], n=20, what="moyeu")
    for rf in (0.5, 0.78):
        g.torus((0, 0, 0.16 * rf * rf + 0.01), "z", 0.62 * rf, 0.022, M["steel_dk"], n=48, m=6, what="raidisseur")
    g.cyl((0, 0, 0.16 + 0.12), "z", 0.04, 0.24, M["steel_dk"], n=12, what="emetteur")
    g.cyl((0, 0, 0.16 + 0.25), "z", 0.06, 0.04, M["ring"], n=14, what="emetteur_tete")
    g.pop()
    g.cyl((cx, cy + 0.02, ztop + 0.36), "z", 0.016, 0.018, E, n=8, style="flat", what="balise")
    PT.capacitors(g, (0.0, -R - 0.14, H["zs"] + H["rz"] * 0.42), 4, 1, 0.1, 0.22, M["emit"])
    PT.sight(g, (-R * 0.64, R * 0.3, H["zs"] + H["rz"] * 0.5), 0.26, 0.26, 0.15, M["emit"], lenses=2)
