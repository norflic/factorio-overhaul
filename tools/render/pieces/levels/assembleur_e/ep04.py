"""Assembleur · Âge 4 · Pétrole (ère II, 4×4, niveaux 7 et 8). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 4. Dans Blender.

En 3 mots : « presse jaune, vérins, flexibles ». L'outil est une PRESSE HYDRAULIQUE : grand cadre de presse JAUNE posé
dans la baie (deux colonnes, chapeau), VÉRIN central chromé et deux vérins latéraux, FLEXIBLES noirs qui descendent du
groupe hydraulique accroché au dos. Dos NOIR (groupe moto-pompe, volants rouges, réservoir d'huile couché et fûts sur le
toit), joues jaunes, gyrophares orange aux coins du chapeau (lumière de l'âge : flamme orange).
Palette 60/30/10 (ages.PALETTE[4]) : jaune de signalisation / noir et tôle larmée / rouge des volants ; flamme orange.
"""
from mathutils import Matrix, Vector

import ages
import corps
import formes as F
import parts2 as P2
from corps import B, halo
from kit import SQ2

V = Vector

EPOQUE = 4
NOM = ages.NOMS[4]
TRIPLET = ("presse jaune", "vérins", "flexibles")
FOYER = ages.FOYER[4]
TRAVAIL = dict(couches=2, images=16, organe="tige du vérin central et plateau mobile (course de 0,3), vérins latéraux ; "
                                           "gyrophares qui tournent (couche glow, 8 images)")
HABILLAGE = dict(ages.CORPS[4], forme_embase='carre', forme_dos='plat', forme_joues='caisson', forme_portique='cadre',
                 mat_dos='noir_capot', mat_portique='jaune_capot')


def matieres(metal, M):
    ages.matieres(4, metal, M)


def _gyro(g, x, yn, z):
    M = g.M
    g.cyl(B(x, yn, z + 0.02), "z", 0.06, 0.04, M["noir_capot"], n=12, what="socle_gyro")
    g.cyl(B(x, yn, z + 0.08), "z", 0.045, 0.08, M["emit"], n=12, style="soft", what="gyrophare")
    halo(g, x, yn, z + 0.1, 0.9)


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.zs, c.Hd     # ze : dessus du plateau de baie (troisième jet)
    ym = (yb + h) / 2.0
    # groupe moto-pompe accroché à la face (est) et flexibles vers le chapeau de la presse
    g.box(B(0.62, yb - 0.16, ze + 0.15), (0.5, 0.26 * SQ2, 0.3), M["jaune_capot"], "hard", what="moteur")
    for k in range(6):
        g.box(B(0.42 + 0.08 * k, yb - 0.3, ze + 0.15), (0.025, 0.02, 0.26), M["noir_capot"], "hard", what="ailette")
    g.cyl(B(0.24, yb - 0.16, ze + 0.15), "x", 0.1, 0.22, M["galva_capot"], n=16, what="pompe")
    P2.handwheel(g, B(0.05, yb - 0.1, ze + 0.42), (0, -1, 0), 0.08, M, mat=M["redpaint"])
    P2.handwheel(g, B(-0.5, yb - 0.06, ze + 0.5), (0, -1, 0), 0.07, M, mat=M["redpaint"])
    P2.gauge(g, B(-0.75, yb - 0.04, ze + 0.5), (0, -1, 0), 0.06, M)
    P2.gauge(g, B(-0.3, yb - 0.04, ze + 0.5), (0, -1, 0), 0.06, M)
    # bande de danger au pied de la face, panneaux de tôle larmée
    q = [B(-h + 0.05, yb - 0.04, ze + 0.02), B(h - 0.05, yb - 0.04, ze + 0.02), B(h - 0.05, yb - 0.04, ze + 0.12),
         B(-h + 0.05, yb - 0.04, ze + 0.12)]
    g.hazard(q, 24, t=0.01)
    corps.face_s(g, -h + 0.1, h - 0.1, yb - 0.02, c.Hj + 0.03, Hd - 0.06, M["tole_larmee"], nu=6, nv=1)
    # réservoir d'huile couché et fûts sur le toit
    g.push((0.0, 0.0, Hd))       # parts2.tank pose ses berceaux depuis z = 0 : repère local au niveau du toit
    P2.tank(g, B(-0.6, ym, 0.22), 0.2, 1.1, (1, 0, 0), M, paint=M["galva_capot"], band=M["jaune_capot"])
    g.pop()
    for k, x in enumerate((0.55, 0.9, 1.25)):
        F.drum(g, tuple(B(x, ym + (0.12 if k % 2 else -0.08), Hd)), 0.13, 0.32,
               M["redpaint"] if k == 1 else M["yellowpaint"], M["noir_capot"])
    _gyro(g, -1.5, ym + 0.2, Hd)
    # pupitre de commande à deux mains devant la colonne ouest
    x0 = -c.xb * 0.92 - 0.05
    g.box(B(x0, c.yt - 0.55, ze + 0.25), (0.1, 0.08 * SQ2, 0.5), M["noir_capot"], "hard", what="pied_pupitre")
    g.box(B(x0, c.yt - 0.55, ze + 0.52), (0.26, 0.12 * SQ2, 0.06), M["jaune_capot"], "hard", what="pupitre")
    for sx in (-1, 1):
        g.cyl(B(x0 + sx * 0.07, c.yt - 0.56, ze + 0.56), "z", 0.025, 0.02, M["redpaint"], n=10, what="bouton")


def outil(g, c):
    """Vérin central chromé, plateau mobile, vérins latéraux, flexibles, gyrophares du chapeau."""
    M = g.M
    yt, zt, zp, bp = c.yt, c.zt, c.zp, c.bp
    top = zp + bp
    g.cyl(B(0, yt, top - 0.18), "z", 0.17, 0.36, M["jaune_capot"], n=24, what="corps_verin")
    g.tube_shell(B(0, yt, top - 0.34), "z", 0.19, 0.16, 0.04, M["noir_capot"], n=24, what="bague")
    g.cyl(B(0, yt, (top - 0.36 + zt + 0.32) / 2), "z", 0.08, top - 0.36 - zt - 0.32, M["steel_hi"], n=16,
          what="tige")
    g.box(B(0, yt, zt + 0.3), (2 * c.xb * 0.92 - 0.1, 0.36 * SQ2, 0.1), M["noir_capot"], "hard", what="plateau")
    g.hazard([B(-0.8, yt - 0.18 - 0.005, zt + 0.26), B(0.8, yt - 0.18 - 0.005, zt + 0.26),
              B(0.8, yt - 0.18 - 0.005, zt + 0.34), B(-0.8, yt - 0.18 - 0.005, zt + 0.34)], 16, t=0.006)
    for sx in (-1, 1):
        x = sx * 0.55
        g.cyl(B(x, yt, top - 0.14), "z", 0.08, 0.28, M["jaune_capot"], n=16, what="verin_lat")
        g.cyl(B(x, yt, (top - 0.28 + zt + 0.35) / 2), "z", 0.035, top - 0.28 - zt - 0.35, M["steel_hi"], n=10,
              what="tige_lat")
        _gyro(g, sx * (c.xb * 0.92 + 0.05), yt - 0.12, top + 0.24)
    # flexibles du groupe hydraulique vers le chapeau
    for k, dx in enumerate((-0.15, 0.0, 0.15)):
        g.hose([B(0.62 + dx, c.yb - 0.2, c.zs + 0.3), B(0.7 + dx, (c.yb + yt) / 2, top + 0.35),
                B(0.25 + dx, yt + 0.1, top + 0.2)], 0.028, M["rubber"], step=0.04)


def ouvrage(g, c):
    """Outillage de presse : semelle noire, 4 colonnettes, flan, pièces moulées rouges."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.box(B(0, yt, zt + 0.05), (0.62, 0.42 * SQ2, 0.1), M["noir_capot"], "hard", what="semelle")
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.cyl(B(sx * 0.25, yt + sy * 0.16, zt + 0.17), "z", 0.025, 0.16, M["steel_hi"], n=8, what="colonnette")
    g.box(B(0, yt, zt + 0.12), (0.34, 0.24 * SQ2, 0.03), M["galva_capot"], "hard", what="flan")
    for k in range(3):
        g.box(B(-0.42 + 0.12 * k, yt - 0.3, zt + 0.03), (0.09, 0.07 * SQ2, 0.05), M["redpaint"], "soft",
              what="piece_moulee")


def piece(g, c):
    """Niveau 8 : palette de trois fûts (coin avant gauche), jerricans et pompe à main (coin avant droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    g.box(B(po["x"], po["yn"], z + 0.04), (0.62, 0.44 * SQ2, 0.08), M["wood"], "hard", what="palette")
    for k, (dx, dy) in enumerate(((-0.15, 0.08), (0.15, 0.08), (0.0, -0.12))):
        F.drum(g, tuple(B(po["x"] + dx, po["yn"] + dy, z + 0.08)), 0.13, 0.34,
               M["redpaint"] if k == 2 else M["yellowpaint"], M["noir_capot"])
    for k in range(3):
        g.box(B(pe["x"] - 0.18 + 0.15 * k, pe["yn"] - 0.1, z + 0.12), (0.12, 0.07 * SQ2, 0.24),
              M["redpaint"] if k != 1 else M["jaune_capot"], "hard", what="jerrican")
        g.box(B(pe["x"] - 0.18 + 0.15 * k, pe["yn"] - 0.1, z + 0.26), (0.06, 0.04, 0.03), M["noir_capot"], "hard",
              what="poignee")
    g.cyl(B(pe["x"] + 0.15, pe["yn"] + 0.15, z + 0.2), "z", 0.04, 0.4, M["galva_capot"], n=10, what="pompe_main")
    g.box(B(pe["x"] + 0.15, pe["yn"] + 0.15, z + 0.42), (0.2, 0.03, 0.03), M["redpaint"], "hard",
          R=Matrix.Rotation(0.3, 3, "Y"), what="levier")
