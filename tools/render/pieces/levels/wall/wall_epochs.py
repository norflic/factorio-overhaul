"""Les 15 époques du mur (bible docs/DESIGN_EPOQUES.md §5, ligne « Mur ») : modèles paramétriques.

S'exécute DANS Blender. Chaque époque e a une fonction e<NN>(k, pose, piece) :
- pose : « droit » (pièce straight_horizontal, raccord périodique sur la tuile) ou « isole » (single) ;
- piece : False = niveau impair 2e-1 (silhouette de l'époque), True = niveau pair 2e (même silhouette +
  la pièce de la bible).
Le niveau 2 (pièce d'époque 1 sur le sprite VANILLA) est construit par piece_e01 seul (rouleau de barbelé),
composé ensuite sur le sprite vanilla par le post-traitement (render_wall.py).

Repères (tuiles de jeu, origine = centre de la tuile, ty vers le sud ; z en unités Blender) :
- ligne avant au sol commune : ty = 0,48 à 0,50 (bas de la face vanilla : +0,50 à l'écran) ;
- JOINT commun des époques 2 à 15 (visual_merge_group = 0, bible §2.5) : plinthe x ∈ [-0,5 ; 0,5],
  ty ∈ [0,28 ; 0,50], z ∈ [0 ; 0,22] ; tout motif répété a une période qui divise la tuile ;
- sommet des masses (O, §1.4) visé par époque : OT[e] (plafond +1,0 tuile, pièces comprises).
"""
import math

from wall_kit import SQ2, zv
from wall_piece import EGAIN

K45 = 1.0 / SQ2

# O visé (dépassement des masses principales au-dessus du bord haut de l'emprise, en tuiles).
# Croissance linéaire de 0,25 (vanilla) à 0,85 à l'époque 15, pour que la pièce du niveau 30 (+0,15)
# reste sous le plafond de +1,0 (Q9). Bible §4 : 0,25 -> 1,00 sans marge pour la pièce.
OT = {e: round(0.25 + (e - 1) * 0.60 / 14, 3) for e in range(1, 16)}


def vt(e):
    """Ordonnée écran du sommet des masses de l'époque e."""
    return -0.5 - OT[e]


PL_D = (-0.5, 0.5, 0.28, 0.50, 0.0, 0.22)      # plinthe commune (joint), pose droite
PL_I = (-0.38, 0.38, 0.06, 0.50, 0.0, 0.18)     # plinthe de la pose isolée


def plinth(k, pose, mat, name="plinthe"):
    x0, x1, t0, t1, z0, z1 = PL_D if pose == "droit" else PL_I
    return k.box(x0, x1, t0, t1, z0, z1, mat, name, bev=0.012)


def span(pose):
    """Largeur du corps : la pose droite couvre toute la tuile ; l'isolée est un pilier court."""
    return (-0.5, 0.5) if pose == "droit" else (-0.31, 0.31)


# =====================================================================================================
# Époque 1 · Pionnier : niveau 1 = vanilla ; niveau 2 = rouleau de barbelé sur la crête
# =====================================================================================================
# Crête vanilla reconstituée dans le repère du pipeline (mesures hr-wall-horizontal / hr-wall-single :
# chape claire de -0,75 à -0,53 à l'écran, bord avant du dessus vers -0,62) : dessus de la chape à
# z = 1,33 pour ty = 0,26.
E1_T, E1_H = 0.26, 1.33


def piece_e01(k, pose):
    wire = k.metal("e01_barbele", "#4A4744", rough=0.38, metallic=0.85, grain=0.2, rust="#6B3A1E", rust_amount=0.55,
                   dirt=0.0, seed=11.0)
    clip = k.metal("e01_agrafe", "#5A5048", rough=0.45, metallic=0.7, rust="#6B3A1E", rust_amount=0.4, dirt=0.0, seed=12)
    r = 0.15
    zc = E1_H + 0.78 * r
    if pose == "droit":
        xa, xb, loops = -0.5, 0.5, 13
    else:
        xa, xb, loops = -0.30, 0.30, 8
    # concertina : deux hélices de sens opposés (boucles croisées), rayon un peu irrégulier
    for h, (ph, hand) in enumerate(((0.0, 1.0), (math.pi * 0.5, -1.0))):
        n = loops * 18
        pts = []
        for i in range(n + 1):
            s = i / n
            x = xa + (xb - xa) * s
            a = ph + hand * 2 * math.pi * loops * s
            rr = r * (1.0 + 0.06 * math.sin(3 * a + 1.3 * h))
            pts.append((x, E1_T - rr * math.cos(a) / SQ2, zc + rr * math.sin(a)))
        k.tube(pts, 0.017, wire, "concertina_%d" % h, sides=5)
    # fil de tension (bas du rouleau) et agrafes sur la chape
    k.cylx(xa, xb, E1_T + 0.02, E1_H + 0.015, 0.012, wire, "fil_tension")
    cx = (0.0,) if pose == "isole" else (-0.25, 0.25)
    for x in cx:
        k.box(x - 0.03, x + 0.03, E1_T - 0.03, E1_T + 0.05, E1_H - 0.02, E1_H + 0.05, clip, "agrafe", bev=0.004)
        # chevalet en X (cornières) qui tient le rouleau, dépasse un peu au-dessus (reprise V3 : D1-1)
        for sgn in (-1, 1):
            k.tube([(x - sgn * 0.085, E1_T, E1_H + 0.01), (x + sgn * 0.085, E1_T, zc + r + 0.05)], 0.013, clip,
                   "chevalet", sides=4, smooth=False)
    # barbes : petites croix le long du fil supérieur (texture lisible au zoom 2)
    n = int(round((xb - xa) * 22))
    for i in range(n):
        x = xa + (i + 0.5) * (xb - xa) / n
        a = 2 * math.pi * loops * (i + 0.5) / n
        k.box(x - 0.018, x + 0.018, E1_T - 0.005, E1_T + 0.005, zc + r * 0.95 - 0.004 + 0.02 * math.sin(a),
              zc + r * 0.95 + 0.004 + 0.02 * math.sin(a), wire, "barbe", bev=0)


# =====================================================================================================
# Époque 2 · Forge : pierre plaquée d'acier boulonné, merlons d'acier (2 par tuile)
# Pièce (niveau 4) : pique d'acier au centre de chaque tuile (+0,12), sur une crête de piques
# =====================================================================================================
def e02(k, pose, piece):
    stone = k.stone("e02_pierre", "#6A6258", mul=1.0, grain=0.3, seed=21)
    steel = k.metal("e02_acier", "#5C6168", mul=1.15, rough=0.36, metallic=0.75, grain=0.16, rust="#5A3A24",
                    rust_amount=0.25, dirt=0.45, seed=22)
    band = k.metal("e02_cerclage", "#2E2C2A", mul=1.2, rough=0.4, metallic=0.85, dirt=0.3, seed=23)
    brass = k.metal("e02_laiton", "#8C7440", mul=1.3, rough=0.25, metallic=0.95, grain=0.1, dirt=0.0, seed=24)
    cap = k.stone("e02_chape", "#8A8278", mul=1.1, grain=0.25, seed=26)
    plinth(k, pose, k.stone("e02_socle", "#4E4842", grain=0.3, seed=25))
    xa, xb = span(pose)
    if pose == "droit":
        t0, t1 = 0.20, 0.46
        zc = zv(-0.30, t0)            # fond des créneaux, bas : la crête devient crénelée (Δ époque 1)
        merl = (-0.25, 0.25)
        mw = 0.125
    else:
        t0, t1 = 0.12, 0.46
        zc = zv(-0.40, t0)
        merl = (-0.20, 0.20)
        mw = 0.10
    k.box(xa, xb, t0, t1, 0.18, zc, stone, "mur")
    # plaques d'acier boulonnées sur la face avant
    plates = ((xa + 0.02, -0.02), (0.02, xb - 0.02))
    for a, b in plates:
        k.box(a, b, t1, t1 + 0.018, 0.27, zc - 0.07, steel, "plaque", bev=0.006)
        for rx in (a + 0.035, (a + b) / 2, b - 0.035):
            for rz in (0.31, zc - 0.11):
                k.rivet(rx, t1 + 0.02, rz, 0.014, brass)
    k.box(xa, xb, t1 + 0.012, t1 + 0.03, 0.56, 0.63, band, "cerclage", bev=0.004)
    for rx in [xa + (i + 0.5) * (xb - xa) / 6 for i in range(6)]:
        k.rivet(rx, t1 + 0.032, 0.595, 0.012, brass)
    # merlons d'acier : bloc de pierre chemisé d'acier, chapeau débordant
    zm = zv(vt(2) + 0.012, t0 - 0.01)
    for cx in merl:
        k.box(cx - mw, cx + mw, t0 - 0.005, t1 + 0.005, zc - 0.02, zm - 0.035, steel, "merlon", bev=0.008)
        k.box(cx - mw - 0.012, cx + mw + 0.012, t0 - 0.012, t1 + 0.014, zm - 0.04, zm, cap, "chapeau", bev=0.006)
        for rz in (zc + 0.06, zm - 0.10):
            for rx in (cx - mw + 0.03, cx + mw - 0.03):
                k.rivet(rx, t1 + 0.008, rz, 0.013, brass)
        if pose == "isole":     # merlons arrière (pilier crénelé aux 4 coins)
            k.box(cx - mw, cx + mw, t0 - 0.005, t0 + 0.09, zc - 0.02, zm - 0.035, steel, "merlon_ar", bev=0.008)
    # rebord de crénelage (chaperon de fonte sur le fond des créneaux)
    k.box(xa, xb, t0 - 0.01, t1 + 0.012, zc - 0.03, zc, cap, "chaperon", bev=0.005)
    k.flush_rivets()
    if piece:
        # Reprise V3 (21/10) : pique d'acier dressée sur un MANTELET riveté qui ferme le créneau central (la
        # pique seule, 0,05 tuile de large, n'ajoutait que 0,05 t² au masque : D1-1) ; piques sur les merlons.
        tc = (t0 + t1) / 2
        hwm = 0.10 if pose == "droit" else 0.075
        zmt = zc + 0.30
        k.box(-hwm, hwm, tc - 0.03, tc + 0.03, zc - 0.01, zmt, steel, "mantelet", bev=0.008)
        k.box(-hwm - 0.01, hwm + 0.01, tc - 0.04, tc + 0.04, zmt - 0.045, zmt, band, "cerclage_mantelet", bev=0.004)
        for rx in (-hwm + 0.03, hwm - 0.03):
            for rz in (zc + 0.06, zmt - 0.09):
                k.rivet(rx, tc + 0.033, rz, 0.014, brass)
        k.flush_rivets()
        ztip = zv(vt(2) - 0.12, tc)
        k.cylv(0.0, tc, zmt, ztip - 0.15, 0.026, steel, "hampe", verts=8)
        k.tor_h(0.0, tc, zmt + 0.10, 0.034, 0.012, brass, "bague")
        k.pyr(0.0, tc, ztip - 0.17, ztip, 0.075, steel, "fer_de_pique", sides=4)
        k.box(-0.11, 0.11, tc - 0.02, tc + 0.02, ztip - 0.19, ztip - 0.16, band, "garde", bev=0.004)
        for cx in merl:
            for dx in (-mw * 0.55, 0.0, mw * 0.55):
                k.pyr(cx + dx, tc, zm - 0.01, zm + 0.13, 0.034, steel, "pointe", sides=4)
        # lisse d'acier qui porte les piques d'un merlon à l'autre (traverse le créneau)
        k.box(xa, xb, tc - 0.015, tc + 0.015, zm - 0.015, zm + 0.025, band, "lisse", bev=0.004)


# =====================================================================================================
# Époque 3 · Vapeur : brique, tuyau de cuivre le long de la crête, une colonnette-cheminée par tuile
# Pièce (niveau 6) : globe de lanterne à vapeur sur la colonnette (+0,15)
# =====================================================================================================
def e03(k, pose, piece):
    # Reprise V3 (21/10) : la colonnette du premier modeleur ne dépassait la crête que de 0,16 tuile (souche
    # illisible). Le parapet de brique descend à -0,42 et la colonnette-cheminée monte franchement à O(3) :
    # crête « en piquets » lisible en rangée ; pilastres de brique aux joints (facettes ouest éclairées).
    brick = k.brick("e03_brique", "#8E6654", "#7C5A4A", "#6A625A", mul=1.0)
    iron = k.metal("e03_fonte", "#3A3634", mul=1.25, rough=0.5, metallic=0.6, grain=0.22, rust="#5A3424",
                   rust_amount=0.3, dirt=0.4, seed=31)
    copper = k.metal("e03_cuivre", "#8A5A3A", mul=1.35, rough=0.28, metallic=0.95, grain=0.14, rust="#3E6A55",
                     rust_amount=0.22, dirt=0.25, seed=32)
    brass = k.metal("e03_laiton", "#9C7E45", mul=1.25, rough=0.25, metallic=0.95, grain=0.1, dirt=0.0, seed=33)
    amber = k.emit("e03_ambre", "#FFC060", strength=3.0, base="#3A2A10")
    soot = k.flat("e03_suie", "#141210", rough=0.95)
    coping = k.stone("e03_chape", "#9A9084", mul=0.8, grain=0.22, seed=34)
    plinth(k, pose, iron)
    xa, xb = span(pose)
    if pose == "droit":
        t0, t1 = 0.20, 0.46
    else:
        t0, t1 = 0.12, 0.46
    zc = zv(-0.42, t0)
    k.box(xa, xb, t0, t1, 0.18, zc, brick, "mur_brique", bev=0.004)
    k.box(xa, xb, t0 - 0.02, t1 + 0.02, zc, zc + 0.055, coping, "chaperon", bev=0.006)
    # pilastres aux joints (droit : à cheval sur deux tuiles, x = ±0,5 ; isolé : aux arêtes)
    for a, b in ((xa, xa + 0.07), (xb - 0.07, xb)):
        k.box(a, b, t1, t1 + 0.04, 0.2, zc - 0.02, brick, "pilastre", bev=0.006)
        k.box(a, b, t1 - 0.01, t1 + 0.05, zc - 0.06, zc - 0.02, iron, "chapiteau_pilastre", bev=0.004)
    # tuyau de cuivre le long de l'avant de la crête, brides au raccord des tuiles, colliers
    zp = zc + 0.055 + 0.05
    k.cylx(xa, xb, t1 - 0.03, zp, 0.05, copper, "tuyau")
    for x in ((xa, xa + 0.03), (xb - 0.03, xb)):
        k.cylx(x[0], x[1], t1 - 0.03, zp, 0.066, brass, "bride")
    for x in ((-0.28, 0.28) if pose == "droit" else (-0.2, 0.2)):
        k.cylx(x - 0.012, x + 0.012, t1 - 0.03, zp, 0.058, iron, "collier")
    # colonnette-cheminée ronde au centre : fût de brique cerclé, collerette de fonte, bouche de suie
    tcol, rcol = (t0 + t1) / 2 - 0.03, 0.105
    ztop = zv(vt(3) + K45 * 0.125, tcol)
    k.cylv(0.0, tcol, zc + 0.04, ztop - 0.05, rcol, brick, "colonnette", verts=32)
    k.cylv(0.0, tcol, zc + 0.04, zc + 0.12, rcol + 0.02, iron, "embase_colonnette", verts=32)
    for z in (zc + 0.30, ztop - 0.16):
        k.tor_h(0.0, tcol, z, rcol + 0.006, 0.014, brass, "cerclage")
    k.cylv(0.0, tcol, ztop - 0.06, ztop, 0.125, iron, "collerette", verts=32)
    k.cylv(0.0, tcol, ztop - 0.002, ztop + 0.002, 0.095, soot, "bouche", verts=24, bev=0)
    # manomètre ambré sur la face du parapet (lueur de jour D2-1 : disque de 0,16 tuile = 10 px hr)
    zg = 0.52 if pose == "droit" else 0.50
    k.cyly(0.0, t1 - 0.005, t1 + 0.035, zg, 0.10, brass, "boitier_mano", verts=32)
    k.cyly(0.0, t1 + 0.035, t1 + 0.045, zg, 0.082, amber, "cadran", verts=32)
    k.box(-0.006, 0.006, t1 + 0.045, t1 + 0.05, zg - 0.01, zg + 0.06, iron, "aiguille", bev=0)
    k.cyly(0.0, t1 - 0.005, t1 + 0.06, zg - 0.16, 0.022, copper, "purge", verts=12)
    k.halo(0.0, t1 + 0.12, zg, "#FFC060", 6.0)
    if piece:
        # lanterne à vapeur : socle de laiton, globe ambré, cage, chapeau ; arrivée de vapeur en cuivre.
        # Reprise V3 : globe agrandi et potence à deux petites lanternes pendues (candélabre), pour que la pièce
        # se lise au zoom 1 et ajoute au moins 0,10 t² (D1-1).
        zb = ztop + 0.01
        rg = 0.095                       # hauteur totale de la lanterne : O(3) + 0,20 au plus
        k.cylv(0.0, tcol, zb, zb + 0.04, 0.085, brass, "socle_lanterne", verts=24)
        k.sph(0.0, tcol, zb + 0.04 + rg, rg, amber, "globe")
        bars = []
        for i in range(6):
            a = 2 * math.pi * (i + 0.5) / 6
            bars.append(k.cylv((rg + 0.008) * math.cos(a), tcol - (rg + 0.008) * math.sin(a) / SQ2, zb + 0.04,
                               zb + 0.04 + 2 * rg + 0.01, 0.008, brass, "barreau", verts=6, bev=0))
        k.S.join(bars, "cage")
        zh = zb + 0.04 + 2 * rg
        k.cylv(0.0, tcol, zh, zh + 0.06, 0.15, iron, "chapeau", verts=24, r2=0.035)
        xs = 0.28 if pose == "droit" else 0.21
        za = zb + 0.03
        k.cylx(-xs, xs, tcol, za, 0.016, brass, "potence")
        for sgn in (-1, 1):
            k.tube([(sgn * 0.10, tcol, za), (sgn * 0.05, tcol, za - 0.12)], 0.012, brass, "console", sides=6,
                   smooth=False)
            x = sgn * xs
            k.cylv(x, tcol, za - 0.03, za + 0.005, 0.012, brass, "crochet", verts=8, bev=0)
            k.cylv(x, tcol, za - 0.075, za - 0.03, 0.085, iron, "chapeau_petit", verts=20, r2=0.03)
            k.sph(x, tcol, za - 0.075 - 0.065, 0.065, amber, "globe_petit", seg=20, rings=10)
            k.halo(x, tcol + 0.12, za - 0.14, "#FFC060", 4.0)
        # tuyau d'alimentation en vapeur : du tuyau de crête jusqu'au socle de la lanterne, le long du fût
        xo = 0.30 if pose == "droit" else 0.22
        pts = []
        for i in range(17):
            s = i / 16.0
            x = xo * (1 - s) ** 1.6 + (rcol + 0.03) * s
            z = zp + (zb + 0.02 - zp) * math.sin(s * math.pi / 2)
            pts.append((x, t1 - 0.03 - (t1 - 0.03 - tcol) * s, z))
        k.tube(pts, 0.026, copper, "arrivee_vapeur", sides=8)
        k.halo(0.0, tcol + 0.15, zb + 0.16, "#FFC060", 9.0)


# =====================================================================================================
# Époque 4 · Pétrole : béton peint à bandes jaunes et noires, garde-corps et poteaux sur la crête
# Pièce (niveau 8) : feu d'avertissement orange sur chaque poteau (+0,15)
# =====================================================================================================
def e04(k, pose, piece):
    concrete = k.stone("e04_beton", "#7A7670", mul=1.0, grain=0.22, seed=41, stain="#5A4A30", stain_amount=0.3)
    hazard = k.stripes("e04_bandes", "#C9A227", "#1C1B1A", mul=0.9, period=0.2)
    galv = k.metal("e04_galva", "#6E7378", mul=1.25, rough=0.35, metallic=0.8, grain=0.14, rust="#6A4A2A",
                   rust_amount=0.15, dirt=0.35, seed=42)
    yellow = k.metal("e04_jaune", "#8C7A3A", mul=1.25, rough=0.45, metallic=0.4, grain=0.2, rust="#4A3A2A",
                     rust_amount=0.25, dirt=0.4, seed=43)
    orange = k.emit("e04_voyant", "#FF8C1A", strength=3.2, base="#3A1A05")
    plinth(k, pose, galv)
    xa, xb = span(pose)
    if pose == "droit":
        t0, t1 = 0.22, 0.47
        zc = zv(-0.40, t0)
        posts = (-0.25, 0.25)
    else:
        t0, t1 = 0.12, 0.47
        zc = zv(-0.40, t0)
        posts = (-0.20, 0.20)
    k.box(xa, xb, t0, t1, 0.18, zc, concrete, "mur_beton")
    k.box(xa, xb, t1, t1 + 0.012, zc - 0.30, zc - 0.06, hazard, "bande_avertissement", bev=0.003)
    k.box(xa, xb, t0 - 0.015, t1 + 0.015, zc, zc + 0.05, galv, "couvertine", bev=0.006)
    # voyant orange encastré (zone lumineuse de jour)
    k.box(-0.095, 0.095, t1 - 0.01, t1 + 0.03, 0.33, 0.58, galv, "boitier_voyant", bev=0.008)
    k.box(-0.068, 0.068, t1 + 0.03, t1 + 0.04, 0.37, 0.55, orange, "voyant")
    k.halo(0.0, t1 + 0.12, 0.46, "#FF8C1A", 5.0)
    # poteaux en H galvanisés (masses de crête, 0,15 tuile) et garde-corps (lisses fines)
    tp = (t0 + t1) / 2
    ztop = zv(vt(4), tp - 0.04)
    for x in posts:
        k.box(x - 0.075, x + 0.075, tp - 0.04, tp + 0.04, zc + 0.04, ztop - 0.04, yellow, "poteau", bev=0.01)
        k.box(x - 0.085, x + 0.085, tp - 0.05, tp + 0.05, ztop - 0.045, ztop, galv, "tete_poteau", bev=0.008)
    zr1, zr2 = ztop - 0.12, (zc + ztop) / 2
    for z in (zr1, zr2):
        k.cylx(xa, xb, tp, z, 0.02, galv, "lisse")
    k.box(xa, xb, tp - 0.006, tp + 0.006, zc + 0.05, zc + 0.12, yellow, "plinthe_garde_corps", bev=0)
    if pose == "isole":
        # garde-corps en carré autour du sommet du pilier
        for x in (xa + 0.02, xb - 0.02):
            k.cyly(x, t0, t1, zr1, 0.02, galv, "lisse_cote")
    if piece:
        for x in posts:
            zb = ztop + 0.005
            k.cylv(x, tp, zb, zb + 0.05, 0.085, galv, "socle_feu", verts=24)
            k.cylv(x, tp, zb + 0.05, zb + 0.14, 0.072, orange, "verrine", verts=24)
            k.sph(x, tp, zb + 0.14, 0.072, orange, "dome")
            cage = []
            for i in range(5):
                a = 2 * math.pi * i / 5
                cage.append(k.cylv(x + 0.066 * math.cos(a), tp - 0.066 * math.sin(a) / SQ2, zb + 0.06, zb + 0.2, 0.007,
                                   galv, "cage", verts=6, bev=0))
            k.S.join(cage, "cage_feu")
            k.tor_h(x, tp, zb + 0.2, 0.05, 0.008, galv, "cercle_cage")
            k.halo(x, tp + 0.12, zb + 0.12, "#FF8C1A", 6.0)
        # panneau d'avertissement accroché au garde-corps (entre les poteaux)
        # (reprise V3 : panneau élargi, il ferme le garde-corps entre les poteaux : D1-1)
        hp = 0.17 if pose == "droit" else 0.12
        k.box(-hp, hp, tp + 0.01, tp + 0.022, zr2 - 0.06, zr1 + 0.04, hazard, "panneau", bev=0.004)
        k.box(-hp - 0.012, hp + 0.012, tp + 0.004, tp + 0.01, zr2 - 0.07, zr1 + 0.05, galv, "cadre_panneau", bev=0)


# =====================================================================================================
# Époque 5 · Volcan : glacis (face inclinée en écailles de blindage), dents sur l'arête, joints de braise
# Pièce (niveau 10) : pointe de basalte haute au centre de chaque tuile (+0,20)
# =====================================================================================================
def e05(k, pose, piece):
    # Reprise V3 (21/10) : l'arête du premier modeleur était à -0,84 et les dents ne dépassaient que de 0,08
    # (invisibles) ; le noyau de braise brillait dans tous les joints (plaques « néon »). Ici : glacis plus bas
    # (arête à -0,56), 2 grosses dents par tuile jusqu'à O(5) (crête en scie, lisible en vignette), écailles
    # pleine largeur, braise dans les 2 joints horizontaux et l'évent central seulement.
    tung = k.metal("e05_tungstene", "#3E3D42", mul=1.35, rough=0.38, metallic=0.85, grain=0.2, rust="#5A3A2A",
                   rust_amount=0.35, dirt=0.4, seed=51)
    burnt = k.metal("e05_rouille", "#5A3A2A", mul=1.1, rough=0.6, metallic=0.5, grain=0.25, dirt=0.4, seed=52)
    ember = k.emit("e05_braise", "#FF4A10", strength=1.2, base="#200805")
    basalt = k.stone("e05_basalte", "#2E2C2C", mul=1.3, grain=0.35, seed=53)
    plinth(k, pose, burnt)
    xa, xb = span(pose)
    if pose == "droit":
        tb, tt, tback = 0.52, 0.26, 0.18
        teeth, hw0, hw1 = (-0.25, 0.25), 0.16, 0.07
    else:
        tb, tt, tback = 0.50, 0.22, 0.10
        teeth, hw0, hw1 = (-0.155, 0.155), 0.15, 0.06
    zcr = zv(-0.56, tt)
    t_at = lambda z: tb - (tb - tt) * (z - 0.12) / (zcr - 0.12)
    # noyau incandescent en retrait (visible dans les joints) et dos de la muraille
    k.prism_x([(tback, 0.0), (tb - 0.05, 0.0), (tb - 0.05, 0.12), (tt + 0.0, zcr - 0.04), (tback, zcr - 0.04)],
              xa + 0.02, xb - 0.02, ember, "noyau_braise")
    k.box(xa, xb, tback, tt + 0.03, 0.1, zcr, tung, "dos", bev=0.006)
    rows = 3
    for r in range(rows):
        f0, f1 = r / rows, (r + 1) / rows
        g = 0.03
        z0, z1 = 0.12 + (zcr - 0.12) * f0 + g, 0.12 + (zcr - 0.12) * f1 - 0.004
        segs = [(xa, xb)]
        if r == 1:      # évent central : fente de braise (zone lumineuse >= 8 x 8 px hr)
            segs = [(xa, -0.07), (0.07, xb)]
        for a, b in segs:
            off = 0.03
            quad = [(a, t_at(z0) + off, z0 - 0.03), (b, t_at(z0) + off, z0 - 0.03), (b, t_at(z1) + off * 0.3, z1),
                    (a, t_at(z1) + off * 0.3, z1)]
            k.slab(quad, 0.045, tung, "ecaille", bev=0.008)
            for rx in ((a + 0.06, b - 0.06) if b - a > 0.3 else ((a + b) / 2,)):
                k.rivet(rx, t_at(z0 + 0.06) + off + 0.025, z0 + 0.05, 0.024, burnt)
    k.flush_rivets()
    k.halo(0.0, tb + 0.05, 0.5, "#FF4A10", 7.0)
    # couvre-arête et dents trapézoïdales (crête en scie)
    k.box(xa, xb, tt - 0.09, tt + 0.05, zcr - 0.05, zcr + 0.01, burnt, "couvre_arete", bev=0.008)
    zt = zv(vt(5), tt - 0.04)
    for cx in teeth:
        prof = [(cx - hw0, zcr - 0.02), (cx + hw0, zcr - 0.02), (cx + hw1, zt), (cx - hw1, zt)]
        k.prism_t(prof, tt - 0.08, tt + 0.04, tung, "dent", bev=0.01)
        k.rivet(cx, tt + 0.045, zcr + 0.10, 0.026, burnt)
    k.flush_rivets()
    if piece:
        # orgue de basalte entre les deux dents : colonne centrale à O(5) + 0,20, deux colonnes inclinées
        tc = tt - 0.02
        ztip = zv(vt(5) - 0.20, tc)
        cols = ((0.0, 0.085, ztip, 0.0), (-0.085, 0.06, zt - 0.02, -0.10), (0.085, 0.06, zt - 0.08, 0.12))
        for x, r, zt_, tilt in cols:
            k.gem(x, tc, zcr - 0.08, r, zt_ - zcr + 0.08, basalt, "colonne_basalte", sides=6, tilt=(tilt, 0.0),
                  tip=0.22)
        # fissure de braise sur la colonne centrale (lueur, 3 px hr de large : accent, non compté en D2-1)
        k.box(-0.022, 0.022, tc + 0.062, tc + 0.07, zcr + 0.06, ztip - 0.20, ember, "fissure", bev=0)
        k.halo(0.0, tc + 0.12, zcr + 0.25, "#FF4A10", 5.0)


# =====================================================================================================
# Époque 6 · Électricité : clôture électrique (poteau à isolateurs, fils tendus au-dessus d'un muret)
# Pièce (niveau 12) : isolateur double et plaque « danger » sur le poteau (+0,15)
# =====================================================================================================
def insulator_pile(k, x, t, z0, n, r, ceramic, cap, name="pile"):
    z = z0
    for i in range(n):
        k.cylv(x, t, z, z + 0.034, r, ceramic, name + "_disque", verts=24, bev=0.008)
        k.cylv(x, t, z + 0.034, z + 0.05, r * 0.55, cap, name + "_noyau", verts=16, bev=0)
        z += 0.05
    return z


def e06(k, pose, piece):
    # Reprise V3 (21/10) : chez le premier modeleur, le poteau (0,07 tuile) et sa petite pile disparaissaient
    # au zoom 1. Ici le POTEAU EST la pile d'isolateurs (disques de céramique de 0,20 tuile, colonne
    # « crantée », signature de l'époque) ; barre de cuivre sur isolateurs le long du muret ; éclateur cyan.
    ceramic = k.metal("e06_ceramique", "#D8D4C8", mul=0.72, rough=0.22, metallic=0.0, grain=0.08, dirt=0.35, seed=61)
    steel = k.metal("e06_acier", "#5C6168", mul=1.2, rough=0.35, metallic=0.8, grain=0.15, rust="#5A3A24",
                    rust_amount=0.15, dirt=0.4, seed=62)
    copper = k.metal("e06_cuivre", "#B0703A", mul=1.0, rough=0.25, metallic=0.95, grain=0.12, dirt=0.1, seed=63)
    concrete = k.stone("e06_muret", "#6E6A64", mul=0.9, grain=0.2, seed=64)
    arc = k.emit("e06_arc", "#60D0FF", strength=1.3, base="#0A1A20")
    yellow = k.metal("e06_jaune", "#C9A227", mul=1.2, rough=0.5, metallic=0.2, grain=0.12, dirt=0.3, seed=65)
    black = k.flat("e06_noir", "#141414", rough=0.6)
    plinth(k, pose, steel)
    xa, xb = span(pose)
    t0, t1 = (0.24, 0.48) if pose == "droit" else (0.14, 0.46)
    zm = zv(-0.36, t0)
    k.box(xa, xb, t0, t1, 0.18, zm, concrete, "muret")
    k.box(xa, xb, t0 - 0.012, t1 + 0.012, zm, zm + 0.04, steel, "couvertine", bev=0.005)
    # montants d'acier aux joints (facettes ouest éclairées, rythme de la rangée)
    for a, b in ((xa, xa + 0.05), (xb - 0.05, xb)):
        k.box(a, b, t1, t1 + 0.03, 0.2, zm, steel, "montant", bev=0.005)
    # barre de cuivre sur isolateurs le long de la face du muret
    zbar = 0.50
    k.cylx(xa, xb, t1 + 0.075, zbar, 0.022, copper, "barre_cuivre", verts=12)
    for x in ((-0.25, 0.25) if pose == "droit" else (0.0,)):
        k.cyly(x, t1, t1 + 0.06, zbar, 0.032, ceramic, "isolateur_barre", verts=16)
    # poteau = pile d'isolateurs sur une embase d'acier, jusqu'à O(6)
    tp, rp = (t0 + t1) / 2, 0.10
    k.box(-0.085, 0.085, tp - 0.07, tp + 0.07, zm + 0.02, zm + 0.11, steel, "embase_pile", bev=0.01)
    z_pile_top = zv(vt(6) + K45 * rp, tp)
    n = max(4, int(round((z_pile_top - (zm + 0.11)) / 0.06)))
    z = zm + 0.11
    dz = (z_pile_top - z) / n
    for i in range(n):
        k.cylv(0.0, tp, z, z + dz * 0.68, rp, ceramic, "pile_disque", verts=24, bev=0.01)
        k.cylv(0.0, tp, z + dz * 0.68, z + dz, rp * 0.58, steel, "pile_noyau", verts=16, bev=0)
        z += dz
    k.cylv(0.0, tp, z_pile_top - 0.005, z_pile_top + 0.03, 0.055, copper, "chapeau_pile", verts=16)
    # fils tendus (cuivre) qui traversent la pile, 3 hauteurs
    for f in (0.25, 0.5, 0.75):
        zw = zm + 0.11 + f * (z_pile_top - zm - 0.11)
        k.cylx(xa, xb, tp + 0.02, zw, 0.011, copper, "fil", verts=8)
    # éclateur : cornes de cuivre et boule d'arc cyan au sommet
    zt = z_pile_top + 0.03
    for side in (-1, 1):
        k.tube([(side * 0.03, tp, zt), (side * 0.05, tp, zt + 0.05), (side * 0.09, tp, zt + 0.12)], 0.012, copper,
               "corne", sides=6)
    k.sph(0.0, tp, zt + 0.075, 0.062, arc, "arc_boule")
    k.halo(0.0, tp + 0.1, zt + 0.08, "#60D0FF", 7.0)
    if piece:
        # traverse d'acier et isolateur double (2 piles de 0,16 tuile), plaque « danger » sur le muret
        za = zm + 0.11 + 0.62 * (z_pile_top - zm - 0.11)
        xs = 0.24 if pose == "droit" else 0.20
        k.box(-xs - 0.06, xs + 0.06, tp - 0.025, tp + 0.025, za - 0.035, za + 0.01, steel, "traverse", bev=0.006)
        ztop2 = zv(vt(6) - 0.15 + K45 * 0.08, tp)
        n2 = max(3, int(round((ztop2 - za) / 0.06)))
        dz2 = (ztop2 - za) / n2
        for x in (-xs, xs):
            z = za + 0.01
            for i in range(n2):
                k.cylv(x, tp, z, z + dz2 * 0.68, 0.08, ceramic, "pile_double_disque", verts=24, bev=0.008)
                k.cylv(x, tp, z + dz2 * 0.68, z + dz2, 0.045, steel, "pile_double_noyau", verts=16, bev=0)
                z += dz2
            k.sph(x, tp, ztop2 + 0.02, 0.035, copper, "borne")
        zs = 0.30
        hw = 0.13 if pose == "droit" else 0.11
        k.box(-hw, hw, t1 + 0.012, t1 + 0.024, zs, zs + 0.17, yellow, "plaque_danger", bev=0.004)
        k.box(-hw - 0.008, hw + 0.008, t1 + 0.004, t1 + 0.012, zs - 0.008, zs + 0.178, black, "bord_plaque", bev=0)
        k.tube([(0.03, t1 + 0.028, zs + 0.15), (-0.025, t1 + 0.028, zs + 0.085), (0.02, t1 + 0.028, zs + 0.09),
                (-0.03, t1 + 0.028, zs + 0.02)], 0.012, black, "eclair_plaque", sides=4, smooth=False)


# =====================================================================================================
# Époque 7 · Cristal : muret de pierre d'où jaillissent 2 à 3 pointes de cristal par tuile
# Pièce (niveau 14) : cristal plus haut au centre (+0,20)
# =====================================================================================================
def e07(k, pose, piece):
    stone = k.stone("e07_pierre", "#4A4038", mul=1.35, grain=0.35, seed=71, stain="#2E2622", stain_amount=0.3)
    bronze = k.metal("e07_bronze", "#6A5236", mul=1.4, rough=0.3, metallic=0.9, grain=0.14, rust="#3E6A55",
                     rust_amount=0.25, dirt=0.3, seed=72)
    crystal = k.emit("e07_cristal", "#B070FF", strength=0.75, base="#7A48C8")  # facettes visibles (reprise V3)
    plinth(k, pose, k.stone("e07_socle", "#3A332E", mul=1.3, grain=0.3, seed=73))
    xa, xb = span(pose)
    t0, t1 = (0.22, 0.48) if pose == "droit" else (0.12, 0.46)
    zm = zv(-0.55, t0)
    k.box(xa, xb, t0, t1, 0.18, zm, stone, "muret", bev=0.012)
    # moellons (relief de la face) : blocs irréguliers légèrement saillants
    rows = [(0.22, 0.46), (0.48, 0.72), (0.74, zm - 0.04)]
    for i, (z0, z1) in enumerate(rows):
        n = 3 if pose == "droit" else 2
        off = (0.17 if i % 2 else 0.0)
        for j in range(n + 1):
            a = xa + ((j - 0.5) / n + off / (xb - xa)) * (xb - xa) if j else xa
            b = xa + ((j + 0.5) / n + off / (xb - xa)) * (xb - xa)
            a, b = max(a, xa) + 0.012, min(b, xb) - 0.012
            if b - a > 0.05:
                k.box(a, b, t1, t1 + 0.016, z0, z1, stone, "moellon", bev=0.012)
    k.box(xa, xb, t0 - 0.01, t1 + 0.02, zm - 0.04, zm + 0.02, bronze, "sertissure", bev=0.006)
    if pose == "droit":
        # (reprise V3 : cristaux élargis et pointes moins effilées : la masse atteint O(7), D1-2)
        spec = ((-0.30, 0.095, -0.88, 0.20, 0.05), (0.03, 0.115, vt(7), -0.06, 0.12), (0.32, 0.09, -0.82, -0.22, -0.04))
    else:
        spec = ((-0.17, 0.085, -0.88, 0.22, 0.05), (0.02, 0.105, vt(7), -0.05, 0.1), (0.19, 0.08, -0.82, -0.25, -0.05))
    tc = (t0 + t1) / 2
    for x, r, vtop, tilt_e, tilt_n in spec:
        h = zv(vtop, tc) - zm + 0.06
        k.gem(x, tc, zm - 0.04, r, h, crystal, "cristal", sides=6, tilt=(tilt_e, tilt_n), tip=0.22)
        k.cylv(x, tc, zm - 0.02, zm + 0.06, r + 0.025, bronze, "bague", verts=6)
        k.halo(x + 0.03, tc + 0.12, zm + 0.25, "#B070FF", 3.0)
    if piece:
        # grand cristal central entre les deux premiers (il comble le creux) et éclats dans l'autre creux
        x, r = (-0.14, 0.14) if pose == "droit" else (-0.08, 0.12)
        h = zv(vt(7) - 0.20, tc - 0.04) - zm + 0.06
        k.gem(x, tc - 0.04, zm - 0.04, r, h, crystal, "grand_cristal", sides=6, tilt=(0.05, 0.06), tip=0.24)
        k.cylv(x, tc - 0.04, zm - 0.02, zm + 0.09, r + 0.03, bronze, "griffe", verts=6)
        xe = 0.18 if pose == "droit" else 0.11
        for dx, rr, hh, te in ((-0.05, 0.06, 0.42, 0.35), (0.05, 0.055, 0.36, -0.40)):
            k.gem(xe + dx, tc - 0.02, zm + 0.0, rr, hh, crystal, "eclat", sides=5, tilt=(te, 0.1), tip=0.3)
        k.halo(x, tc + 0.1, zm + 0.5, "#B070FF", 5.0)


# =====================================================================================================
# Époque 8 · Marais : panneaux de verre épais à sommet bombé, liquide vert, armature vert-de-gris
# Pièce (niveau 16) : globe sur chaque tuile (+0,20), relié au conduit de crête
# =====================================================================================================
def e08(k, pose, piece):
    vdg = k.metal("e08_vert_de_gris", "#4F6B5A", mul=1.25, rough=0.4, metallic=0.75, grain=0.2, rust="#2A3A2A",
                  rust_amount=0.3, dirt=0.4, seed=81)
    rubber = k.flat("e08_caoutchouc", "#2A2A28", rough=0.8)
    glass = k.flat("e08_verre", "#3E5A22", mul=1.0, rough=0.08, metallic=0.0)
    liquid = k.flat("e08_liquide", "#4A6E1C", mul=1.0, rough=0.15, metallic=0.0)
    glow = k.emit("e08_luminescent", "#A8FF3A", strength=2.6, base="#203A08")
    plinth(k, pose, vdg)
    k.box(PL_D[0] if pose == "droit" else PL_I[0], PL_D[1] if pose == "droit" else PL_I[1], 0.30, 0.47, 0.22, 0.25,
          rubber, "joint_caoutchouc", bev=0)
    if pose == "droit":
        xa, xb = -0.45, 0.45
        posts = ((-0.5, -0.45), (0.45, 0.5))
    else:
        xa, xb = -0.28, 0.28
        posts = ((-0.33, -0.28), (0.28, 0.33))
    tg0, tg1 = 0.30, 0.43
    zb = 0.30
    zapex = zv(vt(8), tg0)
    zsh = zapex - 0.30 * (xb - xa) / 0.9
    k.box(xa - 0.05, xb + 0.05, 0.27, 0.46, 0.24, zb, vdg, "rail_bas", bev=0.008)
    for a, b in posts:
        k.box(a, b, 0.26, 0.47, zb - 0.02, zsh - 0.12, vdg, "montant", bev=0.006)
    # profil bombé (arc de cercle) : liquide jusqu'à 62 %, verre au-dessus
    zl = zb + 0.62 * (zsh - zb)
    arc = []
    for i in range(17):
        s = i / 16.0
        x = xa + (xb - xa) * s
        arc.append((x, zsh + (zapex - zsh) * math.sin(math.pi * s)))
    k.prism_t([(xa, zl), (xb, zl), (xb, zsh)] + arc[::-1][1:-1] + [(xa, zsh)], tg0, tg1, glass, "verre_haut")
    # reflets francs du verre (reprise V3 : le verre rendu se lisait comme une tôle peinte) : deux bandes
    # obliques claires sur la face sud, au-dessus du liquide
    sheen = k.flat("e08_reflet", "#B8D890", mul=0.6, rough=0.15)
    w = xb - xa
    for x0, wd in ((xa + 0.18 * w, 0.07 * w), (xa + 0.32 * w, 0.03 * w)):
        za, zb_ = zl + 0.03, zsh + 0.6 * (zapex - zsh)
        k.prism_t([(x0, za), (x0 + wd, za), (x0 + wd + 0.12 * w, zb_), (x0 + 0.12 * w, zb_)], tg1, tg1 + 0.004, sheen,
                  "reflet_verre")
    k.box(xa, xb, tg0, tg1, zb, zl, liquid, "liquide", bev=0)
    # colonne luminescente (lueur de jour) et bulles
    k.box(-0.07, 0.07, tg1, tg1 + 0.008, zb + 0.05, zl - 0.03, glow, "colonne_lumineuse", bev=0)
    import random
    rnd = random.Random(8)
    for i in range(9 if pose == "droit" else 6):
        x = rnd.uniform(xa + 0.06, xb - 0.06)
        z = rnd.uniform(zb + 0.08, zl - 0.05)
        k.sph(x, tg1 + 0.004, z, rnd.uniform(0.018, 0.03), glow, "bulle", seg=12, rings=6)
    k.box(xa, xb, tg1 - 0.005, tg1 + 0.012, zl - 0.012, zl + 0.012, glow, "menisque", bev=0)
    # armature : sangles horizontales vert-de-gris
    for z in (zb + 0.28, zl + 0.02):
        k.box(xa - 0.01, xb + 0.01, tg1, tg1 + 0.02, z - 0.025, z + 0.025, vdg, "sangle", bev=0.004)
    k.halo(0.0, tg1 + 0.15, zb + 0.4, "#A8FF3A", 6.0)
    if piece:
        tc = (tg0 + tg1) / 2
        rg = 0.15                       # (reprise V3 : globe agrandi, bulbes d'épaule : D1-1)
        zgc = zv(vt(8) - 0.20 + rg, tc) - rg * 0.0
        k.cylv(0.0, tc, zapex - 0.05, zgc - rg + 0.03, 0.065, vdg, "col_globe", verts=24)
        k.sph(0.0, tc, zgc, rg, glass, "globe")
        k.sph(0.0, tc + 0.03, zgc - 0.02, rg * 0.72, glow, "coeur_globe")
        k.tor_h(0.0, tc, zgc - rg * 0.35, rg * 0.95, 0.018, vdg, "cerclage_globe")
        # conduit de crête vert-de-gris (relie les globes d'une tuile à l'autre)
        zcd = zsh + 0.02
        k.cylx(-0.5 if pose == "droit" else -0.36, 0.5 if pose == "droit" else 0.36, tg0 - 0.04, zcd, 0.042, vdg, "conduit")
        for x in ((-0.5, -0.47), (0.47, 0.5)) if pose == "droit" else ((-0.36, -0.33), (0.33, 0.36)):
            k.cylx(x[0], x[1], tg0 - 0.04, zcd, 0.055, rubber, "manchon")
        xb_ = 0.31 if pose == "droit" else 0.20
        for sgn in (-1, 1):
            k.cylv(sgn * xb_, tg0 - 0.04, zcd, zcd + 0.07, 0.03, vdg, "col_bulbe", verts=12)
            k.sph(sgn * xb_, tg0 - 0.04, zcd + 0.07 + 0.065, 0.065, glass, "bulbe", seg=20, rings=10)
            k.sph(sgn * xb_, tg0 - 0.02, zcd + 0.07 + 0.055, 0.045, glow, "coeur_bulbe", seg=16, rings=8)
        k.halo(0.0, tc + 0.15, zgc, "#A8FF3A", 6.0)


# =====================================================================================================
# Époque 9 · Atome : blocs de plomb chanfreinés (profil octogonal), bandes d'avertissement
# Pièce (niveau 18) : évent annelé sur chaque tuile (+0,15), conduit annelé de crête
# =====================================================================================================
def e09(k, pose, piece):
    # Reprise V3 (21/10) : le bloc du premier modeleur n'était chanfreiné que d'avant en arrière, donc
    # invisible en silhouette (un rectangle haut, « armoire »). Ici chaque bloc de plomb a une face
    # OCTOGONALE (coins hauts chanfreinés) : en rangée, une encoche en V à chaque joint ; panneau chanfreiné
    # en relief, fenêtre verte, trèfle, bande d'avertissement sur la plinthe.
    lead = k.metal("e09_plomb", "#4A5058", mul=1.35, rough=0.5, metallic=0.55, grain=0.18, dirt=0.45, seed=91)
    lead2 = k.metal("e09_plomb_clair", "#5A626C", mul=1.35, rough=0.42, metallic=0.55, grain=0.14, dirt=0.4, seed=94)
    concrete = k.stone("e09_beton", "#7A7670", mul=0.85, grain=0.2, seed=92)
    hazard = k.stripes("e09_bandes", "#C9A227", "#1C1B1A", mul=0.85, period=0.25)
    yellow = k.metal("e09_jaune", "#C9A227", mul=0.85, rough=0.45, metallic=0.2, grain=0.1, dirt=0.3, seed=93)
    black = k.flat("e09_noir", "#151515", rough=0.6)
    green = k.emit("e09_uranium", "#5CFF4A", strength=1.2, base="#103A08")
    plinth(k, pose, concrete)
    xa, xb = span(pose)
    k.box(xa, xb, 0.50, 0.505, 0.03, 0.19, hazard, "bande_socle", bev=0)
    t0, t1 = (0.20, 0.47) if pose == "droit" else (0.10, 0.47)
    ztop = zv(vt(9), t0)
    ct = 0.17 if pose == "droit" else 0.12          # chanfrein des coins hauts (x)
    cz = ct * 1.4
    cb = 0.04
    octo = [(xa + cb, 0.18), (xb - cb, 0.18), (xb, 0.18 + cb), (xb, ztop - cz), (xb - ct, ztop), (xa + ct, ztop),
            (xa, ztop - cz), (xa, 0.18 + cb)]
    k.prism_t(octo, t0, t1, lead, "bloc_plomb", bev=0.01)
    # panneau chanfreiné en relief sur la face (même octogone, réduit)
    m = 0.07
    zp0, zp1 = 0.26, ztop - 0.07
    inner = [(xa + m + cb, zp0), (xb - m - cb, zp0), (xb - m, zp0 + cb), (xb - m, zp1 - cz * 0.75),
             (xb - m - ct * 0.75, zp1), (xa + m + ct * 0.75, zp1), (xa + m, zp1 - cz * 0.75), (xa + m, zp0 + cb)]
    k.prism_t(inner, t1, t1 + 0.025, lead2, "panneau_chanfreine", bev=0.008)
    for x in (xa + m + 0.03, xb - m - 0.03):
        for z in (zp0 + 0.05, zp1 - cz * 0.75):
            k.rivet(x, t1 + 0.027, z, 0.016, yellow)
    k.flush_rivets()
    # fenêtre verte (lueur de jour) dans le haut du panneau
    zw = ztop - 0.36
    hw = (xb - xa) / 2 - m - 0.07
    k.box(-hw - 0.025, hw + 0.025, t1 + 0.02, t1 + 0.032, zw - 0.085, zw + 0.085, black, "cadre_fenetre", bev=0.005)
    k.box(-hw, hw, t1 + 0.032, t1 + 0.036, zw - 0.06, zw + 0.06, green, "fenetre_verte", bev=0)
    k.halo(0.0, t1 + 0.12, zw, "#5CFF4A", 6.0)
    # trèfle (disque jaune) sous la fenêtre
    xt = 0.0
    zt = zw - 0.27
    k.cyly(xt, t1 + 0.025, t1 + 0.033, zt, 0.075, yellow, "disque_trefle", verts=32)
    k.cyly(xt, t1 + 0.033, t1 + 0.037, zt, 0.014, black, "centre_trefle", verts=16)
    for i in range(3):
        a0 = math.radians(90 + 120 * i - 30)
        a1 = a0 + math.radians(60)
        pts = [(xt + 0.022 * math.cos(a0), zt + 0.022 * math.sin(a0))]
        for j in range(7):
            a = a0 + (a1 - a0) * j / 6
            pts.append((xt + 0.064 * math.cos(a), zt + 0.064 * math.sin(a)))
        pts.append((xt + 0.022 * math.cos(a1), zt + 0.022 * math.sin(a1)))
        k.prism_t(pts, t1 + 0.033, t1 + 0.037, black, "pale_trefle")
    if piece:
        tc = (t0 + t1) / 2
        # conduit annelé posé sur la crête : il franchit les encoches en V entre les blocs
        zcd = ztop + 0.05
        k.cylx(xa, xb, tc, zcd, 0.05, lead2, "conduit_annele")
        n = int(round((xb - xa) / 0.1))
        for i in range(n):
            x = xa + (i + 0.5) * (xb - xa) / n
            k.cylx(x - 0.012, x + 0.012, tc, zcd, 0.064, lead, "anneau_conduit")
        for x in ((xa + 0.1, xb - 0.1) if pose == "droit" else (0.0,)):
            k.box(x - 0.03, x + 0.03, tc - 0.04, tc + 0.04, ztop - 0.01, zcd - 0.03, black, "berceau", bev=0.004)
        # évent annelé (cheminée à anneaux, chapeau champignon) jusqu'à O(9) + 0,15
        zv0 = zcd
        zv1 = zv(vt(9) - 0.15 + K45 * 0.15, tc) - 0.07
        k.cylv(0.0, tc, zv0, zv1, 0.095, lead2, "event", verts=32)
        nr = int((zv1 - zv0) / 0.07)
        for i in range(nr):
            k.tor_h(0.0, tc, zv0 + 0.05 + i * 0.07, 0.097, 0.02, lead, "anneau_event")
        k.cylv(0.0, tc, zv1, zv1 + 0.03, 0.15, lead, "chapeau_event", verts=32)
        k.cylv(0.0, tc, zv1 + 0.03, zv1 + 0.07, 0.15, lead, "dome_event", verts=32, r2=0.06)
        k.tor_h(0.0, tc, zv1 - 0.03, 0.10, 0.016, green, "lisere_vert")
        k.halo(0.0, tc + 0.12, zv1, "#5CFF4A", 3.0)


# =====================================================================================================
# Époque 10 · Haute technologie : panneaux lisses, bandeau lumineux bleu, capteur en demi-sphère,
# pied en retrait (petit vide sous la crête). Pièce (niveau 20) : antenne fine (+0,20)
# =====================================================================================================
def e10(k, pose, piece):
    shell = k.metal("e10_carenage", "#A8ADB3", mul=0.78, rough=0.28, metallic=0.35, grain=0.06, dirt=0.35, seed=101)
    black = k.metal("e10_noir", "#222428", mul=1.3, rough=0.45, metallic=0.3, grain=0.08, dirt=0.2, seed=102)
    glossy = k.flat("e10_capteur", "#16181C", rough=0.12, metallic=0.2)
    blue = k.emit("e10_bleu", "#3AA8FF", strength=3.0, base="#0A1828")
    plinth(k, pose, black)
    xa, xb = span(pose)
    t0, t1 = (0.24, 0.46) if pose == "droit" else (0.14, 0.44)
    zb = 0.64
    legs = (-0.25, 0.25) if pose == "droit" else (-0.17, 0.17)
    for x in legs:
        k.box(x - 0.06, x + 0.06, 0.29, 0.41, 0.2, zb + 0.02, black, "pied", bev=0.012)
    zt = zv(-0.93, t0)
    k.box(xa + 0.006, xb - 0.006, t0, t1, zb, zt, shell, "panneau_lisse", bev=0.05)
    # bandeau lumineux (continu d'une tuile à l'autre) et fenêtre d'état (zone >= 8 x 8 px hr)
    zbd = zt - 0.30
    k.box(xa, xb, t1 - 0.01, t1 + 0.004, zbd - 0.055, zbd + 0.055, black, "gorge_bandeau", bev=0)
    k.box(xa, xb, t1 + 0.004, t1 + 0.008, zbd - 0.03, zbd + 0.03, blue, "bandeau", bev=0)
    k.box(-0.08, 0.08, t1 - 0.005, t1 + 0.012, zb + 0.18, zb + 0.40, black, "ecran", bev=0.008)
    k.box(-0.065, 0.065, t1 + 0.012, t1 + 0.016, zb + 0.20, zb + 0.38, blue, "ecran_lumineux", bev=0)
    k.halo(0.0, t1 + 0.12, zbd, "#3AA8FF", 5.0)
    # capteur en demi-sphère (sommet des masses)
    tc = (t0 + t1) / 2
    rs = 0.16
    zs = zv(vt(10) + rs, tc)          # sommet du dôme (cercle de rayon rs à l'écran) exactement à O(10)
    zs = max(zs, zt - 0.06)
    k.cylv(0.0, tc, zt - 0.06, zs + 0.01, rs + 0.02, black, "socle_capteur", verts=32)
    o = k.sph(0.0, tc, zs, rs, glossy, "capteur", seg=32, rings=16)
    k.tor_h(0.0, tc, zs + 0.01, rs + 0.005, 0.012, blue, "lisere_capteur")
    if piece:
        # Reprise V3 (21/10) : deux mâts d'antenne sur boîtiers trapézoïdaux (le fouet seul, 2 px de large,
        # n'ajoutait presque rien au masque : D1-1) ; dipôles et feu bleu au sommet, à O(10) + 0,20.
        xs = (0.30, -0.30) if pose == "droit" else (0.225, -0.225)
        hb, ht = (0.12, 0.06) if pose == "droit" else (0.08, 0.045)
        tops = (zv(vt(10) - 0.20, tc), zv(vt(10) - 0.10, tc))
        for i, (x, ztip) in enumerate(zip(xs, tops)):
            k.frustum((x - hb, x + hb, tc - 0.08, tc + 0.08), (x - ht, x + ht, tc - 0.05, tc + 0.05), zt - 0.04,
                      zt + 0.13, black, "boitier_antenne")
            k.box(x - 0.045, x + 0.045, tc + 0.08 - 0.004, tc + 0.086, zt + 0.0, zt + 0.07, blue, "voyant_boitier", bev=0)
            k.cylv(x, tc, zt + 0.13, ztip - 0.03, 0.024, shell, "mat_antenne", verts=10, r2=0.012, bev=0)
            for j, (f, w) in enumerate(((0.45, 0.13), (0.65, 0.10), (0.82, 0.07))):
                z = zt + 0.13 + f * (ztip - zt - 0.16)
                k.cylx(x - w, x + w, tc, z, 0.012, shell, "dipole")
            k.sph(x, tc, ztip - 0.02, 0.03, blue, "feu_antenne")
            k.halo(x, tc + 0.08, ztip, "#3AA8FF", 2.0)


# =====================================================================================================
# Époque 11 · Titane : plaques d'alliage en dents de scie inclinées (ailerons) avec ajours
# Pièce (niveau 22) : aileron central plus haut (+0,20)
# =====================================================================================================
def fin(k, xa, xb, x_top0, x_top1, z0, z1, t_base, t_top, thick, mat, name="aileron"):
    """Aileron : plaque trapézoïdale inclinée vers le nord (pied à t_base, sommet à t_top)."""
    quad = [(xa, t_base, z0), (xb, t_base, z0), (x_top1, t_top, z1), (x_top0, t_top, z1)]
    return k.slab(quad, thick, mat, name, bev=0.006)


def e11(k, pose, piece):
    alloy = k.metal("e11_alliage", "#C9C6BE", mul=0.66, rough=0.3, metallic=0.55, grain=0.08, rust="#7A7468",
                    rust_amount=0.3, dirt=0.45, seed=111)
    ti = k.metal("e11_titane", "#8E9AA6", mul=0.95, rough=0.28, metallic=0.85, grain=0.08, dirt=0.35, seed=112)
    line = k.emit("e11_ligne", "#BFE6FF", strength=3.2, base="#20303A")
    plinth(k, pose, ti)
    xa, xb = span(pose)
    k.box(xa, xb, 0.30, 0.46, 0.2, 0.42, alloy, "poutre", bev=0.012)
    k.box(xa, xb, 0.46, 0.466, 0.28, 0.33, line, "ligne_poutre", bev=0)
    k.box(-0.075, 0.075, 0.46, 0.468, 0.24, 0.40, line, "chevron_lumineux", bev=0)
    k.halo(0.0, 0.58, 0.32, "#BFE6FF", 4.0)
    tb, tt = 0.40, 0.24
    z1 = zv(vt(11), tt - 0.02)
    if pose == "droit":
        centers = (-1.0 / 3, 0.0, 1.0 / 3)
        half, top = 0.165, 0.08
    else:
        centers = (-0.15, 0.15)
        half, top = 0.15, 0.08
    for cx in centers:
        # dent de scie : bord ouest incliné, bord est presque vertical ; sommet tronqué (masse >= 0,15)
        fin(k, cx - half, cx + half, cx + half - 2 * top - 0.02, cx + half - 0.02, 0.40, z1, tb, tt, 0.045, alloy)
        # ligne lumineuse le long du bord d'attaque
        pts = [(cx - half + 0.02, tb + 0.03, 0.44), (cx + half - 2 * top - 0.0, tt + 0.03, z1 - 0.04)]
        k.tube(pts, 0.012, line, "ligne_aileron", sides=5, smooth=False)
    k.box(xa, xb, tb - 0.06, tb + 0.06, 0.38, 0.46, ti, "semelle", bev=0.01)
    if piece:
        cxp = -0.02
        zt = zv(vt(11) - 0.20, tt - 0.06)
        hw = 0.22 if pose == "droit" else 0.17           # (reprise V3 : aileron élargi, D1-1)
        fin(k, cxp - hw, cxp + hw, cxp + hw - 0.24, cxp + hw - 0.03, 0.46, zt, tb - 0.10, tt - 0.06, 0.05, ti,
            "aileron_central")
        pts = [(cxp - hw + 0.02, tb - 0.07, 0.5), (cxp + hw - 0.24, tt - 0.03, zt - 0.04)]
        k.tube(pts, 0.013, line, "ligne_centrale", sides=5, smooth=False)
        k.halo(cxp, 0.5, zt - 0.3, "#BFE6FF", 3.0)


# =====================================================================================================
# Époque 12 · Supraconducteurs : plinthe basse et bloc supérieur en lévitation (vide), anneau
# Pièce (niveau 24) : petit anneau flottant au-dessus de chaque tuile (+0,20)
# =====================================================================================================
def e12(k, pose, piece):
    black = k.frost("e12_noir_givre", "#26282E", "#9AA8B8", mul=1.5, amount=0.15, rough=0.35, metallic=0.4)
    chrome = k.metal("e12_chrome", "#9AA3AD", mul=1.0, rough=0.12, metallic=1.0, grain=0.04, dirt=0.15, seed=121)
    cyan = k.emit("e12_cyan", "#4AF0FF", strength=3.2, base="#082028")
    plinth(k, pose, k.metal("e12_socle", "#26282E", mul=1.5, rough=0.4, metallic=0.5, grain=0.1, dirt=0.3, seed=122))
    xa, xb = span(pose)
    t0, t1 = (0.24, 0.46) if pose == "droit" else (0.14, 0.44)
    pl = PL_D if pose == "droit" else PL_I
    k.box(pl[0], pl[1], pl[3] - 0.012, pl[3] + 0.002, 0.16, 0.225, chrome, "liseret_chrome", bev=0)
    k.box(pl[0] + 0.01, pl[1] - 0.01, 0.34, 0.44, 0.22, 0.232, cyan, "lueur_plinthe", bev=0)
    zb = 0.66 if pose == "droit" else 0.60
    zt = zv(vt(12), t0)
    k.box(xa + 0.008, xb - 0.008, t0, t1, zb, zt, black, "bloc_levitation", bev=0.02)
    k.box(xa + 0.01, xb - 0.01, t1 - 0.02, t1 + 0.004, zb - 0.002, zb + 0.035, cyan, "lueur_dessous", bev=0)
    for z in (zt - 0.05, zb + 0.08):
        k.box(xa + 0.008, xb - 0.008, t1, t1 + 0.012, z - 0.02, z + 0.02, chrome, "filet_chrome", bev=0.004)
    # noyau cyan (zone lumineuse) cerclé d'un anneau chromé face au sud, qui dépasse du bloc
    zc = zt - 0.38
    k.cyly(0.0, t1, t1 + 0.012, zc, 0.075, cyan, "noyau", verts=32)
    k.tor_f(0.0, t1 + 0.02, zc + 0.02, 0.2, 0.03, chrome, "anneau_noyau")
    k.halo(0.0, t1 + 0.12, zc, "#4AF0FF", 6.0)
    k.halo(0.0, t1 + 0.1, (zb + 0.22) / 2, "#4AF0FF", 3.0)
    if piece:
        tc = (t0 + t1) / 2
        # (reprise V3 : gyroscope de deux anneaux, l'un horizontal, l'autre face au sud, et noyau noir : la
        # pièce ajoute au moins 0,10 t², D1-1 ; un anneau mince de 0,21 n'en ajoutait que 0,05)
        R = 0.26 if pose == "droit" else 0.20
        zr = zv(vt(12) - 0.20 + K45 * R + 0.035, tc)
        k.tor_h(0.0, tc, zr, R, 0.035, chrome, "anneau_flottant", seg=64)
        k.tor_h(0.0, tc, zr, R - 0.035, 0.012, cyan, "anneau_flottant_lueur", seg=64)
        R2 = R * 0.62
        k.tor_f(0.0, tc, zr + R2 * 0.35, R2, 0.03, chrome, "anneau_vertical", seg=48)
        k.sph(0.0, tc, zr + R2 * 0.35, 0.065, black, "noyau_flottant", seg=24, rings=12)
        k.tor_h(0.0, tc, zr + R2 * 0.35, 0.068, 0.012, cyan, "equateur_noyau", seg=32)
        k.halo(0.0, tc + 0.1, zr, "#4AF0FF", 3.0)


# =====================================================================================================
# Époque 13 · Fusion : plinthe et pylône par tuile, champ de plasma entre les pylônes (hors masque)
# Pièce (niveau 26) : sphère au sommet du pylône (+0,20)
# =====================================================================================================
def e13(k, pose, piece):
    ceramic = k.metal("e13_ceramique", "#D9D6CF", mul=0.62, rough=0.25, metallic=0.05, grain=0.06, dirt=0.4, seed=131)
    copper = k.metal("e13_cuivre", "#B0703A", mul=1.0, rough=0.25, metallic=0.95, grain=0.1, dirt=0.2, seed=132)
    plasma = k.emit("e13_plasma", "#FF4FD8", strength=3.0, base="#3A0A30")
    core = k.emit("e13_coeur", "#FF9A3A", strength=3.0, base="#3A2008")
    fieldm = k.field("e13_champ", "#FF4FD8", strength=0.9, alpha=0.12)   # (reprise V3 : champ moins envahissant)
    plinth(k, pose, ceramic)
    xa, xb = span(pose)
    k.box(xa, xb, 0.32, 0.46, 0.2, 0.36, ceramic, "rail_emetteur", bev=0.012)
    k.box(xa, xb, 0.46, 0.466, 0.25, 0.31, copper, "contact_cuivre", bev=0)
    tp, rp = 0.36, 0.11
    ztop = zv(vt(13) + K45 * rp, tp)
    k.cylv(0.0, tp, 0.30, ztop - 0.06, rp, ceramic, "pylone", verts=32)
    for z in (0.62, 0.84, 1.06):
        k.tor_h(0.0, tp, z, rp + 0.012, 0.02, copper, "bobine")
    k.cylv(0.0, tp, ztop - 0.07, ztop, rp + 0.025, copper, "tete_pylone", verts=32)
    k.cylv(0.0, tp, ztop - 0.002, ztop + 0.002, rp * 0.6, core, "oeil", verts=24, bev=0)
    # tore de plasma horizontal autour du pylône (signature de l'époque)
    ztor = ztop - 0.42
    Rt = 0.27 if pose == "droit" else 0.22        # (reprise V3 : tore élargi, il porte la silhouette de l'époque)
    k.tor_h(0.0, tp, ztor, Rt, 0.05, plasma, "tore_plasma", seg=64, mseg=12)
    k.tor_h(0.0, tp, ztor, Rt, 0.028, core, "tore_coeur", seg=64)
    for a in (0.0, 2.094, 4.189):       # trois bras de céramique qui tiennent le tore
        k.tube([(0.0, tp, ztor), (Rt * math.cos(a), tp - Rt * math.sin(a) / SQ2, ztor)], 0.016, ceramic, "bras_tore",
               sides=6, smooth=False)
    # champ de plasma entre les pylônes : nappe émissive semi-transparente, hors masque
    zf0, zf1 = 0.40, ztor - 0.08
    if pose == "droit":
        segs = ((xa, -rp), (rp, xb))
    else:
        segs = ((-0.32, -rp), (rp, 0.32))
    for a, b in segs:
        k.box(a, b, tp - 0.004, tp + 0.004, zf0, zf1, fieldm, "champ", bev=0)
        n = 3
        for i in range(n):
            x = a + (i + 0.5) * (b - a) / n
            k.box(x - 0.006, x + 0.006, tp - 0.006, tp + 0.006, zf0, zf1, k.field("e13_ligne", "#FF8AE8", 1.2, 0.3),
                  "ligne_champ", bev=0)
    for x in ((xa + 0.01, -0.01) if False else ()):
        pass
    k.halo(0.0, tp + 0.15, ztor, "#FF4FD8", 8.0)
    k.halo(0.0, tp + 0.15, (zf0 + zf1) / 2, "#FF4FD8", 4.0)
    if piece:
        rs = 0.16                                     # (reprise V3 : sphère agrandie, D1-1)
        zsc = zv(vt(13) - 0.20 + rs, tp)
        k.cylv(0.0, tp, ztop, zsc - rs + 0.03, 0.055, copper, "col_sphere", verts=24)
        k.sph(0.0, tp, zsc, rs, ceramic, "sphere_confinement", seg=32, rings=16)
        k.tor_h(0.0, tp, zsc, rs + 0.01, 0.012, copper, "equateur")
        o = k.S.torus(0.29 if pose == "droit" else 0.24, 0.022, k.P(0.0, tp, zsc), plasma, k._name("anneau_plasma"),
                      rot=(0.32, 0.0, 0.0), major_seg=64, minor_seg=8)
        k.halo(0.0, tp + 0.15, zsc, "#FF4FD8", 5.0)


# =====================================================================================================
# Époque 14 · Orbite : bouclier en panneaux dorés inclinés, ajouré ; petites paraboles
# Pièce (niveau 28) : balise sur chaque tuile (+0,15)
# =====================================================================================================
def e14(k, pose, piece):
    # Reprise V3 (21/10) : les deux panneaux droits du premier modeleur faisaient deux rectangles (silhouette
    # de porte). Ici les panneaux s'ouvrent EN AILES : bord extérieur haut, bord intérieur bas ; en rangée, la
    # crête fait une scie (pic à chaque joint, V au centre où se loge la parabole). Panneaux inclinés vers le
    # nord (ils prennent l'appoint zénithal), ajourés entre eux ; or froissé à gauche, cellules à droite.
    gold = k.foil("e14_or", "#C9A23A", mul=1.0, rough=0.38, bump=0.6)
    white = k.metal("e14_blanc", "#CFCBC2", mul=0.7, rough=0.35, metallic=0.2, grain=0.08, dirt=0.45, seed=141)
    cells = k.metal("e14_cellules", "#1E2A55", mul=1.0, rough=0.12, metallic=0.4, grain=0.05, dirt=0.1, seed=142)
    blue = k.emit("e14_reflet", "#2F6BFF", strength=1.2, base="#0A1430")
    red = k.emit("e14_balise", "#FF2A2A", strength=1.3, base="#3A0505")
    plinth(k, pose, white)
    xa, xb = span(pose)
    k.box(xa, xb, 0.33, 0.43, 0.2, 0.32, white, "membrure", bev=0.01)
    tb, tt = 0.42, 0.18
    z0 = 0.36
    z1 = zv(vt(14), tt)
    s_ = (tb - tt) / (z1 - z0)                  # pente du plan des panneaux (ty par unité de z)

    def on_plane(x, v):
        """Point du plan des panneaux qui se projette à l'ordonnée écran v."""
        z = (tb + z0 * s_ - v) / (s_ + K45)
        return (x, tb - (z - z0) * s_, z)

    w = xb - xa
    ib, it_, ob, ot = 0.07 * w, 0.15 * w, 0.44 * w, 0.50 * w   # demi-écarts : intérieur bas/haut, extérieur bas/haut
    v_hi, v_lo = vt(14), vt(14) + 0.24
    bot = lambda x: (x, tb, z0)
    for sgn, m in ((-1, gold), (1, cells)):
        BI, BO = bot(sgn * ib), bot(sgn * ob)
        TO, TI = on_plane(sgn * ot, v_hi), on_plane(sgn * it_, v_lo)
        quad = [BI, BO, TO, TI] if sgn > 0 else [BO, BI, TI, TO]
        k.slab(quad, 0.03, m, "panneau_aile", bev=0.004)
        for a_, b_ in ((BI, TI), (BO, TO), (TI, TO), (BI, BO)):
            k.tube([(a_[0], a_[1] + 0.012, a_[2]), (b_[0], b_[1] + 0.012, b_[2])], 0.014, white, "cadre", sides=6,
                   smooth=False)
        if m is cells:
            # reflet bleu des cellules (zone lumineuse ≥ 8 × 8 px hr) : bande en travers du panneau
            for f0, f1 in ((0.40, 0.58),):
                P0 = [BI[i] + (TI[i] - BI[i]) * f0 for i in range(3)]
                P1 = [BO[i] + (TO[i] - BO[i]) * f0 for i in range(3)]
                P2 = [BO[i] + (TO[i] - BO[i]) * f1 for i in range(3)]
                P3 = [BI[i] + (TI[i] - BI[i]) * f1 for i in range(3)]
                q = [(P0[0] + 0.03, P0[1] + 0.014, P0[2]), (P1[0] - 0.03, P1[1] + 0.014, P1[2]),
                     (P2[0] - 0.03, P2[1] + 0.014, P2[2]), (P3[0] + 0.03, P3[1] + 0.014, P3[2])]
                k.slab(q, 0.004, blue, "reflet_cellules")
            for i in range(1, 4):
                f = i / 4.0
                pb = [BI[j] + (BO[j] - BI[j]) * f for j in range(3)]
                pt = [TI[j] + (TO[j] - TI[j]) * f for j in range(3)]
                k.tube([(pb[0], pb[1] + 0.008, pb[2]), (pt[0], pt[1] + 0.008, pt[2])], 0.006, white, "grille", sides=4,
                       smooth=False)
        # jambe de force derrière chaque aile
        k.tube([(sgn * (ib + ob) / 2, 0.36, 0.30), (sgn * (it_ + ot) / 2, tt + 0.06, (TI[2] + TO[2]) / 2 - 0.1)], 0.02,
               white, "jambe", sides=8, smooth=False)
    # parabole tournée vers le ciel, logée dans le V central
    tdish = 0.30
    zd = on_plane(0.0, v_lo + 0.10)[2]
    k.cylv(0.0, tdish, 0.32, zd, 0.022, white, "mat_parabole", verts=8, bev=0)
    rd = 0.12 if pose == "droit" else 0.09
    k.S.cylinder(rd, 0.04, k.P(0.0, tdish + 0.02, zd + 0.03), white, k._name("parabole"), verts=32, radius2=0.035,
                 rot=(math.radians(180 - 40), 0, 0), bevel_w=0)
    k.tube([(0.0, tdish + 0.04, zd + 0.04), (0.0, tdish + 0.07, zd + 0.14)], 0.008, white, "bras_cornet", sides=4,
           smooth=False)
    k.sph(0.0, tdish + 0.07, zd + 0.15, 0.022, gold, "cornet")
    k.halo(0.25 * w, 0.5, 0.9, "#2F6BFF", 3.0)
    if piece:
        # mât-balise dans le V : boîtier blanc, mât, feu rouge à O(14) + 0,15, vergue à deux feux
        tm = 0.28
        zb = on_plane(0.0, v_lo + 0.02)[2]
        ztop = zv(vt(14) - 0.15 + 0.06, tm)
        hb = 0.12 if pose == "droit" else 0.09
        k.frustum((-hb, hb, tm - 0.06, tm + 0.06), (-hb * 0.55, hb * 0.55, tm - 0.04, tm + 0.04), zb - 0.12, zb + 0.10,
                  white, "boitier_balise")
        k.box(-0.04, 0.04, tm + 0.055, tm + 0.062, zb - 0.07, zb + 0.0, red, "voyant_boitier", bev=0)
        k.cylv(0.0, tm, zb + 0.10, ztop - 0.10, 0.02, white, "mat_balise", verts=8, bev=0)
        k.cylv(0.0, tm, ztop - 0.12, ztop - 0.07, 0.055, white, "socle_feu", verts=24)
        k.sph(0.0, tm, ztop - 0.04, 0.06, red, "feu_balise")
        yv = 0.20 if pose == "droit" else 0.15
        k.cylx(-yv, yv, tm, ztop - 0.30, 0.014, white, "vergue")
        for x in (-yv, yv):
            k.sph(x, tm, ztop - 0.30, 0.035, red, "feu_vergue", seg=12, rings=6)
        k.halo(0.0, tm + 0.1, ztop - 0.06, "#FF2A2A", 6.0)


# =====================================================================================================
# Époque 15 · Légende : plinthe et créneaux flottants en or blanc ; vides entre les merlons et sous la crête
# Pièce (niveau 30) : flèche de couronne sur chaque tuile (+0,15, plafond +1,0)
# =====================================================================================================
def e15(k, pose, piece):
    # (reprise V3 : or blanc plus chaud et moins métallique, sinon il reflète le ciel faible et vire au kaki ;
    # nacre de la plinthe moins claire : elle sortait blanche à 255)
    wgold = k.metal("e15_or_blanc", "#E8DCB0", mul=0.78, rough=0.3, metallic=0.4, grain=0.08, rust="#9A8A60",
                    rust_amount=0.2, dirt=0.4, seed=151)
    nacre = k.metal("e15_nacre", "#D8D2C8", mul=0.5, rough=0.2, metallic=0.2, grain=0.06, dirt=0.35, seed=152)
    light = k.emit("e15_lumiere", "#FFF2C0", strength=1.2, base="#3A3420")
    clear = k.emit("e15_cristal", "#FFF8E0", strength=1.4, base="#8A8270")
    plinth(k, pose, nacre)
    pl = PL_D if pose == "droit" else PL_I
    k.box(pl[0], pl[1], pl[3] - 0.01, pl[3] + 0.004, 0.15, 0.20, wgold, "frise_or", bev=0)
    k.box(pl[0] + 0.02, pl[1] - 0.02, 0.36, 0.44, 0.22, 0.232, light, "lueur_plinthe", bev=0)
    t0, t1 = (0.24, 0.44) if pose == "droit" else (0.14, 0.44)
    zb = 0.86 if pose == "droit" else 0.96          # (reprise V3 : vide sous la crête plus haut au pilier, D1-3)
    zt = zv(vt(15), t0)
    merl = ((-0.25, 0.16), (0.25, 0.16)) if pose == "droit" else ((-0.165, 0.115), (0.165, 0.115))
    for cx, hw in merl:
        # merlon flottant : fût, chapiteau à degrés, couronnement pointu ; dessous lumineux
        prof = [(cx - hw, zb), (cx + hw, zb), (cx + hw, zt - 0.22), (cx + hw * 0.72, zt - 0.08), (cx + hw * 0.4, zt),
                (cx - hw * 0.4, zt), (cx - hw * 0.72, zt - 0.08), (cx - hw, zt - 0.22)]
        k.prism_t(prof, t0, t1, wgold, "merlon_flottant", bev=0.01)
        k.box(cx - hw - 0.012, cx + hw + 0.012, t0 - 0.01, t1 + 0.012, zt - 0.27, zt - 0.22, nacre, "chapiteau", bev=0.006)
        k.box(cx - hw + 0.01, cx + hw - 0.01, t1 - 0.03, t1 + 0.002, zb - 0.002, zb + 0.03, light, "dessous_lumineux", bev=0)
        k.box(cx - 0.065, cx + 0.065, t1, t1 + 0.012, zt - 0.62, zt - 0.40, light, "joyau_lumineux", bev=0.004)
        k.box(cx - hw + 0.03, cx + hw - 0.03, t1, t1 + 0.01, zb + 0.08, zb + 0.13, nacre, "bandeau_nacre", bev=0.003)
        k.halo(cx, t1 + 0.12, zt - 0.5, "#FFF2C0", 4.0)
    # anneau-halo flottant dans le créneau central, gemme claire au centre
    zr = zt - 0.45
    k.tor_f(0.0, (t0 + t1) / 2, zr, 0.075, 0.016, wgold, "anneau_halo")
    k.sph(0.0, (t0 + t1) / 2, zr, 0.035, clear, "gemme_halo", seg=16, rings=8)
    k.halo(0.0, t1 + 0.1, 0.4, "#FFF2C0", 3.0)
    if piece:
        tc = (t0 + t1) / 2
        # flèche de couronne dans le créneau central (reprise V3 : base élargie, collier et anneau : la flèche
        # fine du premier modeleur n'ajoutait que 0,03 t², D1-1), fleurons en couronne sur les merlons
        ztip = zv(vt(15) - 0.15, tc)
        zb2 = zr + 0.07
        rb = 0.085 if pose == "droit" else 0.07
        k.cylv(0.0, tc, zb2, zb2 + 0.07, rb, wgold, "socle_fleche", verts=24, r2=rb * 0.7)
        k.cylv(0.0, tc, zb2 + 0.07, ztip, rb * 0.7, wgold, "fleche", verts=6, r2=0.0, bev=0)
        k.tor_h(0.0, tc, zb2 + 0.30, rb * 0.62, 0.016, nacre, "collier_fleche")
        k.tor_f(0.0, tc + 0.03, zb2 + 0.50, 0.10, 0.016, wgold, "anneau_fleche")
        k.sph(0.0, tc + 0.03, zb2 + 0.50, 0.035, clear, "perle_fleche", seg=12, rings=6)
        for cx, hw in merl:
            zt2 = zv(vt(15) - 0.08, tc)
            for dx in (-hw * 0.55, 0.0, hw * 0.55):
                top = zt2 if dx else zv(vt(15) - 0.12, tc)
                k.cylv(cx + dx, tc, zt - 0.02, top, 0.03, wgold, "fleuron", verts=6, r2=0.0, bev=0)
        k.halo(0.0, tc + 0.1, zb2 + 0.2, "#FFF2C0", 3.0)


EPOCHS = {2: e02, 3: e03, 4: e04, 5: e05, 6: e06, 7: e07, 8: e08, 9: e09, 10: e10, 11: e11, 12: e12, 13: e13, 14: e14,
          15: e15}


# Gain d'albédo par époque (k.gain) : wall_piece.EGAIN (Python pur, lu aussi par measure_wall.py --gains).


def build_level(k, level, pose):
    k.gain = EGAIN[(level + 1) // 2] if level > 2 else EGAIN[1]
    if level == 2:
        piece_e01(k, pose)
        return
    e = (level + 1) // 2
    EPOCHS[e](k, pose, level % 2 == 0)
    k.flush_rivets()
