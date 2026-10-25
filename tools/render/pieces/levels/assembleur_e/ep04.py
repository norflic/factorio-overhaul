"""Assembleur · Âge 4 · Pétrole (ère II, 4×4, niveaux 7 et 8). Lot F3-A, ronde F3-A2 ; fiche FICHES_ASSEMBLEUR.md, âge 4.
Dans Blender.

En 3 mots : « presse jaune, vérins, flexibles ». Plan en PORTIQUE : la machine EST la presse : deux colonnes-pylônes
JAUNES à croisillons noirs, un chapeau-caisson jaune riveté, et sous lui le VÉRIN central chromé et deux vérins latéraux
qui poussent le plateau sur l'outillage. Les FLEXIBLES noirs descendent du chapeau au groupe hydraulique posé sur le dos
bas (moto-pompe, volants rouges, réservoir d'huile couché, fûts). Gyrophares orange sur le chapeau et la cabine.
Ronde F3-A3 : plan en U, la baie est le SOL (socle de presse posé dessus, entrée et sortie au sol devant lui) ;
projecteurs sous le pont et feux des semelles (nuit).
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
HABILLAGE = dict(ages.CORPS[4], plan='portique', forme_embase='carre', forme_dos='bas', forme_joues='socle',
                 forme_portique='aucun', mat_dos='noir_capot')
DENSITE = dict(p=0.65, lampes=0.12)     # ronde F3-A3 : nuit trop sombre


def matieres(metal, M):
    ages.matieres(4, metal, M)


def _gyro(g, x, yn, z):
    M = g.M
    g.cyl(B(x, yn, z + 0.02), "z", 0.06, 0.04, M["noir_capot"], n=12, what="socle_gyro")
    g.cyl(B(x, yn, z + 0.08), "z", 0.045, 0.08, M["emit"], n=12, style="soft", what="gyrophare")
    halo(g, x, yn, z + 0.1, 0.9)


def socle(g, c):
    """Groupe hydraulique sur le dos bas, réservoir d'huile, fûts, tôle larmée, bandes de danger des pylônes."""
    M = g.M
    h, yb, zb = c.h, c.yb, c.z_bas
    ym = (yb + h) / 2.0
    # moto-pompe et réservoir sur le dos bas
    g.box(B(0.55, ym, zb + 0.16), (0.55, 0.3 * SQ2, 0.32), M["jaune_capot"], "hard", what="moteur")
    for k in range(6):
        g.box(B(0.33 + 0.085 * k, ym - 0.16, zb + 0.16), (0.025, 0.02, 0.28), M["noir_capot"], "hard", what="ailette")
    g.cyl(B(0.12, ym, zb + 0.14), "x", 0.11, 0.25, M["galva_capot"], n=16, what="pompe")
    P2.handwheel(g, B(-0.1, ym - 0.17, zb + 0.3), (0, -1, 0.3), 0.08, M, mat=M["redpaint"])
    g.push((0.0, 0.0, zb))     # parts2.tank pose ses berceaux depuis z = 0 : repère local au niveau du dos
    P2.tank(g, B(-0.85, ym, 0.24), 0.21, 1.0, (1, 0, 0), M, paint=M["galva_capot"], band=M["jaune_capot"],
            window=M["emit_soft"])
    g.pop()
    for k, x in enumerate((1.25, 1.55)):
        F.drum(g, tuple(B(x, ym + (0.1 if k else -0.08), zb)), 0.13, 0.32, M["redpaint"] if k else M["yellowpaint"],
               M["noir_capot"])
    c.reserves += [(0.45, ym, 0.45), (-0.85, ym, 0.6), (1.4, ym, 0.3)]
    # face du dos bas : tôle larmée et bande de danger
    corps.face_s(g, -h + 0.1, h - 0.1, yb - 0.02, c.zs + 0.02, zb - 0.02, M["tole_larmee"], nu=6, nv=1)
    g.hazard([B(-h + 0.1, yb - 0.05, zb - 0.1), B(h - 0.1, yb - 0.05, zb - 0.1), B(h - 0.1, yb - 0.05, zb - 0.03),
              B(-h + 0.1, yb - 0.05, zb - 0.03)], 26, t=0.008)
    # bandes de danger sur les pieds des pylônes, gyrophares
    for sx in (-1, 1):
        x = sx * c.xp
        g.hazard([B(x - c.wp / 2 + 0.03, c.yt - c.dp / 2 - 0.035, c.ze + 0.15),
                  B(x + c.wp / 2 - 0.03, c.yt - c.dp / 2 - 0.035, c.ze + 0.15),
                  B(x + c.wp / 2 - 0.03, c.yt - c.dp / 2 - 0.035, c.ze + 0.32),
                  B(x - c.wp / 2 + 0.03, c.yt - c.dp / 2 - 0.035, c.ze + 0.32)], 6, t=0.006)
        _gyro(g, x, c.yt, c.ztop)
    # pupitre à deux mains devant le pylône ouest (ronde F3-A3 : la baie est le SOL ; pupitre debout, voyants)
    x0, y0p, zp0 = -c.xb + 0.13, c.yt - 0.55, 0.0
    g.box(B(x0, y0p, zp0 + 0.03), (0.3, 0.24 * SQ2, 0.06), M["noir_capot"], "hard", what="semelle_pupitre")
    g.box(B(x0, y0p, zp0 + 0.45), (0.1, 0.08 * SQ2, 0.84), M["noir_capot"], "hard", what="pied_pupitre")
    g.box(B(x0, y0p, zp0 + 0.9), (0.26, 0.14 * SQ2, 0.08), M["jaune_capot"], "hard", what="pupitre")
    for sx in (-1, 1):
        g.cyl(B(x0 + sx * 0.07, y0p - 0.02, zp0 + 0.95), "z", 0.025, 0.02, M["redpaint"], n=10, what="bouton")
    corps.lampe(g, B(x0, y0p + 0.04, zp0 + 0.94), 0.022, M["emit"])
    c.reserves.append((x0, y0p, 0.18))
    # projecteurs sous le pont, tournés vers la baie (nuit) ; feux des semelles
    for sx in (-1, 1):
        p = B(sx * 0.88, c.yt - 0.1, c.zp - 0.02)
        g.cyl(p, "z", 0.08, 0.06, M["noir_capot"], n=14, what="projecteur")
        g.cyl(p - V((0, 0, 0.035)), "z", 0.065, 0.012, M["emit"], n=14, style="flat", what="verre_projecteur")
        halo(g, sx * 0.88, c.yt - 0.1, c.zt + 0.4, 1.0)
        for yy in (c.yf + 0.15, c.yb - 0.15):
            corps.lampe(g, B(sx * (c.h - 0.12), yy, c.z_joue), 0.035, M["emit"], cage=M["noir_capot"])


def outil(g, c):
    """Vérin central chromé sous le chapeau, plateau, vérins latéraux, flexibles vers le groupe hydraulique."""
    M = g.M
    yt, zt, zp = c.yt, c.zt, c.zp
    g.cyl(B(0, yt, zp - 0.2), "z", 0.19, 0.4, M["jaune_capot"], n=24, what="corps_verin")
    g.tube_shell(B(0, yt, zp - 0.38), "z", 0.21, 0.18, 0.05, M["noir_capot"], n=24, what="bague")
    g.cyl(B(0, yt, (zp - 0.4 + zt + 0.34) / 2), "z", 0.085, zp - 0.4 - zt - 0.34, M["steel_hi"], n=16, what="tige")
    g.box(B(0, yt, zt + 0.32), (2 * c.xb - 0.2, 0.4 * SQ2, 0.1), M["noir_capot"], "hard", what="plateau")
    g.hazard([B(-0.9, yt - 0.2 - 0.005, zt + 0.28), B(0.9, yt - 0.2 - 0.005, zt + 0.28), B(0.9, yt - 0.2 - 0.005, zt + 0.36),
              B(-0.9, yt - 0.2 - 0.005, zt + 0.36)], 16, t=0.006)
    for sx in (-1, 1):
        x = sx * 0.6
        g.cyl(B(x, yt, zp - 0.15), "z", 0.085, 0.3, M["jaune_capot"], n=16, what="verin_lat")
        g.cyl(B(x, yt, (zp - 0.3 + zt + 0.37) / 2), "z", 0.035, zp - 0.3 - zt - 0.37, M["steel_hi"], n=10,
              what="tige_lat")
        # glissières sur les faces intérieures des pylônes
        g.box(B(sx * (c.xp - c.wp / 2 - 0.03), yt, (zt + zp) / 2), (0.05, 0.12 * SQ2, zp - zt), M["noir_capot"],
              "hard", what="glissiere")
    for k, dx in enumerate((-0.15, 0.0, 0.15)):
        g.hose([B(0.3 + dx, yt + 0.1, c.ztop), B(0.4 + dx, (c.yb + yt) / 2 + 0.3, c.ztop + 0.25),
                B(0.45 + dx, (c.yb + c.h) / 2 - 0.1, c.z_bas + 0.3)], 0.03, M["rubber"], step=0.04)


def ouvrage(g, c):
    """Outillage de presse : semelle noire, 4 colonnettes, flan, pièces moulées rouges (plastique)."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.box(B(0, yt, zt + 0.05), (0.7, 0.46 * SQ2, 0.1), M["noir_capot"], "hard", what="semelle")
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.cyl(B(sx * 0.28, yt + sy * 0.18, zt + 0.17), "z", 0.025, 0.16, M["steel_hi"], n=8, what="colonnette")
    g.box(B(0, yt, zt + 0.12), (0.38, 0.26 * SQ2, 0.03), M["galva_capot"], "hard", what="flan")
    for k in range(3):
        g.box(B(-0.45 + 0.13 * k, yt - 0.34, zt + 0.03), (0.1, 0.08 * SQ2, 0.05), M["redpaint"], "soft",
              what="piece_moulee")


def entree(g, c, p):
    """Fût de brut couché sur un chevalet, robinet rouge (entrée)."""
    M = g.M
    r, z = p["r"], p["z"]
    g.box(B(p["x"], p["yn"], z + 0.06), (2 * r * 0.9, 0.5 * r * SQ2, 0.12), M["noir_capot"], "hard", what="chevalet")
    g.cyl(B(p["x"], p["yn"], z + 0.12 + r * 0.55), "x", r * 0.55, 2 * r * 0.9, M["yellowpaint"], n=20, what="fut_couche")
    for f in (-0.3, 0.3):
        g.tube_shell(B(p["x"] + f * r, p["yn"], z + 0.12 + r * 0.55), "x", r * 0.57, r * 0.5, 0.025, M["noir_capot"],
                     n=20, what="bourrelet")
    P2.handwheel(g, B(p["x"] + r * 0.95, p["yn"], z + 0.12 + r * 0.5), (1, 0, 0), 0.05, M, mat=M["redpaint"])


def sortie(g, c, p):
    """Caisse grillagée noire de pièces moulées rouges (sortie)."""
    corps.bac(g, c, p, g.M["noir_capot"], g.M["redpaint"], forme="plaque")


def piece(g, c):
    """Niveau 8 (plus grande) : palette de quatre fûts sous bâche (coin avant gauche), jerricans, pompe à main et extincteur
    (coin avant droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    # ronde F3-A3 (niveau pair peu visible) : fûts sur DEUX niveaux de palettes (coin gauche) ; groupe électrogène jaune
    # à pot d'échappement et gyrophare (coin droit)
    for niv, zz in enumerate((z, z + 0.5)):
        g.box(B(po["x"], po["yn"], zz + 0.04), (0.72, 0.62 * SQ2, 0.08), M["wood"], "hard", what="palette")
        for k, (dx, dy) in enumerate(((-0.16, 0.12), (0.16, 0.12), (-0.16, -0.14), (0.16, -0.14))):
            F.drum(g, tuple(B(po["x"] + dx, po["yn"] + dy, zz + 0.08)), 0.14, 0.4,
                   M["redpaint"] if (k + niv) % 4 == 3 else M["yellowpaint"], M["noir_capot"])
    xe, ye = pe["x"], pe["yn"]
    g.box(B(xe, ye, z + 0.3), (0.68, 0.52 * SQ2, 0.5), M["jaune_capot"], "hard", what="groupe")
    corps.face_s(g, xe - 0.32, xe + 0.32, ye - 0.26, z + 0.08, z + 0.5, M["noir_capot"], nu=4, nv=1, rivets=False)
    for k in range(5):
        g.box(B(xe - 0.2 + 0.1 * k, ye - 0.275, z + 0.3), (0.03, 0.02, 0.3), M["noir_capot"], "hard", what="ouie")
    g.cyl(B(xe + 0.2, ye + 0.12, z + 0.75), "z", 0.04, 0.5, M["steel_dk"], n=10, what="echappement")
    g.cyl(B(xe + 0.2, ye + 0.12, z + 1.0), "z", 0.055, 0.04, M["noir_capot"], n=10, what="chapeau")
    _gyro(g, xe - 0.18, ye + 0.1, z + 0.55)
    corps.lampe_face(g, xe - 0.2, ye - 0.26, z + 0.44, 0.03, M["emit"], M["noir_capot"])
