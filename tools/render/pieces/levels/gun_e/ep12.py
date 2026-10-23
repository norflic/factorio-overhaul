"""Époque 12 · Supraconducteurs (ère IV, 5×5, niveaux 23 et 24). Constructeur : PLAGE HAUTE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 12) : « chrome, givre, anneaux ».
Quatrième passe (23/10), corrections du constructeur de la plage haute sur le portage de la passe 3 (plus de faisceau
rotatif du tout, règle d'or 1 ; anneaux lus « pneus noirs ») :
  - ARME : canon à RAILS PARALLÈLES autour du faisceau de la lignée : la ROSETTE de 6 tubes au centre, visible sur
    toute la moitié avant, deux RAILS noirs à arête chromée et conducteur de cuivre de part et d'autre ; 4 ANNEAUX
    magnétiques chromés À FACETTES (bande claire, pas un tore noir) sur la moitié arrière, avec un VIDE sombre visible
    entre l'anneau et les rails (disque noir mince : aucune transparence, donc aucun trou enfermé), tenus par des
    entretoises fines (rien ne flotte) ; anneau-bouche en cadre chromé à fentes cyan, rosace éclairée au centre ;
  - MOITIÉ SUD propre à l'époque : trémie enjambée par deux ARCHES MAGNÉTIQUES chromées sur pieds, CELLULES
    CRYOGÉNIQUES (dewars à cols chromés et givre) à la place des caisses ouvertes, tourelles secondaires ceintes d'un
    GRAND ANNEAU chromé horizontal, VANNE CRYOGÉNIQUE à soufflets chromés et mousse givrée au sud-est ;
  - chrome un peu moins clair (albédo 0,7) : aucune bague blanche.
Inchangés de la passe 3 : compresseurs cryogéniques à l'ouest, portiques à grands anneaux à l'est et au nord-ouest,
liaisons (mousse givrée, tuyaux chromés à soufflets), dewars sur la nacelle, foyers cyan glacé, pièce paire (2 bobines
sur pylône), canon de coupole (petit canon à rails, la rosette visible devant).
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

EPOQUE = 12
NOM = "Supraconducteurs"
# passe 5, ronde 2 : liserés et lueurs douces plus forts (force 1,0 au lieu de 0,7) : la lumière CONTINUE cyan glacé
# est la marque de l'âge, et ce qui le place au-dessus du titane (11) au premier coup d'œil
FOYER = ages.FOYER[12]
CANON = dict(L=2.2, nb=6, rb=0.06, rr=0.145)
PLATEFORME = dict(chanfrein=0.15)
# passe 5, ronde 1 (consigne du DC du 23/10 : TOUT le bâtiment change) : l'âge des supraconducteurs est un bâtiment
# GIVRÉ, blanc bleuté, à structure NOIR PROFOND et arêtes CHROME, sur un caillebotis de CHROME à liseré CYAN glacé :
# le contraste noir, givre et chrome, et le cyan continu, le séparent du titane brossé moyen de l'âge 11.
HABILLAGE = dict(ages.CORPS[12],   # lot K0 : MATIÈRE du corps et du pont (capots, acier, rivets, joints,
                 # danger, peinture, plateforme) : commun/ages.py ; ici, les clés propres à la mitrailleuse
                 jupe_cerclage="ring", chapeau="ring", tremie="jacket", tourelleau="chrome_mat",
                 munitions=("ring", "ring"),
                 grille_nacelle="ring",
                 # passe 5, ronde 4 (11-12 noté 2 et 3, 10-12 noté 3 et 3 : « même plan », « même silhouette ») :
                 # coupole en ANNEAUX (noyau givré ceint de deux anneaux chromés à doublure cyan : le triplet « chrome,
                 # givre, anneaux » devient la forme même de la tête) ; 10 : dôme, 11 : coque. Plateforme ronde essayée
                 # (rendu r4a) puis retirée : trou enfermé de 15 px au nord-est (e12-socle) et contour invisible au
                 # zoom 1 (organes d'angle)
                 forme_coupole=dict(forme="anneau", mat="frost", mat2="ring", lisere="emit"))


def _assise(g, c, x0, x1, yn0, yn1, rond=None, mat="jacket"):
    """Passe 5, ronde 4 (pont surélevé) : hauteur dont monter un organe d'époque posé au sol pour qu'il repose SUR le
    pont (corps.z_pont au centre de son emprise, moins le tablier de la lignée, 0,045). Si l'organe monte, une ASSISE
    pleine comble son emprise jusqu'au sol (rien ne flotte au bord du pont). rond : rayon d'une assise ronde ; sinon
    caisson rivé sur l'emprise (x0..x1, yn0..yn1 en tuiles de jeu)."""
    xc, yc = (x0 + x1) / 2, (yn0 + yn1) / 2
    dz = max(0.0, corps.z_pont(c, xc, yc) - 0.045)
    if dz > 0.004:
        M = g.M
        if rond:
            g.cyl((xc, Y(yc), (dz + 0.045) / 2), "z", rond, dz + 0.045, M[mat], n=32, what="assise")
        else:
            PT.hull(g, x0, x1, Y(yn0), Y(yn1), 0.0, dz + 0.045, ins=(0.012, 0.012, 0.012), panel=0.3,
                    mats=[M[mat], M["chrome_mat"]], rivet_step=0.16)
    return dz
# passe 5, ronde 2 (test des écarts : 11 contre 12 noté 2 et 3, 10 contre 12 noté 2 et 2, « même forteresse grise ») :
# le pont devient des DALLES NOIR MIROIR à JOINTS DE GIVRE blanc (fond « trim ») et liseré cyan : un sol sombre où les
# machines givrées et la lumière cyan ressortent, à l'opposé du titane clair uniforme de l'âge 11 et du faux plancher
# gris chaud de l'âge 10.
RECV = ("jacket", "steel_dk")


def matieres(metal, M):
    """Supraconducteurs : noir profond, chrome (reflets francs dans la limite commune), givre.
    Passe 5, ronde 1 (lu « bobines empilées, voyants cyan électriques » = Électricité, et « noir à lueurs cyan » en
    passe 4) : le chrome à métallicité 1 renvoyait le ciel sombre et se lisait NOIR vu de dessus (même fait que les
    tubes en pose N, kit passe 5) ; il passe en métal semi-diffus clair (métallicité 0,45, albédo 0,7) : de dessus,
    une bande ARGENT franche. Les grands capots du corps (coupole, jupe, colonne, nacelle, bras, masque) passent en
    GIVRE (gris bleuté pâle mat, clé « capots ») et les plaques ocre en chrome satiné : la tourelle entière se lit
    « froide », sans cuivre (le cuivre est la matière de l'Électricité)."""
    ages.matieres(12, metal, M)   # lot K0 : matières de l'âge, commun/ages.py (même ordre)
    # rôles de la mitrailleuse (alias), dans l'ordre d'origine
    M["copper"] = M["ring"]   # aucune pièce de cuivre à cette époque (conducteurs, munitions)
    M["pipe2"] = M["ring"]
    M["cable_b"] = M["cable_a"]
    M["spec"] = M["trim"]
    M["accent"] = M["trim"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 21 de l'industriel ; 12 : 2e tourelle secondaire)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    ng = 8
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, ng, M["emit"], a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, ng - 1, M["emit"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    # passe 5, ronde 4 : plateforme RONDE surélevée (HABILLAGE) ; chaque organe repose sur le pont (_assise)
    for (x0_, x1_, a_, b_) in ((1.35, 1.75, -1.15, 1.3), (-1.55, -1.3, -1.0, -0.3)):
        dz = _assise(g, c, x0_, x1_, a_, b_)
        g.push((0, 0, dz))
        P2.grating(g, x0_, x1_, Y(a_), Y(b_), 0.07, M)
        g.pop()
    dz = _assise(g, c, -1.9, -1.1, -2.05, -1.4)
    with at(g, -1.5, -1.72, 0.42, z=dz):
        dewar_rack(g, 0.8, 0.72, 3)
    dz = _assise(g, c, -1.35, -0.75, -2.6, -2.1)
    with at(g, -1.05, -2.35, 0.08, z=dz):
        dewar_rack(g, 0.6, 0.5, 2)
    tremie_arches(g, c)
    for (x, yn, rz) in [(1.78, -1.82, 0.0), (-2.0, -2.28, 0.25)]:
        dz = _assise(g, c, x - 0.42, x + 0.42, yn - 0.42, yn + 0.42, rond=0.43)
        with at(g, x, yn, 0.0, z=dz):
            P2.pedestal(g, 0.42, 0.0, 0.28, 8, M, [M["olive"], M["steel_dk"]], gussets=False)
            mini_turret(g, (0, 0, 0.28), 0.95, rz)
    dz = _assise(g, c, -2.42, -1.62, -0.95, 1.25)
    g.push((0, 0, dz))
    west(g)
    g.pop()
    conduit(g, [(-1.62, Y(0.55), 0.4 + dz), (-1.42, Y(0.6), 0.62 + dz), (-1.2, Y(0.5), 0.72 + dz)], 0.045)
    cables(g, [(-1.62, Y(-0.25), 0.4 + dz), (-1.42, Y(-0.3), 0.6 + dz), (-1.18, Y(-0.35), 0.68 + dz)])
    # nord-ouest : portique à grands anneaux posé en biais
    dz = _assise(g, c, -2.15, -1.3, 1.65, 2.4)
    with at(g, -1.72, 2.02, -0.55, z=dz):
        ring_gantry(g, 0.0, -0.38, 0.38, 0.34, 0.42)
    # est : portique à grands anneaux magnétiques (à la place des réservoirs)
    dz = _assise(g, c, 1.6, 2.4, -0.6, 1.15)
    g.push((0, 0, dz))
    ring_gantry(g, 2.0, Y(-0.6), Y(1.15), 0.42, 0.56)
    g.pop()
    dz = _assise(g, c, -2.45, -2.02, -2.3 / 1.4142, -1.66 / 1.4142)
    g.push((0, 0, dz))
    P3.cabinet(g, -2.45, -2.02, -2.3, -1.66, 0.0, 0.5, M, E, screen_=False)
    g.pop()
    # sud-est : vanne cryogénique (soufflets chromés, mousse givrée) à la place de la vanne à volant
    dz = _assise(g, c, 1.68, 2.36, -1.18, -0.85)
    g.push((0, 0, dz))
    cryo_valve(g, 1.68, 2.36, Y(-1.18), Y(-0.85), 0.3)
    g.pop()
    hose(g, [(1.68, Y(-1.0), 0.3 + dz), (1.45, Y(-1.05), 0.36 + dz), (1.22, Y(-0.85), 0.52 + dz)], 0.05)
    dz = max(0.0, corps.z_pont(c, 2.0, 0.3) - 0.045)
    hose(g, [(1.7, Y(1.05), 0.62 + dz), (1.45, Y(0.95), 0.98 + dz), (1.15, Y(0.75), 0.82 + dz)], 0.06)
    dz = _assise(g, c, 1.25, 2.25, 1.95, 2.42)
    g.push((0, 0, dz))
    P3.cabinet(g, 1.25, 2.25, Y(1.95), Y(2.42), 0.0, 0.56, M, E, screen_=False)
    signature(g, (1.55, Y(2.18), 0.6))
    g.pop()
    # passe 5, ronde 1 : SILHOUETTE de l'âge, deux hautes TOURS CRYOGÉNIQUES givrées à anneaux de chrome et bagues
    # cyan glacé (à la place des caisses du nord)
    for x in (-0.42, 0.42):
        dz = _assise(g, c, x - 0.22, x + 0.22, 1.7, 2.14, rond=0.23)
        g.push((0, 0, dz))
        tour_cryo(g, x, Y(1.92))
        g.pop()
    dz = max(0.0, corps.z_pont(c, -2.24, -1.98 / 1.4142) - 0.045)
    signature(g, (-2.24, -1.98, 0.53 + dz), 2)
    for x in (-0.68, 0.68):
        PT.lamp(g, (x, Y(-2.4) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    _halo(g, [(-2.0, Y(-1.1), 0.5), (1.78, Y(-2.1), 0.6), (0.0, Y(-2.5), 0.5), (2.0, Y(0.3), 0.5),
              (1.75, Y(1.8), 0.5)], 20.0)


def west(g):
    """Groupe de l'ouest : COMPRESSEURS CRYOGÉNIQUES (3 dewars noirs à cols chromés, givre, tuyaux de mousse)."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = -2.42, -1.62, Y(-0.95), Y(1.25), 0.52
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    F.plinth(g, x0, x1, y0, y1, 0.18)
    # trappes de visite givrées sur les faces du socle (pièces lisibles au zoom 2)
    F.hatches(g, (x1 + 0.005, y0 + 0.15, 0.09), (x1 + 0.005, y1 - 0.15, 0.09), 9, (1, 0, 0), M["ring"],
              size=(0.07, 0.06), frame=M["jacket"])
    F.hatches(g, (x0 + 0.1, y0 - 0.005, 0.09), (x1 - 0.1, y0 - 0.005, 0.09), 3, (0, -1, 0), M["trim"],
              size=(0.07, 0.06), frame=M["jacket"])
    r = (x1 - x0) * 0.32
    ys = [y0 + (y1 - y0) * f for f in (0.18, 0.5, 0.82)]
    for i, yy in enumerate(ys):
        hh = 0.62 + 0.06 * (i % 2)
        g.cyl((cx, yy, 0.18 + hh / 2), "z", r, hh, M["frost"], n=28, what="dewar")   # passe 5 : virole givrée
        for zz in (0.3, 0.18 + hh * 0.7):
            g.tube_shell((cx, yy, zz), "z", r + 0.02, r - 0.01, 0.05, M["ring"], n=28, what="collier")
            for k_ in range(10):   # collier à griffes : fentes sombres
                a = TAU * (k_ + 0.5) / 10
                g.box((cx + (r + 0.021) * math.cos(a), yy + (r + 0.021) * math.sin(a), zz), (0.022, 0.006, 0.054),
                      M["void"], "flat", R=Matrix.Rotation(a + math.pi / 2, 3, "Z"), what="fente")
        g.cyl((cx, yy, 0.18 + hh + 0.06), "z", r * 0.42, 0.12, M["ring"], n=20, what="col")
        g.tube_shell((cx, yy, 0.18 + hh + 0.01), "z", r * 0.5, r * 0.4, 0.03, M["trim"], n=20, what="givre")
        g.box((cx - r * 0.7, yy - r * 0.7, 0.4), (0.06, 0.03, 0.12), M["trim"], "flat", what="givre")
        # plaques de givre éparses sur la virole noire (taches claires isolées) et boulons chromés de cerclage
        for k_ in range(7):
            a = -math.pi * 0.15 - math.pi * 0.7 * k_ / 6
            d = V((math.cos(a), math.sin(a), 0))
            zz = 0.36 + 0.07 * (k_ % 3) + 0.12 * (k_ % 2)
            g.box(V((cx, yy, zz)) + d * (r + 0.004), (0.05, 0.008, 0.035), M["trim"], "flat",
                  R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="givre")
            g.dome(V((cx, yy, 0.3)) + d * (r + 0.02), d, 0.02, M["steel_hi"], what="boulon")
        P3.lamp_group(g, (cx + r * 0.2, yy - r - 0.005, 0.45), (1, 0, 0), (0, -1, 0), E, M, n=2,
                      shapes=("fente", "rond"))
    g.tube([V((cx + r * 0.6, ys[0], 0.75)), V((cx + r * 0.9, (ys[0] + ys[1]) / 2, 0.85)),
            V((cx + r * 0.6, ys[1], 0.78))], 0.04, M["pipe"], n=10, what="mousse")
    g.tube([V((cx + r * 0.6, ys[1], 0.78)), V((cx + r * 0.9, (ys[1] + ys[2]) / 2, 0.88)),
            V((cx + r * 0.6, ys[2], 0.75))], 0.04, M["pipe"], n=10, what="mousse")
    # colliers noirs à pinces sur la mousse (le conduit clair se lit en tronçons)
    for j in range(2):
        for f in (0.2, 0.5, 0.8):
            yy = ys[j] + (ys[j + 1] - ys[j]) * f
            zz = 0.78 + 0.07 * math.sin(math.pi * f) + (0.01 if j else 0.0)
            g.cyl((cx + r * 0.6 + r * 0.3 * math.sin(math.pi * f), yy, zz), "y", 0.05, 0.03, M["jacket"], n=12,
                  style="hard", what="collier")


def ring_gantry(g, x, y0, y1, R, zc):
    """Âme noire couchée le long de y, 3 GRANDS anneaux chromés debout (rayon R), tenus par des pinces et un berceau ;
    givre aux joints ; segments cyan. Aucun anneau ne flotte : chaque anneau repose sur un berceau boulonné."""
    M = g.M
    E = M["emit"]
    L = y1 - y0
    F.plinth(g, x - R * 0.85, x + R * 0.85, y0 - 0.05, y1 + 0.05, 0.1)
    for s in (-1, 1):
        F.hatches(g, (x + s * (R * 0.85 + 0.005), y0 + 0.05, 0.05), (x + s * (R * 0.85 + 0.005), y1 - 0.05, 0.05), 6,
                  (s, 0, 0), M["ring"], size=(0.06, 0.05), frame=M["jacket"])
    g.cyl((x, (y0 + y1) / 2, zc), "y", R * 0.34, L, M["jacket"], n=24, what="ame")
    for f in (0.0, 1.0):
        g.cyl((x, y0 + f * L, zc), "y", R * 0.4, 0.06, M["ring"], n=24, what="bride")
    for i in range(3):
        yy = y0 + L * (0.2 + 0.3 * i)
        g.tube_shell((x, yy, zc), "y", R, R * 0.74, 0.13, M["ring"], n=56, what="anneau")
        F.bolts_ring(g, (x, yy - 0.066, zc), (0, -1, 0), R * 0.87, 8, M["rivet"], r=0.013, phase=0.2, skip_down=-0.5)
        for d in F.ring_dirs(12, math.pi / 12, -0.7):   # bobine à secteurs
            g.box(V((x, yy, zc)) + d * (R + 0.002), (0.024, 0.14, 0.016), M["void"], "flat", R=F.Rax(d), what="fente")
        g.torus((x, yy, zc), "y", R, 0.014, M["steel_dk"], n=56, m=6, what="jonc")
        # berceau : 2 jambes vers le socle + traverse (l'anneau y repose)
        for s in (-1, 1):
            a = -math.pi / 2 + s * 0.6
            d = V((math.cos(a), 0, math.sin(a)))
            p = V((x, yy, zc)) + d * R
            g.box(((p.x + x + s * R * 0.7) / 2, yy, p.z / 2 + 0.05), (0.08, 0.1, p.z - 0.02), M["steel_dk"], "hard",
                  what="jambe")
        g.box((x, yy, 0.16), (R * 1.4, 0.16, 0.08), M["steel_dk"], "hard", what="traverse")
        # entretoises de l'âme à l'anneau (jour de « lévitation » fermé)
        for d in F.ring_dirs(4, math.pi / 4, -2):
            g.box(V((x, yy, zc)) + d * (R * 0.55), (0.05, 0.07, R * 0.42), M["steel_dk"], "hard", R=F.Rax(d),
                  what="entretoise")
        for d in F.ring_dirs(3, 0.5, -0.3):
            g.box(V((x, yy - 0.068, zc)) + d * (R * 0.87), (0.07, 0.004, 0.024), E, "flat", R=F.Rax(d),
                  what="segment_lum")
        g.box((x - R * 0.5, yy + 0.07, zc + R * 0.75), (0.08, 0.03, 0.02), M["trim"], "flat", what="givre")


def signature(g, p, kind=0):
    """Petite pièce de signature : petite bobine supraconductrice chromée sur colonnettes, givre."""
    M = g.M
    p = V(p)
    for s in (-1, 1):
        g.cyl(p + V((s * 0.08, 0, 0.06)), "z", 0.015, 0.12, M["steel_dk"], n=8, what="colonnette")
    g.torus(p + V((0, 0, 0.13)), "x", 0.07, 0.022, M["ring"], n=24, m=8, what="bobine")
    g.cyl(p + V((0, 0, 0.13)), "x", 0.03, 0.18, M["jacket"], n=12, what="noyau")
    g.box(p + V((0, -0.06, 0.02)), (0.16, 0.03, 0.03), M["trim"], "flat", what="givre")


def mini_turret(g, c, s, rz):
    """Tourelle secondaire SUPRACONDUCTRICE : couronne rivetée de la lignée, caisson noir profond à bandes chromées,
    GRAND ANNEAU chromé horizontal autour du caisson (vide sombre, 4 pinces), givre ; les DEUX ARMES sont celles de
    l'époque (petits canons à rails et anneaux)."""
    M = g.M
    E = M["emit"]
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["armor2"], n=32, style="soft", what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    PT.hull(g, -0.22 * s, 0.22 * s, -0.28 * s, 0.22 * s, 0.1 * s, 0.38 * s, ins=(0.03 * s, 0.03 * s, 0.06 * s),
            panel=0.22, mats=[M["jacket"], M["steel_dk"]])
    for yy in (-0.15 * s, 0.05 * s):
        g.box((0, yy, 0.385 * s), (0.4 * s, 0.05, 0.02), M["ring"], "hard", what="bande")
    # grand anneau chromé horizontal à facettes, tenu par 4 pinces, vide sombre entre anneau et caisson
    zr_ = 0.26 * s
    g.tube_shell((0, -0.03 * s, zr_), "z", 0.42 * s, 0.35 * s, 0.07 * s, M["ring"], n=12, style="hard", what="anneau")
    for k in range(12):   # bobine à secteurs : fentes sombres sur le dessus de l'anneau
        a = TAU * (k + 0.5) / 12
        g.box((0.385 * s * math.cos(a), -0.03 * s + 0.385 * s * math.sin(a), zr_ + 0.036 * s), (0.08 * s, 0.022, 0.006),
              M["void"], "flat", R=Matrix.Rotation(a, 3, "Z"), what="fente")
    g.tube_shell((0, -0.03 * s, zr_ - 0.01), "z", 0.352 * s, 0.24 * s, 0.012, M["void"], n=24, what="vide")
    for k in range(4):
        a = TAU * (k + 0.5) / 4
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((0, -0.03 * s, zr_)) + d * 0.32 * s, (0.1 * s, 0.04, 0.06 * s), M["steel_dk"], "hard",
              R=Matrix.Rotation(a, 3, "Z"), what="pince")
        g.box(V((0, -0.03 * s, zr_ + 0.036 * s)) + d * 0.385 * s, (0.04, 0.012, 0.004), E, "flat",
              R=Matrix.Rotation(a + math.pi / 2, 3, "Z"), what="segment_lum")
    g.box((-0.2 * s, -0.3 * s, zr_ + 0.04 * s), (0.08, 0.03, 0.012), M["trim"], "flat", what="givre")
    for sx in (-1, 1):
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=[M[k] for k in RECV])
        _gun12(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.022 * s, 0.05 * s)
    PT.lamp(g, (0.0, 0.12 * s, 0.38 * s + 0.01), (0, 0.35, 1), 0.035, E, cage=False)
    g.pop()


def tour_cryo(g, x, y, r=0.2, h=1.0):
    """Tour cryogénique (passe 5, ronde 1 : superstructure de l'âge des supraconducteurs, qui change le contour) :
    embase noire boulonnée, fût GIVRÉ, quatre ANNEAUX de chrome espacés, entre deux anneaux une BAGUE CYAN GLACÉ
    continue sur une gorge noire, calotte givrée et col chromé. Sommet à 1,16 (sous h_max 1,29 de la taille 5)."""
    M = g.M
    E = M["emit"]
    g.cyl((x, y, 0.05), "z", r + 0.06, 0.1, M["jacket"], n=28, what="embase")
    F.bolts_ring(g, (x, y, 0.1), (0, 0, 1), r + 0.035, 8, M["rivet"], r=0.012, phase=0.2)
    g.cyl((x, y, 0.1 + h / 2), "z", r, h, M["frost"], n=28, what="fut_givre")
    zs = [0.1 + h * f for f in (0.18, 0.42, 0.66, 0.9)]
    for zz in zs:
        g.torus((x, y, zz), "z", r + 0.018, 0.022, M["ring"], n=32, m=8, what="anneau_chrome")
    for z0, z1 in zip(zs[:-1], zs[1:]):
        zm = (z0 + z1) / 2
        g.cyl((x, y, zm), "z", r + 0.004, 0.05, M["jacket"], n=28, what="gorge")
        g.torus((x, y, zm), "z", r + 0.006, 0.009, E, n=32, m=6, what="bague_cyan")
    g.sphere((x, y, 0.1 + h), r, M["frost"], n=28, m=10, scale=(1, 1, 0.35), what="calotte")
    g.cyl((x, y, 0.1 + h + r * 0.35 + 0.02), "z", r * 0.35, 0.06, M["ring"], n=16, what="col")
    g.tube_shell((x, y, 0.1 + h + r * 0.35 + 0.05), "z", r * 0.42, r * 0.28, 0.02, M["trim"], n=16, what="givre")
    _halo(g, [(x, y - r - 0.05, 0.1 + h * 0.55)], 5.0)


def dewar_rack(g, w, d, n):
    """CELLULES CRYOGÉNIQUES (à la place de la caisse ouverte) : cadre bas noir, n dewars noirs debout à cols chromés,
    colliers chromés, givre aux cols, voyants cyan."""
    M = g.M
    E = M["emit"]
    PT.hull(g, -w / 2, w / 2, -d / 2, d / 2, 0.0, 0.1, ins=(0.015, 0.015, 0.015), panel=0.24,
            mats=[M["steel_dk"], M["jacket"]], rivet_step=0.12)
    r = min(w / n, d) * 0.36
    for i in range(n):
        x = -w / 2 + w * (i + 0.5) / n
        for j, y in enumerate((-d * 0.2, d * 0.22)):
            hh = 0.36 + 0.06 * ((i + j) % 2)
            g.cyl((x, y, 0.1 + hh / 2), "z", r, hh, M["frost"], n=20, what="dewar")
            g.tube_shell((x, y, 0.1 + hh * 0.35), "z", r + 0.014, r - 0.01, 0.035, M["ring"], n=20, what="collier")
            F.bolts_ring(g, (x, y, 0.1 + hh * 0.35), (0, 0, 1), r + 0.016, 5, M["rivet"], r=0.012, phase=-1.2)
            F.bolts_ring(g, (x, y, 0.1 + hh * 0.8), (0, 0, 1), r + 0.002, 4, M["rivet"], r=0.012, phase=-0.9)
            g.cyl((x, y, 0.1 + hh + 0.03), "z", r * 0.45, 0.06, M["ring"], n=14, what="col")
            g.tube_shell((x, y, 0.1 + hh + 0.004), "z", r * 0.6, r * 0.42, 0.02, M["trim"], n=14, what="givre")
            g.box((x, y - r - 0.003, 0.1 + hh * 0.6), (0.04, 0.006, 0.02), E, "flat", what="voyant")
            for a in (-2.2, -0.9):
                dv = V((math.cos(a), math.sin(a), 0))
                g.box(V((x, y, 0.1 + hh * 0.62)) + dv * (r + 0.003), (0.04, 0.008, 0.03), M["trim"], "flat",
                      R=Matrix((V((-dv.y, dv.x, 0)), dv, V((0, 0, 1)))).transposed(), what="givre")
    F.hatches(g, (-w / 2 + 0.06, -d / 2 - 0.005, 0.05), (w / 2 - 0.06, -d / 2 - 0.005, 0.05), 2 * n, (0, -1, 0),
              M["ring"], size=(0.06, 0.05), frame=M["jacket"])


def tremie_arches(g, c):
    """Trémie de l'époque : enjambée par deux ARCHES MAGNÉTIQUES chromées à facettes (bobines supraconductrices)
    posées sur des pieds blocs noirs (rien ne flotte), segments cyan, givre ; conduit cryogénique gainé de mousse
    givrée sur le flanc."""
    M = g.M
    E = M["emit"]
    x0, x1, y0, y1, h = c.tremie_box
    hw = (x1 - x0) / 2 + 0.16
    for f in (0.3, 0.7):
        yy = y0 + (y1 - y0) * f
        zt = h * (0.75 + 0.3 * f) + 0.12
        for s in (-1, 1):
            g.box((s * hw, yy, zt * 0.5), (0.12, 0.16, zt), M["jacket"], "hard", what="pied")
            g.box((s * hw, yy, 0.03), (0.2, 0.24, 0.06), M["steel_dk"], "hard", what="semelle")
            g.box((s * (hw + 0.062), yy, zt * 0.55), (0.006, 0.06, 0.02), E, "flat", what="voyant")
            F.hatches(g, (s * (hw + 0.061), yy, zt * 0.2), (s * (hw + 0.061), yy, zt * 0.85), 2, (s, 0, 0), M["ring"],
                      size=(0.06, 0.07), frame=M["steel_dk"])
        # arche : demi-anneau chromé à facettes sur les deux pieds
        n = 8
        R = hw
        for i in range(n):
            a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
            p0 = V((R * math.cos(a0), yy, zt + R * 0.35 * math.sin(a0)))
            p1 = V((R * math.cos(a1), yy, zt + R * 0.35 * math.sin(a1)))
            dd = p1 - p0
            Rm = Matrix((dd.normalized(), V((0, 1, 0)), dd.normalized().cross(V((0, 1, 0))))).transposed()
            g.box((p0 + p1) / 2, (dd.length + 0.01, 0.12, 0.1), M["ring"], "hard", R=Rm, what="arche")
            nz = Rm.col[2]
            for dy in (-0.035, 0.035):
                g.dome((p0 + p1) / 2 + nz * 0.05 + V((0, dy, 0)), nz, 0.013, M["rivet"])
        g.box((0, yy + 0.065, zt + R * 0.35 + 0.02), (0.2, 0.004, 0.02), E, "flat", what="segment_lum")
        g.box((-R * 0.6, yy, zt + R * 0.25 + 0.06), (0.1, 0.13, 0.02), M["trim"], "flat", what="givre")


def cryo_valve(g, x0, x1, y0, y1, h):
    """Vanne cryogénique (sud-est) : caisson noir, gros conduit de mousse givrée à soufflets chromés, cols, givre."""
    M = g.M
    E = M["emit"]
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.22, mats=[M["jacket"], M["steel_dk"]],
            rivet_step=0.12)
    w = x1 - x0
    for i, x in enumerate((x0 + w * 0.28, x0 + w * 0.72)):
        g.cyl((x, (y0 + y1) / 2, h + 0.08), "z", 0.07, 0.16, M["ring"], n=16, what="col")
        g.cyl((x, (y0 + y1) / 2, h + 0.01), "z", 0.11, 0.02, M["steel_dk"], n=16, what="bride")
        F.bolts_ring(g, (x, (y0 + y1) / 2, h + 0.02), (0, 0, 1), 0.095, 6, M["rivet"], r=0.012)
        g.hose([(x, (y0 + y1) / 2, h + 0.16), (x, (y0 + y1) / 2, h + 0.26)], 0.075, M["ring"], step=0.022)
        g.tube_shell((x, (y0 + y1) / 2, h + 0.27), "z", 0.085, 0.06, 0.03, M["trim"], n=16, what="givre")
    g.box((x0 + w * 0.5, y0 - 0.004, h * 0.6), (0.06, 0.008, 0.02), E, "flat", what="voyant")
    F.hatches(g, (x0 + 0.06, y0 - 0.005, h * 0.3), (x1 - 0.06, y0 - 0.005, h * 0.3), 5, (0, -1, 0), M["ring"],
              size=(0.06, 0.05), frame=M["steel_dk"])


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduits cryogéniques gainés de mousse givrée, soufflets chromés, câbles noirs épais
# ------------------------------------------------------------------------------------------------
def hose(g, ctrl, r):
    """Conduit cryogénique : gaine de mousse givrée, soufflets chromés aux bouts, bagues de givre."""
    M = g.M
    P, T = g.tube(g.spline(ctrl, 10), r * 1.3, M["pipe"], n=12, what="mousse")
    for i in (0, len(P) - 1):
        g.hose([tuple(P[i] - T[i] * 0.06), tuple(P[i] + T[i] * 0.06)], r * 1.4, M["ring"], step=0.025)
    for i in range(3, len(P) - 2, 7):
        g.cyl(P[i], T[i], r * 1.42, 0.025, M["trim"], n=12, style="flat", what="givre")


def cables(g, ctrl, n=3):
    """Deux câbles noirs épais."""
    M = g.M
    PT.cable_run(g, ctrl, 2, 0.032, 0.075, [M["cable_a"], M["cable_a"]])


def conduit(g, ctrl, r):
    """Conduit d'énergie noir : bagues lumineuses PAR GROUPES (chenillard), colliers chromés."""
    M = g.M
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["jacket"], n=10, what="conduit")
    R = g.resample(P, 0.075)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 4 in (1, 2):
            g.tube_shell(R[i], T2[i], r + 0.008, r * 0.5, 0.03, M["emit"], n=12, what="bague_lum")
        elif i % 4 == 3:
            g.tube_shell(R[i], T2[i], r + 0.016, r * 0.5, 0.03, M["pipe2"], n=12, what="collier")


def pipe(g, ctrl, r, valve_at=None):
    M = g.M
    g.pipe(ctrl, r, M["ring"], fl_mat=M["pipe2"], bolt_mat=M["rivet"])
    if valve_at is not None:
        p, ax = valve_at
        g.box(p, (r * 3.2, r * 3.2, r * 3.2), M["steel_dk"], "hard", what="corps_vanne")
        P2.handwheel(g, V(p) + V(ax).normalized() * (r * 1.6 + 0.06), ax, 0.07, M)


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 24 : 2 bobines d'accélération sur pylône
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.5, Y(-2.64), sx)
    _halo(g, [(-1.5, Y(-2.9), 0.4), (1.5, Y(-2.9), 0.4)], 16.0)


def even_piece(g, x, yb, sx):
    """BOBINE D'ACCÉLÉRATION SUR PYLÔNE : 2 anneaux chromés tenus par un pylône à pinces, noyau noir, sur la plinthe
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
    PT.hull(g, x - 0.12, x + 0.12, yb - 0.12, yb + 0.12, z0, z0 + 0.5, ins=(0.03, 0.03, 0.03), panel=0.25,
            mats=[M["steel_dk"], M["jacket"]], rivet_step=0.11)
    zc = z0 + 0.42
    g.cyl((x, yb, zc), "y", 0.06, 0.5, M["jacket"], n=16, what="noyau")
    for dy in (-0.14, 0.12):
        g.tube_shell((x, yb + dy, zc), "y", 0.23, 0.15, 0.07, M["ring"], n=40, what="anneau")
        # vide sombre entre l'anneau et le noyau (disque noir mince : aucun jour enfermé dans la pièce seule)
        g.cyl((x, yb + dy, zc), "y", 0.152, 0.01, M["void"], n=24, style="flat", what="vide")
        F.seg_ring_y(g, x, yb + dy - 0.037, zc, 0.19, 5, E)
        for s in (-1, 1):
            g.box((x + s * 0.17, yb + dy, zc - 0.13), (0.05, 0.09, 0.14), M["steel_dk"], "hard", what="pince")
    g.box((x, yb, zc - 0.21), (0.44, 0.1, 0.05), M["steel_dk"], "hard", what="traverse")
    g.box((x, yb + 0.2, zc + 0.2), (0.12, 0.05, 0.03), M["trim"], "flat", what="givre")


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon à rails dans de grands anneaux
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse, moteur arrière, arme d'époque, masque de canon,
    alimentation, voyants d'état, bandes chromées de culasse."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun12(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["ochre"], M["olive"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    for f in (0.28, 0.5):
        g.box((x - sx * wr * 0.22, y0 + (y1 - y0) * f, zg + hr + 0.012), (0.03, (y1 - y0) * 0.12, 0.012), M["emit"],
              "flat", what="etat")
    # 2 bandes chromées en travers de la culasse, givre aux joints
    zt = zg + hr + 0.012
    for f in (0.3, 0.62):
        yy = y0 + (y1 - y0) * f
        g.box((x, yy, zt + 0.01), (wr * 0.98, 0.06, 0.03), M["ring"], "hard", what="bande")
        g.box((x - wr * 0.3, yy - 0.04, zt + 0.004), (0.08, 0.025, 0.012), M["trim"], "flat", what="givre")


def _ring12(g, x, yy, z, ro, ri, w, k, struts=4):
    """Anneau magnétique supraconducteur : bande CHROMÉE à facettes larges (pas un tore noir : jamais un pneu),
    VIDE sombre entre l'anneau et ce qu'il entoure (disque mince noir, aucune transparence : aucun trou enfermé),
    entretoises fines qui tiennent l'anneau (rien ne flotte), segments cyan sur la face avant, givre."""
    M = g.M
    E = M["emit"]
    g.tube_shell((x, yy, z), "y", ro, ri, w, M["ring"], n=12, style="hard", what="anneau")
    # bobine à SECTEURS : fentes sombres entre les secteurs chromés (de dessus, l'anneau est une suite de plots
    # chromés, pas une barre continue)
    for d in F.ring_dirs(12, math.pi / 12, -0.7):
        g.box(V((x, yy, z)) + d * (ro + 0.002), (0.022, w * 1.08, 0.016), M["void"], "flat", R=F.Rax(d), what="fente")
    g.tube_shell((x, yy, z), "y", ri + 0.004, ri - 0.012 * k, w * 1.1, M["steel_dk"], n=24, what="jonc")
    g.cyl((x, yy, z), "y", ri - 0.01 * k, 0.012, M["void"], n=24, style="flat", what="vide")
    for d in F.ring_dirs(struts, math.pi / 4, -2):
        g.box(V((x, yy, z)) + d * (ri * 0.7), (0.022 * k, 0.03, ri * 0.62), M["steel_dk"], "hard", R=F.Rax(d),
              what="entretoise")
    if k >= 0.6:
        for d in F.ring_dirs(5, 0.0, -0.4):
            g.box(V((x, yy + w / 2 + 0.002, z)) + d * ((ri + ro) / 2), (0.05 * k, 0.004, 0.02), E, "flat",
                  R=F.Rax(d), what="segment_lum")
        g.box(V((x - ro * 0.55, yy, z + ro * 0.8)), (0.05, w * 1.05, 0.02), M["trim"], "flat", what="givre")
        # passe 5 : LISERÉ DE GIVRE blanc sur le bord supérieur de l'anneau (juges de la passe 4), en 3 plaques
        # suivant l'arrondi (de dessus : un trait blanc sur l'arête argent de chaque anneau)
        for a in (-0.42, 0.0, 0.42):
            d = V((math.sin(a), 0, math.cos(a)))
            g.box(V((x, yy, z)) + d * (ro + 0.004), (ro * 0.4, w * 1.12, 0.014), M["trim"], "flat",
                  R=Matrix.Rotation(a, 3, "Y"), what="givre")


def _gun12(g, x, y0, z, L, nb, rb, rr):
    """Quatrième passe : canon à RAILS PARALLÈLES autour du faisceau de la lignée (règle d'or 1). Au centre, la
    ROSETTE de 6 tubes (corps.rosette), visible sur toute la moitié avant ; de part et d'autre, deux RAILS noirs à arête
    chromée et conducteur de cuivre, sur toute la longueur ; sur la moitié arrière, 4 ANNEAUX magnétiques chromés à
    facettes enfilés autour (un VIDE sombre visible entre l'anneau et les rails, tenu par des entretoises fines) ;
    culasse cryogénique (2 cellules givrées) ; bouche en cadre chromé (anneau-bouche) à fente cyan, rosace éclairée
    au centre. De dessus (pose E) : rails | tubes | rails barrés de 4 bandes chromées ; de face : un cadre chromé."""
    M = g.M
    E = M["emit"]
    k = F.k_arme(rb, rr)
    R0 = rr + rb
    # passe 5, ronde 4 (pose N lue « cheminée » à la ronde 3 : rails et semelle de toute la longueur, anneaux jusqu'à
    # 0,48 L et cadre chromé à la bouche faisaient une colonne annelée coiffée) : CANON EFFILÉ du kit (faisceau qui
    # converge, manchon chromé reculé, dernier cinquième nu, pointes cyan) ; rails et semelle s'arrêtent au manchon
    # (0,78 L), les 4 anneaux se resserrent sur l'arrière (0,10 à 0,37 L) ; plus de cadre à la bouche
    corps.canon_effile(g, x, y0, z, L, nb, rb, rr, jaquette=0.0, bague_mat="ring", conv=0.62, frein=(0.62, 0.78))
    Lr = 0.78 * L
    hwr, hhr = 0.045 * k, 0.13 * k
    sep = R0 + 0.06 * k
    for s in (-1, 1):
        xr = x + s * sep
        g.box((xr, y0 + Lr / 2, z), (2 * hwr, Lr, 2 * hhr), M["jacket"], "hard", what="rail")
        # arête chromée du rail en PLAQUES d'électrode séparées (pas une barre continue)
        # (moitié avant seulement : sur la moitié arrière, les plaques touchaient les anneaux et tout se lisait en une
        # seule échelle chromée)
        npl = max(3, int(L * 0.48 / 0.16))
        for i in range(npl):
            g.box((xr, y0 + L * (0.42 + 0.36 * (i + 0.5) / npl), z + hhr + 0.004),
                  (2 * hwr * 0.7, L * 0.36 / npl - 0.04, 0.012), M["ring"], "hard", what="arete")
        # passe 5 : conducteur en lueur CYAN GLACÉ continue (le cuivre de la passe 4 se lisait « bobine électrique »)
        g.box((xr - s * (hwr + 0.004), y0 + Lr / 2, z), (0.008, Lr * 0.97, hhr * 1.1), E, "flat",
              what="conducteur_lum")
        if k >= 0.9:
            for i in range(int(Lr * 0.9 / 0.11)):
                g.dome((xr + s * (hwr + 0.002), y0 + 0.08 + i * 0.11, z + hhr * 0.55), (s, 0, 0), 0.013, M["rivet"])
        # traverses basses qui lient les rails au faisceau (aucun jour enfermé sous les tubes)
        for f in (0.05, 0.4, 0.74):
            g.box(((xr + x) / 2, y0 + f * L, z - hhr * 0.6), (sep, 0.05, hhr * 0.5), M["steel_dk"], "hard",
                  what="traverse")
    g.box((x, y0 + Lr * 0.5, z - R0 * 0.75), (2 * sep, Lr * 0.98, R0 * 0.5), M["jacket"], "hard", what="semelle")
    # (les cellules cryogéniques de la culasse sont dans l'alimentation, feed() : enfilées dans l'anneau 1, elles
    # enfermaient un jour de 38 px hr en pose E)
    # 4 anneaux magnétiques sur la moitié arrière (corps.JAQUETTE_MAX)
    ro, ri, w = sep + hwr + 0.13 * k, sep + hwr + 0.05 * k, 0.07 * k
    for f in (0.1, 0.19, 0.28, 0.37):
        _ring12(g, x, y0 + f * L, z, ro, ri, w, k)
    # culasse magnétique pleine entre le masque et le premier anneau (aucun jour enfermé au pied de l'anneau 1)
    g.box((x, y0 + 0.07 * L - 0.03, z + (hhr + ro * 1.02) / 2 - 0.02), (2 * ri, 0.14 * L + 0.08, ro * 1.02 - hhr + 0.04),
          M["jacket"], "hard", what="culasse")
    for s in (-1, 1):
        g.box((x + s * ri * 0.6, y0 + 0.06 * L - 0.03, z + ro * 1.02 + 0.012), (0.04, 0.12 * L, 0.02), M["ring"], "hard",
              what="arete")
    # quille pleine sous les anneaux (de l'anneau 1 au dernier) : aucun jour enfermé entre deux anneaux sous le canon
    ya_, yb_ = y0 + 0.1 * L - w / 2, y0 + 0.37 * L + w / 2
    g.box((x, (ya_ + yb_) / 2, z - (hhr + ro * 0.96) / 2), (2 * sep, yb_ - ya_, ro * 0.96 - hhr), M["jacket"], "hard",
          what="quille")
    g.box((x, (ya_ + yb_) / 2, z - ro * 0.96 + 0.01), (2 * sep + 0.04, yb_ - ya_ + 0.02, 0.025), M["ring"], "hard",
          what="arete")
    if k >= 0.9:
        # boulons chromés de la quille entre les anneaux, givre aux joints (pièces isolées sur le noir)
        for i in range(3):
            yy = ya_ + (yb_ - ya_) * (i + 0.5) / 3
            for s in (-1, 1):
                g.dome((x + s * (sep + 0.002), yy, z - (hhr + ro * 0.96) / 2), (s, 0, 0), 0.02, M["steel_hi"],
                       what="boulon")
            g.box((x - sep - 0.004, yy + 0.05, z - hhr - 0.04), (0.008, 0.05, 0.03), M["trim"], "flat", what="givre")
    # culasse magnétique dorsale : plaque mince dans l'axe, de la culasse au dernier anneau (aucun jour enfermé entre
    # la culasse, le masque et les anneaux, vus de dessus)
    g.box((x, (y0 - 0.04 + yb_) / 2, z + (hhr + ro * 0.99) / 2), (0.05 * k, yb_ - y0 + 0.04, ro * 0.99 - hhr), M["jacket"],
          "hard", what="culasse_dorsale")
    g.box((x, (y0 - 0.04 + yb_) / 2, z + ro * 0.99), (0.3 * k, yb_ - y0 + 0.04, 0.025), M["jacket"], "hard",
          what="arete")
    for i in range(3):   # passe 5 : LUEUR CYAN GLACÉ CONTINUE entre les anneaux (juges de la passe 4), sur le dos
        g.box((x, y0 + L * (0.145 + 0.09 * i), z + ro * 0.99 + 0.014),
              (0.08 * k, max(0.02, L * 0.09 - w - 0.02), 0.008), E, "flat", what="lueur_continue")
    return y0 + L


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) noire et sombre, CELLULES CRYOGÉNIQUES cylindriques
    couchées à chapeaux chromés et givre, tuyau cryogénique, voyants."""
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
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=[M["jacket"], M["steel_dk"]],
            rivet_step=0.11)
    ztop = zb1 + 0.015
    # voile plein entre la culasse et la caisse (le jour entre le moteur et la caisse s'enfermait en pose N)
    xa_, xb_ = sorted((x + sx * wr / 2 - sx * 0.01, xo + sx * 0.03))
    g.box(((xa_ + xb_) / 2, y0 - 0.1 + bl * 0.4, zg + hr * 0.05), (xb_ - xa_, bl * 0.8, hr * 1.1), M["steel_dk"],
          "hard", what="voile")
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    for k, yy in enumerate((yb0 + bl * 0.32, yb0 + bl * 0.68)):
        c = V((bc, yy, ztop + 0.07))
        g.cyl(c, "x", 0.07, bw * 0.9, M["jacket"], n=20, what="cellule")
        for s in (-1, 1):
            g.cyl(c + V((s * bw * 0.45, 0, 0)), "x", 0.075, 0.03, M["ring"], n=20, what="chapeau")
        g.tube_shell(c, "x", 0.078, 0.06, 0.03, M["trim"], n=20, what="givre")
        g.box(c + V((0, -0.05, 0.05)), (0.05, 0.02, 0.006), E, "flat", what="voyant")
    g.tube([V((bc, yb0 + bl * 0.5, ztop + 0.08)), V((x + sx * wr * 0.35, yb0 + bl * 0.6, zg + hr + 0.07)),
            V((x + sx * wr * 0.2, y1 - 0.12, zg + hr + 0.04))], 0.026, M["pipe"], n=10, what="cryo")
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=2, shapes=("rond", "carre", "fente"))
    return bc


def dome_gun(g, H, nb, L, s=1.0, zr=None):
    """Canon de coupole sur berceau blindé (lignée _tete15), arme de l'époque (petit canon à rails et anneaux, la
    rosette visible devant). zr (ronde 4) : pied du berceau, lu sur la coupole de forme (corps.z_coque)."""
    M = g.M
    zr = H["zs"] + H["rz"] * 0.92 if zr is None else zr
    zc = zr + 0.3 * s
    PT.hull(g, -0.38 * s, 0.38 * s, -0.22 * s, 0.66 * s, zr - 0.04, zr + 0.2 * s, ins=(0.04, 0.04, 0.1),
            panel=0.22, mats=[M["olive"], M["ochre"]], rivet_step=0.11)
    PT.receiver(g, 0.0, -0.22 * s, 0.66 * s, zc - 0.18 * s, zc + 0.16 * s, 0.36 * s, mats=[M[k] for k in RECV])
    rb, rr = 0.052 * s, 0.125 * s * (1.0 if nb == 6 else 0.85)
    _gun12(g, 0.0, 0.66 * s, zc, L, nb, rb, rr)
    # voile plein sous le canon de coupole, du berceau aux anneaux (aucun jour enfermé avec la coupole)
    g.box((0.0, 0.66 * s + L * 0.25, zc - 0.14 * s), (0.3 * s, L * 0.5, 0.12 * s), M["jacket"], "hard", what="voile")
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.26 * s, 0.3 * s, zr + 0.02), (sx * 0.32 * s, 0.6 * s, zr + 0.2 * s), 0.026)
    P2.feed_chute(g, [(0.45 * s, -0.38 * s, zr + 0.05), (0.4 * s, -0.06 * s, zc + 0.12 * s),
                      (0.15 * s, 0.1 * s, zc + 0.17 * s)], 0.12 * s, M)
    return zc


# ------------------------------------------------------------------------------------------------
# Masque et tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=("ochre", "olive"), fentes=((-0.42, 0.34), (0.42, 0.22)), visiere=("steel_hi", 0.13),
                        coax=dict(fut="steel_dk", manchon="ring", manchon_y=0.28, manchon_r=0.045, manchon_L=0.16))


def tete(g, c):
    M = g.M
    E = M["emit"]
    H = c.H
    R = H["R"]
    z0 = c.rt
    F.slits_grouped(g, R, z0 + 0.2, 9, M["emit"])
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, H["zs"] + 0.25), (sx * R * 0.62, -R * 0.42, H["zs"] + H["rz"] * 0.55),
              (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
    # plaques rapportées : 1re rangée, puis 2e rangée (catalogue §A.5)
    row1 = (0.5, 0.95, 1.4, math.pi - 0.5, math.pi - 0.95, math.pi - 1.4)
    ph1, w1, h1 = (0.32, 0.28, 0.22)
    for i, th in enumerate(row1):
        mat = M["jacket"] if i % 2 else M["steel_dk"]
        P2.applique(g, c.Pf, c.Nf, th, ph1, w1, h1, mat, M)
    for th in (0.75, math.pi - 0.75, 1.57):
        P2.applique(g, c.Pf, c.Nf, th, 0.75, 0.26, 0.22, M["jacket"], M)
    # ronde 4 : coupole en ANNEAUX (noyau bas) : le berceau se pose sur le noyau (corps.z_coque au plus haut de son
    # emprise, pour qu'il ne s'enfonce pas)
    zr = max(corps.z_coque(c, xx, yy) for xx in (-0.3, 0.0, 0.3) for yy in (-0.15, 0.2, 0.5)) - 0.02
    dome_gun(g, H, 4, 1.02, 0.85, zr=zr)
    # sommet de la tête : 2 DEWARS cryogéniques debout sur la nacelle, cols chromés, givre
    bx, yb0, yb1 = c.nac[:3]
    znac = H["zs"] + H["rz"] * 0.42
    for s in (-1, 1):
        x = s * bx * 0.55
        y = (yb0 + yb1) / 2 - 0.05
        g.cyl((x, y, znac + 0.22), "z", 0.13, 0.44, M["frost"], n=24, what="dewar")
        for zz in (0.08, 0.3):
            g.tube_shell((x, y, znac + zz), "z", 0.15, 0.12, 0.04, M["ring"], n=24, what="collier")
        g.cyl((x, y, znac + 0.48), "z", 0.06, 0.08, M["ring"], n=16, what="col")
        g.tube_shell((x, y, znac + 0.445), "z", 0.075, 0.06, 0.02, M["trim"], n=16, what="givre")
        g.box((x, y - 0.135, znac + 0.25), (0.05, 0.006, 0.02), E, "flat", what="voyant")
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
