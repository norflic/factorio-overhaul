"""Laser · Âge 10 · Haute technologie (ère IV, 5×5, niveaux 19 et 20). Lot F1-B (25/10) ; fiche :
fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 10 (fait foi). S'exécute DANS Blender.

En 3 mots : « carénage ivoire, visière bleue, nappes de câbles ». L'affût est un GALET : grand plateau rond chanfreiné
lisse et petit tambour, carénage ivoire à joints anthracite, trappes à voyants bleus, grilles d'aération, écrans et
consoles ; 16 BAIES DE SUPERCONDENSATEURS ; NAPPES DE CÂBLES rouges et bleues dans des goulottes jusqu'au pivot ; baies
électroniques à grilles et voyants groupés aux coins arrière. L'émetteur est une TÊTE CARÉNÉE ivoire (plus large que
longue) barrée d'une VISIÈRE BLEUE ENVELOPPANTE à lamelles (face avant ET flancs, comme l'œil d'un robot), deux capteurs
courts sur le dessus, grilles ; étrier caréné ; baie électronique derrière.
Palette 60/30/10 (ages.PALETTE[10]) : ivoire chaud / anthracite / câbles rouge et bleu vifs, voyants bleus.
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
import parts3 as P3
from kit import SQ2, TAU
from repere import Y, at

V = Vector

EPOQUE = 10
NOM = ages.NOMS[10]
TRIPLET = ("carénage ivoire", "visière bleue", "nappes de câbles")
FOYER = ages.FOYER[10]
FAISCEAU = dict(rgb=(0.2, 0.55, 1.0), rgb2=(0.09, 0.33, 1.0), forme="bleu vif en IMPULSIONS (trait en pointillés "
                "rapides)", largeur=0.9)
HABILLAGE = dict(ages.CORPS[10], **E_.MAQUETTES[10])


def matieres(metal, M):
    ages.matieres(10, metal, M)


def liaison(g, pts, r):
    """Nappe de câbles rouges et bleus dans une goulotte anthracite."""
    M = g.M
    PT.cable_run(g, pts, 4, max(0.011, r * 0.4), max(0.024, r * 0.85), [M["cable_r"], M["cable_b"]])


def condensateur(g, c, x, y, z, r, h):
    """Baie de supercondensateur carrée : caisson ivoire, tête anthracite, fentes, voyant bleu vers l'extérieur."""
    M = g.M
    w = r * 1.5
    a = math.atan2(y, x)
    Rz = Matrix.Rotation(a, 3, "Z")
    hh = h * 0.85
    g.box((x, y, z + hh / 2), (w, w, hh), M["blanc_casse"], "soft", R=Rz, what="baie")
    g.box((x, y, z + hh + 0.02), (w * 1.05, w * 1.05, 0.04), M["anthracite"], "hard", R=Rz, what="tete_baie")
    d = V((math.cos(a), math.sin(a), 0))
    t = V((-d.y, d.x, 0))
    for k in range(3):
        g.box(V((x, y, z + hh * (0.3 + 0.18 * k))) + d * (w / 2 + 0.002), (0.004, w * 0.7, 0.02), M["gris_tech"],
              "flat", R=Rz, what="fente")
    if d.y < 0.3:
        O.lampe(g, V((x, y, z + hh * 0.82)) + d * (w / 2), d, 0.02, M["emit"], M["anthracite"])


def _trappe(g, k, h):
    """Trappe d'accès carénée : joint anthracite, groupe de voyants bleus, poignée encastrée."""
    M = g.M
    g.box((0, 0, 0.004), (0.3, h * 0.55, 0.008), M["gris_tech"], "flat", what="joint")
    g.box((0, 0, 0.01), (0.27, h * 0.48, 0.008), M["blanc_casse"], "soft", what="trappe")
    P3.lamp_group(g, (-0.08, h * 0.12, 0.012), (1, 0, 0), (0, 0, 1), M["emit"], M, n=3, size=0.022)
    g.box((0.07, -h * 0.1, 0.016), (0.06, 0.014, 0.008), M["anthracite"], "flat", what="poignee")


def _grille(g, k, h):
    M = g.M
    w = 0.26
    g.grille([V((-w / 2, -h * 0.22, 0.004)), V((w / 2, -h * 0.22, 0.004)), V((w / 2, h * 0.22, 0.004)),
              V((-w / 2, h * 0.22, 0.004))], 4, slat_mat=M["gris_tech"])


def _console(g, k, w):
    """Console sur le dessus : pupitre anthracite, petit écran, voyants."""
    M = g.M
    if k % 2 == 0:
        g.box((0, 0, 0.05), (0.12, 0.2, 0.1), M["anthracite"], "hard", what="pupitre")
        P3.screen(g, (-0.065, 0, 0.07), (-1, 0, 0.5), 0.12, 0.07, M, M["emit"])
    else:
        g.box((0, 0, 0.025), (0.1, 0.16, 0.05), M["blanc_casse"], "soft", what="boitier")
        P3.lamp_group(g, (-0.052, -0.04, 0.03), (0, 1, 0), (-1, 0, 0), M["emit"], M, n=2, size=0.016)


def _baie_sol(g, k, w):
    """Prise de données au sol (entre deux baies, sur le plateau) : boîtier ivoire, câble court."""
    M = g.M
    g.box((0, 0, 0.03), (0.1, 0.1, 0.06), M["gris_tech"], "hard", what="prise")
    g.box((0, 0, 0.062), (0.06, 0.06, 0.006), M["emit_soft"], "flat", what="voyant")


def socle(g, c):
    """Joints anthracite du carénage, trappes à voyants, grilles d'aération, consoles et écrans, baies électroniques
    (coins arrière), nappes de câbles vers le pivot."""
    M = g.M
    zp = c.gradins[-1][3]
    O.ceinture(g, c, 0, 0.2, 0.012, M["anthracite"])
    O.ceinture(g, c, 1, 0.3, 0.012, M["anthracite"])
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (205, 250, 290, 335)], _trappe, f=0.55, dr=0.004)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (228, 312, 185, 355)], _grille, f=0.55, dr=0.002)
    O.sur_flanc(g, c, 1, [math.radians(a) for a in (220, 270, 320)], _trappe, f=0.6, dr=0.004)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (200, 235, 270, 305, 340)], _console)
    O.sur_dessus(g, c, 0, O.visibles(O.entre_condensateurs(c), nord=0.3), _baie_sol, t=0.5)
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, y = p["x"] - sx * 0.04, Y(p["yn"] - 0.04)
        w, d, h = 0.62, 0.4, 0.72
        PT.hull(g, x - w / 2, x + w / 2, y - d / 2, y + d / 2, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.24,
                mats=[M["blanc_casse"], M["gris_tech"]], rivet_step=0.14)
        g.grille([V((x - w * 0.42, y - d / 2 - 0.01, 0.08)), V((x + w * 0.42, y - d / 2 - 0.01, 0.08)),
                  V((x + w * 0.42, y - d / 2 - 0.01, 0.34)), V((x - w * 0.42, y - d / 2 - 0.01, 0.34))], 5,
                 slat_mat=M["anthracite"])
        P3.lamp_group(g, (x - w * 0.3, y - d / 2 - 0.02, 0.5), (1, 0, 0), (0, -1, 0), M["emit"], M, n=3, size=0.026)
        P3.lamp_group(g, (x + w * 0.05, y - d / 2 - 0.02, 0.6), (1, 0, 0), (0, -1, 0), M["emit_soft"], M, n=2,
                      size=0.022)
        P3.screen(g, (x + w * 0.22, y - d / 2 - 0.015, 0.5), (0, -1, 0), 0.14, 0.09, M, M["emit"])
        P2.fan_radiator(g, x - w * 0.4, x + w * 0.4, y - d * 0.4, y + d * 0.4, h, h + 0.08, 2, M,
                        fin_mat=M["gris_tech"])
        liaison(g, [(x - sx * 0.2, y - 0.25, 0.1), (x * 0.66, Y(p["yn"] * 0.62), c.gradins[0][3] + 0.06),
                    (x * 0.42, Y(p["yn"] * 0.4), zp + 0.04)], 0.035)
        g.halo((x, y - 0.4, 0.4), M["_emit_rgb"], 5.0)
    for (x, yn) in ((0.0, -2.2), (-1.8, -0.9), (1.8, -0.9)):
        g.halo((x, Y(yn), 0.3), M["_emit_rgb"], 5.0)


def piece(g, c):
    """Niveau 20 : deux BAIES DE SUPERCONDENSATEURS carénées aux coins avant (caisson ivoire arrondi, barres d'état
    bleues, grilles), sur un patin de dalles techniques relié au plateau."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.14, yn + 0.14, 0.95, 0.95, rz=sx * 0.785)
        with at(g, x, yn, sx * 0.785, z=0.035):
            PT.hull(g, -0.3, 0.3, -0.22, 0.22, 0.0, 0.62, ins=(0.03, 0.03, 0.03), panel=0.2,
                    mats=[M["blanc_casse"], M["gris_tech"]], rivet_step=0.14)
            for k in range(4):
                g.box((-0.15 + 0.1 * k, -0.225, 0.2 + 0.02 * (k % 2)), (0.05, 0.008, 0.2 + 0.08 * (k % 3)),
                      M["emit"] if k % 2 == 0 else M["gris_tech"], "flat", what="barre_etat")
            g.box((0, 0, 0.64), (0.5, 0.36, 0.04), M["anthracite"], "hard", what="toit")
            g.grille([V((-0.2, -0.12, 0.665)), V((0.2, -0.12, 0.665)), V((0.2, 0.12, 0.665)),
                      V((-0.2, 0.12, 0.665))], 5, slat_mat=M["gris_tech"])
        g.halo((x, Y(yn - 0.4), 0.5), M["_emit_rgb"], 5.0)


def arriere(g, c):
    """BAIE ÉLECTRONIQUE basse : caisson ivoire et anthracite, grille arrière, voyants groupés, câbles."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    T = PT.hull(g, -bx, bx, y0, y1, zb, z1 - 0.04, ins=(0.03, 0.03, 0.0), panel=0.22,
                mats=[M["blanc_casse"], M["gris_tech"]], rivet_step=0.14)
    g.grille(PT.lift(PT.face_quad([V((-bx, y0, zb)), V((bx, y0, zb)), T[1], T[0]], 0.1, 0.6, 0.2, 0.8), 0.01), 5,
             slat_mat=M["anthracite"])
    P3.lamp_group(g, (bx * 0.35, y0 - 0.015, zb + (z1 - zb) * 0.6), (1, 0, 0), (0, -1, 0), M["emit"], M, n=3, size=0.022)
    g.box((0, (y0 + y1) / 2, z1 - 0.02), (2 * bx - 0.06, y1 - y0 - 0.04, 0.03), M["anthracite"], "hard", what="toit")


def tete(g, c):
    """Petits boîtiers ivoire à voyants et nappes courtes à l'arrière de la platine."""
    M = g.M
    zb = O.zb(c)
    for k, (x, y, w) in enumerate(O.pods(c)):
        g.box((x, y, zb + w * 0.7), (w * 2, w * 1.6, w * 1.4), M["blanc_casse"], "soft", what="boitier")
        P3.lamp_group(g, (x - w * 0.5, y - w * 0.8 - 0.012, zb + w * 1.0), (1, 0, 0), (0, -1, 0), M["emit"], M, n=2,
                      size=0.02)
        PT.cable_run(g, [(x, y + w * 0.8, zb + w * 0.4), (x * 0.8, 0.0, zb + w * 0.6), (x * 0.7, 0.2 * c.re, c.zh - 0.4 * c.re)],
                     2, 0.012, 0.026, [M["cable_r"], M["cable_b"]])


def emetteur(g, c):
    """TÊTE CARÉNÉE ivoire (ellipsoïde plus large que longue), VISIÈRE BLEUE ENVELOPPANTE à lamelles (face avant et
    flancs), lentille derrière la visière, deux capteurs courts sur le dessus, joints et grilles."""
    M = g.M
    re, zh = c.re, c.zh
    ax, ay, az = 0.95 * re, 0.55 * re, 0.72 * re
    yc = 0.12 * re
    g.sphere((0, yc, zh), 1.0, M["blanc_casse"], n=40, m=20, scale=(ax, ay, az), what="carenage")
    # joint anthracite à l'équateur arrière, bandeau sombre sous la visière
    zv = 0.1 * az
    s = math.sqrt(1 - (zv / az) ** 2)
    pts = []
    for k in range(49):
        phi = math.radians(-20 + 220 * k / 48)
        pts.append(V((ax * s * 1.01 * math.cos(phi), yc + ay * s * 1.01 * math.sin(phi), zh + zv)))
    g.tube(pts, 0.11 * re, M["anthracite"], n=8, style="soft", what="bandeau")
    # visière : lamelles lumineuses séparées par des meneaux sombres
    nl = 14
    for k in range(nl):
        phi0 = math.radians(-12 + 204 * k / nl)
        phi1 = math.radians(-12 + 204 * (k + 0.78) / nl)
        p0 = V((ax * s * 1.06 * math.cos(phi0), yc + ay * s * 1.06 * math.sin(phi0), zh + zv))
        p1 = V((ax * s * 1.06 * math.cos(phi1), yc + ay * s * 1.06 * math.sin(phi1), zh + zv))
        d = p1 - p0
        nrm = V((d.y, -d.x, 0)).normalized()
        if nrm.dot(V((p0.x, p0.y - yc, 0))) < 0:
            nrm = -nrm
        Rr = Matrix((d.normalized(), nrm, d.normalized().cross(nrm))).transposed()
        g.box((p0 + p1) / 2, (d.length, 0.02, 0.13 * re), M["emit"], "flat", R=Rr, what="lamelle")
    corps.lentille(g, c, yc + ay * 1.0, 0.16 * re, verre=M["glass_dk"], cercle=M["anthracite"], anneau=False)
    # capteurs courts sur le dessus (couchés dans l'axe), grille centrale
    for sx in (-1, 1):
        g.box((sx * 0.38 * ax, yc - 0.05 * re, zh + az * 0.86), (0.14 * re, 0.36 * re, 0.1 * re), M["anthracite"],
              "hard", what="capteur")
        g.cyl((sx * 0.38 * ax, yc + 0.14 * re, zh + az * 0.86), "y", 0.035 * re, 0.02, M["emit"], n=10, style="flat",
              what="oeil_capteur")
    g.grille([V((-0.22 * re, yc - 0.42 * ay, zh + az * 0.93)), V((0.22 * re, yc - 0.42 * ay, zh + az * 0.93)),
              V((0.22 * re, yc + 0.1 * ay, zh + az * 0.97)), V((-0.22 * re, yc + 0.1 * ay, zh + az * 0.97))], 5,
             slat_mat=M["gris_tech"])
    # câbles rouge et bleu qui sortent de l'arrière du carénage vers la baie
    for k, m in enumerate((M["cable_r"], M["cable_b"])):
        xx = (k - 0.5) * 0.12 * re
        g.tube([V((xx, yc - ay * 0.9, zh - 0.1 * az)), V((xx, yc - ay * 1.15, zh - 0.4 * az)),
                V((xx, -0.8 * re, zh - 0.6 * az))], 0.022, m, n=8, what="cable")
