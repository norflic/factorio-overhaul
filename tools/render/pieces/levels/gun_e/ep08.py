"""Époque 8 · Marais (ère III, 4×4, niveaux 15 et 16). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 8) : « verre, bulles, toxique ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py, kit.py).
Corrections de design de la QUATRIÈME PASSE (23/10, constructeur de la plage basse) :
  - liquide JAUNE SOUFRÉ trouble (famille « jaune-vert acide » 60 à 88°, loin du vert uranium de l'atome) ;
  - cuve de verre du canon posée À CÔTÉ du faisceau (règle d'or 1), voile plein, raccord court ; tuyaux bulbe -> canons
    posés sur la coupole (trous enfermés de 379 et 179 px) ;
  - globe en cage dense surélevé, lanterneau plus petit (L2), colonnes de décantation, cuves plus hautes en débord ;
    trémie caoutchoutée ; plateforme presque carrée (chanfrein 0,06) ; bocaux et ancrage sur la pièce paire.
Emplacements remplis : arme (gatling de vert-de-gris à buse en cloche portant une CUVE DE VERRE couchée, manchon à
fenêtres de liquide, boîte d'alimentation à tuyaux souples), mitrailleuse coaxiale, grands volumes du socle (cuves de
verre, globe, bonbonnes clissées, bocaux), liaisons (caoutchouc annelé à tronçon de verre), nacelle (bulbe de verre
dorsal relié aux canons), lanterneau de verre sur la coupole, foyers vert-jaune, pièce paire (2 bonbonnes de verre).
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

EPOQUE = 8
NOM = "Marais"
KIN = 1   # rang dans l'ère III
# passe 4 : liquide JAUNE SOUFRÉ trouble (famille « jaune-vert acide » 60 à 88° mesurée, loin du vert uranium de
# l'atome, 100 à 135°) ; verre teinté opaque, lueur douce plus faible (liquide trouble, pas un néon)
# passe 5 : un peu plus vert (teinte nominale 71° -> 79°) : loin du jaune des fûts du pétrole, encore dans la famille
# ronde 3 (DC : « trop uniforme en terme de palette » ; 8 et 9 avaient deux verts voisins) : JAUNE TOXIQUE (57°) ;
# liquide plus lumineux (force 0,36 -> 0,6 : le marais doit passer devant le cristal en richesse)
# ronde 5 (test à l'aveugle de la ronde 4 : 8 lu « fûts jaunes, rayures danger », pris pour le PÉTROLE, et jugé moins
# évolué que le cristal, « jaune industriel ») : le liquide passe au VERT-JAUNE ACIDE (chartreuse, environ 84°), la
# teinte d'un poison de marais : ni le jaune de signalisation du pétrole (environ 50°) ni le vert uranium de l'atome
# (100 à 135°) ; un peu plus lumineux (0,6 -> 0,75) pour passer devant le cristal
FOYER = ages.FOYER[8]
CANON = dict(L=1.7, nb=6, rb=0.052, rr=0.128)
# passe 4 : chanfrein de plateforme d'époque (remplissage, catalogue §A.5 ; silhouette distincte des voisines)
PLATEFORME = dict(chanfrein=0.06)
# passe 5, ronde 1 (consigne du DC du 23/10 : TOUT le bâtiment change d'âge) : une STATION DE MARAIS sur pilotis :
# pont de PLANCHES de bois mouillé moussu à clous de cuivre, bordé de caoutchouc noir ; coupole et capots de CUIVRE
# OXYDÉ vert-de-gris clair ; plaques de cuivre brun terni ; acier de structure en caoutchouc noir et vert-de-gris ;
# bandes vert-de-gris et noir (aucun jaune : le jaune est au pétrole).
HABILLAGE = dict(ages.CORPS[8],   # lot K0 : MATIÈRE du corps et du pont (capots, acier, rivets, joints,
                 # danger, peinture, plateforme) : commun/ages.py ; ici, les clés propres à la mitrailleuse
                 jupe_cerclage="rubber", tremie="rubber", pochoirs=True, munitions=("verdigris", "emit_soft"),
                 chapeau="cuivre_terni",
                 tourelleau="cuivre_terni", grille_nacelle="vdg_capot",
                 # ronde 3 (test des écarts de la ronde 2 : 8-9 noté 2 et 2, « même plan carrelé », « même socle ») : PONT
                 # SUR PILOTIS (forme « pilotis » du kit) : plancher de bois flotté sur pieux moussus au-dessus du
                 # marais ; les grandes cuves, le globe et la station de pompage traversent le plancher (ils restent
                 # posés au fond : leur sommet ne monte pas sous la tête qui tourne), les bocaux et paniers sont sous le
                 # plancher. Palette (DC, 23/10 9 h 50) : vert-de-gris dominant, bois et cuivre terni en secondaire,
                 # JAUNE TOXIQUE en accent (le vert est à l'atome)
                 forme_plateforme=dict(forme="pilotis", flanc="bois_mousse", flanc2="rubber"),
                 # ronde 4 (test des écarts de la ronde 3 : 7-8 et 8-9 notés 3 et 2 ; 8 jugé MOINS évolué que 7 par les
                 # deux lecteurs, « B industriel jaune », « même socle et dôme » que 9) : la coupole devient une
                 # grande CLOCHE DE VERRE PLEINE DU LIQUIDE TOXIQUE lumineux (forme « cloche » du kit, verre = liquide
                 # jaune soufré qui luit), meneaux et cerces de vert-de-gris : « verre, bulles, toxique » sur toute la
                 # tête, une silhouette haute en cloche et une lumière que le cristal n'a pas
                 # (essai a de la ronde 4 : verre = lueur douce ; la cloche devenait un aplat jaune sans dessin au zoom 1 :
                 # VERRE TOXIQUE brillant non lumineux, jaune-vert profond, dont les reflets dessinent la cloche)
                 forme_coupole=dict(forme="cloche", verre="verre_toxique", mat2="vdg_capot", lisere="emit"),
                 )
ST = dict(jacket="marsh", brake="nozzle", drive="motor", drive_mat="verdigris", fin_mat="steel_dk",
          band="verdigris", recv_mats=("verdigris", "vdg_capot"), feed="hoses", skirt="rubber", appl="vdg_capot",
          gmask=("vdg_capot", "verdigris"), arm=("vdg_capot", "steel_dk"), cap="cuivre_terni",
          col=("vdg_capot", "verdigris"), nac=("vdg_capot", "verdigris"), coax=True)


def matieres(metal, M):
    """Passe 5 : reflet clair du verre (bande verticale fine sur les cuves : le cylindre se lit verre, pas fût peint)."""
    ages.matieres(8, metal, M)   # lot K0 : matières de l'âge, commun/ages.py (même ordre)


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : cuves de verre, globe, bonbonnes clissées, bocaux
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=3)
    socle_marsh(g, KIN)
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def glass_vat(g, x, y, r, h, M, E):
    """Cuve de verre debout : embase de vert-de-gris boulonnée, liquide visible entre 8 côtes, cerclages laiton,
    dôme de verre et couronne, bulles. Chaque panneau de liquide est un foyer de moins de 0,05 t²."""
    g.cyl((x, y, 0.05), "z", r + 0.06, 0.1, M["verdigris"], n=24, style="soft", what="embase")
    F.bolts_ring(g, (x, y, 0.1), (0, 0, 1), r + 0.035, 12, M["cuivre_terni"], r=0.014)
    zb, zt = 0.1, h
    # passe 5 (ronde 1) : lu « fûts jaunes » par un lecteur de la ronde 0 (cylindres lumineux pleins cerclés de laiton).
    # La cuve se lit maintenant comme du VERRE À MOITIÉ PLEIN : liquide en bas (62 %), verre vide sombre au-dessus,
    # mousse de bulles au niveau du liquide, bulles claires qui montent dans le verre vide, reflet vertical,
    # 6 montants fins de vert-de-gris et cerclages de vert-de-gris en haut et en bas seulement (plus de bague de fût).
    zl = zb + (zt - zb) * 0.62
    g.cyl((x, y, (zb + zl) / 2), "z", r - 0.012, zl - zb, M["emit_soft"], n=32, what="liquide")
    g.cyl((x, y, (zl + zt) / 2), "z", r - 0.012, zt - zl, M["glass"], n=32, what="verre_vide")
    nrib = 6
    for kk in range(nrib):
        a = TAU * (kk + 0.5) / nrib + 0.26
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, (zb + zt) / 2)) + d * (r - 0.004), (0.022, 0.026, zt - zb), M["verdigris"], "hard",
              R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="cote")
    for f in (0.04, 0.96):
        g.tube_shell((x, y, zb + (zt - zb) * f), "z", r + 0.02, r - 0.02, 0.04, M["verdigris"], n=32,
                     what="cerclage")
    # mousse au niveau du liquide (anneau de bulles sur la face visible)
    for i in range(11):
        a = -math.pi / 2 + 2.4 * (i / 10.0 - 0.5)
        g.dome((x + math.cos(a) * r * 0.99, y + math.sin(a) * r * 0.99, zl + 0.012 * (i % 2)),
               (math.cos(a), math.sin(a), 0), 0.026, E, what="mousse")
    # bulles qui montent dans le verre vide (claires sur fond sombre) et dans le liquide
    for i in range(9):
        a = -math.pi / 2 + 1.7 * ((i * 4) % 9 / 8.0 - 0.5)
        zz = zl + 0.04 + (zt - zl - 0.08) * ((i * 5) % 9) / 8.0
        g.dome((x + math.cos(a) * r * 0.99, y + math.sin(a) * r * 0.99, zz), (math.cos(a), math.sin(a), 0),
               0.016 + 0.006 * (i % 3), E, what="bulle")
    # reflet vertical du verre (face sud-ouest, côté lumière)
    a = -math.pi / 2 - 0.55
    g.box((x + math.cos(a) * (r - 0.004), y + math.sin(a) * (r - 0.004), (zb + zt) / 2), (0.018, 0.01, (zt - zb) * 0.86),
          M["reflet_verre"], "flat", R=Matrix.Rotation(a + math.pi / 2, 3, "Z"), what="reflet")
    F.sphere(g, (x, y, zt), r * 0.86, M["glass"], n=24, m=12, sz=0.55, what="dome_verre")
    g.tube_shell((x, y, zt + 0.005), "z", r + 0.01, r * 0.8, 0.03, M["verdigris"], n=28, what="couronne")
    for kk in range(4):
        a = TAU * kk / 4 + 0.4
        g.box((x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45, zt + r * 0.3), (0.025, 0.025, r * 0.55),
              M["verdigris"], "hard", R=Matrix.Rotation(0.0, 3, "Z"), what="arceau")
    g.cyl((x, y, zt + r * 0.5), "z", 0.05, 0.06, M["cuivre_terni"], n=12, what="col")
    P2.gauge(g, (x, y - r - 0.03, zb + (zt - zb) * 0.25), (0, -1, 0.3), 0.045, M)


def wicker(g, c, r, M):
    x, y, z = c
    g.cyl((x, y, z + r * 0.9), "z", r, r * 1.8, M["wicker"], n=16, r2=r * 0.85, what="panier")
    for f in (0.2, 0.5, 0.8):
        g.tube_shell((x, y, z + r * 1.8 * f), "z", r * (1.0 - 0.15 * f) + 0.008, r * 0.8, 0.014, M["wood2"], n=16,
                     what="cercle")
    g.cyl((x, y, z + r * 1.8 + 0.05), "z", r * 0.35, 0.1, M["emit_soft"], n=12, r2=r * 0.25, what="col")
    g.cyl((x, y, z + r * 1.8 + 0.11), "z", r * 0.28, 0.025, M["rubber"], n=10, what="bouchon")


def socle_marsh(g, k):
    M = g.M
    E = M["emit"]
    glass_vat(g, 1.68, Y(0.55), 0.3, 1.02, M, E)
    glass_vat(g, 1.68, Y(-0.45), 0.27, 0.88, M, E)
    # nord-ouest : grand globe de verre en cage, sur pompe
    x, y = -1.42, Y(1.28)
    PT.hull(g, x - 0.34, x + 0.34, y - 0.3, y + 0.3, 0.0, 0.16, ins=(0.02, 0.02, 0.02), panel=0.22,
            mats=[M["verdigris"], M["cuivre_terni"]], rivet_step=0.1)
    rG = 0.29
    # globe surélevé sur 4 jambes de vert-de-gris (silhouette haute au nord-ouest, distincte de la grappe du cristal)
    zl = 0.3
    for kk in range(4):
        a = TAU * kk / 4 + math.pi / 4
        g.box((x + math.cos(a) * rG * 0.75, y + math.sin(a) * rG * 0.75, 0.16 + zl / 2), (0.05, 0.05, zl + 0.04),
              M["verdigris"], "hard", what="jambe")
    g.cyl((x, y, 0.16 + zl - 0.02), "z", rG * 0.9, 0.05, M["verdigris"], n=20, what="plateau")
    zc = 0.16 + zl + rG * 0.95
    F.sphere(g, (x, y, zc), rG, M["emit_soft"], n=28, m=14, what="globe")
    # cage dense (12 montants, 3 cerclages) : le globe se lit comme une cuve en cage et non comme un néon, et sa lueur
    # se coupe en fuseaux (L2 : plus grand foyer < 0,45 t²)
    for kk in range(12):
        a = TAU * kk / 12
        g.box((x + math.cos(a) * (rG + 0.012), y + math.sin(a) * (rG + 0.012), zc), (0.034, 0.034, rG * 1.9),
              M["verdigris"], "hard", R=Matrix.Rotation(a, 3, "Z"), what="cage")
    for zz in (-0.45, 0.0, 0.45):
        rz_ = math.sqrt(max(0.0, 1 - zz * zz)) * rG
        g.torus((x, y, zc + zz * rG), "z", rz_ + 0.012, 0.022, M["cuivre_terni"], n=32, m=6, what="ceinture")
    g.cyl((x, y, zc + rG + 0.03), "z", 0.07, 0.07, M["cuivre_terni"], n=14, what="col")
    # ouest : station de pompage (2 corps de pompe, bonbonnes clissées)
    PT.hull(g, -1.92, -1.3, Y(-0.7), Y(0.55), 0.0, 0.36, ins=(0.03, 0.03, 0.03), panel=0.24,
            mats=[M["verdigris"], M["cuivre_terni"]], rivet_step=0.12)
    # passe 4 : 2 COLONNES DE DÉCANTATION en verre (liquide soufré trouble) sur la station de pompage, en cage
    for yn in (-0.35, 0.25):
        zc0, zc1 = 0.36, 0.98
        # passe 5 : liquide en bas (55 %), verre vide sombre au-dessus, mousse au niveau
        zl = zc0 + (zc1 - zc0) * 0.55
        g.cyl((-1.61, Y(yn), (zc0 + zl) / 2), "z", 0.1, zl - zc0, M["emit_soft"], n=20, what="colonne_verre")
        g.cyl((-1.61, Y(yn), (zl + zc1) / 2), "z", 0.1, zc1 - zl, M["glass"], n=20, what="verre_vide")
        for i in range(5):
            a = -math.pi / 2 + 1.8 * (i / 4.0 - 0.5)
            g.dome((-1.61 + math.cos(a) * 0.1, Y(yn) + math.sin(a) * 0.1, zl), (math.cos(a), math.sin(a), 0), 0.02,
                   M["emit"], what="mousse")
        for kk in range(6):
            a = TAU * kk / 6
            g.box((-1.61 + math.cos(a) * 0.105, Y(yn) + math.sin(a) * 0.105, (zc0 + zc1) / 2),
                  (0.026, 0.026, zc1 - zc0), M["verdigris"], "hard", what="cage")
        for zz in (zc0 + 0.02, (zc0 + zc1) / 2, zc1 - 0.02):
            g.tube_shell((-1.61, Y(yn), zz), "z", 0.122, 0.09, 0.03, M["cuivre_terni"], n=20, what="cerclage")
        g.cyl((-1.61, Y(yn), zc1 + 0.03), "z", 0.08, 0.06, M["verdigris"], n=16, what="chapeau")
        g.cyl((-1.61, Y(yn), zc1 + 0.08), "z", 0.03, 0.05, M["cuivre_terni"], n=10, what="col")
        P2.gauge(g, (-1.61, Y(yn) - 0.12, 0.42), (0, -1, 0.3), 0.04, M)
    for (xx, yn) in ((-1.25, -0.95), (-1.05, -1.0)):
        wicker(g, (xx, Y(yn), 0.0), 0.11, M)
    for yn in (-0.6, -0.05, 0.45):
        P2.handwheel(g, (-1.36, Y(yn), 0.42), (1, 0, 0.3), 0.05, M, mat=M["cuivre_terni"])
        P2.gauge(g, (-1.8, Y(yn), 0.38), (0, 0, 1), 0.04, M)
    # gros conduits de caoutchouc annelé (pompes -> globe, cuves -> colonne), tronçons de verre lumineux
    g.hose([(-1.61, Y(0.25), 0.62), (-1.6, Y(0.8), 0.7), (-1.45, Y(1.05), 0.4)], 0.05, M["rubber"], step=0.035)
    link(g, 8, [(1.38, Y(0.55), 0.4), (1.1, Y(0.5), 0.65), (0.86, Y(0.4), 0.78)], 0.07)
    link(g, 8, [(1.42, Y(-0.45), 0.35), (1.1, Y(-0.4), 0.6), (0.9, Y(-0.3), 0.72)], 0.07)
    link(g, 8, [(-1.3, Y(0.1), 0.3), (-1.15, Y(0.1), 0.6), (-0.96, Y(0.06), 0.74)], 0.07)
    link(g, 8, [(-1.15, Y(1.1), 0.3), (-0.9, Y(0.9), 0.6), (-0.66, Y(0.66), 0.78)], 0.06)
    for (xx, yn) in ((-0.95, -0.95), (-0.75, -1.05), (0.9, -0.95), (1.05, -1.05), (-1.6, 0.75), (-1.25, 0.8),
                     (0.6, 1.7), (-0.4, 1.75), (1.15, 1.55), (1.75, 1.2), (-1.85, -0.9), (0.95, 0.95),
                     (-0.6, -1.3), (-1.0, -1.7), (1.85, -0.85), (1.8, 0.15), (-0.6, -1.85), (0.25, 1.9),
                     (-1.85, 0.3), (-1.85, -0.35), (1.15, 1.85), (-1.2, 1.85), (0.6, -1.25), (-0.15, -1.9),
                     (1.85, 0.75), (-1.85, 1.6), (0.85, -1.05), (-0.85, -1.45), (-0.75, -1.0)):
        jar(g, (xx, Y(yn), 0.04), 0.045, 0.11)
    g.halo((1.5, Y(0.05), 0.6), M["_emit_rgb"], 14.0)
    g.halo((-1.42, Y(1.28), 0.6), M["_emit_rgb"], 12.0)
def jar(g, c, r, h):
    """Bocal de prélèvement (marais) : verre lumineux, couvercle et cerclage laiton."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + h / 2), "z", r, h, M["emit_soft"], n=14, what="bocal")
    g.cyl((x, y, z + h + 0.012), "z", r + 0.008, 0.024, M["cuivre_terni"], n=14, what="couvercle")
    g.tube_shell((x, y, z + 0.01), "z", r + 0.008, r - 0.004, 0.02, M["cuivre_terni"], n=14, what="cerclage")
    g.box((x + r, y, z + h / 2), (0.02, 0.02, h), M["steel_dk"], "hard", what="patte")


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduit toxique en caoutchouc annelé, tronçon de tube de verre à viroles de laiton
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » du marais)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    S_ = g.hose(P, r * 0.9, M["rubber"], step=0.03)
    mid = len(S_) // 2
    if len(S_) > 6:
        a, b = S_[mid - 3], S_[mid + 3]
        d = b - a
        g.cyl((a + b) / 2, d, r * 0.95, d.length, M["emit_soft"], n=14, what="tube_verre")
        for q in (a, b):
            g.cyl(q, d, r * 1.25, 0.03, M["cuivre_terni"], n=14, style="hard", what="virole")
    return P


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 16 : 2 bonbonnes de verre sur berceau à pompe
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    M = g.M
    side = c.side
    cx = c.T["piece"]["x"]
    cy = -cx
    s = c.T["piece"]["s"]
    # ronde 3 : la pièce paire se pose SUR le plancher du pilotis
    g.push((0, 0, c.sil["H"] if c.dz else 0.0))
    for sx in (-1, 1):
        xa, xb = sorted((sx * (cx - 0.3 - 0.07 * side), sx * (cx + 0.2 + 0.03 * side)))
        corps.dalle(g, xa, xb, Y(cy - 0.24 - 0.02 * side), Y(cy + 0.34 + 0.06 * side))
    for sx in (-1, 1):
        demijohn(g, (sx * cx, Y(cy), 0.0), M["emit_soft"], 1.62 * s)
        with at(g, sx * cx, cy, 0.0):
            _ancrage(g, 0.24 * s, 0.07, M, n=24)
            # bocaux de prélèvement en arc devant la bonbonne (petits foyers, couvercles de laiton)
            for k in range(5):
                a = math.pi * (0.2 + 0.6 * k / 4)
                jar(g, (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.04), 0.042, 0.1)
            F.bolts_ring(g, (0, 0, 0.072), (0, 0, 1), 0.24 * s + 0.12, 18, M["steel_hi"], r=0.026)
    g.pop()
    _halo(g, [(-cx, Y(cy), 0.4), (cx, Y(cy), 0.4)], 12.0)


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


def demijohn(g, c, emat, s=1.0):
    """Bonbonne de verre sur berceau à pompe (marais) : sphère cerclée, cage, manomètre."""
    M = g.M
    x, y, z = c
    r = 0.13 * s
    g.box((x, y, z + 0.035), (0.3 * s, 0.3 * s * SQ2 * 0.8, 0.07), M["steel_dk"], "hard", what="berceau")
    zc = z + 0.07 + r * 0.95
    F.sphere(g, (x, y, zc), r, emat, n=20, m=12, what="bonbonne")
    g.torus((x, y, zc), "z", r + 0.004, 0.012, M["cuivre_terni"], n=24, m=6, what="cerclage")
    for k in range(6):
        a = TAU * k / 6
        g.box((x + math.cos(a) * (r + 0.012), y + math.sin(a) * (r + 0.012), zc), (0.016, 0.016, r * 2.0),
              M["verdigris"], "hard", what="cage")
    # passe 4 : résille de méridiens et 2 parallèles de vert-de-gris sur le dôme de la bonbonne (la plus grande plage
    # saturée C6 et la zone lumineuse L1 du niveau pair dépassaient : le verre se lit en fuseaux, liquide trouble)
    for k in range(10):
        a = TAU * (k + 0.5) / 10
        pts = [V((x + math.cos(a) * math.cos(ph) * r * 1.02, y + math.sin(a) * math.cos(ph) * r * 1.02,
                  zc + math.sin(ph) * r * 1.02)) for ph in [-0.2 + 1.7 * i / 8 for i in range(9)]]
        g.tube(pts, 0.013, M["verdigris"], n=6, what="meridien")
    for ph in (0.45, 0.95):
        g.torus((x, y, zc + math.sin(ph) * r), "z", math.cos(ph) * r * 1.02, 0.013, M["verdigris"], n=28, m=6,
                what="parallele")
    g.cyl((x, y, zc + r + 0.025), "z", 0.04, 0.05, M["cuivre_terni"], n=12, what="col")
    g.cyl((x + 0.12 * s, y - 0.06 * s, z + 0.13), "z", 0.035, 0.12, M["cuivre_terni"], n=12, what="pompe")
    P2.gauge(g, (x + 0.12 * s, y - 0.06 * s - 0.036, z + 0.16), (0, -1, 0.3), 0.032, M)
    g.hose([(x + 0.12 * s, y - 0.06 * s, z + 0.19), (x + 0.08 * s, y - 0.02, zc + r * 0.7), (x, y, zc + r + 0.04)],
           0.016, M["rubber"], step=0.02)


# ------------------------------------------------------------------------------------------------
# Arme (E1) : gatling de vert-de-gris à cuve de verre couchée
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    M = g.M
    H = c.H
    w_marsh(g, ST, H, x, sx)
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


def w_marsh(g, st, H, x, sx):
    """Époque 8 (passe 4, RÈGLE D'OR 1) : gatling de vert-de-gris à buse en cloche ; la CUVE DE VERRE couchée (liquide
    soufré trouble, côtes, fonds de laiton) est posée À CÔTÉ du faisceau, côté extérieur, sur 2 berceaux, et non plus
    dessus : le faisceau reste visible de dessus ; tuyau de caoutchouc vers la culasse."""
    M = g.M
    w_gatling(g, st, H, x, sx)
    y0, y1 = H["recv"]
    zg, hr = H["zg"], H["hr"]
    rs = H["rr"] + H["rb"] + 0.028
    r = 0.13
    Lv = H["L"] * 0.44
    c = V((x + sx * (rs + r + 0.05), y1 + 0.08 + Lv / 2, zg - 0.02))
    for f in (-0.32, 0.32):
        g.box(V((x + sx * (rs + 0.02), c.y + f * Lv, zg - 0.06)), (0.1, 0.05, 0.05), M["verdigris"], "hard",
              what="bras")
        g.box(c + V((0, f * Lv, -r - 0.015)), (r * 1.4, 0.05, 0.05), M["verdigris"], "hard", what="berceau")
    # voile plein entre le faisceau et la cuve, sur toute la longueur de la cuve (sinon le sol se voit entre eux :
    # trou enfermé de 379 px hr en pose E, rendu rapide du 23/10)
    xa_, xb_ = sorted((x + sx * (rs - 0.03), c.x))
    g.box(((xa_ + xb_) / 2, c.y, zg - 0.03), (xb_ - xa_, Lv + 0.04, 0.11), M["verdigris"], "hard", what="voile")
    for k_ in range(3):
        g.dome(((xa_ + xb_) / 2, c.y - Lv * 0.35 + k_ * Lv * 0.35, zg + 0.027), (0, 0, 1), 0.015, M["cuivre_terni"])
    g.cyl(c, "y", r - 0.008, Lv, M["emit_soft"], n=24, what="liquide")
    for kk in range(8):
        a = TAU * (kk + 0.5) / 8
        d = V((math.cos(a), 0, math.sin(a)))
        g.box(c + d * (r - 0.004), (0.026, Lv, 0.024), M["verdigris"], "hard",
              R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="cote")
    # passe 5 : plus de cerclages de laiton au milieu (ils faisaient un fût couché) : 2 bagues de vert-de-gris aux
    # bouts, fonds de vert-de-gris, reflet clair le long du dessus, bulles plus grosses
    for f in (-0.5, 0.5):
        g.tube_shell(c + V((0, f * Lv, 0)), "y", r + 0.018, r - 0.02, 0.032, M["verdigris"], n=24, what="cerclage")
    for f in (-1, 1):
        g.cyl(c + V((0, f * (Lv / 2 + 0.03), 0)), "y", r * 0.85, 0.05, M["verdigris"], n=24, r2=r * 0.5,
              what="fond")
    g.box(c + V((-sx * r * 0.35, 0, r * 0.93)), (0.016, Lv * 0.84, 0.01), M["reflet_verre"], "flat",
          R=Matrix.Rotation(sx * 0.36, 3, "Y"), what="reflet")
    for i in range(7):
        g.dome(c + V((sx * 0.035 * ((i % 2) * 2 - 1), -Lv * 0.4 + i * Lv * 0.13, r - 0.01)), (0, 0, 1),
               0.016 + 0.006 * (i % 3), M["emit"], what="bulle")
    # raccord de caoutchouc court entre le fond arrière de la cuve et le masque de canon (un tuyau long vers la culasse
    # enfermait un jour de 10 à 29 px en pose N)
    g.hose([c + V((0, -Lv / 2 - 0.04, 0)), c + V((-sx * r * 0.6, -Lv / 2 - 0.1, -0.02)),
            V((x + sx * (rs + 0.02), y1 - 0.0, zg - 0.03))], 0.03, M["rubber"], step=0.03)


def gun_e(g, st, H, x, side):
    """Faisceau de la lignée (corps.rosette), manchon à fenêtres et buse en cloche ; renvoie le rayon de jaquette."""
    M = g.M
    y1 = H["recv"][1]
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    zg = H["zg"]
    rs = rr + rb + 0.028
    pos = corps.rosette(g, x, y1, zg, L, nb, rb, rr, mat=M[st.get("barrel", "gun")], collier_mat=M[st["band"]],
                        colliers=st.get("collars", (0.8,)), bouts=False)
    Lj = L * min(st.get("jacket_f", 0.62), corps.JAQUETTE_MAX)
    jk_marsh(g, st, x, y1, zg, Lj, rs, H)
    br_nozzle(g, st, x, y1 + L, zg, rs, pos, H)
    return rs


def jk_marsh(g, st, x, y0, z, Lj, rs, H):
    """Époque 8 : manchon de vert-de-gris à 2 fenêtres de verre longues (liquide vert-jaune, bulles)."""
    M = g.M
    g.cyl((x, y0 + Lj / 2, z), "y", rs, Lj, M["vdg_capot"], n=28, what="jaquette")   # ronde 3 : clair (pose N)
    for a in (math.pi * 0.5 + 0.55, math.pi * 0.5 - 0.55):
        d = V((math.cos(a), 0, math.sin(a)))
        Rr = Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed()
        c = V((x, y0 + Lj * 0.52, z)) + d * (rs + 0.004)
        g.box(c, (0.07, Lj * 0.7, 0.012), M["emit_soft"], "flat", R=Rr, what="fenetre")
        for s in (-1, 1):
            g.box(c + Rr @ V((s * 0.045, 0, 0.006)), (0.02, Lj * 0.74, 0.02), M["cuivre_terni"], "hard", R=Rr,
                  what="cadre")
        for t in range(4):
            g.box(c + Rr @ V((0, (t - 1.5) * Lj * 0.17, 0.007)), (0.09, 0.016, 0.014), M["verdigris"], "hard", R=Rr,
                  what="barreau")
        for t in range(3):
            g.dome(c + Rr @ V((0.015 * ((t % 2) * 2 - 1), (t - 1) * Lj * 0.2 + 0.03, 0.008)), d, 0.011, M["emit"])
    for yy in (y0 + 0.025, y0 + Lj - 0.02):
        g.tube_shell((x, yy, z), "y", rs + 0.03, rs - 0.01, 0.05, M["rubber"], n=28, what="joint")
        F.bolts_ring(g, (x, yy, z), (0, 1, 0), rs + 0.031, 6, M["cuivre_terni"], r=0.014, skip_down=-0.3)


def br_nozzle(g, st, x, yb, z, rs, pos, H):
    """Époque 8 : buse à collerette de caoutchouc et anneau de joint, plus large que le faisceau."""
    M = g.M
    rb = H["rb"]
    # buse en CLOCHE nettement plus large que le faisceau (silhouette du marais, poses E et N)
    # passe 5 (règle d'or 7) : cloche resserrée (évasement 0,085 -> 0,03) : en pose N, elle faisait le chapeau sombre
    # d'une cheminée
    # ronde 3 (pose N : 8 encore lu « cheminée » à la ronde 2) : plus de collerette de caoutchouc noir ni de face plus
    # large que le faisceau au bout (règle d'or 7 du kit : aucun anneau plus large que le faisceau dans le dernier
    # cinquième) ; buse droite en vert-de-gris CLAIR du corps (le vert-de-gris métallique restait sombre vers le nord)
    g.cyl((x, yb + 0.06, z), "y", rs, 0.14, M["vdg_capot"], n=28, what="buse")
    g.cyl((x, yb + 0.128, z), "y", rs - 0.01, 0.01, M["glass_dk"], n=28, what="fond_cloche")
    g.torus((x, yb - 0.01, z), "y", rs + 0.006, 0.012, M["cuivre_terni"], n=28, m=8, what="joint")
    F.bolts_ring(g, (x, yb + 0.03, z), (0, 1, 0), rs + 0.008, 6, M["cuivre_terni"], r=0.012, skip_down=-0.3)
    g.cyl((x, yb + 0.134, z), "y", rs - 0.004, 0.012, M["vdg_capot"], n=28, what="face")
    F.bores(g, x, yb + 0.14, z, pos, rb, M["cuivre_terni"])
    F.lit_ring(g, (x, yb + 0.142, z), "y", rs - 0.006, M["emit"])


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) de vert-de-gris et kaki."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    return PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)


def drive(g, st, c, r, L):
    """Organe arrière du canon : moteur de la lignée en vert-de-gris, ailettes d'acier sombre."""
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
    """Alimentation : petite boîte à raccord de laiton (tuyaux souples depuis le bulbe dorsal), manomètre."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    bw, bl, bh = 0.18, H["L"] * 0.3, 0.2
    bx0, bx1 = sorted((xo, xo + sx * bw))
    PT.hull(g, bx0, bx1, y0 - 0.05, y0 - 0.05 + bl, zg - bh * 0.6, zg + bh * 0.4, ins=(0.015, 0.015, 0.015),
            panel=0.24, mats=[M["verdigris"], M["cuivre_terni"]], rivet_step=0.11)
    bc = (bx0 + bx1) / 2
    g.cyl((bc, y0 + bl * 0.4, zg + bh * 0.4 + 0.03), "z", 0.05, 0.06, M["cuivre_terni"], n=16, what="raccord")
    P2.gauge(g, (bc, y0 - 0.06, zg), (0, -1, 0.3), 0.04, M)


# ------------------------------------------------------------------------------------------------
# Masque, nacelle, tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=ST["gmask"], fentes=((0.0, 1.1),), visiere=("steel_dk", 0.03),
                        coax=dict(fut="gun", manchon=ST["band"], manchon_y=0.3, manchon_r=0.046, manchon_L=0.12,
                                  anneau=True))


def nacelle(g, c):
    """Bulbe de verre dorsal (réservoir rond lumineux), cerclé, en cage, relié aux canons par des tuyaux souples."""
    M = g.M
    H = c.H
    bx, yb0, yb1, ztop, yc = c.nac
    rB = 0.17
    F.sphere(g, (0.0, yc, ztop + rB * 0.9), rB, M["emit_soft"], n=24, m=12)
    g.torus((0.0, yc, ztop + rB * 0.9), "z", rB + 0.005, 0.016, M["cuivre_terni"], n=28, m=6, what="cerclage")
    for k in range(6):
        a = TAU * k / 6
        g.box((math.cos(a) * (rB + 0.012), yc + math.sin(a) * (rB + 0.012), ztop + rB * 0.9), (0.02, 0.02, rB * 1.9),
              M["verdigris"], "hard", what="cage")
    g.cyl((0.0, yc, ztop + 0.03), "z", rB * 0.85, 0.06, M["verdigris"], n=20, what="embase")
    g.cyl((0.0, yc, ztop + rB * 1.9 + 0.02), "z", 0.04, 0.05, M["cuivre_terni"], n=12, what="col")
    # tuyaux souples bulbe -> canons, posés sur la coupole (passe 4 : l'arc en l'air enfermait un jour de 379 px)
    R, zs, rz = H["R"], H["zs"], H["rz"]
    for sx in (-1, 1):
        mx, my = sx * H["gx"] * 0.6, -0.2
        # ronde 4 : hauteur lue sur la coupole de forme (cloche), jamais par la formule de l'ellipsoïde
        mz = corps.z_coque(c, mx, my) + 0.04
        g.hose([(sx * rB * 0.7, yc + 0.05, ztop + 0.08), (mx, my, mz),
                (sx * H["gx"], H["recv"][0] + 0.2, H["zg"] + H["hr"] + 0.04)], 0.032, M["rubber"], step=0.03)


def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    zs, rz = H["zs"], H["rz"]
    side = c.side
    k = KIN
    F.slits(g, R, c.rt + 0.1 + 0.02 * side, 11, M["emit"], a0=math.pi * 0.62, span=math.pi * 1.76)
    F.voyants_tete(g, H, 16)
    PT.sight(g, (R * 0.2, R * 0.45, corps.z_coque(c, R * 0.2, R * 0.45) - H["rz"] * 0.28), 0.16 + 0.04 * (side - 3), 0.18, 0.1, M["emit"],
             lenses=side - 2)
    appl = M[ST["appl"]]
    n1 = {0: 3, 1: 6, 2: 8}[k] + (side - 2)
    for i in range(n1):
        th = 0.45 + (math.pi - 0.9) * (i + 0.5) / n1
        P2.applique(g, c.Pf, c.Nf, th, 0.3, 0.22 + 0.03 * (side - 2), 0.18 + 0.03 * (side - 2), appl, M)
    # ronde 4 : la coupole est une CLOCHE DE VERRE pleine de liquide lumineux (HABILLAGE, forme_coupole) : plus de
    # plaques hautes ni de lanterneau (il serait noyé dans la cloche) ; BULLES claires collées au verre, en grappes
    # irrégulières qui montent (jamais en rangée)
    rng = g.rng
    for i in range(14):
        th = TAU * ((i * 0.381966) % 1.0)
        ph = (0.18 + 0.62 * ((i * 0.618034) % 1.0)) * math.pi / 2
        rb_ = 0.014 + 0.016 * rng.random()
        p = c.Pf(th, ph, 1.0)
        nrm = c.Nf(th, ph)
        F.sphere(g, tuple(V(p) + V(nrm) * (rb_ * 0.4)), rb_, M["reflet_verre"], n=12, m=6, sz=1.0, what="bulle")
