"""Four · Âge 7 · Cristal (ère III, 4×4, niveaux 13 et 14). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 7. S'exécute
DANS Blender.

En 3 mots : « athanor, couronne de cristaux, portail en arche ». La chambre est un ATHANOR (four d'alchimiste) :
tour OCTOGONALE à trois étages, deux étages de pierre claire en assises (nervures de bronze aux arêtes, fentes violettes
sur les faces sud), coupole octogonale de bronze à plaques rivetées, COURONNE DE CRISTAUX violets au sommet (certains
lumineux) ; PORTAIL EN ARCHE de pierre à claveaux autour de la gueule, cristal en clé de voûte ; vasques de bronze à
flamme violette ; à l'arrière droit, tourelle de pierre à chapeau de bronze (la fumée).
Palette 60/30/10 (ages.PALETTE[7]) : bronze doré / pierre claire / violet de cristal.
"""
import math

from mathutils import Matrix

import ages
import corps
import formes as F
from kit import TAU
from repere import Y

EPOQUE = 7
NOM = ages.NOMS[7]
TRIPLET = ("athanor", "couronne de cristaux", "portail en arche")
FOYER = ages.FOYER[7]
HABILLAGE = dict(ages.CORPS[7], gueule="arche", foyer="bronze_sombre")
CYN = 0.3
PH = math.pi / 8


def matieres(metal, M):
    ages.matieres(7, metal, M)


def octo(R, z, cy, cx=0.0):
    return [(cx + R * math.cos(PH + TAU * k / 8), cy + R * math.sin(PH + TAU * k / 8)) for k in range(8)]


def faces_visibles(Pb, Pt, z0, z1):
    """Quadrilatères des faces de l'octogone tournées vers le sud (normale y < 0), vus de l'extérieur."""
    out = []
    for k in range(8):
        j = (k + 1) % 8
        mx, my = (Pb[k][0] + Pb[j][0]) / 2, (Pb[k][1] + Pb[j][1]) / 2
        q = [corps.V((Pb[k][0], Pb[k][1], z0)), corps.V((Pb[j][0], Pb[j][1], z0)), corps.V((Pt[j][0], Pt[j][1], z1)),
             corps.V((Pt[k][0], Pt[k][1], z1))]
        n = (q[1] - q[0]).cross(q[3] - q[0])
        if n.y < -0.05:
            out.append((k, q))
    return out


def etage(g, R0, R1, z0, z1, cy, mats, assises=True, panneaux=None):
    M = g.M
    Pb, Pt = octo(R0, z0, cy), octo(R1, z1, cy)
    vs = [(x, y, z0) for x, y in Pb] + [(x, y, z1) for x, y in Pt]
    fs = [tuple(range(8))[::-1], tuple(range(8, 16))] + [(k, (k + 1) % 8, 8 + (k + 1) % 8, 8 + k) for k in range(8)]
    g._add(M["joint_violet"] if assises else M["bronze_sombre"], "flat", vs, fs, "etage")
    for k, q in faces_visibles(Pb, Pt, z0, z1):
        if assises:
            F.courses(g, q, mats, bw=0.2, bh=0.1, t=0.02)
        else:
            lu, lv = (q[1] - q[0]).length, (q[3] - q[0]).length
            g.panels(q, max(1, int(lu / 0.32)), max(1, int(lv / 0.3)), mats[0], t=0.022, rivet_mat=M["bronze_clair"],
                     mats=mats, rivet_step=0.1)
    return Pb, Pt


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    cy = Y(CYN)
    pierre = [M["pierre_claire"], M["pierre_claire2"], M["pierre_claire"]]
    etage(g, 1.7, 1.66, zs, 0.6, cy, pierre)
    corps.couronne_poly(g, octo(1.72, 0, cy), octo(1.5, 0, cy), 0.58, 0.66, M["bronze_capot"], what="corniche")
    Pb, Pt = etage(g, 1.42, 1.38, 0.66, 1.82, cy, [M["pierre_claire2"], M["pierre_claire"]])
    for k in range(8):
        x, y = Pb[k]
        if y > cy + 0.3:
            continue
        g.box((x, y, 1.24), (0.09, 0.09, 1.16), M["bronze_capot"], "hard", R=F.Rz(PH + TAU * k / 8), what="nervure")
    for k, q in faces_visibles(Pb, Pt, 0.66, 1.82):
        mid = (q[0] + q[1]) / 2
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
        g.box(mid + nrm * 0.01 + corps.V((0, 0, 0.55)), (0.1, 0.03, 0.5), M["void"], "flat", R=F.Rz(PH + TAU * (k + 0.5)
                                                                                                    / 8 + math.pi / 2),
              what="fente")
        g.box(mid + nrm * 0.02 + corps.V((0, 0, 0.55)), (0.04, 0.02, 0.42), M["emit"], "flat",
              R=F.Rz(PH + TAU * (k + 0.5) / 8 + math.pi / 2), what="fente_lum")
    corps.couronne_poly(g, octo(1.46, 0, cy), octo(1.25, 0, cy), 1.8, 1.88, M["bronze_clair"], what="corniche")
    etage(g, 1.32, 0.55, 1.88, 2.62, cy, [M["bronze_capot"], M["bronze_capot"], M["bronze_clair"]], assises=False)
    couronne(g, c, cy)
    # vasques de bronze à flamme violette sur l'étage bas (avant)
    for sx in (-1, 1):
        x, y = sx * 1.2, cy - 1.15
        g.cyl((x, y, 0.75), "z", 0.06, 0.18, M["bronze_sombre"], n=10, what="pied")
        g.cyl((x, y, 0.88), "z", 0.1, 0.1, M["bronze_capot"], n=14, r2=0.15, what="vasque")
        g.cyl((x, y, 1.02), "z", 0.1, 0.2, M["emit"], n=10, r2=0.0, what="flamme")
        g.halo((x, y - 0.15, 1.0), M["_emit_rgb"], 3.0)


def couronne(g, c, cy):
    M = g.M
    z0 = 2.62
    corps.prisme(g, octo(0.6, 0, cy), z0, z0 + 0.12, M["bronze_sombre"], what="collier")
    cristaux = [(0.0, 0.0, 0.0, 0.85, 0.15, "emit_soft")]
    for k in range(6):
        a = TAU * k / 6 + 0.3
        cristaux.append((0.24 * math.cos(a), 0.24 * math.sin(a), 0.42, 0.5 + 0.12 * (k % 3), 0.1,
                         "emit_soft" if k % 3 == 1 else "crystal"))
    for (dx, dy, tilt, h, r, m) in cristaux:
        d = corps.V((math.sin(tilt) * (dx / 0.24 if dx or dy else 0), math.sin(tilt) * (dy / 0.24 if dx or dy else 0),
                     math.cos(tilt))).normalized()
        F.crystal(g, (dx, cy + dy, z0 + 0.06), d, r, h, M[m])
    g.halo((0, cy - 0.3, z0 + 0.5), M["_emit_rgb"], 5.0)


def gueule(g, c, G):
    """Portail en arche : piédroits de pierre, claveaux en éventail, cristal en clé de voûte."""
    M = g.M
    zr = G.get("zr", (G["bz0"] + G["bz1"]) / 2)
    R = G["bx1"] + 0.16
    yf = G["yf"] - 0.04
    for sx in (-1, 1):
        g.box((sx * (G["bx1"] + 0.1), yf, (G["z0"] + zr) / 2), (0.18, 0.12, zr - G["z0"]), M["pierre_claire"], "hard",
              what="piedroit")
    n = 9
    for k in range(n):
        a = math.pi * (k + 0.5) / n
        p = corps.V((R * math.cos(a), yf, zr + R * math.sin(a)))
        g.box(p, (0.17, 0.12, 0.13), M["pierre_claire2" if k % 2 else "pierre_claire"], "hard",
              R=Matrix.Rotation(-(a + math.pi / 2), 3, "Y"), what="claveau")
    F.crystal(g, (0, yf - 0.03, zr + R + 0.05), (0, -0.3, 1), 0.06, 0.24, M["emit_soft"])


def fumee(g, c):
    M = g.M
    f = c.T["fumee"]
    x, yn = f["x"] + 0.05, f["yn"]
    y = Y(yn)
    z0, z1 = 0.66, 3.1
    g.cyl((x, y, (z0 + z1) / 2), "z", 0.25, z1 - z0, M["pierre_claire2"], n=8, phase=PH, style="hard", what="tourelle")
    for z in (1.2, 1.85, 2.5):
        g.tube_shell((x, y, z), "z", 0.27, 0.22, 0.06, M["bronze_capot"], n=8, what="bague")
    g.tube_shell((x, y, z1 - 0.12), "z", 0.26, 0.2, 0.05, M["emit"], n=8, what="liseré")
    g.cyl((x, y, z1 + 0.05), "z", 0.3, 0.1, M["bronze_capot"], n=8, phase=PH, style="hard", what="chapeau")
    corps.bouche_fumee(g, c, x, yn, z1 + 0.1, 0.17)


def piece(g, c):
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        x, y = p["x"], Y(p["yn"])
        corps.prisme(g, octo(0.3, 0, y, x), zs, zs + 0.18, M["pierre_claire"], style="hard", what="piedestal")
        corps.prisme(g, octo(0.24, 0, y, x), zs + 0.18, zs + 0.24, M["bronze_capot"], what="plateau")
        for k, (dx, dy, tilt, h) in enumerate(((0, 0, 0.0, 0.5), (0.1, 0.05, 0.4, 0.34), (-0.1, 0.04, 0.45, 0.3),
                                               (0.02, -0.1, 0.35, 0.28))):
            d = corps.V((math.sin(tilt) * (1 if dx > 0 else -1 if dx < 0 else 0), -math.sin(tilt) * (dy < 0), 1))
            F.crystal(g, (x + dx, y + dy, zs + 0.24), d, 0.07 if k else 0.09, h,
                      M["emit_soft"] if k == 0 else M["crystal"])
