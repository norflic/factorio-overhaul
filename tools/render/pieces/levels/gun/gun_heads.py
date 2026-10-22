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


# Agrandissement du corps de la tête (reprise 3, 22/10) : aux époques 10 à 15, la tête faisait 0,5 à 1,1 tuile de
# large au sommet d'un mât de 1,4 à 1,9 tuile (lecture « lampadaire »). Le corps (au-dessus du col, repères posés
# dans _head) est agrandi de ce facteur autour de (0, 0, zg), comprimé au-delà de ±0,45 pour rester dans la
# largeur L de la bible (gun.L_TARGET) ; le col est épaissi à la main ; tune.py règle ensuite zg sur O.
HEAD_SCALE = {10: 1.25, 11: 1.35, 12: 1.30, 13: 1.22, 14: 1.35, 15: 1.30}
L_HALF = {10: 1.055, 11: 1.065, 12: 1.075, 13: 1.08, 14: 1.09, 15: 1.10}


def head(k, e, M, z0, zg):
    k.body_marks = None
    _head(k, e, M, z0, zg)
    if e in HEAD_SCALE:
        m0, m1 = k.body_marks
        h = L_HALF[e]
        k.deform(m0, m1, (0.0, 0.0, zg), HEAD_SCALE[e], {"x": (-h, h), "y": (-h, h)})


def _head(k, e, M, z0, zg):
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
        # VAPEUR : chaudière compacte dorsale + cheminée courte, 2 canons longs à ailettes, alimentation par tuyau.
        # Reprise 4 (vérification adverse, majeur 1) : la chaudière (y = -0,48) et la cheminée (y = -0,56, x = 0,18)
        # portaient le sommet en pose S seulement ; en pose N, O tombait à 0,55 (0,94 à l'époque 2). Chaudière
        # avancée sur le dos de la culasse (y = -0,22, rayon 0,30) et cheminée sur l'axe (x = 0) : le sommet est
        # porté par la cheminée (S), les ailettes de bouche (N) et les fonds de chaudière (E, O), à 0,16 unité près.
        zt = turntable(k, z0, 0.70, M["fonte"], M["brass"])
        gear_teeth(k, z0 + 0.05, 0.72, 40, M["fonte"])
        k.cyl(0.46, zg - 0.20 - zt, (0, -0.06, (zt + zg - 0.20) / 2), M["fonte"], r2=0.30, verts=40, name="fut")
        k.tor(0.42, 0.035, (0, -0.06, zt + 0.12), M["brass"], name="bague")
        k.cyl(0.29, 0.86, (0, 0.04, zg), M["main"], axis="y", verts=40, bevel=0.012, name="culasse")
        for yy in (-0.30, 0.06, 0.40):
            k.tor(0.295, 0.025, (0, yy, zg), M["brass"], axis="y", name="cercle")
        for sx in (-1, 1):
            k.cyl(0.058, 0.76, (sx * 0.13, 0.78, zg), M["gun"], axis="y", verts=16, name="canon")
            for yy in (0.58, 0.80, 1.02):
                # ailettes de 0,18 de diamètre : 11,5 px hr, comptées dans les masses (O en pose N) ; canons sur l'axe
                # de la culasse (zg) : marge de 0,03 tuile sur l'époque 2 en pose N
                k.cyl(0.09, 0.05, (sx * 0.13, yy, zg), M["brass"], axis="y", verts=16, name="ailette")
        zb = zg + 0.30
        k.cyl(0.30, 0.88, (0, -0.22, zb), M["main"], axis="x", verts=40, bevel=0.015, name="chaudiere")
        for xx in (-0.30, 0.0, 0.30):
            k.tor(0.305, 0.022, (xx, -0.22, zb), M["brass"], axis="x", name="cercle")
        for sx in (-1, 1):
            k.cyl(0.12, 0.035, (sx * 0.45, -0.22, zb), M["brass"], axis="x", verts=28, name="hublot_cadre")
            k.cyl(0.09, 0.04, (sx * 0.455, -0.22, zb), M["emit"], axis="x", verts=28, name="hublot")
        k.box((0.26, 0.05, 0.16), (0, -0.53, zb - 0.06), M["emit"], bevel=0, name="foyer")
        k.box((0.32, 0.06, 0.04), (0, -0.54, zb + 0.04), M["fonte"], bevel=0, name="grille")
        # cheminée courte sur l'axe, sur le dos de la chaudière
        k.cyl(0.11, 0.20, (0.0, -0.22, zb + 0.36), M["fonte"], verts=28, name="cheminee")
        k.cyl(0.15, 0.07, (0.0, -0.22, zb + 0.495), M["brass"], verts=28, name="collerette")
        k.cyl(0.13, 0.05, (0.0, -0.22, zb + 0.29), M["brass"], verts=28, name="embase")
        k.cyl(0.08, 0.035, (-0.30, -0.06, zb + 0.20), M["brass"], axis=(math.pi / 2 + 0.6, 0, 0), verts=24, name="manometre")
        # regard du foyer sur le DESSUS de la chaudière, devant la cheminée : lueur ambrée visible dans les 4 poses
        # (D2-1, zone de 8 × 8 px hr au moins)
        k.cyl(0.14, 0.04, (0.28, -0.21, zb + 0.305), M["brass"], verts=28, name="regard_cadre")
        k.cyl(0.11, 0.045, (0.28, -0.21, zb + 0.315), M["emit"], verts=28, name="regard")
        k.cyl(0.045, 0.40, (0.30, -0.06, zg + 0.10), M["main"], axis=(0.9, 0, 0), verts=12, name="tuyau")
        k.cyl(0.045, 0.36, (-0.30, -0.04, zg + 0.10), M["main"], axis=(0.9, 0, 0), verts=12, name="tuyau")
        k.halo((0, -0.22, zb), emit_rgb("#FFC060"), 20.0)
        return
    if e == 4:
        # PÉTROLE : tête caissonnée jaune, 2 bidons-chargeurs latéraux, 3 canons ; garde-corps et voyant
        zt = turntable(k, z0, 0.72, M["galva"], M["black"])
        # fût en EMPILEMENT (reprise 4) : tambour bas large + colonne, vérins écartés ; au 1er aperçu de la reprise 4,
        # IoU(époque 3, époque 4) = 0,854 en poses E et O (D1-2 : ≤ 0,85), alors que l'époque 4 ouvre l'ère II
        # (« cylindres, pentes, empilements ; plus large et plus haut », bible §1.2)
        k.cyl(0.54, 0.24, (0, -0.06, zt + 0.12), M["galva"], verts=36, bevel=0.015, name="tambour")
        k.cyl(0.55, 0.05, (0, -0.06, zt + 0.20), M["black"], verts=36, bevel=0, name="cercle")
        k.cyl(0.30, zg - 0.33 - zt, (0, -0.06, (zt + zg - 0.33) / 2), M["galva"], verts=36, name="fut")
        for sx in (-1, 1):   # vérins hydrauliques, du tambour au caisson
            k.cyl(0.07, zg - zt - 0.42, (sx * 0.44, -0.06, (zt + 0.24 + zg - 0.36) / 2), M["main"], verts=16, name="verin")
            k.cyl(0.04, 0.2, (sx * 0.44, -0.06, zg - 0.40), M["galva"], verts=12, name="tige")
        k.box((0.80, 0.96, 0.66), (0, -0.10, zg), M["main"], bevel=0.025, name="caisson")
        for i in range(7):
            k.box((0.82, 0.06, 0.12), (0, -0.52 + i * 0.13, zg - 0.36), M["black"] if i % 2 else M["main"], bevel=0,
                  name="chevron")
        # bidons-chargeurs relevés de 0,08 (reprise 4) : ils portent le sommet en poses E et O, qui doit rester au-dessus
        # de celui de l'époque 3 (O par pose non décroissant, vérification adverse, majeur 1)
        # bidons plus gros et plus écartés (rayon 0,28, x = ±0,70, reprise 4) : tête plus large (ère II) et sommet des
        # poses E et O plus près de celui de la pose N
        zbd = zg + 0.10
        for sx in (-1, 1):
            k.cyl(0.28, 0.82, (sx * 0.70, -0.08, zbd), M["galva"], axis="y", verts=36, bevel=0.012, name="bidon")
            for yy in (-0.32, 0.18):
                k.tor(0.284, 0.022, (sx * 0.70, yy, zbd), M["black"], axis="y", name="cercle")
            k.cyl(0.24, 0.035, (sx * 0.70, 0.34, zbd), M["black"], axis="y", verts=28, name="fond")
            k.cyl(0.07, 0.10, (sx * 0.40, 0.10, zg - 0.06), M["galva"], axis="x", verts=12, name="goulotte")
        k.gatling(3, 0.11, 0.05, 0.40, 1.22, 0.0, zg - 0.05, M["gun"], M["galva"], rings=(0.08, 0.6, 0.95),
                  phase=math.pi / 2)
        zr = zg + 0.33
        # garde-corps de toit plus haut (0,32 au lieu de 0,26, reprise 4) : sommet en pose S au-dessus de l'époque 3
        for x, y in ((-0.36, -0.54), (0.36, -0.54), (-0.36, 0.30), (0.36, 0.30)):
            k.cyl(0.018, 0.32, (x, y, zr + 0.16), M["galva"], verts=8, bevel=0, name="poteau")
        k.box((0.74, 0.028, 0.028), (0, -0.54, zr + 0.31), M["galva"], bevel=0, name="lisse")
        k.box((0.028, 0.86, 0.028), (-0.36, -0.12, zr + 0.31), M["galva"], bevel=0, name="lisse")
        k.box((0.028, 0.86, 0.028), (0.36, -0.12, zr + 0.31), M["galva"], bevel=0, name="lisse")
        # voyant monté sur un pied de 0,20 (reprise 4) : le garde-corps relevé passait devant lui en pose E (zone
        # lumineuse coupée en deux : 6 px au mieux, D2-1 en échec au 1er aperçu de la reprise 4)
        k.cyl(0.05, 0.20, (0.14, -0.28, zr + 0.10), M["black"], verts=20, name="voyant_pied")
        k.sph(0.095, (0.14, -0.28, zr + 0.30), M["emit"], seg=20, rings=10, name="voyant")
        k.box((0.34, 0.34, 0.12), (-0.10, -0.24, zr + 0.06), M["galva"], bevel=0.012, name="trappe")
        k.halo((0.14, -0.28, zr + 0.40), emit_rgb("#FF8C1A"), 20.0)
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
            # frein de bouche plus haut (0,24, reprise 4) : il porte le sommet en pose N (marge sur l'époque 4)
            k.box((0.24, 0.18, 0.24), (sx * 0.20, 1.06, zg - 0.13), M["main"], bevel=0.015, name="frein")
            k.rivets_line((sx * 0.52, -0.62, zg + 0.50), (sx * 0.52, -0.62, zg - 0.32), 5, 0.035, M["rouille"])
            k.box((0.05, 0.36, 0.16), (sx * 0.545, -0.24, zg + 0.04), M["emit"], bevel=0, name="braise")
        k.box((0.40, 0.05, 0.22), (0, -0.67, zg + 0.10), M["emit"], bevel=0, name="braise")
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
        # grappe AVANCÉE près de l'axe (y = -0,10 au lieu de -0,36) et cristal maître presque vertical (reprise 4,
        # vérification adverse, majeur 1) : en arrière, elle ne portait le sommet qu'en pose S (O = 1,48) ; en poses
        # N, E et O la tourelle rapetissait (1,17 à 1,20 contre 1,30 à 1,33 à l'époque 6). L'asymétrie de la grappe
        # reste dans les petits cristaux (longueurs et inclinaisons inégales)
        base = (0.0, -0.10, zg + 0.30)
        k.cyl(0.22, 0.12, (base[0], base[1], base[2] - 0.02), M["main"], verts=7, name="sertissure")
        for j, (L, ax, ay, r) in enumerate(((1.02, 0.02, -0.03, 0.13), (0.80, -0.30, -0.04, 0.11),
                                            (0.70, 0.30, 0.02, 0.10), (0.52, -0.10, 0.26, 0.09),
                                            (0.46, 0.18, -0.30, 0.08))):
            tip = (base[0] + ax * L, base[1] + ay * L, base[2] + L)
            k.spike((base[0] + ax * 0.06, base[1] + ay * 0.06, base[2]), tip, r, M["emit"], sides=6, name="cristal")
        k.halo((0, -0.10, zg + 0.8), emit_rgb("#B070FF"), 20.0)
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
        # bulbe AVANCÉ au-dessus du milieu de la capsule (y = -0,10 au lieu de -0,36) et réduit (rayon 0,39 au lieu de
        # 0,45) (reprise 4, vérification adverse, majeur 1 et mineur 5) : en arrière, il ne portait le sommet qu'en
        # pose S (pose N : 1,27, plus bas que l'époque 7 pose par pose) ; part émissive de 15 à 21 % réduite
        yb, rb = -0.10, 0.39
        zb = zg + 0.30 + 0.16 + rb - 0.04
        k.cyl(0.18, 0.20, (0, yb, zg + 0.36), M["main"], verts=24, name="col")
        # bulbe de LIQUIDE luminescent tenu par une cage vert-de-gris (3 méridiens) : le verre opaque du premier
        # aperçu cachait le liquide (0 px de lueur, aucun halo la nuit : D2-1 en échec, 21/10)
        k.sph(rb, (0, yb, zb), M["emit"], seg=40, rings=20, name="bulbe_liquide")
        for j in range(3):
            k.tor(rb + 0.008, 0.022, (0, yb, zb), M["main"], axis=(math.pi / 2, 0, j * math.pi / 3), mseg=8, name="cage")
        k.tor(rb + 0.01, 0.035, (0, yb, zb - 0.02), M["main"], name="frette")
        k.cyl(0.12, 0.12, (0, yb, zb + rb + 0.03), M["main"], verts=20, name="bouchon")
        k.halo((0, yb, zb), emit_rgb("#A8FF3A"), 20.0)
        return
    if e == 9:
        # ATOME : tête octogonale plombée chanfreinée, 2 canons à manchons, hublot vert, tour de refroidissement
        zt = turntable(k, z0, 0.70, M["main"], M["jaune"])
        k.cyl(0.38, zg - 0.40 - zt, (0, -0.06, (zt + zg - 0.40) / 2), M["beton"], verts=8, spin=math.pi / 8, name="fut")
        k.cyl(0.40, 0.08, (0, -0.06, zt + 0.12), M["jaune"], verts=8, spin=math.pi / 8, name="bande")
        # octogone élargi (reprise 3) : IoU(époque 8, époque 9) = 0,86 en pose N au 1er aperçu (> 0,85, D1-2) ; la
        # tête plombée, large et à pans, se distingue du bulbe rond de l'époque 8
        k.cyl(0.66, 0.58, (0, -0.08, zg), M["main"], verts=8, spin=math.pi / 8, bevel=0.025, name="octogone")
        k.cyl(0.66, 0.16, (0, -0.08, zg + 0.37), M["main"], r2=0.44, verts=8, spin=math.pi / 8, bevel=0.012, name="chanfrein")
        k.cyl(0.50, 0.14, (0, -0.08, zg - 0.36), M["main"], r2=0.66, verts=8, spin=math.pi / 8, bevel=0.012, name="chanfrein_bas")
        k.cyl(0.67, 0.08, (0, -0.08, zg - 0.20), M["jaune"], verts=8, spin=math.pi / 8, bevel=0, name="bande")
        for sx in (-1, 1):
            k.cyl(0.055, 0.78, (sx * 0.18, 0.84, zg - 0.05), M["gun"], axis="y", verts=14, name="canon")
            k.cyl(0.10, 0.44, (sx * 0.18, 0.66, zg - 0.05), M["main"], axis="y", verts=8, name="manchon")
            for yy in (0.48, 0.58, 0.68, 0.78):
                k.cyl(0.125, 0.03, (sx * 0.18, yy, zg - 0.05), M["main"], axis="y", verts=8, name="ailette")
        k.cyl(0.15, 0.045, (0, 0.54, zg + 0.10), M["jaune"], axis="y", verts=28, name="hublot_cadre")
        k.cyl(0.12, 0.05, (0, 0.545, zg + 0.10), M["emit"], axis="y", verts=28, name="hublot")
        for sx in (-1, 1):   # deux hublots de toit, devant la tour (visibles dans les 4 poses)
            k.cyl(0.085, 0.04, (sx * 0.27, 0.20, zg + 0.44), M["emit"], verts=24, name="hublot_toit")
        hb = zg + 0.36
        # tour de refroidissement hyperboloïde SUR L'AXE (reprise 4, vérification adverse, majeur 1) : décentrée en
        # (0,22 ; -0,46), elle portait le sommet en poses S (1,73) et O (1,56) mais pas en N (1,08) ni en E (1,25) :
        # la tourelle rapetissait pose par pose. Asymétrie reportée sur la plaque et les évents latéraux
        tx, ty = 0.0, -0.06
        k.cyl(0.30, 0.36, (tx, ty, hb + 0.18), M["beton"], r2=0.19, verts=32, name="hyper_bas")
        k.cyl(0.19, 0.34, (tx, ty, hb + 0.53), M["beton"], r2=0.27, verts=32, name="hyper_haut")
        k.tor(0.27, 0.02, (tx, ty, hb + 0.70), M["jaune"], name="hyper_levre")
        k.box((0.10, 0.30, 0.16), (-0.62, -0.20, zg + 0.10), M["jaune"], bevel=0.008, name="event")
        k.box((0.30, 0.05, 0.20), (0.0, -0.715, zg), M["jaune"], bevel=0, name="plaque")
        k.halo((0, 0.3, zg + 0.2), emit_rgb("#5CFF4A"), 20.0)
        return
    if e == 10:
        # HAUTE TECHNOLOGIE : dôme caréné, 4 canons courts dans un manchon, capteur optique ; col élancé
        zt = turntable(k, z0, 0.46, M["noir"], M["main"])
        k.cyl(0.22, zg - zt, (0, 0.0, (zt + zg) / 2), M["main"], r2=0.17, verts=32, name="col")
        k.cyl(0.29, 0.12, (0, 0.0, zt + 0.12), M["noir"], verts=32, name="bague")
        # bague lumineuse du col HAUTE de 0,19 (reprise 4) : 0,05 donnait 2 à 3 px hr ; 0,19 = 8,6 px hr, visible
        # dans les 4 poses sous la tête (D2-1 : aucune zone de 8 × 8 en poses N, E et O, vérification adverse)
        k.cyl(0.235, 0.19, (0, 0.0, zt + 0.285), M["emit"], verts=32, bevel=0, name="bague_lueur")
        m0 = k.mark()
        k.cyl(0.56, 0.24, (0, -0.06, zg - 0.14), M["noir"], verts=48, bevel=0.025, name="jupe")
        k.cyl(0.565, 0.06, (0, -0.06, zg - 0.05), M["emit"], verts=48, bevel=0, name="bandeau")
        # dôme plus haut (0,95 au lieu de 0,80, reprise 4) : sommet en poses E, O et S au plus près de la pose N
        k.sph(0.56, (0, -0.06, zg - 0.02), M["main"], scale=(1, 1, 0.95), seg=48, rings=24, name="dome")
        # manchon raccourci (bout à y = 0,85) et 4 canons qui en SORTENT de 0,37 (reprise 4, vérification adverse,
        # mineur 3 : en pose N, pose par défaut, aucun canon n'était lisible) ; les tubes (5,8 px hr chacun) sont des
        # tiges fines : ils ne comptent pas dans O, le manchon (masse) reste sous le profil voulu
        k.cyl(0.19, 0.58, (0, 0.56, zg + 0.02), M["main"], axis="y", verts=36, bevel=0.012, name="manchon")
        k.gatling(4, 0.10, 0.036, 0.80, 1.22, 0.0, zg + 0.02, M["gun"], M["noir"], rings=(0.08,), phase=math.pi / 4)
        k.cyl(0.195, 0.05, (0, 0.85, zg + 0.02), M["emit"], axis="y", verts=36, bevel=0, name="anneau")
        k.sph(0.13, (0.0, 0.22, zg + 0.40), M["noir"], seg=24, rings=12, name="capteur")
        k.cyl(0.085, 0.035, (0.0, 0.33, zg + 0.41), M["emit"], axis="y", verts=24, name="lentille")
        k.cyl(0.014, 0.95, (-0.26, -0.36, zg + 0.70), M["noir"], verts=8, bevel=0, name="antenne")
        k.halo((0, -0.06, zg), emit_rgb("#3AA8FF"), 20.0)
        k.body_marks = (m0, None)
        return
    if e == 11:
        # TITANE : fuseau effilé à ailerons (dorsal et latéraux), 2 canons longs ; mât de titane.
        # Reprise 4 (vérification adverse, majeur 1 et mineur 3) : les grands ailerons latéraux (x = ±0,80, relevés)
        # portaient le sommet en poses E et O (1,94) et l'aileron dorsal (y = -0,72) en pose S ; en pose N, rien ne
        # dépassait du fuseau (O = 1,50 contre 1,83 à l'époque 10) et les canons (r = 0,042) étaient invisibles.
        # Désormais : canons montés SUR les flancs du fuseau, gainés (fourreaux = masses, sommet en pose N) et
        # prolongés de tubes fins ; ailerons latéraux plus courts et plus bas ; aileron dorsal en flèche au milieu
        # du dos ; chargeur sous le fuseau (alimentation en munitions, mineur 3).
        zt = turntable(k, z0, 0.40, M["titane"], M["main"])
        k.cyl(0.16, zg - zt, (0, -0.12, (zt + zg) / 2), M["titane"], r2=0.12, verts=24, name="mat")
        k.cyl(0.23, 0.14, (0, -0.12, zg - 0.30), M["titane"], verts=24, name="rotule")
        m0 = k.mark()
        k.cyl(0.32, 0.95, (0, 0.12, zg), M["main"], axis="y", r2=0.14, verts=36, bevel=0.012, name="fuseau")
        k.sph(0.32, (0, -0.35, zg), M["main"], scale=(1, 1.3, 1), seg=28, rings=14, name="queue")
        k.cyl(0.325, 0.12, (0, -0.08, zg), M["emit"], axis="y", verts=36, bevel=0, name="ligne")
        for sx in (-1, 1):
            k.box((0.07, 0.42, 0.12), (sx * 0.19, 0.36, zg + 0.10), M["titane"], bevel=0.01, name="support")
            k.cyl(0.07, 0.52, (sx * 0.21, 0.48, zg + 0.20), M["titane"], axis="y", verts=16, name="fourreau")
            k.cyl(0.075, 0.05, (sx * 0.21, 0.74, zg + 0.20), M["emit"], axis="y", verts=16, bevel=0, name="bague_canon")
            k.cyl(0.042, 0.62, (sx * 0.21, 1.00, zg + 0.20), M["titane"], axis="y", verts=12, name="canon")
        # chargeur à bande sous le fuseau (munitions)
        k.box((0.24, 0.32, 0.20), (0, 0.10, zg - 0.36), M["titane"], bevel=0.015, name="chargeur")
        k.box((0.20, 0.06, 0.22), (0, 0.29, zg - 0.22), M["dark"], rot=(0.5, 0, 0), bevel=0.0, name="bande")
        # aileron dorsal en flèche, au milieu du dos (mince : il ne compte qu'en poses E et O)
        k.prism_x([(-0.45, zg + 0.20), (0.05, zg + 0.28), (-0.28, zg + 0.80)], 0.0, 0.06, M["aileron"], bevel=0.008,
                  name="aileron_dorsal")
        k.prism_x([(-0.31, zg + 0.46), (-0.21, zg + 0.48), (-0.27, zg + 0.72), (-0.32, zg + 0.70)], 0.0, 0.075,
                  M["emit"], bevel=0, name="ligne_aileron")
        for sx in (-1, 1):
            k.prism_y([(sx * 0.20, zg - 0.04), (sx * 0.66, zg + 0.08), (sx * 0.62, zg + 0.19), (sx * 0.20, zg + 0.12)],
                      -0.45, 0.30, M["aileron"], bevel=0.008, name="aileron_lat")
        k.halo((0, -0.08, zg + 0.1), emit_rgb("#BFE6FF"), 20.0)
        k.body_marks = (m0, None)
        return
    if e == 12:
        # SUPRACONDUCTEURS : fusil à rail flottant au-dessus du socle annulaire (aucun mât : vide)
        k.cyl(0.22, 0.08, (0, 0, z0 + 0.06), M["chrome"], verts=36, name="emetteur")
        k.cyl(0.12, 0.03, (0, 0, z0 + 0.115), M["emit"], verts=28, name="emetteur_lueur")
        m0 = k.mark()
        # Reprise 4 (vérification adverse, majeur 1) : noyau long et bas, culasse à y = -0,76 et anneaux jusqu'à
        # y = 0,98 : sommets aux deux bouts en poses N et S (2,06), mais 1,64 en poses E et O, contre 1,94 à
        # l'époque 11. Noyau recentré et plus haut (masse sur l'axe), anneaux d'accélération regroupés au milieu
        # des rails ; les rails (9 × 15 cm, 7,5 px hr) dépassent seuls vers l'avant (tiges fines).
        k.box((0.72, 0.80, 0.68), (0, -0.05, zg + 0.11), M["main"], bevel=0.035, name="noyau")
        k.box((0.66, 0.70, 0.07), (0, -0.05, zg + 0.46), M["givre"], bevel=0.025, name="givre")
        k.box((0.40, 0.24, 0.28), (0, -0.55, zg + 0.04), M["chrome"], bevel=0.025, name="culasse")
        for sx in (-1, 1):
            k.box((0.09, 1.70, 0.15), (sx * 0.16, 0.40, zg - 0.03), M["chrome"], bevel=0.012, name="rail")
            k.box((0.06, 0.60, 0.12), (sx * 0.38, -0.05, zg + 0.05), M["emit"], bevel=0, name="flanc_lueur")
        for yy in (0.40, 0.58, 0.76):
            k.tor(0.30, 0.055, (0, yy, zg - 0.03), M["chrome"], axis="y", mseg=12, name="anneau")
            k.tor(0.24, 0.035, (0, yy, zg - 0.03), M["emit"], axis="y", name="anneau_lueur")
        # colonne d'anneaux chromés en lévitation entre l'émetteur du socle et la tête (signature de l'époque :
        # « anneaux en lévitation », vides entre eux) ; ils tournent avec la tête (couche object)
        m1 = k.mark()
        z_lo, z_hi = z0 + 0.36, zg - 0.50
        n = max(3, int(round((z_hi - z_lo) / 0.36)) + 1)
        for i in range(n):
            t = i / (n - 1)
            k.tor(0.20 + 0.14 * t, 0.034 + 0.012 * t, (0, -0.05 * t, z_lo + (z_hi - z_lo) * t), M["chrome"], name="lev")
        k.halo((0, 0.3, zg), emit_rgb("#4AF0FF"), 20.0)
        k.body_marks = (m0, m1)
        return
    if e == 13:
        # FUSION : canon à plasma, tête sphérique ceinturée d'un tore de plasma, 2 canons courts ; col de cuivre
        k.cyl(0.19, zg - z0 - 0.40, (0, 0, (z0 + zg - 0.40) / 2), M["cuivre"], verts=28, name="col")
        zz = z0 + 0.30
        while zz < zg - 0.62:
            k.tor(0.22, 0.045, (0, 0, zz), M["main"], name="bague")
            zz += 0.30
        m0 = k.mark()
        k.sph(0.48, (0, -0.05, zg), M["main"], seg=48, rings=24, name="sphere")
        # tore de plasma plus fin (0,065 au lieu de 0,08, reprise 4 : part émissive de 25 % ; vérification adverse,
        # mineur 5)
        k.tor(0.66, 0.065, (0, -0.05, zg - 0.02), M["emit"], seg=72, mseg=14, name="tore")
        k.tor(0.49, 0.035, (0, -0.05, zg - 0.02), M["cuivre"], name="ceinture")
        for j in range(6):
            a = TAU * j / 6
            k.box((0.06, 0.20, 0.06), (0.56 * math.cos(a), -0.05 + 0.56 * math.sin(a), zg - 0.02), M["cuivre"],
                  rot=(0, 0, a), bevel=0, name="agrafe")
        # canons PROLONGÉS au-delà du tore (reprise 4, vérification adverse, mineur 3 : ils n'en dépassaient que de
        # 3 px au zoom 1) : fût de cuivre gainé jusqu'au tore, puis tube fin (8,5 px hr : tige fine, hors de O) et
        # cœur de plasma à la bouche
        # (canons sur l'axe du tore, fût prolongé jusqu'à y = 0,84 : sommet en pose N au-dessus de l'époque 12)
        for sx in (-1, 1):
            k.cyl(0.085, 0.50, (sx * 0.18, 0.59, zg), M["cuivre"], axis="y", verts=18, name="fut_canon")
            k.cyl(0.055, 0.44, (sx * 0.18, 1.04, zg), M["main"], axis="y", verts=14, name="canon")
            k.cyl(0.07, 0.04, (sx * 0.18, 0.88, zg), M["cuivre"], axis="y", verts=14, name="bague")
            k.sph(0.05, (sx * 0.18, 1.25, zg), M["emit2"], seg=14, rings=7, name="coeur")
        k.sph(0.14, (0, -0.12, zg + 0.48), M["cuivre"], seg=18, rings=9, name="injecteur")
        k.halo((0, -0.05, zg), emit_rgb("#FF4FD8"), 22.0)
        k.body_marks = (m0, None)
        return
    if e == 14:
        # ORBITE : tête-satellite, bus en feuille d'or, 2 canons, 2 petits panneaux dorés, parabole de visée
        k.cyl(0.15, zg - z0 - 0.26, (0, 0, (z0 + zg - 0.26) / 2), M["blanc"], r2=0.11, verts=24, name="mat")
        k.cyl(0.22, 0.12, (0, 0, zg - 0.36), M["blanc"], verts=24, name="rotule")
        m0 = k.mark()
        k.box((0.52, 0.64, 0.52), (0, -0.08, zg), M["main"], bevel=0.025, name="bus")
        k.box((0.54, 0.07, 0.54), (0, 0.26, zg), M["blanc"], bevel=0.012, name="face")
        # canons écartés (x = ±0,20 au lieu de ±0,13, reprise 4) : en pose N ils passent de part et d'autre de la
        # parabole, désormais vue par la tranche (mineur 3 : aucun canon lisible en pose N)
        for sx in (-1, 1):
            k.cyl(0.058, 0.82, (sx * 0.20, 0.66, zg - 0.06), M["gun"], axis="y", verts=16, name="canon")
            k.cyl(0.075, 0.10, (sx * 0.20, 1.04, zg - 0.06), M["main"], axis="y", verts=16, name="bouche")
            k.cyl(0.025, 0.40, (sx * 0.46, -0.08, zg + 0.02), M["blanc"], axis="x", verts=8, name="bras")
            k.box((0.46, 0.38, 0.03), (sx * 0.84, -0.08, zg + 0.04), M["cells"], rot=(0, sx * 0.30, 0), bevel=0.005,
                  name="panneau")
            k.box((0.48, 0.40, 0.018), (sx * 0.84, -0.08, zg + 0.02), M["main"], rot=(0, sx * 0.30, 0), bevel=0.0,
                  name="cadre")
            # reflet bleu des cellules : bande de 0,12 (≥ 8 px hr après agrandissement, F37) ; D2-1 (pose O : 170 px
            # seulement au 1er aperçu, luminance sous la médiane du corps + 80)
            k.box((0.40, 0.20, 0.035), (sx * 0.84, -0.08, zg + 0.065), M["emit2"], rot=(0, sx * 0.30, 0), bevel=0,
                  name="reflet")
        # parabole tournée vers le côté (reprise 4, vérification adverse, majeur 1 et mineur 3) : face à l'avant, elle
        # cachait les canons en pose N ; la balise, en arrière (y = -0,24), portait le sommet en pose S seule (2,28
        # contre 1,84 en N). Balise sur l'axe, au-dessus de la parabole : même sommet dans les 4 poses
        k.cyl(0.04, 0.26, (0, -0.04, zg + 0.38), M["blanc"], verts=10, name="pied_parabole")
        k.sph(0.38, (0, -0.04, zg + 0.66), M["blanc"], scale=(0.30, 1, 1), seg=36, rings=18, name="parabole")
        k.cyl(0.025, 0.30, (0.10, -0.04, zg + 0.66), M["main"], axis="x", verts=8, name="cornet")
        k.cyl(0.035, 0.16, (0, -0.04, zg + 1.10), M["blanc"], verts=12, name="pied_balise")
        k.sph(0.10, (0, -0.04, zg + 1.20), M["emit"], seg=20, rings=10, name="balise")
        # caisson de munitions dorsal à bande (alimentation lisible, mineur 3)
        k.box((0.22, 0.24, 0.16), (-0.24, -0.18, zg + 0.34), M["blanc"], bevel=0.012, name="caisson_munitions")
        k.box((0.06, 0.30, 0.04), (-0.21, 0.08, zg + 0.29), M["dark"], rot=(0.4, 0, 0), bevel=0.0, name="bande")
        k.halo((0, -0.04, zg + 0.7), emit_rgb("#FF2A2A"), 20.0)
        k.body_marks = (m0, None)
        return
    if e == 15:
        # LÉGENDE : couronne de 6 canons en étoile flottant sur le socle-disque ; flèches ; halo ; tronçons flottants
        zz, rr = z0 + 0.38, 0.24
        while zz < zg - 0.62:
            k.cyl(rr, 0.08, (0, 0, zz), M["nacre"], verts=36, bevel=0.012, name="troncon")
            k.tor(rr + 0.008, 0.011, (0, 0, zz), M["emit"], name="troncon_lueur")
            zz += 0.42
            rr = max(0.12, rr - 0.04)
        m0 = k.mark()
        k.sph(0.34, (0, 0, zg), M["nacre"], seg=40, rings=20, name="noyau")
        k.tor(0.38, 0.05, (0, 0, zg), M["main"], name="ceinture")
        k.tor(0.36, 0.04, (0, 0, zg), M["main"], axis="y", name="ceinture2")
        for j in range(6):
            a = TAU * j / 6 + math.pi / 6
            ox, oz = math.cos(a), math.sin(a)
            base = (ox * 0.20, 0.10, zg + oz * 0.20)
            tip = (ox * 0.46, 1.12, zg + oz * 0.46)
            k.spike(base, tip, 0.074, M["canon"], sides=8, name="canon")
            mid = tuple(base[i] + (tip[i] - base[i]) * 0.55 for i in range(3))
            k.sph(0.075, mid, M["nacre"], scale=(1.0, 0.45, 1.0), seg=16, rings=8, name="frette")
            k.sph(0.038, tip, M["emit"], seg=12, rings=6, name="bouche")
        for j, (dx, dy, h) in enumerate(((0.0, -0.14, 1.12), (-0.30, -0.10, 0.74), (0.30, -0.10, 0.74),
                                         (-0.18, 0.18, 0.56), (0.18, 0.18, 0.56))):
            k.spike((dx * 0.8, dy, zg + 0.16), (dx, dy, zg + 0.16 + h), 0.09 if j == 0 else 0.075, M["main"], sides=8,
                    name="fleche")
        # anneau-halo ABAISSÉ autour de la couronne (zg + 0,40 au lieu de + 0,74, reprise 4, vérification adverse,
        # mineur 6) : anneau fin (3 à 4 px), il portait le sommet O = 2,38 à la place des masses (2,23 avec une
        # ouverture carrée de 9 px) ; ce sont désormais les flèches et la couronne qui atteignent la cible
        k.tor(0.58, 0.026, (0, -0.02, zg + 0.40), M["emit"], seg=72, name="halo")
        k.halo((0, 0, zg + 0.3), emit_rgb("#FFF2C0"), 24.0)
        k.body_marks = (m0, None)
        return
    raise ValueError(e)
