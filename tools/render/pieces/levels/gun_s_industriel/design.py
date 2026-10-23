"""Mitrailleuse « industriel lourd » : socles et têtes des niveaux témoins (lot V3-S). S'exécute DANS Blender.

REPRISE du 22/10 (2e explorateur), après la critique des essais de 8 h 50 :
  1. les essais se lisaient comme des DALLES carrées vues de dessus (socle plat plein, coins coupés) ;
  2. la tête ne dominait pas ; 3. gris uniforme ; 4. relief plat ; 5. densité de détail en baisse avec la taille.
Refonte de la forme (kit, rendus et mesures du prédécesseur gardés) :
  socle = une COLONNE à goussets (couronne d'orientation à bandes de danger, comme l'artillerie vanilla)
          entourée de MACHINES distinctes, de hauteurs et de formes différentes, dont plusieurs posées EN
          DIAGONALE aux angles, pour que le contour ne soit jamais un carré : trémie à trappe ouverte et caisses
          OUVERTES pleines de cartouches au sud, groupe électrogène à culasses rouges, volant et silencieux à
          l'ouest, réservoirs DEBOUT crème cerclés de laiton à l'est (volumes ronds, comme le réacteur),
          radiateurs à ventilateurs vus de dessus au nord, tourelles secondaires aux angles, condensateurs ;
          gaines annelées, tuyaux de cuivre à brides, vannes à volant, manomètres, conduits d'énergie à bagues
          lumineuses, armoires à voyants, échelles, patins d'ancrage ; caillebotis entre les machines ;
  tête  = SURÉLEVÉE et LARGE (diamètre ≈ 0,45 × le côté) : jupe blindée, coupole rivetée à nervures (volume
          rond), masque avant, deux canons rotatifs LOURDS en flancs (bras de tourillon, culasse, moteur arrière
          bobiné, jaquette perforée, frein de bouche), alimentation (tambours puis caisses et goulottes
          articulées), nacelle arrière (radiateur, échappements), tourelleau à périscopes ; elle grandit avec
          l'ère : tubes plus nombreux et plus longs, télémètre, plaques rapportées, canon de coupole.

Échelle d'emprise (charte §6.2) : niveau 11 (époque 6, ère II) 3×3 ; niveau 21 (époque 11, ère IV) 5×5 ;
niveau 29 (époque 15, ère V) 6×6 ; niveau 30 = niveau 29 + deux cellules d'énergie sur la bande avant (F46).
Conventions : 1 unité = une tuile en X ; une tuile de jeu vers le nord = 1,414 unité en Y (Y()) ; +Z haut.
"""
import math

from mathutils import Matrix, Vector

import parts as PT
import parts2 as P2
import parts3 as P3
from kit import SQ2, TAU

V = Vector
SIDE = {6: 3, 11: 5, 15: 6}


def Y(yn):
    """y de jeu en tuiles, vers le NORD -> Y Blender."""
    return yn * SQ2


SYSTEMS = {
    6: ["tête à canons (2 × 4 tubes)", "alimentation (tambours, trémie à trappe, caisse ouverte, goulotte)",
        "socle pivotant (colonne à goussets, couronne dentée)", "blindage frontal (masque, jupe)",
        "refroidissement (réservoir debout, jaquettes perforées, radiateur à ventilateurs)", "canons jumelés"],
    11: ["tête à canons (2 × 6 tubes)", "alimentation (caisses, goulottes articulées, trémie, caisses ouvertes)",
         "socle pivotant", "blindage frontal et latéral (masque, plaques rapportées)",
         "refroidissement (2 réservoirs, jaquettes, radiateurs à ventilateurs)", "canons jumelés",
         "chargeur automatique (goulotte de la trémie à la couronne)", "conduits et câblage",
         "viseur et télémètre", "générateur (groupe à 5 cylindres)", "tourelle secondaire",
         "radiateurs", "armoire de commande à voyants"],
    15: ["tête à canons (2 × 6 tubes lourds)", "alimentation", "socle pivotant",
         "blindage frontal", "refroidissement (2 réservoirs, radiateur à 3 ventilateurs)",
         "canons jumelés + canon de coupole", "chargeur automatique", "conduits et câblage", "viseur et télémètre",
         "générateur (6 cylindres)", "tourelles secondaires (3)", "radiateurs",
         "réserve d'énergie visible (banc de condensateurs, conduits lumineux, nacelle)",
         "blindage à plaques multiples (plaques rapportées sur la coupole)"],
}
# socle : rayon et hauteur de la colonne, hauteur de la couronne
BASE = {6: dict(R=0.8, h=0.6, rh=0.08), 11: dict(R=1.3, h=0.98, rh=0.12), 15: dict(R=1.6, h=1.16, rh=0.14)}
RING_TOP = {e: BASE[e]["h"] + BASE[e]["rh"] for e in BASE}
# tête : rayon de jupe, haut de jupe, hauteur de coupole, demi-écart des canons, hauteur des canons, longueur
# des tubes, nombre de tubes, rayon d'un tube, rayon du faisceau, culasse (y0, y1), largeur et demi-hauteur
HEAD = {
    6: dict(R=0.68, zs=1.0, rz=0.42, gx=0.94, zg=1.15, L=1.35, nb=4, rb=0.045, rr=0.1, recv=(-0.36, 0.5),
            wr=0.28, hr=0.16),
    11: dict(R=1.12, zs=1.55, rz=0.62, gx=1.5, zg=1.74, L=2.1, nb=6, rb=0.06, rr=0.145, recv=(-0.6, 0.8),
             wr=0.44, hr=0.25),
    15: dict(R=1.38, zs=1.8, rz=0.74, gx=1.84, zg=2.0, L=2.5, nb=6, rb=0.072, rr=0.175, recv=(-0.74, 0.95),
             wr=0.52, hr=0.3),
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
# Socle
# ------------------------------------------------------------------------------------------------
def column(g, e, ladder_ang):
    M = g.M
    B = BASE[e]
    P2.pedestal(g, B["R"], 0.0, B["h"], 12 if e == 6 else 16, M,
                [M["olive"], M["steel_dk"], M["olive"], M["redpaint"]], ladder_at=ladder_ang)
    PT.slewing_ring(g, B["R"] - 0.02, B["h"], B["rh"])
    if e >= 11:
        n = 18 if e == 11 else 26
        slits(g, B["R"] + 0.02, B["h"] * 0.62, n, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
        slits(g, B["R"] + 0.02, B["h"] * 0.38, n, M["emit"], a0=math.pi + 0.2 + 0.08, span=math.pi - 0.4)


def socle(g, e, piece=False):
    {6: _socle6, 11: _socle11, 15: _socle15}[e](g, piece)


def _socle6(g, piece):
    M = g.M
    E = M["emit"]
    column(g, 6, -math.pi * 0.72)
    P2.grating(g, 0.85, 1.2, Y(-0.75), Y(-0.25), 0.07, M)
    P2.grating(g, -0.92, -0.62, Y(-1.0), Y(-0.6), 0.07, M)
    # sud : trémie à trappe ouverte, goulotte vers la couronne
    out = P3.hopper_top(g, -0.38, 0.38, Y(-1.42), -1.0, 0.0, 0.46, M, stencils=False)
    P2.feed_chute(g, [tuple(out), (0.0, -0.9, 0.62), (0.0, -0.66, 0.66)], 0.13, M)
    with at(g, -1.0, -1.05, 0.38):
        P2.open_crate(g, (0, 0, 0), 0.5, 0.56, 0.24, M)
    with at(g, 1.02, -1.08, -0.32):
        PT.crate(g, (0, 0, 0), (0.46, 0.46, 0.28), mat=M["olive"])
        PT.lamp(g, (0.0, -0.1, 0.33), (0, -0.5, 1), 0.03, M["amber"])
    # est : réservoir debout, piquage vers la colonne, gaine
    P3.vtank(g, 1.12, Y(0.3), 0.3, 0.62, M, emat=E, ladder_dir=(1, 0.3), stub_dir=(-1, 0))
    g.hose([(0.95, Y(0.55), 0.55), (0.82, Y(0.5), 0.72), (0.66, Y(0.35), 0.5)], 0.045, M["rubber"])
    # ouest : batterie à isolateurs (accent céramique d'époque 6), arcs cyan, câbles
    PT.hull(g, -1.45, -0.98, Y(-0.5), Y(0.62), 0.0, 0.34, ins=(0.02, 0.02, 0.02), panel=0.26,
            mats=[M["olive"], M["steel_dk"]], rivet_step=0.13)
    for dy in (-0.42, 0.0, 0.42):
        PT.insulators(g, (-1.21, Y(0.06) + dy, 0.34), 4, 0.045)
    for dy in (-0.21, 0.21):
        g.box((-1.21, Y(0.06) + dy, 0.34 + 4 * 0.034 + 0.02), (0.024, 0.34, 0.024), E, "flat", what="arc")
    PT.cable_run(g, [(-1.0, Y(0.45), 0.3), (-0.9, Y(0.45), 0.42), (-0.74, Y(0.3), 0.5)], 2, 0.02, 0.045,
                 [M["rubber"], M["redcable"]])
    # nord : radiateur à ventilateurs
    P2.fan_radiator(g, -0.6, 0.6, Y(1.0), Y(1.42), 0.0, 0.28, 2, M)
    # nord-est : armoire à voyants ; nord-ouest : caisses empilées en biais
    P3.cabinet(g, 0.7, 1.38, Y(0.98), Y(1.38), 0.0, 0.4, M, E, rows=1)
    with at(g, -1.08, 1.12, 0.3):
        PT.crate(g, (0, 0, 0), (0.5, 0.42, 0.24), mat=M["olive"])
    P3.lamp_row(g, (-0.3, Y(-1.42) - 0.03, 0.36), (0.3, Y(-1.42) - 0.03, 0.36), 3, (0, -1, 0), E, M, size=0.028)
    _halo(g, [(-1.2, Y(0.06), 0.6), (1.02, Y(-1.2), 0.45), (1.12, Y(0.0), 0.4)], 16.0)


def _socle11(g, piece):
    M = g.M
    E = M["emit"]
    column(g, 11, -math.pi * 0.7)
    P2.grating(g, 1.35, 1.75, Y(-1.15), Y(1.3), 0.07, M)
    P2.grating(g, -1.55, -1.3, Y(-1.0), Y(-0.3), 0.07, M)
    # sud : trémie, goulotte, caisses ouvertes en biais, tourelle secondaire
    out = P3.hopper_top(g, -0.46, 0.46, Y(-2.4), -1.62, 0.0, 0.66, M)
    P2.feed_chute(g, [tuple(out), (0.0, -1.42, 0.92), (0.0, -1.1, 1.08)], 0.18, M)
    with at(g, -1.5, -1.72, 0.42):
        P2.open_crate(g, (0, 0, 0), 0.78, 0.72, 0.3, M)
    with at(g, -1.05, -2.35, 0.08):
        P2.open_crate(g, (0, 0, 0), 0.6, 0.5, 0.22, M, paint=M["ochre"])
    with at(g, 1.78, -1.82, 0.0):
        P2.pedestal(g, 0.42, 0.0, 0.28, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
        PT.mini_turret(g, (0, 0, 0.28), 0.95, 0.3, E)
    # ouest : groupe électrogène à 5 cylindres, conduit d'énergie lumineux vers la colonne
    P2.engine(g, -2.42, -1.62, Y(-0.95), Y(1.25), 0.0, 0.52, 5, M, emat=E)
    P3.conduit(g, [(-1.62, Y(0.55), 0.4), (-1.42, Y(0.6), 0.62), (-1.2, Y(0.5), 0.72)], 0.045, M, E, step=0.12)
    PT.cable_run(g, [(-1.62, Y(-0.25), 0.4), (-1.42, Y(-0.3), 0.6), (-1.18, Y(-0.35), 0.68)], 3, 0.02, 0.045,
                 [M["rubber"], M["redcable"], M["rubber"]])
    # nord-ouest : radiateur à ventilateurs posé en biais
    with at(g, -1.72, 2.02, -0.55):
        P2.fan_radiator(g, -0.55, 0.55, -0.42, 0.42, 0.0, 0.38, 2, M, emat=E)
    # est : deux réservoirs debout, pompe à vannes, tuyaux, gaines
    P3.vtank(g, 2.02, Y(0.95), 0.38, 0.88, M, emat=E, ladder_dir=(1, 0.2), stub_dir=(-1, 0), glow_gauges=True,
             glow_rings=1)
    P3.vtank(g, 2.02, Y(-0.4), 0.38, 0.88, M, emat=E, ladder_dir=(1, -0.2), stub_dir=(-1, 0), glow_gauges=True,
             glow_rings=1)
    # sud-ouest : armoire de commande ; voyants sur la face sud de la trémie
    P3.cabinet(g, -2.45, -2.02, -2.3, -1.66, 0.0, 0.5, M, E)
    P3.lamp_row(g, (-0.4, Y(-2.4) - 0.03, 0.5), (0.4, Y(-2.4) - 0.03, 0.5), 5, (0, -1, 0), E, M, size=0.03)
    PT.hull(g, 1.68, 2.36, Y(-1.18), Y(-0.85), 0.0, 0.3, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["redpaint"], M["steel_dk"]], rivet_step=0.12)
    P2.handwheel(g, (2.02, Y(-1.18) - 0.08, 0.2), (0, -1, 0.3), 0.08, M)
    P2.pipe_valve(g, [(1.68, Y(-1.0), 0.2), (1.45, Y(-1.05), 0.22), (1.25, Y(-0.85), 0.4)], 0.05, M,
                  valve_at=((1.47, Y(-1.04), 0.22), (0, -1, 0.5)))
    g.hose([(1.7, Y(1.05), 0.62), (1.45, Y(0.95), 0.98), (1.15, Y(0.75), 0.82)], 0.06, M["rubber"])
    # nord-est : armoire de commande à voyants ; nord : caisses de réserve
    P3.cabinet(g, 1.25, 2.25, Y(1.95), Y(2.42), 0.0, 0.56, M, E)
    PT.crate(g, (-0.4, Y(1.95), 0.0), (0.66, 0.6, 0.28), mat=M["olive"])
    PT.crate(g, (0.4, Y(1.95), 0.0), (0.66, 0.6, 0.28), mat=M["ochre"])
    for x, yn in ((-2.3, -2.3), (2.32, 2.4), (-2.3, 2.42)):
        P2.anchor(g, x, Y(yn), 0.26, M)
    for x in (-0.68, 0.68):
        PT.lamp(g, (x, Y(-2.4) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    _halo(g, [(-2.0, Y(-1.1), 0.5), (1.78, Y(-2.1), 0.6), (0.0, Y(-2.5), 0.5), (2.0, Y(0.3), 0.5),
              (1.75, Y(1.8), 0.5)], 20.0)


def _socle15(g, piece):
    M = g.M
    E = M["emit"]
    column(g, 15, -math.pi * 0.68)
    P2.grating(g, 1.65, 1.95, Y(-1.3), Y(1.45), 0.07, M)
    P2.grating(g, -1.95, -1.65, Y(-1.1), Y(1.1), 0.07, M)
    # sud : trémie, goulotte, caisses ouvertes en biais
    out = P3.hopper_top(g, -0.54, 0.54, Y(-2.75), -1.95, 0.0, 0.78, M)
    P2.feed_chute(g, [tuple(out), (0.0, -1.75, 1.08), (0.0, -1.38, 1.28)], 0.2, M)
    with at(g, -1.45, -1.95, 0.45):
        P2.open_crate(g, (0, 0, 0), 0.84, 0.78, 0.32, M)
    with at(g, 1.45, -1.95, -0.45):
        P2.open_crate(g, (0, 0, 0), 0.84, 0.78, 0.32, M, paint=M["ochre"])
    # tourelles secondaires aux angles (ère V : plusieurs), sur fûts
    for (x, yn, rz) in ((-2.4, -2.5, -0.3), (2.4, -2.5, 0.3), (2.4, 2.45, 0.6)):
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.46, 0.0, 0.32, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            PT.mini_turret(g, (0, 0, 0.32), 1.02, rz, E)
    # ouest : groupe électrogène à 6 cylindres ; conduits lumineux
    P2.engine(g, -2.88, -1.98, Y(-1.35), Y(1.35), 0.0, 0.6, 6, M, emat=E)
    P3.conduit(g, [(-1.98, Y(0.7), 0.45), (-1.78, Y(0.75), 0.72), (-1.52, Y(0.62), 0.86)], 0.05, M, E, step=0.12)
    P3.conduit(g, [(-1.98, Y(-0.6), 0.45), (-1.78, Y(-0.65), 0.72), (-1.52, Y(-0.55), 0.86)], 0.05, M, E, step=0.12)
    PT.cable_run(g, [(-1.98, Y(0.05), 0.45), (-1.75, Y(0.02), 0.7), (-1.5, Y(0.0), 0.8)], 3, 0.02, 0.045,
                 [M["rubber"], M["redcable"], M["rubber"]])
    # nord-ouest : banc de condensateurs en biais (réserve d'énergie visible)
    with at(g, -2.05, 2.25, -0.6):
        PT.hull(g, -0.62, 0.62, -0.5, 0.5, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3, mats=[M["steel_dk"]],
                rivet_step=0.13)
        PT.capacitors(g, (0.0, 0.0, 0.14), 3, 2, 0.14, 0.48, E)
        P3.lamp_row(g, (-0.55, -0.52, 0.09), (0.55, -0.52, 0.09), 8, (0, -1, 0), E, M)
    P3.conduit(g, [(-1.6, Y(1.95), 0.5), (-1.35, Y(1.6), 0.8), (-1.1, Y(1.25), 0.95)], 0.05, M, E, step=0.12)
    # est : deux réservoirs debout, pompe, tuyaux, gaines
    P3.vtank(g, 2.4, Y(1.0), 0.44, 0.98, M, emat=E, ladder_dir=(1, 0.2), stub_dir=(-1, 0), gauges=3,
             glow_gauges=True, glow_rings=2)
    P3.vtank(g, 2.4, Y(-0.55), 0.44, 0.98, M, emat=E, ladder_dir=(1, -0.2), stub_dir=(-1, 0), gauges=3,
             glow_gauges=True, glow_rings=2)
    # armoires de commande : sud-ouest (devant le volant) et nord-est (entre réservoir et tourelle)
    P3.cabinet(g, -2.85, -2.08, -2.85, -2.2, 0.0, 0.55, M, E)
    P3.cabinet(g, 1.95, 2.85, 2.02, 2.5, 0.0, 0.5, M, E)
    P3.lamp_row(g, (-0.46, Y(-2.75) - 0.03, 0.6), (0.46, Y(-2.75) - 0.03, 0.6), 7, (0, -1, 0), E, M, size=0.03)
    P3.lamp_row(g, (-0.46, Y(-2.75) - 0.03, 0.5), (0.46, Y(-2.75) - 0.03, 0.5), 7, (0, -1, 0), E, M, size=0.03)
    PT.hull(g, 1.98, 2.85, Y(-1.55), Y(-1.18), 0.0, 0.34, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["redpaint"], M["steel_dk"]], rivet_step=0.12)
    for x in (2.15, 2.65):
        P2.handwheel(g, (x, Y(-1.55) - 0.08, 0.22), (0, -1, 0.3), 0.08, M)
    P2.pipe_valve(g, [(1.98, Y(-1.35), 0.24), (1.75, Y(-1.4), 0.26), (1.55, Y(-1.15), 0.48)], 0.055, M,
                  valve_at=((1.77, Y(-1.39), 0.26), (0, -1, 0.5)))
    g.hose([(2.0, Y(1.1), 0.7), (1.72, Y(1.0), 1.12), (1.4, Y(0.8), 0.95)], 0.065, M["rubber"])
    g.hose([(2.0, Y(-0.45), 0.7), (1.72, Y(-0.5), 1.1), (1.42, Y(-0.4), 0.95)], 0.065, M["rubber"])
    # nord : radiateur à trois ventilateurs ; armoires de commande
    P2.fan_radiator(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.0, 0.42, 3, M, emat=E)
    P3.cabinet(g, -1.15, -0.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    P3.cabinet(g, 0.35, 1.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    for x, yn in ((-2.75, -2.85), (-2.75, 0.0)):
        P2.anchor(g, x, Y(yn), 0.26, M)
    for x in (-0.8, 0.8):
        PT.lamp(g, (x, Y(-2.75) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    if piece:
        # niveau 30 : deux cellules d'énergie blindées sur la bande avant (toujours visible, F46), plinthe à
        # bandes de danger, conduits lumineux vers la trémie
        for sx in (-1, 1):
            x = sx * 1.22
            PT.hull(g, x - 0.34, x + 0.34, Y(-2.98), Y(-2.5), 0.0, 0.12, ins=(0.02, 0.02, 0.02), panel=0.3,
                    mats=[M["steel_dk"]], rivet_step=0.12)
            g.hazard([V((x - 0.34, Y(-2.98) - 0.02, 0.02)), V((x + 0.34, Y(-2.98) - 0.02, 0.02)),
                      V((x + 0.34, Y(-2.98) - 0.02, 0.11)), V((x - 0.34, Y(-2.98) - 0.02, 0.11))], 6, t=0.012,
                     skew=0.6)
            P2.power_cell(g, (x, Y(-2.74), 0.12), 0.24, 0.66, E, M)
            P3.conduit(g, [(x - sx * 0.2, Y(-2.6), 0.5), (x - sx * 0.45, Y(-2.45), 0.62),
                           (sx * 0.74, Y(-2.3), 0.5)], 0.045, M, E, step=0.12)
        _halo(g, [(-1.22, Y(-3.1), 0.4), (1.22, Y(-3.1), 0.4)], 18.0)
    _halo(g, [(-2.4, Y(-1.2), 0.6), (2.4, Y(-2.7), 0.7), (-2.4, Y(-2.7), 0.7), (0.0, Y(-2.85), 0.5),
              (-2.05, Y(2.25), 0.8), (2.4, Y(0.2), 0.6)], 22.0)


# ------------------------------------------------------------------------------------------------
# Tête (repère de la tête : canons vers +Y)
# ------------------------------------------------------------------------------------------------
def motor(g, c, r, L):
    """Moteur d'entraînement bobiné : carter à ailettes, bobinage de cuivre apparent, flasque boulonnée."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z), "y", r, L, M["steel_dk"], n=28, style="soft", what="moteur")
    nf = int((L * 0.5) / 0.04)
    for k in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + k * 0.04, z), "y", r + 0.03, r - 0.01, 0.016, M["steel_hi"], n=28,
                     what="ailette")
    for k in range(4):
        g.torus((x, y + L / 2 - 0.05 - k * 0.034, z), "y", r + 0.006, 0.017, M["copper"], n=28, m=6, what="bobinage")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M["olive"], n=24, style="soft", what="flasque")
    for k in range(8):
        a = TAU * k / 8
        d = V((math.cos(a), 0, math.sin(a)))
        g.dome(V((x, y - L / 2 - 0.06, z)) + d * r * 0.66, V((0, -1, 0)), 0.016, M["rivet"])
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M["brass"], n=12, what="moyeu")


def skirt(g, R, z0, z1, mats, nstrips, band_mat):
    """Jupe blindée : âme, bandes de blindage verticales rivetées, cerclages rivetés."""
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
        for zz in (z0 + h * 0.78,):
            for s in (-1, 1):
                g.dome(d * (R + th) + t * (s * w * 0.34) + V((0, 0, zz)), d, 0.018, M["rivet"])
    for zz in (z0 + 0.03, z1 - 0.03):
        g.tube_shell((0, 0, zz), "z", R + 0.05, R - 0.02, 0.06, band_mat, n=64, what="cerclage")


def slits(g, R, z, n, emat, a0=math.pi / 2 + 0.8, span=TAU - 1.6):
    for k in range(n):
        a = a0 + span * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
        g.box(d * (R + 0.045) + V((0, 0, z)), (0.11, 0.012, 0.035), emat, "flat", R=R3, what="fente")
        g.box(d * (R + 0.05) + V((0, 0, z + 0.035)), (0.14, 0.022, 0.02), g.M["steel_hi"], "hard", R=R3,
              what="visiere")


def gun_side(g, e, sx):
    """Canon rotatif lourd en flanc : bras de tourillon, culasse, moteur arrière, faisceau de tubes, jaquette,
    frein de bouche, masque de canon, alimentation et goulotte articulée."""
    M = g.M
    H = HEAD[e]
    x = sx * H["gx"]
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    R = H["R"]
    xa, xb = sorted((sx * R * 0.8, x - sx * wr / 2))
    PT.hull(g, xa, xb, y0 + 0.12, y1 - 0.18, zg - hr * 0.7, zg + hr * 0.55, ins=(0.0, 0.02, 0.02), panel=0.22,
            mats=[M["olive"], M["steel_dk"]], faces="tsn", rivet_step=0.12)
    g.cyl(((xa + xb) / 2, (y0 + y1) / 2 - 0.04, zg - hr * 0.1), "x", hr * 0.62, abs(xb - xa) + 0.12, M["steel_dk"],
          n=20, what="tourillon")
    g.cyl((x + sx * (wr / 2 + 0.03), (y0 + y1) / 2 - 0.04, zg - hr * 0.1), "x", hr * 0.5, 0.06, M["brass"], n=16,
          style="hard", what="chapeau")
    for k in range(6):
        a = TAU * k / 6
        g.dome(V((x + sx * (wr / 2 + 0.065), (y0 + y1) / 2 - 0.04 + math.cos(a) * hr * 0.36,
                  zg - hr * 0.1 + math.sin(a) * hr * 0.36)), (sx, 0, 0), 0.015, M["rivet"])
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M["ochre"], M["olive"]])
    motor(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6)
    coil = M["emit"] if e >= 11 else None
    PT.gatling(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"], H["L"] * 0.42, coil=coil, brake=(e >= 11))
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    if e == 6:
        PT.drum(g, (xo + sx * 0.1, y0 + 0.12, zg - 0.02), (1, 0, 0), 0.17, 0.15)
        PT.belt(g, [(xo + sx * 0.08, y0 + 0.22, zg + 0.16), (xo, y0 + 0.32, zg + 0.22),
                    (x + sx * wr * 0.3, y0 + 0.38, zg + hr + 0.02)])
    else:
        bw, bl, bh = 0.32 * wr / 0.4, 0.75 * H["L"] / 1.95, 0.5 * hr / 0.23
        bx0, bx1 = sorted((xo + sx * 0.02, xo + sx * (0.02 + bw)))
        PT.hull(g, bx0, bx1, y0 - 0.1, y0 - 0.1 + bl, zg - bh * 0.62, zg + bh * 0.42, ins=(0.015, 0.015, 0.015),
                panel=0.24, mats=[M["olive"], M["ochre"]], rivet_step=0.11)
        g.hazard(PT.lift([V((bx0, y0 - 0.1 + bl * 0.1, zg + bh * 0.42)), V((bx1, y0 - 0.1 + bl * 0.1, zg + bh * 0.42)),
                          V((bx1, y0 - 0.1 + bl * 0.22, zg + bh * 0.42)),
                          V((bx0, y0 - 0.1 + bl * 0.22, zg + bh * 0.42))], 0.012), 4, t=0.01)
        bc = (bx0 + bx1) / 2
        P2.feed_chute(g, [(bc, y0 - 0.1 + bl * 0.6, zg + bh * 0.42 + 0.02),
                          (bc - sx * 0.05, y0 + bl * 0.55, zg + bh * 0.62),
                          (x + sx * wr * 0.2, y0 + bl * 0.5, zg + hr + 0.06)], 0.12 * wr / 0.4 + 0.04, M)
        ztop = zg + bh * 0.42 + 0.015
        P3.lamp_row(g, (bc, y0 + bl * 0.1, ztop), (bc, y0 + bl * 0.42, ztop), 3 + (e >= 15), (0, 0, 1), M["emit"],
                    M, size=0.028)
        # bande lumineuse d'état sur le dessus de la culasse (ères IV-V)
        g.box((x - sx * wr * 0.22, (y0 + y1) / 2, zg + hr + 0.012), (0.03, (y1 - y0) * 0.55, 0.012), M["emit"],
              "flat", what="etat")


def head_core(g, e):
    """Collier, jupe, coupole rivetée, masque avant, nacelle arrière, tourelleau."""
    M = g.M
    H = HEAD[e]
    R, zs, rz = H["R"], H["zs"], H["rz"]
    z0 = RING_TOP[e]
    g.cyl((0, 0, z0 + 0.035), "z", R + 0.07, 0.07, M["steel_dk"], n=56, style="soft", what="collier")
    nb = int(TAU * (R + 0.04) / 0.16)
    for k in range(nb):
        a = TAU * k / nb
        g.dome(((R + 0.04) * math.cos(a), (R + 0.04) * math.sin(a), z0 + 0.07), (0, 0, 1), 0.016, M["rivet"])
    skirt(g, R, z0 + 0.07, zs, [M["olive"], M["olive"], M["steel_dk"]], max(14, int(TAU * R / 0.26)), M["brass"])
    Pf, Nf = P2.dome_hull(g, (0, 0, zs), R, R * 1.06, rz, M["olive"], M, seams=max(12, int(TAU * R / 0.3)),
                          band_mat=M["steel_dk"], ring_seams=(0.62,) if e == 6 else (0.5, 0.95))
    # masque avant entre les canons
    mw = R * 0.5
    PT.hull(g, -mw, mw, R * 0.55, R + 0.22, zs - 0.18, zs + rz * 0.5, ins=(0.04, 0.02, R * 0.26), panel=0.22,
            mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    g.box((0, R + 0.235, zs + 0.02), (mw * 1.1, 0.02, 0.04), M["emit"], "flat", what="fente")
    g.box((0, R + 0.25, zs + 0.065), (mw * 1.3, 0.03, 0.025), M["steel_hi"], "hard", what="visiere")
    g.cyl((mw * 0.45, R + 0.2 + 0.18, zs - 0.06), "y", 0.03, 0.4, M["steel_dk"], n=10, what="coax")
    g.cyl((mw * 0.45, R + 0.2 + 0.28, zs - 0.06), "y", 0.045, 0.16, M["steel_hi"], n=12, what="coax_manchon")
    # nacelle arrière : radiateur (lumineux dès l'ère IV), échappements
    bx = R * 0.62
    yb0, yb1 = -R - 0.3 - 0.1 * (e >= 11), -R * 0.5
    T = PT.hull(g, -bx, bx, yb0, yb1, zs - 0.22, zs + rz * 0.42, ins=(0.03, 0.04, 0.0), panel=0.24,
                mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    back = [V((-bx, yb0, zs - 0.22)), V((bx, yb0, zs - 0.22)), T[1], T[0]]
    if e >= 11:
        for (s0, s1) in ((0.08, 0.46), (0.54, 0.92)):
            PT.glow_grille(g, PT.lift(PT.face_quad(back, s0, s1, 0.2, 0.8), 0.03), 4, M["emit_soft"])
    else:
        g.grille(PT.lift(PT.face_quad(back, 0.15, 0.85, 0.2, 0.8), 0.01), 4)
    for sx in (-1, 1):
        PT.exhaust(g, (sx * bx * 0.7, (yb0 + yb1) / 2 - 0.05, zs + rz * 0.42), 0.05 + 0.015 * (e >= 11),
                   0.22 + 0.06 * (e >= 11))
    # tourelleau à périscopes et trappe
    cx, cy = -R * 0.32, -R * 0.12
    zc = zs + rz * math.sqrt(max(0.0, 1 - (cx / R) ** 2 - (cy / (R * 1.06)) ** 2)) - 0.03
    hc = 0.14 + 0.04 * (e >= 11)
    rc = 0.17 + 0.05 * (e >= 11)
    g.cyl((cx, cy, zc + hc / 2), "z", rc, hc, M["ochre"], n=24, style="soft", what="tourelleau")
    g.torus((cx, cy, zc + hc), "z", rc - 0.02, 0.018, M["steel_dk"], n=24, m=6, what="jonc")
    nper = 3 + (e >= 11) + (e >= 15)
    for k in range(nper):
        a = math.pi / 2 + (k - (nper - 1) / 2) * 0.55
        d = V((math.cos(a), math.sin(a), 0))
        Rr = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
        g.box(V((cx, cy, zc + hc * 0.6)) + d * rc, (0.07, 0.05, 0.06), M["steel_dk"], "hard", R=Rr, what="periscope")
        g.box(V((cx, cy, zc + hc * 0.6)) + d * (rc + 0.028), (0.05, 0.008, 0.03), M["emit"], "flat", R=Rr,
              what="lentille")
    hx, hy = R * 0.34, -R * 0.2
    zh = zs + rz * math.sqrt(max(0.0, 1 - (hx / R) ** 2 - (hy / (R * 1.06)) ** 2)) - 0.02
    PT.hatch(g, (hx, hy, zh), 0.13 + 0.03 * (e >= 11))
    return Pf, Nf


def _tete6(g):
    M = g.M
    Pf, Nf = head_core(g, 6)
    H = HEAD[6]
    slits(g, H["R"], RING_TOP[6] + 0.15, 5, M["emit"], a0=0.0, span=TAU)
    for sx in (-1, 1):
        gun_side(g, 6, sx)
    PT.sight(g, (H["R"] * 0.2, H["R"] * 0.45, H["zs"] + H["rz"] * 0.6), 0.16, 0.18, 0.1, M["emit"], lenses=1)
    PT.cable_run(g, [(-0.2, -H["R"] - 0.2, H["zs"] + 0.2), (-0.5, -0.3, H["zs"] + 0.15),
                     (-H["gx"], -0.15, H["zg"] + H["hr"])], 2, 0.018, 0.04, [M["rubber"], M["redcable"]])
    for th in (0.9, math.pi - 0.9):
        P2.applique(g, Pf, Nf, th, 0.3, 0.22, 0.18, M["steel_dk"], M)


def _tete11(g):
    M = g.M
    Pf, Nf = head_core(g, 11)
    H = HEAD[11]
    R = H["R"]
    slits(g, R, RING_TOP[11] + 0.18, 16, M["emit"], a0=0.0, span=TAU)
    for sx in (-1, 1):
        gun_side(g, 11, sx)
        PT.cable_run(g, [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * 0.8, -0.6, H["zs"] + 0.2),
                         (sx * H["gx"], -0.4, H["zg"] + H["hr"])], 3, 0.018, 0.04,
                     [M["rubber"], M["redcable"], M["rubber"]])
    zt = H["zs"] + H["rz"] * 0.86
    g.box((0.0, R * 0.32, zt), (R * 1.25, 0.1, 0.1), M["ochre"], "hard", what="telemetre")
    for sx in (-1, 1):
        g.cyl((sx * R * 0.64, R * 0.32, zt), "x", 0.07, 0.09, M["steel_dk"], n=14, what="telemetre_bout")
        g.cyl((sx * R * 0.64, R * 0.32 + 0.065, zt), "y", 0.045, 0.012, M["emit"], n=12, style="flat",
              what="lentille")
        g.box((sx * R * 0.3, R * 0.32, zt - 0.1), (0.05, 0.05, 0.12), M["steel_dk"], "hard", what="support")
    for th in (0.5, 0.95, 1.4, math.pi - 0.5, math.pi - 0.95, math.pi - 1.4):
        P2.applique(g, Pf, Nf, th, 0.32, 0.28, 0.22, M["ochre"], M)


def _tete15(g):
    M = g.M
    Pf, Nf = head_core(g, 15)
    H = HEAD[15]
    R = H["R"]
    slits(g, R, RING_TOP[15] + 0.2, 22, M["emit"], a0=0.0, span=TAU)
    slits(g, R, RING_TOP[15] + 0.36, 22, M["emit"], a0=0.14, span=TAU)
    for sx in (-1, 1):
        gun_side(g, 15, sx)
        PT.cable_run(g, [(sx * 0.35, -R - 0.35, H["zs"] + 0.3), (sx * 0.95, -0.7, H["zs"] + 0.24),
                         (sx * H["gx"], -0.5, H["zg"] + H["hr"])], 3, 0.02, 0.045,
                     [M["rubber"], M["redcable"], M["rubber"]])
    for sx in (-1, 1):
        P3.conduit(g, [(sx * 0.6, -R - 0.3, H["zs"] + 0.2), (sx * 1.1, -0.95, H["zs"] + 0.12),
                       (sx * H["gx"], -0.7, H["zg"] + H["hr"] * 0.6)], 0.04, M, M["emit"], step=0.1)
    # blindage à plaques multiples : deux rangées de plaques rapportées sur la coupole
    for th in (0.35, 0.75, 1.15, 1.6, 2.0, 2.4, 2.8, -0.35, -0.75, -2.4, -2.8):
        P2.applique(g, Pf, Nf, th, 0.3, 0.32, 0.26, M["ochre"] if int(abs(th) * 10) % 2 else M["steel_dk"], M)
    for th in (0.6, 1.25, 1.9, 2.55):
        P2.applique(g, Pf, Nf, th, 0.75, 0.26, 0.22, M["ochre"], M)
    # canon de coupole sur berceau blindé
    zr = H["zs"] + H["rz"] * 0.92
    zc = zr + 0.3
    PT.hull(g, -0.38, 0.38, -0.22, 0.66, zr - 0.04, zr + 0.2, ins=(0.04, 0.04, 0.1), panel=0.22,
            mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    PT.receiver(g, 0.0, -0.22, 0.66, zc - 0.18, zc + 0.16, 0.36, mats=[M["ochre"], M["olive"]])
    PT.gatling(g, 0.0, 0.66, zc, 1.7, 6, 0.052, 0.125, 0.68, coil=M["emit"], brake=True)
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.26, 0.3, zr + 0.02), (sx * 0.32, 0.6, zr + 0.2), 0.026)
    P2.feed_chute(g, [(0.45, -0.38, zr + 0.05), (0.4, -0.06, zc + 0.12), (0.15, 0.1, zc + 0.17)], 0.12, M)
    # réserve d'énergie de la nacelle : condensateurs à couronne lumineuse
    PT.capacitors(g, (0.0, -R - 0.14, H["zs"] + H["rz"] * 0.42), 4, 1, 0.1, 0.22, M["emit"])
    PT.sight(g, (-R * 0.64, R * 0.3, H["zs"] + H["rz"] * 0.5), 0.26, 0.26, 0.15, M["emit"], lenses=2)


def tete(g, e):
    {6: _tete6, 11: _tete11, 15: _tete15}[e](g)
