"""Époque 15 · Légende (ère V, 6×6, niveaux 29 et 30). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 15) : « couronnes, or blanc, lumière ».
Quatrième passe (23/10), corrections du constructeur de la plage haute sur le portage de la passe 3 (lue « railgun »,
rangée SOUS 13 et 14) :
  - PLUS IMPRESSIONNANTE QUE 14 : canons de flanc plus longs (L 3,1 contre 2,85 à l'époque 14), DEUX canons de
    coupole jumelés et plus longs (2,3 contre 1,7 ; 14 n'en a qu'un), GRANDE COURONNE ROYALE d'or blanc dressée
    au-dessus de la tourelle sur une colonne de nacre cerclée d'or (rayon 0,84 t, 14 fleurons en flèche alternés de
    0,72 et 0,43 t, calotte de velours cloutée d'or, globe et flèche sommitale, pierres, PARTICULES lumineuses sur
    tiges : rien ne flotte) ;
  - ARME (règle d'or 1) : faisceau lourd de la lignée (rosette visible sur la moitié avant), jaquette ciselée sur la
    moitié arrière au plus, frein EN COURONNE dont la face avant porte la ROSACE éclairée (la bague de la passe 3
    masquait les bouches), 5 flèches évasées à pierres et particules ;
  - OR BLANC dominant en accents ; MOITIÉ SUD propre à l'époque : trémie de nacre dans un CADRE D'OR BLANC à 4 grandes
    flèches et arche à fleuron, RELIQUAIRES D'ÉNERGIE à la place des caisses ouvertes, tourelles secondaires de nacre
    COURONNÉES, COLLECTEUR NACRÉ à pierres et particules au sud-est (à la place des volants).
Inchangés de la passe 3 : grands volumes du socle (groupe électrogène ciselé, réservoirs ciselés à flèches,
radiateur à 3 ventilateurs), liaisons (conduits nacrés à bagues d'or blanc), particules sur la couronne
d'orientation, foyers blanc doré, pièce paire (2 cellules d'énergie couronnées).
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

EPOQUE = 15
NOM = "Légende"
FOYER = dict(rgb=(1.0, 0.949, 0.753), rgb2=(1.0, 0.949, 0.753))
CANON = dict(L=3.1, nb=6, rb=0.072, rr=0.175)
PLATEFORME = dict(chanfrein=0.32)
HABILLAGE = dict(jupe_cerclage="ring", chapeau="ring", tremie="armor2", munitions=("jacket", "trim"))
RECV = ("ochre", "olive")


def matieres(metal, M):
    """Légende : or blanc patiné, nacre."""
    metal("jacket", (0.6, 0.52, 0.32), rough=0.26, met=0.95, grain=0.14, gscale=40.0, rust=(0.25, 0.12, 0.05),
          ra=0.1, dirt=0.85, stain=0.35, sscale=6.0, wear=0.5)
    # bagues, flèches de couronne : or blanc PATINÉ, plus rugueux (aucun éclat blanc franc : « pas de bague blanche »)
    metal("ring", (0.46, 0.39, 0.22), rough=0.42, met=0.9, grain=0.18, gscale=36.0, rust=(0.25, 0.12, 0.05),
          ra=0.14, dirt=0.9, stain=0.5, sscale=6.0, wear=0.6)
    metal("trim", (0.5, 0.47, 0.42), rough=0.3, met=0.15, grain=0.12, gscale=30.0, dirt=0.9, stain=0.5,
          sscale=5.0, wear=0.6, streak=0.4)                                                        # nacre
    M["pipe"] = M["trim"]
    M["pipe2"] = M["jacket"]
    M["cable_a"], M["cable_b"] = M["rubber"], M["redcable"]
    M["spec"] = M["trim"]
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 29 de l'industriel, témoin ; 15 : réservoirs plus hauts)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    ring_lights(g, B["R"] - 0.08, B["h"] + B["rh"] + 0.02)
    ng = 11
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    P2.grating(g, 1.65, 1.95, Y(-1.3), Y(1.45), 0.07, M)
    P2.grating(g, -1.95, -1.65, Y(-1.1), Y(1.1), 0.07, M)
    with at(g, -1.45, -1.95, 0.45):
        reliquary(g, 0.84, 0.7, 0.3)
    with at(g, 1.45, -1.95, -0.45):
        reliquary(g, 0.84, 0.7, 0.3)
    for (x, yn, rz) in [(-2.4, -2.5, -0.3), (2.4, -2.5, 0.3), (2.4, 2.45, -0.4)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.46, 0.0, 0.32, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            mini_turret(g, (0, 0, 0.32), 1.02, rz)
    tremie_crown(g, c)
    # ouest : groupe électrogène à 6 cylindres ; liaisons
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
    # sud-est : collecteur nacré à pierres et particules (à la place de la vanne à volants)
    nacre_manifold(g, 1.98, 2.85, Y(-1.55), Y(-1.18), 0.3)
    hose(g, [(1.98, Y(-1.35), 0.34), (1.75, Y(-1.4), 0.4), (1.55, Y(-1.15), 0.56)], 0.055)
    hose(g, [(2.0, Y(1.1), 0.7), (1.72, Y(1.0), 1.12), (1.4, Y(0.8), 0.95)], 0.065)
    hose(g, [(2.0, Y(-0.45), 0.7), (1.72, Y(-0.5), 1.1), (1.42, Y(-0.4), 0.95)], 0.065)
    # nord : radiateur à trois ventilateurs ; armoires de commande
    P2.fan_radiator(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.0, 0.42, 3, M, emat=E)
    P3.cabinet(g, -1.15, -0.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    P3.cabinet(g, 0.35, 1.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    for x in (-2.75, -2.35, 2.05, 2.55):
        g.sphere((x, Y(-2.97) + 0.12, 0.09), 0.022, E, n=10, m=6, what="pierre")
        g.cyl((x, Y(-2.97) + 0.12, 0.04), "z", 0.035, 0.07, M["ring"], n=10, what="pierre_pied")
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
    """Feux de couronne (face sud de la couronne d'orientation) : « particules » or blanc sur poteaux de nacre, chaque
    feu un foyer séparé."""
    n = 22
    M = g.M
    for k in range(n):
        a = math.pi + math.pi * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0))
        p = V((0, 0, z)) + d * R
        g.cyl(p + V((0, 0, 0.035)), "z", 0.016, 0.07, M["trim"], n=8, what="poteau")
        g.sphere(p + V((0, 0, 0.085)), 0.02, M["emit"], n=10, m=6, what="particule")


def west(g):
    """Groupe de l'ouest : groupe électrogène à 6 cylindres du témoin n29, trappes de nacre cerclées d'or blanc,
    pierres lumineuses."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = -2.88, -1.98, Y(-1.35), Y(1.35), 0.6
    P2.engine(g, x0, x1, y0, y1, 0.0, h, 6, M, emat=E)
    F.hatches(g, (x0 - 0.005, y0 + 0.2, h * 0.25), (x0 - 0.005, y1 - 0.2, h * 0.25), 10, (-1, 0, 0), M["trim"],
              size=(0.07, 0.05), frame=M["ring"])
    F.hatches(g, (x1 + 0.005, y0 + 0.2, h * 0.3), (x1 + 0.005, y1 - 0.2, h * 0.3), 10, (1, 0, 0), M["trim"],
              size=(0.07, 0.05), frame=M["ring"])
    for yy in (y0 + 0.3, y1 - 0.3):
        g.sphere((x0 + 0.08, yy, h + 0.03), 0.022, E, n=10, m=6, what="pierre")


def east(g):
    """Est : deux réservoirs debout ciselés (habillés par l'époque), trappes de nacre et d'or blanc, pierres."""
    M = g.M
    tank(g, 2.4, Y(1.0), 0.44, 1.1, (1, 0.2), (-1, 0), gauges=3)
    tank(g, 2.4, Y(-0.55), 0.44, 1.1, (1, -0.2), (-1, 0), gauges=3)
    for (cx_, cy_) in ((2.4, Y(1.0)), (2.4, Y(-0.55))):
        for kk in range(9):
            a = math.pi + math.pi * (kk + 0.5) / 9
            d = V((math.cos(a), math.sin(a), 0))
            F.hatches(g, V((cx_, cy_, 0.25)) + d * 0.43, V((cx_, cy_, 0.29)) + d * 0.43, 1, d, M["trim"],
                      size=(0.07, 0.05))
            F.hatches(g, V((cx_, cy_, 0.86)) + d * 0.43, V((cx_, cy_, 0.9)) + d * 0.43, 1, d, M["ring"],
                      size=(0.06, 0.05))
        for (bx_, by_) in ((cx_ - 0.6, cy_ - 0.2), (cx_ + 0.3, cy_ - 0.5)):
            g.sphere((bx_, by_, 0.1), 0.02, M["emit"], n=10, m=6, what="pierre")
            g.cyl((bx_, by_, 0.05), "z", 0.035, 0.07, M["ring"], n=10, what="pierre_pied")


def tank(g, x, y, r, h, ladder_dir, stub_dir, gauges=2, rings=1):
    """Réservoir debout de la lignée (P3.vtank) crème cerclé d'or blanc, hublots ; bande ciselée de losanges d'or
    blanc sertis de nacre, 5 flèches sur le fond bombé."""
    M = g.M
    E = M["emit"]
    P3.vtank(g, x, y, r, h, M, paint=M["cream"], emat=E, ladder_dir=ladder_dir, stub_dir=stub_dir, gauges=gauges,
             glow_gauges=True, glow_rings=0, band=M["jacket"])
    F.tank_lights(g, x, y, r, h, EPOQUE)
    # trappes de nacre cerclées d'or blanc sur la virole crème (pièces isolées)
    for k in range(6):
        a = -math.pi * 0.1 - math.pi * 0.8 * k / 5
        d = V((math.cos(a), math.sin(a), 0))
        for zf in (0.2, 0.44, 0.86):
            F.hatches(g, V((x, y, h * zf)) + d * (r + 0.005), V((x, y, h * (zf + 0.06))) + d * (r + 0.005), 1, d,
                      M["trim"] if zf != 0.44 else M["steel_dk"], size=(0.06, 0.05), frame=M["jacket"])
    # bande ciselée : losanges d'or blanc sertis de nacre sur la virole (face visible)
    for k in range(14):
        a = -math.pi * 0.05 - math.pi * 0.9 * k / 13
        d = V((math.cos(a), math.sin(a), 0))
        Rr = Matrix((V((-d.y, d.x, 0)), V((0, 0, 1)), d)).transposed() @ Matrix.Rotation(math.pi / 4, 3, "Z")
        for zz in (h * 0.56, h * 0.7):
            g.box(V((x, y, zz)) + d * (r + 0.012), (0.045, 0.045, 0.014), M["jacket"], "hard", R=Rr,
                  what="ciselure")
            g.box(V((x, y, zz)) + d * (r + 0.02), (0.02, 0.02, 0.008), M["trim"], "hard", R=Rr,
                  what="ciselure")
    for k in range(5):
        a = TAU * k / 5 + 0.3
        d = V((math.cos(a), math.sin(a), 0))
        c = V((x, y, h + r * 0.2)) + d * r * 0.55
        P2.wedge(g, c, c + d * 0.05, c + d * 0.02 + V((0, 0, 0.13)), V((-d.y, d.x, 0)) * 0.02, M["jacket"],
                 what="fleche")


def crown(g, c, R, n=10, h=0.26, gems_all=False, skip=None):
    """GRANDE couronne d'or blanc au-dessus de la tête : bandeau à deux joncs, fleurons en flèche (alternés grands et
    petits), pierres lumineuses, PARTICULES (petites sphères lumineuses sur tiges d'or blanc au-dessus des grands
    fleurons : rien ne flotte), nacre et sertissures. skip = (angle, demi-largeur) : secteur sans fleuron."""
    M = g.M
    E = M["emit"]
    c = V(c)
    g.tube_shell(c, "z", R + 0.06, R - 0.04, 0.14, M["ring"], n=72, what="bandeau")
    for k in range(2 * n):   # boulons sombres du bandeau (pièces isolées sur l'or)
        a = TAU * (k + 0.25) / (2 * n)
        d = V((math.cos(a), math.sin(a), 0))
        g.bolt(c + d * (R + 0.062), d, 0.018, M["steel_dk"], what="boulon")
    g.torus(c + V((0, 0, 0.06)), "z", R + 0.04, 0.016, M["jacket"], n=72, m=6, what="jonc")
    g.torus(c - V((0, 0, 0.06)), "z", R + 0.04, 0.016, M["jacket"], n=72, m=6, what="jonc")
    for k in range(n):
        a = TAU * k / n
        d = V((math.cos(a), math.sin(a), 0))
        t = V((-d.y, d.x, 0))
        a3 = a + TAU / n * 0.5
        d3 = V((math.cos(a3), math.sin(a3), 0))
        g.box(c + d3 * (R + 0.038), (0.08, 0.016, 0.06), M["trim"], "hard", R=Matrix.Rotation(a3 + math.pi / 2, 3, "Z"),
              what="nacre")
        for j in range(3):
            a2 = a + TAU / n * (j + 0.5) / 3
            d2 = V((math.cos(a2), math.sin(a2), 0))
            g.dome(c + d2 * (R + 0.042), d2, 0.012, M["rivet"])
        if skip is not None:
            da = (a - skip[0] + math.pi) % TAU - math.pi
            if abs(da) < skip[1]:
                continue
        p = c + d * (R + 0.01) + V((0, 0, 0.06))
        big = k % 2 == 0
        hk = h * (1.0 if big else 0.6)
        wk = 0.1 if big else 0.07
        P2.wedge(g, p - t * wk, p + t * wk, p + V((0, 0, hk)), d * 0.035, M["jacket"], what="fleuron")
        P2.wedge(g, p - t * wk * 0.5 + V((0, 0, 0.01)), p + t * wk * 0.5 + V((0, 0, 0.01)), p + V((0, 0, hk * 0.62)),
                 d * 0.045, M["trim"], what="fleuron")
        if big or gems_all:
            g.sphere(p + V((0, 0, hk + 0.024)) + d * 0.004, 0.026 if big else 0.02, E, n=10, m=6, what="pierre")
        if big:
            g.cyl(p + V((0, 0, hk + 0.1)), "z", 0.005, 0.12, M["jacket"], n=6, what="tige")
            g.sphere(p + V((0, 0, hk + 0.17)), 0.014, E, n=8, m=5, what="particule")
            g.sphere(p + V((0, 0, hk + 0.11)) + t * 0.01, 0.01, E, n=8, m=5, what="particule")
        g.box(c + d * (R + 0.036), (0.024, 0.024, 0.024), M["trim"], "hard", R=Matrix.Rotation(a, 3, "Z"),
              what="sertissure")


def signature(g, p, kind=0):
    """Petite pièce de signature : petite couronne de flèches d'or blanc sur socle de nacre."""
    M = g.M
    p = V(p)
    g.cyl(p + V((0, 0, 0.02)), "z", 0.07, 0.04, M["trim"], n=16, what="socle_couronne")
    for k in range(5):
        a = TAU * k / 5
        d = V((math.cos(a), math.sin(a), 0))
        c = p + d * 0.055 + V((0, 0, 0.04))
        P2.wedge(g, c - V((-d.y, d.x, 0)) * 0.02, c + V((-d.y, d.x, 0)) * 0.02, c + d * 0.01 + V((0, 0, 0.1)),
                 d * 0.016, M["jacket"], what="fleche")


def mini_turret(g, c, s, rz):
    """Tourelle secondaire LÉGENDE : couronne rivetée de la lignée, caisson de nacre à bandes d'or blanc ciselées,
    PETITE COURONNE de 6 flèches d'or blanc à pierres sur le dos ; les DEUX ARMES sont celles de l'époque (petits
    faisceaux lourds à frein en couronne)."""
    M = g.M
    E = M["emit"]
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["armor2"], n=32, style="soft", what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    PT.hull(g, -0.24 * s, 0.24 * s, -0.3 * s, 0.24 * s, 0.1 * s, 0.38 * s, ins=(0.04 * s, 0.03 * s, 0.08 * s),
            panel=0.22, mats=[M["trim"], M["steel_dk"]])
    for yy in (-0.2 * s, 0.08 * s):
        g.box((0, yy, 0.385 * s), (0.36 * s, 0.04, 0.02), M["jacket"], "hard", what="bande")
        for k in range(5):
            g.dome(((k - 2) * 0.075 * s, yy, 0.385 * s + 0.01), (0, 0, 1), 0.012, M["rivet"])
    for sxx, syy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        g.bolt((sxx * 0.17 * s, -0.04 * s + syy * 0.2 * s, 0.38 * s), (0, 0, 1), 0.02, M["steel_dk"], what="boulon")
    cc = V((0.0, -0.06 * s, 0.39 * s))
    g.cyl(cc + V((0, 0, 0.015)), "z", 0.12 * s, 0.03, M["jacket"], n=24, what="socle_couronne")
    for k in range(6):
        a = TAU * k / 6
        d = V((math.cos(a), math.sin(a), 0))
        t = V((-d.y, d.x, 0))
        q = cc + d * 0.11 * s + V((0, 0, 0.03))
        P2.wedge(g, q - t * 0.03, q + t * 0.03, q + d * 0.012 + V((0, 0, 0.16 * s)), d * 0.02, M["jacket"],
                 what="fleche")
        g.sphere(q + V((0, 0, 0.17 * s)), 0.016, E, n=8, m=5, what="pierre")
    for sx in (-1, 1):
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=[M[k] for k in RECV])
        _gun15(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    g.pop()


def reliquary(g, w, d, h):
    """RELIQUAIRE D'ÉNERGIE (à la place de la caisse ouverte) : coffre de nacre cerclé d'or blanc ciselé, couvercle
    bombé, 4 flèches d'or blanc aux angles, hublots blanc doré, pierres."""
    M = g.M
    E = M["emit"]
    PT.hull(g, -w / 2, w / 2, -d / 2, d / 2, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.26, mats=[M["trim"], M["olive"]],
            rivet_step=0.12)
    g.cyl((0, 0, h), "x", d * 0.42, w * 0.9, M["trim"], n=20, what="couvercle")
    for f in (-0.36, 0.0, 0.36):
        g.tube_shell((f * w, 0, h), "x", d * 0.44, d * 0.36, 0.04, M["jacket"], n=20, what="cerclage")
        F.bolts_ring(g, (f * w + 0.021, 0, h), (1, 0, 0), d * 0.4, 9, M["rivet"], r=0.012, skip_down=0.05)
    # ciselure : losanges d'or blanc sertis de nacre sur la face sud
    for i in range(5):
        x = -w * 0.4 + w * 0.2 * i
        Rr = Matrix.Rotation(math.pi / 4, 3, "Y")
        g.box((x, -d / 2 - 0.006, h * 0.82), (0.04, 0.012, 0.04), M["jacket"], "hard", R=Rr, what="ciselure")
        g.box((x, -d / 2 - 0.012, h * 0.82), (0.018, 0.008, 0.018), M["trim"], "hard", R=Rr, what="ciselure")
    for sxx in (-1, 1):
        for syy in (-1, 1):
            q = V((sxx * (w / 2 - 0.04), syy * (d / 2 - 0.04), h))
            P2.wedge(g, q - V((0.03, 0, 0)), q + V((0.03, 0, 0)), q + V((0, 0, 0.18)), V((0, 0.03, 0)), M["jacket"],
                     what="fleche")
            g.sphere(q + V((0, 0, 0.19)), 0.014, E, n=8, m=5, what="pierre")
    for sxx in (-1, 1):
        F.hatches(g, (sxx * (w / 2 + 0.005), -d / 2 + 0.08, h * 0.45), (sxx * (w / 2 + 0.005), d / 2 - 0.08, h * 0.45),
                  4, (sxx, 0, 0), M["jacket"], size=(0.06, 0.06), frame=M["trim"])
    for i in range(3):
        x = -w * 0.3 + w * 0.3 * i
        g.cyl((x, -d / 2 - 0.01, h * 0.5), "y", 0.04, 0.02, M["jacket"], n=14, what="hublot")
        g.cyl((x, -d / 2 - 0.022, h * 0.5), "y", 0.026, 0.005, E, n=12, style="flat", what="hublot_lum")


def tremie_crown(g, c):
    """Trémie de l'époque (peinte d'acier sombre, HABILLAGE) : CADRE D'OR BLANC ciselé à 4 grandes FLÈCHES aux angles,
    pierres et particules à leur pointe, arche d'or blanc à fleurons en travers de l'arrière, conduits nacrés à bagues
    d'or blanc vers la colonne."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = c.tremie_box
    zl = h - 0.35 * (y1 - y0) * 0.4
    for (xx, yy, zz) in ((x0 - 0.05, y0 + 0.05, zl), (x1 + 0.05, y0 + 0.05, zl), (x0 - 0.05, y1 - 0.05, h),
                         (x1 + 0.05, y1 - 0.05, h)):
        g.box((xx, yy, zz * 0.5), (0.1, 0.1, zz), M["jacket"], "hard", what="montant")
        q = V((xx, yy, zz))
        P2.wedge(g, q - V((0.05, 0, 0)), q + V((0.05, 0, 0)), q + V((0, 0, 0.32)), V((0, 0.05, 0)), M["jacket"],
                 what="fleche")
        P2.wedge(g, q - V((0, 0.05, 0)), q + V((0, 0.05, 0)), q + V((0, 0, 0.26)), V((0.05, 0, 0)), M["trim"],
                 what="fleche")
        g.sphere(q + V((0, 0, 0.34)), 0.022, E, n=10, m=6, what="pierre")
        g.cyl(q + V((0, 0, 0.42)), "z", 0.005, 0.12, M["jacket"], n=6, what="tige")
        g.sphere(q + V((0, 0, 0.49)), 0.012, E, n=8, m=5, what="particule")
    for xx in (x0 - 0.05, x1 + 0.05):
        g.box((xx, (y0 + y1) / 2, (zl + h) / 2 + 0.02), (0.06, y1 - y0, 0.05), M["jacket"], "hard", what="lisse")
        for k in range(7):
            f = (k + 0.5) / 7
            g.dome((xx, y0 + (y1 - y0) * f, zl + (h - zl) * f + 0.047), (0, 0, 1), 0.013, M["rivet"])
            if k % 2 == 0:
                g.box((xx, y0 + (y1 - y0) * f, (zl + (h - zl) * f) * 0.5), (0.11, 0.03, 0.03), M["trim"], "hard",
                      what="ciselure")
    # arche d'or blanc à fleurons en travers de l'arrière de la trémie
    ya = y1 - 0.3
    n = 8
    Ra = (x1 - x0) / 2 + 0.05
    for i in range(n):
        a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
        p0 = V((Ra * math.cos(a0), ya, h + Ra * 0.5 * math.sin(a0)))
        p1 = V((Ra * math.cos(a1), ya, h + Ra * 0.5 * math.sin(a1)))
        dd = p1 - p0
        Rm = Matrix((dd.normalized(), V((0, 1, 0)), dd.normalized().cross(V((0, 1, 0))))).transposed()
        g.box((p0 + p1) / 2, (dd.length + 0.01, 0.08, 0.07), M["jacket"], "hard", R=Rm, what="arche")
    for xx in (-Ra, Ra):
        g.box((xx, ya, h * 0.5), (0.07, 0.08, h), M["jacket"], "hard", what="pied")
    q = V((0, ya, h + Ra * 0.5 + 0.03))
    P2.wedge(g, q - V((0.06, 0, 0)), q + V((0.06, 0, 0)), q + V((0, 0, 0.26)), V((0, 0.04, 0)), M["jacket"],
             what="fleuron")
    g.sphere(q + V((0, 0, 0.28)), 0.024, E, n=10, m=6, what="pierre")
    for s in (-1, 1):
        hose(g, [(s * (Ra + 0.04), ya + 0.05, h * 0.6), (s * (Ra + 0.12), y1 + 0.25, h + 0.2),
                 (s * 0.4, y1 + 0.5, c.rt + 0.04)], 0.05)
    # clous d'or blanc sur les flancs d'acier sombre de la trémie (pièces isolées)
    for xx, nx in ((x0 - 0.03, -1), (x1 + 0.03, 1)):
        for i in range(5):
            for j in range(2):
                yy = y0 + 0.15 + (y1 - y0 - 0.3) * i / 4
                g.bolt((xx, yy, 0.1 + 0.16 * j), (nx, 0, 0), 0.02, M["jacket"], what="clou")


def nacre_manifold(g, x0, x1, y0, y1, h):
    """Collecteur nacré (sud-est) : caisson de nacre à liseré d'or blanc, 3 conduits nacrés debout à bagues d'or
    blanc coiffés de pierres et de particules."""
    M = g.M
    E = M["emit"]
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.22, mats=[M["trim"], M["steel_dk"]],
            rivet_step=0.12)
    w = x1 - x0
    yc = (y0 + y1) / 2
    g.box(((x0 + x1) / 2, y0 - 0.006, h * 0.85), (w * 0.9, 0.012, 0.025), M["jacket"], "hard", what="lisere")
    F.hatches(g, (x0 + 0.08, y0 - 0.005, h * 0.4), (x1 - 0.08, y0 - 0.005, h * 0.4), 5, (0, -1, 0), M["jacket"],
              size=(0.07, 0.06), frame=M["trim"])
    for i in range(3):
        x = x0 + w * (0.2 + 0.3 * i)
        hh = 0.22 + 0.06 * (i % 2)
        g.cyl((x, yc, h + hh / 2), "z", 0.045, hh, M["trim"], n=14, what="conduit_nacre")
        for zz in (h + 0.04, h + hh * 0.6):
            g.tube_shell((x, yc, zz), "z", 0.06, 0.035, 0.03, M["jacket"], n=14, what="bague_or")
        g.sphere((x, yc, h + hh + 0.02), 0.024, E, n=10, m=6, what="pierre")
        g.cyl((x, yc, h + hh + 0.09), "z", 0.005, 0.1, M["jacket"], n=6, what="tige")
        g.sphere((x, yc, h + hh + 0.15), 0.012, E, n=8, m=5, what="particule")


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduits nacrés à bagues d'or blanc, conduits lumineux
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    """Conduit nacré à bagues d'or blanc rapprochées et gorges sombres (le reflet du conduit se lit en tronçons)."""
    M = g.M
    P, T = g.tube(g.spline(ctrl, 10), r, M["trim"], n=12, what="conduit_nacre")
    for i in range(1, len(P) - 1, 3):
        g.tube_shell(P[i], T[i], r + 0.016, r - 0.01, 0.035, M["jacket"], n=14, what="bague_or")
        if i + 1 < len(P) - 1:
            g.tube_shell(P[i + 1], T[i + 1], r + 0.004, r - 0.01, 0.012, M["steel_dk"], n=14, what="gorge")


def cables(g, ctrl, n=3):
    M = g.M
    PT.cable_run(g, ctrl, n, 0.02, 0.045, [M["rubber"], M["redcable"], M["rubber"]])


def conduit(g, ctrl, r):
    """Conduit d'énergie : bagues lumineuses PAR GROUPES (chenillard), colliers d'or blanc."""
    M = g.M
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["steel_dk"], n=10, what="conduit")
    R = g.resample(P, 0.075)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 4 in (1, 2):
            g.tube_shell(R[i], T2[i], r + 0.008, r * 0.5, 0.03, M["emit"], n=12, what="bague_lum")
        elif i % 4 == 3:
            g.tube_shell(R[i], T2[i], r + 0.016, r * 0.5, 0.03, M["pipe2"], n=12, what="collier")


def pipe(g, ctrl, r, valve_at=None):
    M = g.M
    g.pipe(ctrl, r, M["trim"], fl_mat=M["pipe2"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 30 : 2 cellules d'énergie couronnées (témoin n30, agrandies)
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.22, Y(-2.97), sx)
    # halo DEVANT la cellule d'énergie (rayon 0,27 t) : placé en Y(-3,1), il tombait dans la cellule, la lumière était
    # masquée et la couche « lumière » de la pièce sortait vide (production du 23/10)
    _halo(g, [(-1.22, Y(-3.3), 0.3), (1.22, Y(-3.3), 0.3)], 18.0)


def even_piece(g, x, yb, sx):
    """CELLULE D'ÉNERGIE COURONNÉE (niveau 30 témoin, agrandie à 0,10 t²) et couronne de flèches, sur la plinthe
    commune (caisson blindé bas à bande de danger)."""
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
    P2.power_cell(g, (x, yb, z0), 0.27, 0.66, E, M)
    c = V((x, yb, z0 + 0.66 + 0.12))
    for k in range(5):
        a = TAU * k / 5 + 0.3
        d_ = V((math.cos(a), math.sin(a), 0))
        q = c + d_ * 0.18
        P2.wedge(g, q - V((-d_.y, d_.x, 0)) * 0.035, q + V((-d_.y, d_.x, 0)) * 0.035, q + d_ * 0.02 + V((0, 0, 0.17)),
                 d_ * 0.025, M["jacket"], what="fleche")
    g.torus(c, "z", 0.2, 0.025, M["jacket"], n=36, m=8, what="couronne")


# ------------------------------------------------------------------------------------------------
# Arme (E1) : faisceau lourd ciselé, frein en couronne
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    alimentation, voyants d'état, chapeau de nacre et petite couronne sur la culasse."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun15(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # chapeau de nacre, liseré d'or blanc et petite couronne de 5 flèches sur la culasse
    zt = zg + hr + 0.012
    g.box((x, (y0 + y1) / 2, zt + 0.018), (wr * 0.7, (y1 - y0) * 0.5, 0.025), M["trim"], "hard", what="nacre")
    g.box((x, (y0 + y1) / 2, zt + 0.034), (wr * 0.74, 0.02, 0.012), M["jacket"], "hard", what="liseré")
    cc = V((x, (y0 + y1) / 2 + 0.12, zt + 0.03))
    for kk in range(5):
        a = TAU * kk / 5
        d = V((math.cos(a), math.sin(a), 0))
        P2.wedge(g, cc + d * 0.07, cc + d * 0.08 + V((-d.y, d.x, 0)) * 0.03, cc + d * 0.075 + V((0, 0, 0.11)),
                 V((-d.y, d.x, 0)) * 0.02, M["jacket"], what="fleche")
    g.cyl(cc + V((0, 0, 0.01)), "z", 0.07, 0.02, M["jacket"], n=20, what="socle_couronne")


def _gun15(g, x, y0, z, L, nb, rb, rr):
    """Quatrième passe : faisceau LOURD de la lignée (rosette de 6 gros tubes, visible sur toute la moitié avant),
    JAQUETTE CISELÉE d'or blanc patiné et de nacre sur la moitié arrière au plus (corps.JAQUETTE_MAX), colliers d'or
    blanc ; frein EN COURONNE : bague d'or blanc dont la face avant porte la ROSACE éclairée, 5 grandes flèches évasées
    vers l'avant et vers l'extérieur (pose N : une couronne de pointes plus large que le faisceau, jamais un chapeau
    rond), pierres lumineuses et PARTICULES à la pointe des flèches."""
    M = g.M
    E = M["emit"]
    k = F.k_arme(rb, rr)
    rb2, rr2 = rb * 1.12, rr * 1.04
    R0 = rr2 + rb2
    pos = corps.rosette(g, x, y0, z, L, nb, rb2, rr2, colliers=(0.57, 0.67, 0.77, 0.87, 0.95), collier_mat=M["ring"],
                        bouts=False)
    rs = R0 + 0.028
    Ls = min(0.47, corps.JAQUETTE_MAX) * L
    # jaquette en 7 VIROLES ciselées séparées par des joncs de nacre en retrait : le reflet
    # de l'or blanc se lit en tronçons, comme une jaquette d'orfèvre, et non en une seule barre
    g.cyl((x, y0 + Ls / 2, z), "y", rs - 0.006, Ls, M["trim"], n=32, what="ame_jaquette")
    nv = 7
    for i in range(nv):
        ya_, yb_ = y0 + Ls * i / nv + 0.014, y0 + Ls * (i + 1) / nv - 0.014
        g.cyl((x, (ya_ + yb_) / 2, z), "y", rs, yb_ - ya_, M["jacket"], n=32, style="smooth", what="virole")
    for f in (0.03, 0.97):
        g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.028, rs - 0.01, 0.065, M["ring"], n=32, what="bague")
    if k >= 0.9:
        for f in (0.32, 0.66):
            g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.03, rs - 0.01, 0.1, M["trim"], n=32, what="bande_nacre")
            for d in F.ring_dirs(10, 0.0, -0.5):
                R = F.Rax(d) @ Matrix.Rotation(math.pi / 4, 3, "Z")
                for dy in (-0.035, 0.035):
                    g.box(V((x, y0 + f * Ls + dy, z)) + d * (rs + 0.03), (0.04, 0.036, 0.012), M["jacket"], "hard",
                          R=R, what="ciselure")
        for i in range(3):
            yy = y0 + Ls * (0.15 + 0.34 * i) + 0.02
            for d in F.ring_dirs(9, 0.35 * (i % 2), -0.45):
                R = F.Rax(d) @ Matrix.Rotation(math.pi / 4, 3, "Z")
                g.box(V((x, yy, z)) + d * (rs + 0.004), (0.05, 0.05, 0.014), M["trim"], "hard", R=R, what="ciselure")
                g.box(V((x, yy, z)) + d * (rs + 0.012), (0.024, 0.024, 0.008), M["jacket"], "hard", R=R,
                      what="ciselure")
    # frein EN COURONNE : bague pleine d'or blanc dont la face avant porte la rosace, 5 grandes flèches évasées
    yb = y0 + L
    lc = 0.13 * k
    g.cyl((x, yb + lc / 2, z), "y", rs + 0.05, lc, M["ring"], n=36, what="couronne")
    F.stub_tips(g, x, yb - 0.01, yb + lc, z, nb, rb2, rr2)
    g.tube_shell((x, yb + lc * 0.5, z), "y", rs + 0.062, rs + 0.03, lc * 0.4, E, n=36, what="lisere_lum")
    for d in F.ring_dirs(5, math.pi / 2 + math.pi / 5, -0.95):
        R = F.Rax(d)
        t = R.col[0] * 0.034 * k
        c_ = V((x, 0, z))
        pa = c_ + d * (rs - 0.01) + V((0, yb - 0.06, 0))
        pb = c_ + d * (rs + 0.13 * k) + V((0, yb + 0.02, 0))
        pt = c_ + d * (rs + 0.3 * k) + V((0, yb + 0.34 * k, 0))
        pi_ = c_ + d * (rs + 0.04) + V((0, yb + 0.16 * k, 0))
        P2.wedge(g, pa, pb, pt, t * 2.2, M["ring"], what="fleche")
        P2.wedge(g, pa, pt, pi_, t * 2.2, M["ring"], what="fleche")
        P2.wedge(g, c_ + d * (rs - 0.02) + V((0, yb, 0)), c_ + d * (rs + 0.05 * k) + V((0, yb, 0)),
                 c_ + d * (rs + 0.07 * k) + V((0, yb + 0.22 * k, 0)), t * 1.3, M["trim"], what="fleche")
        g.sphere(c_ + d * (rs + 0.3 * k) + V((0, yb + 0.36 * k, 0)), 0.02 * k, E, n=10, m=6, what="pierre")
        if k >= 0.9:
            g.sphere(c_ + d * (rs + 0.36 * k) + V((0, yb + 0.44 * k, 0)), 0.012, E, n=8, m=5, what="particule")
            g.cyl(c_ + d * (rs + 0.33 * k) + V((0, yb + 0.4 * k, 0)), d * 0.6 + V((0, 0.8, 0)), 0.005, 0.07,
                  M["jacket"], n=6, what="tige")
            g.dome(c_ + d * (rs + 0.1 * k) + V((0, yb + 0.05, 0)) + t * 0.6, R.col[0], 0.013, M["rivet"])
    corps.bouche(g, x, yb + lc + 0.002, z, pos, rb2, M["jacket"], rs + 0.02, w=0.022 if k >= 0.9 else 0.012)
    return yb + 0.34 * k


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) kaki et ocre, CELLULE D'ÉNERGIE à couronne lumineuse,
    goulotte, voyants."""
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
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["olive"], M["ochre"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    cw = 0.12 * wr / 0.4 + 0.04
    c = V((bc, yb0 + bl * 0.3, ztop))
    g.cyl(c + V((0, 0, 0.08)), "z", 0.07, 0.16, M["steel_dk"], n=20, what="cellule")
    for zz in (0.03, 0.13):
        g.tube_shell(c + V((0, 0, zz)), "z", 0.078, 0.06, 0.02, M["jacket"], n=20, what="cerclage")
    g.tube_shell(c + V((0, 0, 0.165)), "z", 0.055, 0.042, 0.016, E, n=20, what="couronne_lum")
    for k in range(5):
        a = TAU * k / 5
        d = V((math.cos(a), math.sin(a), 0))
        P2.wedge(g, c + d * 0.06 + V((0, 0, 0.16)), c + d * 0.07 + V((0, 0, 0.16)),
                 c + d * 0.065 + V((0, 0, 0.23)), V((-d.y, d.x, 0)) * 0.018, M["jacket"], what="fleche")
    P2.feed_chute(g, [(bc, yb0 + bl * 0.7, ztop + 0.005), (bc - sx * 0.05, y0 + bl * 0.65, zg + bh * 0.62),
                      (x + sx * wr * 0.25, y0 + bl * 0.55, zg + hr + 0.06)], cw, M)
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=3, shapes=("rond", "carre", "fente"))
    return bc


def dome_gun(g, H, nb, L, s=1.0):
    """Canon de coupole sur berceau blindé (lignée _tete15), arme de l'époque, petite couronne de flèches."""
    M = g.M
    zr = H["zs"] + H["rz"] * 0.92
    zc = zr + 0.3 * s
    PT.hull(g, -0.38 * s, 0.38 * s, -0.22 * s, 0.66 * s, zr - 0.04, zr + 0.2 * s, ins=(0.04, 0.04, 0.1),
            panel=0.22, mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    PT.receiver(g, 0.0, -0.22 * s, 0.66 * s, zc - 0.18 * s, zc + 0.16 * s, 0.36 * s, mats=[M[k] for k in RECV])
    rb, rr = 0.052 * s, 0.125 * s * (1.0 if nb == 6 else 0.85)
    _gun15(g, 0.0, 0.66 * s, zc, L, nb, rb, rr)
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.26 * s, 0.3 * s, zr + 0.02), (sx * 0.32 * s, 0.6 * s, zr + 0.2 * s), 0.026)
    P2.feed_chute(g, [(0.45 * s, -0.38 * s, zr + 0.05), (0.4 * s, -0.06 * s, zc + 0.12 * s),
                      (0.15 * s, 0.1 * s, zc + 0.17 * s)], 0.12 * s, M)
    # petite couronne de flèches sur le berceau
    for k in range(5):
        a = -0.9 + 0.45 * k
        d = V((math.sin(a), -math.cos(a), 0))
        c = V((0, 0.05 * s, zc + 0.16 * s)) + d * 0.2 * s
        P2.wedge(g, c - V((-d.y, d.x, 0)) * 0.025, c + V((-d.y, d.x, 0)) * 0.025, c + V((0, 0, 0.12)),
                 d * 0.018, M["jacket"], what="fleche")
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
    F.slits_grouped(g, R, z0 + 0.2, 12, M["emit"])
    F.slits_grouped(g, R, z0 + 0.36, 12, M["emit"], a0=0.3, per=(3, 2))
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
        conduit(g, [(sx * 0.6, -R - 0.3, H["zs"] + 0.2), (sx * R * 0.72, -R * 0.5, H["zs"] + H["rz"] * 0.4),
                    (xe, ye + 0.2, H["zg"] + H["hr"] * 0.55)], 0.04)
    # blindage à plaques multiples : deux rangées de plaques rapportées, liserés d'or blanc
    row1 = (0.35, 0.75, 1.15, 1.6, 2.0, 2.4, 2.8, -0.35, -0.75, -2.4, -2.8)
    ph1, w1, h1 = (0.3, 0.32, 0.26)
    for i, th in enumerate(row1):
        mat = M["trim"] if i % 3 == 1 else (M["ochre"] if i % 2 else M["steel_dk"])
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    for th in (0.6, 1.25, 1.9, 2.55):
        P2.applique(g, c.Pf, c.Nf, th, 0.75, 0.26, 0.22, M["ochre"], M)
        p = c.Pf(th, 0.75, 1.0)
        n = c.Nf(th, 0.75)
        g.push_frame(p + n * 0.066, n, V((-math.sin(th), math.cos(th), 0)))
        g.box((0, 0, 0), (0.27, 0.012, 0.01), M["jacket"], "hard", what="lisere")
        g.box((0, 0.105, 0), (0.27, 0.012, 0.01), M["jacket"], "hard", what="lisere")
        g.pop()
    # DEUX canons de coupole jumelés (14 n'en a qu'un) : plus de canons, plus longs
    dx = 0.64
    for sx in (-1, 1):
        g.push((sx * dx, 0.0, 0.0))
        zc = dome_gun(g, H, 6, 2.3, 0.9)
        g.pop()
    # affût jumelé : entretoise d'or blanc entre les deux berceaux (les canons sont assez écartés pour qu'aucun jour ne
    # s'enferme entre eux : à 0,42 et 0,33 t d'écart, les flèches des freins fermaient un jour de 300 à 570 px hr)
    g.box((0.0, 0.25, zc - 0.12), (2 * dx - 0.5, 0.3, 0.08), M["jacket"], "hard", what="entretoise")

    def zsurf(x, y):
        return H["zs"] + H["rz"] * math.sqrt(max(0.0, 1 - (x / R) ** 2 - (y / (R * 1.06)) ** 2))
    # sommet de la tête : GRANDE COURONNE ROYALE d'or blanc dressée au-dessus de la tourelle, sur une colonne de nacre
    # cerclée d'or blanc posée sur la coupole, derrière les canons de coupole (rien ne flotte) : bandeau, 12 fleurons
    # en flèche alternés, CALOTTE de nacre pleine (aucun jour enfermé dans la couronne), globe, flèche sommitale,
    # pierres et particules
    yc = -0.78
    zb = zsurf(0.0, yc)
    zr = zb + 0.95
    g.cyl((0.0, yc, (zb + zr) / 2 - 0.05), "z", 0.13, zr - zb, M["trim"], n=20, what="colonne")
    for f in (0.12, 0.45, 0.8):
        g.tube_shell((0.0, yc, zb + (zr - zb) * f), "z", 0.155, 0.12, 0.05, M["jacket"], n=20, what="bague_or")
        F.bolts_ring(g, (0.0, yc, zb + (zr - zb) * f + 0.026), (0, 0, 1), 0.14, 8, M["rivet"], r=0.012)
    g.cyl((0.0, yc, zb + 0.03), "z", 0.24, 0.06, M["jacket"], n=24, what="embase")
    for k in range(6):
        a = TAU * k / 6
        d = V((math.cos(a), math.sin(a), 0))
        P2.wedge(g, V((0, yc, zb + 0.05)) + d * 0.13, V((0, yc, zb + 0.05)) + d * 0.24, V((0, yc, zb + 0.35)) + d * 0.13,
                 V((-d.y, d.x, 0)) * 0.03, M["jacket"], what="gousset")
    rc = 0.84
    crown(g, (0, yc, zr), rc, n=14, h=0.72, gems_all=True)
    g.sphere((0.0, yc, zr + 0.02), rc * 1.0, M["redpaint"], n=32, m=12, scale=(1, 1, 0.36), what="calotte")
    g.torus((0.0, yc, zr + 0.17), "z", rc * 0.74, 0.024, M["jacket"], n=40, m=6, what="cerclage")
    # clous d'or blanc et perles sur le velours de la calotte (pièces isolées)
    for rr_, nn, zf in ((rc * 0.5, 10, 0.86), (rc * 0.86, 16, 0.5)):
        zz = zr + 0.02 + rc * 0.36 * math.sqrt(max(0.0, 1 - (rr_ / rc) ** 2))
        for k in range(nn):
            a = TAU * (k + 0.5 * (nn == 10)) / nn
            d = V((math.cos(a), math.sin(a), 0))
            g.bolt(V((0.0, yc, zz)) + d * rr_, V((d.x * (1 - zf), d.y * (1 - zf), zf)), 0.02, M["jacket"],
                   what="clou")
    g.sphere((0.0, yc, zr + rc * 0.36 + 0.1), 0.1, M["jacket"], n=20, m=10, what="globe")
    g.torus((0.0, yc, zr + rc * 0.36 + 0.1), "z", 0.1, 0.014, M["ring"], n=24, m=6, what="cerclage")
    q = V((0.0, yc, zr + rc * 0.36 + 0.18))
    P2.wedge(g, q - V((0.05, 0, 0)), q + V((0.05, 0, 0)), q + V((0, 0, 0.3)), V((0, 0.04, 0)), M["jacket"],
             what="fleche")
    P2.wedge(g, q - V((0, 0.05, 0)), q + V((0, 0.05, 0)), q + V((0, 0, 0.24)), V((0.04, 0, 0)), M["jacket"],
             what="fleche")
    g.sphere(q + V((0, 0, 0.32)), 0.028, E, n=10, m=6, what="pierre")
    g.cyl(q + V((0, 0, 0.41)), "z", 0.005, 0.12, M["jacket"], n=6, what="tige")
    g.sphere(q + V((0, 0, 0.48)), 0.016, E, n=8, m=5, what="particule")
    PT.capacitors(g, (0.0, -R - 0.14, H["zs"] + H["rz"] * 0.42), 4, 1, 0.1, 0.22, M["emit"])
    PT.sight(g, (-R * 0.64, R * 0.3, H["zs"] + H["rz"] * 0.5), 0.26, 0.26, 0.15, M["emit"], lenses=2)
