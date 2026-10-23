"""Époque 10 · Haute technologie (ère IV, 5×5, niveaux 19 et 20). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 10) : « caréné, câbles, voyants ».
Quatrième passe (23/10), corrections du constructeur de la plage haute sur le portage de la passe 3 :
  - ARME (règle d'or 1) : la nacelle fermée est retirée. La ROSETTE de 6 tubes de la lignée (corps.rosette, colliers
    noir mat) se voit sur toute la moitié avant ; le CARÉNAGE gris clair patiné (fentes de ventilation longitudinales,
    joints noir mat, nappe de câbles rouge et bleue, radôme de visée, antenne fouet) ne couvre que la moitié arrière
    (0,46 L < corps.JAQUETTE_MAX) ; frein à 3 DÉFLECTEURS plus larges que le faisceau (pose N : trois barres en travers,
    jamais un chapeau de cheminée) ; rosace éclairée en face avant (corps.bouche) ;
  - MOITIÉ SUD propre à l'époque : trémie noir mat flanquée de deux CAISSONS CARÉNÉS à nappes de câbles et antenne,
    RACKS À CASSETTES (à la place des caisses ouvertes), tourelle secondaire CARÉNÉE à radôme, BOÎTE DE JONCTION à
    goulottes de câbles au sud-est (à la place de la vanne et du volant : « moins de fluide, plus d'électricité ») ;
  - foyers BLEUS (famille 204 à 228° : la passe 3 mesurait 197°, cyan).
Inchangés de la passe 3 : grands volumes du socle (caissons carénés à l'ouest, à l'est et au nord-ouest), liaisons
(gaines lisses à colliers, faisceaux rouges et bleus), antenne-réseau radar au sommet, écrans, pièce paire (2 radômes
de conduite de tir).
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from corps import Y, at
from kit import SQ2, TAU, axv, basis

V = Vector

EPOQUE = 10
NOM = "Haute technologie"
FOYER = ages.FOYER[10]
CANON = dict(L=2.0, nb=6, rb=0.06, rr=0.145)
PLATEFORME = dict(chanfrein=1.15)
# passe 5, ronde 1 (consigne du DC du 23/10 : TOUT le bâtiment change d'un âge à l'autre) : l'âge de l'électronique
# est un bâtiment de CARÉNAGES BLANC CASSÉ et GRIS posé sur un pont de DALLES ANTHRACITE à liseré BLEU lumineux ;
# acier anthracite, rivets affleurants gris, bandes de danger blanc et bleu ; câbles rouges et bleus, voyants bleus.
HABILLAGE = dict(ages.CORPS[10],   # lot K0 : MATIÈRE du corps et du pont (capots, acier, rivets, joints,
                 # danger, peinture, plateforme) : commun/ages.py ; ici, les clés propres à la mitrailleuse
                 jupe_cerclage="bleu_tech", chapeau="acier_tech", tremie="gris_tech", tourelleau="gris_tech",
                 munitions=("steel_hi", "steel_dk"),
                 grille_nacelle="anthracite",
                 # passe 5, ronde 4 (10-11 noté 3 et 3 à la ronde 3, « silhouette presque identique ») : pont CARRÉ
                 # mince à pans courts et GARDE-CORPS (lisses bleu technique, poteaux et plinthe anthracite), muret au
                 # nord (11 : pont hexagonal et coque ; 12 : plateforme ronde et anneaux)
                 forme_plateforme=dict(forme="carre", flanc="bleu_tech", flanc2="anthracite"))
# passe 5, ronde 2 (test des écarts de la ronde 1 : 10 contre 11 noté 2 et 2, et 10 jugé PLUS évolué que 11 « par ses
# liserés bleus » ; 10 contre 12 noté 2 et 2, « liserés bleus devenus cyan ») : le pont n'a plus de liseré lumineux
# (la lumière continue est la marque des âges 11 et 12) ; les CARÉNAGES (matière « jacket » : caissons, cassettes,
# carénage des canons, tourelle secondaire) passent en CRÈME chaud peu métallique, les nappes de câbles en rouge et
# BLEU VIF plus larges : un bâtiment d'électronique crème et anthracite, chaud et coloré, mat, en deçà du titane.
RECV = ("matte", "jacket")


def matieres(metal, M):
    """Haute technologie : carénage gris clair patiné, noir mat, câbles rouges et bleus, écrans.
    Passe 5, ronde 1 : matières du corps entier (clés d'habillage) ; carénage blanc cassé, peu métallique (une grande
    masse claire reste sous 0,5 de métallicité)."""
    ages.matieres(10, metal, M)   # lot K0 : matières de l'âge, commun/ages.py (même ordre)
    # rôles de la mitrailleuse (alias), dans l'ordre d'origine
    M["ring"] = M["matte"]
    M["trim"] = M["jacket"]
    M["pipe2"] = M["steel_hi"]
    M["cable_a"] = M["cable_r"]
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 21 de l'industriel ; 10 : sans la paire de caisses du nord)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    # foyers de la colonne : fentes groupées (jamais de rangée continue)
    ng = 4
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    P2.grating(g, 1.35, 1.75, Y(-1.15), Y(1.3), 0.07, M)
    P2.grating(g, -1.55, -1.3, Y(-1.0), Y(-0.3), 0.07, M)
    # sud : racks à cassettes en biais (à la place des caisses ouvertes), tourelle secondaire carénée, trémie flanquée
    # de caissons carénés
    # passe 5, ronde 2 : le RADÔME de veille passe au coin SUD-OUEST (au nord, la tête le cachait en pose E) ; la
    # grande baie à cassettes prend sa place au nord
    radome(g, -1.55, Y(-1.74), r=0.36)
    with at(g, -1.05, -2.35, 0.08):
        cassette_rack(g, 0.62, 0.5, 0.34, 3)
    for (x, yn, rz) in [(1.78, -1.82, 0.0)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.42, 0.0, 0.28, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            mini_turret(g, (0, 0, 0.28), 0.95, rz)
    tremie_pods(g, c)
    # ouest : groupe sous carénage ; liaisons d'énergie vers la colonne
    west(g)
    conduit(g, [(-1.62, Y(0.55), 0.4), (-1.42, Y(0.6), 0.62), (-1.2, Y(0.5), 0.72)], 0.045)
    cables(g, [(-1.62, Y(-0.25), 0.4), (-1.42, Y(-0.3), 0.6), (-1.18, Y(-0.35), 0.68)])
    # nord-ouest : caisson caréné posé en biais
    with at(g, -1.72, 2.02, -0.55):
        faired_box(g, -0.42, 0.42, -0.32, 0.32, 0.4, louvers=0, cables=False)
    # est : caisson caréné (à la place des réservoirs)
    faired_box(g, 1.74, 2.36, Y(-0.6), Y(1.15), 0.74, louvers=0)
    # sud-ouest : armoire de commande
    P3.cabinet(g, -2.45, -2.02, -2.3, -1.66, 0.0, 0.5, M, E, screen_=True)
    # sud-est : boîte de jonction à goulottes de câbles (moins de fluide, plus d'électricité)
    junction_box(g, 1.68, 2.36, Y(-1.18), Y(-0.85), 0.36)
    cable_tray(g, [(1.68, Y(-1.0), 0.3), (1.45, Y(-1.05), 0.34), (1.22, Y(-0.85), 0.5)])
    hose(g, [(1.7, Y(1.05), 0.62), (1.45, Y(0.95), 0.98), (1.15, Y(0.75), 0.82)], 0.06)
    # nord-est : armoire de commande ; nord : caisse de réserve
    P3.cabinet(g, 1.25, 2.25, Y(1.95), Y(2.42), 0.0, 0.56, M, E, screen_=True)
    signature(g, (1.55, Y(2.18), 0.6))
    # passe 5, ronde 1 : SILHOUETTE de l'âge, un RADÔME sphérique blanc sur pylône (à la place de la caisse du nord)
    with at(g, 0.32, 1.92, 0.0):
        cassette_rack(g, 0.8, 0.72, 0.42, 4)
    signature(g, (-2.24, -1.98, 0.53), 2)
    for x in (-0.68, 0.68):
        PT.lamp(g, (x, Y(-2.4) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    _halo(g, [(-2.0, Y(-1.1), 0.5), (1.78, Y(-2.1), 0.6), (0.0, Y(-2.5), 0.5), (2.0, Y(0.3), 0.5),
              (1.75, Y(1.8), 0.5)], 20.0)


def radome(g, x, y, r=0.32):
    """Radôme de veille (passe 5, ronde 1 : superstructure de l'âge électronique, qui change le contour) : embase
    carénée, pylône à 4 jambes de force, sphère de carénage blanc cassé à cerclages et méridiens, feu bleu au sommet.
    Sommet à 1,2 (sous h_max 1,29 de la taille 5 : les canons passent au-dessus)."""
    M = g.M
    E = M["emit"]
    g.cyl((x, y, 0.07), "z", 0.3, 0.14, M["ochre"], n=28, what="embase")
    g.torus((x, y, 0.14), "z", 0.29, 0.014, M["steel_dk"], n=28, m=6, what="bourrelet")
    g.cyl((x, y, 0.36), "z", 0.075, 0.44 + (0.32 - r), M["steel_dk"], n=16, what="pylone")
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        d = V((math.cos(a), math.sin(a), 0))
        P2.wedge(g, V((x, y, 0.14)) + d * 0.26, V((x, y, 0.14)) + d * 0.07, V((x, y, 0.5)) + d * 0.07,
                 V((-d.y, d.x, 0)) * 0.03, M["steel_dk"], what="jambe")
    zc = 1.2 - r - 0.03
    g.sphere((x, y, zc), r, M["olive"], n=32, m=16, what="radome")
    for zz, rr in ((zc, r), (zc + r * 0.5, r * 0.866), (zc - r * 0.5, r * 0.866)):
        g.torus((x, y, zz), "z", rr + 0.002, 0.008, M["steel_dk"], n=32, m=6, what="cerclage")
    for ax in ("x", "y"):
        g.torus((x, y, zc), ax, r + 0.002, 0.007, M["steel_dk"], n=32, m=6, what="meridien")
    g.sphere((x, y, zc + r + 0.02), 0.028, E, n=10, m=6, what="feu")
    for k in range(3):   # voyants bleus sur la face sud de l'embase
        dx = -0.12 + 0.12 * k
        g.box((x + dx, y - math.sqrt(0.09 - dx * dx) + 0.002, 0.08), (0.05, 0.012, 0.025), E, "flat",
              what="voyant")
    _halo(g, [(x, y, zc + r + 0.05)], 6.0)


def west(g):
    """Groupe de l'ouest : caisson caréné (même emprise que le groupe électrogène de la lignée), antenne-fouet."""
    M = g.M
    x0, x1, y0, y1, h = -2.42, -1.62, Y(-0.95), Y(1.25), 0.52
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    faired_box(g, x0 + 0.02, x1 - 0.02, y0, y1, h + 0.08, louvers=0, cables=True)
    # antenne-fouet et boîtier sur le toit (fine, hors masse)
    g.box((cx - 0.15, y1 - 0.3, h + 0.13), (0.14, 0.12, 0.08), M["matte"], "hard", what="boitier")
    g.cyl((cx - 0.15, y1 - 0.3, h + 0.4), "z", 0.006, 0.46, M["steel_dk"], n=6, what="antenne")


def faired_box(g, x0, x1, y0, y1, h, louvers=3, cables=True):
    M = g.M
    E = M["emit"]
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
    c = min(hx, hy) * 0.3
    F.plinth(g, x0 - 0.04, x1 + 0.04, y0 - 0.04, y1 + 0.04, 0.08)
    F.loft_z(g, cx, cy, [(0.08, F.octz(hx, hy, c)), (h * 0.72, F.octz(hx, hy, c)), (h, F.octz(hx - 0.1, hy - 0.1, c))],
           M["jacket"], "soft", "carenage")
    # joints de panneaux verticaux (noir mat) sur les faces sud et ouest/est
    nseg = max(2, int((y1 - y0) / 0.55))
    for i in range(1, nseg):
        yy = y0 + (y1 - y0) * i / nseg
        for s in (-1, 1):
            g.box((cx + s * (hx + 0.002), yy, h * 0.4), (0.01, 0.02, h * 0.6), M["matte"], "flat", what="joint")
        g.box((cx, yy, h + 0.003), (2 * (hx - 0.12), 0.02, 0.008), M["matte"], "flat", what="joint")
    # grilles d'aération sur le toit (cadre noir, lames)
    for i in range(louvers):
        yy = y0 + (y1 - y0) * (i + 0.5) / louvers
        q = [V((cx - hx * 0.5, yy - 0.12, h + 0.004)), V((cx + hx * 0.2, yy - 0.12, h + 0.004)),
             V((cx + hx * 0.2, yy + 0.12, h + 0.004)), V((cx - hx * 0.5, yy + 0.12, h + 0.004))]
        g.grille(q, 6, depth=0.02, slat_mat=M["steel_dk"])
        for (u, v) in ((-0.5, -0.12), (0.2, -0.12), (0.2, 0.12), (-0.5, 0.12)):
            g.dome((cx + hx * u, yy + v * 1.15, h + 0.01), (0, 0, 1), 0.012, M["rivet"])
    # passe 5, ronde 1 (juges de la passe 4 : « deux grands caissons gris clair plats ») : CARÉNAGE À FENTES, fentes
    # de ventilation longitudinales noires en 2 colonnes sur le toit (pas de trous ronds, catalogue §B époque 10), et
    # voyants bleus PAR PAIRES aux extrémités des fentes
    nf = max(2, int((y1 - y0 - 0.3) / 0.36))
    for col_ in (-0.12, 0.18):
        for i in range(nf):
            ya_ = y0 + 0.15 + (y1 - y0 - 0.3) * i / nf
            yb_ = y0 + 0.15 + (y1 - y0 - 0.3) * (i + 1) / nf - 0.07
            for j in range(3):
                g.box((cx + hx * col_ + (j - 1) * 0.045, (ya_ + yb_) / 2, h + 0.005), (0.022, yb_ - ya_, 0.006),
                      M["void"], "flat", what="fente")
            if i % 2 == 0:
                for j in range(2):
                    g.box((cx + hx * col_ + (j - 0.5) * 0.05, yb_ + 0.035, h + 0.006), (0.03, 0.022, 0.006), E,
                          "flat", what="voyant")
    # nappes de câbles rouges et bleus dans une goulotte sur le toit, côté est (passe 5 : nappes plus larges, lisibles
    # au zoom 1)
    if cables:
        g.box((cx + hx * 0.6, cy, h + 0.02), (0.26, 2 * hy * 0.92, 0.03), M["matte"], "hard", what="goulotte")
        F.ribbon(g, [(cx + hx * 0.5, y0 + 0.1, h + 0.04), (cx + hx * 0.5, y1 - 0.1, h + 0.04)], 0.1, M["cable_a"])
        F.ribbon(g, [(cx + hx * 0.7, y0 + 0.1, h + 0.041), (cx + hx * 0.7, y1 - 0.1, h + 0.041)], 0.09, M["cable_b"])
    # voyants par groupes, petit écran, face sud
    P3.lamp_group(g, (cx - hx * 0.6, y0 - 0.005, h * 0.55), (1, 0, 0), (0, -1, 0), E, M, n=3)
    P3.screen(g, (cx + hx * 0.35, y0 - 0.005, h * 0.5), (0, -1, 0), 0.14, 0.08, M, E)
    return (cx, cy, h)


def radar_array(g, c, w, hgt, tilt=0.4):
    """Antenne-réseau de radar sur mât (cadre, lattes, treillis arrière), tournée vers l'avant (+y)."""
    M = g.M
    E = M["emit"]
    g.cyl(V(c) + V((0, 0, 0.1)), "z", 0.06, 0.2, M["matte"], n=16, what="mat")
    g.cyl(V(c) + V((0, 0, 0.02)), "z", 0.12, 0.05, M["steel_dk"], n=24, what="pivot")
    g.push(V(c) + V((0, 0, 0.2 + hgt / 2)), rx=tilt)
    g.box((0, 0, 0), (w, 0.05, hgt), M["jacket"], "hard", what="reseau")
    g.box((0, -0.035, 0), (w + 0.04, 0.02, hgt + 0.04), M["matte"], "hard", what="cadre")
    n = int(w / 0.09)
    for i in range(n):
        xx = -w / 2 + w * (i + 0.5) / n
        g.box((xx, 0.03, 0), (0.016, 0.02, hgt * 0.92), M["steel_dk"], "hard", what="latte")
    for zz in (-hgt * 0.3, hgt * 0.3):
        g.box((0, -0.06, zz), (w * 0.9, 0.03, 0.03), M["steel_dk"], "hard", what="treillis")
    g.box((-w * 0.4, 0.045, hgt * 0.38), (0.03, 0.006, 0.02), E, "flat", what="voyant")
    g.box((w * 0.33, 0.045, -hgt * 0.38), (0.03, 0.006, 0.02), E, "flat", what="voyant")
    g.pop()


def signature(g, p, kind=0):
    """Petite pièce de signature posée sur un toit de machine : antenne fouet courte sur embase, boîtier."""
    M = g.M
    p = V(p)
    g.box(p + V((0, 0, 0.03)), (0.12, 0.1, 0.06), M["matte"], "hard", what="boitier")
    g.cyl(p + V((-0.04, 0.03, 0.07)), "z", 0.018, 0.04, M["steel_hi"], n=8, what="embase")
    g.cyl(p + V((-0.04, 0.03, 0.18)), "z", 0.006, 0.2, M["steel_dk"], n=6, what="antenne")
    g.cyl(p + V((-0.03, 0, 0.065)), "z", 0.012, 0.012, M["emit"], n=8, style="flat", what="voyant")


def mini_turret(g, c, s, rz):
    """Tourelle secondaire HAUTE TECHNOLOGIE : couronne rivetée de la lignée, caisson CARÉNÉ gris clair à pans coupés
    (joints noir mat, fentes), RADÔME de visée sur le dos, antenne fouet ; les DEUX ARMES sont celles de l'époque."""
    M = g.M
    E = M["emit"]
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["armor2"], n=32, style="soft", what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    oc = F.octz(0.25 * s, 0.29 * s, 0.09 * s)
    F.loft_z(g, 0.0, -0.03 * s, [(0.1 * s, oc), (0.3 * s, oc), (0.42 * s, F.scale_poly(oc, 0.72))], M["jacket"],
             "soft", "carenage")
    for zz in (0.2 * s, 0.31 * s):
        F.prism(g, [(u, w - 0.03 * s) for u, w in F.scale_poly(oc, 1.03)], zz - 0.008, zz + 0.008, M["matte"],
                what="joint")
    for sxx in (-1, 1):
        g.box((sxx * 0.252 * s, -0.03 * s, 0.25 * s), (0.006, 0.3 * s, 0.025), M["void"], "flat", what="fente")
    g.cyl((0.0, -0.1 * s, 0.43 * s), "z", 0.1 * s, 0.03, M["matte"], n=20, what="embase")
    g.sphere((0.0, -0.1 * s, 0.46 * s), 0.11 * s, M["jacket"], n=24, m=12, scale=(1, 1, 0.8), what="radome")
    g.torus((0.0, -0.1 * s, 0.46 * s), "z", 0.11 * s, 0.008, M["matte"], n=24, m=6, what="joint")
    g.cyl((0.12 * s, -0.2 * s, 0.6 * s), "z", 0.005, 0.36 * s, M["steel_dk"], n=6, what="antenne")
    for sx in (-1, 1):
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=[M[k] for k in RECV])
        _canon10(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    PT.lamp(g, (0.0, 0.14 * s, 0.4 * s + 0.01), (0, 0.35, 1), 0.035, E, cage=False)
    g.pop()


def cassette_rack(g, w, d, h, n):
    """RACK À CASSETTES (à la place de la caisse ouverte) : socle noir mat riveté, n cassettes gris clair enfichées,
    poignées, étiquettes, voyants par groupes, nappe de câbles rouge et bleue sur le dos."""
    M = g.M
    E = M["emit"]
    zb = h * 0.42
    PT.hull(g, -w / 2, w / 2, -d / 2, d / 2, 0.0, zb, ins=(0.02, 0.02, 0.02), panel=0.24,
            mats=[M["matte"], M["steel_dk"]], rivet_step=0.12)
    pitch = (w - 0.08) / n
    for i in range(n):
        x = -w / 2 + 0.04 + pitch * (i + 0.5)
        hc = h * (0.95 if i % 2 else 0.82)
        g.box((x, -d * 0.04, zb + (hc - zb) / 2 + 0.01), (pitch * 0.78, d * 0.8, hc - zb), M["jacket"], "soft",
              what="cassette")
        g.box((x, -d * 0.44 - 0.004, zb + (hc - zb) * 0.7), (pitch * 0.5, 0.012, 0.03), M["matte"], "hard",
              what="poignee")
        g.box((x, -d * 0.04, hc + 0.013), (pitch * 0.5, d * 0.5, 0.006), M["matte"], "flat", what="etiquette")
        g.box((x + pitch * 0.22, -d * 0.3, hc + 0.014), (0.03, 0.03, 0.006), E if i % 3 else M["amber"], "flat",
              what="voyant")
    F.ribbon(g, [(-w / 2 + 0.05, d * 0.42, zb + 0.02), (0.0, d * 0.46, zb + 0.06), (w / 2 - 0.05, d * 0.42, zb + 0.02)],
             0.05, M["cable_a"])
    F.ribbon(g, [(-w / 2 + 0.05, d * 0.36, zb + 0.022), (0.0, d * 0.38, zb + 0.07), (w / 2 - 0.05, d * 0.36, zb + 0.022)],
             0.04, M["cable_b"])
    P3.lamp_group(g, (-w / 2 + 0.06, -d / 2 - 0.02, zb * 0.5), (1, 0, 0), (0, -1, 0), E, M, n=2,
                  shapes=("fente", "rond"))


def tremie_pods(g, c):
    """Trémie de l'époque : flanquée à l'est et à l'ouest de deux CAISSONS CARÉNÉS gris clair (pans coupés, grilles
    d'aération, joints noir mat) qui portent les nappes de câbles vers la colonne, antenne et écran."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = c.tremie_box
    for s in (-1, 1):
        xa = x1 + 0.02 if s > 0 else x0 - 0.3
        xb = xa + 0.28
        cx, cy = (xa + xb) / 2, (y0 + y1) / 2 + 0.05
        hx, hy = 0.14, (y1 - y0) * 0.44
        oc = F.octz(hx, hy, 0.06)
        F.plinth(g, xa - 0.02, xb + 0.02, cy - hy - 0.02, cy + hy + 0.02, 0.06)
        F.loft_z(g, cx, cy, [(0.06, oc), (h * 0.68, oc), (h * 0.82, F.scale_poly(oc, 0.8))], M["jacket"], "soft",
                 "carenage")
        for f in (0.33, 0.66):
            yy = cy - hy + 2 * hy * f
            g.box((cx, yy, h * 0.82 + 0.004), (hx * 1.4, 0.02, 0.008), M["matte"], "flat", what="joint")
            g.box((cx + s * (hx + 0.002), yy, h * 0.4), (0.01, 0.02, h * 0.5), M["matte"], "flat", what="joint")
        q = [V((cx - hx * 0.55, cy - hy * 0.7, h * 0.82 + 0.006)), V((cx + hx * 0.55, cy - hy * 0.7, h * 0.82 + 0.006)),
             V((cx + hx * 0.55, cy - hy * 0.2, h * 0.82 + 0.006)), V((cx - hx * 0.55, cy - hy * 0.2, h * 0.82 + 0.006))]
        g.grille(q, 5, depth=0.018, slat_mat=M["steel_dk"])
        P3.lamp_group(g, (cx - hx * 0.6, cy - hy - 0.004, h * 0.5), (1, 0, 0), (0, -1, 0), E, M, n=2,
                      shapes=("rond", "carre"))
        # nappe de câbles du caisson vers la couronne de la colonne
        F.ribbon(g, [(cx, cy + hy * 0.5, h * 0.84), (cx - s * 0.1, y1 + 0.25, h * 0.95),
                     (s * 0.35, y1 + 0.55, c.rt + 0.06)], 0.06, M["cable_a"] if s > 0 else M["cable_b"])
    xs = x1 + 0.16
    g.cyl((xs, y0 + 0.2, h * 0.82 + 0.25), "z", 0.006, 0.5, M["steel_dk"], n=6, what="antenne")
    g.cyl((xs, y0 + 0.2, h * 0.82 + 0.02), "z", 0.02, 0.04, M["steel_hi"], n=8, what="embase")
    P3.screen(g, (x0 - 0.16, y0 + 0.1, h * 0.84), (0, 0, 1), 0.12, 0.08, M, E)


def junction_box(g, x0, x1, y0, y1, h):
    """Boîte de jonction (sud-est) : caisson noir mat et gris clair, bornier à presse-étoupes, petit écran, voyants."""
    M = g.M
    E = M["emit"]
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.22, mats=[M["matte"], M["jacket"]],
            rivet_step=0.12)
    w = x1 - x0
    for i in range(5):
        x = x0 + 0.08 + (w - 0.16) * i / 4
        g.cyl((x, y0 - 0.02, h * 0.35), "y", 0.022, 0.05, M["steel_hi"], n=10, what="presse_etoupe")
        g.cyl((x, y0 - 0.05, h * 0.35), "y", 0.014, 0.04, M["cable_a"] if i % 2 else M["cable_b"], n=8,
              what="cable")
    P3.screen(g, (x0 + w * 0.3, y0 - 0.01, h * 0.72), (0, -1, 0), 0.12, 0.07, M, E)
    P3.lamp_group(g, (x0 + w * 0.62, y0 - 0.02, h * 0.74), (1, 0, 0), (0, -1, 0), E, M, n=3)


def cable_tray(g, ctrl):
    """Goulotte à câbles noir mat portant deux nappes plates rouge et bleue."""
    M = g.M
    P = g.resample(g.spline(ctrl, 12), 0.05)
    T, _ = g.frames(P)
    for i, p in enumerate(P):
        side = T[i].cross(V((0, 0, 1)))
        if side.length < 1e-3:
            side = V((1, 0, 0))
        side.normalize()
        up = side.cross(T[i]).normalized()
        g.box(p, (0.16, 0.052, 0.02), M["matte"], "flat", R=Matrix((side, T[i], up)).transposed(), what="goulotte")
        if i % 4 == 0:
            for s in (-1, 1):
                g.box(p + side * s * 0.08 + up * 0.02, (0.012, 0.03, 0.04), M["steel_dk"], "hard",
                      R=Matrix((side, T[i], up)).transposed(), what="rebord")
    F.ribbon(g, [V(q) + V((0, 0, 0.014)) for q in ctrl], 0.06, M["cable_a"])
    F.ribbon(g, [V(q) + V((0.0, 0.0, 0.02)) for q in ctrl], 0.04, M["cable_b"])


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : gaines lisses à colliers, faisceaux de câbles rouges et bleus, conduits à bagues lumineuses
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    """Gaine lisse à colliers clairs, faisceau de câbles rouge et bleu posé dessus."""
    M = g.M
    P, T = g.tube(g.spline(ctrl, 10), r * 0.85, M["pipe"], n=12, what="gaine")
    for i in range(2, len(P) - 1, 5):
        g.cyl(P[i], T[i], r * 0.85 + 0.014, 0.03, M["steel_hi"], n=12, style="hard", what="collier")
    PT.cable_run(g, [V(p) + V((0, 0, r + 0.03)) for p in ctrl], 2, 0.016, 0.04, [M["cable_a"], M["cable_b"]])


def cables(g, ctrl, n=3):
    """Faisceau de 4 câbles rouges et bleus."""
    M = g.M
    mats = [M["cable_a"], M["cable_b"], M["cable_a"], M["cable_b"]]
    PT.cable_run(g, ctrl, 4, 0.026, 0.055, mats)


def conduit(g, ctrl, r):
    """Conduit d'énergie : bagues lumineuses PAR GROUPES (chenillard), colliers en matière d'époque."""
    M = g.M
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["steel_dk"], n=10, what="conduit")
    R = g.resample(P, 0.075)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 4 in (1, 2):
            g.tube_shell(R[i], T2[i], r + 0.008, r * 0.5, 0.03, M["emit"], n=12, what="bague_lum")
        elif i % 4 == 3:
            g.tube_shell(R[i], T2[i], r + 0.016, r * 0.5, 0.03, M["pipe2"], n=12, what="collier")


def pipe(g, ctrl, r, valve_at=None):
    M = g.M
    g.pipe(ctrl, r, M["pipe"], fl_mat=M["pipe2"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 20 : 2 radômes de conduite de tir sur affût blindé
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.5, Y(-2.64), sx)
    _halo(g, [(-1.5, Y(-2.9), 0.4), (1.5, Y(-2.9), 0.4)], 16.0)


def even_piece(g, x, yb, sx):
    """Une des deux pièces paires, posée en (x, yb Blender) au sol, côté sx : RADÔME de conduite de tir sur affût
    blindé (embase à armoire), antenne courte."""
    M = g.M
    E = M["emit"]
    # plinthe commune : caisson blindé bas à bande de danger (toujours posé sur le tablier)
    w, d = 0.62, 0.6
    PT.hull(g, x - w / 2, x + w / 2, yb - d / 2, yb + d / 2, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["steel_dk"]], rivet_step=0.12)
    g.hazard([V((x - w / 2, yb - d / 2 - 0.02, 0.02)), V((x + w / 2, yb - d / 2 - 0.02, 0.02)),
              V((x + w / 2, yb - d / 2 - 0.02, 0.12)), V((x - w / 2, yb - d / 2 - 0.02, 0.12))], 6, t=0.012, skew=0.6)
    z0 = 0.14
    P3.lamp_group(g, (x - w / 2 + 0.06, yb - d / 2 - 0.025, 0.07), (1, 0, 0), (0, -1, 0), E, M, n=2,
                  shapes=("rond", "fente"))
    PT.hull(g, x - 0.22, x + 0.22, yb - 0.24, yb + 0.2, z0, z0 + 0.26, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["olive"], M["matte"]], rivet_step=0.11)
    P3.lamp_group(g, (x - 0.12, yb - 0.26, z0 + 0.18), (1, 0, 0), (0, -1, 0), E, M, n=3)
    g.cyl((x, yb, z0 + 0.3), "z", 0.19, 0.06, M["steel_dk"], n=28, style="soft", what="embase")
    g.sphere((x, yb, z0 + 0.33), 0.2, M["jacket"], n=32, m=16, scale=(1, 1, 0.92))
    for zz in (0.33, 0.43):
        rr = 0.2 * math.cos(math.asin(min(0.95, (zz - 0.33) / 0.184)))
        g.torus((x, yb, z0 + zz), "z", rr + 0.004, 0.012, M["matte"], n=32, m=6, what="joint")
    g.cyl((x + 0.08, yb + 0.06, z0 + 0.62), "z", 0.006, 0.22, M["steel_dk"], n=6, what="antenne")
    g.cyl((x - 0.1, yb - 0.1, z0 + 0.48), "z", 0.014, 0.012, E, n=8, style="flat", what="voyant")


# ------------------------------------------------------------------------------------------------
# Arme (E1) : nacelle carénée fermée
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    capteur optique, alimentation, voyants d'état, capot de culasse."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _canon10(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    # capteur optique sur le masque de canon
    cc = V((x + wr * 0.45, y1 + 0.02, zg + hr * 1.35 + 0.06))
    g.box(cc, (0.12, 0.12, 0.1), M["matte"], "hard", what="capteur")
    g.cyl(cc + V((0, 0.07, 0.0)), "y", 0.035, 0.03, M["steel_hi"], n=14, what="capteur_bague")
    g.cyl(cc + V((0, 0.088, 0.0)), "y", 0.025, 0.006, M["emit"], n=12, style="flat", what="lentille")
    g.box(cc + V((0, -0.02, 0.06)), (0.08, 0.06, 0.02), M["jacket"], "hard", what="visiere")
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    # voyants d'état sur la culasse : 2 segments courts (pas de bande continue)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # capot noir mat à petit écran et nappe de câbles
    zt = zg + hr + 0.012
    g.box((x, (y0 + y1) / 2 + 0.05, zt + 0.03), (wr * 0.6, (y1 - y0) * 0.36, 0.04), M["matte"], "hard", what="capot")
    P3.screen(g, (x, (y0 + y1) / 2 + 0.05, zt + 0.052), (0, 0, 1), wr * 0.4, 0.07, M, M["emit"])


def _canon10(g, x, y0, z, L, nb, rb, rr):
    """Quatrième passe (règle d'or 1) : la ROSETTE de la lignée (6 tubes séparés, âme pleine, colliers noir mat) se
    voit sur toute la moitié avant ; le CARÉNAGE gris clair à pans coupés n'enveloppe que la moitié arrière (0,46 L) :
    fentes de ventilation longitudinales à lèvres, joints noir mat, rivets fins, nappe de câbles rouge et bleue dans une
    goulotte, radôme de visée et antenne fouet sur le dos. Frein à 3 DÉFLECTEURS gris clair plus larges que le carénage
    (de dessus en pose N : trois barres en travers, un « T » multiple, jamais un chapeau rond) ; rosace éclairée en
    face avant. De dessus : un pavé clair à fentes, puis les 6 tubes et leurs colliers, puis les déflecteurs."""
    M = g.M
    E = M["emit"]
    k = F.k_arme(rb, rr)
    R0 = rr + rb
    # passe 5, ronde 3 (pose N de la ronde 2 : 10 encore lu « cheminée », colliers noirs à 0,6 et 0,82 L = viroles
    # d'un conduit) : CANON EFFILÉ du kit (faisceau qui converge, un seul manchon à fentes reculé, dernier cinquième
    # nu à pointes éclairées) ; le carénage à fentes de l'époque garde la moitié arrière
    corps.canon_effile(g, x, y0, z, L, nb, rb, rr, jaquette=0.0, bague_mat="matte")
    # carénage partiel (moitié arrière au plus : corps.JAQUETTE_MAX)
    Lc = L * min(0.46, corps.JAQUETTE_MAX)
    hw, hh, c = R0 + 0.075 * k, R0 + 0.05 * k, 0.08 * k
    sec = F.oct8(hw, hh, c)
    F.loft(g, x, z, [(y0 - 0.02, F.scale_poly(sec, 0.92)), (y0 + 0.06 * k, sec), (y0 + Lc - 0.12 * k, sec),
                   (y0 + Lc, F.scale_poly(sec, 0.82))], M["jacket"], "soft", "carenage")
    if k >= 0.9:
        F.prism_y(g, x, z, y0 + Lc * 0.48 - 0.012, y0 + Lc * 0.48 + 0.012, F.scale_poly(sec, 1.02), M["matte"],
                  what="joint")
        for i, (a, b) in enumerate(((0.08, 0.42), (0.54, 0.86))):
            ya, yb = y0 + a * Lc, y0 + b * Lc
            ym, ly = (ya + yb) / 2, yb - ya
            for u in (-hw * 0.48, hw * 0.48):
                g.box((x + u, ym, z + hh + 0.002), (0.028 * k, ly, 0.006), M["void"], "flat", what="fente")
                g.box((x + u + 0.022 * k, ym, z + hh + 0.006), (0.01, ly, 0.01), M["steel_hi"], "hard", what="levre")
            for s in (-1, 1):
                g.box((x + s * (hw + 0.002), ym, z + hh * 0.2), (0.006, ly, 0.03 * k), M["void"], "flat",
                      what="fente")
            for yy in (ya - 0.02, yb + 0.02):
                for u in (-hw + c + 0.03, hw - c - 0.03):
                    g.dome((x + u, yy, z + hh), (0, 0, 1), 0.012, M["rivet"])
        # dos : nappe de câbles rouges et bleus dans une goulotte noire, radôme de visée, antenne fouet
        g.box((x, y0 + Lc * 0.45, z + hh + 0.02), (0.1 * k, Lc * 0.8, 0.03), M["matte"], "hard", what="goulotte")
        g.box((x - 0.02 * k, y0 + Lc * 0.45, z + hh + 0.038), (0.035 * k, Lc * 0.76, 0.01), M["cable_a"], "soft",
              what="nappe")
        g.box((x + 0.022 * k, y0 + Lc * 0.45, z + hh + 0.039), (0.03 * k, Lc * 0.76, 0.01), M["cable_b"], "soft",
              what="nappe")
        yr = y0 + Lc * 0.78
        g.cyl((x - hw * 0.5, yr, z + hh + 0.03), "z", 0.07 * k, 0.05, M["matte"], n=20, what="embase")
        g.sphere((x - hw * 0.5, yr, z + hh + 0.06), 0.08 * k, M["jacket"], n=24, m=12, scale=(1, 1, 0.8), what="radome")
        g.torus((x - hw * 0.5, yr, z + hh + 0.06), "z", 0.08 * k, 0.008, M["matte"], n=24, m=6, what="joint")
        g.cyl((x + hw * 0.55, y0 + Lc * 0.25, z + hh + 0.2), "z", 0.006, 0.36, M["steel_dk"], n=6, what="antenne")
        g.cyl((x + hw * 0.55, y0 + Lc * 0.25, z + hh + 0.025), "z", 0.02, 0.04, M["steel_hi"], n=8, what="embase")
        for s in (-1, 1):
            g.box((x + s * hw * 0.55, y0 + Lc + 0.004, z + hh * 0.45), (0.04, 0.008, 0.025), E, "flat",
                  what="voyant")
    # passe 5, ronde 2 (pose N de la ronde 1 : 10 lu « cheminée ») : le frein à 3 DÉFLECTEURS plus larges que le
    # faisceau est retiré. Ronde 3 : la couronne de bouche aussi (le canon effilé finit sur ses pointes éclairées)
    return y0 + L


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) noir mat et gris, chargeurs à CASSETTES rectangulaires et
    NAPPES de câbles rouges et bleues, voyants."""
    M = g.M
    E = M["emit"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    y0, y1 = H["recv"]
    bw, bl, bh = 0.32 * wr / 0.4, 0.75 * H["L"] / 1.95, 0.5 * hr / 0.23
    bl = min(bl, 0.95)
    bx0, bx1 = sorted((xo + sx * 0.02, xo + sx * (0.02 + bw)))
    bc = (bx0 + bx1) / 2
    yb0, yb1 = y0 - 0.1, y0 - 0.1 + bl
    zb0, zb1 = zg - bh * 0.62, zg + bh * 0.42
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["matte"], M["jacket"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    for k in range(3):
        yy = yb0 + bl * (0.3 + 0.2 * k)
        g.box((bc, yy, ztop + 0.05), (bw * 0.8, bl * 0.15, 0.1), M["jacket"], "hard", what="cassette")
        g.box((bc + sx * bw * 0.28, yy, ztop + 0.102), (0.05, bl * 0.08, 0.006), E if k != 1 else M["amber"],
              "flat", what="voyant")
        g.box((bc - sx * bw * 0.1, yy, ztop + 0.101), (bw * 0.3, bl * 0.1, 0.004), M["matte"], "flat",
              what="etiquette")
    F.ribbon(g, [(bc - sx * 0.04, yb0 + bl * 0.85, ztop + 0.09), (bc - sx * 0.1, y0 + bl * 0.75, zg + bh * 0.7),
                 (x + sx * wr * 0.25, y0 + bl * 0.62, zg + hr + 0.05)], 0.06, M["cable_a"])
    F.ribbon(g, [(bc + sx * 0.02, yb0 + bl * 0.85, ztop + 0.1), (bc - sx * 0.04, y0 + bl * 0.8, zg + bh * 0.75),
                 (x + sx * wr * 0.32, y0 + bl * 0.68, zg + hr + 0.06)], 0.05, M["cable_b"])
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=2, shapes=("rond", "carre", "fente"))
    return bc


# ------------------------------------------------------------------------------------------------
# Masque et tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=("ochre", "olive"), fentes=((-0.42, 0.34), (0.42, 0.22)), visiere=("steel_hi", 0.13),
                        coax=dict(fut="steel_dk", manchon="ring", manchon_y=0.28, manchon_r=0.045, manchon_L=0.16))


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    z0 = c.rt
    F.slits_grouped(g, R, z0 + 0.2, 4, M["emit"])
    for sx in (-1, 1):
        # liaisons nacelle -> bras de tourillon : elles passent SUR la coupole et finissent SUR le bras
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
    # plaques rapportées (blindage) : 1re rangée qui se complète (catalogue §A.5)
    row1 = (0.6, 1.2, math.pi - 0.6, math.pi - 1.2)
    ph1, w1, h1 = (0.32, 0.28, 0.22)
    for i, th in enumerate(row1):
        mat = M["trim"] if i % 3 == 1 else (M["ochre"] if i % 2 else M["steel_dk"])
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    # radôme de visée sur le tourelleau, antennes fouet courtes, petit écran sur la nacelle
    for (ax, ay) in ((-0.5, -0.3), (0.55, -0.55)):
        g.cyl((ax * R, ay * R, H["zs"] + H["rz"] * 0.65), "z", 0.02, 0.05, M["steel_hi"], n=8, what="embase")
        g.cyl((ax * R, ay * R, H["zs"] + H["rz"] * 0.65 + 0.2), "z", 0.006, 0.36, M["steel_dk"], n=6,
              what="antenne")
    bx, yb0, yb1 = c.nac[:3]
    P3.screen(g, (bx * 0.5, (yb0 + yb1) / 2, H["zs"] + H["rz"] * 0.42 + 0.03), (0, 0, 1), 0.14, 0.09, M, M["emit"])
    P3.lamp_group(g, (-bx * 0.6, (yb0 + yb1) / 2 - 0.05, H["zs"] + H["rz"] * 0.42 + 0.005), (1, 0, 0), (0, 0, 1),
                  M["emit"], M, n=3)
    # sommet de la tête : antenne-réseau de radar sur le tourelleau
    radar_array(g, c.tour, 1.25, 0.46, tilt=0.95)
    PT.sight(g, (-R * 0.6, R * 0.32, H["zs"] + H["rz"] * 0.5), 0.2, 0.2, 0.12, M["emit"], lenses=2)

# ------------------------------------------------------------------------------------------------
# Passe 5, ronde 1 (consigne du Directeur Créatif du 23/10 : d'un âge à l'autre, TOUT le bâtiment change, comme deux
# évolutions d'une défense de Clash of Clans) : ce que l'époque dessine (socle, pièce paire, arme, tête, masque) est
# posé dans la palette HABILLÉE de la lignée (corps.habille, réentrant) ; les organes d'époque qui lisent l'olive,
# l'ocre, l'acier sombre ou les rivets prennent ainsi la matière de l'âge, comme le corps. Les tubes (M["gun"]) et les
# matières propres de l'époque ne changent pas.
# ------------------------------------------------------------------------------------------------
def _dans_habillage(f):
    def w(g, c, *a, **k):
        with corps.habille(g, c):
            return f(g, c, *a, **k)
    w.__name__, w.__doc__ = f.__name__, f.__doc__
    return w


socle, piece, arme, tete, masque = [_dans_habillage(_f) for _f in (socle, piece, arme, tete, masque)]
