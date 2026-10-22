"""Les 15 époques du mur (bible docs/DESIGN_EPOQUES.md §5, ligne « Mur ») : modèles paramétriques.

S'exécute DANS Blender. Chaque époque e a une fonction e<NN>(k, pose, piece) :
- pose : « droit » (pièce straight_horizontal, raccord périodique sur la tuile) ou « isole » (single) ;
- piece : False = niveau impair 2e-1 (silhouette de l'époque), True = niveau pair 2e (même silhouette +
  la pièce de la bible).
Le niveau 2 (pièce d'époque 1 sur le sprite VANILLA) est construit par piece_e01 seul (rouleau de barbelé),
composé ensuite sur le sprite vanilla par le post-traitement (render_wall.py).

Repères (tuiles de jeu, origine = centre de la tuile, ty vers le sud ; z en unités Blender) :
- ligne avant au sol commune : ty = 0,48 à 0,50 (bas de la face vanilla : +0,50 à l'écran) ;
- JOINT commun des niveaux 2 à 30 en pose droite (visual_merge_group = 0, bible §2.5 : « même hauteur de
  crête au bord de tuile et même profil de joint ») : plinthe x ∈ [-0,5 ; 0,5], ty ∈ [0,28 ; 0,50],
  z ∈ [0 ; 0,22], et MONTANT DE JOINT identique à toutes les époques (joint() : demi-montant de 0,04 tuile
  de chaque côté du bord, chapeau dont l'arête arrière est à y = -0,712 à l'écran, comme la crête vanilla
  au bord de la tuile : -0,72 à l'ouest, -0,70 à l'est). Rien d'autre ne passe le plan x = ±0,46 (JX) : les
  corps d'époque s'arrêtent sur le montant ; deux murs de niveaux différents se raccordent donc toujours
  sur le même profil (correction du 22/10, désaccord n° 4) ;
- sommet des masses (O, §1.4) visé par époque : OT[e] = enveloppe de la bible §4 (plafond +1,0 tuile,
  pièces comprises).
"""
import math

from wall_kit import SQ2, zv
from wall_piece import EGAIN

K45 = 1.0 / SQ2

# O visé (dépassement des masses principales au-dessus du bord haut de l'emprise, en tuiles).
# Passes 1 à 4 : croissance de 0,25 à 0,905, sous l'enveloppe. Correction du 22/10 (désaccord mineur n° 3) :
# les niveaux impairs suivent l'ENVELOPPE de la bible §4 (0,25 -> 1,00, pas de 0,054) ; les pièces paires
# montent de O(e) + 0,15 à 0,20 sans dépasser le plafond (+1,0) ; à l'époque 15, la pièce est latérale.
# Quelques époques visent un peu au-dessus de l'enveloppe quand leur sommet est en pointe (la mesure des
# masses, segments >= 0,15 tuile, prend la rangée où la pointe atteint 0,15 de large).
# Époque 14 : 0,93 (et non 0,95) : la crête de l'époque 15 est une couronne de FLÈCHES, dont la masse (merlon
# central de 0,20 de large) s'arrête à O = 0,90, les flèches montant seules au plafond ; les sommets des ailes
# de l'époque 14 sont en pointe (O des masses mesuré environ 0,04 sous OT) ; O des masses ne doit pas décroître
# de l'époque 13 à l'époque 15 (D1-2).
OT = {1: 0.25, 2: 0.30, 3: 0.36, 4: 0.41, 5: 0.46, 6: 0.52, 7: 0.60, 8: 0.645, 9: 0.68, 10: 0.73, 11: 0.79,
      12: 0.825, 13: 0.88, 14: 0.93, 15: 1.00}
V_CEIL = -1.5            # ordonnée écran du plafond (+1,0 tuile au-dessus du bord haut de l'emprise)


def vt(e):
    """Ordonnée écran du sommet des masses de l'époque e."""
    return -0.5 - OT[e]


def vpiece(e, dv):
    """Ordonnée écran du sommet d'une pièce paire : O(e) + dv, jamais au-dessus du plafond (+1,0)."""
    return max(vt(e) - dv, V_CEIL + 0.004)


PL_D = (-0.5, 0.5, 0.28, 0.50, 0.0, 0.22)      # plinthe commune (joint), pose droite
PL_I = (-0.38, 0.38, 0.06, 0.50, 0.0, 0.18)     # plinthe de la pose isolée
JX = 0.46                # face intérieure du montant de joint : les corps d'époque s'arrêtent à |x| = JX
JCAP = 0.45              # face intérieure du chapeau du montant
V_JOINT = -0.712         # ordonnée écran de l'arête arrière du chapeau (crête vanilla au bord : -0,72 / -0,70)
TJ0, TJ1 = 0.22, 0.505   # profondeur du montant (ty)


def plinth(k, pose, mat, name="plinthe"):
    x0, x1, t0, t1, z0, z1 = PL_D if pose == "droit" else PL_I
    return k.box(x0, x1, t0, t1, z0, z1, mat, name, bev=0.012)


def joint(k, pose, mat, cap):
    """Montant de joint COMMUN à toutes les époques (pose droite seulement) : même forme, même hauteur, au
    même endroit ; seuls les matériaux suivent l'époque. Demi-montant de chaque côté (le voisin porte l'autre
    moitié) ; arête arrière du chapeau à V_JOINT à l'écran."""
    if pose != "droit":
        return
    zj = zv(V_JOINT, TJ0 - 0.006)
    for a, b, ca, cb in ((-0.5, -JX, -0.5, -JCAP), (JX, 0.5, JCAP, 0.5)):
        k.box(a, b, TJ0, TJ1 - 0.004, 0.0, zj - 0.044, mat, "montant_joint", bev=0.006)
        k.box(ca, cb, TJ0 - 0.006, TJ1, zj - 0.05, zj, cap, "chapeau_joint", bev=0.006)


def span(pose):
    """Largeur du corps : en pose droite, entre les deux montants de joint ; l'isolée est un pilier court."""
    return (-JX, JX) if pose == "droit" else (-0.31, 0.31)


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
        # (22/10, joint commun : le rouleau s'arrête à 0,05 du bord, la crête vanilla reste seule au joint ;
        # un mur N1 et un mur N2 voisins se raccordent sur le même profil)
        xa, xb, loops = -0.45, 0.45, 12
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
    joint(k, pose, steel, cap)
    xa, xb = span(pose)
    if pose == "droit":
        t0, t1 = 0.20, 0.46
        zc = zv(-0.30, t0)            # fond des créneaux, bas : la crête devient crénelée (Δ époque 1)
        # (22/10 : merlons resserrés, le montant de joint, plus bas qu'eux, fait le troisième créneau)
        merl = (-0.21, 0.21)
        mw = 0.095
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
        hwm = 0.115 if pose == "droit" else 0.09
        # (passe 4 : mantelet monté jusqu'aux deux tiers du créneau en pose droite ; au pilier, mantelet mi-haut :
        # monté aux deux tiers, il copiait la colonnette de l'époque 3 (IoU 0,86) ; la pièce du pilier gagne des
        # piques plus fortes et des chevaux de frise qui sortent du pilier)
        zmt = max(zc + 0.36, zv(-0.68 if pose == "droit" else -0.55, tc))
        k.box(-hwm, hwm, tc - 0.03, tc + 0.03, zc - 0.01, zmt, steel, "mantelet", bev=0.008)
        k.box(-hwm - 0.01, hwm + 0.01, tc - 0.04, tc + 0.04, zmt - 0.045, zmt, band, "cerclage_mantelet", bev=0.004)
        for rx in (-hwm + 0.03, hwm - 0.03):
            for rz in (zc + 0.06, zmt - 0.09):
                k.rivet(rx, tc + 0.033, rz, 0.014, brass)
        k.flush_rivets()
        ztip = zv(vt(2) - 0.12, tc)
        rf, gw = (0.11, 0.13) if pose == "droit" else (0.13, 0.16)      # (22/10 : pièce robuste >= 0,10 t²)
        k.cylv(0.0, tc, zmt, ztip - 0.15, 0.026, steel, "hampe", verts=8)
        k.tor_h(0.0, tc, zmt + 0.10, 0.034, 0.012, brass, "bague")
        k.pyr(0.0, tc, ztip - 0.17, ztip, rf, steel, "fer_de_pique", sides=4)
        k.box(-gw, gw, tc - 0.02, tc + 0.02, ztip - 0.19, ztip - 0.16, band, "garde", bev=0.004)
        rp_, hp_ = (0.05, 0.22) if pose == "droit" else (0.056, 0.25)
        for cx in merl:
            for dx in (-mw * 0.55, 0.0, mw * 0.55):
                k.pyr(cx + dx, tc, zm - 0.01, zm + hp_, rp_, steel, "pointe", sides=4)
        if pose == "isole":
            # chevaux de frise : piques obliques qui sortent des flancs du pilier
            for sgn in (-1, 1):
                for zz, ln in ((zm - 0.12, 0.30), (zc + 0.10, 0.26)):
                    k.gem(sgn * (xb - 0.01), tc, zz, 0.034, ln, steel, "cheval_de_frise", sides=4,
                          tilt=(sgn * 0.85, 0.0), tip=0.9)
        # lisse d'acier qui porte les piques d'un merlon à l'autre (traverse le créneau central seulement :
        # rien ne passe le joint)
        k.box(merl[0] - mw, merl[1] + mw, tc - 0.015, tc + 0.015, zm - 0.015, zm + 0.025, band, "lisse", bev=0.004)


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
    joint(k, pose, brick, coping)
    xa, xb = span(pose)
    if pose == "droit":
        t0, t1 = 0.20, 0.46
    else:
        t0, t1 = 0.12, 0.46
    zc = zv(-0.36, t0)          # (22/10 : parapet plus bas : IoU avec le niveau 4 de 0,859)
    k.box(xa, xb, t0, t1, 0.18, zc, brick, "mur_brique", bev=0.004)
    k.box(xa, xb, t0 - 0.02, t1 + 0.02, zc, zc + 0.055, coping, "chaperon", bev=0.006)
    # pilastres aux arêtes du pilier (en pose droite, le montant de joint commun en tient lieu)
    for a, b in (((xa, xa + 0.07), (xb - 0.07, xb)) if pose == "isole" else ()):
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
    # (22/10 : cadran de rayon 0,125 : un disque face au sud se voit aplati de cos 45° ; à 0,082, aucune fenêtre
    # de 8 × 8 px hr n'était entièrement lumineuse, D2-1)
    k.cyly(0.0, t1 - 0.005, t1 + 0.035, zg, 0.145, brass, "boitier_mano", verts=32)
    k.cyly(0.0, t1 + 0.035, t1 + 0.045, zg, 0.125, amber, "cadran", verts=32)
    k.box(-0.006, 0.006, t1 + 0.045, t1 + 0.05, zg - 0.01, zg + 0.06, iron, "aiguille", bev=0)
    k.cyly(0.0, t1 - 0.005, t1 + 0.06, zg - 0.16, 0.022, copper, "purge", verts=12)
    k.halo(0.0, t1 + 0.12, zg, "#FFC060", 6.0)
    if piece:
        # lanterne à vapeur : socle de laiton, globe ambré, cage, chapeau ; arrivée de vapeur en cuivre.
        # Reprise V3 : globe agrandi et potence à deux petites lanternes pendues (candélabre), pour que la pièce
        # se lise au zoom 1 et ajoute au moins 0,10 t² (D1-1).
        zb = ztop + 0.01
        rg = 0.085                       # (22/10 : globes plus petits, part émissive 5 % pour 1 % proposé)
        k.cylv(0.0, tcol, zb, zb + 0.04, 0.085, brass, "socle_lanterne", verts=24)
        k.sph(0.0, tcol, zb + 0.04 + rg, rg, amber, "globe")
        bars = []
        for i in range(6):
            a = 2 * math.pi * (i + 0.5) / 6
            bars.append(k.cylv((rg + 0.008) * math.cos(a), tcol - (rg + 0.008) * math.sin(a) / SQ2, zb + 0.04,
                               zb + 0.04 + 2 * rg + 0.01, 0.008, brass, "barreau", verts=6, bev=0))
        k.S.join(bars, "cage")
        zh = zb + 0.04 + 2 * rg
        k.cylv(0.0, tcol, zh, zh + 0.06, 0.17, iron, "chapeau", verts=24, r2=0.035)
        xs = 0.30 if pose == "droit" else 0.28
        za = zb + 0.03
        k.cylx(-xs, xs, tcol, za, 0.016, brass, "potence")
        for sgn in (-1, 1):
            k.tube([(sgn * 0.10, tcol, za), (sgn * 0.05, tcol, za - 0.12)], 0.012, brass, "console", sides=6,
                   smooth=False)
            x = sgn * xs
            k.cylv(x, tcol, za - 0.03, za + 0.005, 0.012, brass, "crochet", verts=8, bev=0)
            k.cylv(x, tcol, za - 0.075, za - 0.03, 0.085, iron, "chapeau_petit", verts=20, r2=0.03)
            k.sph(x, tcol, za - 0.075 - 0.065, 0.055, amber, "globe_petit", seg=20, rings=10)
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
    glass_o = k.flat("e04_verre_orange", "#C8661A", mul=0.6, rough=0.12)
    plinth(k, pose, galv)
    joint(k, pose, concrete, galv)
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
    # (22/10, joint commun : la lisse haute, au-dessus du montant de joint, ne relie que les deux poteaux ; la
    # lisse basse, sous le chapeau du montant, va d'un montant à l'autre)
    for z, a, b in ((zr1, posts[0], posts[1]) if pose == "droit" else (zr1, xa, xb), (zr2, xa, xb)):
        k.cylx(a, b, tp, z, 0.02, galv, "lisse")
    k.box(xa, xb, tp - 0.006, tp + 0.006, zc + 0.05, zc + 0.12, yellow, "plinthe_garde_corps", bev=0)
    if pose == "isole":
        # garde-corps en carré autour du sommet du pilier
        for x in (xa + 0.02, xb - 0.02):
            k.cyly(x, t0, t1, zr1, 0.02, galv, "lisse_cote")
    if piece:
        for x in posts:
            zb = ztop + 0.005
            # (passe 4 : feux agrandis, la pièce du pilier n'ajoutait que 0,098 t²)
            k.cylv(x, tp, zb, zb + 0.05, 0.10, galv, "socle_feu", verts=24)
            # (22/10 : verrine de verre orange RENDUE, lampe lumineuse au sommet seulement : les feux entièrement
            # émissifs faisaient 8 à 10 % du masque, pour 2 % proposés)
            k.cylv(x, tp, zb + 0.05, zb + 0.16, 0.092, glass_o, "verrine", verts=24)
            k.sph(x, tp, zb + 0.16, 0.092, glass_o, "dome")
            k.sph(x, tp + 0.03, zb + 0.20, 0.05, orange, "lampe")
            cage = []
            for i in range(5):
                a = 2 * math.pi * i / 5
                cage.append(k.cylv(x + 0.098 * math.cos(a), tp - 0.098 * math.sin(a) / SQ2, zb + 0.06, zb + 0.24,
                                   0.007, galv, "cage", verts=6, bev=0))
            k.S.join(cage, "cage_feu")
            k.tor_h(x, tp, zb + 0.24, 0.07, 0.008, galv, "cercle_cage")
            k.halo(x, tp + 0.12, zb + 0.14, "#FF8C1A", 6.0)
        # panneau d'avertissement accroché au garde-corps (entre les poteaux)
        # (reprise V3 : panneau élargi, il ferme le garde-corps entre les poteaux : D1-1)
        hp = 0.17 if pose == "droit" else 0.15
        zp0 = zr2 - (0.06 if pose == "droit" else 0.12)
        k.box(-hp, hp, tp + 0.01, tp + 0.022, zp0, zr1 + 0.04, hazard, "panneau", bev=0.004)
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
    ember = k.emit("e05_braise", "#FF5A18", strength=1.3, base="#200805")
    basalt = k.stone("e05_basalte", "#2E2C2C", mul=1.3, grain=0.35, seed=53)
    plinth(k, pose, burnt)
    joint(k, pose, tung, burnt)
    xa, xb = span(pose)
    # Passe 4 (22/10) : IoU avec l'époque 4 de 0,876 : les dents (x = ±0,25) tombaient sur les poteaux du
    # pétrole. La scie est décalée d'un quart de tuile : une grande dent au centre, des demi-dents aux joints
    # (elles se rejoignent en rangée) ; le glacis descend (arête à -0,40) : la crête en scie porte la silhouette.
    if pose == "droit":
        tb, tt, tback = 0.52, 0.26, 0.18
    else:
        tb, tt, tback = 0.50, 0.22, 0.10
    zcr = zv(-0.40, tt)
    t_at = lambda z: tb - (tb - tt) * (z - 0.12) / (zcr - 0.12)
    # Pilier (passe 4) : TRONC DE PYRAMIDE (signature de l'époque) : flancs inclinés de ±0,31 au pied à ±0,16 à
    # l'arête (la pile d'isolateurs de l'époque 6, sur muret plein, donnait IoU 0,86 avec un pilier droit).
    xtop = 0.16
    if pose == "droit":
        xw = lambda z: xb
    else:
        xw = lambda z: xb - (xb - xtop) * max(0.0, min(1.0, (z - 0.12) / (zcr - 0.12)))
    # noyau incandescent en retrait (visible dans les joints) et dos de la muraille
    xn = (xb - 0.02) if pose == "droit" else xtop - 0.02
    k.prism_x([(tback, 0.0), (tb - 0.05, 0.0), (tb - 0.05, 0.12), (tt + 0.0, zcr - 0.04), (tback, zcr - 0.04)],
              -xn, xn, ember, "noyau_braise")
    if pose == "droit":
        k.box(xa, xb, tback, tt + 0.03, 0.1, zcr, tung, "dos", bev=0.006)
    else:
        k.frustum((xa, xb, tback, tt + 0.03), (-xtop, xtop, tback, tt + 0.03), 0.1, zcr, tung, "dos")
        # joues inclinées (flancs du tronc de pyramide), du pied de la face à l'arête
        for sgn in (-1, 1):
            q = [(sgn * xb, tb + 0.03, 0.09), (sgn * xb, tback, 0.09), (sgn * xtop, tback, zcr), (sgn * xtop, tt + 0.03, zcr)]
            k.mesh([k.P(*v) for v in q], [[0, 1, 2, 3]], burnt, "joue")
    rows = 3
    for r in range(rows):
        f0, f1 = r / rows, (r + 1) / rows
        g = 0.03
        z0, z1 = 0.12 + (zcr - 0.12) * f0 + g, 0.12 + (zcr - 0.12) * f1 - 0.004
        w0, w1 = xw(z0), xw(z1)
        segs = [(-1.0, 1.0)]
        if r == 1:      # évent central : fente de braise (zone lumineuse >= 8 x 8 px hr)
            segs = [(-1.0, -0.075), (0.075, 1.0)]
        for a, b in segs:
            off = 0.03
            a0, b0 = max(a, -1.0) * (w0 if a <= -1.0 else 1.0), (b * w0 if b >= 1.0 else b)
            a1, b1 = (a * w1 if a <= -1.0 else a), (b * w1 if b >= 1.0 else b)
            quad = [(a0, t_at(z0) + off, z0 - 0.03), (b0, t_at(z0) + off, z0 - 0.03), (b1, t_at(z1) + off * 0.3, z1),
                    (a1, t_at(z1) + off * 0.3, z1)]
            k.slab(quad, 0.045, tung, "ecaille", bev=0.008)
            am, bm = (a0 + a1) / 2, (b0 + b1) / 2
            for rx in ((am + 0.06, bm - 0.06) if bm - am > 0.3 else ((am + bm) / 2,)):
                k.rivet(rx, t_at(z0 + 0.06) + off + 0.025, z0 + 0.05, 0.024, burnt)
    k.flush_rivets()
    k.halo(0.0, tb + 0.05, 0.5, "#FF4A10", 7.0)
    # couvre-arête et dents trapézoïdales (crête en scie)
    xc = xb if pose == "droit" else xtop
    k.box(-xc, xc, tt - 0.09, tt + 0.05, zcr - 0.05, zcr + 0.01, burnt, "couvre_arete", bev=0.008)
    zt = zv(vt(5), tt - 0.04)
    # (pilier : sommet de la dent large de 0,16 : il compte dans O des masses, qui ne décroît plus)
    hw0, hw1 = (0.20, 0.06) if pose == "droit" else (0.16, 0.08)
    prof = [(-hw0, zcr - 0.02), (hw0, zcr - 0.02), (hw1, zt), (-hw1, zt)]
    k.prism_t(prof, tt - 0.08, tt + 0.04, tung, "dent", bev=0.01)
    k.rivet(0.0, tt + 0.045, zcr + 0.10, 0.026, burnt)
    # (22/10 : plus de demi-dents aux joints : le montant de joint commun, plus bas que la grande dent, fait
    # la petite dent de la scie)
    k.flush_rivets()
    if piece:
        # orgue de basalte : colonne centrale qui dépasse la grande dent jusqu'à O(5) + 0,20, et deux colonnes
        # dressées dans les creux de la scie (passe 4 : elles comblent les creux, D1-1)
        tc = tt - 0.02
        ztip = zv(vpiece(5, 0.20), tc)
        xg = 0.25 if pose == "droit" else 0.19
        cols = [(0.0, 0.10, ztip, 0.0), (-xg, 0.075, zv(vt(5) - 0.04, tc), -0.10),
                (xg, 0.07, zv(vt(5) + 0.02, tc), 0.12)]
        for x, r, zt_, tilt in cols:
            k.gem(x, tc, zcr - 0.08, r, zt_ - zcr + 0.08, basalt, "colonne_basalte", sides=6, tilt=(tilt, 0.0),
                  tip=0.22)
        # fissure de braise sur la colonne centrale (lueur, 3 px hr de large : accent, non compté en D2-1)
        k.box(-0.015, 0.015, tc + 0.062, tc + 0.07, zt - 0.10, ztip - 0.20, ember, "fissure", bev=0)
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
    ceramic = k.metal("e06_ceramique", "#D8D4C8", mul=0.28, rough=0.22, metallic=0.0, grain=0.08, dirt=0.35, seed=61)
    steel = k.metal("e06_acier", "#5C6168", mul=1.2, rough=0.35, metallic=0.8, grain=0.15, rust="#5A3A24",
                    rust_amount=0.15, dirt=0.4, seed=62)
    copper = k.metal("e06_cuivre", "#B0703A", mul=1.0, rough=0.25, metallic=0.95, grain=0.12, dirt=0.1, seed=63)
    concrete = k.stone("e06_muret", "#6E6A64", mul=1.0, grain=0.2, seed=64)
    # (passe 4b : le dessus du pilier, vu d'en haut, faisait monter sa médiane à 77-84 pour 64 : couvertine sombre)
    cap_steel = k.metal("e06_couvertine", "#3A3D42", mul=0.5, rough=0.5, metallic=0.6, grain=0.15, dirt=0.4, seed=66)
    arc = k.emit("e06_arc", "#60D0FF", strength=1.3, base="#0A1A20")
    yellow = k.metal("e06_jaune", "#C9A227", mul=1.2, rough=0.5, metallic=0.2, grain=0.12, dirt=0.3, seed=65)
    black = k.flat("e06_noir", "#141414", rough=0.6)
    plinth(k, pose, steel)
    joint(k, pose, steel, cap_steel)
    xa, xb = span(pose)
    if pose == "isole":
        # (22/10 : muret du pilier ÉLARGI à la plinthe, ±0,38, et plus bas : IoU avec le tronc de pyramide de
        # l'époque 5 de 0,860 à ±0,31 ; plus étroit, elle montait à 0,879)
        xa, xb = -0.38, 0.38
    t0, t1 = (0.24, 0.48) if pose == "droit" else (0.14, 0.46)
    # (passe 4b : muret plus bas, pile plus fine : IoU avec le tronc de pyramide de l'époque 5 de 0,86 au pilier)
    zm = zv(-0.26 if pose == "droit" else -0.10, t0)   # (passe 4c : pilier plus bas, IoU 0,863 avec l'époque 5)
    k.box(xa, xb, t0, t1, 0.18, zm, concrete, "muret")
    k.box(xa, xb, t0 - 0.012, t1 + 0.012, zm, zm + 0.04, cap_steel, "couvertine", bev=0.005)
    # montants d'acier aux arêtes du pilier (en pose droite, le montant de joint commun en tient lieu)
    for a, b in (((xa, xa + 0.05), (xb - 0.05, xb)) if pose == "isole" else ()):
        k.box(a, b, t1, t1 + 0.03, 0.2, zm, steel, "montant", bev=0.005)
    # barre de cuivre sur isolateurs le long de la face du muret (elle s'arrête avant le montant de joint)
    zbar = min(0.50, zm - 0.07)
    xbar = 0.42 if pose == "droit" else xb
    k.cylx(-xbar, xbar, t1 + 0.075, zbar, 0.022, copper, "barre_cuivre", verts=12)
    for x in ((-0.25, 0.25) if pose == "droit" else (0.0,)):
        k.cyly(x, t1, t1 + 0.06, zbar, 0.032, ceramic, "isolateur_barre", verts=16)
    # poteau = pile d'isolateurs sur une embase d'acier, jusqu'à O(6)
    tp, rp = (t0 + t1) / 2, 0.088
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
    # fils tendus (cuivre) qui traversent la pile, 3 hauteurs ; en pose droite, ils vont d'un montant de joint
    # à l'autre, sous le chapeau (22/10 : rien ne passe le joint au-dessus de lui)
    if pose == "droit":
        zws = [zv(v, tp + 0.02) for v in (-0.36, -0.52, -0.67)]
    else:
        zws = [zm + 0.11 + f * (z_pile_top - zm - 0.11) for f in (0.25, 0.5, 0.75)]
    for zw in zws:
        k.cylx(xa, xb, tp + 0.02, zw, 0.011, copper, "fil", verts=8)
    # éclateur : cornes de cuivre et boule d'arc cyan au sommet
    zt = z_pile_top + 0.03
    for side in (-1, 1):
        k.tube([(side * 0.03, tp, zt), (side * 0.05, tp, zt + 0.05), (side * 0.09, tp, zt + 0.12)], 0.012, copper,
               "corne", sides=6)
    k.sph(0.0, tp, zt + 0.08, 0.095, arc, "arc_boule")       # (22/10 : disque de 12 px : un carré de 8 x 8 y tient)
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
        zs = min(0.30, zm - 0.20)
        hw = 0.13 if pose == "droit" else 0.11
        k.box(-hw, hw, t1 + 0.012, t1 + 0.024, zs, zs + 0.17, yellow, "plaque_danger", bev=0.004)
        k.box(-hw - 0.008, hw + 0.008, t1 + 0.004, t1 + 0.012, zs - 0.008, zs + 0.178, black, "bord_plaque", bev=0)
        k.tube([(0.03, t1 + 0.028, zs + 0.15), (-0.025, t1 + 0.028, zs + 0.085), (0.02, t1 + 0.028, zs + 0.09),
                (-0.03, t1 + 0.028, zs + 0.02)], 0.012, black, "eclair_plaque", sides=4, smooth=False)


# =====================================================================================================
# Époque 7 · Cristal : muret de pierre d'où jaillissent 2 à 3 pointes de cristal par tuile
# Pièce (niveau 14) : cristal plus haut au centre (+0,20)
# =====================================================================================================
def gem_tip(k, x, t, z, r, h, mat, tilt, tip, frac=0.6, name="pointe_lumineuse"):
    """Pointe lumineuse d'un cristal k.gem(x, t, z, r, h, tilt=tilt, tip=tip) : pyramide qui recouvre les
    `frac` derniers de sa pointe (rayon légèrement supérieur), sur le même axe incliné."""
    from mathutils import Vector
    te, tn = tilt
    d = Vector((math.cos(tn) * math.sin(te), math.sin(tn), math.cos(tn) * math.cos(te)))
    hb2 = h - frac * tip * h
    o = k.gem(x, t, z, r * frac * 1.06, frac * tip * h + 0.004, mat, name, sides=6, tilt=tilt, tip=0.97)
    o.location = Vector(k.P(x, t, z)) + d * hb2
    return o


def e07(k, pose, piece):
    stone = k.stone("e07_pierre", "#4A4038", mul=1.6, grain=0.35, seed=71, stain="#2E2622", stain_amount=0.3)
    bronze = k.metal("e07_bronze", "#6A5236", mul=1.4, rough=0.3, metallic=0.9, grain=0.14, rust="#3E6A55",
                     rust_amount=0.25, dirt=0.3, seed=72)
    # Correction du 22/10 (désaccord n° 3) : les cristaux entièrement émissifs couvraient 29 à 47 % du masque
    # (proposition §1.6 : 5 %) et portaient la luminance médiane VUE à 72-117 (cible 55). Les cristaux sont
    # désormais RENDUS avec leur albédo violet (#9A5CFF, bible §1.5), lisses (reflets francs) ; la lumière vit
    # dans un CŒUR lumineux au pied du cristal central (zone de lueur de jour >= 8 x 8 px hr, D2-1) et dans
    # les POINTES lumineuses (accents).
    crystal = k.flat("e07_cristal", "#9A5CFF", mul=0.21, rough=0.14)
    heart = k.emit("e07_coeur", "#D8B0FF", strength=1.3, base="#3A2A50")
    tipm = k.emit("e07_pointe", "#B070FF", strength=1.3, base="#2A1840")
    plinth(k, pose, k.stone("e07_socle", "#3A332E", mul=1.3, grain=0.3, seed=73))
    joint(k, pose, stone, bronze)
    xa, xb = span(pose)
    t0, t1 = (0.22, 0.48) if pose == "droit" else (0.12, 0.46)
    zm = zv(-0.45, t0)               # (passe 3 : muret plus bas, les cristaux portent la silhouette, D1-2)
    k.box(xa, xb, t0, t1, 0.18, zm, stone, "muret", bev=0.012)
    # moellons (relief de la face) : blocs irréguliers légèrement saillants
    rows = [(0.22, 0.44), (0.46, 0.68), (0.70, zm - 0.04)]
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
        # (22/10, joint commun : les cristaux latéraux restent entre les montants, |x| <= 0,41 ; ils s'évasent
        # encore, moins qu'avant)
        spec = ((-0.21, 0.095, vt(7) + 0.08, -0.15, 0.05), (0.02, 0.12, vt(7), -0.04, 0.12),
                (0.22, 0.09, vt(7) + 0.13, 0.15, -0.04))
    else:
        # passe 4 : au pilier, gerbe ÉVASÉE (pointes inclinées vers l'extérieur, hors du pilier) : IoU avec la
        # pile d'isolateurs de l'époque 6 de 0,910 ; O du pilier décroissait (0,469 contre 0,500)
        # (22/10, désaccord mineur n° 5 : la gerbe sortait de la tuile, x de -0,55 à 0,58 ; L max = 1,00)
        spec = ((-0.18, 0.095, vt(7) + 0.10, -0.25, 0.05), (0.02, 0.12, vt(7), -0.05, 0.1),
                (0.20, 0.09, vt(7) + 0.15, 0.25, -0.05))
    tc = (t0 + t1) / 2
    for x, r, vtop, tilt_e, tilt_n in spec:
        h = zv(vtop, tc) - zm + 0.06
        k.gem(x, tc, zm - 0.04, r, h, crystal, "cristal", sides=6, tilt=(tilt_e, tilt_n), tip=0.18)
        gem_tip(k, x, tc, zm - 0.04, r, h, tipm, (tilt_e, tilt_n), 0.18)
        k.cylv(x, tc, zm - 0.02, zm + 0.06, r + 0.025, bronze, "bague", verts=6)
        k.halo(x + 0.03, tc + 0.12, zm + 0.25, "#B070FF", 3.0)
    # cœur lumineux serti au pied du cristal central, devant lui (10 px hr de large)
    k.gem(0.02, tc + 0.10, zm - 0.03, 0.085, 0.24, heart, "coeur_cristal", sides=6, tilt=(0.0, -0.12), tip=0.3)
    k.halo(0.02, tc + 0.22, zm + 0.10, "#B070FF", 4.0)
    if piece:
        # grand cristal dans le creux ouest et éclats dans le creux est, qui sortent de la gerbe (passe 4 : plus
        # haut et plus large, la pièce n'ajoutait que 0,07 t²)
        x, r = (-0.15, 0.17) if pose == "droit" else (-0.10, 0.15)      # (22/10 : pièce robuste >= 0,10 t²)
        h = zv(vpiece(7, 0.20), tc - 0.04) - zm + 0.06
        k.gem(x, tc - 0.04, zm - 0.04, r, h, crystal, "grand_cristal", sides=6, tilt=(0.05, 0.06), tip=0.24)
        gem_tip(k, x, tc - 0.04, zm - 0.04, r, h, tipm, (0.05, 0.06), 0.24)
        k.cylv(x, tc - 0.04, zm - 0.02, zm + 0.09, r + 0.03, bronze, "griffe", verts=6)
        xe = 0.18 if pose == "droit" else 0.12
        for dx, rr, hh, te in ((-0.06, 0.11, 0.90, 0.30), (0.07, 0.10, 0.75, -0.40)):
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
    joint(k, pose, vdg, rubber)
    k.box(PL_D[0] if pose == "droit" else PL_I[0], PL_D[1] if pose == "droit" else PL_I[1], 0.30, 0.47, 0.22, 0.25,
          rubber, "joint_caoutchouc", bev=0)
    if pose == "droit":
        # (22/10, joint commun : la cuve reste entre les montants ; les montants bas de la cuve deviennent ceux
        # du joint)
        xa, xb = -0.42, 0.42      # (22/10 : cuve plus étroite : IoU avec le niveau 14 de 0,867)
        posts = ()
    else:
        xa, xb = -0.28, 0.28
        posts = ((-0.33, -0.28), (0.28, 0.33))
    tg0, tg1 = 0.30, 0.43
    zb = 0.30
    zapex = zv(vt(8), tg0)
    # (passe 3 : dôme plus bombé ; passe 4 : épaules plus basses, crête en BULBES séparés par des creux aux
    # joints : IoU avec l'époque 7 de 0,867 et avec l'époque 9 de 0,934)
    zsh = zapex - 0.78 * (xb - xa) / 0.9
    k.box(xa - 0.05, xb + 0.05, 0.27, 0.46, 0.24, zb, vdg, "rail_bas", bev=0.008)
    # profil bombé (arc de cercle) : liquide jusqu'à 62 %, verre au-dessus. Passe 4b : la cuve s'évase depuis
    # un COL étroit (bulbe, signature de l'époque) : IoU avec la couronne de cristaux du niveau 14 de 0,87 ;
    # montants des joints bas (ils comblaient les flancs du col)
    zl = zb + 0.62 * (zsh - zb)
    xn = 0.26 if pose == "droit" else 0.19
    wz = lambda z: xn + (xb - xn) * max(0.0, min(1.0, (z - zb) / (zl - zb)))
    for a, b in posts:
        k.box(a, b, 0.26, 0.47, zb - 0.02, zb + 0.10, vdg, "montant", bev=0.006)
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
    prof_l = [(-xn, zb), (xn, zb)]
    for i in range(1, 7):
        z = zb + (zl - zb) * i / 6.0
        prof_l.append((xn + (xb - xn) * math.sin(0.5 * math.pi * i / 6.0), z))
    prof_l += [(-x, z) for x, z in prof_l[:1:-1]]
    k.prism_t(prof_l, tg0, tg1, liquid, "liquide")
    wz = lambda z: xn + (xb - xn) * math.sin(0.5 * math.pi * max(0.0, min(1.0, (z - zb) / (zl - zb))))
    # colonne luminescente (lueur de jour) et bulles
    k.box(-0.07, 0.07, tg1, tg1 + 0.008, zb + 0.05, zl - 0.03, glow, "colonne_lumineuse", bev=0)
    import random
    rnd = random.Random(8)
    for i in range(9 if pose == "droit" else 6):
        z = rnd.uniform(zb + 0.08, zl - 0.05)
        x = rnd.uniform(-wz(z) + 0.06, wz(z) - 0.06)
        k.sph(x, tg1 + 0.004, z, rnd.uniform(0.018, 0.03), glow, "bulle", seg=12, rings=6)
    k.box(xa, xb, tg1 - 0.005, tg1 + 0.012, zl - 0.012, zl + 0.012, glow, "menisque", bev=0)
    # armature : sangles horizontales vert-de-gris
    for z in (zb + 0.28, zl + 0.02):
        hw_ = wz(z - 0.025) if z < zl else xb
        k.box(-hw_ - 0.01, hw_ + 0.01, tg1, tg1 + 0.02, z - 0.025, z + 0.025, vdg, "sangle", bev=0.004)
    k.halo(0.0, tg1 + 0.15, zb + 0.4, "#A8FF3A", 6.0)
    if piece:
        tc = (tg0 + tg1) / 2
        rg = 0.21                       # (22/10 : globe agrandi, la pièce robuste n'ajoutait que 0,070 t²)
        zgc = zv(vpiece(8, 0.20) + rg, tc)
        k.cylv(0.0, tc, zapex - 0.05, zgc - rg + 0.03, 0.065, vdg, "col_globe", verts=24)
        k.sph(0.0, tc, zgc, rg, glass, "globe")
        k.sph(0.0, tc + 0.03, zgc - 0.02, rg * 0.72, glow, "coeur_globe")
        k.tor_h(0.0, tc, zgc - rg * 0.35, rg * 0.95, 0.018, vdg, "cerclage_globe")
        # conduit de crête vert-de-gris (relie les globes d'une tuile à l'autre)
        zcd = zsh + 0.02
        # (22/10, joint commun : le conduit relie les deux bulbes d'épaule de la tuile, sans passer le joint)
        xb_ = 0.37 if pose == "droit" else 0.27
        k.cylx(-xb_, xb_, tg0 - 0.04, zcd, 0.042, vdg, "conduit")
        for x in ((-xb_ - 0.05, -xb_ + 0.04), (xb_ - 0.04, xb_ + 0.05)):
            k.cylx(x[0], x[1], tg0 - 0.04, zcd, 0.055, rubber, "manchon")
        # bulbes d'épaule (passe 4 : ils sortent du dôme, au lieu d'être cachés derrière)
        for sgn in (-1, 1):
            k.cylv(sgn * xb_, tg0 - 0.04, zcd - 0.04, zcd + 0.15, 0.032, vdg, "col_bulbe", verts=12)
            k.sph(sgn * xb_, tg0 - 0.04, zcd + 0.15 + 0.085, 0.085, glass, "bulbe", seg=20, rings=10)
            k.sph(sgn * xb_, tg0 - 0.02, zcd + 0.15 + 0.075, 0.055, glow, "coeur_bulbe", seg=16, rings=8)
        k.halo(0.0, tc + 0.15, zgc, "#A8FF3A", 6.0)


# =====================================================================================================
# Époque 9 · Atome : blocs de plomb chanfreinés (profil octogonal), bandes d'avertissement
# Pièce (niveau 18) : évent annelé sur chaque tuile (+0,15), conduit annelé de crête
# =====================================================================================================
def e09(k, pose, piece):
    # Reprise V3 (21/10) : le bloc du premier modeleur n'était chanfreiné que d'avant en arrière (invisible en
    # silhouette). Passe 3 : octogone à gradin (bloc bas jusqu'à -0,66, tour ±0,26) ; il avait la MÊME
    # silhouette que les dômes de l'époque 8 (IoU 0,934, mesure du 22/10). Passe 4 : le bloc de plomb chanfreiné
    # descend (-0,40) et la crête devient une TOUR DE REFROIDISSEMENT À 8 PANS (signature de l'ère atome, bible
    # §0 et §5) : taille de guêpe, lèvre évasée, anneau d'avertissement au pied, bande verte sous la lèvre ; les
    # pans ouest prennent le soleil (reflets francs). Fenêtre verte (lueur de jour) et trèfle sur le bloc.
    lead = k.metal("e09_plomb", "#4A5058", mul=1.35, rough=0.5, metallic=0.55, grain=0.18, dirt=0.45, seed=91)
    lead2 = k.metal("e09_plomb_clair", "#5A626C", mul=1.45, rough=0.38, metallic=0.5, grain=0.14, dirt=0.4, seed=94)
    concrete = k.stone("e09_beton", "#7A7670", mul=0.85, grain=0.2, seed=92)
    hazard = k.stripes("e09_bandes", "#C9A227", "#1C1B1A", mul=0.85, period=0.25)
    yellow = k.metal("e09_jaune", "#C9A227", mul=0.85, rough=0.45, metallic=0.2, grain=0.1, dirt=0.3, seed=93)
    black = k.flat("e09_noir", "#151515", rough=0.6)
    green = k.emit("e09_uranium", "#5CFF4A", strength=1.2, base="#103A08")
    plinth(k, pose, concrete)
    joint(k, pose, lead, lead2)
    xa, xb = span(pose)
    k.box(xa, xb, 0.50, 0.505, 0.03, 0.19, hazard, "bande_socle", bev=0)
    t0, t1 = (0.20, 0.47) if pose == "droit" else (0.10, 0.47)

    def octo(x0, x1, z0, z1, ct, cb=0.04):
        cz = ct * 1.4
        return [(x0 + cb, z0), (x1 - cb, z0), (x1, z0 + cb), (x1, z1 - cz), (x1 - ct, z1), (x0 + ct, z1), (x0, z1 - cz),
                (x0, z0 + cb)]

    # bloc bas chanfreiné (encoches en V aux joints)
    zlo = zv(-0.40, t0)
    k.prism_t(octo(xa, xb, 0.18, zlo, 0.10 if pose == "droit" else 0.08), t0, t1, lead, "bloc_plomb", bev=0.01)
    # fenêtre verte (lueur de jour) et trèfle sur la face du bloc
    zw = 0.50
    hwin = 0.15 if pose == "droit" else 0.10
    xw = -0.12 if pose == "droit" else 0.0
    k.box(xw - hwin - 0.025, xw + hwin + 0.025, t1 - 0.005, t1 + 0.012, zw - 0.12, zw + 0.12, black, "cadre_fenetre",
          bev=0.005)
    k.box(xw - hwin, xw + hwin, t1 + 0.012, t1 + 0.016, zw - 0.095, zw + 0.095, green, "fenetre_verte", bev=0)
    k.halo(xw, t1 + 0.12, zw, "#5CFF4A", 6.0)
    for x in (xa + 0.06, xb - 0.06):
        for z in (0.30, zlo - 0.12):
            k.rivet(x, t1 + 0.005, z, 0.016, yellow)
    k.flush_rivets()
    if pose == "droit":
        xt, zt_ = 0.25, zw
        tf = t1 + 0.012
        k.cyly(xt, t1, tf, zt_, 0.085, yellow, "disque_trefle", verts=32)
        k.cyly(xt, tf, tf + 0.004, zt_, 0.016, black, "centre_trefle", verts=16)
        for i in range(3):
            a0 = math.radians(90 + 120 * i - 30)
            a1 = a0 + math.radians(60)
            pts = [(xt + 0.025 * math.cos(a0), zt_ + 0.025 * math.sin(a0))]
            for j in range(7):
                a = a0 + (a1 - a0) * j / 6
                pts.append((xt + 0.072 * math.cos(a), zt_ + 0.072 * math.sin(a)))
            pts.append((xt + 0.025 * math.cos(a1), zt_ + 0.025 * math.sin(a1)))
            k.prism_t(pts, tf, tf + 0.004, black, "pale_trefle")
    # tour de refroidissement à 8 pans (un pan face au sud, rotz = pi/8) : pied, taille, lèvre
    tc = (t0 + t1) / 2 - 0.02
    rb, rw, rt = (0.21, 0.135, 0.165) if pose == "droit" else (0.165, 0.11, 0.135)
    z0 = zlo - 0.06
    ztop = zv(vt(9) + 0.924 * rt / SQ2, tc)
    zwst = z0 + 0.62 * (ztop - z0)
    oc = math.pi / 8
    k.cylv(0.0, tc, z0, zwst, rb, lead2, "tour_pied", verts=8, r2=rw, bev=0.006, rotz=oc)
    k.cylv(0.0, tc, zwst, ztop - 0.04, rw, lead2, "tour_haut", verts=8, r2=rt, bev=0.006, rotz=oc)
    k.cylv(0.0, tc, ztop - 0.045, ztop, rt + 0.018, lead, "levre", verts=8, bev=0.006, rotz=oc)
    k.cylv(0.0, tc, ztop - 0.002, ztop + 0.002, rt - 0.01, black, "bouche_tour", verts=8, bev=0, rotz=oc)
    # anneau d'avertissement au pied (bandes jaunes et noires) et bande verte sous la lèvre
    slope = (rb - rw) / (zwst - z0)
    k.cylv(0.0, tc, z0 + 0.02, z0 + 0.10, rb - 0.02 * slope + 0.005, hazard, "anneau_avertissement", verts=8,
           r2=rb - 0.10 * slope + 0.005, bev=0, rotz=oc)
    zg0, zg1 = ztop - 0.15, ztop - 0.07
    f0, f1 = (zg0 - zwst) / (ztop - 0.04 - zwst), (zg1 - zwst) / (ztop - 0.04 - zwst)
    k.cylv(0.0, tc, zg0, zg1, rw + (rt - rw) * f0 + 0.005, green, "bande_verte", verts=8,
           r2=rw + (rt - rw) * f1 + 0.005, bev=0, rotz=oc)
    k.halo(0.0, tc + 0.15, zg0, "#5CFF4A", 3.0)
    if piece:
        # évents annelés sur les épaules du bloc (ils comblent les épaulements, D1-1), reliés par un conduit
        # annelé qui passe derrière la tour ; sommet des évents à O(9) + 0,10
        tcv = (t0 + t1) / 2
        xv = (rb + xb) / 2 + (0.01 if pose == "droit" else 0.0)
        rv = 0.08 if pose == "droit" else 0.06
        rh = rv + (0.04 if pose == "droit" else 0.025)
        zcd = zlo + 0.04
        k.cylx(-xv, xv, t0 + 0.03, zcd, 0.045, lead2, "conduit_annele")
        for x in (-xv, xv):
            zv1 = zv(vpiece(9, 0.10) + K45 * rh, tcv) - 0.06
            k.cylv(x, tcv, zlo - 0.05, zv1, rv, lead2, "event", verts=32)
            nr = max(2, int((zv1 - zlo) / 0.07))
            for i in range(nr):
                k.tor_h(x, tcv, zlo + 0.04 + i * 0.07, rv + 0.003, 0.018, lead, "anneau_event")
            k.cylv(x, tcv, zv1, zv1 + 0.025, rh, lead, "chapeau_event", verts=32)
            k.cylv(x, tcv, zv1 + 0.025, zv1 + 0.06, rh, lead, "dome_event", verts=32, r2=0.03)
            k.tor_h(x, tcv, zv1 - 0.025, rv + 0.004, 0.012, green, "lisere_vert")
            k.halo(x, tcv + 0.12, zv1, "#5CFF4A", 3.0)


# =====================================================================================================
# Époque 10 · Haute technologie : panneaux lisses, bandeau lumineux bleu, capteur en demi-sphère,
# pied en retrait (petit vide sous la crête). Pièce (niveau 20) : antenne fine (+0,20)
# =====================================================================================================
def e10(k, pose, piece):
    # Passe 4 (22/10) : la luminance médiane mesurée était de 50 à 62 pour une cible de 82 (bible §1.5), l'albédo
    # du carénage étant déjà à sa borne : une façade plein sud ne reçoit ni le soleil (ouest) ni l'appoint
    # (zénith). Le panneau devient un CARÉNAGE ARRONDI : face inclinée vers l'arrière, arête supérieure en quart
    # de rond lissé (il prend l'appoint zénithal, dégradé franc) ; plinthe en carénage, pieds noirs.
    # (passe 4b : carénage arrondi trop clair, médiane 89 à 97 pour 82 : albédo réduit sous la borne ; 0,42 : 64)
    shell = k.metal("e10_carenage", "#A8ADB3", mul=0.40, rough=0.24, metallic=0.3, grain=0.06, dirt=0.3, seed=101)
    black = k.metal("e10_noir", "#222428", mul=1.3, rough=0.45, metallic=0.3, grain=0.08, dirt=0.2, seed=102)
    glossy = k.flat("e10_capteur", "#16181C", rough=0.12, metallic=0.2)
    blue = k.emit("e10_bleu", "#3AA8FF", strength=3.0, base="#0A1828")
    screen = k.emit("e10_ecran", "#9AD4FF", strength=1.3, base="#0A1828")   # (22/10 : écran plus clair, D2-1)
    plinth(k, pose, shell)
    joint(k, pose, black, shell)
    pl = PL_D if pose == "droit" else PL_I
    k.box(pl[0], pl[1], pl[3] - 0.004, pl[3] + 0.004, 0.05, 0.11, black, "gorge_plinthe", bev=0)
    xa, xb = span(pose)
    t0, t1 = (0.24, 0.46) if pose == "droit" else (0.14, 0.44)
    zb = 0.84                        # (passe 3 : corps levé sur pieds plus hauts, vide sous la crête : D1-2)
    legs = (-0.25, 0.25) if pose == "droit" else (-0.17, 0.17)
    for x in legs:
        k.box(x - 0.06, x + 0.06, 0.29, 0.41, 0.2, zb + 0.02, black, "pied", bev=0.012)
        k.box(x - 0.075, x + 0.075, 0.27, 0.43, 0.2, 0.30, black, "sabot_pied", bev=0.01)
    zt = zv(-0.93, t0)
    # profil du carénage (ty, z) : face inclinée (recul 0,07), quart de rond de rayon (0,11 ; 0,16), dessus
    rec, ry, rz = 0.07, 0.11, 0.16
    tf_top, zf_top = t1 - rec, zt - rz
    prof = [(t1, zb)]
    for i in range(9):
        a = (math.pi / 2) * i / 8
        prof.append((tf_top - ry + ry * math.cos(a), zf_top + rz * math.sin(a)))
    prof += [(t0, zt), (t0, zb)]
    k.prism_x(prof, xa + (0.0 if pose == "droit" else 0.006), xb - (0.0 if pose == "droit" else 0.006), shell,
              "carenage_arrondi", bev=0.01, smooth_deg=30)

    def t_face(z):
        """Profondeur de la face inclinée à la hauteur z."""
        return t1 - rec * (z - zb) / (zf_top - zb)

    def on_face(x0, x1, z0, z1, off):
        return [(x0, t_face(z0) + off, z0), (x1, t_face(z0) + off, z0), (x1, t_face(z1) + off, z1),
                (x0, t_face(z1) + off, z1)]

    # bandeau lumineux (continu d'une tuile à l'autre) et écran d'état (zone >= 8 x 8 px hr), posés SUR la face
    zbd = zt - 0.36
    k.slab(on_face(xa, xb, zbd - 0.055, zbd + 0.055, 0.004), 0.02, black, "gorge_bandeau")
    k.slab(on_face(xa, xb, zbd - 0.025, zbd + 0.025, 0.008), 0.01, blue, "bandeau")
    k.slab(on_face(-0.10, 0.10, zb + 0.10, zb + 0.38, 0.008), 0.02, black, "ecran")
    k.slab(on_face(-0.08, 0.08, zb + 0.12, zb + 0.36, 0.013), 0.01, screen, "ecran_lumineux")
    k.halo(0.0, t1 + 0.12, zbd, "#3AA8FF", 5.0)
    # capteur en demi-sphère (sommet des masses)
    tc = (t0 + t1) / 2 - 0.03
    rs = 0.16
    zs = zv(vt(10) + rs, tc)          # sommet du dôme (cercle de rayon rs à l'écran) exactement à O(10)
    zs = max(zs, zt - 0.06)
    k.cylv(0.0, tc, zt - 0.06, zs + 0.01, rs + 0.02, black, "socle_capteur", verts=32)
    k.sph(0.0, tc, zs, rs, glossy, "capteur", seg=32, rings=16)
    k.tor_h(0.0, tc, zs + 0.01, rs + 0.005, 0.012, blue, "lisere_capteur")
    if piece:
        # Reprise V3 (21/10) : deux mâts d'antenne sur boîtiers trapézoïdaux (le fouet seul, 2 px de large,
        # n'ajoutait presque rien au masque : D1-1) ; dipôles et feu bleu au sommet, à O(10) + 0,20 ; passe 4 :
        # boîtiers plus hauts et plus larges (la pièce n'ajoutait que 0,070 à 0,097 t²)
        tca = (t0 + t1) / 2 - 0.02
        xs = (0.30, -0.30) if pose == "droit" else (0.235, -0.235)
        hb, ht = (0.15, 0.08) if pose == "droit" else (0.11, 0.06)
        hbox = 0.32 if pose == "droit" else 0.42
        tops = (zv(vpiece(10, 0.20), tca), zv(vpiece(10, 0.10), tca))
        for i, (x, ztip) in enumerate(zip(xs, tops)):
            k.frustum((x - hb, x + hb, tca - 0.08, tca + 0.08), (x - ht, x + ht, tca - 0.05, tca + 0.05), zt - 0.20,
                      zt + hbox, shell, "boitier_antenne")      # (passe 4b : carénage, plus noir : médiane 64)
            k.box(x - 0.035, x + 0.035, tca + 0.08 - 0.004, tca + 0.086, zt + 0.0, zt + 0.08, blue, "voyant_boitier",
                  bev=0)
            k.cylv(x, tca, zt + hbox, ztip - 0.03, 0.026, shell, "mat_antenne", verts=10, r2=0.014, bev=0)
            for j, (f, w) in enumerate(((0.35, 0.14), (0.60, 0.11), (0.82, 0.08))):
                z = zt + hbox + f * (ztip - zt - hbox - 0.03)
                k.cylx(x - w, x + w, tca, z, 0.012, shell, "dipole")
            k.sph(x, tca, ztip - 0.02, 0.03, blue, "feu_antenne")
            k.halo(x, tca + 0.08, ztip, "#3AA8FF", 2.0)


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
    # (22/10 : lignes moins fortes, p95 vu 246 pour 240 ; part émissive 18 % pour 8 % proposés)
    line = k.emit("e11_ligne", "#BFE6FF", strength=0.9, base="#20303A")
    plinth(k, pose, ti)
    joint(k, pose, ti, alloy)
    xa, xb = span(pose)
    k.box(xa, xb, 0.30, 0.46, 0.2, 0.42, alloy, "poutre", bev=0.012)
    k.box(xa, xb, 0.46, 0.466, 0.29, 0.32, line, "ligne_poutre", bev=0)
    k.box(-0.075, 0.075, 0.46, 0.468, 0.22, 0.42, line, "chevron_lumineux", bev=0)
    k.halo(0.0, 0.58, 0.32, "#BFE6FF", 4.0)
    tb, tt = 0.40, 0.24
    z1 = zv(vt(11), tt - 0.02)
    # Correction du 22/10 (désaccord n° 6, vide V de 0,11 / 0,06 pour 8 %, et joint commun) : dents plus
    # étroites, ajours plus larges entre elles ; en pose droite, les dents restent entre les montants.
    if pose == "droit":
        centers = (-0.30, 0.0, 0.30)
        half, top = 0.115, 0.075
    else:
        centers = (-0.15, 0.15)
        half, top = 0.11, 0.08
    for cx in centers:
        # dent de scie : bord ouest incliné, bord est presque vertical ; sommet tronqué (masse >= 0,15)
        fin(k, cx - half, cx + half, cx + half - 2 * top - 0.02, cx + half - 0.02, 0.40, z1, tb, tt, 0.045, alloy)
        # ligne lumineuse le long du bord d'attaque
        # (22/10 : ligne sur la moitié haute du bord d'attaque seulement, plus fine)
        pa = (cx - half + 0.02, tb + 0.03, 0.44)
        pb = (cx + half - 2 * top - 0.0, tt + 0.03, z1 - 0.04)
        pm = tuple(pa[i] + 0.60 * (pb[i] - pa[i]) for i in range(3))
        k.tube([pm, pb], 0.009, line, "ligne_aileron", sides=5, smooth=False)
    k.box(xa, xb, tb - 0.06, tb + 0.06, 0.38, 0.46, ti, "semelle", bev=0.01)
    if piece:
        cxp = -0.02
        zt = zv(vpiece(11, 0.20) + 0.04, tt - 0.06)     # (l'épaisseur de l'aileron, vers le nord, montait à O = 1,016)
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
    # (passe 4 : givre plus présent et noir moins profond : luminance médiane 44 à 51 pour une cible de 60)
    black = k.frost("e12_noir_givre", "#26282E", "#9AA8B8", mul=2.1, amount=0.33, rough=0.35, metallic=0.4)
    chrome = k.metal("e12_chrome", "#9AA3AD", mul=0.30,   # (sous la borne : 0,55 et 0,75 y restaient)
                      rough=0.12, metallic=1.0, grain=0.04, dirt=0.15, seed=121)
    cyan = k.emit("e12_cyan", "#4AF0FF", strength=3.2, base="#082028")
    # (22/10 : socle plus sombre : son dessus, éclairé par le zénith, portait la médiane vue du pilier à 82-84)
    socle = k.metal("e12_socle", "#26282E", mul=0.8, rough=0.4, metallic=0.5, grain=0.1, dirt=0.3, seed=122)
    plinth(k, pose, socle)
    joint(k, pose, socle, chrome)
    xa, xb = span(pose)
    if pose == "isole":
        # passe 4 : bloc du pilier plus étroit et plus haut levé (IoU avec les ailerons du niveau 22 de 0,887)
        xa, xb = -0.22, 0.22
    t0, t1 = (0.24, 0.46) if pose == "droit" else (0.14, 0.44)
    pl = PL_D if pose == "droit" else PL_I
    k.box(pl[0], pl[1], pl[3] - 0.012, pl[3] + 0.002, 0.16, 0.225, chrome, "liseret_chrome", bev=0)
    # Correction du 22/10 (désaccords n° 3 et 6) : la bande cyan sur toute la plinthe (0,10 de profondeur)
    # faisait l'essentiel des 11 à 15 % émissifs et portait la médiane VUE du pilier à 82-85 (cible 60) ; elle
    # devient un filet de 0,03 (l'interstice lumineux de la bible). Le bloc lévite plus haut (interstice de
    # 0,18 à 0,30 tuile à l'écran) et il est ÉVIDÉ : une fente centrale, ouverte en bas, où flotte le noyau
    # (vide V de 0,11 / 0,09 pour 12 %).
    k.box(pl[0] + 0.01, pl[1] - 0.01, 0.38, 0.41, 0.22, 0.232, cyan, "lueur_plinthe", bev=0)
    yb = -0.055 if pose == "droit" else -0.20         # bas du bloc à l'écran
    zb = zv(yb, t1)
    zt = zv(vt(12), t0)
    ws = 0.085 if pose == "droit" else 0.07           # demi-largeur de la fente
    zc = zt - 0.62                                    # centre du noyau (sous l'arc avant de l'anneau de la pièce)
    zs = zc + 0.17                                    # haut de la fente
    for a, b in ((xa + 0.008, -ws), (ws, xb - 0.008)):
        k.box(a, b, t0, t1, zb, zs + 0.02, black, "jambe_bloc", bev=0.02)
    k.box(xa + 0.008, xb - 0.008, t0, t1, zs, zt, black, "bloc_levitation", bev=0.02)
    # (passe 4d : couvercle noir sans givre : le dessus givré, vu d'en haut, portait la médiane du pilier à 72-76)
    k.box(xa + 0.02, xb - 0.02, t0 + 0.012, t1 - 0.012, zt - 0.01, zt + 0.012,
          k.metal("e12_couvercle", "#26282E", mul=1.5, rough=0.35, metallic=0.5, grain=0.08, dirt=0.3, seed=123),
          "couvercle", bev=0.006)
    for a, b in ((xa + 0.01, -ws - 0.01), (ws + 0.01, xb - 0.01)):
        k.box(a, b, t1 - 0.02, t1 + 0.004, zb - 0.002, zb + 0.025, cyan, "lueur_dessous", bev=0)
    for z in (zt - 0.05, zb + 0.08):
        k.box(xa + 0.008, xb - 0.008, t1, t1 + 0.012, z - 0.02, z + 0.02, chrome, "filet_chrome", bev=0.004)
    # noyau cyan flottant dans la fente (zone lumineuse : disque de 0,15 tuile face au sud), cerclé d'un anneau
    # chromé face au sud qui passe devant les jambes du bloc
    tcn = (t0 + t1) / 2
    # (sphère de 0,10 : un carré de 8 × 8 px hr tient dans son disque de 12,8 px)
    k.sph(0.0, t1 - 0.03, zc, 0.10, cyan, "noyau_sphere", seg=32, rings=16)
    k.tor_f(0.0, t1 + 0.02, zc + 0.02, 0.2 if pose == "droit" else 0.16, 0.03, chrome, "anneau_noyau")
    k.halo(0.0, t1 + 0.12, zc, "#4AF0FF", 6.0)
    k.halo(0.0, t1 + 0.1, (zb + 0.22) / 2, "#4AF0FF", 3.0)
    if piece:
        tc = (t0 + t1) / 2
        # (reprise V3 : gyroscope de deux anneaux, l'un horizontal, l'autre face au sud, et noyau noir : la
        # pièce ajoute au moins 0,10 t², D1-1 ; un anneau mince de 0,21 n'en ajoutait que 0,05)
        # passe 4 : anneaux plus grands (au pilier, l'anneau horizontal déborde du bloc rétréci) et noyau plus gros,
        # placés au plus haut sous le plafond de +1,0 (la pièce n'ajoutait que 0,083 à 0,094 t²)
        R, rr = (0.41, 0.042) if pose == "droit" else (0.33, 0.038)     # (22/10 : pièce robuste >= 0,10 t²)
        v_ring = max(vt(12) - 0.03, V_CEIL + K45 * R + rr + 0.006)
        zr = zv(v_ring, tc)
        k.tor_h(0.0, tc, zr, R, rr, chrome, "anneau_flottant", seg=64)
        k.tor_h(0.0, tc, zr, R - 0.035, 0.012, cyan, "anneau_flottant_lueur", seg=64)
        R2 = 0.27 if pose == "droit" else 0.21
        v2 = max(v_ring - 0.05, V_CEIL + K45 * R2 + 0.035 + 0.006)
        z2 = zv(v2, tc)
        k.tor_f(0.0, tc, z2, R2, 0.035, chrome, "anneau_vertical", seg=48)
        k.sph(0.0, tc, z2, 0.10, black, "noyau_flottant", seg=24, rings=12)
        k.tor_h(0.0, tc, z2, 0.103, 0.012, cyan, "equateur_noyau", seg=32)
        k.halo(0.0, tc + 0.1, zr, "#4AF0FF", 3.0)


# =====================================================================================================
# Époque 13 · Fusion : plinthe et pylône par tuile, champ de plasma entre les pylônes (hors masque)
# Pièce (niveau 26) : sphère au sommet du pylône (+0,20)
# =====================================================================================================
def e13(k, pose, piece):
    ceramic = k.metal("e13_ceramique", "#D9D6CF", mul=0.56, rough=0.25, metallic=0.05, grain=0.06, dirt=0.4, seed=131)
    copper = k.metal("e13_cuivre", "#B0703A", mul=1.0, rough=0.25, metallic=0.95, grain=0.1, dirt=0.2, seed=132)
    plasma = k.emit("e13_plasma", "#FF4FD8", strength=3.0, base="#3A0A30")
    # Correction du 22/10 (désaccords n° 2 et 3) : le magenta saturé plafonne à une luminance de 135 environ,
    # soit +40 seulement sur un corps de céramique à 92 : la lueur de jour (D2-1) ne tenait pas en pose droite.
    # Le CŒUR du plasma est rendu chauffé à blanc (orangé pâle) dans une fenêtre d'injecteur de 0,14 tuile
    # (9 px hr) ; le tore magenta s'amincit (part émissive de 23 à 30 % pour une proposition de 10 %).
    core = k.emit("e13_coeur", "#FFD8A8", strength=1.0, base="#3A2008")   # (p95 <= 240 : luminance 221)
    fieldm = k.field("e13_champ", "#FF4FD8", strength=0.9, alpha=0.12)   # (reprise V3 : champ moins envahissant)
    # (22/10 : plinthe en céramique plus sombre : son dessus portait la médiane vue du pilier à 119 pour 92)
    plinth(k, pose, k.metal("e13_socle", "#D9D6CF", mul=0.30, rough=0.3, metallic=0.05, grain=0.06, dirt=0.45,
                            seed=134))
    joint(k, pose, ceramic, copper)
    xa, xb = span(pose)
    socle13 = k.metal("e13_socle", "#D9D6CF", mul=0.30, rough=0.3, metallic=0.05, grain=0.06, dirt=0.45, seed=134)
    k.box(xa, xb, 0.32, 0.46, 0.2, 0.36, socle13, "rail_emetteur", bev=0.012)
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
    Rt = 0.25 if pose == "droit" else 0.21        # (reprise V3 : tore élargi, il porte la silhouette de l'époque)
    # tore de confinement en cuivre ; le plasma magenta circule DEDANS (rayon plus petit) : on le voit sur l'arc
    # arrière, au-dessus du cuivre, l'arc avant est caché par le cuivre (part émissive divisée par deux)
    k.tor_h(0.0, tp, ztor, Rt, 0.04, copper, "tore_confinement", seg=64, mseg=10)
    k.tor_h(0.0, tp, ztor + 0.006, Rt - 0.04, 0.03, plasma, "tore_plasma", seg=64, mseg=10)
    for a in (0.0, 2.094, 4.189):       # trois bras de céramique qui tiennent le tore
        k.tube([(0.0, tp, ztor), (Rt * math.cos(a), tp - Rt * math.sin(a) / SQ2, ztor)], 0.016, ceramic, "bras_tore",
               sides=6, smooth=False)
    # injecteur (kit de l'époque) : collier de cuivre sur le pylône, au-dessus du tore, fenêtre du cœur au sud.
    # Un disque face au sud se voit aplati (hauteur × cos 45°) : rayon 0,125 pour qu'un carré de 8 × 8 px hr
    # tienne entièrement dans la zone lumineuse (ellipse de 16 × 11 px)
    zi = ztor + 0.24
    k.cylv(0.0, tp, zi - 0.15, zi + 0.15, rp + 0.05, copper, "injecteur", verts=32)
    k.cyly(0.0, tp, tp + (rp + 0.07) / SQ2, zi, 0.125, core, "fenetre_coeur", verts=32)
    k.cyly(0.0, tp, tp + (rp + 0.065) / SQ2, zi, 0.145, ceramic, "bague_fenetre", verts=32)
    # champ de plasma entre les pylônes : nappe émissive semi-transparente, hors masque
    # (22/10 : le champ part plus haut : au pilier, il se projetait sur le dessus clair de la plinthe et comptait
    # comme surface émissive du masque)
    zf0, zf1 = 0.62, ztor - 0.08
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
    k.halo(0.0, tp + 0.15, ztor, "#FF4FD8", 8.0)
    k.halo(0.0, tp + 0.15, zi, "#FF9A3A", 4.0)
    k.halo(0.0, tp + 0.15, (zf0 + zf1) / 2, "#FF4FD8", 4.0)
    if piece:
        rs = 0.235                                    # (22/10 : sphère agrandie, pièce robuste >= 0,10 t²)
        # passe 4 : l'anneau incliné (0,32 rad) montait à O = 1,078 (plafond +1,0, Q9) : inclinaison 0,20 et
        # centre abaissé pour que le haut de l'anneau reste sous le plafond
        # (passe 4b : anneau presque horizontal et plus large : il déborde du tore ; la pièce n'ajoutait que 0,084)
        Ra, ra, tilt = (0.38 if pose == "droit" else 0.31), 0.03, 0.08
        v_c = max(vt(13) - 0.20 + rs, V_CEIL + Ra * (math.cos(tilt) + math.sin(tilt)) / SQ2 + ra + 0.006)
        zsc = zv(v_c, tp)
        if zsc - rs + 0.03 > ztop + 0.01:
            k.cylv(0.0, tp, ztop, zsc - rs + 0.03, 0.055, copper, "col_sphere", verts=24)
        sph_mat = k.metal("e13_ceramique_sphere", "#D9D6CF", mul=0.30, rough=0.3, metallic=0.05, grain=0.06, dirt=0.45,
                          seed=133)       # (passe 4d : la sphère claire portait la médiane du corps à 103-111 pour 92)
        k.sph(0.0, tp, zsc, rs, sph_mat, "sphere_confinement", seg=32, rings=16)
        k.tor_h(0.0, tp, zsc, rs + 0.01, 0.012, copper, "equateur")
        # hublot du cœur (orange) sur la face sud de la sphère : elle cache l'œil du pylône (passe 4, D2-1)
        # (hublot au-dessus de l'arc avant de l'anneau, qui le coupait : aucune fenêtre 8 × 8 pleine au pilier)
        k.cyly(0.0, tp + 0.12 / SQ2, tp + (rs + 0.006) / SQ2, zsc + 0.08, 0.125, core, "hublot_coeur", verts=32)
        k.cyly(0.0, tp + 0.11 / SQ2, tp + (rs + 0.002) / SQ2, zsc + 0.08, 0.145, copper, "bague_hublot", verts=32)
        # anneau de confinement incliné (cuivre), plasma dedans comme au tore
        k.S.torus(Ra, ra, k.P(0.0, tp, zsc), copper, k._name("anneau_confinement"), rot=(tilt, 0.0, 0.0),
                  major_seg=64, minor_seg=8)
        k.S.torus(Ra - 0.03, 0.017, k.P(0.0, tp, zsc + 0.004), plasma, k._name("anneau_plasma"), rot=(tilt, 0.0, 0.0),
                  major_seg=64, minor_seg=8)
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
    gold = k.foil("e14_or", "#D6A838", mul=1.0, rough=0.38, bump=0.6)
    white = k.metal("e14_blanc", "#CFCBC2", mul=0.7, rough=0.35, metallic=0.2, grain=0.08, dirt=0.45, seed=141)
    cells = k.metal("e14_cellules", "#1E2A55", mul=1.0, rough=0.12, metallic=0.4, grain=0.05, dirt=0.1, seed=142)
    blue = k.emit("e14_reflet", "#A8C8FF", strength=1.3, base="#0A1430")   # reflet clair des cellules (D2-1)
    red = k.emit("e14_balise", "#FF2A2A", strength=1.3, base="#3A0505")
    plinth(k, pose, k.metal("e14_socle", "#CFCBC2", mul=0.4, rough=0.35, metallic=0.2, grain=0.08, dirt=0.45, seed=143))
    joint(k, pose, white, gold)
    xa, xb = span(pose)
    k.box(xa, xb, 0.33, 0.43, 0.2, 0.32, k.metal("e14_socle", "#CFCBC2", mul=0.4, rough=0.35, metallic=0.2, grain=0.08,
                                               dirt=0.45, seed=143), "membrure", bev=0.01)
    # Correction du 22/10 (désaccord n° 6 : vide V de 0,14 / 0,08 pour 21 %) : les panneaux sont LEVÉS SUR
    # MÂTS (bord bas à y = -0,30 à l'écran au lieu de +0,17) ; l'ajour entre les panneaux descend jusqu'à la
    # membrure ; en pose droite, les ailes restent entre les montants de joint.
    tb, tt = 0.40, 0.17
    z0 = zv(-0.30 if pose == "droit" else -0.42, tb)     # (au pilier, plus haut : vide V de 0,19 pour 21 %)
    z1 = zv(vt(14), tt)
    s_ = (tb - tt) / (z1 - z0)                  # pente du plan des panneaux (ty par unité de z)

    def on_plane(x, v):
        """Point du plan des panneaux qui se projette à l'ordonnée écran v."""
        z = (tb + z0 * s_ - v) / (s_ + K45)
        return (x, tb - (z - z0) * s_, z)

    w = xb - xa
    ib, it_, ob, ot = 0.10 * w, 0.17 * w, 0.44 * w, 0.48 * w   # demi-écarts : intérieur bas/haut, extérieur bas/haut
    # (passe 4 : V moins profond : les sommets en pointe des ailes faisaient tomber O des masses à 0,72, sous
    # l'époque 13 ; au pilier, ailes plus étroites : V encore moins profond)
    # (22/10 : V plus profond, place pour le radôme de la pièce : pièce robuste de 0,094 / 0,071 t²)
    v_hi, v_lo = vt(14), vt(14) + (0.17 if pose == "droit" else 0.15)
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
        # mât qui porte l'aile (du haut de la membrure au bord bas du panneau) et jambe de force derrière l'aile
        xm = sgn * (ib + ob) / 2
        k.cylv(xm, tb - 0.03, 0.30, z0 + 0.02, 0.026, white, "mat_aile", verts=12, bev=0)
        k.box(xm - 0.05, xm + 0.05, tb - 0.07, tb + 0.01, z0 - 0.04, z0 + 0.01, white, "rotule_aile", bev=0.006)
        k.tube([(xm, 0.36, 0.30), (sgn * (it_ + ot) / 2, tt + 0.06, (TI[2] + TO[2]) / 2 - 0.1)], 0.018,
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
        # Passe 4b : le mât-balise dans le V (boîtier, mât, vergue) n'ajoutait que 0,058 à 0,086 t² : le V, moins
        # profond depuis la passe 4, l'avalait. La balise devient un RADÔME blanc dressé dans l'ajour central, qui
        # monte jusqu'au plafond (+1,0), feu rouge sur sa face sud ; feux d'extrémité sur les pointes des ailes ;
        # au pilier, bras latéraux à feux.
        tm = 0.27
        rr_ = 0.215 if pose == "droit" else 0.17      # (22/10 : pièce robuste >= 0,10 t²)
        v_c = V_CEIL + 0.006 + rr_
        zc_ = zv(v_c, tm)
        k.cylv(0.0, tm, 0.34, zc_ - rr_ + 0.03, 0.03, white, "mat_balise", verts=8, bev=0)
        k.sph(0.0, tm, zc_, rr_, white, "radome", seg=32, rings=16)
        k.tor_h(0.0, tm, zc_ - rr_ * 0.35, rr_ * 0.94, 0.013, gold, "bague_radome", seg=48)
        k.cyly(0.0, tm + (rr_ - 0.03) / SQ2, tm + (rr_ + 0.006) / SQ2, zc_ + 0.02, 0.06, red, "feu_balise", verts=24)
        for sgn in (-1, 1):
            tx, tty, tz = on_plane(sgn * (ot - 0.03), v_hi)
            # (22/10 : feux d'aile sous le plafond, O tout montait à 1,047)
            k.cylv(tx, tty, tz - 0.02, tz + 0.01, 0.012, white, "potelet_feu", verts=6, bev=0)
            k.sph(tx, tty, tz + 0.03, 0.042, red, "feu_aile", seg=12, rings=6)
            if pose == "isole":
                ax, aty, az = on_plane(sgn * (ot - 0.01), v_hi + 0.36)
                k.cylx(min(ax, ax + sgn * 0.15), max(ax, ax + sgn * 0.15), aty, az, 0.014, white, "bras_feu")
                k.sph(ax + sgn * 0.15, aty, az, 0.05, red, "feu_bras", seg=12, rings=6)
        k.halo(0.0, tm + 0.15, zc_, "#FF2A2A", 6.0)


# =====================================================================================================
# Époque 15 · Légende : plinthe et créneaux flottants en or blanc ; vides entre les merlons et sous la crête
# Pièce (niveau 30) : flèches de couronne sur chaque tuile (plafond +1,0 : la pièce est latérale)
# =====================================================================================================
def e15(k, pose, piece):
    # Correction du 22/10 (désaccord n° 5) : les pinacles de la passe 4, deux cylindres à dôme par tuile sans
    # crête qui les relie, se lisaient au zoom 1 comme des capsules flottantes au-dessus d'une plinthe (mur
    # franchissable, signature d'époque absente au niveau impair). Ici, CRÉNEAUX FLOTTANTS (bible §5) : une
    # crête continue d'or blanc qui flotte d'un montant de joint à l'autre, trois merlons dessus, chacun coiffé
    # d'une FLÈCHE (couronne de flèches, 3 hauteurs : pointes des merlons latéraux, du merlon central, de la
    # flèche centrale) ; pendentifs effilés sous la crête ; anneau-halo et gemme lumineuse dans le vide (base
    # flottante). Part émissive ramenée vers la proposition §1.6 (17-18 % mesurés en passe 4).
    wgold = k.metal("e15_or_blanc", "#E8DCB0", mul=1.0, rough=0.26, metallic=0.12, grain=0.08, rust="#9A8A60",
                    rust_amount=0.2, dirt=0.35, seed=151, cap=0.90)
    # (22/10 : nacre de la plinthe assombrie : son dessus, éclairé par le zénith, portait la médiane vue du pilier
    # à 177 pour 108)
    nacre = k.metal("e15_nacre", "#D8D2C8", mul=0.12, rough=0.3, metallic=0.15, grain=0.06, dirt=0.35, seed=152)
    nacre2 = k.metal("e15_nacre_claire", "#D8D2C8", mul=0.55, rough=0.22, metallic=0.2, grain=0.05, dirt=0.3, seed=153)
    # (22/10 : émission réduite : le blanc doré à 1,2 sortait à une luminance de 250, p95 vu > 240)
    light = k.emit("e15_lumiere", "#FFF2C0", strength=0.9, base="#3A3420")
    clear = k.emit("e15_cristal", "#FFF8E0", strength=0.9, base="#8A8270")
    plinth(k, pose, nacre)
    joint(k, pose, nacre, wgold)
    pl = PL_D if pose == "droit" else PL_I
    k.box(pl[0], pl[1], pl[3] - 0.01, pl[3] + 0.004, 0.15, 0.20, wgold, "frise_or", bev=0)
    k.box(pl[0] + 0.02, pl[1] - 0.02, 0.39, 0.42, 0.22, 0.232, light, "lueur_plinthe", bev=0)
    t0, t1 = (0.24, 0.44) if pose == "droit" else (0.16, 0.42)
    tc = (t0 + t1) / 2
    if pose == "droit":
        xc = 0.44                                   # la crête flotte d'un montant de joint à l'autre
        # merlons : (x, demi-largeur, sommet du merlon à l'écran, sommet de sa flèche à l'écran)
        merl = ((-0.30, 0.08, -1.27, -1.40), (0.0, 0.10, -1.405, -1.497), (0.30, 0.08, -1.27, -1.40))
        pend = (-0.30, 0.30)
    else:
        xc = 0.30
        merl = ((-0.20, 0.065, -1.25, -1.38), (0.0, 0.095, -1.405, -1.497), (0.20, 0.065, -1.25, -1.38))
        pend = (-0.20, 0.20)
    # crête flottante (section octogonale), bas de la face avant à y = -0,87 : elle flotte nettement au-dessus du
    # chapeau du montant de joint (-0,71)
    zb_c = zv(-0.87, t1)
    zt_c = zb_c + 0.13
    c = 0.03
    prof = [(t0, zb_c + c), (t0 + c, zb_c), (t1 - c, zb_c), (t1, zb_c + c), (t1, zt_c - c), (t1 - c, zt_c),
            (t0 + c, zt_c), (t0, zt_c - c)]
    k.prism_x(prof, -xc, xc, wgold, "creneau_flottant", bev=0.006)
    k.box(-xc + 0.02, xc - 0.02, t1 - 0.004, t1 + 0.008, zb_c + 0.015, zb_c + 0.045, light, "lueur_crete", bev=0)
    for x in (-xc, xc):                              # embouts de nacre aux deux bouts de la crête
        k.box(x - 0.025, x + 0.025, t0 - 0.01, t1 + 0.01, zb_c - 0.01, zt_c + 0.01, nacre2, "embout", bev=0.006)
    tm = tc
    oc = math.pi / 8          # un pan face au nord : l'arête arrière du merlon est droite (O des masses = son sommet)
    for x, hw, vtop, vtip in merl:
        zm_top = zv(vtop, tm - (hw + 0.015) * math.cos(oc) / SQ2)
        k.cylv(x, tm, zt_c - 0.01, zm_top - 0.05, hw, wgold, "merlon", verts=8, bev=0.006, rotz=oc)
        k.cylv(x, tm, zm_top - 0.06, zm_top, hw + 0.015, nacre2, "chapiteau", verts=8, bev=0.005, rotz=oc)
        rf = hw * 0.62
        k.cylv(x, tm, zm_top, zv(vtip, tm), rf, wgold, "fleche", verts=8, r2=0.0, bev=0, rotz=oc)
        k.sph(x, tm + (hw + 0.012) / SQ2, zm_top - 0.12, 0.028, clear, "joyau_merlon", seg=12, rings=6)
    # pendentifs effilés sous la crête (base flottante)
    for x in pend:
        k.cylv(x, tm, zb_c - 0.62, zb_c + 0.01, 0.002, wgold, "pendentif", verts=8, r2=0.05, bev=0)
        k.tor_h(x, tm, zb_c - 0.05, 0.05, 0.012, nacre2, "bague_pendentif")
    # anneau-halo flottant dans le vide, gemme lumineuse au centre (zone de lueur de jour : disque de 12,8 px)
    zr = zv(-0.36, t1)
    rr = 0.17 if pose == "droit" else 0.15
    k.tor_f(0.0, t1 - 0.02, zr, rr, 0.024, wgold, "anneau_halo", seg=64, mseg=10)
    k.sph(0.0, t1 - 0.02, zr, 0.10, clear, "gemme_halo", seg=32, rings=16)
    k.halo(0.0, t1 + 0.12, zr, "#FFF2C0", 5.0)
    k.halo(0.0, t1 + 0.1, zb_c, "#FFF2C0", 3.0)
    if piece:
        # COURONNE : grand halo d'or blanc derrière les merlons (il déborde au-dessus de la crête et dans les
        # créneaux), flèches de couronne dans les créneaux, fleurons autour de la flèche centrale ; tout sous le
        # plafond de +1,0 (Q9)
        Rh, rh = (0.43, 0.04) if pose == "droit" else (0.40, 0.036)      # (22/10 : pièce robuste >= 0,10 t²)
        th = t0 - 0.03
        v_h = V_CEIL + K45 * Rh + rh + 0.008
        k.tor_f(0.0, th, zv(v_h, th), Rh, rh, wgold, "halo_couronne", seg=96, mseg=10)
        k.tor_f(0.0, th + 0.012, zv(v_h, th), Rh - 0.03, 0.009, light, "halo_couronne_lueur", seg=96, mseg=6)
        for sgn in (-1, 1):
            for xs, rb, vt_ in (((0.155, 0.05, -1.38), (0.405, 0.04, -1.28)) if pose == "droit" else
                                ((0.10, 0.04, -1.38), (0.275, 0.035, -1.26))):
                k.cylv(sgn * xs, tm, zt_c - 0.01, zt_c + 0.06, rb + 0.01, nacre2, "socle_fleche_couronne", verts=8)
                k.cylv(sgn * xs, tm, zt_c + 0.06, zv(vt_, tm), rb, wgold, "fleche_couronne", verts=8, r2=0.0, bev=0)
        cx, hw, vtop, vtip = merl[1]
        zc_ = zv(vtop, tm - hw / SQ2)
        Rc = hw + 0.04
        k.tor_h(cx, tm, zc_ - 0.03, Rc, 0.02, wgold, "couronne")
        for i in range(5):
            a = math.radians(-90 + 72 * i)            # premier fleuron au sud (devant)
            fx, fy = cx + Rc * math.cos(a), tm - Rc * math.sin(a) / SQ2
            k.pyr(fx, fy, zc_ - 0.03, min(zc_ + 0.12, zv(V_CEIL + 0.01, fy)), 0.03, wgold, "fleuron", sides=4)
        k.halo(0.0, tm + 0.1, zv(v_h, th), "#FFF2C0", 3.0)


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
