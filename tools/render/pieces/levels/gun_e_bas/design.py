"""Mitrailleuse, lot V3-E, époques 1 à 9 (ères I, II, III) : une direction artistique par époque sur la lignée
« industriel lourd » retenue par le Directeur Créatif (22/10, 16 h 45). S'exécute DANS Blender.

Verdict du DC (mot pour mot) : « les dezigns actuel sçnt absoluement epoustçuflan surtout pour les canons et je
pense quil est facile de reprendre le meme style en mode changer des canons et des tuyaux àour correspondre a une
DA d un age ». Donc :
  - le CORPS reste celui de la lignée (colonne à goussets et couronne dentée, coupole rivetée, jupe à bandes,
    masque, nacelle, tourelleau ; trémie à trappe, caisses ouvertes, groupe électrogène, réservoirs debout,
    radiateur à ventilateurs, armoires), au même niveau de détail ;
  - chaque époque change ses CANONS et ses TUYAUX (parts4 : jaquettes, bouches, entraînement, alimentation,
    liaisons), puis ses accents, matières d'accent, foyers et pièces de signature (catalogue DA_PAR_EPOQUE §B) ;
  - emprise d'un cran par ère (Q-S1) : ère I 2×2 (époques 1 à 3, le niveau 1 reste vanilla), ère II 3×3 (4 à 6,
    corps du n11 de l'industriel), ère III 4×4 (7 à 9, corps nouveau entre le n11 et le n21) ;
  - corps dans la luminance de la charte (Q-S2), couleur d'époque dans de petits foyers seulement ;
  - puissance croissante d'une époque à la suivante (Q23) : dans une ère, chaque époque ajoute une machine, des
    plaques rapportées, des foyers et, à la 3e, une arme (coaxial, tourelle secondaire) ; tubes plus longs.
Corrections des juges faites en passant (catalogue §A.6) : bouches lisibles en pose N (frein plus large, rosace,
pourtour éclairé, culasses et magasins au pied des tubes), aucune bague blanche, aucun alignement de voyants,
tablier continu sous les machines (aucun trou enfermé), coins avant libres pour la pièce du niveau pair.
Conventions : 1 unité = une tuile en X ; une tuile de jeu vers le nord = 1,414 unité en Y (Y()) ; +Z haut.
"""
import math

from mathutils import Matrix, Vector

import parts as PT
import parts2 as P2
import parts3 as P3
import parts4 as P4
from kit import SQ2, TAU

V = Vector

SIDE = {1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4}
ERA = {1: 1, 2: 1, 3: 1, 4: 2, 5: 2, 6: 2, 7: 3, 8: 3, 9: 3}
KIN = {1: 0, 2: 1, 3: 2, 4: 0, 5: 1, 6: 2, 7: 0, 8: 1, 9: 2}   # rang de l'époque dans son ère
NAME = {1: "Pionnier", 2: "Forge", 3: "Vapeur", 4: "Pétrole", 5: "Volcan", 6: "Électricité", 7: "Cristal",
        8: "Marais", 9: "Atome"}


def Y(yn):
    """y de jeu en tuiles, vers le NORD -> Y Blender."""
    return yn * SQ2


# socle : rayon et hauteur de la colonne, hauteur de la couronne, pans
BASE = {2: dict(R=0.5, h=0.4, rh=0.07, n=10), 3: dict(R=0.8, h=0.6, rh=0.08, n=12),
        4: dict(R=1.05, h=0.8, rh=0.1, n=14)}


def ring_top(e):
    B = BASE[SIDE[e]]
    return B["h"] + B["rh"]


_H2 = dict(R=0.44, zs=0.74, rz=0.3, gx=0.62, zg=0.86, recv=(-0.24, 0.3), wr=0.2, hr=0.12)
_H3 = dict(R=0.68, zs=1.0, rz=0.42, gx=0.94, zg=1.15, recv=(-0.36, 0.5), wr=0.28, hr=0.16)
_H4 = dict(R=0.92, zs=1.3, rz=0.52, gx=1.24, zg=1.47, recv=(-0.5, 0.66), wr=0.37, hr=0.21)
HEAD = {
    2: dict(_H2, L=0.85, nb=3, rb=0.046, rr=0.072),
    3: dict(_H2, L=0.95, nb=4, rb=0.04, rr=0.078),
    4: dict(_H3, L=1.2, nb=4, rb=0.045, rr=0.1),
    5: dict(_H3, L=1.28, nb=4, rb=0.054, rr=0.115),
    6: dict(_H3, L=1.35, nb=4, rb=0.045, rr=0.1),
    7: dict(_H4, L=1.6, nb=6, rb=0.05, rr=0.125),
    8: dict(_H4, L=1.7, nb=6, rb=0.052, rr=0.128),
    9: dict(_H4, L=1.8, nb=6, rb=0.052, rr=0.128),
}

# styles d'époque (emplacements E1 à E5 du catalogue) : noms de matières de kit.materials
ST = {
    2: dict(jacket="forge", brake="crown", drive="crank", band="blackiron", recv_mats=("bolted", "rawiron"),
            recv_sig="lever", feed="crate_belt", skirt="blackiron", appl="bolted", gmask=("bolted", "rawiron"),
            arm=("bolted", "blackiron"), cap="brass", mask="shield", jacket_f=0.6, col=("bolted", "blackiron"),
            nac=("bolted", "rawiron"), arr="row", barrel="blackiron"),
    3: dict(jacket="steam", brake="steam", drive="steam", band="brass", recv_mats=("castiron", "castiron"),
            feed="drum", drum_mat="brass", skirt="brass", appl="copper_pol", gmask=("castiron", "olive"),
            arm=("olive", "castiron"), cap="brass", jacket_f=0.66, col=("olive", "castiron"),
            nac=("castiron", "olive")),
    4: dict(jacket="galva", brake="slots", drive="motor", drive_mat="steel_dk", band="galva",
            recv_mats=("yellowpaint", "yellowpaint"), recv_sig="stripes", feed="barrels", skirt="galva",
            appl="yellowpaint", gmask=("yellowpaint", "olive"), arm=("olive", "steel_dk"), cap="galva",
            col=("olive", "steel_dk"), nac=("olive", "yellowpaint")),
    5: dict(jacket="hex", brake="wedge", drive="scale", drive_mat="tungsten", fin_mat="burnrust", band="burnrust",
            recv_mats=("tungsten", "burnrust"), recv_sig="scales", feed="armored", skirt="burnrust", appl="tungsten",
            gmask=("tungsten", "burnrust"), arm=("tungsten", "olive"), cap="burnrust", mask="glacis",
            col=("tungsten", "olive"), nac=("tungsten", "burnrust"), flange_mat="burnrust"),
    6: dict(jacket="coils", brake="insul", drive="coil", band="copper", recv_mats=("ochre", "olive"), feed="drum",
            skirt="copper", appl="ochre", gmask=("ochre", "olive"), arm=("olive", "steel_dk"), cap="copper",
            col=("olive", "steel_dk"), nac=("olive", "ochre"), coax=True),
    7: dict(jacket="bronze", brake="claws", drive="crystal", drive_mat="bronze", fin_mat="bronze", band="bronze",
            barrel="bronze", recv_mats=("bronze", "stone"), recv_sig="stone", feed="crystal_mag", skirt="bronze",
            appl="bronze", gmask=("bronze", "olive"), arm=("stone", "olive"), cap="bronze", flange_mat="stone",
            col=("olive", "stone"), nac=("olive", "bronze")),
    8: dict(jacket="marsh", brake="nozzle", drive="motor", drive_mat="verdigris", fin_mat="steel_dk",
            band="verdigris", recv_mats=("verdigris", "olive"), feed="hoses", skirt="rubber", appl="verdigris",
            gmask=("olive", "verdigris"), arm=("olive", "steel_dk"), cap="brass", col=("olive", "verdigris"),
            nac=("olive", "verdigris"), coax=True),
    9: dict(jacket="atom", brake="octo", drive="lead", drive_mat="lead", drive_n=8, band="lead",
            recv_mats=("lead", "steel_dk"), recv_sig="porthole", feed="lead_mag", skirt="hazy", appl="lead",
            gmask=("lead", "olive"), arm=("lead", "steel_dk"), cap="lead", col=("olive", "lead"),
            nac=("lead", "olive"), coax=True),
}


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


class at:
    """Repère local posé en (x, y de jeu vers le nord, z), tourné de rz : `with at(g, x, yn, rz): ...`."""

    def __init__(self, g, x, yn, rz=0.0, z=0.0):
        self.g, self.a = g, ((x, Y(yn), z), rz)

    def __enter__(self):
        self.g.push(self.a[0], rz=self.a[1])
        return self.g

    def __exit__(self, *exc):
        self.g.pop()


# ------------------------------------------------------------------------------------------------
# Socle : éléments communs
# ------------------------------------------------------------------------------------------------
def column(g, e):
    M = g.M
    B = BASE[SIDE[e]]
    st = ST.get(e, ST[2])
    c0, c1 = st["col"]
    P2.pedestal(g, B["R"], 0.0, B["h"], B["n"], M, [M[c0], M["steel_dk"], M[c0], M[c1]],
                ladder_at=-math.pi * 0.72)
    PT.slewing_ring(g, B["R"] - 0.02, B["h"], B["rh"])


def deck(g, side, notch, inset=0.3, e=6):
    """Tablier bas continu (catalogue §A.6 : aucun trou enfermé) sous et ENTRE les machines, RENTRÉ de `inset` sous
    le contour (le contour reste fait de machines, jamais une dalle carrée), coins avant laissés libres (pièce du
    niveau pair). notch : demi-largeur de la bande sud et début de l'encoche. Matière d'époque (P4.deck_e)."""
    h = side / 2.0 - inset
    P4.deck_e(g, e, -h, h, Y(-notch), Y(h), 0.05)
    if notch < h - 0.12:
        P4.deck_e(g, e, -notch, notch, Y(-(h - 0.12)), Y(-notch), 0.05)


# munitions visibles dans la trémie (étui, balle) : la cartouche dit aussi l'âge
BELT = {2: ("brass", "rawiron"), 3: ("brass", "copper"), 4: ("brass", "copper"), 5: ("tungsten", "burnrust"),
        6: ("copper", "steel_hi"), 7: ("bronze", "emit_soft"), 8: ("verdigris", "emit_soft"), 9: ("lead", "uranium")}


def hopper(g, e, x0, x1, y0, y1, h, ring):
    """Trémie de la lignée, peinture d'époque, goulotte vers la couronne, voyants en petit groupe."""
    M = g.M
    paint = {2: "bolted", 3: "castiron", 4: "yellowpaint", 5: "tungsten", 6: "ochre", 7: "bronze", 8: "olive",
             9: "lead"}[e]
    out = P3.hopper_top(g, x0, x1, y0, y1, 0.0, h, M, paint=M[paint], stencils=(e >= 4),
                        belt_mats=tuple(M[k] for k in BELT[e]))
    P2.feed_chute(g, [tuple(out), (0.0, ring[0], ring[1] - 0.02), (0.0, ring[2], ring[1] + 0.02)],
                  0.11 + 0.03 * (SIDE[e] - 2), M)
    if e >= 3:
        P4.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=2 + (e >= 6))
    return out


# ------------------------------------------------------------------------------------------------
# Ère I (2×2) : époques 2 et 3 (le niveau 1 est la mitrailleuse vanilla)
# ------------------------------------------------------------------------------------------------
def _socle_era1(g, e):
    M = g.M
    E = M["emit"]
    k = KIN[e]
    deck(g, 2, 0.48, inset=0.24, e=e)
    column(g, e)
    rt = ring_top(e)
    hopper(g, e, -0.3, 0.3, Y(-0.97), -0.74, 0.32, (-0.62, rt, -0.42))
    # est : réservoir (forge : acier boulonné ; vapeur : chaudière rivetée plus haute à hublot et sifflet)
    hh = 0.46 if k == 1 else 0.58
    P4.tank_e(g, e, 0.74, Y(0.12), 0.19, hh, E, ladder_dir=(1, 0.4), stub_dir=(-1, 0), gauges=1 + (e >= 3))
    # ouest : petit groupe électrogène à 2 cylindres (volant d'inertie à la forge, régulateur à boules à la vapeur)
    P4.engine_e(g, e, -0.97, -0.6, Y(-0.42), Y(0.4), 0.0, 0.26, 2, emat=E)
    # nord-ouest : pile de caisses
    with at(g, -0.66, 0.66, 0.3):
        PT.crate(g, (0, 0, 0), (0.36, 0.3, 0.17), mat=M["wood"] if e == 2 else M["olive"])
        PT.crate(g, (0.02, 0.0, 0.2), (0.3, 0.24, 0.14), mat=M["wood2"] if e == 2 else M["ochre"])
    # nord : radiateur bas
    P2.fan_radiator(g, -0.34, 0.34, Y(0.64), Y(0.95), 0.0, 0.2, 2, M)
    if e == 2:
        # conduit d'air riveté (soufflet), chaîne de transmission du volant vers la colonne, tuyau de fer noir
        P4.duct(g, [(-0.62, Y(0.25), 0.2), (-0.5, Y(0.25), 0.34), (-0.36, Y(0.18), 0.36)], 0.09, 0.07)
        P4.chain(g, (-0.79, Y(-0.42) - 0.12, 0.2), (-0.4, Y(-0.3), 0.3), sag=0.03)
        P4.link(g, 2, [(0.56, Y(0.12), 0.25), (0.48, Y(0.05), 0.36), (0.36, Y(0.0), 0.38)], 0.045)
        # lanterne (nuit) sur la pile de caisses, fentes de forge sur le groupe
        P4.lantern(g, (-0.64, Y(0.66) - 0.02, 0.37), E)
        for i in range(2):
            g.box((-0.6 - 0.004, Y(-0.12) + i * 0.1, 0.1), (0.008, 0.06, 0.03), E, "flat", what="forge")
        _halo(g, [(-0.64, Y(0.6), 0.55), (-0.5, Y(-0.12), 0.3)], 10.0)
    else:
        # vapeur : tuyaux de cuivre coudés à brides de laiton, tuyau de vapeur calorifugé, manomètres, soupape
        P4.link(g, 3, [(0.56, Y(0.12), 0.25), (0.48, Y(0.05), 0.38), (0.36, Y(0.0), 0.4)], 0.045)
        lag = [V((0.74, Y(0.12) + 0.2, hh + 0.02)), V((0.55, Y(0.3), hh + 0.06)), V((0.3, Y(0.42), 0.42))]
        S_, T = g.tube(g.spline(lag, 8), 0.035, M["canvas"], n=10, what="calorifuge")
        for i in range(1, len(S_) - 1, 3):
            g.tube_shell(S_[i], T[i], 0.042, 0.03, 0.016, M["brass"], n=12, what="cerclage")
        P4.link(g, 3, [(-0.6, Y(-0.1), 0.2), (-0.5, Y(-0.1), 0.33), (-0.36, Y(-0.1), 0.36)], 0.035)
        P2.gauge(g, (-0.6 - 0.02, Y(0.25), 0.18), (-1, 0, 0.3), 0.04, M)
        P2.gauge(g, (0.25, Y(-0.97) - 0.03, 0.12), (0, -1, 0.3), 0.038, M)
        # instruments de la vapeur (puissance de la 3e époque de l'ère : plus de pièces, catalogue §A.5)
        P2.gauge(g, (-0.25, Y(-0.97) - 0.03, 0.2), (0, -1, 0.3), 0.032, M)
        P2.gauge(g, (-0.97 - 0.02, Y(-0.3), 0.17), (-1, 0, 0.3), 0.034, M)
        P2.handwheel(g, (-0.5, Y(-0.1), 0.42), (0, 0, 1), 0.05, M)
        for xx in (0.22, -0.22):  # soupapes posées sur le radiateur nord (dessus à z = 0,2)
            g.cyl((xx, Y(0.8), 0.25), "z", 0.022, 0.1, M["brass"], n=10, what="soupape")
            g.cyl((xx, Y(0.8), 0.31), "z", 0.034, 0.02, M["brass"], n=12, what="chapeau")
        # 2e machine (3e époque de l'ère) : armoire au nord-est, soupape à levier
        P4.cabinet_e(g, 0.5, 0.92, Y(0.62), Y(0.95), 0.0, 0.3, M, E, [M["castiron"], M["olive"]], lamps=2)
        g.box((0.8, Y(0.12) - 0.1, hh + 0.12), (0.12, 0.016, 0.016), M["steel_hi"], "hard", what="levier")
        # hublots de foyer sur le groupe
        for i in range(2):
            d = V((-1, 0, 0))
            c = V((-0.97 - 0.004, Y(-0.25) + i * 0.32, 0.13))
            g.cyl(c, d, 0.034, 0.02, M["brass"], n=14, what="hublot_cadre")
            g.cyl(c + d * 0.011, d, 0.022, 0.006, E, n=14, style="flat", what="hublot")
        _halo(g, [(0.74, Y(0.0), 0.4), (-1.0, Y(0.0), 0.3), (0.0, Y(-1.0), 0.3)], 12.0)


# ------------------------------------------------------------------------------------------------
# Ère II (3×3) : époques 4, 5, 6 (corps du n11 de l'industriel, coins avant dégagés)
# ------------------------------------------------------------------------------------------------
def _socle_era2(g, e):
    M = g.M
    E = M["emit"]
    k = KIN[e]
    deck(g, 3, 0.86, e=e)
    column(g, e)
    rt = ring_top(e)
    hopper(g, e, -0.38, 0.38, Y(-1.42), -1.0, 0.46, (-0.9, rt, -0.66))
    with at(g, -0.98, -0.62, 0.38):
        P2.open_crate(g, (0, 0, 0), 0.48, 0.5, 0.24, M, paint=M["olive"] if e != 4 else M["yellowpaint"])
    with at(g, 0.98, -0.62, -0.32):
        PT.crate(g, (0, 0, 0), (0.44, 0.44, 0.27), mat=M[{4: "galva", 5: "tungsten", 6: "olive"}[e]])
        if e >= 5:
            P4.lamp_group(g, (-0.1, -0.24, 0.2), (1, 0, 0), (0, -1, 0), E, n=2)
    # est : réservoir (cuve couchée à l'époque 4)
    P4.tank_e(g, e, 1.12, Y(0.3), 0.3, 0.62 + 0.08 * (k == 2), E, ladder_dir=(1, 0.3), stub_dir=(-1, 0),
              gauges=2, rings=(1 if e == 6 else 0))
    # ouest : groupe électrogène (4, 5) ; batterie à isolateurs du témoin n11 (6)
    if e == 6:
        PT.hull(g, -1.45, -0.98, Y(-0.4), Y(0.72), 0.0, 0.34, ins=(0.02, 0.02, 0.02), panel=0.26,
                mats=[M["olive"], M["steel_dk"]], rivet_step=0.13)
        for dy in (-0.42, 0.0, 0.42):
            PT.insulators(g, (-1.21, Y(0.16) + dy, 0.34), 4, 0.045)
        for dy in (-0.21, 0.21):
            g.box((-1.21, Y(0.16) + dy, 0.34 + 4 * 0.034 + 0.02), (0.024, 0.34, 0.024), E, "flat", what="arc")
        for dy in (-0.3, 0.3):  # bobines de cuivre rondes posées sur la batterie (hybride, gros plan n11)
            g.cyl((-1.38, Y(0.16) + dy, 0.42), "y", 0.05, 0.12, M["steel_dk"], n=18, what="noyau")
            for t in range(4):
                g.torus((-1.38, Y(0.16) + dy - 0.045 + t * 0.03, 0.42), "y", 0.056, 0.012, M["copper"], n=22, m=6,
                        what="spire")
    else:
        P4.engine_e(g, e, -1.46, -0.98, Y(-0.4), Y(0.72), 0.0, 0.34, 3 + (k >= 1), emat=E)
    # nord : radiateur à ventilateurs
    P2.fan_radiator(g, -0.6, 0.6, Y(1.0), Y(1.42), 0.0, 0.28, 2, M, emat=(E if e >= 5 else None))
    # nord-est : armoire ; nord-ouest : caisses en biais
    P4.cabinet_e(g, 0.7, 1.38, Y(0.98), Y(1.38), 0.0, 0.4, M, E,
                 [M[{4: "yellowpaint", 5: "tungsten", 6: "olive"}[e]], M["steel_dk"]], lamps=2 + (k >= 1))
    with at(g, -1.08, 1.12, 0.3):
        PT.crate(g, (0, 0, 0), (0.5, 0.42, 0.24), mat=M["olive"])
        if k >= 1:  # machine de plus (2e époque de l'ère) : 2e caisse empilée
            PT.crate(g, (0.02, 0.0, 0.27), (0.42, 0.34, 0.2), mat=M["ochre"])
    # liaisons d'époque
    P4.link(g, e, [(0.84, Y(0.42), 0.3), (0.72, Y(0.32), 0.5), (0.58, Y(0.22), 0.56)], 0.06)
    P4.link(g, e, [(-0.98, Y(0.45), 0.3), (-0.86, Y(0.4), 0.48), (-0.7, Y(0.3), 0.55)], 0.055)
    P4.link(g, e, [(0.0, Y(1.0), 0.3), (0.05, Y(0.8), 0.5), (0.05, Y(0.55), 0.62)], 0.05)
    if e == 4:
        # fûts empilés à côté de la trémie, flexibles noirs, torchère (pied au sol, tige fine)
        for i, (x, yn) in enumerate(((0.62, -1.12), (0.62, -1.38))):
            barrel_drum(g, (x, Y(yn), 0.0), 0.11, 0.3, M["yellowpaint"] if i else M["galva"])
        g.hose([(1.0, Y(-0.05), 0.2), (0.85, Y(-0.25), 0.35), (0.6, Y(-0.35), 0.5)], 0.035, M["rubber"])
        P4.lamp_group(g, (0.72, Y(1.38) + 0.02, 0.3), (1, 0, 0), (0, 1, 0), E, n=2)
        _halo(g, [(1.12, Y(0.0), 0.4), (-1.2, Y(0.2), 0.45), (0.0, Y(-1.5), 0.35), (1.0, Y(1.4), 0.4)], 16.0)
    elif e == 5:
        # pointes de basalte aux arêtes des machines, contreforts inclinés sur les armoires, fentes de braise
        for (x, yn) in ((0.7, 0.98), (1.38, 0.98)):
            g.box((x, Y(yn) - 0.06, 0.18), (0.06, 0.16, 0.34), M["tungsten"], "hard", R=Matrix.Rotation(0.45, 3, "X"),
                  what="contrefort")
        for (x, yn, z) in ((-1.45, -0.4, 0.36), (-0.98, 0.72, 0.36), (0.6, 1.42, 0.3), (-0.6, 1.42, 0.3)):
            g.cyl((x, Y(yn), z + 0.05), (0.2 * (1 if x > 0 else -1), -0.3, 1), 0.035, 0.13, M["basalt"], n=5,
                  r2=0.004, style="hard", what="pointe")
        for i in range(3):
            g.box((-0.38 - 0.004, Y(-1.3) + i * 0.16, 0.15), (0.008, 0.08, 0.016), E, "flat", what="braise")
        _halo(g, [(-1.2, Y(0.2), 0.4), (1.1, Y(0.1), 0.4), (0.0, Y(-1.5), 0.35), (1.0, Y(1.4), 0.4)], 16.0)
    else:
        # électricité (témoin n11) : câbles sur isolateurs, jeu de barres de cuivre, plaques haute tension, arcs
        for i in range(2):
            g.box((-0.85 + i * 0.07, Y(-0.2), 0.42), (0.03, 0.5, 0.03), M["copper"], "hard", what="barre")
        for s in (-0.85, -0.78):
            PT.insulators(g, (s, Y(-0.38), 0.2), 2, 0.03, h=0.03)
        g.box((-1.2, Y(-0.42) - 0.01, 0.2), (0.1, 0.012, 0.08), M["hazy"], "flat", what="haute_tension")
        _halo(g, [(-1.2, Y(0.16), 0.6), (1.02, Y(-0.7), 0.45), (1.12, Y(0.0), 0.4), (0.0, Y(-1.5), 0.35)], 16.0)
    if k == 2:
        # 3e époque de l'ère : étage de plus (réservoir plus haut : déjà), 2e armoire au sud-ouest
        P4.cabinet_e(g, -1.45, -1.06, Y(-0.95), Y(-0.72), 0.0, 0.38, M, E, [M["olive"], M["steel_dk"]], lamps=2)


def barrel_drum(g, c, r, h, mat):
    """Fût debout (pétrole) : virole, bandes de roulement, bondes."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + h / 2), "z", r, h, mat, n=20, what="fut")
    for f in (0.3, 0.7):
        g.tube_shell((x, y, z + h * f), "z", r + 0.012, r - 0.01, 0.025, M["hazk"], n=20, what="bande")
    g.cyl((x, y, z + h + 0.005), "z", r * 0.9, 0.012, M["steel_dk"], n=20, what="fond")
    g.cyl((x + r * 0.45, y, z + h + 0.016), "z", 0.02, 0.02, M["brass"], n=8, what="bonde")


# ------------------------------------------------------------------------------------------------
# Ère III (4×4) : époques 7, 8, 9 (corps nouveau dans la lignée, entre le n11 et le n21)
# ------------------------------------------------------------------------------------------------
def _socle_era3(g, e):
    M = g.M
    E = M["emit"]
    k = KIN[e]
    deck(g, 4, 1.14, e=e)
    column(g, e)
    rt = ring_top(e)
    hopper(g, e, -0.44, 0.44, Y(-1.93), -1.3, 0.58, (-1.2, rt, -0.9))
    with at(g, -0.86, -1.5, 0.3):
        P2.open_crate(g, (0, 0, 0), 0.5, 0.52, 0.26, M)
    with at(g, 0.86, -1.5, -0.3):
        P2.open_crate(g, (0, 0, 0), 0.5, 0.52, 0.26, M, paint=M["ochre"])
    # ouest : groupe électrogène à 4 cylindres
    P4.engine_e(g, e, -1.95, -1.32, Y(-1.05), Y(0.95), 0.0, 0.46, 4 + (k >= 1), emat=E)
    # est : deux réservoirs debout (le 2e plus haut à la 3e époque)
    P4.tank_e(g, e, 1.6, Y(0.72), 0.33, 0.78, E, ladder_dir=(1, 0.2), stub_dir=(-1, 0), gauges=2,
              rings=(1 if e >= 8 else 0))
    P4.tank_e(g, e, 1.6, Y(-0.5), 0.33, 0.78 + 0.16 * (k == 2), E, ladder_dir=(1, -0.2), stub_dir=(-1, 0), gauges=2,
              rings=(1 if e >= 8 else 0))
    # nord-ouest : radiateur à ventilateurs posé en biais
    with at(g, -1.35, 1.5, -0.55):
        P2.fan_radiator(g, -0.48, 0.48, -0.36, 0.36, 0.0, 0.34, 2, M, emat=E)
    # nord : caisses de réserve ; nord-est : armoire (ou tourelle secondaire à la 3e époque)
    PT.crate(g, (-0.3, Y(1.62), 0.0), (0.56, 0.5, 0.26), mat=M["olive"])
    if k >= 1:  # machine de plus : 2e armoire au nord
        P4.cabinet_e(g, 0.12, 0.82, Y(1.45), Y(1.88), 0.0, 0.48, M, E, [M["olive"], M["steel_dk"]], lamps=3)
    else:
        PT.crate(g, (0.42, Y(1.62), 0.0), (0.56, 0.5, 0.26), mat=M["ochre"])
    if k == 2:
        # dalle sous la tourelle secondaire jusqu'au bord nord (trou enfermé de 12 px hr en pose N sinon)
        P4.deck_e(g, e, 0.95, 1.95, Y(1.1), Y(1.95), 0.05)
        with at(g, 1.5, 1.52, 0.0):
            P2.pedestal(g, 0.36, 0.0, 0.26, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            # orientée vers le nord-est : ses canons ne forment plus de poche avec le canon de flanc (pose N)
            mini_turret_e(g, e, (0, 0, 0.26), 0.82, -0.55, E)
    else:
        P4.cabinet_e(g, 1.05, 1.85, Y(1.42), Y(1.86), 0.0, 0.5, M, E,
                     [M[{7: "bronze", 8: "verdigris", 9: "lead"}[e]], M["steel_dk"]], lamps=3)
    P2.anchor(g, -1.85, Y(1.85), 0.24, M)
    # liaisons d'époque (machines -> colonne)
    P4.link(g, e, [(1.27, Y(0.72), 0.3), (1.12, Y(0.6), 0.62), (0.9, Y(0.42), 0.7)], 0.065)
    P4.link(g, e, [(1.27, Y(-0.5), 0.3), (1.12, Y(-0.42), 0.6), (0.92, Y(-0.3), 0.7)], 0.065)
    P4.link(g, e, [(-1.32, Y(0.5), 0.36), (-1.15, Y(0.45), 0.6), (-0.92, Y(0.35), 0.72)], 0.06)
    P4.link(g, e, [(-1.32, Y(-0.5), 0.36), (-1.15, Y(-0.45), 0.6), (-0.92, Y(-0.35), 0.72)], 0.06)
    P4.link(g, e, [(-1.0, Y(1.1), 0.3), (-0.8, Y(0.88), 0.62), (-0.62, Y(0.62), 0.76)], 0.055)
    P4.link(g, e, [(0.4, Y(1.42), 0.4), (0.38, Y(1.1), 0.68), (0.3, Y(0.7), 0.78)], 0.055)
    if e == 7:
        # plinthes de pierre, grappes de cristal serties sur les armoires, prismes
        P4.crystals(g, (1.45, Y(1.64), 0.53), 1.05)
        P4.crystals(g, (-0.3, Y(1.62), 0.29), 0.95)
        for x in (-0.9, 0.9):
            g.box((x, Y(-1.5) - 0.32, 0.03), (0.6, 0.08, 0.06), M["stone"], "hard", what="plinthe")
        _halo(g, [(1.45, Y(1.6), 0.8), (-1.6, Y(0.0), 0.6), (1.6, Y(0.1), 0.6), (0.0, Y(-2.0), 0.4)], 18.0)
    elif e == 8:
        # bonbonnes clissées, bocaux, conduits de caoutchouc annelé
        for (x, yn) in ((-1.62, -1.32), (-1.38, -1.4)):
            wicker_jug(g, (x, Y(yn), 0.0), 0.11)
        g.hose([(-1.6, Y(-1.25), 0.2), (-1.4, Y(-1.1), 0.45), (-1.32, Y(-0.9), 0.4)], 0.035, M["rubber"])
        _halo(g, [(1.6, Y(0.1), 0.6), (-1.6, Y(0.0), 0.6), (0.0, Y(-2.0), 0.4), (1.45, Y(1.6), 0.6)], 18.0)
    else:
        # plinthes de béton, balises de radiation, bandes jaunes et noires
        for x in (-0.9, 0.9):
            g.box((x, Y(-1.5) - 0.32, 0.03), (0.6, 0.08, 0.06), M["concrete"], "hard", what="plinthe")
        for (x, yn) in ((-1.85, 0.0), (0.0, 1.9)):
            beacon(g, (x, Y(yn), 0.04), E)
        g.hazard([V((-1.95, Y(-1.08), 0.05)), V((-1.32, Y(-1.08), 0.05)), V((-1.32, Y(-1.08) + 0.08, 0.05)),
                  V((-1.95, Y(-1.08) + 0.08, 0.05))], 6, t=0.01)
        _halo(g, [(1.6, Y(0.1), 0.6), (-1.6, Y(0.0), 0.6), (0.0, Y(-2.0), 0.4), (1.5, Y(1.5), 0.7)], 20.0)


def wicker_jug(g, c, r):
    """Bonbonne clissée (marais) : panier d'osier, col de verre lumineux."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + r * 0.9), "z", r, r * 1.8, M["wicker"], n=16, r2=r * 0.85, what="panier")
    for f in (0.2, 0.5, 0.8):
        g.tube_shell((x, y, z + r * 1.8 * f), "z", r * (1.0 - 0.15 * f) + 0.008, r * 0.8, 0.014, M["wood2"], n=16,
                     what="cercle")
    g.cyl((x, y, z + r * 1.8 + 0.05), "z", r * 0.35, 0.1, M["emit_soft"], n=12, r2=r * 0.25, what="col")
    g.cyl((x, y, z + r * 1.8 + 0.11), "z", r * 0.28, 0.025, M["rubber"], n=10, what="bouchon")


def beacon(g, c, emat):
    """Balise de radiation (atome) : poteau, feu vert, plaque jaune."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + 0.13), "z", 0.018, 0.26, M["steel_dk"], n=8, what="poteau")
    g.cyl((x, y, z + 0.28), "z", 0.035, 0.04, emat, n=12, what="feu")
    g.cyl((x, y, z + 0.31), "z", 0.04, 0.015, M["steel_dk"], n=12, what="chapeau")
    g.box((x, y - 0.02, z + 0.18), (0.08, 0.008, 0.06), M["hazy"], "flat", what="plaque")
    g.box((x, y, z + 0.01), (0.08, 0.08, 0.02), M["concrete"], "hard", what="semelle")


def mini_turret_e(g, e, c, s, rz, emat):
    """Tourelle secondaire (1re à la fin de l'ère III, catalogue §A.4) : celle de la lignée, canons d'époque 9."""
    M = g.M
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["lead"], n=8, style="hard", phase=math.pi / 8, what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    PT.hull(g, -0.24 * s, 0.24 * s, -0.3 * s, 0.24 * s, 0.1 * s, 0.4 * s, ins=(0.04 * s, 0.03 * s, 0.1 * s), panel=0.22,
            mats=[M["lead"], M["olive"]])
    for sx in (-1, 1):
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=[M["lead"], M["steel_dk"]])
        P4.barrels(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.55 * s, 4, 0.022, 0.045 * s, M["gun"], collars=(0.75,))
        g.cyl((sx * 0.31 * s, 0.22 * s + 0.17 * s, 0.26 * s), "y", 0.1 * s, 0.24 * s, M["lead"], n=8, style="hard",
              phase=math.pi / 8, what="jaquette")
        g.cyl((sx * 0.31 * s, 0.22 * s + 0.58 * s, 0.26 * s), "y", 0.085 * s, 0.08 * s, M["lead"], n=8, style="hard",
              phase=math.pi / 8, what="frein")
        P4.lit_ring(g, (sx * 0.31 * s, 0.22 * s + 0.625 * s, 0.26 * s), "y", 0.07 * s, emat)
    P4.trefoil(g, (0.0, -0.05 * s, 0.4 * s + 0.004), (0, 0, 1), 0.05)
    PT.lamp(g, (0.0, 0.12 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.03, emat, cage=False)
    g.pop()


def base_pipes(g, e):
    """Collecteur d'époque qui ceinture le pied de la colonne, côté avant (toujours visible) : « tuyaux et câbles
    partout » (charte §4.2), dans la matière et la forme de l'âge (fer noir à brides carrées, cuivre à brides de
    laiton, galvanisé, fonte à coudes vifs, câbles sur isolateurs, guide d'onde de bronze, caoutchouc et verre,
    gaine annelée de cuivre)."""
    B = BASE[SIDE[e]]
    r = B["R"] + 0.12 + 0.02 * (SIDE[e] - 2)
    z = 0.15 + 0.03 * (SIDE[e] - 2)
    angs = (-0.2, -0.85, -1.57, -2.29, -2.94)
    P4.link(g, e, [(r * math.cos(a), r * math.sin(a), z) for a in angs], 0.044 + 0.01 * (SIDE[e] - 2))


def socle(g, e):
    {1: _socle_era1, 2: _socle_era2, 3: _socle_era3}[ERA[e]](g, e)
    base_pipes(g, e)


# ------------------------------------------------------------------------------------------------
# Pièce des niveaux pairs (paire aux coins avant, ≥ 0,10 t² de masque nouveau ; catalogue §A.5 et §B)
# ------------------------------------------------------------------------------------------------
def piece(g, e):
    M = g.M
    E = M["emit"]
    if e == 1:
        _piece1(g)
        return
    side = SIDE[e]
    cx = {2: 0.74, 3: 1.16, 4: 1.55}[side]
    cy = -cx
    s = {2: 1.0, 3: 1.25, 4: 1.65}[side]
    # dalle d'époque sous chaque pièce, raccordée au tablier du socle : aucun jour enfermé entre la pièce, les
    # caisses ouvertes et la trémie (contrôle bloquant : 10 à 28 px hr sans elle)
    for sx in (-1, 1):
        xa, xb = sorted((sx * (cx - 0.3 - 0.07 * side), sx * (cx + 0.2 + 0.03 * side)))
        P4.deck_e(g, e, xa, xb, Y(cy - 0.24 - 0.02 * side), Y(cy + 0.34 + 0.06 * side), 0.05)
    if e == 2:
        # 2 mantelets d'acier (boucliers plats sur pieds, rivetés, créneau de visée), chacun appuyé contre une pile
        # de 2 caisses de munitions cerclées
        for sx in (-1, 1):
            with at(g, sx * (cx + 0.06), cy - 0.08, sx * -0.4):
                PT.crate(g, (0.0, 0.2, 0.0), (0.36, 0.26, 0.18), mat=M["wood"])
                PT.crate(g, (0.01, 0.2, 0.185), (0.3, 0.22, 0.15), mat=M["wood2"])
                P4.mantlet(g, (0.0, -0.04, 0.0), 0.0, w=0.54, h=0.4)
        _halo(g, [(-cx, Y(cy), 0.3), (cx, Y(cy), 0.3)], 6.0)
    elif e == 3:
        # 2 réservoirs de vapeur debout (cylindres rivetés, dôme, grand manomètre), reliés au socle par du cuivre
        for sx in (-1, 1):
            x, y = sx * cx, Y(cy)
            P3.vtank(g, x, y, 0.17, 0.56, M, paint=M["rawiron"], emat=E, ladder_dir=(sx, -0.3), gauges=0)
            for zz in (0.2, 0.44):
                g.tube_shell((x, y, zz), "z", 0.194, 0.16, 0.03, M["brass"], n=32, what="cerclage")
            g.cyl((x, y, 0.56 + 0.1), "z", 0.07, 0.08, M["copper_pol"], n=18, what="dome_vapeur")
            P2.gauge(g, (x - sx * 0.04, y - 0.185, 0.34), (-sx * 0.3, -1, 0.3), 0.075, M)
            P4.link(g, 3, [(x - sx * 0.13, y + 0.06, 0.14), (x - sx * 0.25, y + 0.2, 0.18),
                           (sx * 0.4, Y(-0.8), 0.18)], 0.034)
        _halo(g, [(-cx, Y(cy), 0.3), (cx, Y(cy), 0.3)], 8.0)
    elif e == 4:
        # 2 cuves-chargeurs couchées sur berceau, passerelle et garde-corps
        for sx in (-1, 1):
            x, y = sx * cx, Y(cy)
            P2.tank(g, (x, y + 0.05, 0.27), 0.19, 0.5, (1, 0, 0), M, paint=M["yellowpaint"], band=M["galva"])
            for f in (-0.17, 0.17):
                g.box((x + f, y + 0.05, 0.08), (0.07, 0.32, 0.16), M["steel_dk"], "hard", what="berceau")
            g.box((x, y - 0.24, 0.03), (0.6, 0.12, 0.05), M["grate"], "hard", what="passerelle")
            # garde-corps plein (plinthe peinte à bandes) : une lisse ajourée enfermerait des jours de sol
            g.box((x, y - 0.295, 0.11), (0.58, 0.02, 0.12), M["galva"], "hard", what="garde_corps")
            g.hazard([V((x - 0.28, y - 0.307, 0.06)), V((x + 0.28, y - 0.307, 0.06)), V((x + 0.28, y - 0.307, 0.15)),
                      V((x - 0.28, y - 0.307, 0.15))], 6, t=0.006)
            P2.handwheel(g, (x - sx * 0.33, y + 0.05, 0.27), (-sx, 0, 0), 0.07, M)
            P4.lamp_group(g, (x - 0.08, y + 0.05, 0.47), (1, 0, 0), (0, 0, 1), E, n=2)
        _halo(g, [(-cx, Y(cy), 0.3), (cx, Y(cy), 0.3)], 8.0)
    elif e == 5:
        # 2 mortiers trapus blindés (tube court et gros, incliné, affût à écailles)
        for sx in (-1, 1):
            with at(g, sx * cx, cy, sx * -0.3):
                P4.mortar(g, (0, 0, 0), 0.0, 1.5 * s)
        _halo(g, [(-cx, Y(cy) + 0.1, 0.4), (cx, Y(cy) + 0.1, 0.4)], 10.0)
    elif e == 6:
        # 2 piles de condensateurs à éclateur coiffées d'un tore de Tesla, arc entre les pointes
        for sx in (-1, 1):
            x, y = sx * cx, Y(cy)
            zt = P4.spark_stack(g, (x, y, 0.0), E, 1.5)
            g.box((x - sx * 0.1, y, zt + 0.02), (0.12, 0.016, 0.016), E, "flat", what="arc")
        _halo(g, [(-cx, Y(cy), 0.5), (cx, Y(cy), 0.5)], 10.0)
    elif e == 7:
        for sx in (-1, 1):
            with at(g, sx * cx, cy, sx * -0.25):
                P4.focaliser(g, (0, 0, 0), 0.0, 1.5 * s)
        _halo(g, [(-cx, Y(cy), 0.5), (cx, Y(cy), 0.5)], 12.0)
    elif e == 8:
        for sx in (-1, 1):
            P4.demijohn(g, (sx * cx, Y(cy), 0.0), M["emit_soft"], 1.5 * s)
        _halo(g, [(-cx, Y(cy), 0.4), (cx, Y(cy), 0.4)], 12.0)
    else:
        for sx in (-1, 1):
            with at(g, sx * cx, cy, sx * -0.25):
                P4.lead_chest(g, (0, 0, 0), 0.0, E, 1.45 * s)
        _halo(g, [(-cx, Y(cy), 0.4), (cx, Y(cy), 0.4)], 12.0)


def _piece1(g):
    """Niveau 2 (époque 1, Pionnier) : arc de sacs de sable sur les coins avant et les flancs du vanilla (dépasse de
    0,10 sur les côtés et de 0,15 sous l'emprise), caisse en bois cerclée de fer ouverte au coin avant gauche, bandes
    de cartouches qui pendent, lanterne de nuit."""
    M = g.M
    # plancher de planches cloutées sous l'emprise : cette couche est dessinée SOUS la mitrailleuse vanilla (le
    # vanilla la recouvre), elle ferme les jours entre le pied vanilla et le muret (trous enfermés : 61 px hr sinon)
    P4.deck_e(g, 2, -1.04, 1.04, Y(-1.08), Y(0.62), 0.05)
    for sx in (-1, 1):
        pts = [(sx * 1.08, Y(0.25), 0.0), (sx * 1.08, Y(-0.45), 0.0), (sx * 1.0, Y(-0.88), 0.0),
               (sx * 0.72, Y(-1.13), 0.0), (sx * 0.4, Y(-1.15), 0.0)]
        P4.sandbag_wall(g, pts, rows=2)
    with at(g, -0.68, -0.86, 0.25):
        P4.wood_crate(g, (0, 0, 0.0), (0.3, 0.24, 0.17))
    P4.lantern(g, (0.78, Y(-0.95), 0.15), M["emit"])
    g.box((0.78, Y(-0.95), 0.07), (0.1, 0.1, 0.15), M["wood"], "hard", what="billot")
    _halo(g, [(0.78, Y(-0.95), 0.3)], 6.0)


# ------------------------------------------------------------------------------------------------
# Tête (repère de la tête : canons vers +Y)
# ------------------------------------------------------------------------------------------------
def skirt(g, R, z0, z1, mats, nstrips, band_mat):
    """Jupe blindée de la lignée : âme, bandes de blindage verticales rivetées, cerclages d'époque."""
    M = g.M
    g.cyl((0, 0, (z0 + z1) / 2), "z", R, z1 - z0, M["seam"], n=64, style="smooth", what="ame")
    h = z1 - z0
    w = TAU * R / nstrips
    for k in range(nstrips):
        a = TAU * (k + 0.5) / nstrips
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
        m = mats[g.rng.randrange(len(mats))]
        th = 0.034 * (1 + 0.3 * (g.rng.random() - 0.5))
        g.box(d * (R + th / 2 - 0.004) + V((0, 0, z0 + h * 0.5)), (w * 0.9, th, h * 0.76), m, "hard", R=R3,
              what="bande")
        for s in (-1, 1):
            g.dome(d * (R + th) + t * (s * w * 0.34) + V((0, 0, z0 + h * 0.78)), d, 0.018, M["rivet"])
    for zz in (z0 + 0.03, z1 - 0.03):
        g.tube_shell((0, 0, zz), "z", R + 0.05, R - 0.02, 0.06, band_mat, n=64, what="cerclage")


def slits(g, R, z, n, emat, a0=math.pi / 2 + 0.8, span=TAU - 1.6):
    for k in range(n):
        a = a0 + span * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
        g.box(d * (R + 0.045) + V((0, 0, z)), (0.1, 0.012, 0.03), emat, "flat", R=R3, what="fente")
        g.box(d * (R + 0.05) + V((0, 0, z + 0.032)), (0.13, 0.022, 0.02), g.M["steel_dk"], "hard", R=R3,
              what="visiere")


def gun_side(g, e, sx):
    """Canon de flanc de la lignée (bras de tourillon, culasse, entraînement, faisceau, masque de canon,
    alimentation), chaque organe dans le style de l'époque (parts4)."""
    M = g.M
    st = ST[e]
    H = HEAD[e]
    x = sx * H["gx"]
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    R = H["R"]
    xa, xb = sorted((sx * R * 0.8, x - sx * wr / 2))
    PT.hull(g, xa, xb, y0 + 0.1, y1 - 0.14, zg - hr * 0.7, zg + hr * 0.55, ins=(0.0, 0.02, 0.02), panel=0.22,
            mats=[M[k] for k in st["arm"]], faces="tsn", rivet_step=0.12)
    # berceau arrière (bas) du bras : ferme le jour entre l'entraînement, la nacelle et la coupole (contrôle des
    # trous enfermés ; lignée : 26 à 41 px de trou à cet endroit)
    xc, xd = sorted((sx * R * 0.45, x))
    PT.hull(g, xc, xd, y0 - 0.34, y0 + 0.14, H["zs"] - 0.2, zg - hr * 0.55, ins=(0.02, 0.03, 0.0), panel=0.22,
            mats=[M["steel_dk"], M[st["arm"][0]]], faces="tsn", rivet_step=0.12)
    # berceau avant (bas) : ferme le coin entre le bras, la jaquette et la coupole (trous enfermés de 10 à 27 px hr
    # dans la composition socle + tête, poses E et N)
    xe, xf = sorted((sx * R * 0.55, x))
    PT.hull(g, xe, xf, y1 - 0.2, y1 + 0.2, H["zs"] - 0.12, zg - hr * 0.35, ins=(0.02, 0.0, 0.04), panel=0.22,
            mats=[M["steel_dk"], M[st["arm"][0]]], faces="tsn", rivet_step=0.12)
    g.cyl(((xa + xb) / 2, (y0 + y1) / 2 - 0.04, zg - hr * 0.1), "x", hr * 0.62, abs(xb - xa) + 0.12, M["steel_dk"],
          n=20, what="tourillon")
    g.cyl((x + sx * (wr / 2 + 0.03), (y0 + y1) / 2 - 0.04, zg - hr * 0.1), "x", hr * 0.5, 0.06, M[st["cap"]], n=16,
          style="hard", what="chapeau")
    P4.bolts_ring(g, (x + sx * (wr / 2 + 0.062), (y0 + y1) / 2 - 0.04, zg - hr * 0.1), (sx, 0, 0), hr * 0.36, 6,
                  M["rivet"], r=0.015)
    P4.breech(g, st, x, y0, y1, zg - hr, zg + hr, wr)
    Ld = 0.26 + hr * 0.6
    P4.drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.78, Ld)
    P4.gun_e(g, st, H, x, sx)
    # masque de canon (lignée), matière d'époque
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M[k] for k in st["gmask"]], rivet_step=0.11)
    xo = x + sx * (wr / 2 - 0.005)   # l'alimentation touche la culasse : aucun jour entre les deux
    P4.feed(g, st, H, x, sx, xo)
    if e >= 3:
        PT.lamp(g, (x - sx * wr * 0.25, y0 + 0.1, zg + hr + 0.03), (0, 0.4, 1), 0.026, M["emit"], cage=(e != 7))


# voyants isolés de la tête (un foyer chacun, jamais en rangée) : la puissance monte d'une époque à la suivante
# (catalogue §A.5 : « +20 % de foyers, jamais plus gros » ; dominance de progression.py : foyers non décroissants)
HEAD_LAMPS = {2: 0, 3: 4, 4: 6, 5: 4, 6: 12, 7: 6, 8: 10, 9: 12}


def head_lamps(g, e):
    M = g.M
    H = HEAD[e]
    n = HEAD_LAMPS[e]
    if not n:
        return
    y0, y1 = H["recv"]
    zg, hr, wr, R = H["zg"], H["hr"], H["wr"], H["R"]
    cands = []
    for sx in (1, -1):
        x = sx * H["gx"]
        xa, xb = sorted((sx * R * 0.8, x - sx * wr / 2))
        cands += [((x + sx * wr * 0.22, y0 + (y1 - y0) * 0.72, zg + hr + 0.035), (0, 0, 1)),
                  (((xa + xb) / 2, y0 + 0.2, zg + hr * 0.55 + 0.01), (0, 0, 1)),
                  ((x - sx * wr * 0.3, y1 + 0.02, zg + hr * 1.35 + 0.01), (0, 0.3, 1)),
                  ((x + sx * wr * 0.2, y0 + (y1 - y0) * 0.3, zg + hr + 0.035), (0, 0, 1)),
                  ((x, y0 - 0.06, zg + hr * 0.8), (0, -0.5, 1)),
                  (((xa + xb) / 2 + sx * 0.06, y1 - 0.2, zg + hr * 0.55 + 0.01), (0, 0, 1)),
                  ((sx * R * 0.5, -R - 0.2, H["zs"] + H["rz"] * 0.42 + 0.005), (0, 0, 1)),
                  ((x - sx * wr * 0.32, y0 + (y1 - y0) * 0.5, zg + hr + 0.035), (0, 0, 1)),
                  ((sx * R * 0.55, -R * 0.85, H["zs"] + H["rz"] * 0.42 + 0.005), (0, 0, 1))]
    # ordre : on alterne les côtés pour rester symétrique
    h = len(cands) // 2
    order = [c for pair in zip(cands[:h], cands[h:]) for c in pair]
    for k, (p, nrm) in enumerate(order[:n]):
        shape = k // 2 % 3
        if shape == 1:
            P4.lamp_group(g, p, (1, 0, 0), nrm, M["emit"], n=1, sizes=(0.046,))
        else:
            PT.lamp(g, p, nrm, 0.03 if shape == 0 else 0.026, M["emit"], cage=False)


def head_core(g, e):
    """Collier, jupe, coupole rivetée, masque avant, nacelle arrière, tourelleau (lignée), habillés par l'époque."""
    M = g.M
    st = ST[e]
    H = HEAD[e]
    R, zs, rz = H["R"], H["zs"], H["rz"]
    z0 = ring_top(e)
    g.cyl((0, 0, z0 + 0.035), "z", R + 0.07, 0.07, M["steel_dk"], n=56, style="soft", what="collier")
    nb = int(TAU * (R + 0.04) / 0.16)
    for k in range(nb):
        a = TAU * k / nb
        g.dome(((R + 0.04) * math.cos(a), (R + 0.04) * math.sin(a), z0 + 0.07), (0, 0, 1), 0.016, M["rivet"])
    skirt(g, R, z0 + 0.07, zs, [M["olive"], M["olive"], M["steel_dk"]], max(12, int(TAU * R / 0.26)), M[st["skirt"]])
    Pf, Nf = P2.dome_hull(g, (0, 0, zs), R, R * 1.06, rz, M["olive"], M, seams=max(10, int(TAU * R / 0.3)),
                          band_mat=M["steel_dk"], ring_seams=(0.62,) if SIDE[e] <= 3 else (0.5, 0.95))
    mw = R * 0.5
    mask = st.get("mask")
    if mask == "shield":
        # bouclier frontal riveté de la forge, bord haut CRÉNELÉ qui dépasse au-dessus de la tête. Reprise : il est
        # INCLINÉ vers l'arrière (30° sur la verticale) pour que sa face rivetée se voie d'en haut à toutes les
        # poses (droit, on n'en voyait que la tranche), et ses merlons sont dans son plan.
        # Il se dresse DEVANT la coupole, sur une console rivetée qui part de la jupe (aucune pièce qui flotte).
        sw = H["gx"] - H["wr"] * 0.72 - 0.02
        hS = rz + 0.2
        yS = R + 0.16
        tilt = 0.6
        PT.hull(g, -sw, sw, R * 0.85, yS + 0.06, zs - 0.24, zs - 0.12, ins=(0.0, 0.0, 0.0), panel=0.2,
                mats=[M["blackiron"], M["rawiron"]], faces="tsew", rivet_step=0.1)
        g.push((0.0, yS, zs - 0.14), rx=tilt)
        PT.hull(g, -sw, sw, -0.025, 0.025, 0.0, hS, ins=(0.0, 0.0, 0.0), panel=0.2,
                mats=[M["bolted"], M["rawiron"]], faces="tsnew", rivet_step=0.1)
        n = 7
        for i in range(n):
            if i % 2 == 0:
                xx = -sw + (2 * sw) * (i + 0.5) / n
                g.box((xx, 0.0, hS + 0.05), (2 * sw / n, 0.05, 0.1), M["bolted"], "hard", what="merlon")
                g.dome((xx, 0.027, hS + 0.05), (0, 1, 0), 0.014, M["rivet"])
        g.box((0, 0.028, hS - 0.02), (sw * 2 + 0.02, 0.016, 0.034), M["rawiron"], "hard", what="rebord")
        for yy in (0.25, 0.6):
            g.box((0, 0.03, hS * yy), (sw * 2 + 0.03, 0.014, 0.036), M["blackiron"], "hard", what="cerclage")
            for k in range(7):
                g.dome((-sw + 2 * sw * (k + 0.5) / 7, 0.038, hS * yy), (0, 1, 0), 0.014, M["brass"])
        for s in (-1, 1):
            g.box((s * sw * 0.45, 0.03, hS * 0.78), (0.08, 0.008, 0.03), M["void"], "flat", what="visee")
        g.pop()
        for s in (-1, 1):
            g.box((s * sw * 0.7, yS - 0.14, zs + 0.0), (0.03, 0.3, 0.03), M["blackiron"], "hard",
                  R=Matrix.Rotation(0.75, 3, "X"), what="etai")
    elif mask == "glacis":
        T = PT.hull(g, -mw, mw, R * 0.55, R + 0.24, zs - 0.18, zs + rz * 0.55, ins=(0.04, 0.02, R * 0.32), panel=0.22,
                    mats=[M["tungsten"], M["burnrust"]], rivet_step=0.11)
        for i in range(3):
            for j in range(3):
                yy = R * 0.62 + (R * 0.5) * (i / 2.0)
                zz = zs + rz * 0.5 - (rz * 0.5 + 0.12) * (i / 2.0) + 0.03
                g.box(((j - 1) * mw * 0.62, yy, zz), (mw * 0.66, 0.14, 0.018), M["tungsten"], "hard",
                      R=Matrix.Rotation(-0.55, 3, "X"), what="ecaille")
                g.dome(((j - 1) * mw * 0.62, yy + 0.04, zz + 0.022), (0, 0.4, 1), 0.017, M["rivet"])
        g.box((0, R + 0.25, zs - 0.06), (mw * 1.1, 0.012, 0.03), M["emit"], "flat", what="fente")
    else:
        PT.hull(g, -mw, mw, R * 0.55, R + 0.22, zs - 0.18, zs + rz * 0.5, ins=(0.04, 0.02, R * 0.26), panel=0.22,
                mats=[M[k] for k in st["gmask"]], rivet_step=0.11)
        g.box((0, R + 0.235, zs + 0.02), (mw * 1.1, 0.02, 0.04), M["emit"], "flat", what="fente")
        g.box((0, R + 0.25, zs + 0.065), (mw * 1.3, 0.03, 0.025), M["steel_dk"], "hard", what="visiere")
    if st.get("coax"):
        g.cyl((mw * 0.45, R + 0.2 + 0.18, zs - 0.06), "y", 0.03, 0.4, M["gun"], n=10, what="coax")
        g.cyl((mw * 0.45, R + 0.2 + 0.3, zs - 0.06), "y", 0.046, 0.12, M[st["band"]], n=12, what="coax_manchon")
        P4.lit_ring(g, (mw * 0.45, R + 0.2 + 0.365, zs - 0.06), "y", 0.04, M["emit"], w=0.01)
    # nacelle arrière : radiateur, échappements (remplacés par l'organe dorsal de l'époque)
    bx = R * 0.62
    yb0, yb1 = -R - 0.26, -R * 0.5
    T = PT.hull(g, -bx, bx, yb0, yb1, zs - 0.2, zs + rz * 0.42, ins=(0.03, 0.04, 0.0), panel=0.24,
                mats=[M[k] for k in st["nac"]], rivet_step=0.11)
    back = [V((-bx, yb0, zs - 0.2)), V((bx, yb0, zs - 0.2)), T[1], T[0]]
    g.grille(PT.lift(PT.face_quad(back, 0.15, 0.85, 0.2, 0.8), 0.01), 4,
             slat_mat=M[{3: "copper_pol", 7: "bronze", 9: "lead"}.get(e, "steel")])
    ztop = zs + rz * 0.42
    yc = (yb0 + yb1) / 2
    if e == 3:
        # chaudière dorsale compacte et UNE cheminée ronde courte à collerette, à l'arrière gauche
        g.cyl((0.05, yc, ztop + 0.08), "x", 0.09, bx * 1.3, M["rawiron"], n=22, what="chaudiere")
        for f in (-0.4, 0.0, 0.4):
            g.tube_shell((0.05 + f * bx * 0.65, yc, ztop + 0.08), "x", 0.102, 0.08, 0.025, M["brass"], n=22,
                         what="cerclage")
        c = V((0.05 + bx * 0.65 + 0.004, yc, ztop + 0.08))
        g.cyl(c, "x", 0.05, 0.016, M["brass"], n=14, what="hublot_cadre")
        g.cyl(c + V((0.008, 0, 0)), "x", 0.034, 0.006, M["emit"], n=14, style="flat", what="hublot")
        P4.chimney(g, (-bx * 0.62, yb0 + 0.08, ztop), 0.056, 0.24)
        P2.gauge(g, (bx * 0.5, yb1 - 0.02, ztop + 0.04), (0, 0.5, 1), 0.035, M)
    elif e == 4:
        for sx in (-1, 1):
            PT.exhaust(g, (sx * bx * 0.7, yc - 0.05, ztop), 0.045, 0.2)
        P4.flare(g, (0.0, yb0 + 0.1, ztop), 0.24, M["emit"])
    elif e == 7:
        PT.exhaust(g, (bx * 0.7, yc - 0.05, ztop), 0.05, 0.22)
        P4.crystals(g, (-bx * 0.55, yc, ztop), 1.15)
    elif e == 8:
        # bulbe de verre dorsal (réservoir rond lumineux), cerclé, relié aux canons par des tuyaux souples
        rB = 0.17
        P4.sphere(g, (0.0, yc, ztop + rB * 0.9), rB, M["emit_soft"], n=24, m=12)
        g.torus((0.0, yc, ztop + rB * 0.9), "z", rB + 0.005, 0.016, M["brass"], n=28, m=6, what="cerclage")
        for k in range(6):
            a = TAU * k / 6
            g.box((math.cos(a) * (rB + 0.012), yc + math.sin(a) * (rB + 0.012), ztop + rB * 0.9), (0.02, 0.02, rB * 1.9),
                  M["verdigris"], "hard", what="cage")
        g.cyl((0.0, yc, ztop + 0.03), "z", rB * 0.85, 0.06, M["verdigris"], n=20, what="embase")
        g.cyl((0.0, yc, ztop + rB * 1.9 + 0.02), "z", 0.04, 0.05, M["brass"], n=12, what="col")
        for sx in (-1, 1):
            g.hose([(sx * rB * 0.7, yc + 0.05, ztop + 0.12), (sx * H["gx"] * 0.6, -0.2, H["zg"] + H["hr"] + 0.12),
                    (sx * H["gx"], H["recv"][0] + 0.2, H["zg"] + H["hr"] + 0.04)], 0.032, M["rubber"], step=0.03)
    elif e == 9:
        P4.tower(g, (bx * 0.35, yc, ztop), 0.165, 0.22)
        PT.exhaust(g, (-bx * 0.7, yc - 0.05, ztop), 0.05, 0.2)
    else:
        he = 0.18 + 0.03 * (SIDE[e] - 2)
        re = 0.045 + 0.005 * (SIDE[e] - 2)
        if e == 6:
            # tour de Tesla dorsale : pile d'isolateurs crème, tore de cuivre, deux piles latérales, arcs cyan
            zt6 = PT.insulators(g, (0.0, yc, ztop), 5, 0.05, h=0.036)
            g.torus((0.0, yc, zt6 + 0.03), "z", 0.1, 0.03, M["copper"], n=28, m=8, what="tore")
            g.cyl((0.0, yc, zt6 + 0.03), "z", 0.06, 0.05, M["copper"], n=14, what="borne")
            for sx in (-1, 1):
                zs6 = PT.insulators(g, (sx * bx * 0.62, yc - 0.02, ztop), 3, 0.036, h=0.032)
                g.cyl((sx * bx * 0.62, yc - 0.02, zs6 + 0.01), "z", 0.03, 0.03, M["copper"], n=10, what="borne")
                p0 = V((sx * bx * 0.62, yc - 0.02, zs6 + 0.03))
                p1 = V((sx * 0.1, yc, zt6 + 0.03))
                g.cyl((p0 + p1) / 2, p1 - p0, 0.009, (p1 - p0).length, M["emit"], n=6, style="flat", what="arc")
        else:
            for sx in (-1, 1):
                PT.exhaust(g, (sx * bx * 0.7, yc - 0.05, ztop), re, he)
        if e == 5:
            for sx in (-1, 1):
                g.cyl((sx * bx * 0.7, yc - 0.05, ztop + he + 0.012), "z", re - 0.027, 0.008, M["emit"], n=14,
                      style="flat", what="braise")
    # tourelleau à périscopes et trappe
    cx, cy = -R * 0.32, -R * 0.12
    zc = zs + rz * math.sqrt(max(0.0, 1 - (cx / R) ** 2 - (cy / (R * 1.06)) ** 2)) - 0.03
    hc = 0.12 + 0.02 * (SIDE[e] - 2)
    rc = 0.14 + 0.03 * (SIDE[e] - 2)
    g.cyl((cx, cy, zc + hc / 2), "z", rc, hc, M["ochre"] if e not in (5, 9) else M[st["appl"]], n=24, style="soft",
          what="tourelleau")
    g.torus((cx, cy, zc + hc), "z", rc - 0.02, 0.016, M["steel_dk"], n=24, m=6, what="jonc")
    nper = 2 + (SIDE[e] >= 3) + (SIDE[e] >= 4)
    for k in range(nper):
        a = math.pi / 2 + (k - (nper - 1) / 2) * 0.6
        d = V((math.cos(a), math.sin(a), 0))
        Rr = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
        g.box(V((cx, cy, zc + hc * 0.6)) + d * rc, (0.06, 0.045, 0.055), M["steel_dk"], "hard", R=Rr, what="periscope")
        g.box(V((cx, cy, zc + hc * 0.6)) + d * (rc + 0.025), (0.045, 0.008, 0.026), M["emit"], "flat", R=Rr,
              what="lentille")
    hx, hy = R * 0.34, -R * 0.2
    zh = zs + rz * math.sqrt(max(0.0, 1 - (hx / R) ** 2 - (hy / (R * 1.06)) ** 2)) - 0.02
    PT.hatch(g, (hx, hy, zh), 0.1 + 0.02 * (SIDE[e] - 2))
    return Pf, Nf


def tete(g, e):
    M = g.M
    st = ST[e]
    H = HEAD[e]
    R = H["R"]
    k = KIN[e]
    Pf, Nf = head_core(g, e)
    nsl = {2: 0, 3: 4, 4: 5, 5: 6, 6: 7, 7: 9, 8: 11, 9: 13}[e]
    if nsl:
        slits(g, R, ring_top(e) + 0.1 + 0.02 * SIDE[e], nsl, M["emit"], a0=math.pi * 0.62, span=math.pi * 1.76)
    for sx in (-1, 1):
        gun_side(g, e, sx)
    head_lamps(g, e)
    # liaisons de la tête (nacelle -> canons) dans le style de l'époque
    # reprise : elles passent EN ARC au-dessus de la tête (avant : à hauteur de la jupe, cachées par la coupole)
    if e != 8:
        zt = H["zs"] + H["rz"] * 0.42
        for sx in (-1, 1):
            P4.arch_hose(g, e, (sx * 0.15, -R - 0.06, zt + 0.02),
                         (sx * (H["gx"] - 0.03), H["recv"][0] + 0.1, H["zg"] + H["hr"] + 0.03),
                         0.1 + 0.03 * (SIDE[e] - 2), 0.034 + 0.008 * (SIDE[e] - 2))
    # viseur (ère II : 1 lentille ; ère III : 2)
    if SIDE[e] >= 3:
        PT.sight(g, (R * 0.2, R * 0.45, H["zs"] + H["rz"] * 0.6), 0.16 + 0.04 * (SIDE[e] - 3), 0.18, 0.1, M["emit"],
                 lenses=SIDE[e] - 2)
    if e == 3:
        P2.gauge(g, (R * 0.3, R * 0.5, H["zs"] + H["rz"] * 0.55), (0, 0.6, 1), 0.04, M)
    # plaques rapportées de la coupole (blindage : base, 1re rangée complète, 2e rangée ; catalogue §A.5)
    appl = M[st["appl"]]
    n1 = {0: 3, 1: 6, 2: 8}[k] + (SIDE[e] - 2)
    for i in range(n1):
        th = 0.45 + (math.pi - 0.9) * (i + 0.5) / n1
        if e == 5:
            for j in range(2):
                P2.applique(g, Pf, Nf, th + 0.12 * j, 0.25 + 0.15 * j, 0.24, 0.16, M["tungsten"], M, bolts=0)
        else:
            P2.applique(g, Pf, Nf, th, 0.3, 0.22 + 0.03 * (SIDE[e] - 2), 0.18 + 0.03 * (SIDE[e] - 2), appl, M)
    if k >= 1 or SIDE[e] >= 4:
        n2 = 2 + 2 * k
        for i in range(n2):
            th = 0.7 + (math.pi - 1.4) * (i + 0.5) / n2
            P2.applique(g, Pf, Nf, th, 0.72, 0.2, 0.16, appl if e != 9 else M["lead"], M)
    if e == 9:
        P4.trefoil(g, Pf(math.pi / 2, 0.55, 1.03), Nf(math.pi / 2, 0.55), 0.06)
        # hublots verts ronds (réacteur vanilla) sur les flancs de la nacelle, bandes jaunes et noires
        bx = R * 0.62
        yc = (-R - 0.26 - R * 0.5) / 2
        for sx in (-1, 1):
            c = V((sx * (bx + 0.004), yc, H["zs"] + 0.02))
            g.cyl(c, (sx, 0, 0), 0.06, 0.02, M["steel_hi"], n=18, what="cadre")
            g.cyl(c + V((sx * 0.012, 0, 0)), (sx, 0, 0), 0.042, 0.006, M["emit"], n=18, style="flat", what="hublot")
            P4.bolts_ring(g, c + V((sx * 0.012, 0, 0)), (sx, 0, 0), 0.051, 6, M["rivet"], r=0.012)
        g.hazard([V((-R * 0.5, R + 0.24, H["zs"] - 0.14)), V((R * 0.5, R + 0.24, H["zs"] - 0.14)),
                  V((R * 0.5, R + 0.24, H["zs"] - 0.08)), V((-R * 0.5, R + 0.24, H["zs"] - 0.08))], 8, t=0.008)
