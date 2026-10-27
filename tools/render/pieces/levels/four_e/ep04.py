"""Four · Âge 4 · Pétrole (ère II, 3×3, niveaux 7 et 8). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 4. S'exécute
DANS Blender.

En 3 mots : « colonne jaune, brûleurs, torchère ». La chambre est un FOUR DE RAFFINERIE debout : COLONNE cylindrique
jaune de signalisation, bandes noires rivetées, jupe à bande de danger, toit conique noir, passerelle annulaire et
échelle, hublots de flamme orange ; trois BRÛLEURS à volant rouge piqués dans la jupe, nourris par une rampe noire à
brides jaunes ; pompe à huile et fûts devant ; TORCHÈRE fine à l'arrière droit, flamme orange au sommet (la fumée).
Palette 60/30/10 (ages.PALETTE[4]) : jaune / noir (tôles larmées) / rouge des volants ; flamme orange.
"""
import math

import ages
import corps
import formes as F
import parts2 as P2
from kit import TAU
from repere import Y

EPOQUE = 4
NOM = ages.NOMS[4]
TRIPLET = ("colonne jaune", "brûleurs", "torchère")
FOYER = ages.FOYER[4]
HABILLAGE = dict(ages.CORPS[4], foyer="noir_capot")
CX, CYN, R = -0.25, 0.3, 0.82


def matieres(metal, M):
    ages.matieres(4, metal, M)


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    y = Y(CYN)
    # jupe noire à bande de danger
    g.cyl((CX, y, zs + 0.14), "z", R + 0.08, 0.28, M["noir_capot"], n=40, what="jupe")
    F.hazard_ring(g, (CX, y, zs + 0.2), "z", R + 0.08, 0.1, n=16)
    # virole jaune, bandes noires rivetées
    z0, z1 = zs + 0.28, 1.85
    g.cyl((CX, y, (z0 + z1) / 2), "z", R, z1 - z0, M["jaune_capot"], n=44, what="virole")
    for z in (0.72, 1.22, 1.78):
        g.tube_shell((CX, y, z), "z", R + 0.022, R - 0.02, 0.06, M["noir_capot"], n=44, what="bande")
        for k in range(18):
            a = math.pi + math.pi * (k + 0.5) / 18
            g.dome((CX + (R + 0.022) * math.cos(a), y + (R + 0.022) * math.sin(a), z), (math.cos(a), math.sin(a), 0),
                   0.014, M["galva_capot"])
    # toit conique, trou d'homme
    # ronde 1 : toit JAUNE (noir, il couvrait la colonne vue de dessus : on ne lisait plus le jaune dominant)
    g.cyl((CX, y, z1 + 0.18), "z", R + 0.02, 0.36, M["jaune_capot"], n=44, r2=0.22, style="soft", what="toit")
    for k in range(12):
        a = TAU * k / 12
        g.box((CX + (R * 0.62) * math.cos(a), y + (R * 0.62) * math.sin(a), z1 + 0.2), (R * 0.75, 0.035, 0.03),
              M["noir_capot"], "hard", R=corps.Matrix.Rotation(a, 3, "Z") @ corps.Matrix.Rotation(0.52, 3, "Y"),
              what="nervure_toit")
    g.cyl((CX, y, z1 + 0.4), "z", 0.24, 0.1, M["noir_capot"], n=20, what="trou_homme")
    g.cyl((CX, y, z1 + 0.47), "z", 0.12, 0.06, M["redpaint"], n=16, what="soupape")
    # passerelle annulaire (plancher et plinthe pleine) et échelle en façade
    g.tube_shell((CX, y, 1.4), "z", R + 0.2, R - 0.01, 0.035, M["tole_larmee"], n=44, what="passerelle")
    g.tube_shell((CX, y, 1.45), "z", R + 0.2, R + 0.18, 0.08, M["jaune_capot"], n=44, what="plinthe")
    for k in range(10):
        a = math.pi + math.pi * (k + 0.5) / 10
        g.box((CX + (R + 0.1) * math.cos(a), y + (R + 0.1) * math.sin(a), 1.36), (0.03, 0.03, 0.08), M["noir_capot"],
              "hard", what="console")
    xl = CX - 0.45
    yl = y - math.sqrt(R * R - 0.45 * 0.45) - 0.04
    for dx in (-0.08, 0.08):
        g.box((xl + dx, yl, (zs + 0.3 + 1.4) / 2), (0.02, 0.02, 1.1), M["galva_capot"], "hard", what="limon")
    for k in range(9):
        g.box((xl, yl, zs + 0.38 + k * 0.12), (0.16, 0.016, 0.016), M["galva_capot"], "hard", what="barreau")
    # hublots de flamme
    for a in (-2.1, -1.2, -0.55):
        p = corps.V((CX + R * math.cos(a), y + R * math.sin(a), 0.55))
        d = corps.V((math.cos(a), math.sin(a), 0))
        g.cyl(p + d * 0.01, d, 0.07, 0.03, M["noir_capot"], n=14, what="hublot_cadre")
        g.cyl(p + d * 0.03, d, 0.045, 0.01, M["emit"], n=14, style="flat", what="hublot")
    bruleurs(g, c)
    # pompe à huile (devant à droite) et fûts (devant à gauche)
    corps.boite(g, 0.72, 1.3, -0.9, -0.5, zs, zs + 0.32, [M["noir_capot"], M["tole_larmee2"]], panel=0.2, faces="ts")
    g.cyl((1.0, Y(-0.7), zs + 0.48), "x", 0.11, 0.42, M["jaune_capot"], n=20, what="moteur")
    P2.handwheel(g, (0.78, Y(-0.92), zs + 0.42), (0, -1, 0), 0.07, M, mat=M["redpaint"])
    for (x, yn) in ((-1.18, -0.82), (-0.92, -0.86), (-1.12, -0.52)):
        F.drum(g, (x, Y(yn), zs), 0.12, 0.34, M["jaune_capot"], M["noir_capot"], top=M["noir_capot"])


def bruleurs(g, c):
    """Trois brûleurs piqués dans la jupe, volant rouge, rampe noire à brides jaunes au sol."""
    M = g.M
    zs = c.T["sole_h"]
    y = Y(CYN)
    bouts = []
    for a_deg in (205.0, 243.0, 334.0):
        a = math.radians(a_deg)
        d = corps.V((math.cos(a), math.sin(a), 0))
        p0 = corps.V((CX, y, zs + 0.2)) + d * (R + 0.08)
        g.cyl(p0 + d * 0.16, d, 0.075, 0.32, M["noir_capot"], n=16, what="bruleur")
        g.cyl(p0 + d * 0.33, d, 0.09, 0.04, M["jaune_capot"], n=16, what="bride")
        g.cyl(p0 + d * 0.02, d, 0.1, 0.04, M["emit"], n=16, style="flat", what="flamme_bruleur")
        P2.handwheel(g, p0 + d * 0.2 + corps.V((0, 0, 0.11)), (0, 0, 1), 0.06, M, mat=M["redpaint"])
        bouts.append(p0 + d * 0.36)
    pts = [(b.x, b.y, zs + 0.06) for b in bouts]
    g.pipe([pts[0], (CX - 0.4, y - 1.25, zs + 0.06), pts[1]], 0.035, M["noir_capot"], fl_mat=M["jaune_capot"])
    for b in bouts:
        g.cyl((b.x, b.y, zs + 0.13), "z", 0.03, 0.14, M["noir_capot"], n=10, what="piquage")


def gueule(g, c, G):
    q = [corps.V((G["bx0"], G["yf"] - 0.012, G["bz1"] + 0.03)), corps.V((G["bx1"], G["yf"] - 0.012, G["bz1"] + 0.03)),
         corps.V((G["bx1"], G["yf"] - 0.012, G["bz1"] + 0.1)), corps.V((G["bx0"], G["yf"] - 0.012, G["bz1"] + 0.1))]
    g.hazard(q, 8, t=0.012)


def fumee(g, c):
    M = g.M
    f = c.T["fumee"]
    x, yn = f["x"] + 0.1, f["yn"] + 0.1
    y = Y(yn)
    zs = c.T["sole_h"]
    z1 = 2.55
    g.cyl((x, y, zs + 0.06), "z", 0.2, 0.12, M["noir_capot"], n=16, what="embase")
    g.cyl((x, y, (zs + z1) / 2), "z", 0.085, z1 - zs, M["galva_capot"], n=16, what="torchere")
    for z in (0.7, 1.4, 2.1):
        g.tube_shell((x, y, z), "z", 0.105, 0.07, 0.05, M["jaune_capot"], n=16, what="bague")
    g.cyl((x, y, z1 + 0.06), "z", 0.14, 0.12, M["noir_capot"], n=18, what="tete")
    corps.bouche_fumee(g, c, x, yn, z1 + 0.12, 0.12)
    g.cyl((x, y, z1 + 0.25), "z", 0.1, 0.26, M["emit"], n=12, r2=0.0, style="soft", what="flamme")
    g.halo((x, y - 0.2, z1 + 0.2), M["_emit_rgb"], 5.0)


def piece(g, c):
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        w = 2 * p["rw"] * 0.8
        g.box((p["x"], Y(p["yn"]), zs + 0.03), (w, Y(p["prof"] * 0.6), 0.06), M["bois_verni"] if "bois_verni" in M
              else M["wood"], "hard", what="palette")
        for k in range(3):
            x = p["x"] - w / 3 + w / 3 * k
            F.drum(g, (x, Y(p["yn"]) + (0.04 if k % 2 else -0.03), zs + 0.06), 0.11, 0.32,
                   M["jaune_capot"] if k != 1 else M["noir_capot"], M["noir_capot"] if k != 1 else M["jaune_capot"],
                   top=M["noir_capot"])
