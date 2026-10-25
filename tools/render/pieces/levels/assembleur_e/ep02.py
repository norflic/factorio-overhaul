"""Assembleur · Âge 2 · Forge (ère I, 3×3, niveaux 3 et 4). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 2. Dans Blender.

En 3 mots : « martinet, enclume, toit de briques ». L'outil est un MARTINET (marteau-pilon à bascule) : manche de chêne
cerclé de fer sur un chevalet posé sur la joue ouest, tête de fer forgé levée au-dessus de l'ENCLUME, roue à cames qui
le soulève. Le dos est une FORGE de briques à toit de tuiles de brique (deux pans), un FOYER rougeoyant sous sa hotte,
un soufflet de cuir, des outils pendus. Joues basses de fer martelé.
Palette 60/30/10 (ages.PALETTE[2]) : fer gris martelé / brique rouge / braise rouge.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2

V = Vector

EPOQUE = 2
NOM = ages.NOMS[2]
TRIPLET = ("martinet", "enclume", "toit de briques")
FOYER = ages.FOYER[2]
TRAVAIL = dict(couches=2, images=16, organe="manche et tête du martinet (bascule de 14°), roue à cames qui tourne ; "
                                           "étincelles et braise du lopin (couche glow)")
HABILLAGE = dict(ages.CORPS[2], forme_embase='carre', forme_dos='pans', forme_joues='basses', forme_portique='aucun',
                 mat_dos='brique', mat_joues='fer_martele', mat_table='fer_noir')
ANGLE = -0.14     # bascule du manche (tête levée)


def matieres(metal, M):
    ages.matieres(2, metal, M)
    metal("chene", (0.17, 0.095, 0.045), rough=0.75, met=0.0, grain=0.5, gscale=18.0, dirt=0.9, stain=0.8, wear=1.0,
          streak=0.5)


def socle(g, c):
    """Briques sur la face du dos, foyer sous hotte, soufflet, outils pendus, tas de charbon, seau."""
    M = g.M
    h, yb, ze = c.h, c.yb, c.zs          # troisième jet : le pied de la face est caché par le plateau de baie
    zw = c.zw_pans
    q = [B(-h + 0.02, yb - 0.03, ze), B(h - 0.02, yb - 0.03, ze), B(h - 0.02, yb - 0.03, zw),
         B(-h + 0.02, yb - 0.03, zw)]
    F.courses(g, q, [M["brique"], M["brique_pave"], M["brique_pave2"]], bw=0.14, bh=0.065, t=0.018)
    # foyer : sole de briques, braises, hotte de fer à cerclages
    xf = 0.42
    g.box(B(xf, yb - 0.18, ze + 0.08), (0.5, 0.3 * SQ2, 0.16), M["brique"], "hard", what="sole")
    for k in range(9):
        F.lump(g, B(xf - 0.18 + 0.045 * k, yb - 0.3 + 0.04 * (k % 3), ze + 0.17), 0.05, M["emit"] if k % 3 else
               M["braise_sombre"] if "braise_sombre" in M else M["soot"])
    zh0, zh1 = ze + 0.5, zw + 0.3      # ronde 3 : hotte plus haute (elle cachait les braises : 0 foyer mesuré)
    g.hexa([B(xf - 0.27, yb - 0.36, zh0), B(xf + 0.27, yb - 0.36, zh0), B(xf + 0.27, yb - 0.02, zh0),
            B(xf - 0.27, yb - 0.02, zh0), B(xf - 0.1, yb - 0.1, zh1), B(xf + 0.1, yb - 0.1, zh1),
            B(xf + 0.1, yb + 0.12, zh1), B(xf - 0.1, yb + 0.12, zh1)], M["fer_noir"], "hard", "hotte")
    g.box(B(xf, yb + 0.01, zh1 + 0.1), (0.24, 0.24 * SQ2, 0.2), M["brique"], "hard", what="conduit")
    g.box(B(xf, yb + 0.01, zh1 + 0.21), (0.3, 0.3 * SQ2, 0.03), M["fer_noir"], "hard", what="chapeau")
    for z in (zh0 + 0.02, zh0 + 0.08):
        g.box(B(xf, yb - 0.36, z), (0.55, 0.02, 0.025), M["fer_clair_f"], "hard", what="cerclage")
    halo(g, xf, yb - 0.25, ze + 0.2, 2.2)
    # soufflet de cuir à l'ouest du foyer
    xs = -0.4
    g.hexa([B(xs - 0.2, yb - 0.3, ze + 0.14), B(xs + 0.2, yb - 0.3, ze + 0.14), B(xs + 0.16, yb - 0.05, ze + 0.14),
            B(xs - 0.16, yb - 0.05, ze + 0.14), B(xs - 0.2, yb - 0.3, ze + 0.27), B(xs + 0.2, yb - 0.3, ze + 0.27),
            B(xs + 0.16, yb - 0.05, ze + 0.22), B(xs - 0.16, yb - 0.05, ze + 0.22)], M["leather"], "soft", "soufflet")
    g.box(B(xs, yb - 0.18, ze + 0.07), (0.36, 0.25 * SQ2, 0.14), M["chene"], "hard", what="caisse_soufflet")
    g.cyl(B(xs + 0.28, yb - 0.17, ze + 0.18), "x", 0.03, 0.4, M["fer_noir"], n=8, what="buse")
    # outils pendus sur la face (tenailles, tisonnier)
    for k, x in enumerate((-1.1, -0.95, 1.0, 1.15)):
        g.box(B(x, yb - 0.05, zw - 0.12), (0.025, 0.02, 0.2), M["fer_noir"], "hard",
              R=Matrix.Rotation(0.12 * (1 if k % 2 else -1), 3, "Y"), what="outil_pendu")
        g.dome(B(x, yb - 0.04, zw - 0.05), (0, -1, 0), 0.018, M["fer_clair_f"])
    # tas de charbon et seau de trempe dans la baie
    for k in range(7):
        F.lump(g, B(-0.55 + 0.06 * (k % 4), -0.95 + 0.07 * (k // 4), ze), 0.06, M["soot"])
    F.stave_barrel(g, tuple(B(0.58, -1.0, ze)), 0.11, 0.2, M["chene"], M["fer_noir"], open_top=M["glass_dk"])
    # pignons de briques (faces est et ouest vues par la tranche) : rien ; corniche de fer sur l'égout du toit
    g.box(B(0, yb - 0.06, zw - 0.02), (2 * h + 0.1, 0.05, 0.05), M["fer_noir"], "hard", what="egout")


def outil(g, c):
    """Martinet : chevalet de chêne sur la joue ouest, manche cerclé, tête de fer levée, roue à cames."""
    M = g.M
    yt, zj = c.yt, c.z_joue
    x0 = -c.xm + 0.12
    zpiv = c.zp - 0.38
    for sy in (-1, 1):
        g.box(B(x0, yt + sy * 0.1, (zj + zpiv) / 2 + 0.03), (0.09, 0.07 * SQ2, zpiv - zj + 0.06), M["chene"], "hard",
              what="chevalet")
        g.box(B(x0 + 0.1, yt + sy * 0.1, zj + 0.12), (0.03, 0.04, 0.3), M["chene"], "hard",
              R=Matrix.Rotation(0.6, 3, "Y"), what="jambe_force")
    g.cyl(B(x0, yt, zpiv), "y", 0.035, 0.32, M["fer_noir"], n=10, what="axe")
    d = V((math.cos(ANGLE), 0.0, -math.sin(ANGLE)))
    P0 = B(x0, yt, zpiv)
    L = 1.25
    R = Matrix.Rotation(ANGLE, 3, "Y")
    g.box(P0 + d * (L / 2 - 0.2), (L, 0.08 * SQ2, 0.09), M["chene"], "hard", R=R, what="manche")
    for t in (0.0, 0.35, 0.7, 0.95):
        g.box(P0 + d * (t - 0.05), (0.03, 0.1 * SQ2, 0.11), M["fer_noir"], "hard", R=R, what="frette")
    tete = P0 + d * (L - 0.26)
    g.box(tete + V((0, 0, -0.12)), (0.2, 0.17 * SQ2, 0.22), M["fer_noir"], "hard", what="tete_martinet")
    g.box(tete + V((0, 0, -0.25)), (0.16, 0.13 * SQ2, 0.05), M["fer_clair_f"], "hard", what="panne")
    # roue à cames (plan face au sud) en queue
    F.disc_wheel(g, B(x0 - 0.13, yt - 0.18, zj + 0.21), "y", 0.19, 0.05, M["fer_noir"], M["fer_martele"], spokes=5)
    for k in range(4):
        a = math.pi / 2 * k + 0.4
        g.box(B(x0 - 0.13 + 0.2 * math.cos(a), yt - 0.2, zj + 0.21 + 0.2 * math.sin(a)), (0.06, 0.05, 0.06),
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
    g.cyl(B(0.21, yt, z + 0.2), "x", 0.045, 0.14, M["fer_martele"], n=10, r2=0.006, what="bigorne")
    g.box(B(-0.02, yt, z + 0.25), (0.2, 0.08 * SQ2, 0.05), M["emit"], "soft", what="lopin")
    halo(g, 0.0, yt, z + 0.3, 0.8)
    g.box(B(-0.2, yt - 0.04, z + 0.25), (0.22, 0.02 * SQ2, 0.015), M["fer_noir"], "hard",
          R=Matrix.Rotation(0.15, 3, "Z"), what="pince")


def entree(g, c):
    """Coffre de chêne plein de charbon (entrée)."""
    M = g.M
    p = corps.place(c, "joue_O")
    r, z = p["r"], c.z_joue
    g.box(B(p["x"], p["yn"], z + 0.09), (2 * r, 2 * r * SQ2, 0.18), M["chene"], "hard", what="coffre")
    for k in range(10):
        F.lump(g, B(p["x"] - r * 0.6 + r * 0.4 * (k % 4), p["yn"] - r * 0.5 + r * 0.45 * (k // 4), z + 0.17), 0.05,
               M["soot"])
    for f in (-0.8, 0.8):
        g.box(B(p["x"], p["yn"] + f * r, z + 0.1), (2 * r + 0.02, 0.025, 0.2), M["fer_noir"], "hard", what="ferrure")


def piece(g, c):
    """Niveau 4 : râtelier de pinces et marteaux (coin avant gauche), tonneau de trempe et lingots (coin avant droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    x, yn = po["x"], po["yn"]
    for sx in (-1, 1):
        g.box(B(x + sx * 0.18, yn, z + 0.18), (0.04, 0.04 * SQ2, 0.36), M["chene"], "hard", what="montant")
    g.box(B(x, yn, z + 0.34), (0.42, 0.04 * SQ2, 0.04), M["chene"], "hard", what="traverse")
    # ronde 2 : dos de planches PLEIN derrière les outils (le cadre ouvert enfermait 95 px de sol)
    g.box(B(x, yn + 0.03, z + 0.19), (0.36, 0.02 * SQ2, 0.3), M["wood2"], "hard", what="dos_ratelier")
    for k in range(5):
        xx = x - 0.14 + 0.07 * k
        g.box(B(xx, yn - 0.03, z + 0.2), (0.018, 0.015, 0.26), M["fer_noir"], "hard",
              R=Matrix.Rotation(0.1 * (k - 2), 3, "Y"), what="pince")
        if k % 2:
            g.box(B(xx, yn - 0.04, z + 0.08), (0.06, 0.03, 0.04), M["fer_martele"], "hard", what="tete_marteau")
    g.box(B(x, yn, z + 0.02), (0.46, 0.2 * SQ2, 0.04), M["chene"], "hard", what="semelle")
    xe, ye = pe["x"], pe["yn"]
    F.stave_barrel(g, tuple(B(xe + 0.1, ye + 0.05, z)), 0.13, 0.26, M["chene"], M["fer_noir"], open_top=M["glass_dk"])
    for k in range(6):
        g.box(B(xe - 0.15 + 0.05 * (k % 3), ye - 0.12 + 0.03 * (k // 3), z + 0.03 + 0.05 * (k // 3)),
              (0.045, 0.14 * SQ2, 0.045), M["fer_martele"] if k % 2 else M["forgeplate"], "hard", what="lingot")
    g.box(B(xe - 0.1, ye - 0.12, z + 0.16), (0.12, 0.05 * SQ2, 0.03), M["emit"], "soft", what="lingot_chaud")
    halo(g, xe - 0.1, ye - 0.12, z + 0.25, 0.7)
