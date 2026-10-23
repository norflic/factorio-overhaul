"""Époque 5 · Volcan (ère II, 3×3, niveaux 9 et 10). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 5) : « blindé, sombre, braise ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py, kit.py).
Corrections de design de la QUATRIÈME PASSE (23/10, constructeur de la plage basse) :
  - arme : OBUSIER court et massif qui dépasse nettement du corps : 4 tubes de gros calibre en carré (rosette),
    manchon blindé à 6 pans sur la moitié arrière, frein en coin large à évents sombres et lèvres de braise ;
  - socle : les grandes grilles orange (lues comme des résistances) deviennent des CROÛTES DE LAVE fissurées
    (fissures ramifiées, scories, braises) ; bunkers plus hauts ; tas de scories dans le contour (îlot de 38 px) ;
  - foyers rouge braise (famille 345 à 14° mesurée) ; chanfrein 0,4 ; ancrage boulonné des mortiers.
Emplacements remplis : arme (OBUSIER court et massif : manchon blindé à pans, cylindres de recul, frein en coin à
évents de braise, culasse à écailles, caisson blindé incliné), masque (glacis en écailles), grands volumes du socle
(bunkers en tronc de pyramide, tas de scories rougeoyants), liaisons (fonte à coudes vifs et fentes de braise),
fentes de braise sur la coupole, foyers braise, pièce paire (2 mortiers blindés).
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

EPOQUE = 5
NOM = "Volcan"
KIN = 1   # rang dans l'ère II
# passe 4 : rouge braise (famille 345 à 14° MESURÉE)
FOYER = dict(rgb=(1.0, 0.08, 0.02))
CANON = dict(L=1.15, nb=4, rb=0.068, rr=0.11)
# passe 4 : chanfrein de plateforme d'époque (remplissage, catalogue §A.5 ; silhouette distincte des voisines)
PLATEFORME = dict(chanfrein=0.5)
# passe 5, ronde 1 (consigne du DC du 23/10 : TOUT le bâtiment change d'âge) : le corps entier est taillé dans le
# BASALTE et coulé en FONTE : pont de dalles de basalte inégales (relief) à joints rouge sombre de roche chaude,
# (joints du pont noirs : rouges, ils dessinaient une grille de cadres) ; coupole et capots de basalte gris froid, plaques de fonte, acier de structure en fonte noire, rivets de fonte
# brûlée. Aucun olive ni ocre : un bloc de roche noire veinée de braise.
HABILLAGE = dict(jupe_cerclage="burnrust", tremie="tungsten", pochoirs=True, munitions=("tungsten", "burnrust"),
                 tourelleau="tungsten", chapeau="burnrust", capots=("basalte_capot", "fonte_v"),
                 acier=("fonte_noire", "fonte_v"), rivets="burnrust", joints="braise_sombre",
                 danger=("braise_sombre", "fonte_noire"), peinture="burnrust",
                 plateforme=dict(motif="dalles", pas=0.34, joint=0.022, mat="basalte_dalle", mat2="basalte_dalle2",
                                 fond="fonte_noire", bord="fonte_noire", boulons=None, relief=0.7))
ST = dict(jacket="hex", brake="wedge", drive="scale", drive_mat="tungsten", fin_mat="burnrust", band="burnrust",
          recv_mats=("tungsten", "burnrust"), recv_sig="scales", feed="armored", skirt="burnrust", appl="tungsten",
          gmask=("tungsten", "burnrust"), arm=("tungsten", "olive"), cap="burnrust", mask="glacis",
          col=("tungsten", "olive"), nac=("tungsten", "burnrust"), flange_mat="burnrust")


def matieres(metal, M):
    """Passe 5 : matières du CORPS du volcan (basalte rugueux non métallique, fonte peu métallique)."""
    metal("basalte_capot", (0.115, 0.112, 0.11), rough=0.75, met=0.05, grain=0.45, gscale=26.0, dirt=0.7, stain=0.55,
          sscale=4.0, wear=1.6, mottle=0.5)
    metal("basalte_dalle", (0.1, 0.097, 0.095), rough=0.8, met=0.0, grain=0.5, gscale=26.0, dirt=0.7, stain=0.6,
          sscale=4.0, wear=1.2, mottle=0.5)
    metal("basalte_dalle2", (0.075, 0.072, 0.07), rough=0.8, met=0.0, grain=0.5, gscale=26.0, dirt=0.7, stain=0.6,
          sscale=4.0, wear=1.2, mottle=0.5)
    metal("fonte_v", (0.16, 0.15, 0.145), rough=0.55, met=0.45, grain=0.3, gscale=30.0, rust=(0.22, 0.07, 0.03),
          ra=0.2, dirt=0.75, stain=0.5, wear=1.6)
    metal("fonte_noire", (0.05, 0.047, 0.045), rough=0.55, met=0.45, grain=0.3, rust=(0.22, 0.07, 0.03), ra=0.15,
          dirt=0.7, stain=0.4, wear=2.0)
    metal("braise_sombre", (0.22, 0.03, 0.008), rough=0.7, met=0.0, grain=0.3, dirt=0.3, stain=0.2)


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : bunkers en tronc de pyramide, tas de scories
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=2)
    socle_volcano(g, KIN)
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def lava_crust(g, cx, cy, z, w, l, M, E, step=0.085, seed=0):
    """Croûte de lave (passe 4 : remplace les grilles orange, lues comme des résistances) : dalle de basalte bosselée,
    FISSURES rougeoyantes tracées en lignes brisées qui se ramifient (aucune grille, aucun aplat), blocs de scorie
    posés dessus, quelques braises."""
    g.box((cx, cy, z + 0.012), (w, l, 0.024), M["basalt"], "hard", what="croute")
    rng = g.rng
    nb = max(3, int((w * l) / 0.04) + 1)
    for k in range(nb):
        # départ près d'un bord, marche brisée vers l'intérieur
        a = TAU * (k + 0.3 * rng.random()) / nb
        px, py = cx + math.cos(a) * w * 0.42, cy + math.sin(a) * l * 0.42
        hd = a + math.pi + 0.6 * (rng.random() - 0.5)
        nseg = 4 + (k % 3)
        for s in range(nseg):
            Ls = 0.05 + 0.04 * rng.random()
            hd += 0.9 * (rng.random() - 0.5)
            qx, qy = px + math.cos(hd) * Ls, py + math.sin(hd) * Ls
            qx = min(cx + w / 2 - 0.02, max(cx - w / 2 + 0.02, qx))
            qy = min(cy + l / 2 - 0.02, max(cy - l / 2 + 0.02, qy))
            seg = math.hypot(qx - px, qy - py)
            if seg > 0.01:
                wd = 0.022 if s < 2 else 0.015
                g.box(((px + qx) / 2, (py + qy) / 2, z + 0.026), (seg + 0.012, wd, 0.006), E, "flat",
                      R=Matrix.Rotation(math.atan2(qy - py, qx - px), 3, "Z"), what="fissure")
            if s == 2 and rng.random() < 0.6:   # ramification courte
                hb = hd + (0.9 if rng.random() < 0.5 else -0.9)
                bx_, by_ = px + math.cos(hb) * 0.05, py + math.sin(hb) * 0.05
                g.box(((px + bx_) / 2, (py + by_) / 2, z + 0.026), (0.055, 0.012, 0.006), E, "flat",
                      R=Matrix.Rotation(hb, 3, "Z"), what="fissure")
            px, py = qx, qy


def bunker(g, x0, x1, yn0, yn1, h, M, E, ins=0.12, slits=3, spikes=2):
    T = PT.hull(g, x0, x1, Y(yn0), Y(yn1), 0.0, h, ins=(ins, ins * 0.8, ins * 1.2), panel=0.24,
                mats=[M["tungsten"], M["burnrust"], M["tungsten"]], rivet_step=0.1)
    # fentes de braise au sud (meurtrières rougeoyantes)
    y0 = Y(yn0)
    for i in range(slits):
        xx = x0 + (x1 - x0) * (i + 0.5) / slits
        yf = y0 + ins * 0.8 * 0.45 - 0.04
        g.box((xx, yf, h * 0.45), (0.12, 0.012, 0.046), E, "flat", what="braise")
        g.box((xx, yf - 0.01, h * 0.45 + 0.035), (0.15, 0.04, 0.022), M["tungsten"], "hard",
              R=Matrix.Rotation(-0.6, 3, "X"), what="visiere")
        for s_ in (-1, 1):
            g.box((xx + s_ * 0.075, yf + 0.01, h * 0.45), (0.022, 0.05, 0.07), M["burnrust"], "hard", what="joue")
    # creuset ouvert sur le dessus : rebord de rouille brûlée, CROÛTE DE LAVE fissurée (plus de grille orange)
    cx_, cy_ = (T[0].x + T[2].x) / 2, (T[0].y + T[2].y) / 2
    gw, gl = (T[1].x - T[0].x) * 0.62, (T[2].y - T[1].y) * 0.5
    # passe 5, ronde 1 : plus de croûte de lave ENCADRÉE (lue « runes de dragon » : un glyphe dans un cadre) : une
    # BOUCHE DE LAVE à ciel ouvert, flaque irrégulière cernée de blocs de basalte, d'où part une COULÉE qui traverse
    # le dessus et descend en rigole le long de la face sud (lave hors des cadres, demande des juges)
    rm = min(gw, gl)
    F.lump(g, (cx_, cy_, h + 0.004), rm * 0.4, E, sz=0.2, n=10, m=5, jit=0.3, what="lave")
    for i in range(7):
        a = TAU * i / 7 + 0.3
        if abs(a - 1.5 * math.pi) < 0.5:
            continue   # brèche au sud : la coulée sort par là
        F.lump(g, (cx_ + math.cos(a) * rm * 0.56, cy_ + math.sin(a) * rm * 0.6, h), 0.055 + 0.015 * (i % 3),
               M["basalt"], sz=0.6, n=8, m=5, jit=0.3, what="scorie")
    rng = g.rng
    pts = [V((cx_, cy_ - rm * 0.3, h + 0.012))]
    ytop = min((t_.y for t_ in T[:4]), key=lambda v: abs(v - Y(yn0)))
    for i in range(1, 4):
        pts.append(V((cx_ + 0.035 * (rng.random() - 0.5) * 2, cy_ - rm * 0.3 + (ytop - cy_ + rm * 0.3) * i / 3,
                      h + 0.012)))
    yb_ = Y(yn0)
    for i in range(1, 4):
        t = i / 3
        pts.append(V((cx_ + 0.04 * (rng.random() - 0.5) * 2, ytop + (yb_ - ytop) * t, h * (1 - t) + 0.012)))
    for i, (a_, b_) in enumerate(zip(pts, pts[1:])):
        e_ = b_ - a_
        g.cyl((a_ + b_) / 2, e_, 0.03 - 0.003 * i, e_.length + 0.02, E, n=8, style="flat", what="coulee")
    # pointes de basalte aux coins du dessus
    for i in range(spikes):
        p = T[(2 + i) % 4]
        g.cyl(p + V((0, 0, 0.08)), (0.25 * (1 if p.x > (x0 + x1) / 2 else -1), 0.15, 1), 0.04, 0.17, M["basalt"],
              n=5, r2=0.004, style="hard", what="pointe")
    return T


def slag_heap(g, x, yn, r, M, E, n=7):
    """Tas de scories : blocs de basalte et de rouille brûlée entassés, braises et fissures rougeoyantes entre les
    blocs (petites, irrégulières)."""
    y = Y(yn)
    for i in range(n):
        a = TAU * i / n + 0.4
        rr = r * (0.45 + 0.25 * (i % 2))
        F.lump(g, (x + math.cos(a) * rr, y + math.sin(a) * rr * 1.2, 0.0), r * (0.42 - 0.04 * (i % 3)), M["basalt"],
               sz=0.5, n=9, m=5, jit=0.3, what="scorie")
    F.lump(g, (x, y, 0.06), r * 0.55, M["burnrust"], sz=0.6, n=10, m=6, jit=0.25, what="scorie")
    for i in range(4):
        a = TAU * i / 4 + 1.0
        g.box((x + math.cos(a) * r * 0.32, y + math.sin(a) * r * 0.38, r * 0.28), (0.07, 0.014, 0.012), E, "flat",
              R=Matrix.Rotation(a + 0.7, 3, "Z"), what="fissure")
    F.lump(g, (x + r * 0.2, y - r * 0.15, r * 0.3), 0.045, E, sz=0.6, n=6, m=4, what="braise")
    F.lump(g, (x - r * 0.35, y + r * 0.2, r * 0.22), 0.04, E, sz=0.6, n=6, m=4, what="braise")


def socle_volcano(g, k):
    M = g.M
    E = M["emit"]
    # ouest et est : bunkers blindés en tronc de pyramide, creusets de lave fissurée sur le dessus
    bunker(g, -1.5, -0.78, -0.8, 0.92, 0.68, M, E, slits=4)
    bunker(g, 0.78, 1.5, -0.66, 0.8, 0.72, M, E, slits=3)
    # bouche de lave de l'est (gueule rougeoyante au sud, sur le flanc du bunker)
    g.box((1.17, Y(-0.6) + 0.1, 0.16), (0.22, 0.02, 0.08), E, "flat", what="gueule")
    for xx in (-1.3, -0.98):
        g.box((xx, Y(-0.8) + 0.085, 0.14), (0.13, 0.02, 0.06), E, "flat", what="gueule")
        g.box((xx, Y(-0.8) + 0.07, 0.185), (0.16, 0.04, 0.025), M["tungsten"], "hard", what="linteau")
    PT.hull(g, 1.0, 1.34, Y(-0.6) - 0.02, Y(-0.6) + 0.1, 0.22, 0.3, ins=(0.02, 0.0, 0.02), panel=0.2,
            mats=[M["tungsten"]], rivet_step=0.1)
    # nord : tas de scories (dans le contour de la plateforme : aucun îlot au coin chanfreiné), évent de lave
    slag_heap(g, -0.95, 1.0, 0.34, M, E, n=9)
    slag_heap(g, -0.35, 1.18, 0.26, M, E, n=6)
    F.prism(g, [(0.68, Y(0.96)), (1.36, Y(0.96)), (1.36, Y(1.36)), (0.68, Y(1.36))], 0.0, 0.08, M["tungsten"])
    T = PT.hull(g, 0.72, 1.32, Y(1.0), Y(1.32), 0.08, 0.42, ins=(0.18, 0.12, 0.12), panel=0.22,
                mats=[M["tungsten"], M["burnrust"]], rivet_step=0.1)
    lava_crust(g, 1.02, (T[0].y + T[2].y) / 2, 0.42, 0.2, 0.18, M, E, step=0.07)
    # conduits de fonte à coudes vifs (fentes de braise sur les coudes)
    link(g, 5, [(-0.88, Y(0.3), 0.3), (-0.8, Y(0.3), 0.5), (-0.66, Y(0.24), 0.5)], 0.06)
    link(g, 5, [(0.88, Y(0.1), 0.3), (0.8, Y(0.1), 0.5), (0.66, Y(0.08), 0.5)], 0.06)
    link(g, 5, [(0.9, Y(1.18), 0.3), (0.6, Y(1.0), 0.45), (0.3, Y(0.8), 0.55)], 0.055)
    for (xx, yn) in ((-1.25, 0.95), (0.75, 0.9), (1.25, 0.9)):
        F.lump(g, (xx, Y(yn), 0.06), 0.05, M["basalt"], sz=0.5, n=7, m=4, what="scorie")
        g.box((xx + 0.02, Y(yn) - 0.03, 0.09), (0.05, 0.016, 0.012), E, "flat", R=Matrix.Rotation(0.6, 3, "Z"),
              what="braise")
    g.halo((-0.95, Y(1.0), 0.3), M["_emit_rgb"], 12.0)
    g.halo((1.17, Y(-0.7), 0.25), M["_emit_rgb"], 12.0)
    g.halo((1.02, Y(1.16), 0.6), M["_emit_rgb"], 8.0)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduit trapu en fonte à coudes VIFS, brides lourdes à 6 boulons, fente de braise sur le coude
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » du volcan)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        d = b - a
        g.cyl((a + b) / 2, d, r * 1.05, d.length, M["castiron"], n=12, style="hard", what="conduit")
    for i, p in enumerate(P):
        g.box(p, (r * 2.4, r * 2.4, r * 2.4), M["tungsten"], "hard", what="coude")
        if 0 < i < len(P) - 1:
            g.box(p + V((0, -r * 1.21, 0)), (r * 1.4, 0.008, r * 0.4), M["emit"], "flat", what="braise")
        for k in range(6):
            ang = TAU * k / 6
            g.dome(p + V((math.cos(ang) * r * 0.9, -r * 1.2, math.sin(ang) * r * 0.9)), (0, -1, 0), 0.015,
                   M["rivet"])
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
# Pièce du niveau 10 : 2 mortiers trapus blindés
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
        with at(g, sx * cx, cy, sx * -0.3):
            mortar(g, (0, 0, 0), 0.0, 1.5 * s)
            _ancrage(g, 0.2 * 1.5 * s, 0.062 * 1.5 * s, g.M)
    _halo(g, [(-cx, Y(cy) + 0.1, 0.4), (cx, Y(cy) + 0.1, 0.4)], 10.0)


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


def mortar(g, c, rz, s=1.0):
    """Mortier trapu blindé (volcan) : tube court et gros incliné vers l'avant, affût à écailles."""
    M = g.M
    g.push(c, rz=rz)
    F.prism(g, [(-0.17 * s, -0.17 * s), (0.17 * s, -0.17 * s), (0.17 * s, 0.17 * s), (-0.17 * s, 0.17 * s)], 0.0,
          0.06 * s, M["tungsten"])
    g.cyl((0, 0, 0.1 * s), "z", 0.14 * s, 0.08 * s, M["burnrust"], n=8, style="hard", what="affut")
    for k in range(6):
        a = TAU * k / 6
        d = V((math.cos(a), math.sin(a), 0))
        g.box(d * 0.13 * s + V((0, 0, 0.12 * s)), (0.09 * s, 0.02, 0.06 * s), M["tungsten"], "hard",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed() @ Matrix.Rotation(-0.35, 3, "X"),
              what="ecaille")
    d = V((0, -0.55, 1)).normalized()
    p = V((0, 0.02, 0.18 * s))
    g.cyl(p + d * 0.1 * s, d, 0.075 * s, 0.24 * s, M["tungsten"], n=16, what="tube")
    g.tube_shell(p + d * 0.2 * s, d, 0.09 * s, 0.06 * s, 0.05 * s, M["burnrust"], n=16, what="bague")
    g.cyl(p + d * 0.225 * s, d, 0.05 * s, 0.01, M["void"], n=14, style="flat", what="bouche")
    g.tube_shell(p + d * 0.228 * s, d, 0.07 * s, 0.05 * s, 0.01, M["emit"], n=16, what="levre")
    for sx in (-1, 1):
        g.box((sx * 0.1 * s, 0.0, 0.2 * s), (0.03, 0.12 * s, 0.1 * s), M["tungsten"], "hard", what="tourillon")
        g.dome((sx * 0.117 * s, 0.0, 0.21 * s), (sx, 0, 0), 0.02, M["rivet"])
    g.pop()


# ------------------------------------------------------------------------------------------------
# Arme (E1) : obusier
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    M = g.M
    H = c.H
    w_howitzer(g, ST, H, x, sx)
    y0 = H["recv"][0]
    PT.lamp(g, (x - sx * H["wr"] * 0.25, y0 + 0.1, H["zg"] + H["hr"] + 0.03), (0, 0.4, 1), 0.026, M["emit"], cage=True)


def w_howitzer(g, st, H, x, sx):
    """Époque 5 (passe 4) : OBUSIER COURT ET MASSIF par flanc, qui DÉPASSE nettement du corps : 4 tubes de gros
    calibre en carré (corps.rosette « square » : les 4 bouches se voient, règle d'or 1), manchon blindé à 6 pans de
    tungstène sur la moitié arrière seulement, à écailles rivetées et JOINTS DE LAVE rougeoyants entre les rangs
    d'écailles, 2 cylindres de recul (dessus et dessous), frein de bouche en coin à évents de braise ; culasse à
    écailles, caisson blindé incliné."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    breech(g, st, x, y0, y1, zg - hr * 1.2, zg + hr * 1.2, wr * 1.18)
    Ld = 0.26 + hr * 0.6
    drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.9, Ld)
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    pos = corps.rosette(g, x, y1, zg, L, nb, rb, rr, mat=M["gun"], arr="square", colliers=(0.72,),
                        collier_mat=M["burnrust"], bouts=False)
    rbun = rr + rb
    R6 = rbun + 0.06
    Lj = L * corps.JAQUETTE_MAX
    c6 = math.cos(math.pi / 6)
    g.cyl((x, y1 + Lj / 2, zg), "y", R6, Lj, M["tungsten"], n=6, style="hard", phase=math.pi / 6, what="manchon")
    # écailles rivetées en 3 rangs (la braise vit dans les évents de la bouche, pas sur le manchon)
    for f in range(6):
        a = math.pi / 6 + TAU * f / 6 + TAU / 12
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.3:
            continue
        Rr = Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed()
        for i in range(3):
            yy = y1 + Lj * (0.18 + 0.3 * i)
            g.box(V((x, yy, zg)) + d * (R6 * c6 + 0.012), (R6 * 0.95, Lj * 0.27, 0.022), M["tungsten"], "hard",
                  R=Rr @ Matrix.Rotation(-0.12, 3, "X"), what="ecaille")
            g.dome(V((x, yy - Lj * 0.06, zg)) + d * (R6 * c6 + 0.03), d, 0.02, M["rivet"])
    for yy in (y1 + 0.035, y1 + Lj - 0.03):
        g.cyl((x, yy, zg), "y", R6 + 0.03, 0.07, M["burnrust"], n=6, style="hard", phase=math.pi / 6, what="bague")
    # cylindres de recul massifs dessus et dessous (ils dépassent du manchon : silhouette lourde en pose N)
    for s in (-1, 1):
        zr = zg + s * (R6 + 0.05)
        g.cyl((x, y1 + Lj * 0.55, zr), "y", 0.048, Lj * 1.1, M["burnrust"], n=14, what="recul")
        g.cyl((x, y1 + Lj * 1.08, zr), "y", 0.06, 0.06, M["tungsten"], n=14, what="tete_recul")
        g.box((x, y1 + Lj * 1.08, (zr + zg) / 2), (0.05, 0.05, abs(zr - zg)), M["tungsten"], "hard", what="patte")
    br_wedge(g, st, x, y1 + L, zg, rbun + 0.05, pos, H)
    PT.hull(g, x - wr * 0.85, x + wr * 0.85, y1 - 0.04, y1 + 0.07, zg - hr * 1.45, zg + hr * 1.55,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["tungsten"], M["burnrust"]], rivet_step=0.1)
    xo = x + sx * (wr * 0.59 - 0.005)
    feed(g, st, H, x, sx, xo)


def br_wedge(g, st, x, yb, z, rs, pos, H):
    """Époque 5 : frein de bouche en coin (bloc trapézoïdal à évents obliques), lèvres de braise dans les évents."""
    M = g.M
    rb = H["rb"]
    # passe 5 (règle d'or 7) : coin resserré au diamètre du faisceau (2,3 / 2,7 rs -> 1,8 / 2,1 rs), sans oreilles
    w0, w1 = rs * 1.8, rs * 2.1
    h0, h1 = rs * 1.75, rs * 1.45
    y0, y1 = yb - 0.03, yb + 0.2
    pts = [V((x - w0 / 2, y0, z - h0 / 2)), V((x + w0 / 2, y0, z - h0 / 2)), V((x + w1 / 2, y1, z - h1 / 2)),
           V((x - w1 / 2, y1, z - h1 / 2)),
           V((x - w0 / 2, y0, z + h0 / 2)), V((x + w0 / 2, y0, z + h0 / 2)), V((x + w1 / 2, y1, z + h1 / 2)),
           V((x - w1 / 2, y1, z + h1 / 2))]
    g.hexa(pts, M["tungsten"], "hard", what="frein")
    for s in (-1, 1):
        for k in range(3):
            yy = y0 + 0.05 + k * 0.06
            xx = x + s * (w0 / 2 + (w1 - w0) / 2 * (yy - y0) / (y1 - y0)) + s * 0.002
            Rr = Matrix.Rotation(s * 0.5, 3, "Z")
            g.box((xx, yy, z + 0.01), (0.016, 0.044, h1 * 0.78), M["void"], "flat", R=Rr, what="event")
            g.box((xx + s * 0.002, yy, z - h1 * 0.22), (0.016, 0.036, h1 * 0.26), M["emit"], "flat", R=Rr,
                  what="braise")
            g.box((xx + s * 0.006, yy + 0.026, z + 0.01), (0.016, 0.012, h1 * 0.86), M["tungsten"], "hard", R=Rr,
                  what="lame")
    # évents supérieurs rougeoyants (lisibles d'en haut, poses E et N) et oreilles : jamais un chapeau de cheminée
    for k in range(3):
        yy = y0 + 0.05 + k * 0.06
        hz = h0 / 2 + (h1 - h0) / 2 * (yy - y0) / (y1 - y0)
        g.box((x, yy, z + hz + 0.002), (w0 * 0.62, 0.022, 0.008), M["void"], "flat", what="event")
        g.box((x, yy, z + hz + 0.004), (w0 * 0.34, 0.01, 0.006), M["emit"], "flat", what="braise")
    for k in range(4):
        g.dome((x - w1 * 0.3 + k * w1 * 0.2, y0 + 0.11, z + (h0 + h1) / 4 + 0.006), (0, 0, 1), 0.02, M["rivet"])
    # face avant rectangulaire (le coin est plus large que haut), rosace des 4 bouches, pourtour de braise en cadre
    fw, fh = w1 * 0.84, h1 * 0.86
    g.box((x, y1 + 0.004, z), (fw, 0.01, fh), M["burnrust"], "hard", what="face")
    F.bores(g, x, y1 + 0.01, z, pos, rb, M["burnrust"])
    for s in (-1, 1):
        g.box((x + s * (fw / 2 - 0.012), y1 + 0.012, z), (0.016, 0.008, fh - 0.02), M["emit"], "flat", what="cadre_lum")
        g.box((x, y1 + 0.012, z + s * (fh / 2 - 0.012)), (fw - 0.02, 0.008, 0.016), M["emit"], "flat",
              what="cadre_lum")


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) à ÉCAILLES de blindage."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    T = PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)
    zc = z1 + 0.012
    for i in range(2):
        for j in range(2):
            yy = y0 + 0.1 + (y1 - y0 - 0.2) * i
            g.box((x + (j - 0.5) * w * 0.45, yy, zc + 0.02 + 0.006 * i), (w * 0.44, 0.13, 0.016), M["tungsten"],
                  "hard", R=Matrix.Rotation(-0.18, 3, "X"), what="ecaille")
    return T


def drive(g, st, c, r, L):
    """Organe arrière du canon : moteur de tungstène à ailettes de rouille brûlée, ÉCAILLES sur le dessus."""
    M = g.M
    x, y, z = c
    body = M[st.get("drive_mat", "steel_dk")]
    g.cyl((x, y, z), "y", r, L, body, n=28, style="soft", phase=math.pi / 8, what="moteur")
    nf = int((L * 0.5) / 0.045)
    fm = M[st.get("fin_mat", "steel_hi")]
    for kk in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + kk * 0.045, z), "y", r + 0.026, r - 0.01, 0.014, fm, n=28, what="ailette")
    for kk in range(5):
        a = math.pi / 2 + (kk - 2) * 0.55
        d = V((math.cos(a), 0, math.sin(a)))
        g.box(V((x, y + L * 0.25, z)) + d * (r + 0.012), (0.08, L * 0.42, 0.018), M["tungsten"], "hard",
              R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed() @ Matrix.Rotation(0.12, 3, "X"),
              what="ecaille")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M[st.get("flange_mat", "olive")], n=24, style="soft",
          what="flasque")
    F.bolts_ring(g, (x, y - L / 2 - 0.06, z), (0, -1, 0), r * 0.66, 8, M["rivet"], r=0.016)
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M[st["band"]], n=12, what="moyeu")


def feed(g, st, H, x, sx, xo):
    """Alimentation : CAISSON BLINDÉ incliné à goulotte, écailles, fente de braise."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    bw, bl, bh = 0.2, H["L"] * 0.36, 0.22
    bx0, bx1 = sorted((xo, xo + sx * bw))
    PT.hull(g, bx0, bx1, y0 - 0.05, y0 - 0.05 + bl, zg - bh * 0.7, zg + bh * 0.35, ins=(0.02, 0.03, 0.06),
            panel=0.24, mats=[M["tungsten"], M["burnrust"]], rivet_step=0.11)
    for k in range(3):
        g.box(((bx0 + bx1) / 2, y0 + bl * (0.2 + 0.25 * k), zg + bh * 0.35 + 0.012), (bw * 0.9, 0.1, 0.016),
              M["tungsten"], "hard", R=Matrix.Rotation(-0.2, 3, "X"), what="ecaille")
    bc = (bx0 + bx1) / 2
    P2.feed_chute(g, [(bc, y0 + bl * 0.6, zg + bh * 0.35 + 0.03), (bc - sx * 0.05, y0 + bl * 0.55, zg + hr + 0.05),
                      (x + sx * wr * 0.2, y0 + bl * 0.5, zg + hr + 0.06)], 0.12, M)
    g.box((bc + sx * (bw / 2 + 0.004), y0 + bl * 0.4, zg), (0.01, 0.06, 0.02), M["emit"], "flat", what="braise")


# ------------------------------------------------------------------------------------------------
# Masque (remplace celui de la lignée) : GLACIS en écailles incliné
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    mw = R * 0.5
    PT.hull(g, -mw, mw, R * 0.55, R + 0.24, zs - 0.18, zs + rz * 0.55, ins=(0.04, 0.02, R * 0.32), panel=0.22,
            mats=[M["tungsten"], M["burnrust"]], rivet_step=0.11)
    for i in range(3):
        for j in range(3):
            yy = R * 0.62 + (R * 0.5) * (i / 2.0)
            zz = zs + rz * 0.5 - (rz * 0.5 + 0.12) * (i / 2.0) + 0.03
            g.box(((j - 1) * mw * 0.62, yy, zz), (mw * 0.66, 0.14, 0.018), M["tungsten"], "hard",
                  R=Matrix.Rotation(-0.55, 3, "X"), what="ecaille")
            g.dome(((j - 1) * mw * 0.62, yy + 0.04, zz + 0.022), (0, 0.4, 1), 0.017, M["rivet"])
    g.box((0, R + 0.25, zs - 0.06), (mw * 1.1, 0.012, 0.03), M["emit"], "flat", what="fente")


def nacelle(g, c):
    """Deux échappements de la lignée, bouches de braise."""
    M = g.M
    bx, yb0, yb1, ztop, yc = c.nac
    re, he = c.T["echap"]
    for sx in (-1, 1):
        PT.exhaust(g, (sx * bx * 0.7, yc - 0.05, ztop), re, he)
    for sx in (-1, 1):
        g.cyl((sx * bx * 0.7, yc - 0.05, ztop + he + 0.012), "z", re - 0.027, 0.008, M["emit"], n=14,
              style="flat", what="braise")


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    side = c.side
    k = KIN
    F.slits(g, R, c.rt + 0.1 + 0.02 * side, 6, M["emit"], a0=math.pi * 0.62, span=math.pi * 1.76)
    zt = H["zs"] + H["rz"] * 0.42
    for sx in (-1, 1):
        arch_hose(g, EPOQUE, (sx * 0.15, -R - 0.06, zt + 0.02),
                  (sx * (H["gx"] - 0.03), H["recv"][0] + 0.1, H["zg"] + H["hr"] + 0.03),
                  0.1 + 0.03 * (side - 2), 0.034 + 0.008 * (side - 2))
    F.voyants_tete(g, H, 6)
    PT.sight(g, (R * 0.2, R * 0.45, H["zs"] + H["rz"] * 0.6), 0.16 + 0.04 * (side - 3), 0.18, 0.1, M["emit"],
             lenses=side - 2)
    # plaques rapportées : écailles de tungstène (une par position : passe 4, densité de détail D3 de 67 ramenée vers
    # la plage), puis 2e rangée
    appl = M[ST["appl"]]
    n1 = {0: 3, 1: 6, 2: 8}[k] + (side - 2)
    for i in range(n1):
        th = 0.45 + (math.pi - 0.9) * (i + 0.5) / n1
        P2.applique(g, c.Pf, c.Nf, th, 0.3, 0.26, 0.18, M["tungsten"], M, bolts=0)
    n2 = 2 + 2 * k
    for i in range(n2):
        th = 0.7 + (math.pi - 1.4) * (i + 0.5) / n2
        P2.applique(g, c.Pf, c.Nf, th, 0.72, 0.2, 0.16, appl, M)
    # signature de coupole : fentes de braise à visière
    for i in range(7):
        th = math.pi * 0.2 + math.pi * 0.6 * i / 6
        p, nrm = c.Pf(th, 0.55, 1.012), c.Nf(th, 0.55)
        g.push_frame(p, nrm, xdir=(math.cos(th + math.pi / 2), math.sin(th + math.pi / 2), 0))
        g.box((0, 0, 0.004), (0.12, 0.022, 0.01), M["emit"], "flat", what="braise")
        g.box((0, 0.024, 0.014), (0.15, 0.025, 0.02), M["tungsten"], "hard", what="visiere")
        g.pop()
