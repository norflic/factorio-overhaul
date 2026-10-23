"""Époque 11 · Titane (ère IV, 5×5, niveaux 21 et 22). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 11) : « ailerons, effilé, titane ».
Quatrième passe (23/10), corrections du constructeur de la plage haute sur le portage de la passe 3 (lu « industrie
lourde blindée », pose N lue comme des cheminées) :
  - ALLIAGE CLAIR PATINÉ en accents LARGES : manchon arrière des canons, ailerons, colliers, dérives (matière « ring »
    éclaircie, toujours patinée, luminance rendue <= 200) ; le titane (« jacket ») reste moyen ;
  - ARME : canon LONG et EFFILÉ (faisceau de 6 tubes fins, 1,25 L), manchon arrière à pans (<= moitié arrière),
    QUATRE AILERONS RADIAUX en X (diagonales, 0,5 t d'envergure : lisibles au zoom 1 de dessus comme de face), frein
    en POINTE DE FLÈCHE à deux grandes ailettes horizontales en flèche (pose N : une pointe de flèche plus large que le
    faisceau, jamais un chapeau rond) ;
  - SOCLE : la turbine lourde de l'ouest devient un BANC DE MISSILES (3 missiles effilés couchés sur berceaux, nez en
    ogive, empennages clairs) ; moitié sud propre à l'époque : trémie en titane à deux GRANDS AILERONS en flèche,
    CAISSES À MISSILES (à la place des caisses ouvertes), tourelle secondaire en FUSEAU à ailerons sur pieds en V,
    COLLECTEUR DE TUBULURES FINES groupées à colliers clairs au sud-est (à la place de la vanne et du volant).
Inchangés de la passe 3 : réservoirs-fusées à ogive à l'est, échangeur à ailettes au nord-ouest, télémètre à
ailerons, chenillard bleu-blanc, dérives au sommet, foyers bleu-blanc, pièce paire (2 lance-missiles à ailerons).
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

EPOQUE = 11
NOM = "Titane"
FOYER = dict(rgb=(0.749, 0.902, 1.0), rgb2=(0.749, 0.902, 1.0))
CANON = dict(L=2.1, nb=6, rb=0.06, rr=0.145)
PLATEFORME = dict(chanfrein=0.8)
# passe 5, ronde 1 (consigne du DC du 23/10 : TOUT le bâtiment change d'un âge à l'autre) : l'âge du titane est un
# bâtiment ENTIÈREMENT EN TITANE BROSSÉ bleu-blanc (capots clairs, plaques moyennes, acier de structure bleu acier),
# posé sur un pont de TÔLES DE TITANE rivetées : plus de pont noir, plus d'olive ni d'ocre.
HABILLAGE = dict(jupe_cerclage="ring", chapeau="ring", tremie="titane_md", tourelleau="titane_md",
                 munitions=("ring", "steel_hi"), capots=("titane_cl", "titane_md"), acier=("titane_dk", "ring"),
                 rivets="rivet_ti", danger=("titane_cl", "bleu_nuit"), peinture="titane_md",
                 grille_nacelle="titane_dk",
                 plateforme=dict(motif="toles", mat="tole_ti", mat2="tole_ti2", fond="void", bord="titane_dk",
                                 boulons="rivet_ti", relief=0.25, lisere="emit_soft"))
RECV = ("jacket", "olive")


def matieres(metal, M):
    """Titane : titane patiné (moyen), alliage blanc PATINÉ (accents larges : manchons, ailerons, colliers).
    Passe 5, ronde 1 : titane et alliage en métal semi-diffus (métallicité 0,45 au lieu de 0,88 et 0,55 : un métal
    pur renvoie le ciel sombre et se lit noir vu de dessus, fait du kit en pose N), titane légèrement bleuté, alliage
    bleu-blanc clair (juges de la passe 4 : « titane brossé bleu-blanc clair ») ; ailerons radiaux 1,4 fois plus
    grands (envergure 0,6 t au lieu de 0,42)."""
    rust = (0.24, 0.085, 0.03)
    metal("jacket", (0.34, 0.36, 0.39), rough=0.32, met=0.45, grain=0.14, gscale=40.0, rust=rust, ra=0.06,
          dirt=0.8, stain=0.45, sscale=6.0, wear=1.0, streak=0.4)
    metal("ring", (0.62, 0.64, 0.66), rough=0.4, met=0.45, grain=0.14, gscale=30.0, rust=(0.2, 0.1, 0.05),
          ra=0.1, dirt=0.9, stain=0.6, sscale=5.0, wear=0.8, streak=0.5)
    # corps entier en titane (passe 5, ronde 1) : brossé = traînées longues (streak), bleuté, semi-diffus
    metal("titane_cl", (0.44, 0.49, 0.56), rough=0.32, met=0.45, grain=0.1, gscale=60.0, dirt=0.5, stain=0.3,
          sscale=6.0, wear=0.5, streak=0.7)
    metal("titane_md", (0.25, 0.28, 0.32), rough=0.34, met=0.45, grain=0.1, gscale=60.0, dirt=0.6, stain=0.35,
          sscale=6.0, wear=0.7, streak=0.6)
    metal("titane_dk", (0.1, 0.115, 0.135), rough=0.35, met=0.5, grain=0.1, gscale=50.0, dirt=0.6, stain=0.3,
          wear=0.9, streak=0.4)
    metal("tole_ti", (0.32, 0.355, 0.4), rough=0.36, met=0.45, grain=0.08, gscale=60.0, dirt=0.6, stain=0.35,
          sscale=5.0, streak=0.6)
    metal("tole_ti2", (0.26, 0.29, 0.33), rough=0.36, met=0.45, grain=0.08, gscale=60.0, dirt=0.6, stain=0.35,
          sscale=5.0, streak=0.6)
    metal("rivet_ti", (0.36, 0.4, 0.45), rough=0.35, met=0.45, grain=0.05, dirt=0.2, stain=0.0, reflet="fin")
    metal("bleu_nuit", (0.02, 0.03, 0.075), rough=0.4, met=0.2, grain=0.06, dirt=0.4, stain=0.2)
    M["trim"] = M["ring"]
    M["pipe"] = M["jacket"]
    M["pipe2"] = M["ring"]
    M["cable_a"], M["cable_b"] = M["redcable"], M["rubber"]
    M["spec"] = M["ring"]
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 21 de l'industriel, témoin)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    ring_lights(g, B["R"] - 0.08, B["h"] + B["rh"] + 0.02)
    ng = 7
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    P2.grating(g, 1.35, 1.75, Y(-1.15), Y(1.3), 0.07, M)
    P2.grating(g, -1.55, -1.3, Y(-1.0), Y(-0.3), 0.07, M)
    with at(g, -1.5, -1.72, 0.42):
        missile_crate(g, 0.8, 0.74, 0.3, 3)
    with at(g, -1.05, -2.35, 0.08):
        missile_crate(g, 0.62, 0.52, 0.24, 2)
    tremie_fins(g, c)
    for (x, yn, rz) in [(1.78, -1.82, 0.0)]:
        with at(g, x, yn, 0.0):
            P2.pedestal(g, 0.42, 0.0, 0.28, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            turret_legs(g, 0.42, 0.28)
            mini_turret(g, (0, 0, 0.28), 0.95, rz)
    # ouest : turbine de titane ; liaisons d'énergie vers la colonne
    west(g)
    conduit(g, [(-1.62, Y(0.55), 0.4), (-1.42, Y(0.6), 0.62), (-1.2, Y(0.5), 0.72)], 0.045)
    cables(g, [(-1.62, Y(-0.25), 0.4), (-1.42, Y(-0.3), 0.6), (-1.18, Y(-0.35), 0.68)])
    # nord-ouest : échangeur à ailettes posé en biais
    with at(g, -1.72, 2.02, -0.55):
        fin_exchanger(g, -0.55, 0.55, -0.42, 0.42, 0.62)
    # est : deux réservoirs-fusées à ogive et ailerons
    rocket_tank(g, 2.02, Y(0.95), 0.37, 0.92)
    rocket_tank(g, 2.02, Y(-0.4), 0.37, 0.92)
    P3.cabinet(g, -2.45, -2.02, -2.3, -1.66, 0.0, 0.5, M, E, screen_=False)
    # sud-est : collecteur de tubulures fines groupées (à la place de la vanne et du volant)
    manifold(g, 1.68, 2.36, Y(-1.18), Y(-0.85), 0.26)
    hose(g, [(1.7, Y(-1.0), 0.28), (1.45, Y(-1.05), 0.34), (1.22, Y(-0.85), 0.52)], 0.05)
    hose(g, [(1.7, Y(1.05), 0.62), (1.45, Y(0.95), 0.98), (1.15, Y(0.75), 0.82)], 0.06)
    P3.cabinet(g, 1.25, 2.25, Y(1.95), Y(2.42), 0.0, 0.56, M, E, screen_=False)
    signature(g, (1.55, Y(2.18), 0.6))
    # passe 5, ronde 1 : SILHOUETTE de l'âge, deux grandes DÉRIVES de titane en flèche (à la place des caisses du nord)
    for x in (-0.42, 0.42):
        derive(g, x, Y(1.92))
    signature(g, (-2.24, -1.98, 0.53), 2)
    for p in ((1.75, Y(2.18), 0.6), (-0.4, Y(1.95), 0.3), (2.02, Y(-1.02), 0.3),
              (-1.95, Y(-1.5), 0.45), (0.0, Y(-2.0), 0.68), (-0.95, Y(-2.35), 0.24)):
        signature(g, p)
    for x in (-0.68, 0.68):
        PT.lamp(g, (x, Y(-2.4) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    _halo(g, [(-2.0, Y(-1.1), 0.5), (1.78, Y(-2.1), 0.6), (0.0, Y(-2.5), 0.5), (2.0, Y(0.3), 0.5),
              (1.75, Y(1.8), 0.5)], 20.0)


def ring_lights(g, R, z):
    """Feux de couronne (face sud de la couronne d'orientation) : CHENILLARD bleu-blanc en segments courts, chaque feu
    un foyer séparé (espacement > 20 px hr)."""
    n = 13
    M = g.M
    for k in range(n):
        a = math.pi + math.pi * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0))
        t = V((-d.y, d.x, 0))
        Rr = Matrix((t, d, V((0, 0, 1)))).transposed()
        p = V((0, 0, z)) + d * R
        g.box(p, (0.1, 0.04, 0.03), M["steel_dk"], "hard", R=Rr, what="support")
        g.box(p + V((0, 0, 0.018)), (0.075, 0.018, 0.008), M["emit"], "flat", R=Rr, what="chenillard")


def turret_legs(g, R, h):
    """Pieds en V SOUS la tourelle secondaire, posés sur le tablier plein."""
    M = g.M
    for k in range(4):
        a = TAU * (k + 0.5) / 4
        d = V((math.cos(a), math.sin(a), 0))
        for s in (-1, 1):
            t = V((-d.y, d.x, 0))
            g.box(d * (R + 0.08) + t * s * 0.06 + V((0, 0, h * 0.45)), (0.04, 0.04, h * 0.95), M["jacket"], "hard",
                  R=Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(s * 0.3, 3, "X"), what="pied_v")


def west(g):
    """Groupe de l'ouest : BANC DE MISSILES (3 missiles effilés de titane couchés sur berceaux, nez en ogive d'alliage
    clair, empennages en X d'alliage clair, tuyères), brides de maintien, chenillard bleu-blanc. Remplace la turbine
    lourde de la passe 3 (lue « industrie lourde »)."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1 = -2.42, -1.62, Y(-0.95), Y(1.25)
    cx = (x0 + x1) / 2
    F.plinth(g, x0, x1, y0, y1, 0.1)
    r = 0.105
    zc = 0.1 + 0.07 + r
    ya, yb = y0 + 0.3, y1 - 0.42
    for f in (0.18, 0.5, 0.82):
        yy = ya + (yb - ya) * f
        g.box((cx, yy, 0.1 + 0.05), (x1 - x0 - 0.04, 0.1, 0.1), M["steel_dk"], "hard", what="berceau")
        for i in range(3):
            xm = cx + (i - 1) * 0.255
            g.tube_shell((xm, yy, zc), "y", r + 0.018, r - 0.005, 0.05, M["ring"], n=20, what="bride")
            g.dome((xm, yy, zc + r + 0.02), (0, 0, 1), 0.012, M["rivet"])
    for i in range(3):
        xm = cx + (i - 1) * 0.255
        g.cyl((xm, (ya + yb) / 2, zc), "y", r, yb - ya, M["jacket"], n=16, what="missile")
        for f in (0.33, 0.66):
            g.tube_shell((xm, ya + (yb - ya) * f, zc), "y", r + 0.006, r - 0.01, 0.02, M["steel_dk"], n=16,
                         what="joint")
        # nez en ogive (alliage clair), pointe
        g.cyl((xm, yb + 0.16, zc), "y", r, 0.32, M["ring"], n=16, r2=0.035, what="ogive")
        g.cyl((xm, yb + 0.35, zc), "y", 0.035, 0.06, M["steel_hi"], n=10, r2=0.006, what="pointe")
        # tuyère et empennage en X (alliage clair)
        g.cyl((xm, ya - 0.06, zc), "y", r * 0.7, 0.12, M["steel_dk"], n=14, r2=r * 0.9, what="tuyere")
        g.cyl((xm, ya - 0.122, zc), "y", r * 0.6, 0.006, M["soot"], n=14, style="flat", what="tuyere_fond")
        for d in F.ring_dirs(4, math.pi / 4, -0.9):
            c_ = V((xm, 0, zc))
            P2.wedge(g, c_ + d * (r - 0.01) + V((0, ya + 0.02, 0)), c_ + d * (r - 0.01) + V((0, ya + 0.34, 0)),
                     c_ + d * (r + 0.12) + V((0, ya - 0.02, 0)), F.Rax(d).col[0] * 0.02, M["ring"], what="aileron")
        for k in range(6):
            g.dome((xm, ya + 0.4 + (yb - ya - 0.5) * k / 5, zc + r * 0.98), (0, 0, 1), 0.011, M["rivet"])
        for f in (0.15, 0.45, 0.75):   # chenillard : segments courts espacés (chacun un foyer)
            g.box((xm + r * 0.7, ya + (yb - ya) * f, zc + r * 0.7), (0.02, 0.09, 0.02), E, "flat", what="chenillard")
    F.hatches(g, (x0 + 0.06, y0 + 0.25, 0.1), (x0 + 0.06, y1 - 0.25, 0.1), 6, (0, 0, 1), M["steel_hi"],
              size=(0.06, 0.06))


def missile_crate(g, w, d, h, n):
    """CAISSE À MISSILES (à la place de la caisse ouverte) : caisson titane riveté, alvéoles alignées dont sortent les
    nez en ogive d'alliage clair, couvercle rabattu, deux ailerons de manutention."""
    M = g.M
    E = M["emit"]
    PT.hull(g, -w / 2, w / 2, -d / 2, d / 2, 0.0, h, ins=(0.015, 0.015, 0.015), panel=0.24,
            mats=[M["jacket"], M["olive"]], rivet_step=0.11)
    pitch = (w - 0.1) / n
    for i in range(n):
        x = -w / 2 + 0.05 + pitch * (i + 0.5)
        for j in range(2):
            y = -d * 0.22 + d * 0.44 * j
            g.cyl((x, y, h + 0.006), "z", pitch * 0.36, 0.012, M["void"], n=14, style="flat", what="alveole")
            g.cyl((x, y, h + 0.06), "z", pitch * 0.3, 0.12, M["ring"], n=14, r2=0.012, what="nez")
    g.box((0, d / 2 + 0.03, h + 0.1), (w * 0.96, 0.03, 0.22), M["jacket"], "hard", R=Matrix.Rotation(-0.25, 3, "X"),
          what="couvercle")
    for s in (-1, 1):
        P2.wedge(g, V((s * w / 2, -d * 0.3, h * 0.3)), V((s * w / 2, d * 0.3, h * 0.3)),
                 V((s * (w / 2 + 0.1), -d * 0.2, h * 0.3)), V((0, 0, 0.025)), M["ring"], what="aileron")
    P3.lamp_group(g, (-w / 2 + 0.06, -d / 2 - 0.02, h * 0.5), (1, 0, 0), (0, -1, 0), E, M, n=2,
                  shapes=("fente", "rond"))
    for s in (-1, 1):
        g.box((s * w * 0.3, -d / 2 + 0.02, h + 0.004), (0.09, 0.02, 0.008), E, "flat", what="chenillard")


def tremie_fins(g, c):
    """Trémie de l'époque (peinte en titane, HABILLAGE) : deux GRANDS AILERONS d'alliage clair en flèche sur les
    flancs (nervurés, rivetés), une dérive dorsale sur l'arrière, tubulures fines groupées le long des flancs."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = c.tremie_box
    for s in (-1, 1):
        xb = x1 if s > 0 else x0
        p0 = V((xb, y0 + 0.12, 0.08))
        p1 = V((xb, y1 - 0.1, 0.08))
        p2 = V((xb + s * 0.34, y0 - 0.06, 0.08))
        P2.wedge(g, p0, p1, p2, V((0, 0, 0.05)), M["ring"], what="aileron")
        g.box((xb + s * 0.12, (y0 + y1) / 2 - 0.2, 0.115), (0.03, (y1 - y0) * 0.55, 0.025), M["steel_dk"], "hard",
              what="nervure")
        for f in (0.25, 0.5, 0.75):
            g.dome((xb + s * 0.06, y0 + (y1 - y0) * f, 0.11), (0, 0, 1), 0.012, M["rivet"])
        # tubulures fines groupées par 3 le long du flanc, colliers clairs
        xt = xb + s * 0.05
        PT.cable_run(g, [(xt, y0 + 0.05, h * 0.55), (xt, (y0 + y1) / 2, h * 0.62), (xt, y1 + 0.2, h * 0.9),
                         (s * 0.3, y1 + 0.45, c.rt + 0.04)], 3, 0.014, 0.034, [M["jacket"]])
        for yy in (y0 + 0.3, y0 + 0.75):
            g.box((xt + s * 0.02, yy, h * 0.45), (0.02, 0.09, 0.02), E, "flat", what="chenillard")
    zt = h + 0.02
    P2.wedge(g, V((0, y1 - 0.5, zt)), V((0, y1 - 0.08, zt)), V((0, y1 - 0.55, zt + 0.32)), V((0.035, 0, 0)), M["ring"],
             what="derive")


def manifold(g, x0, x1, y0, y1, h):
    """Collecteur de tubulures fines (sud-est) : caisson titane bas, 6 piquages fins à colliers d'alliage clair groupés
    par 3, aileron de signature, chenillard."""
    M = g.M
    E = M["emit"]
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.22, mats=[M["jacket"], M["steel_dk"]],
            rivet_step=0.12)
    w = x1 - x0
    for gi in range(2):
        for i in range(3):
            x = x0 + 0.1 + gi * w * 0.5 + i * 0.07
            g.cyl((x, (y0 + y1) / 2, h + 0.1), "z", 0.016, 0.2, M["jacket"], n=8, what="tubulure")
            g.cyl((x, (y0 + y1) / 2, h + 0.2), "y", 0.016, (y1 - y0) * 0.9, M["jacket"], n=8, what="tubulure")
        xc = x0 + 0.17 + gi * w * 0.5
        for zz in (h + 0.06, h + 0.16):
            g.box((xc, (y0 + y1) / 2, zz), (0.22, 0.05, 0.03), M["ring"], "hard", what="collier")
    P2.wedge(g, V((x1 - 0.05, y0 + 0.05, h)), V((x1 - 0.05, y1 - 0.05, h)), V((x1 - 0.05, y0 + 0.02, h + 0.2)),
             V((0.025, 0, 0)), M["ring"], what="aileron")
    g.box((x0 + w * 0.4, y0 - 0.004, h * 0.6), (0.09, 0.008, 0.025), E, "flat", what="chenillard")


def rocket_tank(g, x, y, r, h):
    M = g.M
    E = M["emit"]
    g.cyl((x, y, 0.05), "z", r + 0.08, 0.1, M["steel_dk"], n=32, style="soft", what="socle")
    nb = int(TAU * (r + 0.05) / 0.12)
    for k in range(nb):
        a = TAU * k / nb
        g.bolt((x + (r + 0.05) * math.cos(a), y + (r + 0.05) * math.sin(a), 0.1), (0, 0, 1), 0.016, M["steel_hi"])
    hexr = [(math.cos(TAU * i / 8 + TAU / 16), math.sin(TAU * i / 8 + TAU / 16)) for i in range(8)]
    F.loft_z(g, x, y, [(0.1, F.scale_poly(hexr, r)), (h, F.scale_poly(hexr, r)), (h + r * 1.1, F.scale_poly(hexr, r * 0.3)),
                     (h + r * 1.35, F.scale_poly(hexr, 0.04))], M["jacket"], "hard", "ogive")
    for zz in (0.3, h * 0.62, h):
        g.tube_shell((x, y, zz), "z", r * 1.02 + 0.018, r - 0.01, 0.04, M["ring"], n=8, style="hard", what="cerclage")
        for kk in range(10):
            a = TAU * (kk + 0.5) / 10
            d = V((math.cos(a), math.sin(a), 0))
            if d.y > 0.5:
                continue
            g.dome(V((x, y, zz - 0.045)) + d * (r * 0.96 + 0.004), d, 0.012, M["rivet"])
    for a in (math.pi * 0.25, math.pi * 0.75, math.pi * 1.25, math.pi * 1.75):
        d = V((math.cos(a), math.sin(a), 0))
        t = V((-d.y, d.x, 0)) * 0.03
        c = V((x, y, 0))
        P2.wedge(g, c + d * (r - 0.01) + V((0, 0, 0.12)), c + d * (r - 0.01) + V((0, 0, h * 0.75)),
                 c + d * (r + 0.24) + V((0, 0, 0.12)), t, M["ring"], what="aileron")
        g.box(c + d * (r + 0.08) + V((0, 0, 0.3)), (0.045, 0.045, 0.36), M["steel_dk"], "hard",
              R=Matrix.Rotation(a, 3, "Z"), what="nervure")
        for zz in (0.2, 0.34, 0.48):
            g.dome(c + d * (r + 0.04) + V((0, 0, zz)) + t * 0.7, t, 0.012, M["rivet"])
    for a in (-1.1, -1.55, -2.0, -2.45):
        d = V((math.cos(a), math.sin(a), 0))
        F.hatches(g, V((x, y, 0.42)) + d * (r * 0.93), V((x, y, 0.62)) + d * (r * 0.93), 2, d, M["matte"],
                size=(0.06, 0.07), frame=M["ring"])
    for a in (-0.7, -1.3, -1.9, -2.5):
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, 0.105)) + d * (r + 0.07), (0.07, 0.07, 0.014), M["steel_hi"], "hard", R=Matrix.Rotation(a, 3, "Z"),
              what="trappe")
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        d = V((math.cos(a), math.sin(a), 0))
        F.hatches(g, V((x, y, h + r * 0.35)) + d * (r * 0.78), V((x, y, h + r * 0.45)) + d * (r * 0.72), 1,
                (d.x * 0.8, d.y * 0.8, 0.6), M["steel_dk"], size=(0.05, 0.05))
    for k, (a, zz) in enumerate(((-1.3, 0.45), (-1.75, 0.53), (-1.0, 0.8), (-2.1, 0.25))):
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, h * zz)) + d * (r + 0.01), (0.09, 0.02, 0.03), E, "flat",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="chenillard")


def derive(g, x, y):
    """Dérive de fusée (passe 5, ronde 1 : superstructure de l'âge du titane, qui change le contour) : semelle
    boulonnée, grande lame triangulaire de titane clair en flèche (bord d'attaque au sud, bord de fuite vertical au
    nord), bord d'attaque en alliage et LIGNE LUMINEUSE bleu-blanc, rivets en ligne. Pleine (aucun jour). Sommet à 1,15
    (sous h_max 1,29 de la taille 5)."""
    M = g.M
    E = M["emit"]
    y0, y1, ht = y - 0.42, y + 0.4, 1.15
    g.box((x, y, 0.05), (0.16, y1 - y0 + 0.06, 0.1), M["steel_dk"], "hard", what="semelle")
    for yy in (y0 + 0.06, y, y1 - 0.06):
        for s in (-1, 1):
            g.dome((x + s * 0.08, yy, 0.1), (0, 0, 1), 0.014, M["rivet"])
    a, b, cc = V((x, y0, 0.1)), V((x, y1, 0.1)), V((x, y1 + 0.02, ht))
    P2.wedge(g, a, b, cc, V((0.05, 0, 0)), M["olive"], what="derive")
    # bord d'attaque : baguette d'alliage et ligne lumineuse posée dessus
    d = cc - a
    tg = d.normalized()
    sd = V((1, 0, 0))
    nn = tg.cross(sd).normalized()
    if nn.y > 0:
        nn = -nn
    Rm = Matrix((tg, sd, tg.cross(sd))).transposed()
    g.box((a + cc) / 2 + nn * 0.012, (d.length, 0.06, 0.03), M["ring"], "hard", R=Rm, what="bord_attaque")
    g.box((a + cc) / 2 + nn * 0.03, (d.length * 0.8, 0.02, 0.008), E, "flat", R=Rm, what="ligne_lum")
    # rivets sur les deux faces, en ligne parallèle à la semelle
    for i in range(5):
        yy = y0 + 0.25 + i * (y1 - y0 - 0.3) / 4
        for s in (-1, 1):
            g.dome((x + s * 0.026, yy, 0.22), (s, 0, 0), 0.011, M["rivet"])
    g.box((x, y1 - 0.03, ht * 0.55), (0.06, 0.04, ht * 0.85), M["steel_dk"], "hard", what="bord_fuite")


def fin_exchanger(g, x0, x1, y0, y1, h, nfin=7):
    """Échangeur de titane : socle, rangée d'AILETTES verticales anguleuses en alliage clair, collecteurs."""
    M = g.M
    F.plinth(g, x0, x1, y0, y1, 0.12)
    for i in range(nfin):
        x = x0 + 0.08 + (x1 - x0 - 0.16) * (i + 0.5) / nfin
        P2.wedge(g, V((x, y0 + 0.06, 0.12)), V((x, y1 - 0.06, 0.12)), V((x, y0 + 0.12, h)), V((0.035, 0, 0)), M["ring"],
                 what="ailette")
        g.box((x, (y0 + y1) / 2, 0.16), (0.05, y1 - y0 - 0.1, 0.06), M["steel_dk"], "hard", what="pied")
    for yy in (y0 + 0.1, y1 - 0.12):
        g.cyl(((x0 + x1) / 2, yy, 0.2), "x", 0.04, x1 - x0 - 0.06, M["jacket"], n=10, what="collecteur")
    F.hatches(g, (x0 + 0.06, y0 - 0.005, 0.07), (x1 - 0.06, y0 - 0.005, 0.07), 4, (0, -1, 0), M["steel_hi"],
            size=(0.06, 0.04))
    for f in (0.2, 0.6):
        g.box((x0 + (x1 - x0) * f, y0 + 0.02, 0.135), (0.08, 0.02, 0.025), M["emit"], "flat", what="chenillard")


def signature(g, p, kind=0):
    """Petite pièce de signature posée sur un toit de machine : 2 ailerons d'alliage clair."""
    M = g.M
    p = V(p)
    for s in (-1, 1):
        P2.wedge(g, p + V((s * 0.08, -0.08, 0)), p + V((s * 0.08, 0.1, 0)), p + V((s * 0.08, -0.06, 0.12)),
                 V((0.02, 0, 0)), M["ring"], what="aileron")


def mini_turret(g, c, s, rz):
    """Tourelle secondaire TITANE : couronne rivetée de la lignée, caisson en FUSEAU (section hexagonale effilée vers
    l'avant, titane, joints sombres), dérive dorsale et 2 ailerons latéraux d'alliage clair en flèche ; les DEUX ARMES
    sont celles de l'époque (canons longs et effilés à ailerons)."""
    M = g.M
    E = M["emit"]
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["armor2"], n=32, style="soft", what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    hexs = [(0.0, 1.0), (0.87, 0.5), (0.87, -0.5), (0.0, -1.0), (-0.87, -0.5), (-0.87, 0.5)]
    zf = 0.27 * s
    F.loft(g, 0.0, zf, [(-0.34 * s, F.scale_poly(hexs, 0.12 * s)), (-0.22 * s, F.scale_poly(hexs, 0.19 * s)),
                        (0.1 * s, F.scale_poly(hexs, 0.19 * s)), (0.34 * s, F.scale_poly(hexs, 0.07 * s))],
           M["jacket"], "hard", "fuseau")
    g.box((0, -0.05 * s, 0.15 * s), (0.32 * s, 0.4 * s, 0.1 * s), M["steel_dk"], "hard", what="assise")
    for yy in (-0.2 * s, 0.05 * s):
        F.loft(g, 0.0, zf, [(yy - 0.01, F.scale_poly(hexs, 0.2 * s)), (yy + 0.01, F.scale_poly(hexs, 0.2 * s))],
               M["ring"], "hard", "collier")
    P2.wedge(g, V((0, -0.3 * s, zf + 0.15 * s)), V((0, 0.0, zf + 0.15 * s)), V((0, -0.36 * s, zf + 0.36 * s)),
             V((0.02, 0, 0)), M["ring"], what="derive")
    for sx in (-1, 1):
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=[M[k] for k in RECV])
        _gun11(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
        P2.wedge(g, V((sx * 0.4 * s, -0.3 * s, 0.3 * s)), V((sx * 0.4 * s, -0.05 * s, 0.3 * s)),
                 V((sx * 0.58 * s, -0.36 * s, 0.3 * s)), V((0, 0, 0.02)), M["ring"], what="aileron")
    g.box((0.0, 0.2 * s, zf + 0.1 * s), (0.08, 0.02, 0.012), E, "flat", what="chenillard")
    g.pop()


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduits fins de titane groupés par 3, colliers d'alliage clair, conduits à bagues lumineuses
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    """Trois conduits fins de titane serrés, colliers d'alliage blanc patiné."""
    M = g.M
    PT.cable_run(g, ctrl, 3, r * 0.42, r * 0.95, [M["jacket"]])
    P = g.spline(ctrl, 10)
    T, _ = g.frames(P)
    for i in range(2, len(P) - 1, 6):
        g.cyl(P[i], T[i], r * 1.55, 0.04, M["ring"], n=12, style="hard", what="collier")


def cables(g, ctrl, n=3):
    M = g.M
    PT.cable_run(g, ctrl, n, 0.02, 0.045, [M["rubber"], M["redcable"], M["rubber"]])


def conduit(g, ctrl, r):
    """Conduit d'énergie : bagues lumineuses PAR GROUPES (chenillard), colliers d'alliage clair."""
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
    g.pipe(ctrl, r, M["jacket"], fl_mat=M["pipe2"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 22 : 2 lance-missiles à ailerons
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.5, Y(-2.64), sx)
    _halo(g, [(-1.5, Y(-2.9), 0.4), (1.5, Y(-2.9), 0.4)], 16.0)


def even_piece(g, x, yb, sx):
    """LANCE-MISSILES À AILERONS : caisson 2 × 2 cellules incliné, nez des missiles, ailerons arrière, sur la plinthe
    commune (caisson blindé bas à bande de danger)."""
    M = g.M
    E = M["emit"]
    w, d = 0.62, 0.6
    PT.hull(g, x - w / 2, x + w / 2, yb - d / 2, yb + d / 2, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["steel_dk"]], rivet_step=0.12)
    g.hazard([V((x - w / 2, yb - d / 2 - 0.02, 0.02)), V((x + w / 2, yb - d / 2 - 0.02, 0.02)),
              V((x + w / 2, yb - d / 2 - 0.02, 0.12)), V((x - w / 2, yb - d / 2 - 0.02, 0.12))], 6, t=0.012, skew=0.6)
    z0 = 0.14
    P3.lamp_group(g, (x - w / 2 + 0.06, yb - d / 2 - 0.025, 0.07), (1, 0, 0), (0, -1, 0), E, M, n=2,
                  shapes=("rond", "fente"))
    g.cyl((x, yb, z0 + 0.04), "z", 0.24, 0.08, M["steel_dk"], n=28, style="soft", what="couronne")
    P3.lamp_group(g, (x - 0.28, yb - 0.31, 0.08), (1, 0, 0), (0, -1, 0), E, M, n=2, shapes=("fente", "rond"))
    P3.lamp_group(g, (x + 0.12, yb - 0.31, 0.08), (1, 0, 0), (0, -1, 0), E, M, n=1, shapes=("carre",))
    g.push((x, yb, z0 + 0.1), rz=0.0, rx=0.3)
    PT.hull(g, -0.24, 0.24, -0.22, 0.22, 0.0, 0.36, ins=(0.01, 0.01, 0.01), panel=0.24,
            mats=[M["olive"], M["jacket"]], rivet_step=0.11, faces="tsewn")
    for i in range(2):
        for j in range(2):
            cx, cz = -0.11 + 0.22 * i, 0.1 + 0.16 * j
            g.cyl((cx, -0.225, cz), "y", 0.072, 0.02, M["void"], n=16, style="flat", what="cellule")
            g.cyl((cx, -0.2, cz), "y", 0.052, 0.12, M["ring"], n=14, r2=0.012, what="nez")
            g.cyl((cx, -0.262, cz), "y", 0.016, 0.006, E, n=8, style="flat", what="pointe")
    for s in (-1, 1):
        P2.wedge(g, V((s * 0.24, 0.0, 0.1)), V((s * 0.24, 0.22, 0.1)), V((s * 0.36, 0.2, 0.06)),
                 V((0, 0, 0.02)), M["ring"], what="aileron")
        P2.wedge(g, V((s * 0.1, 0.1, 0.36)), V((s * 0.1, 0.22, 0.36)), V((s * 0.1, 0.22, 0.47)),
                 V((0.02, 0, 0)), M["ring"], what="aileron")
    g.pop()


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon long à empennage
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    alimentation, voyants d'état, culasse en flèche."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun11(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # culasse EN FLÈCHE : capot effilé vers l'arrière (alliage blanc patiné), rivets
    zt = zg + hr + 0.012
    b = [V((x - wr * 0.4, y0 + 0.12, zt)), V((x + wr * 0.4, y0 + 0.12, zt)), V((x + wr * 0.4, y1 - 0.22, zt)),
         V((x - wr * 0.4, y1 - 0.22, zt))]
    t = [V((x - 0.02, y0 - 0.12, zt + 0.015)), V((x + 0.02, y0 - 0.12, zt + 0.015)),
         V((x + wr * 0.3, y1 - 0.26, zt + 0.045)), V((x - wr * 0.3, y1 - 0.26, zt + 0.045))]
    g.hexa(b + t, M["ring"], "hard", what="coin")
    g.box((x, (y0 + y1) / 2 - 0.1, zt + 0.04), (0.014, (y1 - y0) * 0.6, 0.012), M["steel_dk"], "hard",
          what="arete")
    for k in range(4):
        for s_ in (-1, 1):
            g.dome((x + s_ * wr * (0.08 + 0.05 * k), y0 + 0.02 + k * 0.17, zt + 0.02 + 0.008 * k), (0, 0, 1),
                   0.013, M["rivet"])


def _gun11(g, x, y0, z, L, nb, rb, rr):
    """Quatrième passe : canon LONG (1,25 L) et EFFILÉ (6 tubes fins serrés, rosette visible sur toute la moitié
    avant), manchon arrière à pans d'ALLIAGE CLAIR patiné (<= moitié arrière, joints de titane sombres), QUATRE
    AILERONS RADIAUX en X (diagonales) d'alliage clair, nervurés, sur le manchon, et un 2e empennage plus petit ;
    frein en POINTE DE FLÈCHE à deux grandes ailettes horizontales en flèche, rosace éclairée devant. De dessus (pose
    E) : une flèche empennée ; en pose N : une pointe de flèche plus large que le faisceau, jamais un chapeau rond."""
    M = g.M
    E = M["emit"]
    k = F.k_arme(rb, rr)
    L2 = L * 1.25
    rb2, rr2 = rb * 0.72, rr * 0.6
    R0 = rr2 + rb2
    pos = corps.rosette(g, x, y0, z, L2, nb, rb2, rr2, colliers=(0.62, 0.8), collier_mat=M["ring"], bouts=False,
                        segments=10)
    g.cyl((x, y0 + L2 * 0.99, z), "y", max(rr2 - rb2 * 0.55, rr2 * 0.55), L2 * 0.04 + 0.03, M["steel_dk"], n=12,
          what="ame_bout")
    # manchon à pans anguleux (hexagone effilé vers l'avant), alliage clair, joints de titane, rivets
    Ls = min(0.42, corps.JAQUETTE_MAX) * L2
    hexs = [(0.0, 1.0), (0.87, 0.5), (0.87, -0.5), (0.0, -1.0), (-0.87, -0.5), (-0.87, 0.5)]
    r_a, r_b = R0 + 0.12 * k, R0 + 0.035
    F.loft(g, x, z, [(y0 - 0.02, F.scale_poly(hexs, r_a * 0.9)), (y0 + 0.1, F.scale_poly(hexs, r_a)),
                   (y0 + Ls, F.scale_poly(hexs, r_b))], M["ring"], "hard", "manchon")

    def rad(yy):
        return r_a + (r_b - r_a) * max(0.0, min(1.0, (yy - y0 - 0.1) / (Ls - 0.1)))
    for f in (0.3, 0.62):
        rr_ = rad(y0 + f * Ls)
        F.loft(g, x, z, [(y0 + f * Ls - 0.016, F.scale_poly(hexs, rr_ * 1.05)),
                         (y0 + f * Ls + 0.016, F.scale_poly(hexs, rr_ * 1.05))], M["jacket"], "hard", "joint")
        if k >= 0.9:
            for (u, w) in hexs[:3] + hexs[5:]:
                g.dome((x + u * rr_ * 1.0, y0 + f * Ls + 0.04, z + w * rr_ * 1.0), (u, 0, w), 0.012, M["rivet"])
    # AILERONS RADIAUX EN X (4 diagonales ; pas d'aileron vers le sol), grand empennage puis petit empennage
    for (yy, span, chord) in ((y0 + 0.3 * k, 0.6 * k, 0.75 * k), (y0 + Ls + 0.12 * k, 0.28 * k, 0.36 * k)):
        r0 = rad(yy)
        for d in F.ring_dirs(4, math.pi / 4, -0.9):
            if d.z < 0 and yy < y0 + 0.5 * k:
                sp = span * 0.6
            else:
                sp = span
            t = F.Rax(d).col[0] * 0.024
            c_ = V((x, 0, z))
            p0 = c_ + d * (r0 - 0.01) + V((0, yy - 0.12 * k, 0))
            p1 = c_ + d * (r0 - 0.01) + V((0, yy + chord, 0))
            p2 = c_ + d * (r0 + sp) + V((0, yy + 0.02, 0))
            P2.wedge(g, p0, p1, p2, t, M["ring"], what="aileron")
            if k >= 0.9:
                g.box(c_ + d * (r0 + sp * 0.4) + V((0, yy + 0.08, 0)), (0.024, 0.05, sp * 0.75), M["jacket"], "hard",
                      R=F.Rax(d), what="nervure")
                for f in (0.3, 0.6):
                    g.dome(c_ + d * (r0 + sp * f * 0.8) + V((0, yy + chord * (1 - f) * 0.6, 0)) + F.Rax(d).col[0] * 0.013,
                           F.Rax(d).col[0], 0.011, M["rivet"])
    # conduits fins jumelés de titane sur le dos (chenillard bleu-blanc en segments)
    if k >= 0.9:
        for s in (-1, 1):
            p0 = V((x + s * 0.04 * k, y0 + Ls + 0.02, z + R0 + 0.02))
            p1 = V((x + s * 0.04 * k, y0 + L2 * 0.88, z + R0 + 0.02))
            g.tube([p0, p1], 0.012 * k, M["jacket"], n=8, what="conduit")
            for f in (0.2, 0.55, 0.9):
                g.cyl(p0.lerp(p1, f), "y", 0.02 * k, 0.025, M["ring"], n=10, style="hard", what="collier")
            g.cyl(p0.lerp(p1, 0.38) + V((0, 0, 0.004)), "y", 0.016 * k, 0.04, E, n=8, style="flat",
                  what="segment_lum")
    # frein EN POINTE DE FLÈCHE : bague, corps hexagonal effilé, 2 grandes ailettes horizontales en flèche (plus
    # larges que le faisceau), évents obliques, rosace éclairée en face avant
    yb0 = y0 + L2
    lb = 0.36 * k
    g.tube_shell((x, yb0 + 0.02, z), "y", R0 + 0.05, rr2 * 0.4, 0.05, M["ring"], n=28, what="bague")
    g.cyl((x, yb0 + lb / 2, z), "y", R0 + 0.055, lb, M["jacket"], n=6, r2=R0 + 0.01, style="hard", phase=math.pi / 2,
          what="frein")
    for s in (-1, 1):
        c_ = V((x, 0, z))
        P2.wedge(g, c_ + V((s * (R0 + 0.03), yb0 + 0.02, 0)), c_ + V((s * (R0 + 0.01), yb0 + lb, 0)),
                 c_ + V((s * (R0 + 0.2 * k), yb0 - 0.04 * k, 0)), V((0, 0, 0.028 * k)), M["ring"], what="ailette")
        for i in range(3):
            g.box(V((x + s * (R0 + 0.045 - i * 0.01), yb0 + lb * (0.25 + 0.22 * i), z + 0.02)),
                  (0.012, 0.06 * k, 0.03 * k), M["void"], "flat", R=Matrix.Rotation(s * 0.5, 3, "Z"), what="event")
    if k >= 0.9:
        P2.wedge(g, V((x, yb0 + 0.02, z + R0)), V((x, yb0 + lb * 0.8, z + R0 * 0.6)),
                 V((x, yb0 + 0.02, z + R0 + 0.12 * k)), V((0.022, 0, 0)), M["ring"], what="ailette")
    corps.bouche(g, x, yb0 + lb + 0.002, z, pos, rb2, M["steel_dk"], R0 + 0.008, w=0.018 if k >= 0.9 else 0.01)
    return yb0 + lb


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) titane et kaki, goulotte, 2 ailerons, voyants."""
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
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["jacket"], M["olive"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    chute = [(bc, yb0 + bl * 0.6, ztop + 0.005), (bc - sx * 0.05, y0 + bl * 0.55, zg + bh * 0.62),
             (x + sx * wr * 0.2, y0 + bl * 0.5, zg + hr + 0.06)]
    cw = 0.12 * wr / 0.4 + 0.04
    P2.feed_chute(g, chute, cw, M)
    for k in range(2):
        yy = yb0 + bl * (0.35 + 0.35 * k)
        P2.wedge(g, V((bc, yy - 0.1, ztop)), V((bc, yy + 0.08, ztop)), V((bc, yy - 0.08, ztop + 0.13)),
                 V((0.02, 0, 0)), M["ring"], what="aileron")
    P3.lamp_group(g, (bc + sx * bw * 0.32, yb0 + bl * 0.4, ztop - 0.005), (0, 1, 0), (0, 0, 1), E, M, n=2,
                  shapes=("fente", "rond"))
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
    F.slits_grouped(g, R, z0 + 0.2, 8, M["emit"])
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
    row1 = (0.5, 0.95, 1.4, math.pi - 0.5, math.pi - 0.95, math.pi - 1.4)
    ph1, w1, h1 = (0.32, 0.28, 0.22)
    for i, th in enumerate(row1):
        mat = M["trim"] if i % 3 == 1 else (M["ochre"] if i % 2 else M["steel_dk"])
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    # télémètre à ailerons
    zt = H["zs"] + H["rz"] * 0.86
    g.box((0.0, R * 0.32, zt), (R * 1.25, 0.1, 0.1), M["jacket"], "hard", what="telemetre")
    for sx in (-1, 1):
        g.cyl((sx * R * 0.64, R * 0.32, zt), "x", 0.07, 0.09, M["steel_dk"], n=14, what="telemetre_bout")
        g.cyl((sx * R * 0.64, R * 0.32 + 0.065, zt), "y", 0.045, 0.012, M["emit"], n=12, style="flat",
              what="lentille")
        g.box((sx * R * 0.3, R * 0.32, zt - 0.1), (0.05, 0.05, 0.12), M["steel_dk"], "hard", what="support")
        P2.wedge(g, V((sx * R * 0.62, R * 0.32 - 0.05, zt + 0.05)), V((sx * R * 0.62, R * 0.32 + 0.05, zt + 0.05)),
                 V((sx * R * 0.62, R * 0.32 - 0.04, zt + 0.15)), V((0.02, 0, 0)), M["ring"], what="aileron")
    # sommet de la tête : grande DÉRIVE en flèche sur la nacelle, 2 dérives latérales inclinées, plaques anguleuses
    bx, yb0, yb1 = c.nac[:3]
    znac = H["zs"] + H["rz"] * 0.42
    for s, ang, sc in ((0, 0.0, 1.0), (-1, -0.5, 0.6), (1, 0.5, 0.6)):
        x = s * bx * 0.75
        g.push((x, 0, znac), ry=ang)
        P2.wedge(g, V((0, yb0 + 0.05, 0)), V((0, yb1 - 0.05, 0)), V((0, yb0 - 0.12, 0.55 * sc)), V((0.04, 0, 0)),
                 M["ring"], what="derive")
        g.box((0, (yb0 + yb1) / 2 - 0.05, 0.08 * sc), (0.06, (yb1 - yb0) * 0.6, 0.06), M["steel_dk"], "hard",
              what="nervure")
        for f in (0.25, 0.5):
            g.dome((0.022, yb0 + (yb1 - yb0) * (0.6 - f), 0.4 * sc * f + 0.05), (1, 0, 0), 0.012, M["rivet"])
        g.pop()
    for th in (math.pi / 2 - 0.55, math.pi / 2 + 0.55):
        P2.applique(g, c.Pf, c.Nf, th, 0.42, 0.5, 0.34, M["ring"], M, bolts=4)
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
