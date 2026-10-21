"""Têtes (tournantes, position « prepared ») de la famille gun, époques 2 à 15 (lot V3 phase 1).

Repère local de la tête : canons vers +Y ; z0 = dessus du socle ; zg = hauteur de l'axe des canons
(réglée par époque, params.json, pour suivre l'enveloppe O de la bible §4).
Proportions calées sur la tête vanilla : couronne de rotation ~0,7 de rayon, corps de 0,8 à 1,0 de large,
pointe des canons à y ≤ 1,25 (largeur L ≤ enveloppe dans les poses E et O).
Tout ce qui est au-dessus du socle appartient à la tête (couche object) : fût, col, mât, tronçons.
"""
import math
import random

from gun_kit import TAU, emit_rgb


def turntable(k, z0, r, mat, mat2, h=0.08):
    k.cyl(r, h, (0, 0, z0 + h / 2), mat, verts=56, bevel=0.012, name="couronne")
    k.cyl(r * 0.80, h * 0.8, (0, 0, z0 + h * 1.4), mat2, verts=56, bevel=0.01, name="couronne2")
    return z0 + h * 1.8


def gear_teeth(k, z, r, n, mat, size=0.05):
    """Denture de la couronne (rappel de la couronne dentée vanilla)."""
    objs = []
    for i in range(n):
        a = TAU * i / n
        o = k.S.box((size, size * 0.8, size * 0.9), (r * math.cos(a), r * math.sin(a), z), mat, k._name("dent"),
                    bevel_w=0)
        o.rotation_euler = (0, 0, a)
        objs.append(o)
    k._keep(k.S.join(objs, k._name("denture")))


def head(k, e, M, z0, zg):
    if e == 2:
        # FORGE : caisson riveté à 2 canons, bouclier frontal plat qui dépasse au-dessus de la tête
        zt = turntable(k, z0, 0.72, M["band"], M["main"])
        gear_teeth(k, z0 + 0.05, 0.74, 40, M["band"])
        k.rivet_ring(0.62, z0 + 0.10, 20, 0.018, M["brass"])
        k.cyl(0.44, zg - 0.36 - zt, (0, -0.08, (zt + zg - 0.36) / 2), M["main"], verts=8, spin=math.pi / 8, bevel=0.015,
              name="fut")
        k.cyl(0.46, 0.06, (0, -0.08, zt + 0.10), M["band"], verts=8, spin=math.pi / 8, name="cercle")
        for sx in (-1, 1):   # fourche
            k.box((0.11, 0.62, 0.62), (sx * 0.41, -0.08, zg - 0.16), M["main"], bevel=0.015, name="flasque")
            k.rivets_line((sx * 0.47, -0.30, zg - 0.40), (sx * 0.47, 0.14, zg - 0.40), 4, 0.02, M["brass"])
            k.cyl(0.10, 0.05, (sx * 0.48, -0.08, zg - 0.05), M["brass"], axis="x", verts=16, name="tourillon")
        k.box((0.70, 0.92, 0.62), (0, -0.12, zg + 0.02), M["main"], bevel=0.025, name="caisson")
        k.box((0.74, 0.96, 0.07), (0, -0.12, zg + 0.36), M["band"], bevel=0.01, name="toit")
        for sx in (-1, 1):
            for zz in (zg + 0.22, zg - 0.18):
                k.rivets_line((sx * 0.355, -0.56, zz), (sx * 0.355, 0.32, zz), 8, 0.018, M["brass"])
        for sx in (-1, 1):
            k.cyl(0.065, 0.84, (sx * 0.15, 0.70, zg - 0.06), M["gun"], axis="y", verts=16, name="canon")
            k.cyl(0.085, 0.12, (sx * 0.15, 1.07, zg - 0.06), M["band"], axis="y", verts=16, name="bouche")
            k.cyl(0.080, 0.05, (sx * 0.15, 0.62, zg - 0.06), M["brass"], axis="y", verts=16, name="frette")
        # bouclier frontal incliné, dépasse de 0,30 au-dessus du toit, bord renforcé
        k.box((1.02, 0.07, 1.06), (0, 0.42, zg + 0.10), M["main"], rot=(-0.14, 0, 0), bevel=0.015, name="bouclier")
        k.box((1.06, 0.09, 0.07), (0, 0.36, zg + 0.62), M["band"], rot=(-0.14, 0, 0), bevel=0.008, name="bord")
        for sx in (-1, 1):
            k.box((0.07, 0.09, 1.06), (sx * 0.50, 0.43, zg + 0.10), M["band"], rot=(-0.14, 0, 0), bevel=0.006, name="montant")
            k.rivets_line((sx * 0.42, 0.37, zg - 0.36), (sx * 0.42, 0.45, zg + 0.56), 7, 0.02, M["brass"])
        k.box((0.16, 0.08, 0.12), (0, 0.38, zg + 0.44), M["dark"], rot=(-0.14, 0, 0), bevel=0, name="viseur")
        # caisse de munitions latérale et bande cartouchière
        k.box((0.28, 0.50, 0.42), (-0.52, -0.22, zg + 0.04), M["main"], bevel=0.018, name="munitions")
        for dy in (-0.36, -0.08):
            k.box((0.30, 0.05, 0.44), (-0.52, dy, zg + 0.04), M["band"], bevel=0.005, name="cercle")
        k.box((0.16, 0.26, 0.07), (-0.36, 0.10, zg + 0.16), M["brass"], rot=(0, 0.35, 0), bevel=0, name="bande")
        return
    if e == 3:
        # VAPEUR : chaudière dorsale + cheminée ronde, 2 canons longs, alimentation par tuyau ; socle en fonte
        zt = turntable(k, z0, 0.70, M["fonte"], M["brass"])
        gear_teeth(k, z0 + 0.05, 0.72, 40, M["fonte"])
        k.cyl(0.46, zg - 0.20 - zt, (0, -0.06, (zt + zg - 0.20) / 2), M["fonte"], r2=0.30, verts=40, name="fut")
        k.tor(0.42, 0.035, (0, -0.06, zt + 0.12), M["brass"], name="bague")
        k.cyl(0.29, 0.86, (0, 0.04, zg), M["main"], axis="y", verts=40, bevel=0.012, name="culasse")
        for yy in (-0.30, 0.06, 0.40):
            k.tor(0.295, 0.025, (0, yy, zg), M["brass"], axis="y", name="cercle")
        for sx in (-1, 1):
            k.cyl(0.058, 0.76, (sx * 0.13, 0.78, zg - 0.04), M["gun"], axis="y", verts=16, name="canon")
            for yy in (0.58, 0.80, 1.02):
                k.cyl(0.08, 0.05, (sx * 0.13, yy, zg - 0.04), M["brass"], axis="y", verts=16, name="ailette")
        zb = zg + 0.36
        k.cyl(0.34, 0.88, (0, -0.48, zb), M["main"], axis="x", verts=40, bevel=0.015, name="chaudiere")
        for xx in (-0.30, 0.0, 0.30):
            k.tor(0.345, 0.022, (xx, -0.48, zb), M["brass"], axis="x", name="cercle")
        for sx in (-1, 1):
            k.cyl(0.13, 0.035, (sx * 0.45, -0.48, zb), M["brass"], axis="x", verts=28, name="hublot_cadre")
            k.cyl(0.10, 0.04, (sx * 0.455, -0.48, zb), M["emit"], axis="x", verts=28, name="hublot")
        k.box((0.26, 0.05, 0.16), (0, -0.83, zb - 0.08), M["emit"], bevel=0, name="foyer")
        k.box((0.32, 0.06, 0.04), (0, -0.84, zb + 0.02), M["fonte"], bevel=0, name="grille")
        k.cyl(0.11, 0.34, (0.18, -0.56, zb + 0.30 + 0.17), M["fonte"], verts=28, name="cheminee")
        k.cyl(0.15, 0.07, (0.18, -0.56, zb + 0.66), M["brass"], verts=28, name="collerette")
        k.cyl(0.13, 0.05, (0.18, -0.56, zb + 0.36), M["brass"], verts=28, name="embase")
        k.cyl(0.09, 0.035, (-0.22, -0.30, zb + 0.30), M["brass"], axis=(math.pi / 2 + 0.6, 0, 0), verts=24, name="manometre")
        k.cyl(0.045, 0.46, (0.30, -0.20, zg + 0.20), M["main"], axis=(0.9, 0, 0), verts=12, name="tuyau")
        k.cyl(0.045, 0.40, (-0.30, -0.18, zg + 0.20), M["main"], axis=(0.9, 0, 0), verts=12, name="tuyau")
        k.halo((0, -0.48, zb), emit_rgb("#FFC060"), 20.0)
        return
    if e == 4:
        # PÉTROLE : tête caissonnée jaune, 2 bidons-chargeurs latéraux, 3 canons ; garde-corps et voyant
        zt = turntable(k, z0, 0.72, M["galva"], M["black"])
        k.cyl(0.34, zg - 0.33 - zt, (0, -0.06, (zt + zg - 0.33) / 2), M["galva"], verts=36, name="fut")
        for sx in (-1, 1):   # vérins hydrauliques
            k.cyl(0.07, zg - zt - 0.2, (sx * 0.36, -0.06, (zt + zg - 0.33) / 2 + 0.05), M["main"], verts=16, name="verin")
            k.cyl(0.04, 0.2, (sx * 0.36, -0.06, zg - 0.40), M["galva"], verts=12, name="tige")
        k.box((0.80, 0.96, 0.66), (0, -0.10, zg), M["main"], bevel=0.025, name="caisson")
        for i in range(7):
            k.box((0.82, 0.06, 0.12), (0, -0.52 + i * 0.13, zg - 0.36), M["black"] if i % 2 else M["main"], bevel=0,
                  name="chevron")
        for sx in (-1, 1):
            k.cyl(0.24, 0.82, (sx * 0.64, -0.08, zg + 0.02), M["galva"], axis="y", verts=36, bevel=0.012, name="bidon")
            for yy in (-0.32, 0.18):
                k.tor(0.244, 0.022, (sx * 0.64, yy, zg + 0.02), M["black"], axis="y", name="cercle")
            k.cyl(0.20, 0.035, (sx * 0.64, 0.34, zg + 0.02), M["black"], axis="y", verts=28, name="fond")
            k.cyl(0.07, 0.10, (sx * 0.40, 0.10, zg - 0.06), M["galva"], axis="x", verts=12, name="goulotte")
        k.gatling(3, 0.11, 0.05, 0.40, 1.22, 0.0, zg - 0.05, M["gun"], M["galva"], rings=(0.08, 0.6, 0.95),
                  phase=math.pi / 2)
        zr = zg + 0.33
        for x, y in ((-0.36, -0.54), (0.36, -0.54), (-0.36, 0.30), (0.36, 0.30)):
            k.cyl(0.018, 0.26, (x, y, zr + 0.13), M["galva"], verts=8, bevel=0, name="poteau")
        k.box((0.74, 0.028, 0.028), (0, -0.54, zr + 0.25), M["galva"], bevel=0, name="lisse")
        k.box((0.028, 0.86, 0.028), (-0.36, -0.12, zr + 0.25), M["galva"], bevel=0, name="lisse")
        k.box((0.028, 0.86, 0.028), (0.36, -0.12, zr + 0.25), M["galva"], bevel=0, name="lisse")
        k.cyl(0.08, 0.07, (0.14, -0.28, zr + 0.035), M["black"], verts=20, name="voyant_pied")
        k.sph(0.095, (0.14, -0.28, zr + 0.12), M["emit"], seg=20, rings=10, name="voyant")
        k.box((0.34, 0.34, 0.12), (-0.10, -0.24, zr + 0.06), M["galva"], bevel=0.012, name="trappe")
        k.halo((0.14, -0.28, zr + 0.22), emit_rgb("#FF8C1A"), 20.0)
        return
    if e == 5:
        # VOLCAN : tête en coin (blindage incliné, profil trapézoïdal), 2 canons lourds en tungstène
        zt = turntable(k, z0, 0.72, M["main"], M["rouille"])
        sq = [(0.46, 0.40), (-0.46, 0.40), (-0.46, -0.52), (0.46, -0.52)]
        k.frustum_poly(sq, zt, zg - 0.40, 0.74, M["main"], bevel=0.02, name="affut")
        prof = [(-0.66, zg - 0.40), (0.56, zg - 0.40), (0.12, zg + 0.46), (-0.66, zg + 0.58)]
        k.prism_x(prof, 0.0, 1.00, M["main"], bevel=0.025, name="coin")
        prof2 = [(-0.64, zg - 0.38), (0.54, zg - 0.38), (0.11, zg + 0.44), (-0.64, zg + 0.56)]
        k.prism_x(prof2, 0.0, 1.08, M["rouille"], bevel=0.02, name="joues")
        for j, (yy, zz) in enumerate(((0.44, zg - 0.20), (0.31, zg + 0.06), (0.18, zg + 0.31))):
            k.box((0.96 - 0.06 * j, 0.06, 0.30), (0, yy + 0.035, zz), M["main"], rot=(-1.10, 0, 0), bevel=0.015, name="ecaille")
        for sx in (-1, 1):
            k.cyl(0.085, 0.74, (sx * 0.20, 0.76, zg - 0.16), M["gun"], axis="y", verts=18, name="canon")
            k.box((0.24, 0.18, 0.18), (sx * 0.20, 1.06, zg - 0.16), M["main"], bevel=0.015, name="frein")
            k.rivets_line((sx * 0.52, -0.62, zg + 0.50), (sx * 0.52, -0.62, zg - 0.32), 5, 0.035, M["rouille"])
            k.box((0.05, 0.36, 0.16), (sx * 0.545, -0.24, zg + 0.04), M["emit"], bevel=0, name="braise")
        k.box((0.40, 0.05, 0.16), (0, -0.67, zg + 0.10), M["emit"], bevel=0, name="braise")
        for sx in (-1, 1):   # pointes de basalte sur l'arrière du toit
            k.spike((sx * 0.30, -0.52, zg + 0.52), (sx * 0.36, -0.62, zg + 0.88), 0.07, M["rouille"], sides=5, name="pointe")
        k.halo((0, -0.24, zg + 0.1), emit_rgb("#FF4A10"), 20.0)
        return
    if e == 6:
        # ÉLECTRICITÉ : moteur bobiné, 4 canons rotatifs, isolateurs dorsaux ; fût en pile d'isolateurs
        zt = turntable(k, z0, 0.70, M["steel"], M["coil"])
        k.cyl(0.16, zg - zt, (0, -0.10, (zt + zg) / 2), M["steel"], verts=24, name="ame")
        z = zt
        i = 0
        while z < zg - 0.40:
            r = 0.40 if i % 2 == 0 else 0.30
            k.cyl(r, 0.08, (0, -0.10, z + 0.04), M["main"], verts=36, bevel=0.015, name="iso_col")
            z += 0.08
            i += 1
        k.cyl(0.38, 0.66, (0, -0.30, zg), M["coil"], axis="y", verts=40, bevel=0.012, name="moteur")
        for yy in (-0.56, -0.46, -0.36, -0.26, -0.16):
            k.tor(0.385, 0.026, (0, yy, zg), M["coil"], axis="y", name="spire")
        k.cyl(0.395, 0.14, (0, -0.04, zg), M["emit"], axis="y", verts=40, bevel=0, name="bobine_lueur")
        k.cyl(0.30, 0.07, (0, 0.06, zg), M["steel"], axis="y", verts=36, name="flasque")
        k.gatling(4, 0.13, 0.05, 0.08, 1.20, 0.0, zg, M["gun"], M["steel"], rings=(0.05, 0.45, 0.93), phase=math.pi / 4)
        # 2 hautes piles d'isolateurs dorsales (signature de l'époque : colonnes « crantées » qui dépassent
        # nettement de la tête dans les 4 poses) ; disques larges (0,13) et étroits (0,085) alternés
        for sx in (-1, 1):
            ztop = k.disc_stack(sx * 0.24, -0.40, zg + 0.30, 7, 0.13, 0.085, 0.075, M["main"], cap=M["coil"])
            k.sph(0.10, (sx * 0.24, -0.40, ztop + 0.08), M["emit"], seg=16, rings=8, name="eclateur")
        k.box((0.62, 0.05, 0.05), (0, -0.40, zg + 0.36), M["coil"], bevel=0, name="barre_isolateurs")
        k.box((0.50, 0.14, 0.18), (0, -0.70, zg - 0.16), M["steel"], bevel=0.012, name="boitier")
        k.halo((0, -0.40, zg + 0.7), emit_rgb("#60D0FF"), 20.0)
        return
    if e == 7:
        # CRISTAL : canon à éclats, tête de bronze organique, grappe de cristaux dorsale asymétrique
        zt = turntable(k, z0, 0.68, M["main"], M["pierre"])
        k.cyl(0.42, zg - 0.26 - zt, (0, -0.06, (zt + zg - 0.26) / 2), M["main"], r2=0.24, verts=9, bevel=0.012, name="fut")
        k.tor(0.36, 0.05, (0, -0.06, zt + 0.12), M["pierre"], mseg=8, name="bague")
        k.sph(0.46, (0, -0.10, zg), M["main"], scale=(1.0, 1.32, 0.86), seg=36, rings=18, name="corps")
        k.tor(0.38, 0.04, (0, 0.20, zg), M["pierre"], axis="y", name="bague")
        for sx in (-1, 1):
            k.cyl(0.065, 0.78, (sx * 0.16, 0.78, zg - 0.08), M["gun"], axis="y", r2=0.05, verts=14, name="canon")
            k.cyl(0.09, 0.12, (sx * 0.16, 1.14, zg - 0.08), M["main"], axis="y", verts=7, name="bouche")
            k.spike((sx * 0.16, 1.10, zg - 0.02), (sx * 0.20, 1.24, zg + 0.16), 0.045, M["emit"], sides=6, name="eclat")
        base = (0.0, -0.36, zg + 0.30)
        k.cyl(0.22, 0.12, (base[0], base[1], base[2] - 0.02), M["main"], verts=7, name="sertissure")
        for j, (L, ax, ay, r) in enumerate(((1.02, 0.05, -0.10, 0.13), (0.78, -0.34, -0.12, 0.11),
                                            (0.66, 0.36, -0.06, 0.10), (0.52, -0.12, 0.28, 0.09),
                                            (0.46, 0.26, -0.34, 0.08))):
            tip = (base[0] + ax * L, base[1] + ay * L, base[2] + L)
            k.spike((base[0] + ax * 0.06, base[1] + ay * 0.06, base[2]), tip, r, M["emit"], sides=6, name="cristal")
        k.halo((0, -0.36, zg + 0.8), emit_rgb("#B070FF"), 20.0)
        return
    if e == 8:
        # MARAIS : tête à 2 canons et réservoir-bulbe dorsal ; fût bulbeux
        zt = turntable(k, z0, 0.66, M["main"], M["rubber"])
        h = zg - 0.30 - zt
        k.cyl(0.18, h, (0, -0.10, zt + h / 2), M["main"], verts=24, name="col")
        k.sph(0.40, (0, -0.10, zt + h * 0.42), M["main"], scale=(1, 1, 0.75), seg=36, rings=18, name="bulbe_fut")
        k.tor(0.40, 0.04, (0, -0.10, zt + h * 0.42), M["rubber"], name="jonc")
        k.cyl(0.30, 0.78, (0, 0.0, zg), M["main"], axis="y", verts=36, bevel=0.012, name="capsule")
        k.sph(0.30, (0, -0.39, zg), M["main"], seg=28, rings=14, name="cul")
        for sx in (-1, 1):
            k.cyl(0.055, 0.74, (sx * 0.15, 0.74, zg - 0.06), M["gun"], axis="y", verts=14, name="canon")
            k.sph(0.09, (sx * 0.15, 1.12, zg - 0.06), M["glass"], seg=16, rings=8, name="bulbe_bouche")
            k.cyl(0.04, 0.62, (sx * 0.26, 0.10, zg + 0.24), M["rubber"], axis=(1.2, 0, 0), verts=10, name="durite")
        zb = zg + 0.66
        k.cyl(0.18, 0.22, (0, -0.36, zg + 0.30), M["main"], verts=24, name="col")
        k.sph(0.46, (0, -0.36, zb), M["glass"], seg=40, rings=20, name="bulbe")
        k.sph(0.43, (0, -0.36, zb - 0.09), M["emit"], scale=(1, 1, 0.78), seg=36, rings=18, name="liquide")
        k.tor(0.46, 0.035, (0, -0.36, zb - 0.02), M["main"], name="frette")
        k.cyl(0.12, 0.12, (0, -0.36, zb + 0.48), M["main"], verts=20, name="bouchon")
        k.halo((0, -0.36, zb), emit_rgb("#A8FF3A"), 20.0)
        return
    if e == 9:
        # ATOME : tête octogonale plombée chanfreinée, 2 canons à manchons, hublot vert, tour de refroidissement
        zt = turntable(k, z0, 0.70, M["main"], M["jaune"])
        k.cyl(0.38, zg - 0.40 - zt, (0, -0.06, (zt + zg - 0.40) / 2), M["beton"], verts=8, spin=math.pi / 8, name="fut")
        k.cyl(0.40, 0.08, (0, -0.06, zt + 0.12), M["jaune"], verts=8, spin=math.pi / 8, name="bande")
        k.cyl(0.58, 0.58, (0, -0.08, zg), M["main"], verts=8, spin=math.pi / 8, bevel=0.025, name="octogone")
        k.cyl(0.58, 0.16, (0, -0.08, zg + 0.37), M["main"], r2=0.38, verts=8, spin=math.pi / 8, bevel=0.012, name="chanfrein")
        k.cyl(0.46, 0.14, (0, -0.08, zg - 0.36), M["main"], r2=0.58, verts=8, spin=math.pi / 8, bevel=0.012, name="chanfrein_bas")
        k.cyl(0.59, 0.08, (0, -0.08, zg - 0.20), M["jaune"], verts=8, spin=math.pi / 8, bevel=0, name="bande")
        for sx in (-1, 1):
            k.cyl(0.055, 0.78, (sx * 0.18, 0.84, zg - 0.05), M["gun"], axis="y", verts=14, name="canon")
            k.cyl(0.10, 0.44, (sx * 0.18, 0.66, zg - 0.05), M["main"], axis="y", verts=8, name="manchon")
            for yy in (0.48, 0.58, 0.68, 0.78):
                k.cyl(0.125, 0.03, (sx * 0.18, yy, zg - 0.05), M["main"], axis="y", verts=8, name="ailette")
        k.cyl(0.15, 0.045, (0, 0.47, zg + 0.10), M["jaune"], axis="y", verts=28, name="hublot_cadre")
        k.cyl(0.12, 0.05, (0, 0.475, zg + 0.10), M["emit"], axis="y", verts=28, name="hublot")
        k.cyl(0.13, 0.04, (0.0, -0.08, zg + 0.46), M["emit"], verts=28, name="hublot_toit")
        hb = zg + 0.36
        k.cyl(0.24, 0.30, (0.0, -0.44, hb + 0.15), M["beton"], r2=0.15, verts=28, name="hyper_bas")
        k.cyl(0.15, 0.28, (0.0, -0.44, hb + 0.44), M["beton"], r2=0.21, verts=28, name="hyper_haut")
        k.box((0.30, 0.05, 0.20), (0.0, -0.66, zg), M["jaune"], bevel=0, name="plaque")
        k.halo((0, 0.3, zg + 0.2), emit_rgb("#5CFF4A"), 20.0)
        return
    if e == 10:
        # HAUTE TECHNOLOGIE : dôme caréné, 4 canons courts dans un manchon, capteur optique ; col élancé
        zt = turntable(k, z0, 0.46, M["noir"], M["main"])
        k.cyl(0.15, zg - zt, (0, 0.0, (zt + zg) / 2), M["main"], verts=28, name="col")
        k.cyl(0.21, 0.12, (0, 0.0, zt + 0.12), M["noir"], verts=28, name="bague")
        k.cyl(0.56, 0.24, (0, -0.06, zg - 0.14), M["noir"], verts=48, bevel=0.025, name="jupe")
        k.cyl(0.565, 0.06, (0, -0.06, zg - 0.05), M["emit"], verts=48, bevel=0, name="bandeau")
        k.sph(0.56, (0, -0.06, zg - 0.02), M["main"], scale=(1, 1, 0.80), seg=48, rings=24, name="dome")
        k.cyl(0.19, 0.70, (0, 0.62, zg - 0.05), M["main"], axis="y", verts=36, bevel=0.012, name="manchon")
        k.gatling(4, 0.085, 0.036, 0.94, 1.20, 0.0, zg - 0.05, M["gun"], M["noir"], rings=(0.5,), phase=math.pi / 4)
        k.cyl(0.195, 0.05, (0, 0.94, zg - 0.05), M["emit"], axis="y", verts=36, bevel=0, name="anneau")
        k.sph(0.13, (0.0, 0.22, zg + 0.40), M["noir"], seg=24, rings=12, name="capteur")
        k.cyl(0.085, 0.035, (0.0, 0.33, zg + 0.41), M["emit"], axis="y", verts=24, name="lentille")
        k.cyl(0.014, 0.95, (-0.26, -0.36, zg + 0.70), M["noir"], verts=8, bevel=0, name="antenne")
        k.halo((0, -0.06, zg), emit_rgb("#3AA8FF"), 20.0)
        return
    if e == 11:
        # TITANE : tête effilée (fuseau) à ailerons arrière, 2 canons longs ; mât de titane
        zt = turntable(k, z0, 0.40, M["titane"], M["main"])
        k.cyl(0.11, zg - zt, (0, -0.12, (zt + zg) / 2), M["titane"], verts=20, name="mat")
        k.cyl(0.17, 0.12, (0, -0.12, zg - 0.30), M["titane"], verts=20, name="rotule")
        k.cyl(0.32, 0.95, (0, 0.12, zg), M["main"], axis="y", r2=0.14, verts=36, bevel=0.012, name="fuseau")
        k.sph(0.32, (0, -0.35, zg), M["main"], scale=(1, 1.3, 1), seg=28, rings=14, name="queue")
        k.cyl(0.325, 0.12, (0, -0.08, zg), M["emit"], axis="y", verts=36, bevel=0, name="ligne")
        for sx in (-1, 1):
            k.cyl(0.042, 1.00, (sx * 0.25, 0.70, zg - 0.16), M["titane"], axis="y", verts=12, name="canon")
            k.box((0.05, 0.40, 0.08), (sx * 0.22, 0.20, zg - 0.14), M["titane"], name="support")
        k.prism_x([(-0.82, zg + 0.14), (-0.18, zg + 0.26), (-0.72, zg + 1.00)], 0.0, 0.06, M["main"], bevel=0.008,
                  name="aileron_dorsal")
        k.prism_x([(-0.72, zg + 0.56), (-0.62, zg + 0.62), (-0.73, zg + 0.94), (-0.78, zg + 0.90)], 0.0, 0.075, M["emit"],
                  bevel=0, name="ligne_aileron")
        for sx in (-1, 1):
            k.prism_y([(sx * 0.20, zg - 0.04), (sx * 0.80, zg + 0.24), (sx * 0.75, zg + 0.36), (sx * 0.20, zg + 0.14)],
                      -0.52, 0.30, M["main"], bevel=0.008, name="aileron_lat")
        k.halo((0, -0.08, zg + 0.1), emit_rgb("#BFE6FF"), 20.0)
        return
    if e == 12:
        # SUPRACONDUCTEURS : fusil à rail flottant au-dessus du socle annulaire (aucun mât : vide)
        k.cyl(0.22, 0.08, (0, 0, z0 + 0.06), M["chrome"], verts=36, name="emetteur")
        k.cyl(0.12, 0.03, (0, 0, z0 + 0.115), M["emit"], verts=28, name="emetteur_lueur")
        k.box((0.72, 0.86, 0.46), (0, -0.26, zg), M["main"], bevel=0.035, name="noyau")
        k.box((0.66, 0.76, 0.07), (0, -0.26, zg + 0.24), M["givre"], bevel=0.025, name="givre")
        k.box((0.40, 0.24, 0.28), (0, -0.76, zg + 0.04), M["chrome"], bevel=0.025, name="culasse")
        for sx in (-1, 1):
            k.box((0.09, 1.70, 0.15), (sx * 0.16, 0.40, zg - 0.03), M["chrome"], bevel=0.012, name="rail")
            k.box((0.06, 0.70, 0.06), (sx * 0.38, -0.26, zg - 0.10), M["emit"], bevel=0, name="flanc_lueur")
        for yy in (0.18, 0.58, 0.98):
            k.tor(0.33, 0.06, (0, yy, zg - 0.03), M["chrome"], axis="y", mseg=12, name="anneau")
            k.tor(0.26, 0.03, (0, yy, zg - 0.03), M["emit"], axis="y", name="anneau_lueur")
        # colonne d'anneaux chromés en lévitation entre l'émetteur du socle et la tête (signature de l'époque :
        # « anneaux en lévitation », vides entre eux) ; ils tournent avec la tête (couche object)
        z_lo, z_hi = z0 + 0.36, zg - 0.44
        n = max(3, int(round((z_hi - z_lo) / 0.36)) + 1)
        for i in range(n):
            t = i / (n - 1)
            k.tor(0.20 + 0.14 * t, 0.034 + 0.012 * t, (0, -0.26 * t, z_lo + (z_hi - z_lo) * t), M["chrome"], name="lev")
        k.halo((0, 0.3, zg), emit_rgb("#4AF0FF"), 20.0)
        return
    if e == 13:
        # FUSION : canon à plasma, tête sphérique ceinturée d'un tore de plasma, 2 canons courts ; col de cuivre
        k.cyl(0.13, zg - z0 - 0.40, (0, 0, (z0 + zg - 0.40) / 2), M["cuivre"], verts=24, name="col")
        zz = z0 + 0.35
        while zz < zg - 0.55:
            k.tor(0.16, 0.035, (0, 0, zz), M["main"], name="bague")
            zz += 0.35
        k.sph(0.48, (0, -0.05, zg), M["main"], seg=48, rings=24, name="sphere")
        k.tor(0.66, 0.08, (0, -0.05, zg - 0.02), M["emit"], seg=72, mseg=14, name="tore")
        k.tor(0.49, 0.035, (0, -0.05, zg - 0.02), M["cuivre"], name="ceinture")
        for j in range(6):
            a = TAU * j / 6
            k.box((0.06, 0.20, 0.06), (0.56 * math.cos(a), -0.05 + 0.56 * math.sin(a), zg - 0.02), M["cuivre"],
                  rot=(0, 0, a), bevel=0, name="agrafe")
        for sx in (-1, 1):
            k.cyl(0.085, 0.56, (sx * 0.18, 0.62, zg - 0.08), M["cuivre"], axis="y", verts=18, name="canon")
            k.cyl(0.11, 0.12, (sx * 0.18, 0.92, zg - 0.08), M["main"], axis="y", verts=18, name="bouche")
            k.sph(0.065, (sx * 0.18, 0.99, zg - 0.08), M["emit2"], seg=14, rings=7, name="coeur")
        k.sph(0.14, (0, -0.12, zg + 0.48), M["cuivre"], seg=18, rings=9, name="injecteur")
        k.halo((0, -0.05, zg), emit_rgb("#FF4FD8"), 22.0)
        return
    if e == 14:
        # ORBITE : tête-satellite, bus en feuille d'or, 2 canons, 2 petits panneaux dorés, parabole de visée
        k.cyl(0.09, zg - z0 - 0.26, (0, 0, (z0 + zg - 0.26) / 2), M["blanc"], verts=20, name="mat")
        k.cyl(0.16, 0.10, (0, 0, zg - 0.30), M["blanc"], verts=20, name="rotule")
        k.box((0.52, 0.64, 0.52), (0, -0.08, zg), M["main"], bevel=0.025, name="bus")
        k.box((0.54, 0.07, 0.54), (0, 0.26, zg), M["blanc"], bevel=0.012, name="face")
        for sx in (-1, 1):
            k.cyl(0.058, 0.82, (sx * 0.13, 0.66, zg - 0.10), M["blanc"], axis="y", verts=16, name="canon")
            k.cyl(0.075, 0.10, (sx * 0.13, 1.04, zg - 0.10), M["main"], axis="y", verts=16, name="bouche")
            k.cyl(0.025, 0.40, (sx * 0.46, -0.08, zg + 0.02), M["blanc"], axis="x", verts=8, name="bras")
            k.box((0.46, 0.38, 0.03), (sx * 0.84, -0.08, zg + 0.04), M["cells"], rot=(0, sx * 0.30, 0), bevel=0.005,
                  name="panneau")
            k.box((0.48, 0.40, 0.018), (sx * 0.84, -0.08, zg + 0.02), M["main"], rot=(0, sx * 0.30, 0), bevel=0.0,
                  name="cadre")
            k.box((0.40, 0.05, 0.035), (sx * 0.84, -0.08, zg + 0.065), M["emit2"], rot=(0, sx * 0.30, 0), bevel=0,
                  name="reflet")
        k.cyl(0.04, 0.26, (0, -0.12, zg + 0.38), M["blanc"], verts=10, name="pied_parabole")
        k.sph(0.38, (0, -0.06, zg + 0.66), M["blanc"], scale=(1, 0.30, 1), seg=36, rings=18, name="parabole")
        k.cyl(0.025, 0.30, (0, 0.08, zg + 0.66), M["main"], axis="y", verts=8, name="cornet")
        k.sph(0.075, (0, -0.26, zg + 1.08), M["emit"], seg=16, rings=8, name="balise")
        k.halo((0, -0.1, zg + 0.7), emit_rgb("#FF2A2A"), 20.0)
        return
    if e == 15:
        # LÉGENDE : couronne de 6 canons en étoile flottant sur le socle-disque ; flèches ; halo ; tronçons flottants
        zz, rr = z0 + 0.38, 0.24
        while zz < zg - 0.62:
            k.cyl(rr, 0.08, (0, 0, zz), M["nacre"], verts=36, bevel=0.012, name="troncon")
            k.tor(rr + 0.012, 0.018, (0, 0, zz), M["emit"], name="troncon_lueur")
            zz += 0.42
            rr = max(0.12, rr - 0.04)
        k.sph(0.34, (0, 0, zg), M["nacre"], seg=40, rings=20, name="noyau")
        k.tor(0.38, 0.05, (0, 0, zg), M["main"], name="ceinture")
        k.tor(0.36, 0.04, (0, 0, zg), M["main"], axis="y", name="ceinture2")
        for j in range(6):
            a = TAU * j / 6 + math.pi / 6
            ox, oz = math.cos(a), math.sin(a)
            base = (ox * 0.20, 0.10, zg + oz * 0.20)
            tip = (ox * 0.46, 1.12, zg + oz * 0.46)
            k.spike(base, tip, 0.06, M["main"], sides=8, name="canon")
            k.sph(0.05, tip, M["emit"], seg=12, rings=6, name="bouche")
        for j, (dx, dy, h) in enumerate(((0.0, -0.14, 1.12), (-0.30, -0.10, 0.74), (0.30, -0.10, 0.74),
                                         (-0.18, 0.18, 0.56), (0.18, 0.18, 0.56))):
            k.spike((dx * 0.8, dy, zg + 0.16), (dx, dy, zg + 0.16 + h), 0.09 if j == 0 else 0.075, M["main"], sides=8,
                    name="fleche")
        k.tor(0.58, 0.026, (0, -0.02, zg + 0.74), M["emit"], seg=72, name="halo")
        k.halo((0, 0, zg + 0.3), emit_rgb("#FFF2C0"), 24.0)
        return
    raise ValueError(e)
