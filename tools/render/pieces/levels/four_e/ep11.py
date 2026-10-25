"""Four · Âge 11 · Titane (ère IV, 5×5, niveaux 21 et 22). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 11.
S'exécute DANS Blender.

En 3 mots : « nacelle à réacteur, ailerons, tuyère orange ». La chambre est un FOUR À TUYÈRE (fusion du titane par jet
de gaz chaud) : grande NACELLE DE RÉACTEUR de titane bleu couchée sur deux pylônes, tournée de 20° pour montrer son
entrée d'air (lèvre d'alliage pâle, roue d'aubes, cône orange) ; bandes bleu nuit et bande orange ; AILERONS : dérive
dorsale et plans latéraux à bout orange ; socle de tôles de titane ; à l'arrière droit la TUYÈRE verticale à volets,
bague ORANGE et lueur bleu-blanc (la fumée).
Palette 60/30/10 (ages.PALETTE[11]) : bleu titane / alliage pâle et bleu nuit / orange aéronautique.
"""
import math

from mathutils import Matrix

import ages
import corps
from kit import TAU
from repere import Y

EPOQUE = 11
NOM = ages.NOMS[11]
TRIPLET = ("nacelle à réacteur", "ailerons", "tuyère orange")
FOYER = ages.FOYER[11]
HABILLAGE = dict(ages.CORPS[11], foyer="titane_dk")
Z_SOCLE = 0.5
# ronde 1 : tournée de 20°, l'entrée d'air restait vue par la tranche (la nacelle se lisait « citerne ») : 50°
CX, CYN, CZ, RN, TH = -0.3, 0.2, 1.78, 0.8, math.radians(50.0)


def matieres(metal, M):
    ages.matieres(11, metal, M)


def monde(lx, lz=0.0, ly=0.0):
    """Point du repère de la nacelle (x le long de l'axe) vers Blender."""
    c, s = math.cos(TH), math.sin(TH)
    return corps.V((CX + lx * c - ly * s, Y(CYN) + lx * s + ly * c, CZ + lz))


def plaque(g, pts, ep, m, what="aileron"):
    """Plaque épaisse ep le long de la normale du polygone plan pts (4 points, repère courant)."""
    q = [corps.V(p) for p in pts]
    n = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
    g.hexa([p - n * ep / 2 for p in q] + [p + n * ep / 2 for p in q], m, "hard", what)


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    corps.boite(g, -2.3, 2.3, -1.85, 2.35, zs, Z_SOCLE, [M["tole_ti"], M["tole_ti2"], M["titane_md"]],
                ins=(0.03, 0.03, 0.03), panel=0.5, faces="ts")
    g.box((0, Y(-1.85) - 0.005, Z_SOCLE - 0.04), (4.6, 0.03, 0.06), M["bleu_nuit"], "hard", what="liseré")
    for sx in (-1, 1):
        for k in range(3):
            g.box((sx * (2.0 - 0.12 * k), Y(-1.85) - 0.012, zs + 0.2), (0.06, 0.02, 0.22), M["orange_aero"], "hard",
                  R=Matrix.Rotation(sx * 0.6, 3, "Y"), what="chevron")
    # pylônes
    for lx in (-0.95, 0.45):
        p = monde(lx)
        h = CZ - RN + 0.08 - Z_SOCLE
        g.box((p.x, p.y, Z_SOCLE + h / 2), (0.6, 0.16, h), M["titane_dk"], "hard", R=Matrix.Rotation(TH, 3, "Z"),
              what="pylone")
        g.box((p.x, p.y, Z_SOCLE + 0.04), (0.75, 0.3, 0.08), M["bleu_nuit"], "hard", R=Matrix.Rotation(TH, 3, "Z"),
              what="semelle")
    nacelle(g, c)


def nacelle(g, c):
    M = g.M
    g.push((CX, Y(CYN), CZ), rz=TH)
    x0, x1, x2 = -1.62, 0.8, 1.55
    g.cyl(((x0 + x1) / 2, 0, 0), "x", RN, x1 - x0, M["titane_cl"], n=44, what="nacelle")
    for x, m, w in ((-1.2, "bleu_nuit", 0.06), (-0.65, "orange_aero", 0.09), (-0.15, "bleu_nuit", 0.06),
                    (0.55, "bleu_nuit", 0.06)):
        g.tube_shell((x, 0, 0), "x", RN + 0.018, RN - 0.02, w, M[m], n=44, what="bande")
    for a in (-0.9, -0.3, 0.3):
        nrm = corps.V((0, math.sin(a), math.cos(a)))
        for k in range(16):
            x = x0 + 0.1 + (x1 - x0 - 0.2) * (k + 0.5) / 16
            g.dome(corps.V((x, 0, 0)) + nrm * RN, nrm, 0.014, M["rivet_ti"])
    g.cyl(((x1 + x2) / 2, 0, 0), "x", RN, x2 - x1, M["titane_md"], n=44, r2=0.5, what="queue")
    g.cyl((x2 + 0.02, 0, 0), "x", 0.5, 0.05, M["titane_dk"], n=36, what="culot")
    # entrée d'air : lèvre, fond, aubes, cône orange
    g.cyl((x0 - 0.1, 0, 0), "x", RN + 0.12, 0.2, M["ring"], n=44, r2=RN, what="capot")
    g.torus((x0 - 0.2, 0, 0), "x", RN + 0.02, 0.11, M["ring"], n=44, m=8, what="levre")
    g.cyl((x0 - 0.12, 0, 0), "x", RN - 0.04, 0.02, M["void"], n=36, style="flat", what="fond")
    for k in range(18):
        a = TAU * k / 18
        d = corps.V((0, math.cos(a), math.sin(a)))
        g.box(corps.V((x0 - 0.15, 0, 0)) + d * 0.45, (0.02, 0.09, 0.56), M["titane_cl"], "hard",
              R=Matrix.Rotation(a, 3, "X") @ Matrix.Rotation(0.5, 3, "Z"), what="aube")
    g.cyl((x0 - 0.3, 0, 0), "x", 0.24, 0.36, M["orange_aero"], n=20, r2=0.02, what="cone")
    # ailerons : dérive dorsale, plans latéraux (bouts orange)
    plaque(g, [(0.05, 0, RN - 0.05), (1.25, 0, RN - 0.2), (1.38, 0, RN + 0.75), (0.85, 0, RN + 0.75)], 0.07,
           M["titane_dk"])
    plaque(g, [(0.85, 0, RN + 0.72), (1.38, 0, RN + 0.72), (1.38, 0, RN + 0.84), (0.85, 0, RN + 0.84)], 0.08,
           M["orange_aero"], "bout")
    for sy in (-1, 1):
        plaque(g, [(0.2, sy * (RN - 0.05), -0.05), (1.3, sy * (RN - 0.05), -0.15), (1.42, sy * (RN + 0.6), -0.15),
                   (0.95, sy * (RN + 0.6), -0.1)], 0.06, M["titane_dk"])
        plaque(g, [(0.95, sy * (RN + 0.55), -0.1), (1.42, sy * (RN + 0.55), -0.15), (1.42, sy * (RN + 0.66), -0.15),
                   (0.95, sy * (RN + 0.66), -0.1)], 0.07, M["orange_aero"], "bout")
    g.pop()
    g.halo(tuple(monde(-1.9, 0.0, -0.4)), M["_emit_rgb"], 4.0)


def socle(g, c):
    """Ronde 2 (richesse : le pont de titane était nu) : groupe hydraulique à l'avant droit, râtelier de bouteilles
    d'argon à l'arrière droit (procédé Kroll), caisses à l'arrière gauche, feux de piste au bord avant."""
    M = g.M
    z = Z_SOCLE
    corps.boite(g, 1.0, 2.05, -1.6, -0.95, z, z + 0.42, [M["titane_md"], M["tole_ti2"]], panel=0.3, faces="ts")
    for x in (1.25, 1.75):
        g.tube_shell((x, Y(-1.28), z + 0.46), "z", 0.17, 0.13, 0.06, M["titane_dk"], n=20, what="buse")
        g.cyl((x, Y(-1.28), z + 0.43), "z", 0.13, 0.02, M["void"], n=16, style="flat", what="fond")
        for k in range(5):
            a = TAU * k / 5
            g.box((x + 0.07 * math.cos(a), Y(-1.28) + 0.07 * math.sin(a), z + 0.44), (0.12, 0.03, 0.01),
                  M["titane_cl"], "hard", R=Matrix.Rotation(a, 3, "Z"), what="pale")
    g.box((1.52, Y(-1.6) - 0.012, z + 0.3), (0.9, 0.02, 0.05), M["orange_aero"], "hard", what="bande")
    g.pipe([(1.1, Y(-1.0), z + 0.2), (0.7, Y(-0.6), z + 0.15), (tuple(monde(0.45))[0], tuple(monde(0.45))[1],
                                                                  z + 0.12)], 0.045, M["bleu_nuit"],
           fl_mat=M["orange_aero"])
    for i in range(2):
        for k in range(3):
            x, yn = 1.45 + 0.24 * k, 1.75 + 0.3 * i
            g.cyl((x, Y(yn), z + 0.3), "z", 0.09, 0.6, M["titane_dk"], n=14, what="bouteille")
            g.cyl((x, Y(yn), z + 0.64), "z", 0.06, 0.08, M["orange_aero"], n=12, what="robinet")
    g.box((1.69, Y(1.62), z + 0.45), (0.8, 0.04, 0.05), M["bleu_nuit"], "hard", what="sangle")
    for (x, yn, h) in ((-1.95, 1.9, 0.3), (-1.55, 1.95, 0.24), (-1.75, 1.55, 0.2)):
        corps.boite(g, x - 0.17, x + 0.17, yn - 0.15, yn + 0.15, z, z + h, [M["tole_ti"], M["titane_cl"]], panel=0.2,
                    faces="ts")
    for k in range(10):
        x = -2.15 + 4.3 * k / 9
        if abs(x) < 0.85:
            continue
        g.dome((x, Y(-1.85) + 0.05, z + 0.005), (0, 0, 1), 0.03, M["emit"], n=8, what="feu")


def fumee(g, c):
    """Tuyère verticale à volets, bague orange, lueur bleu-blanc."""
    M = g.M
    p = monde(1.2, 0.0, 0.0)
    x, yn = p.x, p.y / Y(1.0)
    zs_ = [CZ + 0.3, 2.65, 3.05, 3.45, 3.8]
    rs = [0.34, 0.27, 0.24, 0.3, 0.37]
    corps.tube_v(g, x, yn, rs, zs_, M["titane_md"], n=32, caps=False, what="tuyere")
    for k in range(14):
        a = TAU * k / 14
        g.box((x + 0.33 * math.cos(a), p.y + 0.33 * math.sin(a), 3.6), (0.1, 0.02, 0.36), M["titane_dk"], "hard",
              R=Matrix.Rotation(a + math.pi / 2, 3, "Z") @ Matrix.Rotation(0.18, 3, "X"), what="volet")
    g.torus((x, p.y, 3.3), "z", 0.3, 0.04, M["orange_aero"], n=32, m=6, what="bague")
    g.torus((x, p.y, 3.79), "z", 0.37, 0.035, M["orange_aero"], n=32, m=6, what="levre")
    g.torus((x, p.y, 3.62), "z", 0.27, 0.03, M["emit"], n=28, m=5, what="lueur")
    corps.bouche_fumee(g, c, x, yn, 3.8, 0.34, levre=False)
    g.cyl((x, p.y, 3.4), "z", 0.25, 0.02, M["emit_soft"] if "emit_soft" in M else M["emit"], n=24, style="flat",
          what="flamme")


def piece(g, c):
    """Lingots d'éponge de titane en piles croisées, sangles orange."""
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        for dx in (-0.36, 0.36):
            x, y = p["x"] + dx, Y(p["yn"])
            for i in range(4):
                for k in range(3):
                    if i % 2 == 0:
                        g.box((x, y - 0.18 + 0.18 * k, zs + 0.05 + 0.1 * i), (0.5, 0.15, 0.09),
                              M["tole_ti" if (i + k) % 2 else "titane_cl"], "soft", what="lingot")
                    else:
                        g.box((x - 0.17 + 0.17 * k, y, zs + 0.05 + 0.1 * i), (0.15, 0.52, 0.09),
                              M["titane_md" if k % 2 else "tole_ti2"], "soft", what="lingot")
            for sy in (-0.12, 0.12):
                g.box((x, y + sy, zs + 0.21), (0.54, 0.03, 0.43), M["orange_aero"], "hard", what="sangle")
