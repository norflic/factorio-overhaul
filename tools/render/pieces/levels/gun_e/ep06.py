"""Époque 6 · Électricité (ère II, 3×3, niveaux 11 et 12). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 6) : « bobines, isolateurs, arcs ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py, kit.py).
Corrections de design de la QUATRIÈME PASSE (23/10, constructeur de la plage basse) :
  - arme (règle d'or 1) : canon de lignée complet (corps.canon_lignee, sans jaquette) + BOBINE OUVERTE (hélice de
    cuivre à spires espacées : on voit les tubes), peignes d'isolateurs de porcelaine, anneau isolateur, électrodes
    et arc à la bouche, SPHÈRE DE DÉCHARGE sur pile d'isolateurs ;
  - plus aucun manchon de cuivre plein (ceinture de coupole et touret de cuivre remplacés : poteaux de porcelaine,
    câble gainé) ; isolateurs de porcelaine claire ; transformateur gris clair à radiateurs ; tour de Tesla haute.
Emplacements remplis : arme (CANON-BOBINE : tube central gainé de 5 grosses bobines de cuivre et d'isolateurs, bouche
à électrodes, moteur bobiné, tambour), mitrailleuse coaxiale, grands volumes du socle (tour de Tesla, transformateur
à traversées, touret de câble, sphère de décharge, condensateurs), liaisons (câbles sur isolateurs), nacelle (tour
de Tesla dorsale et arcs), spires de cuivre sur la coupole, foyers cyan, pièce paire (2 piles à éclateur).
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

EPOQUE = 6
NOM = "Électricité"
KIN = 2   # rang dans l'ère II
FOYER = ages.FOYER[6]   # ronde 3 : bleu électrique (cyan clair avant ; le cyan glacé est au 12)
CANON = dict(L=1.35, nb=4, rb=0.045, rr=0.1)
# passe 5 : cerclages de jupe sombres (moins de cuivre sur le corps : lu « cuivre, cheminée, vapeur » à la ronde 0)
# passe 5, ronde 1 reprise (consigne du DC du 23/10 : TOUT le bâtiment change d'âge) : une CENTRALE de 1900 :
# coupole et capots de PORCELAINE blanche, plaques vert d'eau de salle des machines, acier de structure en bakélite
# noire et cuivre poli, rivets de cuivre, pont de CARREAUX de céramique gris clair à joints noirs bordé de cuivre.
# Le bâtiment devient clair : il ne se lit plus « cuivre sombre, cheminée, vapeur ».
HABILLAGE = dict(ages.CORPS[6],   # lot K0 : MATIÈRE du corps et du pont (capots, acier, rivets, joints,
                 # danger, peinture, plateforme) : commun/ages.py ; ici, les clés propres à la mitrailleuse
                 jupe_cerclage="copper_pol", tremie="cream", pochoirs=True, munitions=("copper", "steel_hi"),
                 chapeau="copper_pol",
                 tourelleau="bleu_machine", grille_nacelle="copper_pol",
                 )
# ronde 3 : culasses et masques d'arme en bleu machine et porcelaine (ils restaient ocre et olive de la lignée)
ST = dict(jacket="coils", brake="insul", drive="coil", band="copper", recv_mats=("bleu_machine", "porcelaine_capot"),
          feed="drum", skirt="copper", appl="porcelaine", gmask=("bleu_machine", "porcelaine_capot"),
          arm=("bleu_machine", "fonte_bleue"), cap="copper", col=("bleu_machine", "fonte_bleue"),
          nac=("bleu_machine", "porcelaine_capot"), coax=True)


def matieres(metal, M):
    """Porcelaine des isolateurs (passe 4 : « piles d'isolateurs blancs » ; patinée, arêtes claires, jamais un blanc pur :
    C8) ; elle devient l'accent de l'époque (PT.insulators, peignes et anneaux)."""
    ages.matieres(6, metal, M)   # lot K0 : matières de l'âge, commun/ages.py (ordre d'origine, porcelaine 2e)
    # rôle de la mitrailleuse (alias) : la porcelaine des isolateurs est l'accent
    M["accent"] = M["porcelaine"]


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : tour de Tesla, transformateur, touret de câble, sphère de décharge
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=3)
    socle_electric(g, KIN)
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def tesla_tower(g, x, yn, h, M, E, s=1.0):
    y = Y(yn)
    PT.hull(g, x - 0.2 * s, x + 0.2 * s, y - 0.2 * s, y + 0.2 * s, 0.0, 0.18, ins=(0.03, 0.03, 0.03), panel=0.2,
            mats=[M["bleu_machine"], M["steel_dk"]], rivet_step=0.1)
    g.box((x, y - 0.2 * s - 0.006, 0.1), (0.14, 0.012, 0.07), M["hazy"], "flat", what="haute_tension")
    n = max(4, int((h - 0.24) / 0.05))
    zt = PT.insulators(g, (x, y, 0.18), n, 0.075 * s, h=0.05)
    g.torus((x, y, zt + 0.04), "z", 0.15 * s, 0.05 * s, M["copper"], n=32, m=10, what="tore")
    g.cyl((x, y, zt + 0.04), "z", 0.15 * s, 0.06, M["steel_dk"], n=24, what="ame_tore")
    F.sphere(g, (x, y, zt + 0.12), 0.055 * s, M["steel_hi"], n=16, m=10, what="boule")
    return zt + 0.04


def streamer(g, p0, d, L, n=4, amp=0.03):
    """Décharge OUVERTE (passe 5) : ligne brisée lumineuse qui part d'une pièce et s'arrête dans l'air (un seul bout
    attaché : aucun jour de sol enfermé)."""
    rng = g.rng
    d = V(d).normalized()
    side = d.cross(V((0, 0, 1)))
    if side.length < 1e-4:
        side = V((1, 0, 0))
    side.normalize()
    pts = [V(p0)]
    for i in range(1, n + 1):
        t = i / n
        pts.append(V(p0) + d * L * t + side * amp * (rng.random() - 0.5) * 2 + V((0, 0, amp * (rng.random() - 0.5))))
    for a, b in zip(pts, pts[1:]):
        e = b - a
        g.cyl((a + b) / 2, e, 0.011, e.length + 0.006, g.M["emit"], n=6, style="flat", what="arc")


def tesla_trapue(g, x, yn, M, E):
    """Passe 5 : BOBINE DE TESLA TRAPUE (0,56 t de haut au lieu du mât à sphère de 1,3 t lu « cheminée ») : caisson
    bas, bobine secondaire épaisse à spires de cuivre jointives, spirale primaire au pied, 3 poteaux d'isolateurs
    blancs, gros tore d'aluminium au sommet, 5 décharges cyan ouvertes qui en partent."""
    y = Y(yn)
    PT.hull(g, x - 0.24, x + 0.24, y - 0.24, y + 0.24, 0.0, 0.14, ins=(0.03, 0.03, 0.03), panel=0.2,
            mats=[M["bleu_machine"], M["steel_dk"]], rivet_step=0.1)
    g.box((x, y - 0.24 - 0.006, 0.08), (0.14, 0.012, 0.07), M["hazy"], "flat", what="haute_tension")
    # spirale primaire (2 spires larges) et ses poteaux de porcelaine
    for kk, R_ in enumerate((0.19, 0.155)):
        g.torus((x, y, 0.16 + 0.012 * kk), "z", R_, 0.012, M["copper"], n=36, m=6, what="primaire")
    for t in range(3):
        a = TAU * t / 3 + 0.5
        F.post_insulator(g, (x + math.cos(a) * 0.19, y + math.sin(a) * 0.19, 0.14), 3, 0.035, h=0.03)
    # bobine secondaire : âme sombre, spires de cuivre jointives
    z0, z1 = 0.14, 0.5
    g.cyl((x, y, (z0 + z1) / 2), "z", 0.1, z1 - z0, M["steel_dk"], n=24, what="ame_bobine")
    ns = int((z1 - z0 - 0.04) / 0.022)
    for t in range(ns):
        g.torus((x, y, z0 + 0.03 + t * 0.022), "z", 0.105, 0.0105, M["copper"], n=28, m=6, what="spire")
    # tore d'aluminium (âme pleine : aucun jour par son trou)
    zt = z1 + 0.045
    g.torus((x, y, zt), "z", 0.15, 0.05, M["steel_hi"], n=36, m=12, what="tore")
    g.cyl((x, y, zt), "z", 0.15, 0.07, M["steel_dk"], n=28, what="ame_tore")
    F.sphere(g, (x, y, zt + 0.045), 0.05, M["steel_hi"], n=16, m=8, what="borne")
    for t in range(5):
        a = TAU * t / 5 + 0.3
        if math.cos(a) > 0.3:
            continue   # ronde 1 : une décharge vers l'est touchait le canon nord en pose E (jour enfermé de 11 px)
        d = V((math.cos(a), math.sin(a), 0.25))
        streamer(g, V((x, y, zt)) + V((math.cos(a), math.sin(a), 0)) * 0.2, d, 0.17, n=4, amp=0.025)
    return zt


def socle_electric(g, k):
    M = g.M
    E = M["emit"]
    t1 = tesla_trapue(g, -1.12, 1.08, M, E)
    # nord-est : batterie de condensateurs BASSE (une tour à cet endroit traverse le canon nord en pose E : jour enfermé)
    PT.hull(g, 0.78, 1.46, Y(0.72), Y(1.18), 0.0, 0.06, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["bleu_machine"], M["steel_dk"]], rivet_step=0.1)
    PT.capacitors(g, (1.12, Y(0.95), 0.06), 4, 2, 0.062, 0.16, E)
    # (passe 4 : plus d'arc libre entre la tour et le sol ou la tête : chaque arc fermait un jour enfermé, 84 puis
    # 113 px hr ; les arcs vivent sur les canons et sur la pièce paire, entre pièces rapprochées)
    # ouest : transformateur (cuve à ailettes, 3 traversées isolées, bornes de cuivre)
    for (xx, yn) in ((-0.62, -1.3), (0.62, -1.3), (-0.5, -0.95), (0.5, -0.95)):
        F.post_insulator(g, (xx, Y(yn), 0.0), 4, 0.04, h=0.045)
    for yn in (-0.8, 0.82):
        F.post_insulator(g, (-1.2, Y(yn), 0.0), 5, 0.045, h=0.045)
    PT.hull(g, -1.49, -0.86, Y(-0.72), Y(0.72), 0.0, 0.62, ins=(0.02, 0.02, 0.02), panel=0.24,
            mats=[M["transfo"], M["transfo"], M["steel_dk"]], rivet_step=0.12)
    for i in range(11):  # ailettes de refroidissement sur le dessus
        yy = Y(-0.62) + i * 0.16
        g.box((-1.18, yy, 0.64), (0.54, 0.024, 0.05), M["steel_dk"], "hard", what="ailette")
    for s_ in (-1, 1):   # radiateurs latéraux à ailettes (face est et ouest du transformateur)
        for i in range(9):
            g.box((-1.18 + s_ * 0.335, Y(-0.5) + i * 0.17, 0.32), (0.05, 0.022, 0.44), M["transfo"], "hard",
                  what="ailette")
        for yn_ in (0.5, 0.2):
            PT.lamp(g, (-1.18 + s_ * 0.37, Y(yn_), 0.52), (s_, 0, 0.35), 0.042, E, cage=True)
    for i, yn in enumerate((-0.35, 0.0, 0.35)):
        zt = F.post_insulator(g, (-1.18, Y(yn), 0.66), 7, 0.06, h=0.045)
        g.cyl((-1.18, Y(yn), zt + 0.02), "z", 0.03, 0.04, M["copper"], n=10, what="borne")
    g.box((-1.18, Y(-0.72) - 0.03, 0.3), (0.22, 0.012, 0.12), M["hazy"], "flat", what="plaque_danger")
    g.box((-1.18, Y(-0.72) - 0.036, 0.3), (0.06, 0.012, 0.08), M["hazk"], "flat", what="eclair")
    # est : touret de câble de cuivre (flasques face au sud), sur chevalet
    xr, yr, zr = 1.2, Y(0.0), 0.48
    for s in (-1, 1):
        # ronde 2 : flasques vert d'eau (le grand disque de bois sombre faisait une tache noire à l'est)
        g.cyl((xr, yr + s * 0.14, zr), (0, 1, 0), 0.46, 0.04, M["bleu_machine"], n=36, style="soft", what="flasque")
        F.bolts_ring(g, (xr, yr + s * 0.14 - 0.024 * (s < 0), zr), (0, -1, 0), 0.3, 10, M["rivet"], r=0.013)
        g.box((xr, yr + s * 0.2, 0.24), (0.08, 0.04, 0.48), M["steel_dk"], "hard", what="chevalet")
    # câble gainé enroulé (noir et rouge) : plus de cuivre plein sur le socle (passe 4)
    for kk in range(8):
        g.torus((xr, yr - 0.105 + kk * 0.03, zr), (0, 1, 0), 0.33, 0.016, M["redcable"] if kk % 3 == 1 else M["rubber"],
                n=32, m=6, what="spire")
    g.cyl((xr, yr - 0.16, zr), (0, 1, 0), 0.06, 0.03, M["steel_dk"], n=14, what="moyeu")
    # sud-est du touret : sphère de décharge sur poteau isolé
    zt = F.post_insulator(g, (0.95, Y(-0.72), 0.0), 6, 0.05, h=0.05)
    F.sphere(g, (0.95, Y(-0.72), zt + 0.1), 0.1, M["steel_hi"], n=20, m=12, what="sphere")
    # câbles sur isolateurs, jeu de barres
    link(g, 6, [(-0.9, Y(0.2), 0.4), (-0.84, Y(0.2), 0.52), (-0.66, Y(0.16), 0.58)], 0.06)
    link(g, 6, [(-1.0, Y(1.0), 0.3), (-0.6, Y(0.9), 0.5), (-0.3, Y(0.7), 0.6)], 0.06)
    link(g, 6, [(0.9, Y(0.7), 0.2), (0.7, Y(0.62), 0.32), (0.5, Y(0.52), 0.4)], 0.06)
    for i in range(2):
        g.box((0.82 + i * 0.07, Y(0.42), 0.36), (0.03, 0.4, 0.03), M["copper"], "hard", what="barre")
    for s in (0.82, 0.89):
        PT.insulators(g, (s, Y(0.52), 0.18), 3, 0.03, h=0.06)
    g.halo((-1.12, Y(1.08), 0.6), M["_emit_rgb"], 12.0)
    PT.hull(g, -0.7, 0.3, Y(0.92), Y(1.36), 0.0, 0.08, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["bleu_machine"], M["steel_dk"]], rivet_step=0.1)
    # passe 5 : flanc nord, 4 GROSSES PILES D'ISOLATEURS de porcelaine blanche (0,17 t de large) en rang, jeu de
    # barres de cuivre posé dessus (au lieu de la batterie de condensateurs basse, illisible au zoom 1)
    for xx in (-0.58, -0.32, -0.06, 0.2):
        zt = PT.insulators(g, (xx, Y(1.14), 0.08), 5, 0.085, h=0.05)
    g.box((-0.19, Y(1.14), zt + 0.01), (0.86, 0.035, 0.03), M["copper"], "hard", what="barre")
    # passe 4 : poteaux d'isolateurs de porcelaine devant le transformateur (piles blanches lisibles)
    for (xx, yn) in ((-1.42, -0.92), (-1.2, -0.95), (-0.98, -0.92), (1.42, -0.5), (1.45, 0.62),
                     (-0.82, -1.36), (0.82, -1.36)):
        F.post_insulator(g, (xx, Y(yn), 0.0), 5, 0.045, h=0.045)
    for (xx, yn) in ((-1.45, -0.7), (-0.95, -0.7), (1.45, 0.45), (0.85, -0.45)):
        PT.lamp(g, (xx, Y(yn), 0.06), (0, -0.3, 1), 0.03, E, cage=True)
    g.halo((1.12, Y(1.12), 0.4), M["_emit_rgb"], 10.0)
    g.halo((0.95, Y(-0.72), 0.6), M["_emit_rgb"], 8.0)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : câbles torsadés sur isolateurs (en l'air : isolateurs enfilés sur le faisceau)
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » de l'électricité)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    PT.cable_run(g, P, 3, 0.02, 0.045, [M["rubber"], M["redcable"], M["rubber"]])
    if kind != "arch":
        for p in P[1:-1]:
            zz = p.z
            g.cyl((p.x, p.y, zz - 0.07), "z", 0.02, 0.1, M["steel_dk"], n=8, what="support")
            PT.insulators(g, (p.x, p.y, zz - 0.02), 2, 0.032, h=0.026)
    else:  # en l'air : isolateurs enfilés sur le faisceau, aucune pièce qui pend dans le vide
        for p in P[1:-1]:
            g.cyl(p, "z", 0.05, 0.03, M["accent"], n=14, style="soft", what="isolateur")
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
# Pièce du niveau 12 : 2 piles de condensateurs à éclateur coiffées d'un tore de Tesla, arc entre les pointes
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
        zt = spark_stack(g, (x, y, 0.0), E, 1.5)
        g.box((x - sx * 0.1, y, zt + 0.02), (0.12, 0.016, 0.016), E, "flat", what="arc")
    _halo(g, [(-cx, Y(cy), 0.5), (cx, Y(cy), 0.5)], 10.0)


def spark_stack(g, c, emat, s=1.0):
    """Pile de condensateurs à éclateur (électricité) : colonne d'isolateurs trapue coiffée d'un tore de Tesla."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + 0.04), "z", 0.12 * s, 0.08, M["steel_dk"], n=20, style="soft", what="embase")
    F.bolts_ring(g, (x, y, z + 0.08), (0, 0, 1), 0.1 * s, 6, M["rivet"], r=0.013)
    g.cyl((x, y, z + 0.08 + 0.07 * s), "z", 0.08 * s, 0.14 * s, M["bleu_machine"], n=18, what="condensateur")
    g.tube_shell((x, y, z + 0.12 + 0.07 * s), "z", 0.088 * s, 0.07 * s, 0.025, M["brass"], n=18, what="cerclage")
    zt = PT.insulators(g, (x, y, z + 0.08 + 0.14 * s), 4, 0.06 * s, h=0.035)
    g.torus((x, y, zt + 0.03), "z", 0.075 * s, 0.024 * s, M["copper"], n=24, m=8, what="tore")
    # âme pleine du tore (sinon le sol se voit par son trou : contrôle des trous enfermés)
    g.cyl((x, y, zt + 0.03), "z", 0.075 * s, 0.03, M["steel_dk"], n=20, what="ame_tore")
    g.cyl((x, y, zt + 0.045), "z", 0.035, 0.05, M["copper"], n=10, what="borne")
    return zt + 0.06


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon-bobine
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    M = g.M
    H = c.H
    w_coil(g, c, x, sx)
    y0 = H["recv"][0]
    PT.lamp(g, (x - sx * H["wr"] * 0.25, y0 + 0.1, H["zg"] + H["hr"] + 0.03), (0, 0.4, 1), 0.026, M["emit"], cage=True)


def helix(g, x, ya, yb, z, rc, pitch, rw, mat, phase=0.0):
    """Spire OUVERTE (fil de cuivre enroulé en hélice, pas large) autour de l'axe y : on voit les tubes entre les
    spires."""
    n = max(8, int((yb - ya) / pitch * 14))
    pts = []
    for i in range(n + 1):
        t = i / n
        a = phase + TAU * (yb - ya) / pitch * t
        pts.append(V((x + rc * math.cos(a), ya + (yb - ya) * t, z + rc * math.sin(a))))
    g.tube(pts, rw, mat, n=8, what="spire")


def w_coil(g, c, x, sx):
    """Époque 6 (passe 4, RÈGLE D'OR 1) : le canon de lignée complet (corps.canon_lignee : rosette de 4 tubes séparés,
    frein en bloc, culasse, moteur bobiné, caisse) SANS jaquette perforée, et l'organe électrique AJOUTÉ autour :
      - BOBINE OUVERTE sur la moitié arrière : hélice de fil de cuivre à spires espacées (les tubes se voient entre
        les spires), tenue par 2 peignes d'isolateurs blancs longitudinaux (aucune bague claire horizontale) ;
      - anneau isolateur de porcelaine derrière le frein (petit, sombre-cerclé), 2 électrodes et un arc à la bouche ;
      - SPHÈRE DE DÉCHARGE sur pile d'isolateurs blancs, posée sur la culasse, arc vers la bobine.
    Aucun manchon de cuivre plein (il rappelait la vapeur : défaut de la passe 3)."""
    M = g.M
    H = c.H
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    L, rr, rb = H["L"], H["rr"], H["rb"]
    corps.canon_lignee(g, c, x, sx, recv_mats=("bleu_machine", "porcelaine_capot"), jaquette=0.0, frein=True,
                       frein_mat="steel", bague_mat="bakelite", masque_mats=("bleu_machine", "porcelaine_capot"))
    rc = rr + rb + 0.045
    ya, yb = y1 + 0.08, y1 + L * corps.JAQUETTE_MAX
    helix(g, x, ya, yb, zg, rc, 0.075, 0.017, M["copper"])
    for s in (-1, 1):   # peignes d'isolateurs longitudinaux (porcelaine), sur les flancs
        g.box((x + s * (rc + 0.012), (ya + yb) / 2, zg), (0.03, yb - ya + 0.06, 0.05), M["accent"], "soft",
              what="peigne")
        for k in range(4):
            yy = ya + (yb - ya) * (k + 0.5) / 4
            g.cyl((x + s * (rc + 0.03), yy, zg), (1, 0, 0), 0.03, 0.03, M["accent"], n=12, style="soft",
                  what="isolateur")
    for yy in (ya - 0.03, yb + 0.03):   # flasques sombres de bobine (bagues sombres : pose N sans cheminée)
        g.tube_shell((x, yy, zg), "y", rc + 0.03, rr + rb * 0.4, 0.03, M["steel_dk"], n=28, what="flasque")
        F.bolts_ring(g, (x, yy, zg), (0, 1, 0), rc + 0.03, 6, M["rivet"], r=0.014, phase=0.3, skip_down=-0.3)
    # anneau isolateur derrière la bouche ; passe 5 : plus d'électrodes ni d'arc DEVANT la bouche (sans le frein en
    # bloc du kit, ils enfermaient du sol : 57 px en tête E, 35 px en tête N). L'ARC court maintenant SUR le faisceau,
    # de la bobine à l'anneau (environ 0,5 t), entre deux petites piles d'isolateurs : il se détache sur les tubes, pas
    # sur le sol, et il est plus long, donc lisible par la lueur.
    ybb = y1 + L
    g.tube_shell((x, ybb - 0.07, zg), "y", rr + rb + 0.04, rr + rb * 0.3, 0.035, M["accent"], n=28, what="isolateur")
    za = zg + rr + rb + 0.012
    ea, eb = yb + 0.06, ybb - 0.09
    # (l'arc reste au ras du dessus des tubes : plus haut, il laisse voir le sol entre lui et le faisceau)
    for yy in (ea, eb):
        g.cyl((x, yy, za - 0.005), "z", 0.03, 0.03, M["accent"], n=14, style="soft", what="isolateur")
        F.sphere(g, (x, yy, za + 0.025), 0.022, M["copper"], n=10, m=6, what="pointe")
    arc(g, V((x, ea + 0.02, za + 0.02)), V((x, eb - 0.02, za + 0.02)), 7, 0.02)
    # sphère de décharge sur pile d'isolateurs, posée sur la culasse ; arc vers la bobine
    ps = (x - sx * wr * 0.15, (y0 + y1) / 2 + 0.02, zg + hr + 0.01)
    zt = PT.insulators(g, ps, 3, 0.05, h=0.04)
    F.sphere(g, (ps[0], ps[1], zt + 0.065), 0.075, M["steel_hi"], n=18, m=10, what="sphere_decharge")
    arc(g, V((ps[0], ps[1] + 0.06, zt + 0.07)), V((x, ya + 0.05, zg + rc + 0.02)), 3, 0.03)


def arc(g, p0, p1, n, amp):
    """Arc électrique : ligne brisée lumineuse fine entre deux pointes (< 0,05 t²)."""
    rng = g.rng
    d = p1 - p0
    side = d.cross(V((0, 0, 1)))
    if side.length < 1e-4:
        side = V((1, 0, 0))
    side.normalize()
    pts = [p0]
    for i in range(1, n):
        t = i / n
        pts.append(p0 + d * t + side * amp * (rng.random() - 0.5) * 2 + V((0, 0, amp * (rng.random() - 0.5))))
    pts.append(p1)
    for a, b in zip(pts, pts[1:]):
        e = b - a
        g.cyl((a + b) / 2, e, 0.008, e.length + 0.006, g.M["emit"], n=6, style="flat", what="arc")


# ------------------------------------------------------------------------------------------------
# Masque, nacelle, tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=ST["gmask"], fentes=((0.0, 1.1),), visiere=("steel_dk", 0.03),
                        coax=dict(fut="gun", manchon=ST["band"], manchon_y=0.3, manchon_r=0.046, manchon_L=0.12,
                                  anneau=True))


def nacelle(g, c):
    """Tour de Tesla dorsale : pile d'isolateurs, tore de cuivre, deux piles latérales, arcs cyan."""
    M = g.M
    bx, yb0, yb1, ztop, yc = c.nac
    zt6 = PT.insulators(g, (0.0, yc, ztop), 5, 0.05, h=0.036)
    g.torus((0.0, yc, zt6 + 0.03), "z", 0.1, 0.03, M["copper"], n=28, m=8, what="tore")
    g.cyl((0.0, yc, zt6 + 0.03), "z", 0.06, 0.05, M["copper"], n=14, what="borne")
    for sx in (-1, 1):
        zs6 = PT.insulators(g, (sx * bx * 0.62, yc - 0.02, ztop), 3, 0.036, h=0.032)
        g.cyl((sx * bx * 0.62, yc - 0.02, zs6 + 0.01), "z", 0.03, 0.03, M["copper"], n=10, what="borne")
        p0 = V((sx * bx * 0.62, yc - 0.02, zs6 + 0.03))
        p1 = V((sx * 0.1, yc, zt6 + 0.03))
        g.cyl((p0 + p1) / 2, p1 - p0, 0.009, (p1 - p0).length, M["emit"], n=6, style="flat", what="arc")


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    zs, rz = H["zs"], H["rz"]
    side = c.side
    k = KIN
    F.slits(g, R, c.rt + 0.1 + 0.02 * side, 7, M["emit"], a0=math.pi * 0.62, span=math.pi * 1.76)
    F.voyants_tete(g, H, 18)
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

    def rad_at(z):
        t = max(0.0, min(1.0, (z - zs) / rz))
        return R * math.sqrt(max(0.0, 1 - t * t))
    # signature de coupole (passe 4 : plus de ceinture de cuivre pleine, qui rappelait la vapeur) : couronne de
    # 6 poteaux d'isolateurs de porcelaine sur le bas de la coupole, pile d'isolateurs et boule de décharge
    zc6 = zs + 0.05
    for t in range(6):
        a = math.pi * 0.1 + math.pi * 0.8 * t / 5 + math.pi
        p = (math.cos(a) * rad_at(zc6) * 0.98, math.sin(a) * rad_at(zc6) * 0.98, zc6)
        ztp = PT.insulators(g, p, 3, 0.035, h=0.03)
        g.cyl((p[0], p[1], ztp + 0.01), "z", 0.014, 0.03, M["copper"], n=8, what="borne")
    # ronde 2 (silhouette d'âge sur la coupole) : TÊTE DE TESLA à la place libre de la coupole (corps.accroche) :
    # pile d'isolateurs blancs, gros tore d'aluminium à âme pleine, borne, 4 décharges cyan ouvertes vers l'arrière et
    # le haut (aucune vers les canons), halo cyan
    a = corps.accroche(c, "coupole")
    p = V((a["x"], a["y"], a["z"] - 0.02))
    g.cyl(p, "z", 0.075, 0.05, M["fonte_bleue"], n=16, style="soft", what="embase")
    F.bolts_ring(g, p + V((0, 0, 0.025)), (0, 0, 1), 0.06, 6, M["rivet"], r=0.011)
    zt = PT.insulators(g, (p.x, p.y, p.z + 0.025), 3, 0.055, h=0.04)
    rt = max(0.1, min(0.15, a["r"] * 0.7))
    g.torus((p.x, p.y, zt + 0.035), "z", rt, rt * 0.33, M["steel_hi"], n=36, m=12, what="tore")
    g.cyl((p.x, p.y, zt + 0.035), "z", rt, rt * 0.45, M["steel_dk"], n=28, what="ame_tore")
    F.sphere(g, (p.x, p.y, zt + 0.035 + rt * 0.3), 0.045, M["steel_hi"], n=14, m=8, what="borne")
    for t in range(4):
        aa = math.pi * 1.1 + math.pi * 0.8 * t / 3   # repère de la tête : les canons sont vers +y, l'arrière vers -y
        d = V((math.cos(aa), math.sin(aa), 0.45))
        streamer(g, V((p.x, p.y, zt + 0.035)) + V((math.cos(aa), math.sin(aa), 0)) * (rt * 1.3), d, 0.12, n=3,
                 amp=0.02)
    g.halo((p.x, p.y, zt + 0.1), M["_emit_rgb"], 10.0)
