"""Assembleur · Âge 2 · Forge (ère I, 3×3, niveaux 3 et 4). Lot F3-A, ronde F3-A2 ; fiche FICHES_ASSEMBLEUR.md, âge 2.
Dans Blender.

En 3 mots : « martinet, enclume, toit de briques ». Plan en L : la FORGE de briques occupe le nord (toit de tuiles de
brique à deux pans) et l'ouest (AILE haute de briques dont la face sud porte le FOYER rougeoyant sous sa hotte, le soufflet
de cuir accroché). À l'est, sur la joue basse, le chevalet de chêne du MARTINET : le manche cerclé de fer enjambe la baie
et sa tête de fer, levée, tombe sur l'ENCLUME. Roue à cames, tas de charbon, seau de trempe, outils pendus.
Ronde F3-A3 : le quart NORD-EST est du SOL (le L se lit), lanternes et braises (nuit), sortie au coin avant est du bâti.
Palette 60/30/10 (ages.PALETTE[2]) : fer gris martelé / brique rouge / braise rouge.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2, TAU

V = Vector

EPOQUE = 2
NOM = ages.NOMS[2]
TRIPLET = ("martinet", "enclume", "toit de briques")
FOYER = ages.FOYER[2]
TRAVAIL = dict(couches=2, images=16, organe="manche et tête du martinet (bascule de 14°), roue à cames qui tourne ; "
                                           "étincelles et braise du lopin, flamme du foyer (couche glow)")
HABILLAGE = dict(ages.CORPS[2], plan='L', forme_embase='carre', forme_dos='pans', forme_joues='basses',
                 forme_portique='aucun', mat_dos='brique', mat_joues='fer_martele', mat_table='fer_noir')
DENSITE = dict(p=0.65, lampes=0.06)     # ronde F3-A3 : nuit trop sombre (voyants = braises et lanternes)
ANGLE = 0.14     # bascule du manche (tête levée, vers l'ouest)


def matieres(metal, M):
    ages.matieres(2, metal, M)
    metal("chene", (0.17, 0.095, 0.045), rough=0.75, met=0.0, grain=0.5, gscale=18.0, dirt=0.9, stain=0.8, wear=1.0,
          streak=0.5)


def _briques(g, x0, x1, yn, z0, z1):
    M = g.M
    q = [B(x0, yn - 0.03, z0), B(x1, yn - 0.03, z0), B(x1, yn - 0.03, z1), B(x0, yn - 0.03, z1)]
    F.courses(g, q, [M["brique"], M["brique_pave"], M["brique_pave2"]], bw=0.14, bh=0.065, t=0.018)


def socle(g, c):
    """Briques des faces, foyer dans l'aile ouest, soufflet, outils pendus, charbon, seau."""
    M = g.M
    h, yb, zs = c.h, c.yb, c.zs
    zw = c.zw_pans
    _briques(g, -c.xb, c.dos_ext[1], yb, zs, zw)      # ronde F3-A3 : le dos s'arrête au coin vide (nord-est)
    # lanternes pendues à la face du dos et braises au chapeau du conduit (nuit)
    for x in (-0.66, -0.42):
        g.box(B(x, yb - 0.08, zw - 0.05), (0.02, 0.1, 0.02), M["fer_noir"], "hard", what="potence")
        g.box(B(x, yb - 0.13, zw - 0.14), (0.08, 0.08 * SQ2, 0.11), M["fer_noir"], "hard", what="lanterne")
        g.box(B(x, yb - 0.13, zw - 0.14), (0.06, 0.09 * SQ2, 0.08), M["emit"], "soft", what="flamme_lanterne")
        halo(g, x, yb - 0.25, zw - 0.15, 1.1)       # F3-B : nuit de l'âge 2 plus claire
    # face sud de l'AILE : briques, FOYER voûté rougeoyant, hotte de fer, soufflet
    xa, xz, yf = -h + 0.02, -c.xb, c.yf
    _briques(g, xa, xz, yf, c.ze + 0.05, c.z_aile - 0.03)
    xf = (xa + xz) / 2.0
    zf0, zf1 = c.ze + 0.12, c.ze + 0.48
    g.box(B(xf, yf - 0.06, (zf0 + zf1) / 2), (0.42, 0.05, zf1 - zf0), M["brique"], "hard", what="encadrement")
    g.box(B(xf, yf - 0.09, (zf0 + zf1) / 2 - 0.02), (0.3, 0.03, zf1 - zf0 - 0.1), M["soot"], "flat", what="bouche")
    for k in range(8):
        F.lump(g, B(xf - 0.12 + 0.034 * k, yf - 0.12, zf0 + 0.03 + 0.02 * (k % 2)), 0.045,
               M["emit"] if k % 3 else M["forgeplate"])
    g.cyl(B(xf, yf - 0.06, zf1 + 0.02), "y", 0.2, 0.06, M["brique_pave2"], n=16, what="voute_foyer")
    g.hexa([B(xf - 0.25, yf - 0.32, zf1 + 0.08), B(xf + 0.25, yf - 0.32, zf1 + 0.08), B(xf + 0.25, yf - 0.02, zf1 + 0.08),
            B(xf - 0.25, yf - 0.02, zf1 + 0.08), B(xf - 0.1, yf - 0.12, c.z_aile - 0.08), B(xf + 0.1, yf - 0.12, c.z_aile - 0.08),
            B(xf + 0.1, yf - 0.02, c.z_aile - 0.08), B(xf - 0.1, yf - 0.02, c.z_aile - 0.08)], M["fer_noir"], "hard", "hotte")
    for z in (zf1 + 0.1, zf1 + 0.16):
        g.box(B(xf, yf - 0.32, z), (0.52, 0.02, 0.025), M["fer_clair_f"], "hard", what="cerclage")
    halo(g, xf, yf - 0.25, zf0 + 0.15, 3.4)          # F3-B : nuit de l'âge 2 plus claire
    c.reserves.append((xf, yf - 0.2, 0.3))
    # conduit de briques sur l'aile (sortie de la hotte)
    g.box(B(xf, (yf + yb) / 2, c.z_aile + 0.12), (0.24, 0.24 * SQ2, 0.24), M["brique"], "hard", what="conduit")
    g.box(B(xf, (yf + yb) / 2, c.z_aile + 0.25), (0.3, 0.3 * SQ2, 0.03), M["fer_noir"], "hard", what="chapeau")
    g.box(B(xf, (yf + yb) / 2 - 0.125, c.z_aile + 0.17), (0.14, 0.012, 0.06), M["emit"], "flat", what="braise_conduit")
    halo(g, xf, (yf + yb) / 2 - 0.2, c.z_aile + 0.2, 0.6)
    c.reserves.append((xf, (yf + yb) / 2, 0.22))
    # soufflet de cuir sur le bâti, contre l'aile
    xs, ys = -c.xb + 0.22, c.yt + 0.25
    g.box(B(xs, ys, zs + 0.06), (0.32, 0.22 * SQ2, 0.12), M["chene"], "hard", what="caisse_soufflet")
    g.hexa([B(xs - 0.17, ys - 0.12, zs + 0.12), B(xs + 0.17, ys - 0.12, zs + 0.12), B(xs + 0.14, ys + 0.1, zs + 0.12),
            B(xs - 0.14, ys + 0.1, zs + 0.12), B(xs - 0.17, ys - 0.12, zs + 0.24), B(xs + 0.17, ys - 0.12, zs + 0.24),
            B(xs + 0.14, ys + 0.1, zs + 0.2), B(xs - 0.14, ys + 0.1, zs + 0.2)], M["leather"], "soft", "soufflet")
    g.cyl(B(xs - 0.2, ys - 0.05, zs + 0.16), "x", 0.03, 0.18, M["fer_noir"], n=8, what="buse")
    c.reserves.append((xs, ys, 0.22))
    # outils pendus sur la face du dos
    for k, x in enumerate((-0.25, -0.14, -0.03, 0.07)):       # F3-B : le dos s'arrête en x = 0,15
        g.box(B(x, yb - 0.05, zw - 0.15), (0.025, 0.02, 0.22), M["fer_noir"], "hard",
              R=Matrix.Rotation(0.12 * (1 if k % 2 else -1), 3, "Y"), what="outil_pendu")
        g.dome(B(x, yb - 0.04, zw - 0.03), (0, -1, 0), 0.018, M["fer_clair_f"])
    # tas de charbon et seau de trempe sur le bâti
    for k in range(7):
        F.lump(g, B(-0.5 + 0.06 * (k % 4), -1.05 + 0.07 * (k // 4), zs), 0.06, M["emit"] if k in (2, 5) else M["soot"])
    halo(g, -0.42, -1.1, zs + 0.1, 0.4)
    F.stave_barrel(g, tuple(B(-0.02, -1.08, zs)), 0.11, 0.2, M["chene"], M["fer_noir"], open_top=M["glass_dk"])
    c.reserves += [(-0.4, -1.0, 0.2), (-0.02, -1.08, 0.16)]


def outil(g, c):
    """Martinet : chevalet de chêne sur la joue est, manche cerclé vers l'ouest, tête de fer levée, roue à cames."""
    M = g.M
    yt, zj = c.yt, c.z_joue
    x0 = c.xm - 0.12
    zpiv = c.zp - 0.38
    c.reserves.append((x0 + 0.05, yt - 0.05, 0.33))
    for sy in (-1, 1):
        g.box(B(x0, yt + sy * 0.1, (zj + zpiv) / 2 + 0.03), (0.09, 0.07 * SQ2, zpiv - zj + 0.06), M["chene"], "hard",
              what="chevalet")
        g.box(B(x0 - 0.1, yt + sy * 0.1, zj + 0.12), (0.03, 0.04, 0.3), M["chene"], "hard",
              R=Matrix.Rotation(-0.6, 3, "Y"), what="jambe_force")
    g.cyl(B(x0, yt, zpiv), "y", 0.035, 0.32, M["fer_noir"], n=10, what="axe")
    d = V((-math.cos(ANGLE), 0.0, math.sin(ANGLE)))
    P0 = B(x0, yt, zpiv)
    L = 1.2
    R = Matrix.Rotation(ANGLE, 3, "Y")
    g.box(P0 + d * (L / 2 - 0.2), (L, 0.08 * SQ2, 0.09), M["chene"], "hard", R=R, what="manche")
    for t in (0.0, 0.35, 0.7, 0.92):
        g.box(P0 + d * (t - 0.05), (0.03, 0.1 * SQ2, 0.11), M["fer_noir"], "hard", R=R, what="frette")
    tete = P0 + d * (L - 0.26)
    g.box(tete + V((0, 0, -0.12)), (0.2, 0.17 * SQ2, 0.22), M["fer_noir"], "hard", what="tete_martinet")
    g.box(tete + V((0, 0, -0.25)), (0.16, 0.13 * SQ2, 0.05), M["fer_clair_f"], "hard", what="panne")
    F.disc_wheel(g, B(x0 + 0.14, yt - 0.18, zj + 0.21), "y", 0.19, 0.05, M["fer_noir"], M["fer_martele"], spokes=5)
    for k in range(4):
        a = math.pi / 2 * k + 0.4
        g.box(B(x0 + 0.14 + 0.2 * math.cos(a), yt - 0.2, zj + 0.21 + 0.2 * math.sin(a)), (0.06, 0.05, 0.06),
              M["fer_clair_f"], "hard", what="came")


def ouvrage(g, c):
    """Enclume sur billot, lopin rougeoyant, pince posée."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.cyl(B(0.02, yt, zt + 0.06), "z", 0.17, 0.12, M["chene"], n=14, what="billot")
    z = zt + 0.12
    g.box(B(0.02, yt, z + 0.05), (0.2, 0.12 * SQ2, 0.1), M["fer_noir"], "hard", what="pied_enclume")
    g.box(B(0.02, yt, z + 0.13), (0.12, 0.08 * SQ2, 0.06), M["fer_noir"], "hard", what="taille")
    g.box(B(0.0, yt, z + 0.19), (0.3, 0.13 * SQ2, 0.07), M["fer_martele"], "hard", what="table_enclume")
    g.cyl(B(-0.21, yt, z + 0.2), "x", 0.045, 0.14, M["fer_martele"], n=10, r2=0.006, what="bigorne")
    g.box(B(-0.02, yt, z + 0.25), (0.2, 0.08 * SQ2, 0.05), M["emit"], "soft", what="lopin")
    halo(g, 0.0, yt, z + 0.3, 0.8)
    g.box(B(0.2, yt - 0.04, z + 0.25), (0.22, 0.02 * SQ2, 0.015), M["fer_noir"], "hard",
          R=Matrix.Rotation(-0.15, 3, "Z"), what="pince")


def entree(g, c, p):
    """Coffre de chêne plein de charbon, sur l'aile (entrée)."""
    M = g.M
    r, z = p["r"], p["z"]
    g.box(B(p["x"], p["yn"], z + 0.09), (2 * r, 2 * r * SQ2, 0.18), M["chene"], "hard", what="coffre")
    for k in range(10):
        F.lump(g, B(p["x"] - r * 0.6 + r * 0.4 * (k % 4), p["yn"] - r * 0.5 + r * 0.45 * (k // 4), z + 0.17), 0.05,
               M["soot"])
    for f in (-0.8, 0.8):
        g.box(B(p["x"], p["yn"] + f * r, z + 0.1), (2 * r + 0.02, 0.025, 0.2), M["fer_noir"], "hard", what="ferrure")


def sortie(g, c, p):
    """Caisse de chêne cerclée de fer, fers à cheval et clous forgés (sortie)."""
    M = g.M
    corps.bac(g, c, p, M["chene"], M["fer_clair_f"], forme="lingot")
    for k in range(3):
        # F3-B (nuit) : un fer encore rouge, sorti de la forge
        g.torus(B(p["x"] - 0.1 + 0.1 * k, p["yn"] + 0.05, p["z"] + 0.16), "z", 0.04, 0.01,
                M["emit"] if k == 1 else M["fer_noir"], n=12, m=4, what="fer_a_cheval")
    halo(g, p["x"], p["yn"], p["z"] + 0.25, 0.5)


def piece(g, c):
    """Niveau 4 (plus grande) : râtelier haut de pinces et marteaux (coin avant gauche) ; seconde enclume sur billot,
    lopin chaud et tonneau de trempe (coin avant droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    x, yn = po["x"], po["yn"]
    # ronde F3-A3 (niveau pair peu visible) : râtelier HAUT (0,8) chargé, et brasero rougeoyant sur trépied
    Hr = 0.8
    for sx in (-1, 1):
        g.box(B(x + sx * 0.24, yn, z + Hr / 2), (0.06, 0.06 * SQ2, Hr), M["chene"], "hard", what="montant")
    for zz in (Hr - 0.03, Hr * 0.55):
        g.box(B(x, yn, z + zz), (0.56, 0.06 * SQ2, 0.06), M["chene"], "hard", what="traverse")
    g.box(B(x, yn + 0.03, z + Hr / 2 + 0.02), (0.48, 0.02 * SQ2, Hr - 0.1), M["wood2"], "hard", what="dos_ratelier")
    for k in range(7):
        xx = x - 0.2 + 0.066 * k
        g.box(B(xx, yn - 0.03, z + Hr * 0.5), (0.025, 0.015, Hr * 0.7), M["fer_noir"], "hard",
              R=Matrix.Rotation(0.08 * (k - 3), 3, "Y"), what="pince")
        if k % 2:
            g.box(B(xx, yn - 0.045, z + 0.14), (0.09, 0.04, 0.07), M["fer_martele"], "hard", what="tete_marteau")
    g.box(B(x, yn, z + 0.02), (0.6, 0.26 * SQ2, 0.04), M["chene"], "hard", what="semelle")
    xe, ye = pe["x"], pe["yn"]
    for k in range(3):
        a = TAU * k / 3 + 0.5
        g.box(B(xe + 0.16 * math.cos(a), ye + 0.16 * math.sin(a), z + 0.2), (0.035, 0.035 * SQ2, 0.4), M["fer_noir"],
              "hard", what="pied_brasero")
    g.cyl(B(xe, ye, z + 0.44), "z", 0.19, 0.1, M["fer_noir"], n=18, r2=0.25, style="hard", what="vasque")
    for k in range(9):
        F.lump(g, B(xe - 0.12 + 0.06 * (k % 5), ye - 0.06 + 0.1 * (k // 5), z + 0.5), 0.06,
               M["emit"] if k % 2 else M["forgeplate"])
    halo(g, xe, ye, z + 0.6, 1.2)
    g.box(B(xe - 0.05, ye - 0.05, z + 0.62), (0.3, 0.025 * SQ2, 0.02), M["fer_noir"], "hard",
          R=Matrix.Rotation(0.4, 3, "Z"), what="tisonnier")
