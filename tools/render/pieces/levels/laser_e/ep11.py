"""Laser · Âge 11 · Titane (ère IV, 5×5, niveaux 21 et 22). Lot F1-B (25/10) ; fiche : fo-logs/2026-10-24_F1/FICHES_LASER.md,
âge 11 (fait foi). S'exécute DANS Blender.

En 3 mots : « roue à ailerons, titane bleu, pointe orange ». L'affût est une TURBINE : étoile à 8 pointes chanfreinée en
3 gradins de titane bleu, liserés de lumière, 4 ailerons au sol, chevrons orange aux pointes, prises d'air, rivets ;
16 PILES DE DISQUES de titane à chapeau orange ; DÉRIVES triangulaires plantées aux coins arrière. L'émetteur est une
ROUE À AILERONS : carénage annulaire d'alliage, 12 ailerons vrillés autour de l'axe du faisceau, flasque arrière fermée,
CÔNE ORANGE au centre (la pointe) qui porte la lentille ; nacelle courte derrière ; fourche effilée ; caisson arrière à
deux petites dérives en V.
Palette 60/30/10 (ages.PALETTE[11]) : bleu titane / alliage blanc bleuté et bleu nuit / orange aéronautique.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import epoques as E_
import formes as F
import orne as O
import parts as PT
import parts2 as P2
from kit import SQ2, TAU
from repere import Y, at

V = Vector

EPOQUE = 11
NOM = ages.NOMS[11]
TRIPLET = ("roue à ailerons", "titane bleu", "pointe orange")
FOYER = ages.FOYER[11]
FAISCEAU = dict(rgb=(0.85, 0.94, 1.0), rgb2=(0.749, 0.902, 1.0), forme="trait très fin et très long, blanc bleuté, "
                "onde de choc (anneau) au départ", largeur=0.5)
HABILLAGE = dict(ages.CORPS[11], **E_.MAQUETTES[11])


def matieres(metal, M):
    ages.matieres(11, metal, M)


def liaison(g, pts, r):
    """Conduit de titane sombre à bagues orange."""
    M = g.M
    P = g.tube(g.spline(pts, 8), r, M["titane_dk"], n=10, what="conduit")[0]
    for i in range(2, len(P) - 1, 4):
        a = (P[min(len(P) - 1, i + 1)] - P[i - 1]).normalized()
        g.cyl(P[i], a, r * 1.3, r * 0.9, M["orange_aero"], n=10, style="hard", what="bague")


def condensateur(g, c, x, y, z, r, h):
    """Pile de disques de titane (ailettes alternées claires et sombres), fût central, chapeau orange."""
    M = g.M
    g.cyl((x, y, z + h * 0.45), "z", r * 0.45, h * 0.9, M["titane_dk"], n=12, what="fut")
    nd = 7
    for k in range(nd):
        zz = z + 0.04 + k * (h * 0.8) / nd
        g.cyl((x, y, zz), "z", r * (1.0 if k % 2 == 0 else 0.82), 0.025, M["titane_cl"] if k % 2 == 0 else M["ring"],
              n=16, style="hard", what="disque")
    g.cyl((x, y, z + h * 0.92), "z", r * 0.7, 0.05, M["orange_aero"], n=14, r2=r * 0.3, style="soft", what="chapeau")


def _chevron(g, k, h):
    """Chevron orange et rivets sur la pointe de l'étoile (repère du flanc)."""
    M = g.M
    for s in (-1, 1):
        g.box((s * 0.05, 0, 0.004), (0.12, 0.03, 0.008), M["orange_aero"], "flat", R=Matrix.Rotation(s * 0.6, 3, "Z"),
              what="chevron")
    for j in range(3):
        g.bolt(((j - 1) * 0.08, -h * 0.3, 0.004), (0, 0, 1), 0.012, M["rivet_ti"])


def _prise_air(g, k, h):
    """Prise d'air ovale (repère du flanc) : lèvre d'alliage, fond bleu nuit, grille."""
    M = g.M
    g.cyl((0, 0, 0.012), "z", 0.07, 0.024, M["ring"], n=16, what="levre")
    g.cyl((0, 0, 0.022), "z", 0.055, 0.008, M["bleu_nuit"], n=16, style="flat", what="fond")
    for j in range(3):
        g.box((0, (j - 1) * 0.03, 0.026), (0.1, 0.008, 0.006), M["titane_dk"], "flat", what="lame")


def _dessus(g, k, w):
    """Dessus : ventilateur vu de dessus ou petit caisson à voyant."""
    M = g.M
    if k % 2 == 0:
        P2.fan_radiator(g, -0.1, 0.1, -0.1, 0.1, 0.0, 0.06, 1, M, fin_mat=M["titane_md"])
    else:
        g.box((0, 0, 0.03), (0.1, 0.16, 0.06), M["titane_md"], "hard", what="caisson")
        O.lampe(g, (0, -0.081, 0.03), (0, -1, 0), 0.018, M["emit"], M["bleu_nuit"])
        g.box((0, 0, 0.062), (0.1, 0.02, 0.005), M["orange_aero"], "flat", what="repere")


def _derive(g, x, y, sx, h, L, M):
    """Dérive triangulaire pleine de titane, plantée dans le sol, bord d'attaque orange, rivets."""
    a = V((x - sx * L * 0.35, y + L * 0.25, 0.0))
    b = V((x + sx * L * 0.45, y - L * 0.35, 0.0))
    top = V((x - sx * L * 0.15, y + L * 0.12, h))
    dd = (b - a).normalized()
    P2.wedge(g, a, b, top, V((-dd.y, dd.x, 0.0)) * 0.09, M["titane_cl"], what="derive")
    d = top - b
    g.box((top + b) / 2, (0.05, d.length, 0.05), M["orange_aero"], "hard",
          R=Matrix.Rotation(math.atan2(-d.x, d.y), 3, "Z") @ Matrix.Rotation(math.atan2(d.z, math.hypot(d.x, d.y)), 3, "X"),
          what="bord_attaque")
    g.box((a + b) / 2 + V((0, 0, 0.04)), ((b - a).length * 1.05, 0.14, 0.08), M["titane_dk"], "hard",
          R=Matrix.Rotation(math.atan2((b - a).y, (b - a).x), 3, "Z"), what="semelle")


def socle(g, c):
    """Chevrons orange et rivets aux pointes de l'étoile, prises d'air, ventilateurs et caissons sur les gradins,
    dérives (coins arrière), conduits vers le pivot."""
    M = g.M
    zp = c.gradins[-1][3]
    pointes = [math.radians(101.25) + TAU * k / 8 for k in range(8)]
    O.sur_flanc(g, c, 0, O.visibles(pointes, nord=0.4), _chevron, f=0.5, dr=0.004)
    O.sur_flanc(g, c, 1, O.visibles([a + TAU / 16 for a in pointes], nord=0.2), _prise_air, f=0.5, dr=0.0)
    O.rivets_flanc(g, c, 2, 0.5, M["rivet_ti"], pas=0.12, r=0.012)
    O.ceinture(g, c, 0, 0.18, 0.014, M["bleu_nuit"])
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (200, 230, 250, 290, 310, 340)], _dessus)
    O.sur_dessus(g, c, 0, O.visibles(O.entre_condensateurs(c), nord=0.2), _dessus, t=0.5)
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, y = p["x"] - sx * 0.04, Y(p["yn"] - 0.04)
        _derive(g, x, y, sx, 0.9, 0.85, M)
        # ronde 1 (F1-B) : la dérive était un ÎLOT détaché (1 479 px, ilots.py) : longeron de titane au sol de son pied
        # au flanc du premier gradin, et conduit qui part de son pied
        a = math.atan2(p["yn"], p["x"])
        q, nrm, _ = O.flanc(c, 0, a, 0.1, -0.05)
        d = V((x, y, 0.0)) - V((q.x, q.y, 0.0))
        g.box((V((x, y, 0.0)) + V((q.x, q.y, 0.0))) / 2 + V((0, 0, 0.05)), (d.length + 0.1, 0.16, 0.1), M["titane_dk"],
              "hard", R=Matrix.Rotation(math.atan2(d.y, d.x), 3, "Z"), what="longeron")
        for j in range(3):
            g.bolt(tuple(V((q.x, q.y, 0.1)) + d * (0.25 + 0.25 * j)), (0, 0, 1), 0.015, M["rivet_ti"])
        liaison(g, [(x - sx * 0.1, y - 0.15, 0.12), (x * 0.66, Y(p["yn"] * 0.62), c.gradins[0][3] + 0.08),
                    (x * 0.42, Y(p["yn"] * 0.4), zp + 0.05)], 0.04)
        g.halo((x, y - 0.4, 0.4), M["_emit_rgb"], 4.0)
    for (x, yn) in ((0.0, -2.2), (-1.8, -0.9), (1.8, -0.9)):
        g.halo((x, Y(yn), 0.3), M["_emit_rgb"], 4.0)


def piece(g, c):
    """Niveau 22 : deux NACELLES À AILERONS couchées en travers sur des berceaux, aux coins avant, patin de tôles de
    titane relié au premier gradin."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.14, yn + 0.14, 0.95, 0.95, rz=sx * 0.785)
        with at(g, x, yn, sx * 0.785, z=0.035):
            for s in (-1, 1):
                g.box((s * 0.18, 0, 0.08), (0.06, 0.3, 0.16), M["titane_dk"], "hard", what="berceau")
            r, L = 0.15, 0.6
            g.cyl((0, 0, 0.22), "x", r, L, M["titane_cl"], n=24, style="soft", what="nacelle")
            g.sphere((L / 2, 0, 0.22), r, M["orange_aero"], n=20, m=10, scale=(1.6, 1.0, 1.0), what="nez")
            g.cyl((-L / 2 - 0.03, 0, 0.22), "x", r * 0.8, 0.06, M["titane_dk"], n=20, what="tuyere")
            g.cyl((-L / 2 - 0.06, 0, 0.22), "x", r * 0.55, 0.012, M["emit"], n=16, style="flat", what="feu")
            for k in range(4):
                a = TAU * k / 4 + math.pi / 4
                d = V((0, math.cos(a), math.sin(a)))
                g.box(V((-L * 0.35, 0, 0.22)) + d * (r + 0.07), (0.16, 0.02, 0.14), M["titane_md"], "hard",
                      R=Matrix.Rotation(a, 3, "X"), what="aileron")
            g.tube_shell((0.0, 0, 0.22), "x", r + 0.012, r - 0.01, 0.03, M["orange_aero"], n=24, what="bague")
        g.halo((x, Y(yn - 0.4), 0.4), M["_emit_rgb"], 4.0)


def arriere(g, c):
    """Caisson arrière bas de titane à DEUX PETITES DÉRIVES EN V (couchées vers les côtés, jamais dressées)."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    PT.hull(g, -bx, bx, y0, y1, zb, z1 - 0.1, ins=(0.05, 0.08, 0.0), panel=0.24,
            mats=[M["titane_md"], M["titane_cl"]], rivet_step=0.12)
    for sx in (-1, 1):
        a = V((sx * bx * 0.3, y0 + 0.02, z1 - 0.1))
        b = V((sx * bx * 0.3, y1 - 0.05, z1 - 0.1))
        top = V((sx * bx * 1.05, y0 + 0.04, z1 + 0.06))
        P2.wedge(g, a, b, top, (b - a).cross(top - a).normalized() * 0.035, M["titane_cl"], what="derive")
        g.box(((a + top) / 2), (0.03, 0.03, 0.02), M["orange_aero"], "hard", what="repere")


def tete(g, c):
    """Petits réservoirs de titane à bague orange et prises d'air à l'arrière de la platine."""
    M = g.M
    zb = O.zb(c)
    for (x, y, w) in O.pods(c):
        g.cyl((x, y, zb + w * 0.6), "y", w * 0.7, w * 2.0, M["titane_cl"], n=14, style="soft", what="reservoir")
        g.tube_shell((x, y, zb + w * 0.6), "y", w * 0.76, w * 0.6, 0.03, M["orange_aero"], n=14, what="bague")


def emetteur(g, c):
    """ROUE À AILERONS : carénage annulaire d'alliage à bande orange, 12 ailerons vrillés, flasque arrière fermée,
    CÔNE ORANGE central (la pointe) qui porte la lentille ; nacelle courte derrière (portée par l'axe)."""
    M = g.M
    re, zh = c.re, c.zh
    # ronde 1 (F1-B) : la roue du premier jet était enfermée dans un carénage annulaire ; en pose E on ne voyait qu'un
    # cylindre d'alliage, et en pose N le dos de la nacelle : ni « roue » ni « ailerons ». Désormais : moyeu PLEIN d'où
    # sortent 12 ailerons vrillés (ouverts vers l'extérieur : aucun jour enfermé), lisibles de côté et de dos ; cône
    # orange plus gros et plus long.
    # nacelle arrière
    g.cyl((0, -0.45 * re, zh), "y", 0.62 * re, 0.6 * re, M["titane_md"], n=32, r2=0.7 * re, style="soft",
          what="nacelle")
    g.tube_shell((0, -0.55 * re, zh), "y", 0.66 * re, 0.5 * re, 0.05, M["ring"], n=32, what="bague")
    # moyeu plein
    yh0, yh1 = -0.16 * re, 0.36 * re
    g.cyl((0, (yh0 + yh1) / 2, zh), "y", 0.66 * re, yh1 - yh0, M["titane_md"], n=40, style="soft", what="moyeu")
    for yy in (yh0 + 0.03, yh1 - 0.03):
        g.tube_shell((0, yy, zh), "y", 0.68 * re, 0.6 * re, 0.05, M["ring"], n=40, what="cercle_moyeu")
    F.bolts_ring(g, (0, yh1 + 0.002, zh), (0, 1, 0), 0.56 * re, 16, M["rivet_ti"], r=0.014)
    # ailerons vrillés (alliage clair à bout orange)
    for k in range(12):
        a = TAU * k / 12 + 0.13
        d = V((math.cos(a), 0, math.sin(a)))
        m = V((0, (yh0 + yh1) / 2, zh)) + d * (0.8 * re)
        Rr = Matrix((d, V((0, 1, 0)).cross(d), V((0, 1, 0)))).transposed() @ Matrix.Rotation(0.4, 3, "X")
        g.box(m, (0.42 * re, 0.07 * re, 0.44 * re), M["ring"] if k % 2 else M["titane_cl"], "hard", R=Rr,
              what="aileron")
        g.box(V((0, (yh0 + yh1) / 2, zh)) + d * (1.0 * re), (0.05 * re, 0.075 * re, 0.4 * re), M["orange_aero"], "hard",
              R=Rr, what="bout_aileron")
    # cône orange (la pointe) et lentille
    g.cyl((0, 0.74 * re, zh), "y", 0.44 * re, 0.76 * re, M["orange_aero"], n=28, r2=0.09 * re, style="soft",
          what="cone")
    for f in (0.42, 0.62):
        g.tube_shell((0, f * re, zh), "y", (0.44 - 0.5 * (f - 0.36)) * re + 0.01, 0.2 * re, 0.035, M["titane_dk"],
                     n=28, what="bague_cone")
    corps.lentille(g, c, 1.12 * re, 0.08 * re, verre=M["glass_dk"], cercle=M["titane_dk"])
