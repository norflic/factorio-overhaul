"""Époque 4 · Pétrole (ère II, 3×3, niveaux 7 et 8). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 4) : « fûts, jaune, vannes ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py, kit.py).
Corrections de design de la QUATRIÈME PASSE (23/10, constructeur de la plage basse) :
  - (époque bien lue : gardée) frein en bloc élargi à oreilles (pose N), jaquette à la moitié arrière, voyants de
    plus ; foyers ramenés dans la famille « orange de torchère » ; chanfrein de plateforme 0,75.
Emplacements remplis : arme (gatling à jaquette galvanisée perforée, frein à 2 fentes, culasse jaune à bandes
noires, gros fût-chargeur couché sur le flanc), grands volumes du socle (2 cuves couchées jaunes à passerelle, fûts,
groupe de pompage, rampe de conduites), liaisons (galvanisé à vanne à volant rouge), nacelle (torchère), bague de
danger sur la coupole, foyers orange, pièce paire (2 cuves-chargeurs couchées).
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

EPOQUE = 4
NOM = "Pétrole"
KIN = 0   # rang dans l'ère II
# passe 4 : teinte nominale plus rouge (mesurée à 38° en passe 3, hors famille « orange de torchère » 24 à 34°)
FOYER = dict(rgb=(1.0, 0.42, 0.1))
CANON = dict(L=1.2, nb=4, rb=0.045, rr=0.1)
# passe 4 : chanfrein de plateforme d'époque (remplissage, catalogue §A.5 ; silhouette distincte des voisines)
PLATEFORME = dict(chanfrein=0.75)
# passe 5 (ronde 1) : lu « cuivre, cuves, vapeur » par un lecteur de la ronde 0 : plus AUCUN laiton ni cuivre visible
# (munitions en cartouches rouges et galvanisé, bouchons rouges) ; GRANDS CAPOTS jaune délavé (clé « capots » du kit :
# coupole, colonne, nacelle, masque) et plaques secondaires galvanisées : la machine se lit jaune et gris, jamais
# laiton.
# Ronde 1 reprise après la consigne du DC du 23/10 (TOUT le bâtiment change d'âge) : pont de TÔLES larmées
# galvanisées claires bordées de jaune de sécurité, acier de structure galvanisé sombre et galvanisé clair, rivets
# galvanisés, joints de caoutchouc noir, peinture rouge des vannes. Lecture : plate-forme pétrolière jaune et grise.
# Ronde 3 (DC, 23/10 9 h 50 : « trop uniforme en terme de palette ») : JAUNE DE SIGNALISATION dominant, NOIR en
# secondaire (acier de structure, plaques secondaires, conduites, tôles du pont, bandes de danger jaune et noir),
# rouge des volants et flamme orange en accent ; le gris galvanisé disparaît (il rapprochait 4 de 5 et de 6). Silhouette
# (test des écarts de la ronde 2, 4-5 et 5-6 : « même forme », « silhouette identique ») : PONT CARRÉ à garde-corps
# jaunes (forme « carre » du kit), au lieu de l'octogone commun aux trois âges de l'ère II.
HABILLAGE = dict(jupe_cerclage="galva", tremie="yellowpaint", pochoirs=True, munitions=("redpaint", "galva"),
                 chapeau="noir_capot", capots=("jaune_capot", "noir_capot"), acier=("noir_capot", "galva_capot"),
                 rivets="galva_capot", joints="rubber", tourelleau="jaune_capot", danger=("jaune_capot", "noir_capot"),
                 forme_plateforme=dict(forme="carre", flanc="jaune_capot", flanc2="noir_capot"),
                 plateforme=dict(motif="toles", pas=0.5, mat="tole_larmee", mat2="tole_larmee2", bord="jaune_capot",
                                 boulons="galva_capot", relief=0.2))
ST = dict(jacket="galva", brake="slots", drive="motor", drive_mat="steel_dk", band="galva",
          recv_mats=("yellowpaint", "yellowpaint"), recv_sig="stripes", feed="barrels", skirt="galva",
          appl="jaune_capot", gmask=("yellowpaint", "galva"), arm=("jaune_capot", "noir_capot"), cap="galva",
          col=("jaune_capot", "noir_capot"), nac=("jaune_capot", "yellowpaint"), flange_mat="galva")


def matieres(metal, M):
    """Test noir et blanc de la passe 3 : le galvanisé des grands aplats est plus clair (× 1,35)."""
    rust = (0.24, 0.085, 0.03)
    # ronde 3 : la clé « galva » (conduites, frein, jaquette, bagues des cuves) devient de l'acier PEINT EN NOIR satiné
    # (secondaire noir de la palette jaune et noir) ; le nom reste pour ne pas toucher au dessin
    # ronde 3 : acier nu clair du canon (jaquette perforée, frein) : un métal pur vers le nord reste noir (kit, pose N)
    metal("acier_canon", (0.4, 0.39, 0.37), rough=0.4, met=0.35, grain=0.12, gscale=30.0, dirt=0.5, stain=0.3,
          sscale=5.0, wear=1.0)
    metal("noir_capot", (0.045, 0.044, 0.042), rough=0.42, met=0.1, grain=0.15, gscale=30.0, rust=(0.24, 0.085, 0.03),
          ra=0.08, dirt=0.55, stain=0.4, sscale=5.0, wear=2.2, streak=0.3)
    metal("galva", (0.06, 0.059, 0.057), rough=0.38, met=0.3, grain=0.3 * 0.62, gscale=30.0, rust=rust, ra=0.2, dirt=0.8,
          stain=0.75, stain2=0.32, sscale=5.0, wear=1.6, streak=0.45, tone=1.35)
    # passe 5 : jaune délavé des GRANDS CAPOTS (clé « capots ») : matière de corps, ni vive ni réfléchissante, plus
    # claire et moins sale que le jaune des accents (« yellowpaint ») pour se lire jaune au zoom 1
    # ronde 2 (lecteurs de la ronde 1 : « olive laiton », « couleur laiton ») : PEINTURE jaune de chantier délavée,
    # mate et presque pas métallique (un jaune métallique se lit laiton), plus claire et plus pâle
    # (essai a de la ronde 2 : (0,58 ; 0,46 ; 0,12) restait kaki au zoom 1 : la saleté et les taches l'assombrissent ;
    # jaune franc, moins sale)
    # ronde 4 (test des écarts de la ronde 3 : 4 jugé PLUS évolué que 5 par les deux lecteurs, et que 6 par un
    # lecteur : « O doré à dôme ») : la peinture jaune perd son éclat d'or : jaune plus pâle et moins saturé (vraiment
    # « délavé »), écaillée sur la rouille (ra 0,1 -> 0,26), plus sale ; c'est le PREMIER âge de l'ère II, le plus brut
    # ronde 5 (test à l'aveugle de la ronde 4 : 4 lu « laiton, dôme, tuyaux de vapeur », pris pour la VAPEUR) : le
    # jaune pâle (0,7 ; 0,6 ; 0,13) se lisait laiton : il garde sa clarté mais devient un JAUNE DE SIGNALISATION citron
    # franc (bleu presque nul), toujours mat et écaillé : une peinture de chantier, jamais un métal
    metal("jaune_capot", (0.72, 0.6, 0.025), rough=0.75, met=0.0, grain=0.26, gscale=30.0, rust=rust, ra=0.26,
          dirt=0.65, stain=0.55, sscale=5.0, wear=2.4, streak=0.5)
    # jaune des cuves et des fûts : même teinte que la bibliothèque, un peu plus clair et moins sale (aperçu de ronde 1 :
    # il tournait à l'olive brun au zoom 1) ; ronde 2 : mat, comme les capots
    # ronde 5 : même jaune citron que les capots (l'ancien (0,64 ; 0,46 ; 0,07) tirait à l'or et au laiton)
    metal("yellowpaint", (0.66, 0.54, 0.02), rough=0.7, met=0.0, grain=0.2, gscale=30.0, rust=rust, ra=0.2,
          dirt=0.55, stain=0.55, sscale=5.0, wear=2.4, streak=0.5)
    # passe 5 : galvanisé du CORPS (peu métallique : grande masse claire, règle de reflets du kit) et tôles larmées
    metal("galva_capot", (0.32, 0.33, 0.33), rough=0.42, met=0.4, grain=0.15, gscale=30.0, rust=rust, ra=0.12,
          dirt=0.7, stain=0.55, sscale=5.0, wear=1.2, streak=0.35)
    metal("galva_sombre", (0.12, 0.125, 0.13), rough=0.42, met=0.45, grain=0.15, gscale=30.0, rust=rust, ra=0.2,
          dirt=0.75, stain=0.5, wear=1.4)
    # ronde 3 : tôles larmées gris anthracite (plus de galvanisé clair : palette jaune et noir)
    metal("tole_larmee", (0.15, 0.148, 0.145), rough=0.45, met=0.4, grain=0.5, gscale=70.0, rust=rust, ra=0.15,
          dirt=0.8, stain=0.6, sscale=5.0, wear=0.8)
    metal("tole_larmee2", (0.12, 0.118, 0.115), rough=0.45, met=0.4, grain=0.5, gscale=70.0, rust=rust, ra=0.22,
          dirt=0.8, stain=0.6, sscale=5.0, wear=0.8)


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : cuves couchées, fûts, groupe de pompage, rampe de conduites
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=2)
    socle_petrol(g, KIN)
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def fuel_tank(g, x, yn0, yn1, r, M, E, ladder=True, catwalk=True):
    """Cuve couchée de carburant (nord-sud) : virole jaune délavé, bagues de danger jaune et noire, berceaux,
    passerelle et garde-corps pleins sur le dessus, échelle au sud, jauge de niveau, trou d'homme."""
    y0, y1 = Y(yn0), Y(yn1)
    L = y1 - y0
    zc = 0.1 + r
    P2.tank(g, (x, (y0 + y1) / 2, zc), r, L, (0, 1, 0), M, paint=M["yellowpaint"], band=M["galva"], gauges=1)
    for f in (-0.3, 0.05, 0.38):
        F.hazard_ring(g, (x, (y0 + y1) / 2 + f * L, zc), (0, 1, 0), r + 0.004, 0.09, n=14)
    if catwalk:
        g.box((x, (y0 + y1) / 2, zc + r + 0.025), (0.2, L * 0.86, 0.03), M["grate"], "hard", what="passerelle")
        for s in (-1, 1):
            g.box((x + s * 0.11, (y0 + y1) / 2, zc + r + 0.075), (0.016, L * 0.82, 0.07), M["galva"], "hard",
                  what="plinthe")
            g.hazard([V((x + s * 0.12, y0 + L * 0.1, zc + r + 0.05)), V((x + s * 0.12, y1 - L * 0.1, zc + r + 0.05)),
                      V((x + s * 0.12, y1 - L * 0.1, zc + r + 0.1)), V((x + s * 0.12, y0 + L * 0.1, zc + r + 0.1))][::s],
                     12, t=0.004)
    if ladder:
        P2.ladder(g, V((x, y0 - r * 0.6, 0.0)), V((0, -1, 0)), 0.0, zc + r + 0.03, 0.14, M)
    # jauge de niveau verticale (verre ambré) au sud-ouest, vanne à volant rouge à l'extrémité nord
    p = V((x - r * 0.75, y0 + 0.12, zc))
    g.box(p, (0.02, 0.05, r * 1.3), M["emit_soft"], "flat", what="jauge")
    for s in (-1, 1):
        g.box(p + V((-0.006, s * 0.035, 0)), (0.024, 0.016, r * 1.4), M["steel_hi"], "hard", what="cadre")
    g.cyl((x, y1 + r * 0.25 + 0.06, zc - r * 0.4), (0, 1, 0), 0.04, 0.12, M["galva"], n=12, what="piquage")
    P2.handwheel(g, (x, y1 + r * 0.25 + 0.06, zc - r * 0.4 + 0.1), (0, 0, 1), 0.07, M, mat=M["redpaint"])


def socle_petrol(g, k):
    M = g.M
    E = M["emit"]
    fuel_tank(g, -1.12, -0.7, 0.86, 0.3, M, E)
    fuel_tank(g, 1.14, -0.42, 0.36, 0.27, M, E, ladder=False)
    # sud-est (devant la 2e cuve) : GROUPE DE FÛTS de 200 L (passe 5 : diamètre 0,3 t, au lieu de 0,22 ; jaune, un
    # rouge), lisibles au zoom 1 comme des fûts et pas comme des cuves
    for i, (x, yn) in enumerate(((0.98, -0.7), (1.3, -0.7), (1.14, -0.98), (0.82, -1.0))):
        F.drum(g, (x, Y(yn), 0.0), 0.15, 0.4, M["redpaint"] if i == 1 else M["yellowpaint"], M["hazk"])
    # nord-ouest : groupe de pompage (moteur, 2 vannes à volant rouge)
    PT.hull(g, -1.42, -0.86, Y(1.0), Y(1.4), 0.0, 0.3, ins=(0.03, 0.03, 0.03), panel=0.24,
            mats=[M["yellowpaint"], M["steel_dk"]], rivet_step=0.12)
    g.cyl((-1.14, Y(1.2), 0.4), "x", 0.1, 0.4, M["galva"], n=20, what="moteur")
    for kk in range(6):
        g.tube_shell((-1.3 + kk * 0.06, Y(1.2), 0.4), "x", 0.118, 0.09, 0.014, M["steel_hi"], n=20, what="ailette")
    for xx in (-1.36, -0.92):
        P2.handwheel(g, (xx, Y(1.0) - 0.05, 0.36), (0, -1, 0.2), 0.075, M, mat=M["redpaint"])
    # ronde 2 (silhouette d'âge, juges : « torchère à flamme ») : TORCHÈRE haute au coin nord-ouest, posée sur le
    # groupe de pompage : fût galvanisé à bagues de danger, passerelle ronde, brûleur noirci, grande flamme orange.
    # Sommet sous h_max (0,76, accroches.py) : la tête qui tourne passe au-dessus.
    torchere(g, -1.36, Y(1.34), 0.3, 0.74, M, E)
    # nord : rampe de 3 conduites galvanisées sur supports, vannes rouges
    for i in range(3):
        yy = Y(1.22) + (i - 1) * 0.1
        g.cyl((0.0, yy, 0.22), "x", 0.038, 1.5, M["galva"], n=12, what="conduite")
    g.box((0.0, Y(1.22), 0.08), (1.5, 0.3, 0.16), M["steel_dk"], "hard", what="massif")
    for xx in (-0.6, 0.0, 0.6):
        g.box((xx, Y(1.22), 0.1), (0.05, 0.34, 0.2), M["steel_dk"], "hard", what="support")
    P2.handwheel(g, (0.3, Y(1.22) - 0.1, 0.32), (0, 0, 1), 0.065, M, mat=M["redpaint"])
    # liaisons galvanisées (vannes rouges)
    link(g, 4, [(-0.82, Y(0.1), 0.3), (-0.8, Y(0.06), 0.46), (-0.66, Y(0.04), 0.56)], 0.06)
    link(g, 4, [(0.87, Y(0.2), 0.3), (0.8, Y(0.24), 0.48), (0.66, Y(0.2), 0.56)], 0.06)
    g.hose([(1.0, Y(-0.55), 0.3), (0.9, Y(-0.4), 0.42), (0.7, Y(-0.38), 0.5)], 0.035, M["rubber"])
    F.lamp_group(g, (-1.36, Y(1.0) - 0.02, 0.22), (1, 0, 0), (0, -1, 0), E, n=2)
    # passe 4 : voyants orange de plus (au plus 3 alignés, un groupe par machine : catalogue §A.6)
    F.lamp_group(g, (0.32, Y(1.22) - 0.16, 0.14), (1, 0, 0), (0, -1, 0), E, n=3)
    F.lamp_group(g, (-0.45, Y(1.22) - 0.16, 0.14), (1, 0, 0), (0, -1, 0), E, n=2)

    g.halo((-1.1, Y(1.0), 0.4), M["_emit_rgb"], 10.0)


def torchere(g, x, y, z0, z1, M, E):
    """Torchère de plate-forme pétrolière (ronde 2) : fût galvanisé, 2 bagues de danger, passerelle ronde pleine (une
    passerelle ajourée enfermerait du sol), brûleur noirci, flamme orange en 2 cônes et halo."""
    h = z1 - z0
    g.cyl((x, y, z0 + 0.02), "z", 0.07, 0.04, M["steel_dk"], n=16, what="embase")
    F.bolts_ring(g, (x, y, z0 + 0.04), (0, 0, 1), 0.055, 6, M["rivet"], r=0.011)
    g.cyl((x, y, z0 + h / 2), "z", 0.034, h, M["galva"], n=14, what="fut_torchere")
    for f in (0.3, 0.62):
        F.hazard_ring(g, (x, y, z0 + h * f), "z", 0.037, 0.05, n=10)
    g.cyl((x, y, z0 + h * 0.8), "z", 0.075, 0.018, M["grate"], n=16, what="passerelle")
    g.tube_shell((x, y, z0 + h * 0.8 + 0.03), "z", 0.078, 0.07, 0.05, M["galva"], n=16, what="garde_corps")
    g.cyl((x, y, z1 - 0.02), "z", 0.05, 0.05, M["soot"], n=12, what="bruleur")
    g.cyl((x, y, z1 + 0.07), "z", 0.065, 0.14, E, n=10, r2=0.016, what="flamme")
    g.cyl((x + 0.015, y, z1 + 0.18), "z", 0.034, 0.1, E, n=8, r2=0.004, what="flamme")
    g.halo((x, y, z1 + 0.1), M["_emit_rgb"], 9.0)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduite galvanisée à brides, vanne à volant rouge au milieu
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » du pétrole)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    g.pipe(P, r * 0.8, M["galva"], fl_mat=M["steel_dk"], bolt_mat=M["rivet"])
    S_ = g.spline(P, 8)
    i = len(S_) // 2
    g.cyl(S_[i], (S_[i + 1] - S_[i - 1]), r * 1.25, r * 1.6, M["steel_dk"], n=12, style="hard", what="vanne")
    P2.handwheel(g, S_[i] + V((0, 0, r * 1.25 + 0.06)), (0, 0, 1), max(0.045, r * 1.1), M)
    return P


def arch_hose(g, e, p0, p1, lift, r):
    """Liaison de la tête qui PASSE PAR-DESSUS la coupole (visible à toutes les poses), dans le style d'époque."""
    p0, p1 = V(p0), V(p1)
    m = (p0 + p1) / 2
    m.z = max(p0.z, p1.z) + lift
    q0 = p0.lerp(m, 0.5)
    q0.z = m.z - lift * 0.25
    q1 = m.lerp(p1, 0.5)
    q1.z = m.z - lift * 0.25
    return link(g, e, [p0, q0, m, q1, p1], r, kind="arch")


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 8 : 2 cuves-chargeurs couchées sur berceau, passerelle et garde-corps
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    M = g.M
    E = M["emit"]
    side = c.side
    cx = c.T["piece"]["x"]
    cy = -cx
    for sx in (-1, 1):
        xa, xb = sorted((sx * (cx - 0.3 - 0.07 * side), sx * (cx + 0.2 + 0.03 * side)))
        corps.dalle(g, xa, xb, Y(cy - 0.24 - 0.02 * side), Y(cy + 0.34 + 0.06 * side))
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
        F.lamp_group(g, (x - 0.08, y + 0.05, 0.47), (1, 0, 0), (0, 0, 1), E, n=2)
    _halo(g, [(-cx, Y(cy), 0.3), (cx, Y(cy), 0.3)], 8.0)


# ------------------------------------------------------------------------------------------------
# Arme (E1) : gatling galvanisée et gros fût-chargeur couché
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    M = g.M
    H = c.H
    w_petrol(g, ST, H, x, sx)
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


def w_petrol(g, st, H, x, sx):
    """Époque 4 : gatling à jaquette galvanisée perforée, alimentée par un GROS FÛT-CHARGEUR couché le long du flanc
    extérieur (jaune délavé, bagues de danger jaune et noire, sangles, bouchon), flexible noir vers la culasse."""
    M = g.M
    st2 = dict(st, feed="none")
    w_gatling(g, st2, H, x, sx)
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    r = 0.155
    Lb = H["L"] * 0.62
    rs = H["rr"] + H["rb"] + 0.028
    c = V((x + sx * (max(wr / 2, rs + 0.03) + r + 0.005), y0 + 0.05 + Lb / 2, zg + 0.01))
    g.box(c - V((sx * r * 0.45, 0, r * 0.55)), (r * 1.7, Lb * 0.9, r * 0.95), M["steel_dk"], "hard", what="berceau")
    g.cyl(c, "y", r, Lb, M["yellowpaint"], n=28, what="fut")
    for f in (-0.5, 0.5):
        g.cyl(c + V((0, f * (Lb + 0.02), 0)), "y", r * 0.9, 0.03, M["yellowpaint"], n=28, what="fond")
        g.tube_shell(c + V((0, f * Lb, 0)), "y", r + 0.012, r - 0.01, 0.028, M["steel_dk"], n=28, what="sertissage")
    for f in (-0.22, 0.22):
        F.hazard_ring(g, c + V((0, f * Lb, 0)), (0, 1, 0), r + 0.002, 0.07, n=12)
    for f in (-0.38, 0.0, 0.38):
        g.tube_shell(c + V((0, f * Lb, 0)), "y", r + 0.018, r + 0.002, 0.022, M["steel_dk"], n=28, what="sangle")
    g.cyl(c + V((sx * r * 0.3, Lb / 2 + 0.03, r * 0.45)), "y", 0.026, 0.04, M["redpaint"], n=10, what="bouchon")
    g.box(c + V((0, 0, r + 0.025)), (0.035, Lb * 0.34, 0.025), M["steel_hi"], "hard", what="poignee")
    g.hose([c + V((-sx * r * 0.6, -Lb / 2 + 0.03, r * 0.2)), V((x + sx * wr * 0.55, y0 + 0.02, zg + 0.03)),
            V((x + sx * wr * 0.4, y0 + 0.08, zg + 0.04))], 0.03, M["rubber"], step=0.03)


def gun_e(g, st, H, x, side):
    """Faisceau de la lignée (corps.rosette), jaquette et bouche de l'époque ; renvoie le rayon de jaquette."""
    M = g.M
    y1 = H["recv"][1]
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    zg = H["zg"]
    rs = rr + rb + 0.028
    pos = corps.rosette(g, x, y1, zg, L, nb, rb, rr, mat=M[st.get("barrel", "gun")], collier_mat=M[st["band"]],
                        colliers=st.get("collars", (0.8,)), bouts=False)
    Lj = L * min(st.get("jacket_f", 0.62), corps.JAQUETTE_MAX)
    jk_perforated(g, st, x, y1, zg, Lj, rs, H, mat="acier_canon")
    br_slots(g, st, x, y1 + L, zg, rs, pos, H)
    return rs


def jk_perforated(g, st, x, y0, z, Lj, rs, H, mat=None, coils=0):
    """Époques 4 et 6 : tôle perforée (galvanisée à l'époque 4), bobines de cuivre annulaires à l'époque 6."""
    M = g.M
    m = M[mat or st.get("jacket_mat", "steel")]
    g.cyl((x, y0 + Lj / 2, z), "y", rs, Lj, m, n=28, style="smooth", what="jaquette")
    nh_ax = max(2, int((Lj - 0.1) / 0.06))
    nh_ang = max(8, int(TAU * rs / 0.07))
    for i in range(nh_ax):
        for j in range(nh_ang):
            a = TAU * j / nh_ang + (0.5 * TAU / nh_ang if i % 2 else 0.0)
            d = V((math.cos(a), 0.0, math.sin(a)))
            if d.z < -0.45:
                continue
            p = V((x, y0 + 0.07 + (Lj - 0.14) * (i + 0.5) / nh_ax, z)) + d * (rs + 0.002)
            g.cyl(p, d, 0.016, 0.006, M["void"], n=6, style="flat", what="trou")
    for yy in (y0 + 0.03, y0 + Lj - 0.02):
        g.tube_shell((x, yy, z), "y", rs + 0.022, rs - 0.01, 0.05, M[st["band"]], n=28, what="bague")
        F.bolts_ring(g, (x, yy, z), (0, 1, 0), rs + 0.024, 6, M["rivet"], r=0.015, phase=0.2, skip_down=-0.3)
    # époque 6 : 3 BOBINES de cuivre larges et épaisses (spires jointives), séparées par des disques isolateurs en
    # céramique patinée : cuivre + crème, la paire de l'électricité (jamais de bague blanche, catalogue §B.6)
    for k in range(coils):
        yc = y0 + Lj * (0.22 + 0.56 * k / max(1, coils - 1)) if coils > 1 else y0 + Lj * 0.5
        g.tube_shell((x, yc, z), "y", rs + 0.032, rs - 0.01, 0.1, M["steel_dk"], n=28, what="bobine")
        for t in range(7):
            g.torus((x, yc - 0.042 + t * 0.014, z), "y", rs + 0.04, 0.0085, M["copper"], n=28, m=6, what="spire")
        for s in (-1, 1):
            g.tube_shell((x, yc + s * 0.066, z), "y", rs + 0.056, rs - 0.01, 0.018, M["accent"], n=28,
                         what="isolateur")


def br_slots(g, st, x, yb, z, rs, pos, H):
    """Époque 4 : frein de bouche à 2 fentes latérales, acier galvanisé."""
    M = g.M
    rb = H["rb"]
    # passe 5 (règle d'or 7, pose N) : le bloc à oreilles deux fois plus large que le faisceau (« T » plat, chapeau de
    # cheminée en pose N) est remplacé par un frein ROND au diamètre de la jaquette : 2 fentes de chaque côté, bague de
    # danger, face avant à rosace éclairée (bouts de tubes vus en bout)
    # ronde 3 (pose N, 4 lu « cheminée » à la ronde 2) : frein et jaquette en ACIER NU CLAIR (règle d'or 7 du kit), au
    # lieu du galvanisé devenu noir
    w = rs * 2.0
    g.cyl((x, yb + 0.07, z), "y", rs, 0.15, M["acier_canon"], n=28, style="soft", what="frein")
    for s in (-1, 1):
        for k in range(2):
            g.box((x + s * (rs - 0.004), yb + 0.03 + k * 0.08, z), (0.014, 0.045, rs * 0.9), M["void"], "flat",
                  what="fente")
    F.hazard_ring(g, (x, yb + 0.025, z), (0, 1, 0), rs + 0.004, 0.035, n=12)
    g.cyl((x, yb + 0.15, z), "y", rs - 0.012, 0.012, M["acier_canon"], n=28, what="face")
    F.bores(g, x, yb + 0.157, z, pos, rb, M["steel_hi"])
    F.lit_ring(g, (x, yb + 0.158, z), "y", rs - 0.014, M["emit"])


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) peinte en jaune délavé, bandes noires de danger écaillées."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    T = PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)
    zc = z1 + 0.012
    for k in range(3):
        yy = y0 + (y1 - y0) * (0.2 + 0.3 * k)
        g.box((x, yy, zc + 0.002), (w * 0.9, 0.04, 0.008), M["hazk"], "flat", what="bande")
    return T


def drive(g, st, c, r, L):
    """Organe arrière du canon : moteur de la lignée (carter, ailettes, flasque boulonnée, moyeu)."""
    M = g.M
    x, y, z = c
    body = M[st.get("drive_mat", "steel_dk")]
    g.cyl((x, y, z), "y", r, L, body, n=28, style="soft", phase=math.pi / 8, what="moteur")
    nf = int((L * 0.5) / 0.045)
    fm = M[st.get("fin_mat", "steel_hi")]
    for kk in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + kk * 0.045, z), "y", r + 0.026, r - 0.01, 0.014, fm, n=28, what="ailette")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M[st.get("flange_mat", "olive")], n=24, style="soft",
          what="flasque")
    F.bolts_ring(g, (x, y - L / 2 - 0.06, z), (0, -1, 0), r * 0.66, 8, M["rivet"], r=0.016)
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M[st["band"]], n=12, what="moyeu")


def feed(g, st, H, x, sx, xo):
    """Pas d'alimentation séparée : w_petrol pose le gros fût-chargeur couché sur le flanc (passe 3 : st2 feed=none)."""
    return None


# ------------------------------------------------------------------------------------------------
# Masque, nacelle, tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=ST["gmask"], fentes=((0.0, 1.1),), visiere=("steel_dk", 0.03))


def nacelle(g, c):
    """Deux échappements et une petite TORCHÈRE (tige fine, brûleur, flamme ≤ 0,05 t²)."""
    M = g.M
    bx, yb0, yb1, ztop, yc = c.nac
    for sx in (-1, 1):
        PT.exhaust(g, (sx * bx * 0.7, yc - 0.05, ztop), 0.045, 0.2)
    flare(g, (0.0, yb0 + 0.1, ztop), 0.24, M["emit"])


def flare(g, c, h, emat):
    """Petite torchère (pétrole) : tige fine, brûleur, flamme (≤ 0,05 t²)."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + h / 2), "z", 0.018, h, M["galva"], n=8, what="tige")
    g.cyl((x, y, z + h + 0.02), "z", 0.03, 0.04, M["soot"], n=10, what="bruleur")
    g.cyl((x, y, z + h + 0.07), "z", 0.024, 0.08, emat, n=8, r2=0.004, what="flamme")
    g.box((x, y, z + 0.04), (0.08, 0.08, 0.02), M["steel_dk"], "hard", what="pied")


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    side = c.side
    k = KIN
    F.slits(g, R, c.rt + 0.1 + 0.02 * side, 5, M["emit"], a0=math.pi * 0.62, span=math.pi * 1.76)
    F.voyants_tete(g, H, 6)
    zt = H["zs"] + H["rz"] * 0.42
    for sx in (-1, 1):
        arch_hose(g, EPOQUE, (sx * 0.15, -R - 0.06, zt + 0.02),
                  (sx * (H["gx"] - 0.03), H["recv"][0] + 0.1, H["zg"] + H["hr"] + 0.03),
                  0.1 + 0.03 * (side - 2), 0.034 + 0.008 * (side - 2))
    PT.sight(g, (R * 0.2, R * 0.45, H["zs"] + H["rz"] * 0.6), 0.16 + 0.04 * (side - 3), 0.18, 0.1, M["emit"],
             lenses=side - 2)
    appl = M[ST["appl"]]
    n1 = {0: 3, 1: 6, 2: 8}[k] + (side - 2)
    for i in range(n1):
        th = 0.45 + (math.pi - 0.9) * (i + 0.5) / n1
        P2.applique(g, c.Pf, c.Nf, th, 0.3, 0.22 + 0.03 * (side - 2), 0.18 + 0.03 * (side - 2), appl, M)
    # signature de coupole : bague de danger jaune et noire
    F.hazard_ring(g, (0, 0, H["zs"] + 0.035), "z", R * 1.03, 0.07, n=max(16, int(TAU * R / 0.14)))
