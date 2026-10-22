"""Époque 9 · Atome (ère III, 4×4, niveaux 17 et 18). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 9) : « plomb, hublots, radioactif ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py, kit.py ; la dalle de béton de la tourelle secondaire
devient une dalle de caillebotis du kit).
Corrections de design de la QUATRIÈME PASSE (23/10, constructeur de la plage basse) :
  - plomb GRIS MAT plus clair ; ailettes sombres (pose N : aucune bague claire) ; plaque de signalisation à trèfle
    sur chaque fourreau ; grand trèfle peint et panneau « radiations » ; fenêtre à 3 barres de combustible vert
    uranium ; hublots de la cuve plus grands et plus nombreux ; tour de refroidissement plus grande ; lampe hors du
    contour retirée (îlot de 22 px) ; chanfrein 0,55.
Emplacements remplis : arme (gatling à 6 tubes sous fourreau OCTOGONAL de plomb, paquets d'ailettes, frein
octogonal, culasse à hublots verts, magasins plombés à trèfle), mitrailleuse coaxiale, 1re tourelle secondaire,
grands volumes du socle (tour de refroidissement, cuve sphérique plombée à hublots, fûts, balises), liaisons (grosses
gaines annelées de cuivre à raccords à damier), nacelle (tour de refroidissement), trèfle, hublots et bague de danger
sur la tête, foyers vert uranium, pièce paire (2 conteneurs plombés).
"""
import math

from mathutils import Matrix, Vector

import corps
import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from corps import Y, at
from kit import SQ2, TAU, axv, basis

V = Vector

EPOQUE = 9
NOM = "Atome"
KIN = 2   # rang dans l'ère III
FOYER = dict(rgb=(0.361, 1.0, 0.29))
CANON = dict(L=1.8, nb=6, rb=0.052, rr=0.128)
# passe 4 : chanfrein de plateforme d'époque (remplissage, catalogue §A.5 ; silhouette distincte des voisines)
PLATEFORME = dict(chanfrein=0.55)
HABILLAGE = dict(jupe_cerclage="hazy", tremie="lead", pochoirs=True, munitions=("lead", "uranium"),
                 grille_nacelle="lead", tourelleau="lead", chapeau="lead")
ST = dict(jacket="atom", brake="octo", drive="lead", drive_mat="lead", drive_n=8, band="lead",
          recv_mats=("lead", "steel_dk"), recv_sig="porthole", feed="lead_mag", skirt="hazy", appl="lead",
          gmask=("lead", "olive"), arm=("lead", "steel_dk"), cap="lead", col=("olive", "lead"),
          nac=("lead", "olive"), coax=True)


def matieres(metal, M):
    """Passe 4 : PLOMB GRIS MAT (« fûts plombés gris mat » : gris neutre plus clair que le corps, très rugueux, peu
    métallique, sans reflet) ; béton plus clair (× 1,45, test noir et blanc de la passe 3) ; jaune des plaques de
    signalisation (patiné, jamais vif : C5)."""
    metal("lead", (0.23, 0.225, 0.215), rough=0.66, met=0.35, grain=0.28 * 0.62, rust=(0.13, 0.12, 0.105), ra=0.25,
          dirt=0.85, stain=0.6, stain2=0.32, sscale=5.0, wear=1.4, streak=0.45)
    metal("concrete", (0.17, 0.155, 0.135), rough=0.92, met=0.0, grain=0.5 * 0.62, gscale=30.0, dirt=0.9, stain=0.85,
          stain2=0.32, sscale=5.0, wear=1.4, streak=0.6, tone=1.45)


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : tour de refroidissement, cuve sphérique plombée, fûts, balises ; 1re tourelle secondaire
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=3)
    socle_atom(g, KIN)
    # 3e époque de l'ère III : 1re tourelle secondaire (catalogue §A.4), au nord-ouest, sur sa dalle
    corps.dalle(g, -1.98, -1.05, Y(1.05), Y(1.98))
    with at(g, -1.56, 1.58, 0.0):
        P2.pedestal(g, 0.36, 0.0, 0.26, 8, g.M, [g.M["olive"], g.M["steel_dk"]], gussets=False)
        mini_turret_e(g, EPOQUE, (0, 0, 0.26), 0.82, 0.55, g.M["emit"])
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def cooling_tower(g, x, y, r, h, M):
    prof = [(0.0, 1.0), (0.18, 0.86), (0.4, 0.72), (0.62, 0.68), (0.82, 0.72), (1.0, 0.8)]
    for i in range(len(prof) - 1):
        z0_, r0 = prof[i]
        z1_, r1 = prof[i + 1]
        g.cyl((x, y, h * (z0_ + z1_) / 2), "z", r * r0, h * (z1_ - z0_), M["concrete"], n=40, r2=r * r1,
              caps=(i == 0), what="tour")
    g.cyl((x, y, h - 0.01), "z", r * 0.8 - 0.02, 0.02, M["void"], n=32, style="flat", what="bouche")
    g.tube_shell((x, y, h), "z", r * 0.84, r * 0.74, 0.04, M["steel_dk"], n=40, what="levre")
    F.hazard_ring(g, (x, y, h * 0.14), "z", r * 0.88, 0.07, n=20)
    for zf in (0.4, 0.62):
        g.tube_shell((x, y, h * zf), "z", r * (0.73 if zf < 0.5 else 0.69) + 0.012, r * 0.6, 0.02, M["concrete"],
                     n=40, what="ceinture")
    for kk in range(12):
        a = TAU * kk / 12
        g.box((x + math.cos(a) * r * 0.98, y + math.sin(a) * r * 0.98, 0.05), (0.05, 0.05, 0.1), M["concrete"],
              "hard", R=Matrix.Rotation(a, 3, "Z"), what="pied")
    P2.ladder(g, V((x, y - r * 0.95, 0.0)), V((0, -1, 0)), 0.0, h * 0.5, 0.12, M)


def socle_atom(g, k):
    M = g.M
    E = M["emit"]
    cooling_tower(g, 1.3, Y(1.2), 0.56, 1.25, M)
    sphere_tank(g, 1.52, Y(0.0), 0.42, 1.05, E, ladder_dir=(1, -0.2))
    # ouest : parc de fûts plombés à trèfles sur dalle de béton, blocs de protection
    F.prism(g, [(-1.94, Y(-1.12)), (-1.28, Y(-1.12)), (-1.28, Y(0.62)), (-1.94, Y(0.62))], 0.0, 0.06,
             M["concrete"])
    for i, (xx, yn) in enumerate(((-1.78, -0.55), (-1.52, -0.58), (-1.78, -0.25), (-1.52, -0.28), (-1.78, 0.05),
                                  (-1.52, 0.02))):
        F.drum(g, (xx, Y(yn), 0.06), 0.11, 0.3, M["lead"], M["hazy"], trefoil=(i % 2 == 0))
    PT.hull(g, -1.94, -1.3, Y(0.18), Y(0.62), 0.06, 0.4, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["concrete"], M["concrete"]], rivets=False)
    g.hazard([V((-1.92, Y(0.18) - 0.004, 0.1)), V((-1.32, Y(0.18) - 0.004, 0.1)), V((-1.32, Y(0.18) - 0.004, 0.2)),
              V((-1.92, Y(0.18) - 0.004, 0.2))], 8, t=0.008)
    # passe 4 : fenêtre de contrôle sur le dessus du bloc de protection, 3 barres de combustible vert uranium
    # (foyers lisibles au zoom 1, chacun < 0,02 t²), cadre et barreaux de plomb
    wx, wy = -1.62, Y(0.4)
    g.box((wx, wy, 0.405), (0.42, 0.44, 0.012), M["void"], "flat", what="fenetre")
    for i in range(3):
        g.box((wx - 0.12 + 0.12 * i, wy, 0.412), (0.05, 0.36, 0.01), E, "flat", what="barre_combustible")
    for s_ in (-1, 1):
        g.box((wx + s_ * 0.22, wy, 0.42), (0.04, 0.48, 0.035), M["lead"], "hard", what="cadre")
        g.box((wx, wy + s_ * 0.23, 0.42), (0.48, 0.04, 0.035), M["lead"], "hard", what="cadre")
    for i in range(2):
        g.box((wx - 0.06 + 0.12 * i, wy, 0.422), (0.022, 0.44, 0.022), M["lead"], "hard", what="barreau")
    # grand trèfle peint sur la dalle de béton et panneau de signalisation sur poteau (signature, lisible de haut)
    F.trefoil(g, (-1.61, Y(-0.98), 0.063), (0, 0, 1), 0.15)
    sign(g, (-1.61, Y(-0.76), 0.06), 0.3, 0.56)
    # balises de radiation
    for (xx, yn) in ((-1.78, -0.55), (-1.52, -0.28), (-1.78, 0.05)):
        PT.lamp(g, (xx + 0.04, Y(yn) - 0.04, 0.37), (0, -0.2, 1), 0.026, E, cage=False)
    for (xx, yn) in ((-0.9, -1.3), (0.9, -1.3), (1.84, 0.6), (-0.6, -1.0), (0.6, -1.0), (1.84, -0.6),
                     (-1.84, 0.85), (0.75, 1.78), (-0.4, 1.8)):
        PT.lamp(g, (xx, Y(yn), 0.06), (0, -0.3, 1), 0.03, E, cage=True)
    for (xx, yn) in ((-1.9, -0.95), (0.9, 1.85)):
        g.cyl((xx, Y(yn), 0.15), "z", 0.018, 0.3, M["steel_dk"], n=8, what="poteau")
        g.cyl((xx, Y(yn), 0.32), "z", 0.04, 0.05, E, n=12, what="feu")
        g.cyl((xx, Y(yn), 0.355), "z", 0.045, 0.015, M["steel_dk"], n=12, what="chapeau")
        g.box((xx, Y(yn), 0.02), (0.1, 0.1, 0.04), M["concrete"], "hard", what="semelle")
    # gaines annelées de cuivre épaisses (réacteur vanilla)
    link(g, 9, [(1.2, Y(0.0), 0.4), (1.05, Y(0.0), 0.62), (0.9, Y(-0.05), 0.76)], 0.07)
    link(g, 9, [(1.0, Y(1.0), 0.3), (0.82, Y(0.86), 0.5), (0.66, Y(0.7), 0.6)], 0.07)
    link(g, 9, [(-1.3, Y(-0.2), 0.3), (-1.15, Y(-0.2), 0.6), (-0.96, Y(-0.2), 0.74)], 0.07)
    g.halo((1.55, Y(0.0), 0.5), M["_emit_rgb"], 14.0)
    g.halo((-1.6, Y(-0.2), 0.5), M["_emit_rgb"], 10.0)
def sign(g, c, s, h):
    """Panneau de signalisation « danger radiations » sur 2 poteaux (atome) : plaque jaune patinée cerclée de noir,
    grand trèfle, inclinée vers le haut (lisible de dessus)."""
    M = g.M
    x, y, z = c
    for s_ in (-1, 1):
        g.cyl((x + s_ * s * 0.38, y, z + h * 0.5), "z", 0.016, h, M["steel_dk"], n=8, what="poteau")
        g.box((x + s_ * s * 0.38, y, z + 0.015), (0.06, 0.06, 0.03), M["concrete"], "hard", what="semelle")
    g.push((x, y - 0.02, z + h - s * 0.4), rx=-0.75)
    g.box((0, 0, 0), (s + 0.03, 0.022, s + 0.03), M["hazk"], "hard", what="panneau")
    g.box((0, -0.013, 0), (s, 0.006, s), M["hazy"], "flat", what="panneau")
    F.trefoil(g, (0, -0.018, 0), (0, -1, 0), s * 0.36)
    g.pop()


def sphere_tank(g, x, y, r, h, emat, ladder_dir=(1, 0.2)):
    """Cuve sphérique plombée à hublots verts (atome ; idée de la cuve à hublots de la haute technologie, hublots
    du réacteur vanilla) : jupe de béton à bande jaune et noire, sphère de plomb à ceinture rivetée, 3 hublots
    cerclés, trou d'homme, évent, échelle. Même place et même masse que le réservoir debout de la lignée."""
    M = g.M
    zc = max(0.12 + r * 0.95, h - r * 0.95)
    g.cyl((x, y, 0.045), "z", r + 0.06, 0.09, M["concrete"], n=8, style="hard", phase=math.pi / 8, what="plinthe")
    g.cyl((x, y, (0.09 + zc) / 2), "z", r * 0.72, zc - 0.09, M["concrete"], n=24, what="jupe")
    q = [V((x - r * 0.72, y - r * 0.73, 0.1)), V((x + r * 0.72, y - r * 0.73, 0.1)),
         V((x + r * 0.72, y - r * 0.73, 0.18)), V((x - r * 0.72, y - r * 0.73, 0.18))]
    g.hazard(q, 6, t=0.01)
    F.sphere(g, (x, y, zc), r, M["lead"], n=36, m=18, what="sphere")
    g.tube_shell((x, y, zc), "z", r + 0.022, r - 0.03, 0.05, M["steel_dk"], n=40, what="ceinture")
    nb = int(TAU * r / 0.11)
    for k in range(nb):
        a = TAU * (k + 0.5) / nb
        d = V((math.cos(a), math.sin(a), 0))
        g.dome(V((x, y, zc)) + d * (r + 0.024), d, 0.014, M["rivet"])
    # méridiens soudés (lecture du volume) et hublots verts côté sud
    for k in range(6):
        a = TAU * (k + 0.25) / 6
        pts = [V((x + r * 1.004 * math.cos(ph) * math.cos(a), y + r * 1.004 * math.cos(ph) * math.sin(a),
                  zc + r * 1.004 * math.sin(ph))) for ph in [0.1 + 1.2 * i / 10 for i in range(11)]]
        g.tube(pts, 0.011, M["steel_dk"], n=6, what="soudure")
    for a, ph in ((-math.pi / 2 - 0.55, 0.35), (-math.pi / 2 + 0.45, 0.3), (-math.pi / 2 - 0.05, 0.85),
                  (-math.pi / 2 - 1.2, 0.5), (0.3, 0.75)):
        d = V((math.cos(ph) * math.cos(a), math.cos(ph) * math.sin(a), math.sin(ph)))
        c = V((x, y, zc)) + d * (r + 0.004)
        g.cyl(c, d, 0.078, 0.03, M["steel_dk"], n=20, what="cadre")
        g.cyl(c + d * 0.016, d, 0.058, 0.006, emat, n=20, style="flat", what="hublot")
        F.bolts_ring(g, c + d * 0.016, d, 0.068, 8, M["rivet"], r=0.011)
    g.cyl((x + r * 0.25, y + r * 0.2, zc + r * 0.93), "z", r * 0.24, 0.05, M["steel_dk"], n=16, what="trou_homme")
    g.tube([V((x - r * 0.3, y + r * 0.3, zc + r * 0.85)), V((x - r * 0.3, y + r * 0.3, zc + r + 0.1)),
            V((x - r * 0.3 + 0.06, y + r * 0.3, zc + r + 0.14))], 0.02, M["steel_hi"], n=8, what="event")
    F.trefoil(g, V((x + r * 0.33, y, zc + r * 0.3)) + V((0, -1, 0)) * (r * 0.9 + 0.006), (0.33, -0.9, 0.3), 0.05)
    ld = V((ladder_dir[0], ladder_dir[1], 0)).normalized()
    P2.ladder(g, V((x, y, 0)) + ld * (r + 0.05), ld, 0.09, zc + r * 0.6, 0.16, M)
def mini_turret_e(g, e, c, s, rz, emat):
    """Tourelle secondaire (1re à la fin de l'ère III, catalogue §4) : celle de la lignée, canons d'époque 9."""
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
        barrels(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.55 * s, 4, 0.022, 0.045 * s, M["gun"], collars=(0.75,))
        g.cyl((sx * 0.31 * s, 0.22 * s + 0.17 * s, 0.26 * s), "y", 0.1 * s, 0.24 * s, M["lead"], n=8, style="hard",
              phase=math.pi / 8, what="jaquette")
        g.cyl((sx * 0.31 * s, 0.22 * s + 0.58 * s, 0.26 * s), "y", 0.085 * s, 0.08 * s, M["lead"], n=8, style="hard",
              phase=math.pi / 8, what="frein")
        F.lit_ring(g, (sx * 0.31 * s, 0.22 * s + 0.625 * s, 0.26 * s), "y", 0.07 * s, emat)
    F.trefoil(g, (0.0, -0.05 * s, 0.4 * s + 0.004), (0, 0, 1), 0.05)
    PT.lamp(g, (0.0, 0.12 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.03, emat, cage=False)
    g.pop()


def barrels(g, x, y0, z, L, nb, rb, rr, mat, phase=0.3, collar_mat=None, collars=(0.8,), ends=True, arr="ring"):
    """Faisceau de la lignée : corps.rosette (même géométrie que parts4.barrels de la passe 3)."""
    return corps.rosette(g, x, y0, z, L, nb, rb, rr, mat=mat, phase=phase, colliers=collars, collier_mat=collar_mat,
                         bouts=ends, arr=arr)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : GROSSE gaine annelée de cuivre (réacteur et silo vanilla), raccords plombés à liseré jaune
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » de l'atome)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    S_ = g.hose(P, r * 1.2, M["copper"], step=0.034)
    for q, d in ((S_[0], S_[1] - S_[0]), (S_[-1], S_[-1] - S_[-2])):
        g.cyl(q, d, r * 1.6, 0.07, M["lead"], n=8, style="hard", phase=math.pi / 8, what="raccord")
        g.tube_shell(q + d.normalized() * 0.045, d, r * 1.55, r * 0.9, 0.025, M["hazy"], n=8, what="liseré")
    return P


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 18 : 2 conteneurs plombés (coffre chanfreiné, trèfle, hublot vert, poignées)
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    M = g.M
    E = M["emit"]
    side = c.side
    cx = c.T["piece"]["x"]
    cy = -cx
    s = c.T["piece"]["s"]
    for sx in (-1, 1):
        xa, xb = sorted((sx * (cx - 0.3 - 0.07 * side), sx * (cx + 0.2 + 0.03 * side)))
        corps.dalle(g, xa, xb, Y(cy - 0.24 - 0.02 * side), Y(cy + 0.34 + 0.06 * side))
    for sx in (-1, 1):
        with at(g, sx * cx, cy, sx * -0.25):
            lead_chest(g, (0, 0, 0), 0.0, E, 1.45 * s)
    _halo(g, [(-cx, Y(cy), 0.4), (cx, Y(cy), 0.4)], 12.0)


def lead_chest(g, c, rz, emat, s=1.0):
    """Conteneur plombé (atome) : coffre chanfreiné, trèfle, hublot vert, poignées."""
    M = g.M
    g.push(c, rz=rz)
    w, d, h = 0.34 * s, 0.26 * s, 0.22 * s
    ch = 0.05 * s
    bot = [(-w / 2 + ch, -d / 2), (w / 2 - ch, -d / 2), (w / 2, -d / 2 + ch), (w / 2, d / 2 - ch),
           (w / 2 - ch, d / 2), (-w / 2 + ch, d / 2), (-w / 2, d / 2 - ch), (-w / 2, -d / 2 + ch)]
    F.prism(g, bot, 0.0, h, M["lead"])
    F.prism(g, [(px * 0.86, py * 0.86) for px, py in bot], h, h + 0.04, M["lead"])
    g.box((0, 0, h * 0.25), (w + 0.01, d + 0.01, 0.03), M["hazy"], "hard", what="bande")
    F.trefoil(g, (0, 0, h + 0.042), (0, 0, 1), 0.06 * s)
    g.cyl((w * 0.28, -d / 2 - 0.004, h * 0.6), "y", 0.04, 0.02, M["steel_hi"], n=16, what="cadre")
    g.cyl((w * 0.28, -d / 2 - 0.014, h * 0.6), "y", 0.027, 0.006, emat, n=16, style="flat", what="hublot")
    for sx in (-1, 1):
        g.box((sx * (w / 2 + 0.015), 0, h * 0.7), (0.02, d * 0.4, 0.03), M["steel_hi"], "hard", what="poignee")
    for (px, py) in bot[::2]:
        g.dome((px * 0.9, py * 0.9, h + 0.042), (0, 0, 1), 0.015, M["rivet"])
    g.pop()


# ------------------------------------------------------------------------------------------------
# Arme (E1) : gatling plombé à ailettes
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    M = g.M
    H = c.H
    w_atom(g, ST, H, x, sx)
    y0 = H["recv"][0]
    PT.lamp(g, (x - sx * H["wr"] * 0.25, y0 + 0.1, H["zg"] + H["hr"] + 0.03), (0, 0.4, 1), 0.026, M["emit"], cage=True)


def w_gatling(g, st, H, x, sx):
    """Faisceau rotatif de la lignée, habillé par l'époque (jaquette, bouche, entraînement, alimentation)."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    breech(g, st, x, y0, y1, zg - hr, zg + hr, wr)
    Ld = 0.26 + hr * 0.6
    drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.78, Ld)
    gun_e(g, st, H, x, sx)
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M[k] for k in st["gmask"]], rivet_step=0.11)
    xo = x + sx * (wr / 2 - 0.005)
    feed(g, st, H, x, sx, xo)


def w_atom(g, st, H, x, sx):
    """Époque 9 : gatling à 6 tubes sous fourreau OCTOGONAL de plomb, 3 paquets d'AILETTES de refroidissement
    radiales (disques octogonaux), plaques de danger jaune et noire, hublot vert, frein octogonal."""
    M = g.M
    w_gatling(g, st, H, x, sx)
    y1 = H["recv"][1]
    zg = H["zg"]
    rs = H["rr"] + H["rb"] + 0.028
    R8 = rs * 1.12
    Lj = H["L"] * min(st.get("jacket_f", 0.62), corps.JAQUETTE_MAX)
    for f in (0.5,):
        for t in range(int(Lj * 0.42 / 0.035)):
            yy = y1 + Lj * 0.3 + t * 0.035
            g.cyl((x, yy, zg), "y", R8 + 0.11, 0.016, M["steel_dk"] if t % 2 else M["lead"], n=8, style="hard",
                  phase=math.pi / 8, what="ailette")
    g.box((x, y1 + Lj * 0.46, zg - R8 * 0.62), (2 * (R8 + 0.09), Lj * 0.84, R8 * 0.9), M["lead"], "hard",
          what="quille")
    for s in (-1, 1):  # plaques de danger sur les flancs
        g.box((x + s * (R8 * math.cos(math.pi / 8) + 0.012), y1 + Lj * 0.84, zg), (0.008, 0.16, 0.1), M["hazy"],
              "flat", what="plaque")
        g.hazard([V((x + s * (R8 * 0.93 + 0.018), y1 + Lj * 0.84 - 0.07, zg - 0.045)),
                  V((x + s * (R8 * 0.93 + 0.018), y1 + Lj * 0.84 + 0.07, zg - 0.045)),
                  V((x + s * (R8 * 0.93 + 0.018), y1 + Lj * 0.84 + 0.07, zg + 0.045)),
                  V((x + s * (R8 * 0.93 + 0.018), y1 + Lj * 0.84 - 0.07, zg + 0.045))][::s], 5, t=0.004)


def gun_e(g, st, H, x, side):
    """Faisceau de la lignée (corps.rosette), fourreau octogonal et frein octogonal ; renvoie le rayon de jaquette."""
    M = g.M
    y1 = H["recv"][1]
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    zg = H["zg"]
    rs = rr + rb + 0.028
    pos = corps.rosette(g, x, y1, zg, L, nb, rb, rr, mat=M[st.get("barrel", "gun")], collier_mat=M[st["band"]],
                        colliers=st.get("collars", (0.8,)), bouts=False)
    Lj = L * min(st.get("jacket_f", 0.62), corps.JAQUETTE_MAX)
    jk_atom(g, st, x, y1, zg, Lj, rs, H)
    br_octo(g, st, x, y1 + L, zg, rs, pos, H)
    return rs


def jk_atom(g, st, x, y0, z, Lj, rs, H):
    """Époque 9 : jaquette octogonale chanfreinée en plomb, manchons de refroidissement annelés."""
    """Époque 9 : fourreau OCTOGONAL en plomb gris (clair, jamais noir), chanfreins, 3 nervures octogonales,
    2 bandes à damier jaune et noir, hublot vert sur le dessus près de la culasse, trèfle près de la bouche.
    Aucune spire de cuivre sur le canon (motif réservé à l'électricité) : le cuivre annelé vit dans les gaines."""
    M = g.M
    R8 = rs * 1.12
    ph8 = math.pi / 8
    g.cyl((x, y0 + Lj / 2, z), "y", R8, Lj, M["lead"], n=8, style="hard", phase=ph8, what="jaquette")
    for f in (0.12, 0.5, 0.88):
        g.cyl((x, y0 + Lj * f, z), "y", R8 + 0.022, 0.04, M["lead"], n=8, style="hard", phase=ph8, what="nervure")
        for k in range(8):
            a = ph8 + TAU * k / 8 + TAU / 16
            d = V((math.cos(a), 0, math.sin(a)))
            if d.z < -0.3:
                continue
            g.dome(V((x, y0 + Lj * f, z)) + d * ((R8 + 0.022) * math.cos(ph8) + 0.004), d, 0.014, M["rivet"])
    # bandes à damier (8 pans alternés jaune / noir) entre les nervures
    for f in (0.31, 0.69):
        for k in range(8):
            a = ph8 + TAU * k / 8 + TAU / 16
            d = V((math.cos(a), 0, math.sin(a)))
            if d.z < -0.45:
                continue
            rf = R8 * math.cos(ph8)
            Rr = Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed()
            g.box(V((x, y0 + Lj * f, z)) + d * (rf + 0.004), (2 * R8 * math.sin(ph8) * 0.98, 0.07, 0.008),
                  M["hazy"] if k % 2 else M["hazk"], "flat", R=Rr, what="damier")
    top = V((x, y0 + Lj * 0.14, z + R8 * math.cos(ph8)))
    g.cyl(top + V((0, 0, 0.012)), "z", 0.042, 0.024, M["steel_hi"], n=18, what="cadre")
    g.cyl(top + V((0, 0, 0.026)), "z", 0.029, 0.006, M["emit"], n=18, style="flat", what="hublot")
    F.bolts_ring(g, top + V((0, 0, 0.024)), (0, 0, 1), 0.036, 6, M["rivet"], r=0.011)
    # plaque de signalisation à trèfle posée à plat sur le dessus du fourreau (lisible de haut, poses E et N)
    zt8 = z + R8 * math.cos(ph8)
    yp = y0 + Lj * 0.86
    g.box((x, yp, zt8 + 0.008), (0.19, 0.19, 0.012), M["hazk"], "hard", what="plaque")
    g.box((x, yp, zt8 + 0.016), (0.165, 0.165, 0.006), M["hazy"], "flat", what="plaque")
    F.trefoil(g, V((x, yp, zt8 + 0.021)), (0, 0, 1), 0.065)
    for sxx in (-1, 1):
        for syy in (-1, 1):
            g.dome((x + sxx * 0.07, yp + syy * 0.07, zt8 + 0.02), (0, 0, 1), 0.012, M["rivet"])


def br_octo(g, st, x, yb, z, rs, pos, H):
    """Époque 9 : frein de bouche octogonal à évents."""
    M = g.M
    rb = H["rb"]
    R8 = rs * 1.12 + 0.03
    g.cyl((x, yb + 0.06, z), "y", R8, 0.17, M["lead"], n=8, style="hard", phase=math.pi / 8, what="frein")
    for f in range(8):
        a = math.pi / 8 + TAU * f / 8 + TAU / 16
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.4:
            continue
        rf = R8 * math.cos(math.pi / 8)
        for k in range(2):
            g.box(V((x, yb + 0.02 + k * 0.08, z)) + d * (rf + 0.002), (0.05, 0.035, 0.01), M["void"], "flat",
                  R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="event")
    g.cyl((x, yb + 0.15, z), "y", R8 - 0.02, 0.012, M["concrete"], n=8, phase=math.pi / 8, what="face")
    F.ears(g, x, yb + 0.06, z, R8 + 0.025, 0.12, R8 * 0.9, M["lead"])
    F.bores(g, x, yb + 0.156, z, pos, rb, M["copper"])
    F.lit_ring(g, (x, yb + 0.158, z), "y", rs + 0.01, M["emit"])
    g.tube_shell((x, yb - 0.025, z), "y", R8 + 0.006, R8 - 0.03, 0.022, M["hazy"], n=8, what="liseré")


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) plombée, HUBLOTS verts ronds sur les deux flancs."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    T = PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)
    for s in (-1, 1):
        c = V((x + s * (w / 2 + 0.004), (y0 + y1) / 2, (z0 + z1) / 2))
        g.cyl(c, (s, 0, 0), 0.055, 0.02, M["steel_hi"], n=18, what="cadre")
        g.cyl(c + V((s * 0.012, 0, 0)), (s, 0, 0), 0.038, 0.006, M["emit"], n=18, style="flat", what="hublot")
        F.bolts_ring(g, c + V((s * 0.012, 0, 0)), (s, 0, 0), 0.047, 6, M["rivet"], r=0.012)
    return T


def drive(g, st, c, r, L):
    """Organe arrière du canon : moteur OCTOGONAL de plomb, bande de danger."""
    M = g.M
    x, y, z = c
    body = M[st.get("drive_mat", "steel_dk")]
    g.cyl((x, y, z), "y", r, L, body, n=st["drive_n"], style="hard", phase=math.pi / 8, what="moteur")
    nf = int((L * 0.5) / 0.045)
    fm = M[st.get("fin_mat", "steel_hi")]
    for kk in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + kk * 0.045, z), "y", r + 0.026, r - 0.01, 0.014, fm, n=28, what="ailette")
    g.tube_shell((x, y + L * 0.3, z), "y", r + 0.015, r - 0.01, 0.03, M["hazy"], n=8, what="bande")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M[st.get("flange_mat", "olive")], n=24, style="soft",
          what="flasque")
    F.bolts_ring(g, (x, y - L / 2 - 0.06, z), (0, -1, 0), r * 0.66, 8, M["rivet"], r=0.016)
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M[st["band"]], n=12, what="moyeu")


def feed(g, st, H, x, sx, xo):
    """Alimentation : magasins plombés à trèfle, goulotte annelée de cuivre."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    bw, bl, bh = 0.2, H["L"] * 0.34, 0.22
    bx0, bx1 = sorted((xo, xo + sx * bw))
    PT.hull(g, bx0, bx1, y0 - 0.05, y0 - 0.05 + bl, zg - bh * 0.62, zg + bh * 0.42, ins=(0.025, 0.025, 0.025),
            panel=0.24, mats=[M["lead"], M["lead"]], rivet_step=0.11)
    bc = (bx0 + bx1) / 2
    F.trefoil(g, (bc, y0 + bl * 0.4, zg + bh * 0.42 + 0.004), (0, 0, 1), 0.06)
    g.hose([(bc, y0 + bl * 0.75, zg + bh * 0.42), (bc - sx * 0.05, y0 + bl * 0.7, zg + hr + 0.06),
            (x + sx * wr * 0.2, y0 + bl * 0.6, zg + hr + 0.05)], 0.04, M["copper"], step=0.028)


# ------------------------------------------------------------------------------------------------
# Masque, nacelle, tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=ST["gmask"], fentes=((0.0, 1.1),), visiere=("steel_dk", 0.03),
                        coax=dict(fut="gun", manchon=ST["band"], manchon_y=0.3, manchon_r=0.046, manchon_L=0.12,
                                  anneau=True))


def nacelle(g, c):
    """Petite tour de refroidissement hyperboloïde sur la nacelle et un échappement."""
    bx, yb0, yb1, ztop, yc = c.nac
    tower(g, (bx * 0.35, yc, ztop), 0.165, 0.22)
    PT.exhaust(g, (-bx * 0.7, yc - 0.05, ztop), 0.05, 0.2)


def tower(g, c, r, h):
    """Petite tour de refroidissement hyperboloïde (atome), béton à bandes."""
    M = g.M
    x, y, z = c
    prof = [(0.0, 1.0), (0.3, 0.8), (0.55, 0.72), (0.8, 0.78), (1.0, 0.86)]
    for i in range(len(prof) - 1):
        z0_, r0 = prof[i]
        z1_, r1 = prof[i + 1]
        g.cyl((x, y, z + h * (z0_ + z1_) / 2), "z", r * r0, h * (z1_ - z0_), M["concrete"], n=24, r2=r * r1,
              what="tour")
    g.tube_shell((x, y, z + h), "z", r * 0.88, r * 0.74, 0.03, M["steel_dk"], n=24, what="levre")
    g.cyl((x, y, z + h - 0.01), "z", r * 0.75, 0.01, M["void"], n=20, style="flat", what="bouche")
    g.tube_shell((x, y, z + h * 0.15), "z", r * 0.98, r * 0.85, 0.03, M["hazy"], n=24, what="bande")
    for k in range(6):
        a = TAU * k / 6
        g.box((x + math.cos(a) * r * 0.95, y + math.sin(a) * r * 0.95, z + 0.04), (0.03, 0.03, 0.08), M["steel_dk"],
              "hard", what="pied")


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    side = c.side
    k = KIN
    F.slits(g, R, c.rt + 0.1 + 0.02 * side, 13, M["emit"], a0=math.pi * 0.62, span=math.pi * 1.76)
    F.voyants_tete(g, H, 18)
    PT.sight(g, (R * 0.2, R * 0.45, H["zs"] + H["rz"] * 0.6), 0.16 + 0.04 * (side - 3), 0.18, 0.1, M["emit"],
             lenses=side - 2)
    appl = M[ST["appl"]]
    n1 = {0: 3, 1: 6, 2: 8}[k] + (side - 2)
    for i in range(n1):
        th = 0.45 + (math.pi - 0.9) * (i + 0.5) / n1
        P2.applique(g, c.Pf, c.Nf, th, 0.3, 0.22 + 0.03 * (side - 2), 0.18 + 0.03 * (side - 2), appl, M)
    n2 = 2 + 2 * k
    for i in range(n2):
        th = 0.7 + (math.pi - 1.4) * (i + 0.5) / n2
        P2.applique(g, c.Pf, c.Nf, th, 0.72, 0.2, 0.16, M["lead"], M)
    F.trefoil(g, c.Pf(math.pi / 2, 0.55, 1.03), c.Nf(math.pi / 2, 0.55), 0.06)
    # hublots verts ronds (réacteur vanilla) sur les flancs de la nacelle, bandes jaunes et noires
    bx = R * 0.62
    yc = (-R - 0.26 - R * 0.5) / 2
    for sx in (-1, 1):
        c_ = V((sx * (bx + 0.004), yc, H["zs"] + 0.02))
        g.cyl(c_, (sx, 0, 0), 0.06, 0.02, M["steel_hi"], n=18, what="cadre")
        g.cyl(c_ + V((sx * 0.012, 0, 0)), (sx, 0, 0), 0.042, 0.006, M["emit"], n=18, style="flat", what="hublot")
        F.bolts_ring(g, c_ + V((sx * 0.012, 0, 0)), (sx, 0, 0), 0.051, 6, M["rivet"], r=0.012)
    g.hazard([V((-R * 0.5, R + 0.24, H["zs"] - 0.14)), V((R * 0.5, R + 0.24, H["zs"] - 0.14)),
              V((R * 0.5, R + 0.24, H["zs"] - 0.08)), V((-R * 0.5, R + 0.24, H["zs"] - 0.08))], 8, t=0.008)
    # signature de coupole : bague de danger
    F.hazard_ring(g, (0, 0, H["zs"] + 0.035), "z", R * 1.03, 0.07, n=max(16, int(TAU * R / 0.14)))
