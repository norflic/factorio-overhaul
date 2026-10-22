"""Armes d'époque (lot V3-E, époques 10 à 15), sur la lignée de l'industriel (design.py:gun_side : bras de
tourillon, culasse, moteur arrière, masque de canon, caisse d'alimentation). S'exécute DANS Blender.

Reprise du 22/10 (17 h 35), retour de l'orchestrateur sur les premiers aperçus : les 6 têtes gardaient le MÊME
faisceau de gatling et la même culasse, seules la jaquette et la bouche changeaient ; au zoom 1, on ne voyait pas
6 âges. Chaque époque a donc maintenant SA silhouette d'arme (nombre, calibre et longueur des tubes, culasse,
alimentation), lisible de dessus en pose E comme de face en pose N :

  10 Haute technologie : CARÉNAGE à pans coupés (3 panneaux gris clair patinés, fentes longitudinales), capteur
     optique sur le dos, bouts de tubes nus, frein à 3 déflecteurs ; chargeurs à cassettes et nappes de câbles.
  11 Titane : MANCHON CONIQUE effilé, 4 rangées d'AILERONS triangulaires en alliage blanc patiné (profil en
     flèche de dessus), conduits fins jumelés sur le dos, frein en pointe de flèche à évents obliques.
  12 Supraconducteurs : CANON À BOBINES : âme noire enfilée de 5 ANNEAUX chromés larges (tenus par des
     mâchoires boulonnées, segments cyan, givre), 2 conduits cryogéniques le long de l'âme, anneau-bouche chromé.
  13 Fusion : CANON À PLASMA à un seul gros tube : CHAMBRE DE CONFINEMENT sphérique en céramique au pied (tore
     magenta segmenté, cerclages de cuivre, 3 injecteurs à cœur orange), tube à AILETTES de céramique, BUSE
     évasée à cœur orange.
  14 Orbite : CANON ÉLECTROMAGNÉTIQUE à 2 RAILS parallèles, arrière enveloppé de FEUILLE D'OR froissée ceinturée,
     colliers isolants blanc cassé, cadre de bouche à capteur annulaire et balise rouge, petite PARABOLE.
  15 Légende : faisceau rotatif LOURD à 6 tubes (le canon que le Directeur Créatif a aimé, au sommet de sa
     puissance), jaquette ciselée or blanc et nacre, frein EN COURONNE de 5 grandes flèches à pierres lumineuses.

Corrections des juges (catalogue §A.6) gardées : bouche éclairée fine (< 0,03 t²), pièces au pied des tubes qui
débordent latéralement (contre la lecture « cheminée » en pose N), aucune bague blanche, cœur des faisceaux plein
(aucun trou enfermé), taille des rivets constante.
"""
import math

from mathutils import Matrix, Vector

import parts as PT
import parts2 as P2
import parts3 as P3
from kit import TAU

V = Vector


def _ring_dirs(n, phase=0.0, skip_down=-0.55):
    """Directions radiales autour de l'axe y (dans le plan xz), sans celles qui pointent vers le sol."""
    out = []
    for k in range(n):
        a = phase + TAU * k / n
        d = V((math.cos(a), 0.0, math.sin(a)))
        if d.z < skip_down:
            continue
        out.append(d)
    return out


def _Rax(d):
    """Repère (x = tangente, y = axe du canon, z = radiale d)."""
    y = V((0, 1, 0))
    return Matrix((y.cross(d).normalized(), y, d)).transposed()


def _k(rb, rr):
    """Échelle de l'arme par rapport au canon de flanc de l'ère IV (rr + rb = 0,205)."""
    return (rr + rb) / 0.205


# ------------------------------------------------------------------------------------------------
# Outils communs
# ------------------------------------------------------------------------------------------------
def tubes(g, x, y0, z, L, nb, rb, rr, phase=0.3, core=True):
    M = g.M
    for i in range(nb):
        a = phase + TAU * i / nb
        bx, bz = x + rr * math.cos(a), z + rr * math.sin(a)
        g.cyl((bx, y0 + L / 2, bz), "y", rb, L, M["gun"], n=10, what="canon")
        g.cyl((bx, y0 + L + 0.003, bz), "y", rb * 0.62, 0.008, M["void"], n=8, style="flat", what="bouche")
    if core:
        g.cyl((x, y0 + L * 0.5, z), "y", max(rr * 0.42, rr - rb * 0.7), L * 0.97, M["steel_dk"], n=12, what="axe")


def collar(g, x, yy, z, ro, ri, w, mat, nriv=6):
    M = g.M
    g.tube_shell((x, yy, z), "y", ro, ri, w, mat, n=28, what="collier")
    for d in _ring_dirs(nriv, 0.2, -0.3):
        g.dome(V((x, yy, z)) + d * (ro + 0.002), d, 0.015, M["rivet"])


def muzzle_glow(g, x, y, z, r, mat=None):
    """Anneau lumineux fin autour de la bouche (couleur d'époque, < 0,03 t²)."""
    g.tube_shell((x, y, z), "y", r, r * 0.78, 0.012, mat or g.M["emit"], n=28, what="bouche_lum")


def prism(g, x, z, ya, yb, poly, mat, style="hard", what="carenage"):
    """Prisme le long de y, de section `poly` (liste de (u, w) en x, z autour de (x, z))."""
    n = len(poly)
    vs = [(x + u, ya, z + w) for u, w in poly] + [(x + u, yb, z + w) for u, w in poly]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(mat, style, vs, fs, what)


def _oct(hw, hh, c):
    return [(-hw + c, -hh), (hw - c, -hh), (hw, -hh + c), (hw, hh - c), (hw - c, hh), (-hw + c, hh), (-hw, hh - c),
            (-hw, -hh + c)]


def _scale(poly, s):
    return [(u * s, w * s) for u, w in poly]


def dish(g, c, r, depth, mat_in, mat_out, rx=0.0, rz=0.0, horn=True):
    """Parabole (coupelle, dos, lèvre, 3 haubans, cornet) ; axe local +z tourné de rx puis rz."""
    M = g.M
    g.push(c, rz=rz, rx=rx)
    n = 24
    vs, fs = [], []
    for i in range(5):
        rr = r * i / 4
        for j in range(n):
            a = TAU * j / n
            vs.append((rr * math.cos(a), rr * math.sin(a), depth * (rr / r) ** 2))
    for i in range(4):
        for j in range(n):
            j2 = (j + 1) % n
            fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
    g._add(mat_in, "flat", vs, fs, "coupelle")
    g._add(mat_out, "smooth", [(v[0], v[1], v[2] - 0.016) for v in vs], [f[::-1] for f in fs], "coupelle_dos")
    g.torus((0, 0, depth), "z", r, 0.012, M["steel_dk"], n=32, m=6, what="levre")
    if horn:
        g.cyl((0, 0, depth + r * 0.4), "z", max(0.012, r * 0.05), r * 0.8, M["steel_dk"], n=8, what="tige")
        g.cyl((0, 0, depth + r * 0.75), "z", r * 0.13, r * 0.25, M["steel_dk"], n=10, what="cornet")
    g.pop()


def loft(g, x, z, secs, mat, style="hard", what="carenage"):
    """Volume balayé le long de y : secs = [(y, poly)] (même nombre de sommets), bouts fermés."""
    n = len(secs[0][1])
    vs = []
    for y, poly in secs:
        vs += [(x + u, y, z + w) for u, w in poly]
    fs = [tuple(range(n))[::-1]]
    m = len(secs)
    for s in range(m - 1):
        for i in range(n):
            j = (i + 1) % n
            fs.append((s * n + i, s * n + j, (s + 1) * n + j, (s + 1) * n + i))
    fs.append(tuple(range((m - 1) * n, m * n)))
    g._add(mat, style, vs, fs, what)


def _stub_tips(g, x, ya, yb, z, nb, rb, rr, phase=0.3):
    """Bouts de tubes (rosace de bouche) entre ya et yb, âme pleine."""
    M = g.M
    for i in range(nb):
        a = phase + TAU * i / nb
        bx, bz = x + rr * math.cos(a), z + rr * math.sin(a)
        g.cyl((bx, (ya + yb) / 2, bz), "y", rb, yb - ya, M["gun"], n=10, what="canon")
        g.cyl((bx, yb + 0.003, bz), "y", rb * 0.62, 0.008, M["void"], n=8, style="flat", what="bouche")
    g.cyl((x, (ya + yb) / 2, z), "y", max(rr * 0.42, rr - rb * 0.7), (yb - ya) * 0.97, M["steel_dk"], n=12,
          what="axe")


# ------------------------------------------------------------------------------------------------
# 10 Haute technologie : NACELLE CARÉNÉE FERMÉE (le faisceau est caché), radôme, antenne, déflecteurs
# ------------------------------------------------------------------------------------------------
def _gun10(g, x, y0, z, L, nb, rb, rr):
    """Troisième passe (19 h 05) : le canon n'est plus un faisceau habillé d'un manchon, c'est un CAISSON LISSE
    FERMÉ gris clair (carénage à pans coupés, nez effilé) d'où ne sortent que les 6 bouches. De dessus : un gros
    pavé clair à fentes sombres, sans bague ; de face : un écran plat à 6 trous et 3 déflecteurs."""
    M = g.M
    E = M["emit"]
    k = _k(rb, rr)
    R0 = rr + rb
    hw, hh, c = R0 + 0.13 * k, R0 + 0.06 * k, 0.12 * k
    Lf = 0.84 * L
    sec = _oct(hw, hh, c)
    loft(g, x, z, [(y0 - 0.02, _scale(sec, 0.92)), (y0 + 0.08 * k, sec), (y0 + Lf - 0.3 * k, sec),
                   (y0 + Lf, _scale(sec, 0.74))], M["jacket"], "soft", "carenage")
    # joints de panneaux (3 panneaux), fentes de ventilation longitudinales, rivets fins
    for f in (0.3, 0.58):
        yy = y0 + f * Lf
        prism(g, x, z, yy - 0.012, yy + 0.012, _scale(sec, 1.02), M["matte"], what="joint")
    for i, (a, b) in enumerate(((0.06, 0.27), (0.33, 0.55), (0.61, 0.8))):
        ya, yb = y0 + a * Lf, y0 + b * Lf
        ym, ly = (ya + yb) / 2, yb - ya
        for u in ((-hw * 0.45, hw * 0.45) if i != 1 else (-hw * 0.45, 0.0, hw * 0.45)):
            g.box((x + u, ym, z + hh + 0.002), (0.03 * k, ly, 0.006), M["void"], "flat", what="fente")
            g.box((x + u + 0.024 * k, ym, z + hh + 0.006), (0.01, ly, 0.01), M["steel_hi"], "hard", what="levre")
        for s in (-1, 1):
            g.box((x + s * (hw + 0.002), ym, z), (0.006, ly, 0.03 * k), M["void"], "flat", what="fente")
        for yy in (ya - 0.02, yb + 0.02):
            for u in (-hw + c + 0.03, hw - c - 0.03):
                g.dome((x + u, yy, z + hh), (0, 0, 1), 0.012, M["rivet"])
    # dos : nappe de câbles rouges et bleus dans une goulotte noire, antenne fouet et radôme de visée
    g.box((x, y0 + Lf * 0.4, z + hh + 0.025), (0.12 * k, Lf * 0.62, 0.035), M["matte"], "hard", what="goulotte")
    g.box((x - 0.025 * k, y0 + Lf * 0.41, z + hh + 0.046), (0.04 * k, Lf * 0.58, 0.01), M["cable_a"], "soft",
          what="nappe")
    g.box((x + 0.03 * k, y0 + Lf * 0.41, z + hh + 0.047), (0.035 * k, Lf * 0.58, 0.01), M["cable_b"], "soft",
          what="nappe")
    yr = y0 + Lf * 0.82
    g.cyl((x, yr, z + hh + 0.03), "z", 0.1 * k, 0.05, M["matte"], n=20, what="embase")
    g.sphere((x, yr, z + hh + 0.07), 0.11 * k, M["jacket"], n=24, m=12, scale=(1, 1, 0.8), what="radome")
    g.torus((x, yr, z + hh + 0.07), "z", 0.11 * k, 0.01, M["matte"], n=24, m=6, what="joint")
    g.cyl((x + 0.12 * k, y0 + Lf * 0.2, z + hh + 0.2), "z", 0.006, 0.36, M["steel_dk"], n=6, what="antenne")
    g.cyl((x + 0.12 * k, y0 + Lf * 0.2, z + hh + 0.025), "z", 0.02, 0.04, M["steel_hi"], n=8, what="embase")
    # face avant plate du carénage : bouches, voyants par 2
    yf = y0 + Lf
    _stub_tips(g, x, yf - 0.05, y0 + L, z, nb, rb, rr)
    collar(g, x, yf + (y0 + L - yf) * 0.5, z, R0 + 0.02, rr * 0.3, 0.045, M["matte"])
    for s in (-1, 1):
        g.box((x + s * hw * 0.55, yf + 0.004, z + hh * 0.45), (0.04, 0.008, 0.025), E, "flat", what="voyant")
    # frein à 3 DÉFLECTEURS plus large que la nacelle
    yb = y0 + L + 0.14 * k
    g.cyl((x, yb, z), "y", rr * 0.95, 0.28 * k, M["matte"], n=20, what="frein_noyau")
    for i, dy in enumerate((-0.1, 0.0, 0.1)):
        g.box((x, yb + dy * k, z), (2 * hw + 0.1 * k - 0.06 * i * k, 0.045 * k, 2 * hh * 0.8), M["jacket"], "hard",
              what="deflecteur")
    g.box((x, yb, z + hh * 0.8), (hw * 0.7, 0.26 * k, 0.024), M["matte"], "hard", what="longeron")
    muzzle_glow(g, x, yb + 0.145 * k, z, rr * 0.62)
    return yb + 0.145 * k


# ------------------------------------------------------------------------------------------------
# 11 Titane : LONG canon fin, manchon anguleux, grands AILERONS en flèche
# ------------------------------------------------------------------------------------------------
def _gun11(g, x, y0, z, L, nb, rb, rr):
    """Troisième passe : un canon LONG (1,25 × la longueur de l'époque) et FIN (faisceau de 6 tubes serrés, 0,27 de
    large), manchon arrière à PANS ANGULEUX en titane, et deux paires d'AILERONS en flèche en alliage clair patiné
    (empennage horizontal de 0,5 tuile d'envergure) : de dessus, une flèche empennée ; de face, une croix."""
    M = g.M
    E = M["emit"]
    k = _k(rb, rr)
    L2 = L * 1.25
    rb2, rr2 = rb * 0.72, rr * 0.6
    R0 = rr2 + rb2
    tubes(g, x, y0, z, L2, nb, rb2, rr2)
    # manchon à pans anguleux (hexagone allongé, effilé vers l'avant), plaques de titane rivetées
    Ls = 0.46 * L2
    hexs = [(0.0, 1.0), (0.87, 0.5), (0.87, -0.5), (0.0, -1.0), (-0.87, -0.5), (-0.87, 0.5)]
    r_a, r_b = R0 + 0.12 * k, R0 + 0.035
    loft(g, x, z, [(y0 - 0.02, _scale(hexs, r_a * 0.9)), (y0 + 0.1, _scale(hexs, r_a)),
                   (y0 + Ls, _scale(hexs, r_b))], M["jacket"], "hard", "manchon")
    for f in (0.25, 0.5, 0.75):
        rr_ = r_a + (r_b - r_a) * (f * Ls - 0.1) / (Ls - 0.1)
        loft(g, x, z, [(y0 + f * Ls - 0.015, _scale(hexs, rr_ * 1.04)), (y0 + f * Ls + 0.015, _scale(hexs, rr_ * 1.04))],
             M["steel_dk"], "hard", "joint")
        for (u, w) in hexs[:3] + hexs[5:]:
            g.dome((x + u * rr_ * 0.98, y0 + f * Ls + 0.04, z + w * rr_ * 0.98), (u, 0, w), 0.012, M["rivet"])
    # EMPENNAGE : 2 grands ailerons horizontaux (vers l'extérieur et vers l'intérieur) et 1 dorsal, bord d'attaque
    # en flèche ; nervure et rivets ; un 2e empennage plus petit à mi-longueur
    sx = 1.0 if x >= 0 else -1.0
    for (yy, span, chord, inner) in ((y0 + 0.36, 0.5 * k, 0.62 * k, 0.32 * k), (y0 + Ls + 0.1, 0.26 * k, 0.32 * k,
                                                                                0.2 * k)):
        r0 = (r_a + (r_b - r_a) * (yy - y0 - 0.1) / (Ls - 0.1)) if yy < y0 + 0.5 else r_b
        # pas d'aileron côté coupole : il fermait un jour avec le socle en pose N (contrôle des trous)
        for d, sp in (((V((sx, 0, 0)), span), (V((0, 0, 1)), span * 0.7)) if yy < y0 + 0.5 else ((V((0, 0, 1)), span),)):
            t = _Rax(d).col[0] * 0.026
            c = V((x, 0, z))
            # emplanture prolongée vers l'arrière (virure) sur le grand empennage : ferme le jour avec le socle
            p0 = c + d * (r0 - 0.01) + V((0, yy - (0.15 * k if yy < y0 + 0.5 else 0.0), 0))
            p1 = c + d * (r0 - 0.01) + V((0, yy + chord, 0))
            p2 = c + d * (r0 + sp) + V((0, yy + 0.02, 0))
            P2.wedge(g, p0, p1, p2, t, M["ring"], what="aileron")
            g.box(c + d * (r0 + sp * 0.45) + V((0, yy + 0.06, 0)), (0.026, 0.05, sp * 0.85), M["steel_dk"], "hard",
                  R=_Rax(d), what="nervure")
            for f in (0.3, 0.6):
                g.dome(c + d * (r0 + sp * f * 0.8) + V((0, yy + chord * (1 - f) * 0.7, 0)) + _Rax(d).col[0] * 0.014,
                       _Rax(d).col[0], 0.012, M["rivet"])
    # conduits fins jumelés en titane sur le dos (chenillard bleu-blanc en segments)
    for s in (-1, 1):
        p0 = V((x + s * 0.04 * k, y0 + Ls + 0.02, z + R0 + 0.02))
        p1 = V((x + s * 0.04 * k, y0 + L2 * 0.88, z + R0 + 0.02))
        g.tube([p0, p1], 0.014 * k, M["jacket"], n=8, what="conduit")
        for f in (0.2, 0.55, 0.9):
            g.cyl(p0.lerp(p1, f), "y", 0.022 * k, 0.025, M["ring"], n=10, style="hard", what="collier")
        g.cyl(p0.lerp(p1, 0.38) + V((0, 0, 0.004)), "y", 0.017 * k, 0.04, E, n=8, style="flat", what="segment_lum")
    for f in (0.62, 0.8):
        collar(g, x, y0 + f * L2, z, R0 + 0.018, rr2 * 0.3, 0.04, M["ring"])
    # frein EFFILÉ en pointe de flèche, évents obliques, 4 petits ailerons
    yb0 = y0 + L2
    lb = 0.4 * k
    g.tube_shell((x, yb0 + 0.02, z), "y", R0 + 0.06, rr2 * 0.4, 0.05, M["ring"], n=28, what="bague")
    g.cyl((x, yb0 + lb / 2, z), "y", R0 + 0.06, lb, M["jacket"], n=6, r2=rr2 * 0.7, style="hard", phase=math.pi / 2,
          what="frein")
    for s in (-1, 1):
        for i in range(3):
            d = V((s, 0, 0))
            g.box(V((x, yb0 + lb * (0.22 + 0.22 * i), z)) + d * (R0 + 0.04 - i * 0.045 * k),
                  (0.016, 0.07, 0.045), M["void"], "flat", R=Matrix.Rotation(s * 0.5, 3, "Z") @ _Rax(d), what="event")
    for d in _ring_dirs(4, math.pi / 4, -0.9):
        t = _Rax(d).col[0] * 0.02
        c = V((x, 0, z))
        P2.wedge(g, c + d * (R0 + 0.04) + V((0, yb0, 0)), c + d * (rr2 * 0.8) + V((0, yb0 + lb * 0.8, 0)),
                 c + d * (R0 + 0.15 * k) + V((0, yb0 + 0.01, 0)), t, M["ring"], what="aileron")
    g.cyl((x, yb0 + lb + 0.002, z), "y", rr2 * 0.6, 0.006, M["void"], n=16, style="flat", what="bouche")
    muzzle_glow(g, x, yb0 + lb + 0.004, z, rr2 * 0.75)
    return yb0 + lb


# ------------------------------------------------------------------------------------------------
# 12 Supraconducteurs : CANON À RAILS (2 rails parallèles) dans de GRANDS ANNEAUX MAGNÉTIQUES
# ------------------------------------------------------------------------------------------------
def _gun12(g, x, y0, z, L, nb, rb, rr):
    """Troisième passe : plus de faisceau rotatif. Deux RAILS noirs à arête chromée et conducteur de cuivre, sur une
    âme noire ; 4 GRANDS ANNEAUX chromés (0,8 tuile de diamètre à l'ère IV) enfilés autour, « en lévitation » : un
    jour étroit entre anneau et rails, FERMÉ par des entretoises à pinces (aucune pièce qui flotte). Culasse
    cryogénique (2 cellules givrées) ; bouche en cadre chromé à fente cyan. De dessus : une tige noire barrée de
    4 grandes barres chromées ; de face : 4 cercles concentriques autour de 2 rails."""
    M = g.M
    E = M["emit"]
    k = _k(rb, rr)
    hwr, hhr, sep = 0.05 * k, 0.17 * k, 0.15 * k
    for s in (-1, 1):
        xr = x + s * sep
        g.box((xr, y0 + L / 2, z), (2 * hwr, L, 2 * hhr), M["jacket"], "hard", what="rail")
        g.box((xr, y0 + L / 2, z + hhr + 0.004), (2 * hwr * 0.7, L * 0.99, 0.012), M["ring"], "hard", what="arete")
        g.box((xr - s * (hwr + 0.004), y0 + L / 2, z), (0.008, L * 0.97, hhr * 1.1), M["copper"], "hard",
              what="conducteur")
        for i in range(int(L * 0.9 / 0.11)):
            g.dome((xr + s * (hwr + 0.002), y0 + 0.08 + i * 0.11, z + hhr * 0.55), (s, 0, 0), 0.013, M["rivet"])
    g.box((x, y0 + L * 0.5, z - hhr * 0.25), (2 * (sep - hwr) + 0.02, L * 0.98, hhr * 1.4), M["jacket"], "hard",
          what="ame")
    g.box((x, y0 + L * 0.5, z + hhr * 0.35), (2 * (sep - hwr) - 0.01, L * 0.96, 0.01), E, "flat", what="fente_lum")
    # culasse cryogénique : 2 cellules givrées couchées sur l'arrière des rails
    for s in (-1, 1):
        c = V((x + s * (sep + hwr + 0.07 * k), y0 + 0.24 * k, z + 0.02))
        g.cyl(c, "y", 0.07 * k, 0.36 * k, M["jacket"], n=18, what="cellule")
        for t in (-0.15, 0.15):
            g.cyl(c + V((0, t * k, 0)), "y", 0.076 * k, 0.03, M["ring"], n=18, what="chapeau")
        g.tube_shell(c, "y", 0.078 * k, 0.06 * k, 0.05, M["trim"], n=18, what="givre")
    # grands anneaux magnétiques, entretoises et pinces, segments cyan sur la face avant
    ro, ri, w = 0.42 * k, 0.3 * k, 0.15 * k
    for f in (0.36, 0.53, 0.7, 0.87):
        yy = y0 + f * L
        # anneau ÉPAIS (tore chromé de 0,15 de section sur une âme annulaire) : lisible de dessus au zoom 1
        g.tube_shell((x, yy, z), "y", ro - 0.05 * k, ri, w * 0.8, M["jacket"], n=48, what="anneau_ame")
        g.torus((x, yy, z), "y", ro - 0.07 * k, 0.07 * k, M["ring"], n=48, m=12, what="anneau")
        g.tube_shell((x, yy, z), "y", ro - 0.12 * k, ri, w * 0.95, M["steel_dk"], n=36, what="jonc")
        g.cyl((x, yy, z), "y", ri + 0.01, w * 0.45, M["jacket"], n=36, what="flasque")
        for d in _ring_dirs(4, math.pi / 4, -2):
            R = _Rax(d)
            # entretoise : de l'anneau aux rails (ferme le jour de « lévitation »)
            g.box(V((x, yy, z)) + d * ((ri + 0.17 * k) / 2), (0.04 * k, w * 0.7, ri - 0.15 * k), M["steel_dk"], "hard",
                  R=R, what="entretoise")
            g.box(V((x, yy, z)) + d * (ro + 0.01), (0.06 * k, w * 1.3, 0.04), M["steel_dk"], "hard", R=R, what="pince")
            g.dome(V((x, yy, z)) + d * (ro + 0.032), d, 0.013, M["rivet"])
        for d in _ring_dirs(5, 0.0, -0.4):
            g.box(V((x, yy + w / 2 + 0.002, z)) + d * ((ri + ro) / 2), (0.06 * k, 0.004, 0.022), E, "flat", R=_Rax(d),
                  what="segment_lum")
        g.box(V((x - ro * 0.6, yy - w * 0.4, z + ro * 0.62)), (0.06, 0.03, 0.02), M["trim"], "flat", what="givre")
    # culasse magnétique dorsale et quille : plaques fines dans l'axe, de l'anneau 1 au dernier (aucun jour enfermé
    # entre les anneaux, vus de dessus comme de face)
    ya_, yb_ = y0 + 0.36 * L, y0 + 0.87 * L
    g.box((x, (ya_ + yb_) / 2, z + (hhr + ro * 0.92) / 2), (0.05 * k, yb_ - ya_, ro * 0.92 - hhr), M["jacket"], "hard",
          what="culasse_dorsale")
    g.box((x, (ya_ + yb_) / 2, z + ro * 0.9), (0.08 * k, yb_ - ya_, 0.025), M["ring"], "hard", what="arete")
    g.box((x, (ya_ + yb_) / 2, z - (hhr + ro * 0.92) / 2), (0.05 * k, yb_ - ya_ + 0.1, ro * 0.92 - hhr), M["jacket"],
          "hard", what="quille")
    if k < 0.9:
        # petit canon à rails (coupole, tourelles secondaires) : caisson d'accélérateur plein entre les anneaux
        g.box((x, (ya_ + yb_) / 2 + 0.05 * L, z + ro * 0.12), (2 * ro * 0.86, yb_ - ya_ + 0.1 * L, 2 * ro), M["jacket"],
              "hard", what="caisson")
        for f in (0.2, 0.5, 0.8):
            g.box((x, ya_ + (yb_ - ya_) * f, z + ro * 1.12), (ro * 1.2, 0.05, 0.012), M["ring"], "hard", what="plaque")
    # bouche : cadre chromé à fente cyan
    ym = y0 + L + 0.04
    ow = sep + hwr + 0.05
    g.box((x, ym, z + hhr + 0.035), (2 * ow + 0.05, 0.08, 0.05), M["ring"], "hard", what="cadre")
    g.box((x, ym, z - hhr - 0.03), (2 * ow + 0.05, 0.08, 0.04), M["ring"], "hard", what="cadre")
    for s in (-1, 1):
        g.box((x + s * ow, ym, z), (0.05, 0.08, 2 * hhr + 0.09), M["ring"], "hard", what="cadre")
    g.box((x, ym - 0.02, z), (2 * ow, 0.03, 2 * hhr + 0.06), M["jacket"], "hard", what="fond_cadre")
    g.box((x, ym + 0.042, z), (2 * (sep - hwr), 0.006, hhr * 1.4), E, "flat", what="bouche_lum")
    return ym + 0.05


# ------------------------------------------------------------------------------------------------
# 13 Fusion : CHAMBRE SPHÉRIQUE et ANNEAUX TORIQUES EMPILÉS (céramique et cuivre)
# ------------------------------------------------------------------------------------------------
def _gun13(g, x, y0, z, L, nb, rb, rr):
    """Troisième passe : canon à plasma = une grosse CHAMBRE DE CONFINEMENT sphérique en céramique au pied (cerclages
    de cuivre, injecteurs, tore segmenté), puis un empilement de 7 ANNEAUX TORIQUES épais (céramique et cuivre en
    alternance, 0,6 tuile de diamètre) sur une âme sombre, puis une BUSE évasée à cœur orange. De dessus : une boule
    suivie d'un chapelet de perles ; de face : des cercles empilés."""
    M = g.M
    E, E2 = M["emit"], M["emit2"]
    k = _k(rb, rr)
    rs = 0.3 * k
    cy = y0 + rs * 0.85
    C = V((x, cy, z))
    g.sphere(C, rs, M["jacket"], n=32, m=16, what="chambre")
    for f in (-0.55, 0.0, 0.55):
        rr_ = rs * math.sqrt(1 - f * f)
        g.torus(C + V((0, f * rs, 0)), "y", rr_ + 0.004, 0.016, M["copper"], n=36, m=6, what="cerclage")
        for d in _ring_dirs(8, 0.2, -0.4):
            g.dome(C + V((0, f * rs, 0)) + d * (rr_ + 0.018), d, 0.012, M["rivet"])
    for d in _ring_dirs(7, 0.25, -0.5):
        R = _Rax(d)
        g.box(C + V((0, -0.3 * rs, 0)) + d * (rs * 0.95 + 0.02), (0.07 * k, 0.03, 0.022), E, "flat", R=R,
              what="tore_seg")
    for dv in (V((0, -0.5, 0.86)), V((0.82, -0.5, 0.3)), V((-0.82, -0.5, 0.3))):
        d = dv.normalized()
        p = C + d * (rs + 0.06 * k)
        g.cyl(p, d, 0.045 * k, 0.16 * k, M["jacket"], n=14, what="injecteur")
        g.cyl(p - d * 0.03 * k, d, 0.052 * k, 0.02, M["copper"], n=14, style="hard", what="bague")
        g.cyl(p + d * 0.085 * k, d, 0.018 * k, 0.005, E2, n=10, style="flat", what="coeur")
    # âme et anneaux toriques empilés
    ys, ye = cy + rs * 0.8, y0 + 0.86 * L
    rC = 0.1 * k
    g.cyl((x, (ys + ye) / 2, z), "y", rC, ye - ys + 0.04, M["steel_dk"], n=20, what="ame")
    Rt, rt = 0.18 * k, 0.075 * k
    nt = 7
    for i in range(nt):
        yy = ys + rt + (ye - ys - 2 * rt) * i / (nt - 1)
        mat = M["jacket"] if i % 2 == 0 else M["copper"]
        g.torus((x, yy, z), "y", Rt, rt if i % 2 == 0 else rt * 0.8, mat, n=40, m=12, what="anneau_torique")
        g.tube_shell((x, yy, z), "y", Rt, rC - 0.005, rt * 1.2, M["steel_dk"], n=24, what="moyeu")
        if k >= 0.9:
            for d in _ring_dirs(5, 0.2 + i * 0.4, -0.3):
                g.box(V((x, yy, z)) + d * (Rt + rt * 0.98), (0.05, 0.045, 0.014), M["steel_dk"], "hard", R=_Rax(d),
                      what="bride")
        if i in (2, 4) and k >= 0.9:
            for d in _ring_dirs(4, 0.4 + i * 0.3, -0.5):
                g.box(V((x, yy, z)) + d * (Rt + rt * 0.92), (0.05 * k, 0.04, 0.008), E, "flat", R=_Rax(d),
                      what="segment_lum")
    # tirants de cuivre le long de l'empilement (relient les anneaux : aucun jour enfermé)
    for d in (V((0, 0, 1)), V((1, 0, 0)), V((-1, 0, 0))):
        p0 = V((x, ys, z)) + d * (Rt - rt * 0.4)
        p1 = V((x, ye, z)) + d * (Rt - rt * 0.4)
        g.tube([p0, p1], 0.022 * k, M["copper"], n=8, what="tirant")
    # buse évasée en céramique, ailettes, cœur orange
    lb = 0.28 * k
    g.tube_shell((x, ye + 0.02, z), "y", Rt + 0.02, rC * 0.6, 0.05, M["copper"], n=30, what="bague")
    g.cyl((x, ye + lb / 2 + 0.03, z), "y", Rt * 0.9, lb, M["jacket"], n=30, r2=Rt * 1.45, style="smooth", what="buse")
    for d in _ring_dirs(6, 0.0, -0.6):
        g.box(V((x, ye + lb / 2 + 0.03, z)) + d * (Rt * 1.22), (0.022, lb * 0.85, 0.08 * k), M["jacket"], "hard",
              R=_Rax(d), what="ailette")
    yt = ye + lb + 0.03
    g.cyl((x, yt + 0.002, z), "y", Rt * 1.3, 0.008, M["void"], n=28, style="flat", what="fond")
    g.cyl((x, yt + 0.006, z), "y", Rt * 0.55, 0.006, E2, n=20, style="flat", what="coeur")
    muzzle_glow(g, x, yt + 0.007, z, Rt * 1.38, E)
    return yt


# ------------------------------------------------------------------------------------------------
# 14 Orbite : canon à ÉMETTEUR (grande coupelle avant), corps en feuille d'or, PANNEAUX dorés repliés
# ------------------------------------------------------------------------------------------------
def _gun14(g, x, y0, z, L, nb, rb, rr):
    """Troisième passe : le canon est un ÉMETTEUR. Corps cylindrique enveloppé de feuille d'or froissée et sanglé,
    flanqué d'un PANNEAU doré replié (cadre blanc cassé, cellules bleu nuit en petites bandes), fût d'émission
    sombre à colliers isolants, et une grande COUPELLE d'émission dorée tournée vers l'avant (0,7 tuile de
    diamètre), à pointe d'émission et balise rouge. De dessus : un long corps doré terminé en T ; de face : des
    disques dorés."""
    M = g.M
    E, E2 = M["emit"], M["emit2"]
    k = _k(rb, rr)
    R0 = rr + rb
    rbody = R0 + 0.05 * k
    Lb = 0.6 * L
    nseg = 5
    for i in range(nseg):
        g.crumple((x, y0 + Lb * (i + 0.5) / nseg, z), "y", rbody, Lb / nseg - 0.015, M["jacket"], n=22, k=3,
                  amp=0.016)
    g.cyl((x, y0 + Lb / 2, z), "y", rbody - 0.02, Lb, M["steel_dk"], n=20, what="ame")
    for i in range(nseg + 1):
        yy = y0 + Lb * i / nseg
        g.tube_shell((x, yy, z), "y", rbody + 0.022, rbody - 0.03, 0.04, M["ring"], n=30, what="sangle")
        g.box((x + rbody * 0.5, yy, z + rbody * 0.84), (0.04, 0.055, 0.03), M["steel_hi"], "hard", what="boucle")
    # panneau doré replié côté extérieur (et un plus petit côté intérieur), charnières sur le corps
    sx = 1.0 if x >= 0 else -1.0
    for side, span in ((sx, 0.34 * k), (-sx, 0.14 * k)):
        x_in = x + side * (rbody + 0.01)
        x_out = x_in + side * span
        ya, yb = y0 + 0.06, y0 + Lb - 0.06
        zz = z + 0.02
        g.box(((x_in + x_out) / 2, (ya + yb) / 2, zz), (span, yb - ya, 0.035), M["ring"], "hard", what="panneau_cadre")
        nc = 4
        for j in range(nc):
            yy0 = ya + 0.03 + (yb - ya - 0.06) * j / nc
            yy1 = ya + 0.03 + (yb - ya - 0.06) * (j + 1) / nc - 0.025
            g.box(((x_in + x_out) / 2, (yy0 + yy1) / 2, zz + 0.02), (span * 0.82, yy1 - yy0, 0.006),
                  M["spec"] if j % 2 == 0 else M["jacket"], "flat", what="cellules")
        for f in (0.2, 0.8):
            g.cyl((x_in, ya + (yb - ya) * f, zz), "y", 0.03, 0.08, M["steel_dk"], n=10, what="charniere")
    # fût d'émission : tube sombre, colliers isolants blanc cassé
    yf0, yf1 = y0 + Lb, y0 + L - 0.1 * k
    rf = R0 * 0.55
    g.cyl((x, (yf0 + yf1) / 2, z), "y", rf, yf1 - yf0, M["gun"], n=20, what="fut")
    g.cyl((x, yf0 + 0.04, z), "y", rbody * 0.8, 0.1, M["steel_dk"], n=24, r2=rf, what="cone")
    for f in (0.25, 0.5, 0.75):
        yy = yf0 + (yf1 - yf0) * f
        g.tube_shell((x, yy, z), "y", rf + 0.045 * k, rf - 0.01, 0.05, M["ring"], n=24, what="collier_isolant")
    # grande coupelle d'émission tournée vers l'avant ET vers le haut (55°) : de dessus on voit son intérieur doré
    # (ellipse), de face un disque ; rotule et étrier sur le bout du fût, pointe d'émission, balise rouge
    rd = 0.34 * k
    dd = 0.12 * k
    yd = yf1 + 0.04
    g.sphere((x, yd, z), 0.07 * k, M["steel_dk"], n=16, m=8, what="rotule")
    for s in (-1, 1):
        g.box((x + s * 0.075 * k, yd, z + 0.03), (0.025, 0.1 * k, 0.14 * k), M["ring"], "hard", what="etrier")
    dish(g, (x, yd + 0.03, z + 0.05), rd, dd, M["jacket"], M["steel_dk"], rx=-0.96, horn=False)
    ax = V((0, 0.82, 0.57))
    g.cyl(V((x, yd + 0.03, z + 0.05)) + ax * (dd + 0.1 * k), ax, 0.03 * k, 0.22 * k, M["steel_dk"], n=12, what="emetteur")
    g.cyl(V((x, yd + 0.03, z + 0.05)) + ax * (dd + 0.215 * k), ax, 0.045 * k, 0.03, M["ring"], n=14, what="emetteur_tete")
    g.torus((x, yd + 0.03, z + 0.05), "y", 0.06 * k, 0.018, M["ring"], n=16, m=6, what="collier")
    g.cyl((x, yd - 0.02, z + 0.07 * k + 0.12 * k), "z", 0.02, 0.05, M["steel_dk"], n=8, what="balise_pied")
    g.cyl((x, yd - 0.02, z + 0.07 * k + 0.15 * k), "z", 0.016, 0.014, E, n=8, style="flat", what="balise")
    for s in (-1, 1):
        g.cyl((x + s * (rbody + 0.02), y0 + Lb * 0.5, z + rbody * 0.3), "z", 0.018, 0.016, E, n=8, style="flat",
              what="balise")
    g.cyl((x, yd + 0.03 + dd * 0.5, z + 0.05 + dd * 0.4), (0, 0.82, 0.57), 0.03 * k, 0.006, E2, n=12, style="flat",
          what="lentille")
    muzzle_glow(g, x, yf1 - 0.02, z, rf + 0.05 * k, E2)
    return yd + rd * 0.6


# ------------------------------------------------------------------------------------------------
# 15 Légende : faisceau lourd ciselé, frein en couronne
# ------------------------------------------------------------------------------------------------
def _gun15(g, x, y0, z, L, nb, rb, rr):
    M = g.M
    E = M["emit"]
    k = _k(rb, rr)
    rb2, rr2 = rb * 1.12, rr * 1.04
    tubes(g, x, y0, z, L, nb, rb2, rr2)
    R0 = rr2 + rb2
    rs = R0 + 0.028
    Ls = 0.52 * L
    yc = y0 + Ls / 2
    g.cyl((x, yc, z), "y", rs, Ls, M["jacket"], n=32, style="smooth", what="jaquette")
    for f in (0.03, 0.97):
        g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.028, rs - 0.01, 0.065, M["ring"], n=32, what="bague")
    for f in (0.3, 0.64):
        g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.03, rs - 0.01, 0.1, M["trim"], n=32, what="bande_nacre")
        for d in _ring_dirs(10, 0.0, -0.5):
            R = _Rax(d) @ Matrix.Rotation(math.pi / 4, 3, "Z")
            for dy in (-0.035, 0.035):
                g.box(V((x, y0 + f * Ls + dy, z)) + d * (rs + 0.03), (0.028, 0.028, 0.01), M["jacket"], "hard", R=R,
                      what="ciselure")
    for i in range(3):
        yy = y0 + Ls * (0.13 + 0.34 * i) + 0.02
        for d in _ring_dirs(9, 0.35 * (i % 2), -0.45):
            R = _Rax(d) @ Matrix.Rotation(math.pi / 4, 3, "Z")
            g.box(V((x, yy, z)) + d * (rs + 0.004), (0.05, 0.05, 0.014), M["trim"], "hard", R=R, what="ciselure")
            g.box(V((x, yy, z)) + d * (rs + 0.012), (0.024, 0.024, 0.008), M["jacket"], "hard", R=R, what="ciselure")
    for f in (0.66, 0.88):
        collar(g, x, y0 + f * L, z, R0 + 0.024, rr2 * 0.3, 0.05, M["ring"])
    # frein EN COURONNE : bague, 5 grandes flèches évasées, 5 flèches de nacre, pierres lumineuses
    yb = y0 + L + 0.06
    g.tube_shell((x, yb, z), "y", rs + 0.05, rr2 * 0.4, 0.15, M["ring"], n=36, what="couronne")
    g.tube_shell((x, yb + 0.076, z), "y", rs + 0.03, rs, 0.012, E, n=36, what="liseré_lum")
    for d in _ring_dirs(5, math.pi / 2 + math.pi / 5, -0.95):
        R = _Rax(d)
        t = R.col[0] * 0.034 * k
        c = V((x, 0, z))
        # flèche en feuille : base large (arrière), pointe évasée vers l'avant
        pa = c + d * (rs - 0.01) + V((0, yb - 0.1, 0))
        pb = c + d * (rs + 0.13 * k) + V((0, yb - 0.02, 0))
        pt = c + d * (rs + 0.27 * k) + V((0, yb + 0.32 * k, 0))
        pi_ = c + d * (rs + 0.02) + V((0, yb + 0.14 * k, 0))
        P2.wedge(g, pa, pb, pt, t * 2.2, M["ring"], what="fleche")
        P2.wedge(g, pa, pt, pi_, t * 2.2, M["ring"], what="fleche")
        P2.wedge(g, c + d * (rs - 0.02) + V((0, yb, 0)), c + d * (rs + 0.05 * k) + V((0, yb, 0)),
                 c + d * (rs + 0.06 * k) + V((0, yb + 0.2 * k, 0)), t * 1.3, M["trim"], what="fleche")
        g.sphere(c + d * (rs + 0.23 * k) + V((0, yb + 0.28 * k, 0)), 0.02 * k, E, n=10, m=6, what="pierre")
        g.dome(c + d * (rs + 0.1 * k) + V((0, yb + 0.05, 0)) + t * 0.6, R.col[0], 0.013, M["rivet"])
    muzzle_glow(g, x, yb + 0.077, z, rr2 * 0.62)
    return yb + 0.3 * k


GUNS = {10: _gun10, 11: _gun11, 12: _gun12, 13: _gun13, 14: _gun14, 15: _gun15}


def barrel(g, ep, x, y0, z, L, nb, rb, rr, Ls=None):
    """Arme complète de l'époque, de la face avant du masque (y0) vers +y. Renvoie (rayon extérieur, y de bouche)."""
    yend = GUNS[ep](g, x, y0, z, L, nb, rb, rr)
    return rr + rb + 0.028, yend


# ------------------------------------------------------------------------------------------------
# Culasse, alimentation et pièces d'époque autour du canon de flanc
# ------------------------------------------------------------------------------------------------
RECV_MATS = {10: ("matte", "jacket"), 11: ("jacket", "olive"), 12: ("jacket", "steel_dk"), 13: ("olive", "steel_dk"),
             14: ("ring", "olive"), 15: ("ochre", "olive")}


def recv_mats(g, ep):
    return [g.M[k] for k in RECV_MATS[ep]]


def breech_extra(g, ep, x, sx, y0, y1, zg, wr, hr):
    M = g.M
    E = M["emit"]
    zt = zg + hr + 0.012
    if ep == 10:
        # capot noir mat à petit écran et nappe de câbles
        g.box((x, (y0 + y1) / 2 + 0.05, zt + 0.03), (wr * 0.6, (y1 - y0) * 0.36, 0.04), M["matte"], "hard",
              what="capot")
        P3.screen(g, (x, (y0 + y1) / 2 + 0.05, zt + 0.052), (0, 0, 1), wr * 0.4, 0.07, M, E)
    elif ep == 11:
        # culasse EN FLÈCHE : capot effilé vers l'arrière (alliage blanc patiné), rivets
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
    elif ep == 12:
        # 2 bandes chromées en travers de la culasse, givre aux joints
        for f in (0.3, 0.62):
            yy = y0 + (y1 - y0) * f
            g.box((x, yy, zt + 0.01), (wr * 0.98, 0.06, 0.03), M["ring"], "hard", what="bande")
            g.box((x - wr * 0.3, yy - 0.04, zt + 0.004), (0.08, 0.025, 0.012), M["trim"], "flat", what="givre")
    elif ep == 13:
        # collecteur de cuivre à 2 injecteurs debout
        g.box((x, (y0 + y1) / 2, zt + 0.03), (wr * 0.5, (y1 - y0) * 0.5, 0.05), M["copper"], "hard",
              what="collecteur")
        for f in (0.35, 0.65):
            c = V((x, y0 + (y1 - y0) * f, zt + 0.13))
            g.cyl(c, "z", 0.04, 0.14, M["jacket"], n=14, what="injecteur")
            g.tube_shell(c + V((0, 0, 0.03)), "z", 0.047, 0.035, 0.016, M["copper"], n=14, what="bague")
            g.cyl(c + V((0, 0, 0.075)), "z", 0.02, 0.008, M["copper"], n=10, style="flat", what="embout")
    elif ep == 14:
        # couverture d'or froissée sur la culasse, sangles
        g.crumple((x, (y0 + y1) / 2, zt + 0.04), "y", wr * 0.32, (y1 - y0) * 0.7, M["jacket"], n=14, k=3,
                  amp=0.012)
        for f in (0.25, 0.75):
            g.box((x, y0 + (y1 - y0) * (0.15 + 0.7 * f), zt + 0.04), (wr * 0.7, 0.035, 0.05), M["ring"], "hard",
                  what="sangle")
    else:
        # chapeau de nacre, liseré d'or blanc et petite couronne de 5 flèches sur la culasse
        g.box((x, (y0 + y1) / 2, zt + 0.018), (wr * 0.7, (y1 - y0) * 0.5, 0.025), M["trim"], "hard", what="nacre")
        g.box((x, (y0 + y1) / 2, zt + 0.034), (wr * 0.74, 0.02, 0.012), M["jacket"], "hard", what="liseré")
        c = V((x, (y0 + y1) / 2 + 0.12, zt + 0.03))
        for kk in range(5):
            a = TAU * kk / 5
            d = V((math.cos(a), math.sin(a), 0))
            P2.wedge(g, c + d * 0.07, c + d * 0.08 + V((-d.y, d.x, 0)) * 0.03, c + d * 0.075 + V((0, 0, 0.11)),
                     V((-d.y, d.x, 0)) * 0.02, M["jacket"], what="fleche")
        g.cyl(c + V((0, 0, 0.01)), "z", 0.07, 0.02, M["jacket"], n=20, what="socle_couronne")


def ribbon(g, ctrl, w, mat, step=0.03, t=0.008):
    """Nappe de câbles plate (haute technologie) le long d'une courbe."""
    P = g.resample(g.spline(ctrl, 12), step)
    T, _ = g.frames(P)
    for i, p in enumerate(P):
        tt = T[i]
        side = tt.cross(V((0, 0, 1)))
        if side.length < 1e-3:
            side = V((1, 0, 0))
        side.normalize()
        up = side.cross(tt).normalized()
        g.box(p, (w, step * 1.05, t), mat, "flat", R=Matrix((side, tt, up)).transposed(), what="nappe")


def feed(g, ep, x, sx, H, xo):
    """Alimentation latérale : caisse (volume de la lignée) habillée par époque, goulotte ou équivalent."""
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
    mats = {10: [M["matte"], M["jacket"]], 11: [M["jacket"], M["olive"]], 12: [M["jacket"], M["steel_dk"]],
            13: [M["olive"], M["steel_dk"]], 14: [M["ring"], M["olive"]], 15: [M["olive"], M["ochre"]]}[ep]
    PT.hull(g, bx0, bx1, yb0, yb1, zb0, zb1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=mats, rivet_step=0.11)
    ztop = zb1 + 0.015
    g.hazard(PT.lift([V((bx0, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.1, zb1)), V((bx1, yb0 + bl * 0.2, zb1)),
                      V((bx0, yb0 + bl * 0.2, zb1))], 0.012), 4, t=0.01)
    chute = [(bc, yb0 + bl * 0.6, ztop + 0.005), (bc - sx * 0.05, y0 + bl * 0.55, zg + bh * 0.62),
             (x + sx * wr * 0.2, y0 + bl * 0.5, zg + hr + 0.06)]
    cw = 0.12 * wr / 0.4 + 0.04
    if ep == 10:
        # chargeurs à CASSETTES rectangulaires et NAPPES de câbles rouges et bleues
        for k in range(3):
            yy = yb0 + bl * (0.3 + 0.2 * k)
            g.box((bc, yy, ztop + 0.05), (bw * 0.8, bl * 0.15, 0.1), M["jacket"], "hard", what="cassette")
            g.box((bc + sx * bw * 0.28, yy, ztop + 0.102), (0.05, bl * 0.08, 0.006), E if k != 1 else M["amber"],
                  "flat", what="voyant")
            g.box((bc - sx * bw * 0.1, yy, ztop + 0.101), (bw * 0.3, bl * 0.1, 0.004), M["matte"], "flat",
                  what="etiquette")
        ribbon(g, [(bc - sx * 0.04, yb0 + bl * 0.85, ztop + 0.09), (bc - sx * 0.1, y0 + bl * 0.75, zg + bh * 0.7),
                   (x + sx * wr * 0.25, y0 + bl * 0.62, zg + hr + 0.05)], 0.06, M["cable_a"])
        ribbon(g, [(bc + sx * 0.02, yb0 + bl * 0.85, ztop + 0.1), (bc - sx * 0.04, y0 + bl * 0.8, zg + bh * 0.75),
                   (x + sx * wr * 0.32, y0 + bl * 0.68, zg + hr + 0.06)], 0.05, M["cable_b"])
    elif ep == 11:
        P2.feed_chute(g, chute, cw, M)
        for k in range(2):
            yy = yb0 + bl * (0.35 + 0.35 * k)
            P2.wedge(g, V((bc, yy - 0.1, ztop)), V((bc, yy + 0.08, ztop)), V((bc, yy - 0.08, ztop + 0.13)),
                     V((0.02, 0, 0)), M["ring"], what="aileron")
        P3.lamp_group(g, (bc + sx * bw * 0.32, yb0 + bl * 0.4, ztop - 0.005), (0, 1, 0), (0, 0, 1), E, M, n=2,
                      shapes=("fente", "rond"))
    elif ep == 12:
        # CELLULES CRYOGÉNIQUES cylindriques couchées, chapeaux chromés, givre
        for k, yy in enumerate((yb0 + bl * 0.32, yb0 + bl * 0.68)):
            c = V((bc, yy, ztop + 0.07))
            g.cyl(c, "x", 0.07, bw * 0.9, M["jacket"], n=20, what="cellule")
            for s in (-1, 1):
                g.cyl(c + V((s * bw * 0.45, 0, 0)), "x", 0.075, 0.03, M["ring"], n=20, what="chapeau")
            g.tube_shell(c, "x", 0.078, 0.06, 0.03, M["trim"], n=20, what="givre")
            g.box(c + V((0, -0.05, 0.05)), (0.05, 0.02, 0.006), E, "flat", what="voyant")
        g.tube([V((bc, yb0 + bl * 0.5, ztop + 0.08)), V((x + sx * wr * 0.35, yb0 + bl * 0.6, zg + hr + 0.07)),
                V((x + sx * wr * 0.2, y1 - 0.12, zg + hr + 0.04))], 0.026, M["pipe"], n=10, what="cryo")
    elif ep == 13:
        # INJECTEURS debout (céramique, bagues de cuivre) reliés à la chambre de confinement par du cuivre annelé
        for k in range(3):
            yy = yb0 + bl * (0.22 + 0.28 * k)
            c = V((bc, yy, ztop + 0.09))
            g.cyl(c, "z", 0.045, 0.18, M["jacket"], n=16, what="injecteur")
            for zz in (-0.06, 0.0, 0.06):
                g.tube_shell(c + V((0, 0, zz)), "z", 0.052, 0.04, 0.018, M["copper"], n=16, what="bague")
            g.cyl(c + V((0, 0, 0.1)), "z", 0.025, 0.03, M["emit2"], n=10, style="flat", what="coeur")
        rs = H["rb"] + H["rr"] + 0.07 * _k(H["rb"], H["rr"])
        g.hose([(bc, yb0 + bl * 0.75, ztop + 0.12), (x + sx * wr * 0.3, yb0 + bl * 0.85, zg + hr + 0.1),
                (x + sx * wr * 0.15, y1 - 0.02, zg + hr + 0.08), (x, y1 + rs * 0.6, zg + rs * 0.85)], 0.03,
               M["copper"], step=0.03)
    elif ep == 14:
        # BRAS ARTICULÉ de chargement à vérin, coffre blanc cassé, plaque de feuille d'or
        pa = V((bc, yb0 + bl * 0.55, ztop + 0.02))
        pm = V((bc - sx * 0.04, y0 + bl * 0.45, zg + hr + 0.32))
        pb = V((x + sx * wr * 0.2, y0 + bl * 0.4, zg + hr + 0.06))
        for (p, q) in ((pa, pm), (pm, pb)):
            d = q - p
            g.cyl((p + q) / 2, d, 0.03, d.length, M["ring"], n=12, what="bras")
        for p in (pa, pm, pb):
            g.cyl(p, (1, 0, 0), 0.045, 0.07, M["steel_dk"], n=14, what="articulation")
        PT.piston(g, tuple(pa + V((0, 0.1, 0))), tuple(pm + V((0, 0.06, -0.08))), 0.018)
        g.crumple((bc, yb0 + bl * 0.25, ztop + 0.03), "x", 0.05, bw * 0.8, M["jacket"], n=12, k=3, amp=0.01)
        P2.feed_chute(g, [(bc, yb0 + bl * 0.75, ztop + 0.005), (bc - sx * 0.05, y0 + bl * 0.7, zg + bh * 0.62),
                          (x + sx * wr * 0.3, y0 + bl * 0.62, zg + hr + 0.06)], cw * 0.8, M)
    else:
        # CELLULE D'ÉNERGIE à couronne lumineuse sur la caisse
        c = V((bc, yb0 + bl * 0.3, ztop))
        g.cyl(c + V((0, 0, 0.08)), "z", 0.07, 0.16, M["steel_dk"], n=20, what="cellule")
        for zz in (0.03, 0.13):
            g.tube_shell(c + V((0, 0, zz)), "z", 0.078, 0.06, 0.02, M["jacket"], n=20, what="cerclage")
        g.tube_shell(c + V((0, 0, 0.165)), "z", 0.055, 0.042, 0.016, E, n=20, what="couronne_lum")
        for k in range(5):
            a = TAU * k / 5
            d = V((math.cos(a), math.sin(a), 0))
            P2.wedge(g, c + d * 0.06 + V((0, 0, 0.16)), c + d * 0.07 + V((0, 0, 0.16)),
                     c + d * 0.065 + V((0, 0, 0.23)), V((-d.y, d.x, 0)) * 0.018, M["jacket"], what="fleche")
        P2.feed_chute(g, [(bc, yb0 + bl * 0.7, ztop + 0.005), (bc - sx * 0.05, y0 + bl * 0.65, zg + bh * 0.62),
                          (x + sx * wr * 0.25, y0 + bl * 0.55, zg + hr + 0.06)], cw, M)
    if ep in (10, 12, 13, 14, 15):
        P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                      E, M, n=2 if ep < 13 else 3, shapes=("rond", "carre", "fente"))
    return bc


def mantle_extra(g, ep, x, y1, zg, wr, hr):
    """Pièces du masque de canon : capteur optique (10)."""
    M = g.M
    if ep == 10:
        c = V((x + wr * 0.45, y1 + 0.02, zg + hr * 1.35 + 0.06))
        g.box(c, (0.12, 0.12, 0.1), M["matte"], "hard", what="capteur")
        g.cyl(c + V((0, 0.07, 0.0)), "y", 0.035, 0.03, M["steel_hi"], n=14, what="capteur_bague")
        g.cyl(c + V((0, 0.088, 0.0)), "y", 0.025, 0.006, M["emit"], n=12, style="flat", what="lentille")
        g.box(c + V((0, -0.02, 0.06)), (0.08, 0.06, 0.02), M["jacket"], "hard", what="visiere")
