"""Époque 7 · Cristal (ère III, 4×4, niveaux 13 et 14). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 7) : « bronze, cristaux, violet ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py, kit.py).
Corrections de design de la QUATRIÈME PASSE (23/10, constructeur de la plage basse) :
  - (époque bien lue : gardée) jaquette à la moitié arrière ; grappe nord-est déplacée (trou enfermé de 19 à 42 px
    en pose E) ; trémie en laiton ; éclats de cristal et ancrage boulonné sur les focalisateurs.
Emplacements remplis : arme (gatling de bronze à 6 tubes terminée par un GROS PRISME DE CRISTAL tenu par 3 griffes,
moteur à bague de pierre et cristal, chargeurs à étuis de cristal), grands volumes du socle (grandes grappes de
cristal sur socles de pierre, résonateur, bassins), liaisons (guides d'onde de bronze à section carrée), nacelle
(grappe de cristaux), cristaux sertis sur la coupole, foyers violets, pièce paire (2 focalisateurs à cristal).
"""
import math
import random

from mathutils import Matrix, Vector

import corps
import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from corps import Y, at
from kit import SQ2, TAU, axv, basis

V = Vector

EPOQUE = 7
NOM = "Cristal"
KIN = 0   # rang dans l'ère III
FOYER = dict(rgb=(0.69, 0.44, 1.0), doux=dict(force=0.8, base=(0.07, 0.035, 0.1)))
CANON = dict(L=1.6, nb=6, rb=0.05, rr=0.125)
# passe 5, ronde 1 (consigne du DC du 23/10 : TOUT le bâtiment change d'âge ; l'ère III monte d'un cran en clarté) :
# un SANCTUAIRE : pont de DALLES de pierre claire (calcaire) à joints violet sombre, bordé d'un liseré LUMINEUX
# violet ; coupole et capots de BRONZE doré clair ; plaques de pierre claire ; acier de structure en bronze sombre ;
# rivets de bronze clair ; bandes de bronze et de pierre (aucune bande de danger jaune et noire).
HABILLAGE = dict(jupe_cerclage="bronze_clair", tremie="brass", pochoirs=False, munitions=("bronze", "emit_soft"),
                 grille_nacelle="bronze_capot", chapeau="bronze_clair", capots=("bronze_capot", "pierre_claire"),
                 acier=("bronze_sombre", "bronze_clair"), rivets="bronze_clair", joints="joint_violet",
                 danger=("pierre_claire", "bronze_sombre"), peinture="bronze_sombre", tourelleau="pierre_claire",
                 plateforme=dict(motif="dalles", pas=0.36, joint=0.014, mat="pierre_claire", mat2="pierre_claire2",
                                 fond="joint_violet", bord="bronze_capot", boulons=None, lisere="emit_soft",
                                 relief=0.3))
ST = dict(jacket="bronze", brake="claws", drive="crystal", drive_mat="bronze", fin_mat="bronze", band="bronze",
          barrel="bronze", recv_mats=("bronze", "stone"), recv_sig="stone", feed="crystal_mag", skirt="bronze",
          appl="bronze_capot", gmask=("bronze", "olive"), arm=("stone", "olive"), cap="bronze", flange_mat="stone",
          col=("olive", "stone"), nac=("olive", "bronze"))


def matieres(metal, M):
    """Test noir et blanc de la passe 3 : la pierre des grands aplats est plus sombre (× 0,85)."""
    metal("stone", (0.075, 0.056, 0.044), rough=0.85, met=0.0, grain=0.5 * 0.62, gscale=26.0, dirt=0.9, stain=0.8,
          stain2=0.32, sscale=5.0, wear=2.2, tone=0.85)
    # passe 5 : matières du CORPS du sanctuaire (pierre claire non métallique, bronze peu métallique)
    # ronde 2 (test des écarts de la ronde 1 : le cristal jugé PLUS évolué que le marais et que l'atome, « cristaux et
    # or, dalle blanche ») : premier âge de l'ère III, il descend d'un cran : pierre de grès gris-mauve plus sombre
    # (plus de dalle blanche), bronze patiné brun au lieu du bronze doré ; les cristaux violets restent la signature
    # (essai a : 0,33 se lisait encore « dalle blanche » au zoom 1 ; 0,22)
    metal("pierre_claire", (0.22, 0.2, 0.21), rough=0.85, met=0.0, grain=0.32, gscale=26.0, dirt=0.8, stain=0.55,
          sscale=5.0, wear=0.8, mottle=0.35)
    metal("pierre_claire2", (0.185, 0.168, 0.176), rough=0.85, met=0.0, grain=0.32, gscale=26.0, dirt=0.8, stain=0.55,
          sscale=5.0, wear=0.8, mottle=0.35)
    metal("bronze_capot", (0.38, 0.23, 0.1), rough=0.4, met=0.45, grain=0.14, gscale=30.0, rust=(0.1, 0.2, 0.14),
          ra=0.12, dirt=0.65, stain=0.4, sscale=5.0, wear=0.9)
    metal("bronze_sombre", (0.16, 0.095, 0.045), rough=0.4, met=0.45, grain=0.15, rust=(0.1, 0.2, 0.14), ra=0.1,
          dirt=0.7, stain=0.4, wear=1.2)
    # ronde 3 (test des écarts de la ronde 2 : le cristal encore jugé plus évolué que le marais et l'atome, « dôme doré »)
    # : bronze clair moins doré, plus patiné ; les cristaux violets restent la signature
    metal("bronze_clair", (0.5, 0.33, 0.15), rough=0.36, met=0.45, grain=0.05, dirt=0.25, stain=0.0, reflet="fin")
    metal("joint_violet", (0.06, 0.025, 0.08), rough=0.7, met=0.0, grain=0.1, dirt=0.3, stain=0.0)


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : grandes grappes de cristal, résonateur de pierre, bassins de bronze
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=3)
    socle_crystal(g, KIN)
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def cluster(g, x, y, s, M, seed=0, plinth=True, n=6):
    """Grappe de cristaux taillés (matière cristal opaque violet sombre, cœurs lumineux étroits) sur socle de
    pierre octogonal à couronne de bronze et griffes."""
    rng = random.Random(seed)
    if plinth:
        g.cyl((x, y, 0.06), "z", 0.42 * s, 0.12, M["stone"], n=8, style="hard", phase=math.pi / 8, what="socle")
        g.tube_shell((x, y, 0.14), "z", 0.36 * s, 0.26 * s, 0.05, M["bronze"], n=8, what="couronne")
        for kk in range(8):
            a = TAU * kk / 8
            g.dome((x + math.cos(a) * 0.31 * s, y + math.sin(a) * 0.31 * s, 0.17), (0, 0, 1), 0.02, M["brass"])
    z0 = 0.14 if plinth else 0.0
    g.cyl((x, y, z0 + 0.03), "z", 0.26 * s, 0.06, M["stone"], n=8, style="hard", what="gangue")
    specs = [(0.0, 0.0, 0.95, 0.12, 0.0, 0.0)]
    for i in range(1, n):
        a = TAU * i / (n - 1) + rng.uniform(-0.3, 0.3)
        specs.append((math.cos(a) * 0.15, math.sin(a) * 0.15, rng.uniform(0.42, 0.7), rng.uniform(0.06, 0.09), a,
                      rng.uniform(0.3, 0.55)))
    for dx, dy, h, r, a, tilt in specs:
        d = V((math.cos(a) * math.sin(tilt), math.sin(a) * math.sin(tilt), math.cos(tilt)))
        base = V((x + dx * s, y + dy * s, z0 + 0.02))
        # cristaux hauts : lumière douce violette (chacun < 0,1 t², catalogue : ≤ 0,45 t²) ; les petits restent sombres
        F.crystal(g, base, d, r * s, h * s, M["emit_soft"] if h > 0.5 else M["crystal"])


def socle_crystal(g, k):
    M = g.M
    E = M["emit"]
    cluster(g, -1.42, Y(1.3), 1.0, M, seed=7)
    # passe 4 : grappe nord-est poussée dans le coin et posée plus bas (le sol se voyait entre ses pointes et le canon
    # nord en pose E : trou enfermé de 19 à 42 px hr)
    cluster(g, 1.52, Y(1.46), 0.78, M, seed=11, n=5)
    # ouest : résonateur (bloc de pierre taillée, arche de bronze, lentille-cristal couchée)
    PT.hull(g, -1.92, -1.3, Y(-0.7), Y(0.6), 0.0, 0.3, ins=(0.03, 0.03, 0.03), panel=0.28,
            mats=[M["stone"], M["stone"]], rivets=False, rivet_step=0.2)
    for s in (-1, 1):
        g.box((-1.61, Y(-0.05) + s * 0.55, 0.48), (0.08, 0.08, 0.36), M["bronze"], "hard", what="montant")
        g.dome((-1.61, Y(-0.05) + s * 0.55, 0.67), (0, 0, 1), 0.03, M["brass"])
    g.box((-1.61, Y(-0.05), 0.62), (0.1, 1.18, 0.06), M["bronze"], "hard", what="linteau")
    F.crystal(g, (-1.61, Y(-0.05) - 0.45, 0.46), (0, 1, 0), 0.11, 0.9, M["emit_soft"], tip=0.25, n=6)
    for s in (-1, 1):
        g.tube_shell((-1.61, Y(-0.05) + s * 0.22, 0.46), (0, 1, 0), 0.14, 0.1, 0.05, M["bronze"], n=6, what="bague")
    # est : 2 bassins octogonaux de bronze, cristaux qui y poussent
    for (yn, sd) in ((0.55, 3), (-0.45, 5)):
        g.cyl((1.55, Y(yn), 0.1), "z", 0.3, 0.2, M["bronze"], n=8, style="hard", phase=math.pi / 8, what="bassin")
        g.tube_shell((1.55, Y(yn), 0.2), "z", 0.32, 0.25, 0.04, M["brass"], n=8, what="levre")
        g.cyl((1.55, Y(yn), 0.195), "z", 0.25, 0.01, M["stone"], n=8, style="flat", what="lit")
        cluster(g, 1.55, Y(yn), 0.62, M, seed=sd, plinth=False, n=5)
    # guides d'onde de bronze vers la colonne
    link(g, 7, [(-1.2, Y(1.1), 0.3), (-1.0, Y(0.9), 0.6), (-0.8, Y(0.66), 0.8)], 0.06)
    link(g, 7, [(1.2, Y(1.1), 0.3), (1.0, Y(0.9), 0.6), (0.8, Y(0.66), 0.8)], 0.06)
    link(g, 7, [(-1.3, Y(0.0), 0.3), (-1.2, Y(0.0), 0.6), (-1.0, Y(-0.05), 0.72)], 0.06)
    link(g, 7, [(1.3, Y(0.05), 0.3), (1.22, Y(0.05), 0.6), (1.02, Y(0.05), 0.72)], 0.06)
    for i, (xx, yn) in enumerate(((-1.0, -0.95), (1.0, -0.95), (-1.6, 0.75), (1.62, 0.95), (-0.7, 1.7),
                                  (0.7, 1.7), (-1.75, -0.95), (-0.55, -1.75), (0.6, -1.8))):
        g.cyl((xx, Y(yn), 0.06), "z", 0.06, 0.04, M["bronze"], n=6, style="hard", what="sertissure")
        F.crystal(g, V((xx, Y(yn), 0.07)), (0.2 * ((i % 3) - 1), 0.15, 1), 0.035, 0.16, M["emit_soft"], tip=0.4)
        for k in range(3):
            a = TAU * k / 3
            g.dome((xx + math.cos(a) * 0.05, Y(yn) + math.sin(a) * 0.05, 0.085), (0, 0, 1), 0.013, M["brass"])
    g.halo((-1.42, Y(1.3), 0.8), M["_emit_rgb"], 14.0)
    g.halo((1.42, Y(1.3), 0.8), M["_emit_rgb"], 12.0)
    g.halo((1.55, Y(0.05), 0.5), M["_emit_rgb"], 10.0)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : guide d'onde de bronze à section carrée, joints cannelés, coudes à 45°
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » du cristal)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        d = b - a
        Rr = F.Ry(d)
        g.box((a + b) / 2, (r * 1.7, d.length, r * 1.7), M["bronze"], "hard", R=Rr, what="guide")
        n = max(1, int(d.length / 0.16))
        for k in range(n + 1):
            q = a + d * (k / n)
            g.box(q, (r * 2.1, 0.03, r * 2.1), M["brass"] if k % 2 else M["stone"], "hard", R=Rr, what="joint")
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
# Pièce du niveau 14 : 2 focalisateurs à cristal (affût de bronze sur plinthe de pierre, grappe de 3 cristaux)
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    side = c.side
    cx = c.T["piece"]["x"]
    cy = -cx
    s = c.T["piece"]["s"]
    for sx in (-1, 1):
        xa, xb = sorted((sx * (cx - 0.3 - 0.07 * side), sx * (cx + 0.2 + 0.03 * side)))
        corps.dalle(g, xa, xb, Y(cy - 0.24 - 0.02 * side), Y(cy + 0.34 + 0.06 * side))
    for sx in (-1, 1):
        with at(g, sx * cx, cy, sx * -0.25):
            focaliser(g, (0, 0, 0), 0.0, 1.3 * s)
            _ancrage(g, 0.19 * 1.5 * s, 0.082 * 1.5 * s, g.M, n=22)
            # éclats de cristal sertis autour de l'affût (petits foyers violets, sertissures de bronze)
            for k in range(5):
                a = math.pi * (0.15 + 0.7 * k / 4)
                xx, yy = math.cos(a) * 0.36, math.sin(a) * 0.36
                g.cyl((xx, yy, 0.06), "z", 0.05, 0.04, g.M["bronze"], n=6, style="hard", what="sertissure")
                F.crystal(g, V((xx, yy, 0.075)), (0.15 * ((k % 3) - 1), 0.1, 1), 0.03, 0.13, g.M["emit_soft"], tip=0.4)
                for j in range(3):
                    b = TAU * j / 3
                    g.dome((xx + math.cos(b) * 0.045, yy + math.sin(b) * 0.045, 0.082), (0, 0, 1), 0.016,
                           g.M["brass"])
    _halo(g, [(-cx, Y(cy), 0.5), (cx, Y(cy), 0.5)], 12.0)


def _ancrage(g, R, z, M, n=14, pieds=4):
    """Passe 4 : semelle d'ancrage de la pièce paire (couronne de boulons, pattes boulonnées au caillebotis) : la pièce
    ne fait plus BAISSER le nombre de petites pièces du niveau pair (contrôle impair -> pair de dominance.py)."""
    F.bolts_ring(g, (0, 0, z), (0, 0, 1), R, n, M["steel_hi"], r=0.026)
    for k in range(pieds):
        a = TAU * (k + 0.5) / pieds
        d = V((math.cos(a), math.sin(a), 0))
        p = d * (R + 0.09)
        g.box((p.x, p.y, 0.015), (0.1, 0.1, 0.03), M["steel_dk"], "hard", R=Matrix.Rotation(a, 3, "Z"), what="patte")
        for j in (-1, 1):
            q = p + V((-d.y, d.x, 0)) * 0.03 * j
            g.dome((q.x, q.y, 0.032), (0, 0, 1), 0.024, M["steel_hi"])


def focaliser(g, c, rz, s=1.0):
    """Focalisateur à cristal (cristal) : plinthe de pierre, affût de bronze, grappe de 3 cristaux vers l'avant."""
    M = g.M
    g.push(c, rz=rz)
    F.prism(g, [(-0.16 * s, -0.16 * s), (0.16 * s, -0.16 * s), (0.16 * s, 0.16 * s), (-0.16 * s, 0.16 * s)], 0.0,
          0.08 * s, M["stone"])
    g.box((0, 0, 0.1 * s), (0.22 * s, 0.22 * s, 0.05 * s), M["bronze"], "hard", what="affut")
    for k in range(4):
        a = TAU * k / 4 + math.pi / 4
        g.dome((math.cos(a) * 0.09 * s, math.sin(a) * 0.09 * s, 0.125 * s), (0, 0, 1), 0.016, M["brass"])
    for k, (dx, h, r) in enumerate(((0.0, 0.3, 0.05), (-0.07, 0.22, 0.038), (0.07, 0.22, 0.038))):
        d = V((dx * 2.0, -0.55, 1)).normalized()
        base = V((dx * s, 0.02 * s, 0.12 * s))
        g.cyl(base + d * h * s * 0.38, d, r * s, h * s * 0.76, M["emit"], n=6, style="hard", what="cristal")
        g.cyl(base + d * h * s * 0.88, d, r * s, h * s * 0.24, M["emit"], n=6, r2=0.004, style="hard", what="pointe")
        g.tube_shell(base + d * 0.03, d, r * s + 0.015, r * s - 0.005, 0.03, M["bronze"], n=12, what="sertissure")
    g.pop()


# ------------------------------------------------------------------------------------------------
# Arme (E1) : gatling de bronze au prisme de cristal
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    M = g.M
    H = c.H
    w_crystal(g, ST, H, x, sx)
    y0 = H["recv"][0]
    PT.lamp(g, (x - sx * H["wr"] * 0.25, y0 + 0.1, H["zg"] + H["hr"] + 0.03), (0, 0.4, 1), 0.026, M["emit"],
            cage=False)


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


def w_crystal(g, st, H, x, sx):
    """Époque 7 : gatling de bronze à 6 tubes, terminée par un GROS PRISME DE CRISTAL tenu par 3 griffes."""
    M = g.M
    st2 = dict(st, brake="none")
    w_gatling(g, st2, H, x, sx)
    zg = H["zg"]
    rs = H["rr"] + H["rb"] + 0.028
    yb = H["recv"][1] + H["L"]
    ro = rs + 0.03
    g.tube_shell((x, yb + 0.02, zg), "y", ro, H["rr"] * 0.3, 0.1, M["bronze"], n=28, what="couronne")
    g.tube_shell((x, yb + 0.075, zg), "y", ro + 0.012, ro - 0.025, 0.02, M["brass"], n=28, what="levre")
    pos = [(x + H["rr"] * math.cos(0.3 + TAU * i / H["nb"]), zg + H["rr"] * math.sin(0.3 + TAU * i / H["nb"]))
           for i in range(H["nb"])]
    F.bores(g, x, yb + 0.072, zg, pos, H["rb"], M["bronze"])
    F.lit_ring(g, (x, yb + 0.087, zg), "y", ro + 0.006, M["emit"])
    rc = 0.17
    ly = yb + 0.12
    g.cyl((x, (yb + 0.08 + ly + 0.04) / 2, zg), "y", ro - 0.02, ly + 0.04 - (yb + 0.08), M["bronze"], n=12,
          r2=rc * 0.95, what="nez")
    g.cyl((x, ly + 0.02, zg), "y", rc * 0.85, 0.06, M["stone"], n=6, style="hard", what="sertissure")
    F.crystal(g, V((x, ly + 0.04, zg)), (0, 1, 0), rc, 0.52, M["emit_soft"], tip=0.35, n=6, what="prisme")

    for k in range(3):
        a = math.pi / 2 + TAU * k / 3
        d = V((math.cos(a), 0, math.sin(a)))
        p0 = V((x, yb + 0.07, zg)) + d * (ro - 0.01)
        p1 = V((x, ly + 0.2, zg)) + d * (rc * 0.95)
        g.cyl((p0 + p1) / 2, p1 - p0, 0.022, (p1 - p0).length, M["bronze"], n=6, style="hard", what="griffe")
        g.dome(p1, d, 0.024, M["brass"])


def gun_e(g, st, H, x, side):
    """Faisceau de la lignée (corps.rosette) en bronze, jaquette ciselée de l'époque ; la bouche (couronne à griffes et
    prisme) est posée par w_crystal ; renvoie le rayon de jaquette."""
    M = g.M
    y1 = H["recv"][1]
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    zg = H["zg"]
    rs = rr + rb + 0.028
    corps.rosette(g, x, y1, zg, L, nb, rb, rr, mat=M[st.get("barrel", "gun")], collier_mat=M[st["band"]],
                  colliers=st.get("collars", (0.8,)), bouts=False)
    Lj = L * min(st.get("jacket_f", 0.62), corps.JAQUETTE_MAX)
    jk_bronze(g, st, x, y1, zg, Lj, rs, H)
    return rs


def jk_bronze(g, st, x, y0, z, Lj, rs, H):
    """Époque 7 : bronze ciselé à sertissures, 3 cristaux violets enchâssés près de la culasse."""
    M = g.M
    g.cyl((x, y0 + Lj / 2, z), "y", rs, Lj, M["bronze"], n=28, what="jaquette")
    # ciselure : listels en relief
    for i in range(3):
        yy = y0 + Lj * (0.22 + 0.3 * i)
        g.tube_shell((x, yy, z), "y", rs + 0.014, rs - 0.01, 0.022, M["bronze"], n=28, what="listel")
    for k in range(10):
        a = TAU * k / 10
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.35:
            continue
        g.box(V((x, y0 + Lj * 0.68, z)) + d * (rs + 0.004), (0.03, Lj * 0.42, 0.012), M["bronze"], "hard",
              R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="cannelure")
    for k, a in enumerate((math.pi * 0.5, math.pi * 0.5 + 1.15, math.pi * 0.5 - 1.15)):
        d = V((math.cos(a), 0, math.sin(a)))
        c = V((x, y0 + Lj * 0.3, z)) + d * (rs + 0.006)
        g.tube_shell(c + d * 0.01, d, 0.05, 0.03, 0.024, M["brass"], n=16, what="sertissure")
        g.cyl(c + d * 0.03, d, 0.034, 0.05, M["emit"], n=6, style="hard", what="cristal")
        g.cyl(c + d * 0.075, d, 0.034, 0.04, M["emit"], n=6, r2=0.006, style="hard", what="pointe")
        for s in (-1, 1):
            g.box(c + d * 0.03 + V((0, s * 0.045, 0)), (0.018, 0.024, 0.03), M["brass"], "hard", what="griffe")
    for yy in (y0 + 0.025, y0 + Lj - 0.02):
        g.tube_shell((x, yy, z), "y", rs + 0.026, rs - 0.01, 0.045, M["stone"], n=28, what="bague")


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) de bronze et pierre, bloc de pierre taillée."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    T = PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)
    zc = z1 + 0.012
    g.box((x, y0 + 0.08, zc + 0.03), (w * 0.8, 0.14, 0.06), M["stone"], "hard", what="pierre")
    return T


def drive(g, st, c, r, L):
    """Organe arrière du canon : moteur de bronze, bague de pierre et cristal."""
    M = g.M
    x, y, z = c
    body = M[st.get("drive_mat", "steel_dk")]
    g.cyl((x, y, z), "y", r, L, body, n=28, style="soft", phase=math.pi / 8, what="moteur")
    nf = int((L * 0.5) / 0.045)
    fm = M[st.get("fin_mat", "steel_hi")]
    for kk in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + kk * 0.045, z), "y", r + 0.026, r - 0.01, 0.014, fm, n=28, what="ailette")
    g.tube_shell((x, y + L * 0.3, z), "y", r + 0.02, r - 0.01, 0.05, M["stone"], n=24, what="bague")
    g.cyl((x, y + L * 0.3, z + r + 0.02), (0, 0.3, 1), 0.02, 0.07, M["emit"], n=6, r2=0.005, style="hard",
          what="cristal")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M[st.get("flange_mat", "olive")], n=24, style="soft",
          what="flasque")
    F.bolts_ring(g, (x, y - L / 2 - 0.06, z), (0, -1, 0), r * 0.66, 8, M["rivet"], r=0.016)
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M[st["band"]], n=12, what="moyeu")


def feed(g, st, H, x, sx, xo):
    """Alimentation : chargeurs à cartouches de cristal (étuis translucides violets)."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    bw, bl, bh = 0.2, H["L"] * 0.32, 0.22
    bx0, bx1 = sorted((xo, xo + sx * bw))
    PT.hull(g, bx0, bx1, y0 - 0.05, y0 - 0.05 + bl, zg - bh * 0.6, zg + bh * 0.4, ins=(0.015, 0.015, 0.015),
            panel=0.24, mats=[M["bronze"], M["stone"]], rivet_step=0.11)
    bc = (bx0 + bx1) / 2
    for k in range(4):
        g.cyl((bc - 0.05 + (k % 2) * 0.1, y0 + bl * (0.25 + 0.3 * (k // 2)), zg + bh * 0.4 + 0.02), "z", 0.026,
              0.05, M["emit_soft"], n=6, r2=0.012, style="hard", what="etui")
    P2.feed_chute(g, [(bc, y0 + bl * 0.7, zg + bh * 0.4 + 0.02), (bc - sx * 0.05, y0 + bl * 0.6, zg + hr + 0.05),
                      (x + sx * wr * 0.2, y0 + bl * 0.55, zg + hr + 0.06)], 0.12, M)


# ------------------------------------------------------------------------------------------------
# Masque, nacelle, tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=ST["gmask"], fentes=((0.0, 1.1),), visiere=("steel_dk", 0.03))


def nacelle(g, c):
    """Un échappement et une grappe de cristaux sur la nacelle."""
    bx, yb0, yb1, ztop, yc = c.nac
    PT.exhaust(g, (bx * 0.7, yc - 0.05, ztop), 0.05, 0.22)
    crystals(g, (-bx * 0.55, yc, ztop), 1.15)


def crystals(g, c, s=1.0):
    """Grappe de cristaux (3 tailles, opaques, foyers violets) sur une embase de bronze."""
    M = g.M
    c = V(c)
    g.cyl(c + V((0, 0, 0.02)), "z", 0.07 * s + 0.03, 0.04, M["bronze"], n=8, style="hard", what="embase")
    for k, (dx, dy, h, r, tilt) in enumerate(((0.0, 0.0, 0.22, 0.04, 0.0), (0.06, 0.03, 0.15, 0.03, 0.4),
                                              (-0.05, 0.04, 0.12, 0.026, -0.45), (0.02, -0.05, 0.09, 0.022, 0.3))):
        d = V((math.sin(tilt), 0.25 * tilt, 1)).normalized()
        base = c + V((dx * s, dy * s, 0.04))
        g.cyl(base + d * h * s * 0.4, d, r * s, h * s * 0.8, M["emit"], n=6, style="hard", what="cristal")
        g.cyl(base + d * h * s * 0.9, d, r * s, h * s * 0.2, M["emit"], n=6, r2=0.003, style="hard", what="pointe")


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    side = c.side
    k = KIN
    F.slits(g, R, c.rt + 0.1 + 0.02 * side, 9, M["emit"], a0=math.pi * 0.62, span=math.pi * 1.76)
    F.voyants_tete(g, H, 14)
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
    n2 = 2 + 2 * k
    for i in range(n2):
        th = 0.7 + (math.pi - 1.4) * (i + 0.5) / n2
        P2.applique(g, c.Pf, c.Nf, th, 0.72, 0.2, 0.16, appl, M)
    # signature de coupole : cristaux sertis dans des sertissures de laiton
    for i, (th, ph, h) in enumerate(((math.pi * 0.3, 0.5, 0.26), (math.pi * 0.7, 0.55, 0.22),
                                     (math.pi * 1.2, 0.45, 0.24), (math.pi * 1.8, 0.5, 0.2),
                                     (math.pi * 0.5, 0.95, 0.3))):
        p, nrm = c.Pf(th, ph, 1.0), c.Nf(th, ph)
        g.tube_shell(p + nrm * 0.015, nrm, 0.08, 0.05, 0.03, M["brass"], n=6, what="sertissure")
        F.crystal(g, p, nrm, 0.06, h, M["crystal"], tip=0.35)
