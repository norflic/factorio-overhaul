"""Pièce du pipeline V0 : famille « mitrailleuse » (clé gun), 30 niveaux, lot V3 phase 1.

Fichier de pièce au format de tools/render/README.md (PIECE + build(S, C, variant)), lu par
tools/render/blender/render_piece.py (dans Blender) et par les scripts de ce dossier (Python système :
ce module n'importe ni bpy ni gun_kit au niveau supérieur).

Variantes (une variante = une pose = un rendu Blender, 5 passes) :
  e01-piece-avant, e01-piece-flancs   pièce du niveau 2 (sacs de sable) posée sur le socle VANILLA ;
                                      « flancs » est masquée au pixel par l'alpha du socle vanilla
                                      (méthode de la variante « four » de V0), « avant » ne l'est pas
                                      (elle passe devant le socle) ;
  eNN-socle                           socle (base_picture) du niveau impair 2e-1, e = 2..15 ;
  eNN-socle-piece                     socle + pièce du niveau pair 2e, rendus ensemble (1 pose : liseré
                                      et ombres de contact exacts entre pièce et socle) ;
  eNN-tete-N|E|S|O                    tête en position « prepared », 4 directions de référence.
Le niveau 1 est le sprite vanilla (Q11) : aucune variante.

Réglages par époque (params.json, écrit par tune.py) : zg = hauteur de l'axe des canons (suit
l'enveloppe O de la bible §4), gain = gain d'albédo (luminance médiane du corps, bible §1.5).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

DIRS = {"N": 0.0, "E": -math.pi / 2, "S": math.pi, "O": math.pi / 2}
EPOCHS = list(range(1, 16))
# bible §4, colonne Mitrailleuse : O (dépassement au-dessus du bord haut de l'emprise) et L (largeur)
O_TARGET = {1: 0.84, 2: 0.95, 3: 1.06, 4: 1.17, 5: 1.29, 6: 1.40, 7: 1.51, 8: 1.62, 9: 1.73, 10: 1.84,
            11: 1.95, 12: 2.07, 13: 2.18, 14: 2.29, 15: 2.40}
L_TARGET = {1: 1.95, 2: 1.97, 3: 1.99, 4: 2.00, 5: 2.02, 6: 2.04, 7: 2.06, 8: 2.08, 9: 2.09, 10: 2.11,
            11: 2.13, 12: 2.15, 13: 2.16, 14: 2.18, 15: 2.20}
V_TARGET = {10: 3, 11: 7, 12: 10, 13: 13, 14: 17, 15: 20}          # vide minimal (% du masque niveau 1)
O_PLAFOND, L_MAX = 2.40, 2.20
# dessus du socle (z de la couronne), doit correspondre à gun_kit.socle()
SOCLE_TOP = {2: 0.32, 3: 0.34, 4: 0.28, 5: 0.36, 6: 0.26, 7: 0.33, 8: 0.30, 9: 0.28, 10: 0.41, 11: 0.45,
             12: 0.30, 13: 0.51, 14: 0.35, 15: 0.35}
EMIT_HEX = {3: "#FFC060", 4: "#FF8C1A", 5: "#FF4A10", 6: "#60D0FF", 7: "#B070FF", 8: "#A8FF3A", 9: "#5CFF4A",
            10: "#3AA8FF", 11: "#BFE6FF", 12: "#4AF0FF", 13: "#FF4FD8", 14: "#FF2A2A", 15: "#FFF2C0"}

# bible §5, fiches « Mitrailleuse » : silhouette du niveau impair (tête + socle) et pièce du niveau pair
SILHOUETTE = {
    1: "vanilla (Q11)",
    2: "FORGE : caisson riveté à 2 canons, bouclier frontal plat qui dépasse au-dessus de la tête ; socle octogonal cerclé",
    3: "VAPEUR : chaudière compacte sur le dos de la culasse, cheminée courte sur l'axe ; 2 canons longs à ailettes ; tuyaux ; socle rond en fonte nervurée",
    4: "PÉTROLE : caisson jaune délavé à chevrons, 2 bidons-chargeurs latéraux, 3 canons ; garde-corps sur le toit ; plate-forme à patins",
    5: "VOLCAN : tête en coin (blindage incliné en écailles), 2 canons lourds à frein de bouche ; socle en tronc de pyramide à contreforts ; fentes de braise",
    6: "ÉLECTRICITÉ : moteur bobiné, 4 canons rotatifs ; 2 hautes piles d'isolateurs dorsales ; fût en pile d'isolateurs ; couronne d'isolateurs au socle",
    7: "CRISTAL : tête de bronze organique à 2 canons, grappe de cristaux sur le dos (cristal maître vertical près de l'axe, petits cristaux inégaux) ; socle de pierre taillée à hauts éclats",
    8: "MARAIS : capsule vert-de-gris à 2 canons et bulbe de verre (liquide luminescent) sur le milieu du dos ; fût bulbeux ; socle bombé à cosses",
    9: "ATOME : tête octogonale plombée chanfreinée, 2 canons à manchons de refroidissement, hublots verts, tour hyperboloïde sur l'axe ; socle octogonal en béton à contreforts",
    10: "HAUTE TECHNOLOGIE : dôme caréné, 4 canons qui sortent d'un manchon court, capteur optique, antenne fouet ; col élancé à bague lumineuse ; socle sur 3 pieds courts",
    11: "TITANE : fuseau effilé à ailerons (dorsal en flèche, latéraux courts), 2 canons longs gainés sur les flancs, chargeur sous le fuseau ; mât ; socle tripode à pieds en V",
    12: "SUPRACONDUCTEURS : fusil à rail (noyau haut sur l'axe, 2 longs rails, anneaux d'accélération) flottant au-dessus d'un socle annulaire, anneaux de lévitation",
    13: "FUSION : tête sphérique ceinturée d'un tore de plasma, 2 canons qui dépassent du tore ; col de cuivre bagué ; socle trépied",
    14: "ORBITE : tête-satellite (bus en feuille d'or), 2 canons, 2 petits panneaux dorés, parabole de profil et balise sur l'axe, caisson de munitions ; mât ; socle à 3 jambes",
    15: "LÉGENDE : couronne de 6 canons en étoile et 5 flèches, anneau-halo autour de la couronne, tronçons flottants ; socle-disque sur pied à anneau lumineux",
}
PIECE_NAME = {
    1: "arc de sacs de sable sur les coins avant et les flancs du socle (avant-centre libre), piquets",
    2: "caisse de munitions cerclée sur le flanc gauche (+ petite caisse), dépasse de 0,10 à gauche",
    3: "réservoir de vapeur debout au coin avant droit (manomètre, soupape), dépasse de 0,10 à droite",
    4: "passerelle à garde-corps autour de l'avant du socle, dépasse de 0,15 de chaque côté",
    5: "jupe d'écailles inclinées autour de l'avant du socle, dépasse au sud et sur les côtés",
    6: "2 condensateurs (piles d'isolateurs courtes à éclateur) aux coins avant",
    7: "grappes de cristaux aux coins avant",
    8: "bonbonne de verre (liquide luminescent) sur le flanc gauche",
    9: "plaques plombées à trèfle devant les coins avant",
    10: "petit radôme de visée au coin avant droit",
    11: "ailerons de socle aux coins avant (lignes lumineuses)",
    12: "anneau flottant chromé autour du socle, dépasse de chaque côté",
    13: "injecteurs à plasma aux coins avant",
    14: "mât-balise et son coffret au coin avant gauche",
    15: "petites flèches à feu aux coins avant",
}
DESCR = {}
for _e in range(1, 16):
    DESCR[2 * _e - 1] = SILHOUETTE[_e]
    DESCR[2 * _e] = "silhouette du niveau %d + pièce : %s" % (2 * _e - 1, PIECE_NAME[_e])

VANILLA_BASE_MASK = {
    "hr": {"file": "gun-turret/hr-gun-turret-base.png", "shift": (0.015625, -0.03125)},
    "lr": {"file": "gun-turret/gun-turret-base.png", "shift": (0.03125, -0.03125)},
}


def load_params():
    p = {"zg": {}, "gain": {}}
    path = os.path.join(HERE, "params.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            raw = json.load(f)
        for k in ("zg", "gain"):
            p[k] = {int(e): float(v) for e, v in raw.get(k, {}).items()}
    for e in EPOCHS:
        p["zg"].setdefault(e, (O_TARGET[e] + 1.0) / math.sqrt(0.5) - 1.45)
        p["gain"].setdefault(e, 1.9)
    return p


def level_variants(level):
    """Variantes qui composent un niveau (1..30), dans l'ordre de dessin : socle puis tête."""
    e = (level + 1) // 2
    if level == 1:
        return None
    if level == 2:
        return {"socle": ["e01-piece-flancs", "e01-piece-avant"], "tete": None}
    s = "e%02d-socle-piece" % e if level % 2 == 0 else "e%02d-socle" % e
    return {"socle": [s], "tete": {d: "e%02d-tete-%s" % (e, d) for d in DIRS}}


def _variants():
    v = {
        "e01-piece-avant": {"epoch": 1, "part": "piece-avant", "level": 2},
        "e01-piece-flancs": {"epoch": 1, "part": "piece-flancs", "level": 2, "mask": VANILLA_BASE_MASK},
    }
    for e in EPOCHS[1:]:
        v["e%02d-socle" % e] = {"epoch": e, "part": "socle", "level": 2 * e - 1}
        v["e%02d-socle-piece" % e] = {"epoch": e, "part": "socle-piece", "level": 2 * e}
        for d in DIRS:
            v["e%02d-tete-%s" % (e, d)] = {"epoch": e, "part": "tete", "dir": d, "level": 2 * e - 1}
    for name, meta in v.items():
        meta["dest"] = "levels/gun/" + name
        meta["anchor_tiles"] = (0.0, 0.0)
    return v


PIECE = {
    "name": "gun",
    "variants": _variants(),
    "margin_px": 40,
}


# --- halo de nuit (bible §1.6, D2-3, proposition ❔) : I(N) = 0,05 + 0,02·N ; taille S(N) = s·(1 + 0,05·N)
# tuiles (s = 2, côté de l'emprise), lue comme un DIAMÈTRE (LightDefinition.size) : rayon nul = S(N)/2.
# Porté par le SOCLE (base_picture, 1 direction : la flaque ne tourne pas avec la tête). Époques 1 et 2 : aucune
# source de lumière dans la fiche « Mitrailleuse » (lumière « — »), donc pas de halo.
def halo_intensity(level):
    return 0.05 + 0.02 * level


def halo_radius(level):
    return 2.0 * (1.0 + 0.05 * level) / 2.0


def margin_px(name):
    v = PIECE["variants"][name]
    if v["part"] in ("socle", "socle-piece") and v["epoch"] >= 3:
        return max(40, int(64 * halo_radius(v["level"])) - 50)
    return PIECE["margin_px"]


def build(S, C, variant):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import gun_kit as G
    v = PIECE["variants"][variant]
    e, part = v["epoch"], v["part"]
    P = load_params()
    M = G.materials(S, e, P["gain"][e])
    if part.startswith("piece-"):
        k = G.K(S, C, "p")
        G.piece_e01(k, M, part.split("-", 1)[1])
        return k
    if part in ("socle", "socle-piece"):
        k = G.K(S, C, "s")
        z0 = G.socle(k, e, M)
        assert abs(z0 - SOCLE_TOP[e]) < 1e-9, (e, z0)
        if part == "socle-piece":
            kp = G.K(S, C, "pp")
            G.piece(kp, e, M)
        if e >= 3:
            # source du halo de nuit de la TÊTE, portée par le socle (sur l'axe, à la hauteur des canons) : la
            # flaque au sol ne dépend pas de la direction de la tête (passe light du socle seulement)
            k.halo((0.0, 0.0, P["zg"][e]), G.emit_rgb(EMIT_HEX[e]), 20.0)
        return k
    import gun_heads as GH
    k = G.K(S, C, "t")
    GH.head(k, e, M, SOCLE_TOP[e], P["zg"][e])
    k.rotate(DIRS[v["dir"]])
    return k
