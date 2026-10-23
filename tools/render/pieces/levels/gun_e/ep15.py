"""Époque 15 · Néant (ère V cosmique, 6×6, niveaux 29 et 30) : le SOMMET de la suite. Constructeur de l'ère V.
S'exécute DANS Blender.

Consigne du Directeur Créatif (23/10, 12 h 40 : « je préférerais un truc genre big bang ou maîtrise cosmique du néant » ;
vers 13 h 10, option A) : 15 NÉANT (ou « Singularité ») : la maîtrise du trou noir du Cœur ; horizon noir absolu, disque
de lumière qui tourne, lumière déviée, poussière d'étoiles : « un Big Bang tenu en laisse ». Histoire du jeu : « Le Cœur
s'éveille : failles, primordiaux, Marée du Cœur » (matière exotique, annihilation 2 GW, stabilisateur de Casimir).
Fiche : FICHES_ERE_V.md §4 (fait foi). L'ancien thème Légende (nacre, or blanc, couronne royale, rubis) a été REFUSÉ :
réécrit au nouveau thème (ronde 1 de l'ère V, 23/10).

Image : au centre de la tourelle, un HORIZON NOIR ABSOLU (sphère lisse qui renvoie le soleil) ; autour de sa base, un
DISQUE DE LUMIÈRE segmenté blanc-or-orange, tenu par 3 GRIFFES d'or (la laisse) ; la base en gradins se creuse comme
un puits de gravité, des conduits d'or en SPIRALE y font tomber la lumière vers le centre ; des stabilisateurs de
Casimir gardent les angles nord.
Palette 60/30/10 : NOIR CHAUD anthracite brun (capots, gradins, caissons) ; OR CHAUFFÉ (griffes, arêtes des gradins,
cerclages, conduits, plaques) ; LUMIÈRE INCANDESCENTE blanc-or vers orange. L'horizon est le seul vrai noir, lisse.
Silhouette : coupole en COQUE lisse d'horizon noir (forme « coque » du kit en matière d'horizon : la forme « dome » à
options n'existe pas dans corps._coupole_forme), prolongée jusqu'au disque par une jupe d'horizon ; disque sur la place
« couronne » ; pont à GRADINS (sans fleurons) à liserés pleine lumière ; trémie en ENTONNOIR ; 2 stabilisateurs de
Casimir ; 2 cellules de matière exotique de part et d'autre de la trémie.
Canons : L 3,10, tubes lourds ; culasse = MICRO-SINGULARITÉ (boule noire plus large que le faisceau, cernée d'un anneau
de photons, tenue par 3 griffes d'or : pose N, une boule noire cerclée de lumière au pied de chaque faisceau) ;
2 canons de coupole jumelés ; cellules d'annihilation à l'alimentation.
Tuyaux : conduits d'or en arcs de SPIRALE vers le centre (chenillard vers l'intérieur), câbles d'horizon, jauges de marée.
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
from kit import SQ2, TAU, basis

V = Vector

EPOQUE = 15
NOM = "Néant"
# incandescence blanc-or #FFE6A8 et orange #FFA347 (fiche §4 E5)
FOYER = ages.FOYER[15]
# tubes lourds (+5 % de calibre), L 3,10 (+10,7 % sur 14)
CANON = dict(L=3.1, nb=6, rb=0.076, rr=0.185)
PLATEFORME = dict(chanfrein=0.32)
# RONDE 2 : rayon de la SPHÈRE D'HORIZON dessinée par l'époque (centre sur le plan du disque, zg + hr + 0,01 = 2,31 ;
# sommet vers 3,31 : la plus haute pièce de la suite ; aire vue de dessus environ 8,7 % de l'emprise, le disque en
# couvre une part : fiche §4, horizon 6 à 8 % au plus)
RS = 1.0
# RONDE 2 (lecteurs : « or et noir, luxe ») : l'OR quitte le CORPS (plaques ocre, dents, rivets, boulons, grilles,
# arêtes du pont) pour ne rester qu'à la LAISSE et à la lumière (griffes, bord du disque, conduits en spirale, cerclages) ;
# le corps est noir chaud à usure de cendre, et ses seules lignes vives sont les liserés de LUMIÈRE des gradins
HABILLAGE = dict(ages.CORPS[15],   # lot K0 : MATIÈRE du corps et du pont (capots, acier, rivets, joints,
                 # danger, peinture, plateforme) : commun/ages.py ; ici, les clés propres à la mitrailleuse
                 jupe_cerclage="or_chauffe", chapeau="cendre", tremie="noir_chaud", tourelleau="noir_chaud",
                 grille_nacelle="cendre", munitions=("cendre", "noir_profond"),
                 # PUITS DE GRAVITÉ : gradins de noir chaud, lignes de potentiel pleine lumière, AUCUN fleuron (les
                 # fleurons royaux sont la Légende refusée), aucune arête d'or (ronde 2)
                 forme_plateforme=dict(forme="gradins", flanc="noir_chaud", flanc2="cendre", lisere="emit",
                                       crenaux=False),
                 # HORIZON NOIR : coque lisse en matière d'horizon (diélectrique lisse : reflet du soleil, se lit comme
                 # une SPHÈRE noire), équateur d'or
                 forme_coupole=dict(forme="coque", mat="horizon", mat2="or_chauffe"),
                 # ronde 2 : entonnoir de cendre (l'or de la trémie se lisait encore « luxe » à l'aperçu r2)
                 forme_tremie=dict(forme="entonnoir", mat="noir_chaud", mat2="cendre"))
RECV = ("noir_chaud", "noir_profond")


def matieres(metal, M):
    """Néant : noir chaud anthracite brun satiné (patiné : arêtes usées plus claires), or chauffé (patiné, plus mat dans
    les creux), or blanc chaud au contact du disque, horizon (seul vrai noir, lisse). Le noir chaud est remonté d'un
    cran par rapport à l'albédo de la fiche (plancher C1 >= 43 : un corps noir sans arêtes se lirait comme un bloc)."""
    ages.matieres(15, metal, M)   # lot K0 : matières de l'âge, commun/ages.py (même ordre)
    # rôles de la mitrailleuse (alias), dans l'ordre d'origine
    M["gun"] = M["acier_brule"]
    M["copper"] = M["or_chauffe"]
    M["ring"] = M["or_chauffe"]
    M["jacket"] = M["noir_chaud"]
    M["trim"] = M["or_chauffe"]
    M["pipe"] = M["or_chauffe"]
    M["pipe2"] = M["noir_chaud"]
    M["cable_a"], M["cable_b"] = M["rubber"], M["noir_profond"]
    M["spec"] = M["or_chauffe"]
    M["accent"] = M["or_chauffe"]


def _halo(g, pts, power, rgb=None):
    col = rgb or g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


def _rx_coque(c, z):
    """Rayon (axe x du repère de la tête) de la coupole de forme à la hauteur z (corps.z_coque, par dichotomie)."""
    lo, hi = 0.0, c.H["R"]
    for _ in range(30):
        m = (lo + hi) / 2
        if corps.z_coque(c, m, 0.0) > z:
            lo = m
        else:
            hi = m
    return lo


def _assise(g, c, x0, x1, yn0, yn1, rond=None):
    """Pont à gradins : hauteur dont monter un organe posé au sol pour qu'il repose SUR le pont (corps.z_pont au
    centre de son emprise, moins le tablier, 0,045) ; si l'organe monte, une ASSISE pleine de noir chaud à jonc d'or
    comble son emprise jusqu'au sol (rien ne flotte au bord d'un gradin)."""
    xc, yc = (x0 + x1) / 2, (yn0 + yn1) / 2
    dz = max(0.0, corps.z_pont(c, xc, yc) - 0.045)
    if dz > 0.004:
        M = g.M
        if rond:
            g.cyl((xc, Y(yc), (dz + 0.045) / 2), "z", rond, dz + 0.045, M["noir_chaud"], n=32, what="assise")
            g.torus((xc, Y(yc), dz + 0.045), "z", rond, 0.014, M["or_chauffe"], n=32, m=6, what="jonc")
        else:
            PT.hull(g, x0, x1, Y(yn0), Y(yn1), 0.0, dz + 0.045, ins=(0.012, 0.012, 0.012), panel=0.3,
                    mats=[M["noir_chaud"], M["or_chauffe"]], rivet_step=0.16)
    return dz


# ------------------------------------------------------------------------------------------------
# Organes signature : griffe, micro-singularité, fenêtre blanc-or
# ------------------------------------------------------------------------------------------------
def griffe(g, pts, w, t, mat=None):
    """GRIFFE d'or chauffé : chaîne de blocs pleins le long d'une courbe (points), section w × t qui s'amincit vers la
    pointe ; dernier point = pointe recourbée."""
    M = g.M
    mat = mat or M["or_chauffe"]
    P = [V(p) for p in pts]
    n = len(P) - 1
    for i in range(n):
        a, b = P[i], P[i + 1]
        d = b - a
        if d.length < 1e-5:
            continue
        f = 1.0 - 0.55 * i / max(1, n)
        dn = d.normalized()
        up = V((0, 0, 1)) if abs(dn.z) < 0.95 else V((1, 0, 0))
        sd = dn.cross(up).normalized()
        nm = sd.cross(dn).normalized()
        Rm = Matrix((sd, dn, nm)).transposed()
        g.box((a + b) / 2, (w * f, d.length + t * 0.6, t * f), mat, "hard", R=Rm, what="griffe")


def singularite(g, C, r, k=1.0, axe="y", griffes=True):
    """MICRO-SINGULARITÉ : sphère d'horizon noir lisse, ANNEAU DE PHOTONS fin (lumière blanc-or) qui la cerne, liseré
    orange au bord, 3 griffes d'or qui la tiennent sans la cacher."""
    M = g.M
    C = V(C)
    g.sphere(C, r, M["horizon"], n=32, m=16, what="horizon")
    g.torus(C, axe, r + 0.012 * k + 0.004, 0.009 * k + 0.004, M["emit"], n=48, m=6, what="anneau_photons")
    g.torus(C, axe, r + 0.03 * k + 0.008, 0.006 * k + 0.003, M["emit2"], n=48, m=6, what="anneau_photons2")
    if griffes:
        ax = {"x": V((1, 0, 0)), "y": V((0, 1, 0)), "z": V((0, 0, 1))}[axe]
        _, u, w = basis(ax)
        for i in range(3):
            a = TAU * i / 3 + 0.5
            d = u * math.cos(a) + w * math.sin(a)
            pts = [C - ax * r * 0.97 + d * r * 0.3, C - ax * r * 0.62 + d * (r * 0.8),
                   C + d * (r * 1.0 + 0.004), C + ax * r * 0.6 + d * (r * 0.8), C + ax * r * 0.86 + d * (r * 0.5)]
            griffe(g, pts, 0.07 * k + 0.02, 0.05 * k + 0.014)


def fenetre(g, p, nrm, w, h, mat=None):
    """Fenêtre blanc-or : cadre d'or chauffé, fond lumineux (≤ 0,03 t²)."""
    M = g.M
    p = V(p)
    n = V(nrm).normalized()
    _, u, v = basis(n)
    up = V((0, 0, 1))
    if abs(n.z) < 0.9:
        u = up.cross(n).normalized()
        v = n.cross(u).normalized()
    Rm = Matrix((u, v, n)).transposed()
    g.box(p + n * 0.008, (w + 0.04, h + 0.04, 0.016), M["or_chauffe"], "hard", R=Rm, what="cadre")
    g.box(p + n * 0.017, (w, h, 0.004), mat or M["emit"], "flat", R=Rm, what="fenetre_lum")


# ------------------------------------------------------------------------------------------------
# Socle (corps du niveau 29)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    E = M["emit"]
    B = c.B
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.62, 6, E, a0=math.pi + 0.2, span=math.pi - 0.4)
    F.slits_grouped(g, B["R"] + 0.02, B["h"] * 0.36, 5, M["emit2"], a0=math.pi + 0.35, span=math.pi - 0.7,
                    per=(3, 2))
    for zz in (B["h"] * 0.22, B["h"] * 0.86):
        g.tube_shell((0, 0, zz), "z", B["R"] + 0.03, B["R"] - 0.02, 0.05, M["or_chauffe"], n=64, what="cerclage")
    dz = _assise(g, c, 1.65, 1.95, -1.3, 1.45)
    g.push((0, 0, dz))
    P2.grating(g, 1.65, 1.95, Y(-1.3), Y(1.45), 0.07, M)
    g.pop()
    dz = _assise(g, c, -1.95, -1.65, -1.1, 1.1)
    g.push((0, 0, dz))
    P2.grating(g, -1.95, -1.65, Y(-1.1), Y(1.1), 0.07, M)
    g.pop()
    # sud : CELLULES D'ANNIHILATION (à la place des caisses ouvertes)
    for sx in (-1, 1):
        dz = _assise(g, c, sx * 1.45 - 0.45, sx * 1.45 + 0.45, -2.35, -1.55)
        with at(g, sx * 1.45, -1.95, -sx * 0.45, z=dz):
            cellule_annihilation(g, 0.84, 0.7, 0.32)
    # tourelles secondaires (sud) à micro-singularité ; le coin nord-est passe au stabilisateur de Casimir
    for (x, yn, rz) in [(-2.4, -2.5, -0.3), (2.4, -2.5, 0.3)]:
        dz = _assise(g, c, x - 0.46, x + 0.46, yn - 0.46, yn + 0.46, rond=0.47)
        with at(g, x, yn, 0.0, z=dz):
            P2.pedestal(g, 0.46, 0.0, 0.32, 8, M, [M["noir_chaud"], M["or_chauffe"]], gussets=False)
            mini_turret(g, (0, 0, 0.32), 1.02, rz)
    tremie_puits(g, c)
    # 2 CELLULES DE MATIÈRE EXOTIQUE de part et d'autre de la trémie (accroches tremie_O, tremie_E)
    for sx in (-1, 1):
        x, yn = sx * 0.92, -2.41
        dz = _assise(g, c, x - 0.22, x + 0.22, yn - 0.16, yn + 0.16)
        cellule_exotique(g, (x, Y(yn), dz + 0.045), 0.34)
    corps.collecteur(g, c, conduit_or, r=0.05)
    # CONDUITS EN SPIRALE sur les gradins : arcs qui tombent vers la colonne, tous dans le sens du disque
    spirale(g, c, (1.05, -2.35), 0.55, 0.045)
    spirale(g, c, (-1.05, -2.35), 0.5, 0.045)
    spirale(g, c, (2.5, 0.35), 0.45, 0.04)
    spirale(g, c, (-2.45, -0.55), 0.45, 0.04)
    # ouest : ANNIHILATEUR 2 GW
    dz = _assise(g, c, -2.88, -1.98, -1.35, 1.35)
    g.push((0, 0, dz))
    annihilateur(g)
    g.pop()
    cables(g, [(-1.98, Y(0.05), 0.5 + dz), (-1.75, Y(0.02), 0.72 + dz), (-1.5, Y(0.0), 0.82 + dz)])
    # nord : 2 STABILISATEURS DE CASIMIR (plaques à interstices lumineux fermés)
    for sx in (-1, 1):
        x, yn = sx * 2.1, 2.3
        dz = _assise(g, c, x - 0.38, x + 0.38, yn - 0.24, yn + 0.24)
        casimir(g, (x, Y(yn), dz + 0.045), 0.62, 0.5, 6)
    # est : RÉSERVOIRS DE MATIÈRE EXOTIQUE
    for yn in (1.0, -0.55):
        dz = _assise(g, c, 1.96, 2.84, yn - 0.44, yn + 0.44, rond=0.45)
        g.push((0, 0, dz))
        reservoir_exotique(g, 2.4, Y(yn), 0.44, 1.0)
        g.pop()
    dz = _assise(g, c, -2.85, -2.08, -2.85 / SQ2, -2.2 / SQ2)
    g.push((0, 0, dz))
    P3.cabinet(g, -2.85, -2.08, -2.85, -2.2, 0.0, 0.55, M, E)
    g.pop()
    # sud-est : banc de JAUGES DE MARÉE (à la place de la vanne à volants)
    dz = _assise(g, c, 1.98, 2.85, -1.55, -1.18)
    g.push((0, 0, dz))
    jauges_maree(g, 1.98, 2.85, Y(-1.55), Y(-1.18), 0.3)
    g.pop()
    conduit_or(g, [(2.0, Y(1.1), 0.75 + dz), (1.72, Y(1.0), 1.12 + dz), (1.4, Y(0.8), 0.95 + dz)], 0.055)
    conduit_or(g, [(2.0, Y(-0.45), 0.75 + dz), (1.72, Y(-0.5), 1.1 + dz), (1.42, Y(-0.4), 0.95 + dz)], 0.055)
    # nord : radiateur noir et or flanqué des stabilisateurs ; armoires
    dz = _assise(g, c, -1.3, 1.3, 2.05, 2.78)
    g.push((0, 0, dz))
    P2.fan_radiator(g, -1.3, 1.3, Y(2.05), Y(2.78), 0.0, 0.42, 3, M, emat=E)
    g.pop()
    dzc = _assise(g, c, -1.15, 1.25, 1.6, 1.98)
    g.push((0, 0, dzc))
    P3.cabinet(g, -1.15, -0.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    P3.cabinet(g, 0.35, 1.25, Y(1.6), Y(1.98), 0.0, 0.5, M, E)
    g.pop()
    dz = max(0.0, corps.z_pont(c, -2.6, 0.0) - 0.045)
    g.push((0, 0, dz))
    P2.anchor(g, -2.6, Y(0.0), 0.26, M)
    g.pop()
    for x in (-0.8, 0.8):
        PT.lamp(g, (x, Y(-2.75) - 0.05, 0.12), (0, -0.4, 1), 0.034, M["amber"])
    _halo(g, [(-2.4, Y(-1.2), 0.6), (2.4, Y(-2.7), 0.7), (-2.4, Y(-2.7), 0.7), (0.0, Y(-2.85), 0.5),
              (-2.1, Y(2.3), 0.8), (2.1, Y(2.3), 0.8), (2.4, Y(0.2), 0.6)], 22.0)


def cellule_annihilation(g, w, d, h):
    """CELLULE D'ANNIHILATION (2 GW) : caisson noir chaud riveté, couvercle bombé, 2 fenêtres blanc-or, griffes d'or
    aux angles."""
    M = g.M
    PT.hull(g, -w / 2, w / 2, -d / 2, d / 2, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.26,
            mats=[M["noir_chaud"], M["noir_chaud2"], M["or_chauffe"]], rivet_step=0.12)
    g.cyl((0, 0, h), "x", d * 0.38, w * 0.86, M["noir_chaud"], n=20, what="couvercle")
    for f in (-0.36, 0.0, 0.36):
        g.tube_shell((f * w, 0, h), "x", d * 0.4, d * 0.33, 0.04, M["or_chauffe"], n=20, what="cerclage")
    for f in (-0.2, 0.2):
        fenetre(g, (f * w, -d / 2, h * 0.5), (0, -1, 0), 0.12, 0.1)
    for sxx in (-1, 1):
        for syy in (-1, 1):
            q = V((sxx * (w / 2 - 0.01), syy * (d / 2 - 0.01), h * 0.4))
            griffe(g, [q, q + V((0, 0, h * 0.62)), q + V((-sxx * 0.08, -syy * 0.06, h * 0.75))], 0.05, 0.035)


def mini_turret(g, c, s, rz):
    """Tourelle secondaire NÉANT : couronne rivetée de la lignée, caisson noir chaud à bandes d'or, MICRO-SINGULARITÉ
    sur le dos (sphère d'horizon, anneau de photons, griffes) ; deux petits canons de l'époque."""
    M = g.M
    g.push(c, rz=rz)
    g.cyl((0, 0, 0.05 * s), "z", 0.36 * s, 0.1 * s, M["armor2"], n=32, style="soft", what="couronne")
    nb = int(TAU * 0.32 * s / 0.1)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((0.31 * s * math.cos(a), 0.31 * s * math.sin(a), 0.1 * s), (0, 0, 1), 0.016, M["rivet"])
    PT.hull(g, -0.24 * s, 0.24 * s, -0.3 * s, 0.24 * s, 0.1 * s, 0.32 * s, ins=(0.04 * s, 0.03 * s, 0.06 * s),
            panel=0.22, mats=[M["noir_chaud"], M["noir_chaud2"]])
    for yy in (-0.2 * s, 0.08 * s):
        g.box((0, yy, 0.325 * s), (0.4 * s, 0.04, 0.02), M["or_chauffe"], "hard", what="bande")
    g.cyl((0.0, -0.06 * s, 0.34 * s), "z", 0.07 * s, 0.05, M["noir_profond"], n=20, what="socle_singularite")
    singularite(g, (0.0, -0.06 * s, 0.34 * s + 0.12 * s), 0.1 * s, k=0.6, axe="z")
    for sx in (-1, 1):
        PT.receiver(g, sx * 0.31 * s, -0.16 * s, 0.22 * s, 0.16 * s, 0.36 * s, 0.13 * s, mats=[M[k] for k in RECV])
        _gun15(g, sx * 0.31 * s, 0.22 * s, 0.26 * s, 0.62 * s, 6, 0.023 * s, 0.052 * s)
    g.pop()


def tremie_puits(g, c):
    """Trémie de l'époque (ENTONNOIR du kit, or à l'intérieur, noir dehors) : liseré d'or au bord de l'entonnoir, deux
    conduits d'or qui tombent vers la colonne."""
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    W = x1 - x0
    for s in (-1, 1):
        conduit_or(g, [(s * (W / 2 + 0.05), y1 - 0.25, h * 0.55), (s * (W / 2 + 0.15), y1 + 0.2, h + 0.2),
                       (s * 0.4, y1 + 0.5, c.rt + 0.04)], 0.045)


def cellule_exotique(g, p, a):
    """CELLULE DE MATIÈRE EXOTIQUE : cube noir chaud à arêtes d'or (12 arêtes), fenêtre blanc-or sur les faces vues."""
    M = g.M
    p = V(p)
    C = p + V((0, 0, a / 2))
    g.box(C, (a, a, a), M["noir_chaud"], "hard", what="cellule")
    e = 0.03
    for (dx, dy) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        g.box(C + V((dx * a / 2, dy * a / 2, 0)), (e, e, a + e), M["or_chauffe"], "hard", what="arete")
    for dz in (-1, 1):
        for dy in (-1, 1):
            g.box(C + V((0, dy * a / 2, dz * a / 2)), (a + e, e, e), M["or_chauffe"], "hard", what="arete")
        for dx in (-1, 1):
            g.box(C + V((dx * a / 2, 0, dz * a / 2)), (e, a + e, e), M["or_chauffe"], "hard", what="arete")
    fenetre(g, C - V((0, a / 2, 0)), (0, -1, 0), a * 0.42, a * 0.42)
    fenetre(g, C + V((0, 0, a / 2)), (0, 0, 1), a * 0.36, a * 0.36, M["emit2"])


def spirale(g, c, depart, tour, r):
    """CONDUIT EN SPIRALE : tube d'or chauffé qui suit un arc de spirale depuis `depart` (x, yn) jusqu'au pied de la
    colonne, tourné de `tour` radians dans le sens du disque (trigonométrique vu de dessus) ; il ne fait que descendre
    vers le centre (hauteur monotone, au-dessus du gradin le plus haut traversé) ; manchons noirs tous les 0,3 t et
    CHENILLARD de points blanc-or vers l'intérieur ; supports à griffe jusqu'au pont (rien ne flotte)."""
    M = g.M
    x0, y0 = depart[0], Y(depart[1])
    r0 = math.hypot(x0, y0)
    a0 = math.atan2(y0, x0)
    r1 = c.B["R"] - 0.02
    n = 40
    pts = []
    for i in range(n + 1):
        t = i / n
        rr = r0 + (r1 - r0) * (t ** 0.8)
        a = a0 + tour * t
        pts.append([rr * math.cos(a), rr * math.sin(a), 0.0])
    zb = [corps.z_pont(c, p[0], p[1] / SQ2) for p in pts]
    zmax = 0.0
    for i in range(n + 1):
        zmax = max(zmax, zb[i])
        pts[i][2] = zmax + r + 0.03
    # le bout entre dans la colonne à une hauteur raisonnable
    pts[-1][2] = max(pts[-1][2], 0.3)
    P = [V(p) for p in pts]
    P, T = g.tube(P, r, M["or_chauffe"], n=12, what="spirale")
    R = g.resample(P, 0.1)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 3 == 0:
            g.tube_shell(R[i], T2[i], r + 0.014, r * 0.5, 0.04, M["noir_chaud"], n=12, what="manchon")
        elif i % 3 == 1:
            g.sphere(R[i] + V((0, 0, r * 0.9)), 0.012, M["emit"], n=8, m=5, what="chenillard")
    for i in range(0, len(R) - 1, 3):
        zp = corps.z_pont(c, R[i].x, R[i].y / SQ2)
        hh = R[i].z - r - zp
        if hh > 0.02:
            g.box(V((R[i].x, R[i].y, zp + hh / 2)), (0.04, 0.04, hh), M["noir_profond"], "hard", what="support")
            g.box(V((R[i].x, R[i].y, R[i].z - r * 0.8)), (0.07, 0.03, 0.03), M["or_chauffe"], "hard", what="griffe")


def annihilateur(g):
    """Groupe de l'ouest : ANNIHILATEUR 2 GW (caisson noir chaud à ailettes, 3 fenêtres blanc-or sur le toit, griffes
    d'or aux angles, bande d'or)."""
    M = g.M
    x0, x1, y0, y1, h = -2.88, -1.98, Y(-1.35), Y(1.35), 0.55
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.03), panel=0.28,
            mats=[M["noir_chaud"], M["noir_chaud2"], M["noir_profond"]], rivet_step=0.12)
    for xx in (x0 - 0.02, x1 + 0.02):
        for i in range(12):
            yy = y0 + 0.15 + (y1 - y0 - 0.3) * i / 11
            g.box((xx, yy, h * 0.5), (0.04, 0.016, h * 0.66), M["noir_profond"], "hard", what="ailette")
    g.box((x1 + 0.045, cy, h * 0.9), (0.012, y1 - y0 - 0.2, 0.035), M["or_chauffe"], "hard", what="bande")
    for f in (-0.55, 0.0, 0.55):
        fenetre(g, (cx, cy + f * (y1 - y0) * 0.5, h), (0, 0, 1), 0.3, 0.12)
    for (xx, yy) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        q = V((xx, yy, h * 0.3))
        dx = 1 if xx == x0 else -1
        dy = 1 if yy == y0 else -1
        griffe(g, [q, q + V((0, 0, h * 0.7)), q + V((dx * 0.12, dy * 0.12, h * 0.8))], 0.06, 0.04)


def casimir(g, p, w, d, n):
    """STABILISATEUR DE CASIMIR : empilement de n plaques de noir chaud parallèles, très rapprochées, à arêtes d'or,
    séparées par des INTERSTICES LUMINEUX blanc-or FERMÉS par des entretoises d'angle (aucun jour) ; chapeau d'or.
    Un bloc large et plat : jamais un cylindre debout."""
    M = g.M
    p = V(p)
    tp, gap = 0.045, 0.03
    for i in range(n):
        z = p.z + i * (tp + gap)
        g.box(p + V((0, 0, z - p.z + tp / 2)), (w, d, tp), M["noir_chaud"], "hard", what="plaque_casimir")
        g.box(p + V((0, -d / 2 - 0.004, z - p.z + tp * 0.75)), (w + 0.01, 0.012, tp * 0.35), M["or_chauffe"], "hard",
              what="arete_or")
        if i < n - 1:
            g.box(p + V((0, 0, z - p.z + tp + gap / 2)), (w - 0.1, d - 0.1, gap * 0.98), M["emit"], "flat",
                  what="interstice")
    ht = n * (tp + gap) - gap
    for (dx, dy) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        g.box(p + V((dx * (w / 2 - 0.035), dy * (d / 2 - 0.035), ht / 2)), (0.07, 0.07, ht), M["or_chauffe"], "hard",
              what="entretoise")
    g.box(p + V((0, 0, ht + 0.02)), (w * 0.7, d * 0.7, 0.04), M["or_chauffe"], "hard", what="chapeau")
    for dx in (-1, 1):
        g.dome(p + V((dx * w * 0.25, 0, ht + 0.04)), (0, 0, 1), 0.02, M["rivet"])


def reservoir_exotique(g, x, y, r, h):
    """RÉSERVOIR DE MATIÈRE EXOTIQUE (même place et même masse que le réservoir debout) : virole noir chaud cerclée
    d'or, FENTE blanc-or verticale sur la face vue, griffes d'or sur le fond bombé."""
    M = g.M
    P3.vtank(g, x, y, r, h, M, paint=M["noir_chaud"], emat=M["emit"], ladder_dir=(1, 0.2), stub_dir=(-1, 0),
             gauges=2, glow_gauges=True, glow_rings=0, band=M["or_chauffe"])
    for zz in (0.3, 0.55, 0.8):
        g.tube_shell((x, y, h * zz), "z", r + 0.02, r - 0.01, 0.045, M["or_chauffe"], n=40, what="cerclage")
    a = -1.6
    d = V((math.cos(a), math.sin(a), 0))
    g.box(V((x, y, h * 0.55)) + d * (r + 0.012), (0.07, 0.024, h * 0.42), M["or_chauffe"], "hard", R=Matrix((
        V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="cadre_fente")
    g.box(V((x, y, h * 0.55)) + d * (r + 0.026), (0.03, 0.006, h * 0.36), M["emit"], "flat", R=Matrix((
        V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed(), what="fente_lum")
    for k in range(3):
        a = TAU * k / 3 + 0.3
        dd = V((math.cos(a), math.sin(a), 0))
        q = V((x, y, h)) + dd * r * 0.75
        griffe(g, [q, q + dd * 0.06 + V((0, 0, 0.08)), q - dd * 0.06 + V((0, 0, 0.16))], 0.05, 0.035)


def jauges_maree(g, x0, x1, y0, y1, h):
    """Banc de JAUGES DE MARÉE (sud-est) : caisson noir chaud, 3 cadrans noirs à aiguille d'or et point blanc-or,
    espacements inégaux ; 2 conduits d'or debout."""
    M = g.M
    PT.hull(g, x0, x1, y0, y1, 0.0, h, ins=(0.02, 0.02, 0.02), panel=0.22, mats=[M["noir_chaud"], M["or_chauffe"]],
            rivet_step=0.12)
    w = x1 - x0
    for f in (0.17, 0.42, 0.8):
        p = V((x0 + w * f, y0 - 0.005, h * 0.55))
        n = V((0, -1, 0))
        g.cyl(p + n * 0.012, n, 0.055, 0.024, M["or_chauffe"], n=16, style="hard", what="jauge")
        g.cyl(p + n * 0.026, n, 0.044, 0.004, M["noir_profond"], n=16, style="flat", what="cadran")
        g.box(p + n * 0.03 + V((0.012, 0, 0.012)), (0.05, 0.004, 0.008), M["or_blanc_chaud"], "flat",
              R=Matrix.Rotation(0.7, 3, "Y"), what="aiguille")
        g.cyl(p + n * 0.031 + V((-0.02, 0, -0.02)), n, 0.008, 0.003, M["emit"], n=8, style="flat", what="point")
    yc = (y0 + y1) / 2
    for f in (0.3, 0.7):
        x = x0 + w * f
        conduit_or(g, [(x, yc, h), (x, yc, h + 0.18), (x - 0.06, yc + 0.2, h + 0.26)], 0.04)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : conduits d'or (chenillard vers le centre), câbles d'horizon
# ------------------------------------------------------------------------------------------------
def conduit_or(g, ctrl, r):
    """Conduit d'OR CHAUFFÉ : manchons noirs tous les 0,3 t, chenillard de points blanc-or, berceaux sur le pont."""
    M = g.M
    P = g.spline(ctrl, 10)
    P, T = g.tube(P, r, M["or_chauffe"], n=12, what="conduit_or")
    R = g.resample(P, 0.1)
    T2, _ = g.frames(R)
    for i in range(1, len(R) - 1):
        if i % 3 == 0:
            g.tube_shell(R[i], T2[i], r + 0.014, r * 0.5, 0.04, M["noir_chaud"], n=12, what="manchon")
        elif i % 3 == 1:
            _, u, w = basis(T2[i])
            g.sphere(R[i] + V((0, 0, r * 0.9)), 0.011, M["emit"], n=8, m=5, what="chenillard")


def cables(g, ctrl, n=3):
    """Câbles d'HORIZON : câbles noirs épais à bagues d'or."""
    M = g.M
    PT.cable_run(g, ctrl, n, 0.022, 0.05, [M["noir_profond"], M["or_chauffe"], M["noir_profond"]])


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 30 : 2 SINGULARITÉS EN CAGE
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    for sx in (-1, 1):
        even_piece(g, sx * 1.22, Y(-2.97), sx)
    _halo(g, [(-1.22, Y(-3.3), 0.4), (1.22, Y(-3.3), 0.4)], 18.0)


def even_piece(g, x, yb, sx):
    """SINGULARITÉ EN CAGE : sphère d'horizon (diamètre 0,24) cernée d'un petit DISQUE segmenté blanc-or, tenue par
    3 griffes d'or sur un socle blindé noir chaud à caisson de cellules ; plinthe commune à bande de danger."""
    M = g.M
    E = M["emit"]
    w, d = 0.62, 0.6
    PT.hull(g, x - w / 2, x + w / 2, yb - d / 2, yb + d / 2, 0.0, 0.14, ins=(0.02, 0.02, 0.02), panel=0.3,
            mats=[M["noir_chaud"], M["noir_profond"]], rivet_step=0.12)
    g.hazard([V((x - w / 2, yb - d / 2 - 0.02, 0.02)), V((x + w / 2, yb - d / 2 - 0.02, 0.02)),
              V((x + w / 2, yb - d / 2 - 0.02, 0.12)), V((x - w / 2, yb - d / 2 - 0.02, 0.12))], 6, t=0.012, skew=0.6)
    P3.lamp_group(g, (x - w / 2 + 0.06, yb - d / 2 - 0.025, 0.07), (1, 0, 0), (0, -1, 0), E, M, n=2,
                  shapes=("rond", "fente"))
    PT.hull(g, x - 0.22, x + 0.22, yb - 0.22, yb + 0.22, 0.14, 0.3, ins=(0.015, 0.015, 0.015), panel=0.22,
            mats=[M["noir_chaud"], M["or_chauffe"]], rivet_step=0.1)
    fenetre(g, (x, yb - 0.22, 0.22), (0, -1, 0), 0.14, 0.06)
    C = V((x, yb, 0.3 + 0.24))
    g.cyl((x, yb, 0.34), "z", 0.07, 0.08, M["noir_profond"], n=20, what="pied")
    # petit disque segmenté (anneau noir et 16 segments blanc-or)
    g.tube_shell(C, "z", 0.26, 0.16, 0.024, M["noir_chaud"], n=48, what="disque")
    for i in range(16):
        a = TAU * (i + 0.5) / 16
        dd = V((math.cos(a), math.sin(a), 0))
        g.box(C + dd * 0.21 + V((0, 0, 0.014)), (TAU * 0.21 / 16 * 0.75, 0.06, 0.006), E if i % 2 else M["emit2"],
              "flat", R=Matrix((V((-dd.y, dd.x, 0)), dd, V((0, 0, 1)))).transposed(), what="segment")
    singularite(g, C, 0.12, k=0.8, axe="z", griffes=False)
    for i in range(3):
        a = TAU * i / 3 + 0.4
        dd = V((math.cos(a), math.sin(a), 0))
        griffe(g, [V((x, yb, 0.3)) + dd * 0.18, C + dd * 0.27 + V((0, 0, -0.08)), C + dd * 0.28 + V((0, 0, 0.06)),
                   C + dd * 0.16 + V((0, 0, 0.13))], 0.06, 0.04)


# ------------------------------------------------------------------------------------------------
# Arme (E1) : canon effilé lourd à MICRO-SINGULARITÉ
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    """Canon de flanc (après le bras de tourillon du kit) : culasse noir chaud à griffes d'or, moteur arrière, canon de
    l'époque, masque de canon, CELLULES D'ANNIHILATION à l'alimentation, voyants."""
    M = g.M
    H = c.H
    zg = H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    PT.receiver(g, x, y0, y1, zg - hr, zg + hr, wr, mats=[M[k] for k in RECV])
    corps.moteur_lignee(g, (x, y0 - 0.2 - hr * 0.3, zg), hr * 0.78, 0.3 + hr * 0.6, moyeu="ring")
    _gun15(g, x, y1, zg, H["L"], H["nb"], H["rb"], H["rr"])
    PT.hull(g, x - wr * 0.72, x + wr * 0.72, y1 - 0.04, y1 + 0.07, zg - hr * 1.3, zg + hr * 1.35,
            ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["noir_chaud"], M["or_chauffe"]], rivet_step=0.11)
    PT.lamp(g, (x, y0 + 0.12, zg + hr + 0.03), (0, 0.4, 1), 0.03, M["emit"])
    xo = x + sx * (wr / 2 + 0.05)
    feed(g, x, sx, H, xo)
    zt = zg + hr + 0.012
    g.box((x, (y0 + y1) / 2, zt + 0.012), (wr * 0.76, (y1 - y0) * 0.5, 0.024), M["noir_profond"], "hard", what="plaque")
    for f in (0.3, 0.7):
        g.box((x, y0 + (y1 - y0) * f, zt + 0.028), (wr * 0.8, 0.03, 0.012), M["or_chauffe"], "hard", what="liseré")
    for s in (-1, 1):
        q = V((x + s * wr * 0.5, y1 - 0.12, zg + hr * 0.2))
        griffe(g, [q, q + V((s * 0.04, 0.0, hr * 0.85)), q + V((-s * 0.06, 0.02, hr * 1.05))], 0.06, 0.04)


def _gun15(g, x, y0, z, L, nb, rb, rr):
    """Canon effilé LOURD du kit (bague et manchon d'or chauffé, pointes presque blanches) + MICRO-SINGULARITÉ à la
    culasse : sphère d'horizon noir PLUS LARGE que le faisceau, anneau de photons qui la cerne, 3 griffes d'or ; elle
    s'AJOUTE à la rosette (règle d'or 1). En pose N : une boule noire cerclée de lumière au pied de chaque faisceau."""
    M = g.M
    k = F.k_arme(rb, rr)
    R0 = rr + rb
    # ronde 2 : pointes ORANGE incandescent (des pointes crème se lisaient vapeur de cheminée en pose N)
    e_, M["emit"] = M["emit"], M["emit2"]
    try:
        corps.canon_effile(g, x, y0, z, L, nb, rb, rr, jaquette=0.3, bague_mat="or_chauffe", conv=0.6,
                           frein=(0.66, 0.8))
    finally:
        M["emit"] = e_
    rs = R0 + 0.06 * k + 0.004
    cy = y0 + rs * 0.85 + 0.02
    singularite(g, (x, cy, z), rs, k=k, axe="y", griffes=True)
    return y0 + L


def feed(g, x, sx, H, xo):
    """Alimentation latérale : caisson noir chaud (volume de la lignée), 2 CELLULES D'ANNIHILATION à fenêtres blanc-or
    et cerclages d'or, goulotte, voyants."""
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
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24,
            mats=[M["noir_chaud"], M["or_chauffe"]], rivet_step=0.11)
    ztop = zb1 + 0.015
    for kk in range(2):
        cc = V((bc, yb0 + bl * (0.25 + 0.3 * kk), ztop))
        g.cyl(cc + V((0, 0, 0.08)), "z", 0.075, 0.16, M["noir_profond"], n=20, what="cellule")
        for zz in (0.03, 0.13):
            g.tube_shell(cc + V((0, 0, zz)), "z", 0.083, 0.065, 0.02, M["or_chauffe"], n=20, what="cerclage")
        fenetre(g, cc + V((0, -0.076, 0.08)), (0, -1, 0), 0.05, 0.05)
        g.tube_shell(cc + V((0, 0, 0.165)), "z", 0.058, 0.044, 0.012, E, n=20, what="couronne_lum")
    P2.feed_chute(g, [(bc, yb0 + bl * 0.88, ztop + 0.01), (bc - sx * 0.05, y0 + bl * 0.75, zg + bh * 0.55),
                      (x + sx * wr * 0.25, y0 + bl * 0.6, zg + hr + 0.06)], 0.12 * wr / 0.4 + 0.04, M)
    P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.06, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                  E, M, n=3, shapes=("rond", "carre", "fente"))
    return bc


def dome_gun(g, c, xg, L, s=1.0):
    """Canon de coupole JUMELÉ planté dans l'horizon (corps.z_coque) : fût-pivot noir à griffes d'or, berceau blindé,
    canon de l'époque à micro-singularité."""
    M = g.M
    yb = -0.3 * s
    zr = max(corps.z_coque(c, xg + xx, yy) for xx in (-0.32 * s, 0.0, 0.32 * s)
             for yy in (yb - 0.2 * s, yb, yb + 0.3 * s, yb + 0.62 * s)) + 0.02
    zc = zr + 0.3 * s
    zs_ = corps.z_coque(c, xg, yb + 0.22 * s) - 0.05
    g.cyl((xg, yb + 0.22 * s, (zs_ + zr) / 2), "z", 0.17 * s, zr - zs_, M["noir_chaud"], n=24, what="pivot")
    for i in range(3):
        a = TAU * i / 3 + 0.3
        d = V((math.cos(a), math.sin(a), 0))
        q = V((xg, yb + 0.22 * s, zs_ + 0.04)) + d * 0.17 * s
        griffe(g, [q + d * 0.04, q + d * 0.09 + V((0, 0, (zr - zs_) * 0.6)), q + d * 0.02 + V((0, 0, zr - zs_))],
               0.05, 0.035)
    g.push((xg, 0.0, 0.0))
    PT.hull(g, -0.34 * s, 0.34 * s, yb - 0.2 * s, yb + 0.62 * s, zr - 0.04, zr + 0.18 * s, ins=(0.04, 0.04, 0.08),
            panel=0.22, mats=[M["noir_chaud"], M["or_chauffe"]], rivet_step=0.11)
    PT.receiver(g, 0.0, yb - 0.2 * s, yb + 0.62 * s, zc - 0.16 * s, zc + 0.14 * s, 0.34 * s, mats=[M[k] for k in RECV])
    _gun15(g, 0.0, yb + 0.62 * s, zc, L, 6, 0.052 * s, 0.125 * s)
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.24 * s, yb + 0.25 * s, zr + 0.02), (sx * 0.3 * s, yb + 0.55 * s, zr + 0.18 * s), 0.024)
    g.pop()
    return zc


# ------------------------------------------------------------------------------------------------
# Masque et tête
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    corps.masque_lignee(g, c, mats=("or_chauffe", "noir_chaud"), fentes=((-0.42, 0.34), (0.42, 0.22)),
                        visiere=("or_chauffe", 0.13),
                        coax=dict(fut="noir_profond", manchon="or_chauffe", manchon_y=0.28, manchon_r=0.045,
                                  manchon_L=0.16))


def tete(g, c):
    M = g.M
    E = M["emit"]
    H = c.H
    R = H["R"]
    zs = H["zs"]
    K = corps.accroche(c, "couronne")
    r0, r1 = K["r0"], K["r1"]
    zd0 = K["z0"] + 0.02
    # JUPE D'HORIZON : la sphère noire descend jusqu'au disque (la jupe de la lignée est couverte)
    g.cyl((0, 0, (zd0 + zs) / 2 + 0.01), "z", R + 0.075, zs - zd0 + 0.02, M["horizon"], n=96, what="horizon_jupe")
    # RONDE 2 (test à l'aveugle de la ronde 1 : « il manque une silhouette propre au dernier niveau », 15 lu « or et noir,
    # grand anneau, luxe » et confondu avec 13) : l'HORIZON devient une VRAIE SPHÈRE NOIRE, la plus haute pièce de toute
    # la suite (rayon RS, centre sur le plan du disque, sommet vers 3,3), dessinée par l'époque PAR-DESSUS la coque du
    # kit (qui reste dessous, cachée) ; le DISQUE DE LUMIÈRE passe par son équateur, comme Saturne ou Gargantua : la moitié
    # avant du disque barre la sphère, la moitié arrière est mangée par elle. Les canons de coupole sortent de sa face
    # avant (plus de tourelleau ni de viseur visibles : ils restent sous la sphère).
    zr = H["zg"] + H["hr"] + 0.01
    g.sphere((0, 0, zr), RS, M["horizon"], n=72, m=36, what="horizon")
    # DISQUE D'ACCRÉTION élargi (0,54 au lieu de 0,26) : plateau de noir chaud continu depuis l'intérieur de la sphère,
    # 4 bandes de 64 segments à joints noirs, du blanc pur au bord de l'horizon jusqu'à l'orange au bord extérieur, puis
    # une bande de poussière (un segment sur deux) ; chaque segment est VRILLÉ de 0,35 rad : le disque tourne et
    # s'enroule (spirale) vers l'horizon ; bord d'or vif. Il reste dans le rayon libre entre les culasses (1,58).
    rin = RS + 0.012
    rout = 1.55
    g.tube_shell((0, 0, zr), "z", rout, RS * 0.9, 0.04, M["noir_chaud"], n=160, what="disque")
    g.tube_shell((0, 0, zr), "z", rout + 0.024, rout - 0.004, 0.05, M["or_vif"], n=160, what="bord_disque")
    # joints décalés d'une bande à l'autre (0,18 de segment) : ils dessinent des BRAS EN SPIRALE, pas un damier (aperçu
    # r2a : des phases alternées faisaient un damier blanc et noir, lu « luxe »)
    bandes = ((E, 0.0, 1), (E, 0.18, 1), (M["emit_soft"], 0.36, 1), (M["emit2"], 0.54, 1), (M["emit2"], 0.72, 2))
    nb_ = len(bandes)
    wb = (rout - rin - 0.03 - 0.012 * nb_) / nb_
    for j, (mat, ph, pas) in enumerate(bandes):
        rm = rin + 0.012 + j * (wb + 0.012) + wb / 2
        n = 64
        for i in range(0, n, pas):
            a = TAU * (i + ph) / n
            dd = V((math.cos(a), math.sin(a), 0))
            tg = V((-dd.y, dd.x, 0))
            # vrille : la longueur du segment penche vers le centre dans le sens du disque
            tv = (tg * math.cos(0.35) - dd * math.sin(0.35)).normalized()
            nv = V((-tv.y, tv.x, 0))
            g.box(dd * rm + V((0, 0, zr + 0.022)), (TAU * rm / n * (0.9 if pas == 1 else 0.6), wb * (0.86 if pas == 1 else 0.5), 0.006), mat,
                  "flat", R=Matrix((tv, nv, V((0, 0, 1)))).transposed(), what="segment_disque")
    # ANNEAU DE PHOTONS : tube lumineux fin qui cerne l'horizon au ras du disque, et un second, plus fin, au-dessus
    g.torus((0, 0, zr + 0.02), "z", RS + 0.006, 0.02, E, n=128, m=8, what="anneau_photons")
    zp2 = zr + RS * 0.38
    g.torus((0, 0, zp2), "z", math.sqrt(max(0.0, RS * RS - (zp2 - zr) ** 2)) + 0.004, 0.008, M["emit_soft"], n=128,
            m=6, what="anneau_photons2")
    rx = RS
    # LE DISQUE (place « couronne ») : anneau plat de noir chaud, 3 bandes de segments lumineux à joints noirs
    # (lumière en orifices, jamais une plage), bord d'or, 8 bras radiaux qui le tiennent à la jupe
    rd0, rd1 = R + 0.03, r1 + 0.02
    zd = zd0 + 0.03
    g.tube_shell((0, 0, zd), "z", rd1, rd0, 0.05, M["noir_chaud"], n=96, what="disque")
    g.tube_shell((0, 0, zd), "z", rd1 + 0.022, rd1 - 0.004, 0.06, M["or_chauffe"], n=96, what="bord_disque")
    bandes = ((R + 0.09, R + 0.16, E, 24, 0.0), (R + 0.185, R + 0.255, M["emit_soft"], 24, 0.35),
              (R + 0.28, rd1 - 0.03, M["emit2"], 24, 0.7))
    for (ra, rb_, mat, n, ph) in bandes:
        rm = (ra + rb_) / 2
        for i in range(n):
            a = TAU * (i + ph) / n
            dd = V((math.cos(a), math.sin(a), 0))
            g.box(dd * rm + V((0, 0, zd + 0.027)), (TAU * rm / n * 0.72, rb_ - ra, 0.006), mat, "flat",
                  R=Matrix((V((-dd.y, dd.x, 0)), dd, V((0, 0, 1)))).transposed(), what="segment_disque")
    for i in range(8):
        a = TAU * (i + 0.5) / 8
        dd = V((math.cos(a), math.sin(a), 0))
        g.box(dd * (R + 0.01) + V((0, 0, zd - 0.045)), (0.06, 0.12, 0.05), M["noir_chaud"], "hard",
              R=Matrix((V((-dd.y, dd.x, 0)), dd, V((0, 0, 1)))).transposed(), what="bras_disque")
        g.dome(dd * (R + 0.04) + V((0, 0, zd - 0.02)), (0, 0, 1), 0.014, M["rivet"])
    # LA LAISSE : 3 GRIFFES d'or chauffé à 120° (aucune devant le masque avant), qui sortent de la sphère sous le disque,
    # l'enjambent et se referment sur son bord extérieur
    rx2 = math.sqrt(RS * RS - 0.28 ** 2)
    for th in (math.radians(30), math.radians(150), math.radians(270)):
        dd = V((math.cos(th), math.sin(th), 0))
        pe = V((rx2 * 0.97 * math.cos(th), rx2 * 0.97 * math.sin(th), zr - 0.28))
        pts = [pe, pe + dd * 0.12 + V((0, 0, 0.1)), dd * (rout - 0.1) + V((0, 0, zr + 0.14)),
               dd * (rout + 0.06) + V((0, 0, zr + 0.09)), dd * (rout + 0.07) + V((0, 0, zr - 0.02)),
               dd * (rout + 0.01) + V((0, 0, zr - 0.06))]
        griffe(g, pts, 0.12, 0.07, mat=M["or_vif"])
    for sx in (-1, 1):
        xe = sx * (H["gx"] - H["wr"] * 0.5 - 0.08)
        ye = H["recv"][0] + 0.35
        cc = [(sx * 0.3, -R - 0.3, zs + 0.15), (sx * R * 0.62, -R * 0.42, zs + 0.32), (xe, ye, H["zg"] + H["hr"] * 0.6)]
        cables(g, cc)
        conduit_or(g, [(sx * 0.6, -R - 0.3, zs + 0.1), (sx * R * 0.8, -R * 0.5, zs + 0.22),
                       (xe, ye + 0.2, H["zg"] + H["hr"] * 0.55)], 0.034)
    # DEUX canons de coupole jumelés qui SORTENT DE LA FACE AVANT de l'horizon, au-dessus du disque (ronde 2)
    for sx in (-1, 1):
        lance(g, zr, sx * 0.4, 2.3, 0.9)
    # nacelle : 2 cellules d'annihilation à fenêtres blanc-or
    bx, yb0, yb1 = c.nac[:3]
    znac = zs + H["rz"] * 0.42
    for xx in (-0.2, 0.2):
        cc = V((xx, yb0 + 0.25, znac))
        g.cyl(cc + V((0, 0, 0.09)), "z", 0.08, 0.18, M["noir_profond"], n=20, what="cellule")
        for zz in (0.03, 0.15):
            g.tube_shell(cc + V((0, 0, zz)), "z", 0.088, 0.07, 0.022, M["or_chauffe"], n=20, what="cerclage")
        fenetre(g, cc + V((0, -0.081, 0.09)), (0, -1, 0), 0.05, 0.06)
    PT.capacitors(g, (0.0, -R - 0.14, zs + H["rz"] * 0.42), 4, 1, 0.1, 0.22, M["emit2"])
    _halo(g, [(0.0, -R - 0.6, zd + 0.1)], 14.0)


def lance(g, zr, xg, L, s):
    """Canon de coupole de la ronde 2 : sa culasse est ENFONCÉE dans la face avant de l'horizon (seule la moitié avant
    en sort), collier de 3 griffes d'or vif au ras de la sphère, canon de l'époque à micro-singularité. Rien ne flotte :
    la culasse traverse la surface de la sphère."""
    M = g.M
    zc = zr + 0.4 * s
    rr_ = math.sqrt(max(0.0, RS * RS - (zc - zr) ** 2 - xg * xg))
    ys = rr_                                   # point de la surface de la sphère devant le canon
    y0, y1 = ys - 0.38 * s, ys + 0.22 * s
    PT.receiver(g, xg, y0, y1, zc - 0.15 * s, zc + 0.13 * s, 0.3 * s, mats=[M[k] for k in RECV])
    for sxx in (-1, 1):
        g.box((xg + sxx * 0.155 * s, ys + 0.1 * s, zc), (0.02, 0.06, 0.2 * s), M["or_chauffe"], "hard", what="bande")
    _gun15(g, xg, y1, zc, L, 6, 0.05 * s, 0.12 * s)
    for i in range(3):
        a = TAU * i / 3 + 0.5
        d = V((math.cos(a), 0.0, math.sin(a)))
        q = V((xg, ys - 0.02, zc)) + d * 0.2 * s
        griffe(g, [q - V((0, 0.05, 0)), q + V((0, 0.08, 0)) + d * 0.05, q + V((0, 0.16, 0)) - d * 0.02],
               0.05, 0.035, mat=M["or_vif"])


def _dans_habillage(f):
    def w(g, c, *a, **k):
        with corps.habille(g, c):
            return f(g, c, *a, **k)
    w.__name__, w.__doc__ = f.__name__, f.__doc__
    return w


socle, piece, arme, tete, masque = [_dans_habillage(_f) for _f in (socle, piece, arme, tete, masque)]
