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
        for k in range(3):
            a = TAU * k / 3
            g.cyl((r * 0.5 * math.cos(a), r * 0.5 * math.sin(a), depth + r * 0.35),
                  (-math.cos(a), -math.sin(a), 1.4), 0.006, r * 0.95, M["steel_dk"], n=6, what="hauban")
        g.cyl((0, 0, depth + r * 0.75), "z", r * 0.13, r * 0.25, M["steel_dk"], n=10, what="cornet")
    g.pop()


# ------------------------------------------------------------------------------------------------
# 10 Haute technologie : carénage, capteur, déflecteurs
# ------------------------------------------------------------------------------------------------
def _gun10(g, x, y0, z, L, nb, rb, rr):
    M = g.M
    E = M["emit"]
    k = _k(rb, rr)
    R0 = rr + rb
    tubes(g, x, y0, z, L, nb, rb, rr)
    Lf = 0.66 * L
    hw, hh, c = R0 + 0.085 * k, R0 + 0.04 * k, 0.08 * k
    sec = _oct(hw, hh, c)
    segs = ((0.0, 0.31), (0.33, 0.64), (0.66, 1.0))
    prism(g, x, z, y0, y0 + Lf, _scale(sec, 0.95), M["matte"], what="ame_carenage")
    for a, b in segs:
        prism(g, x, z, y0 + a * Lf, y0 + b * Lf, sec, M["jacket"])
    prism(g, x, z, y0 - 0.02, y0 + 0.04, _scale(sec, 1.07), M["matte"], what="cloison")
    prism(g, x, z, y0 + Lf - 0.01, y0 + Lf + 0.05, _scale(sec, 1.07), M["matte"], what="cloison")
    for i, (a, b) in enumerate(segs):
        ya, yb = y0 + a * Lf + 0.06, y0 + b * Lf - 0.06
        ym, ly = (ya + yb) / 2, yb - ya
        for u in (-hw * 0.38, hw * 0.38):
            g.box((x + u, ym, z + hh + 0.002), (0.034 * k, ly, 0.006), M["void"], "flat", what="fente")
            g.box((x + u + 0.026 * k, ym, z + hh + 0.006), (0.012, ly, 0.012), M["steel_hi"], "hard", what="levre")
        for s in (-1, 1):
            g.box((x + s * (hw + 0.002), ym, z + 0.01), (0.006, ly, 0.028 * k), M["void"], "flat", what="fente")
            g.box((x + s * (hw + 0.006), ym, z + 0.01 + 0.024 * k), (0.012, ly, 0.012), M["steel_hi"], "hard",
                  what="levre")
        for yy in (y0 + a * Lf + 0.025, y0 + b * Lf - 0.025):
            for u in (-hw + c + 0.025, hw - c - 0.025):
                g.dome((x + u, yy, z + hh), (0, 0, 1), 0.012, M["rivet"])
    # capteur optique sur le dos (boîtier noir mat, lentille bleue vers l'avant, visière)
    yp = y0 + Lf * 0.8
    g.box((x, yp, z + hh + 0.05 * k), (0.15 * k, 0.2 * k, 0.09 * k), M["matte"], "hard", what="capteur")
    g.cyl((x, yp + 0.11 * k, z + hh + 0.05 * k), "y", 0.04 * k, 0.03, M["steel_hi"], n=14, what="bague")
    g.cyl((x, yp + 0.127 * k, z + hh + 0.05 * k), "y", 0.028 * k, 0.006, E, n=12, style="flat", what="lentille")
    g.box((x, yp + 0.02, z + hh + 0.1 * k), (0.17 * k, 0.16 * k, 0.014), M["jacket"], "hard", what="visiere")
    ribbon(g, [(x - 0.03 * k, yp - 0.1 * k, z + hh + 0.02), (x - 0.05 * k, y0 + Lf * 0.45, z + hh + 0.014),
               (x - 0.06 * k, y0 + 0.02, z + hh + 0.03)], 0.045 * k, M["cable_a"])
    ribbon(g, [(x + 0.04 * k, yp - 0.1 * k, z + hh + 0.022), (x + 0.06 * k, y0 + Lf * 0.45, z + hh + 0.016),
               (x + 0.07 * k, y0 + 0.02, z + hh + 0.032)], 0.035 * k, M["cable_b"])
    # bouts de tubes nus : un collier noir mat à 2 voyants
    yc = y0 + Lf + (L - Lf) * 0.55
    collar(g, x, yc, z, R0 + 0.022, rr * 0.3, 0.05, M["matte"])
    for s in (-1, 1):
        g.box((x + s * (R0 + 0.024) * 0.7, yc, z + (R0 + 0.024) * 0.71), (0.03, 0.03, 0.006), E, "flat",
              R=_Rax(V((s * 0.7, 0, 0.71)).normalized()), what="voyant")
    # frein à 3 DÉFLECTEURS
    yb = y0 + L + 0.15 * k
    g.cyl((x, yb, z), "y", rr * 0.95, 0.3 * k, M["matte"], n=20, what="frein_noyau")
    for i, dy in enumerate((-0.11, 0.0, 0.11)):
        g.box((x, yb + dy * k, z), (2 * hw + 0.24 * k - 0.05 * i * k, 0.05 * k, 2 * hh * 0.95), M["jacket"], "hard",
              what="deflecteur")
        g.box((x, yb + dy * k - 0.03 * k, z + hh * 0.95), (2 * hw + 0.2 * k - 0.05 * i * k, 0.012, 0.012),
              M["steel_hi"], "hard", what="arete")
    g.box((x, yb, z + hh * 0.9), (hw * 0.8, 0.27 * k, 0.026), M["steel_dk"], "hard", what="longeron")
    muzzle_glow(g, x, yb + 0.155 * k, z, rr * 0.62)
    return yb + 0.155 * k


# ------------------------------------------------------------------------------------------------
# 11 Titane : manchon conique, ailerons en flèche, frein effilé
# ------------------------------------------------------------------------------------------------
def _gun11(g, x, y0, z, L, nb, rb, rr):
    M = g.M
    E = M["emit"]
    k = _k(rb, rr)
    R0 = rr + rb
    tubes(g, x, y0, z, L, nb, rb, rr)
    Ls = 0.7 * L
    rbk, rfr = R0 + 0.07 * k, R0 + 0.014

    def rad(y):
        return rbk + (rfr - rbk) * (y - y0) / Ls
    g.cyl((x, y0 + Ls / 2, z), "y", rbk, Ls, M["jacket"], n=32, r2=rfr, style="smooth", what="manchon")
    for d in _ring_dirs(8, TAU / 16, -0.5):
        g.box(V((x, y0 + Ls / 2, z)) + d * ((rbk + rfr) / 2 + 0.002), (0.012, Ls * 0.96, 0.008), M["steel_dk"], "hard",
              R=_Rax(d) @ Matrix.Rotation(math.atan2(rbk - rfr, Ls), 3, "X"), what="joint")
    nrow = 4
    for i in range(nrow):
        ya = y0 + 0.05 + (Ls - 0.1) * i / nrow
        yb = ya + (Ls - 0.1) / nrow * 0.9
        hf = (0.32 - 0.05 * i) * k
        r0 = rad(ya)
        g.tube_shell((x, ya + 0.015, z), "y", r0 + 0.018, r0 - 0.02, 0.034, M["ring"], n=32, what="pied_ailerons")
        for a in (0.0, math.pi / 3, 2 * math.pi / 3, math.pi):
            d = V((math.cos(a), 0.0, math.sin(a)))
            if x * d.x < -0.3 * abs(x):
                continue    # pas d'aileron tourné vers la coupole (il fermerait un jour avec le masque)
            t = _Rax(d).col[0] * 0.024
            c = V((x, 0, z))
            p0 = c + d * (r0 - 0.005) + V((0, ya, 0))
            p1 = c + d * (rad(yb) - 0.005) + V((0, yb, 0))
            p2 = c + d * (r0 + hf) + V((0, ya + 0.02, 0))
            P2.wedge(g, p0, p1, p2, t, M["ring"], what="aileron")
            g.box(c + d * (r0 + hf * 0.5) + V((0, ya + 0.03, 0)), (0.03, 0.04, hf * 0.9), M["steel_dk"], "hard",
                  R=_Rax(d), what="nervure")
            g.dome(c + d * (r0 + 0.03) + V((0, ya + 0.06, 0)) + _Rax(d).col[0] * 0.016, _Rax(d).col[0], 0.012,
                   M["rivet"])
    # conduits fins jumelés en titane sur le dos, colliers d'alliage blanc, segments bleu-blanc (chenillard)
    for s in (-1, 1):
        p0 = V((x + s * 0.05 * k, y0 + 0.02, z + rbk + 0.02))
        p1 = V((x + s * 0.05 * k, y0 + Ls * 0.92, z + rfr + 0.02))
        g.tube([p0, p1], 0.016 * k, M["jacket"], n=8, what="conduit")
        for f in (0.15, 0.5, 0.85):
            q = p0.lerp(p1, f)
            g.cyl(q, "y", 0.026 * k, 0.025, M["ring"], n=10, style="hard", what="collier")
        for f in (0.3, 0.68):
            q = p0.lerp(p1, f)
            g.cyl(q + V((0, 0, 0.004)), "y", 0.019 * k, 0.04, E, n=8, style="flat", what="segment_lum")
    collar(g, x, y0 + Ls + (L - Ls) * 0.5, z, R0 + 0.02, rr * 0.3, 0.045, M["ring"])
    # frein EFFILÉ en pointe de flèche : tronc de cône long, évents obliques, 4 ailerons à la base
    yb0 = y0 + L
    lb = 0.36 * k
    g.tube_shell((x, yb0 + 0.02, z), "y", R0 + 0.05, rr * 0.4, 0.05, M["ring"], n=28, what="bague")
    g.cyl((x, yb0 + lb / 2, z), "y", R0 + 0.05, lb, M["jacket"], n=28, r2=rr * 0.7, style="smooth", what="frein")
    for s in (-1, 1):
        for i in range(3):
            d = V((s, 0, 0))
            g.box(V((x, yb0 + lb * (0.25 + 0.22 * i), z)) + d * (R0 + 0.04 - i * 0.05 * k),
                  (0.016, 0.075, 0.05), M["void"], "flat", R=Matrix.Rotation(s * 0.5, 3, "Z") @ _Rax(d), what="event")
    for d in _ring_dirs(4, math.pi / 4, -0.9):
        t = _Rax(d).col[0] * 0.022
        c = V((x, 0, z))
        P2.wedge(g, c + d * (R0 + 0.04) + V((0, yb0, 0)), c + d * (rr * 0.8) + V((0, yb0 + lb * 0.8, 0)),
                 c + d * (R0 + 0.16 * k) + V((0, yb0 + 0.01, 0)), t, M["ring"], what="aileron")
    g.cyl((x, yb0 + lb + 0.002, z), "y", rr * 0.55, 0.006, M["void"], n=16, style="flat", what="bouche")
    muzzle_glow(g, x, yb0 + lb + 0.004, z, rr * 0.68)
    return yb0 + lb


# ------------------------------------------------------------------------------------------------
# 12 Supraconducteurs : canon à bobines (anneaux chromés)
# ------------------------------------------------------------------------------------------------
def _gun12(g, x, y0, z, L, nb, rb, rr):
    M = g.M
    E = M["emit"]
    k = _k(rb, rr)
    R0 = rr + rb
    tubes(g, x, y0, z, L, nb, rb, rr)
    g.cyl((x, y0 + 0.455 * L, z), "y", R0 + 0.012, 0.91 * L, M["jacket"], n=28, style="smooth", what="ame")
    for d in _ring_dirs(6, 0.0, -0.4):
        g.box(V((x, y0 + 0.455 * L, z)) + d * (R0 + 0.014), (0.014, 0.88 * L, 0.008), M["steel_dk"], "hard",
              R=_Rax(d), what="nervure")
    ro, ri, w = R0 + (0.2 if k >= 1.0 else 0.11) * k, R0 - 0.005, 0.1 * k
    # étage d'accélération à l'AVANT (5 anneaux) ; à l'arrière, colliers cryogéniques chromés plus étroits
    fs = (0.5, 0.6, 0.7, 0.8, 0.9) if k >= 1.0 else (0.16, 0.33, 0.5, 0.67, 0.84)
    if k >= 1.0:
        for f in (0.12, 0.24, 0.36):
            collar(g, x, y0 + f * L, z, R0 + 0.04 * k, ri, 0.05, M["ring"])
            g.box(V((x - (R0 + 0.03), y0 + f * L - 0.035, z - 0.03)), (0.03, 0.025, 0.04), M["trim"], "flat",
                  what="givre")
    for f in fs:
        yy = y0 + f * L
        g.tube_shell((x, yy, z), "y", ro, ri, w, M["ring"], n=44, what="anneau")
        g.torus((x, yy, z), "y", ro, 0.011, M["ring"], n=44, m=6, what="jonc")
        g.tube_shell((x, yy, z), "y", R0 + 0.05 * k, ri, w * 1.5, M["steel_dk"], n=28, what="moyeu")
        for d in _ring_dirs(4, math.pi / 4, -2):
            R = _Rax(d)
            g.box(V((x, yy, z)) + d * (ro + 0.012), (0.05 * k, w * 1.35, 0.05), M["steel_dk"], "hard", R=R,
                  what="machoire")
            g.dome(V((x, yy, z)) + d * (ro + 0.038), d, 0.013, M["rivet"])
        for d in _ring_dirs(4, 0.0, -0.4):
            R = _Rax(d)
            g.box(V((x, yy + w / 2 + 0.002, z)) + d * ((ri + ro) / 2 + 0.02 * k), (0.05 * k, 0.004, 0.018), E,
                  "flat", R=R, what="segment_lum")
        for s in (-1, 1):
            g.box(V((x + s * (ro - 0.03), yy, z - 0.04)), (0.03, w * 1.1, 0.05), M["trim"], "flat", what="givre")
    # 2 conduits cryogéniques le long de l'âme (mousse givrée), colliers chromés
    # quille de guidage sous l'âme (entre les anneaux : aucun jour enfermé)
    g.box((x, y0 + (fs[0] + fs[-1]) / 2 * L, z - (ro - 0.02) / 2), (0.05 * k, (fs[-1] - fs[0]) * L + w, ro - 0.02),
          M["steel_dk"], "hard", what="quille")
    g.box((x, y0 + (fs[0] + fs[-1]) / 2 * L, z - ro * 0.55), (0.09 * k, (fs[-1] - fs[0]) * L + w * 0.6, ro * 0.9),
          M["steel_dk"], "hard", what="quille")
    for s in (-1, 1):
        d = V((s * 0.62, 0, 0.78))
        p0 = V((x, y0 + 0.03, z)) + d * (R0 + 0.045 * k)
        p1 = V((x, y0 + 0.92 * L, z)) + d * (R0 + 0.045 * k)
        g.tube([p0, p1], 0.024 * k, M["pipe"], n=10, what="cryo")
        for f in (0.08, 0.92):
            g.hose([tuple(p0.lerp(p1, f - 0.03)), tuple(p0.lerp(p1, f + 0.03))], 0.03 * k, M["ring"], step=0.02)
    # ANNEAU-BOUCHE chromé à fente cyan
    yc = y0 + L + 0.09 * k
    g.tube_shell((x, yc, z), "y", R0 + 0.075 * k, rr * 0.42, 0.17 * k, M["ring"], n=36, what="anneau_bouche")
    g.tube_shell((x, yc, z), "y", R0 + 0.08 * k, R0 + 0.05 * k, 0.02, E, n=36, what="fente_lum")
    muzzle_glow(g, x, yc + 0.087 * k, z, rr * 0.6)
    return yc + 0.085 * k


# ------------------------------------------------------------------------------------------------
# 13 Fusion : chambre de confinement, tube à ailettes de céramique, buse
# ------------------------------------------------------------------------------------------------
def _gun13(g, x, y0, z, L, nb, rb, rr):
    M = g.M
    E, E2 = M["emit"], M["emit2"]
    k = _k(rb, rr)
    R0 = rr + rb
    rs = R0 + 0.07 * k
    cy = y0 + rs * 0.92
    C = V((x, cy, z))
    g.sphere(C, rs, M["jacket"], n=32, m=16)
    for f in (-0.5, 0.5):
        rr_ = rs * math.sqrt(1 - f * f)
        g.torus(C + V((0, f * rs, 0)), "y", rr_ + 0.004, 0.014, M["copper"], n=36, m=6, what="cerclage")
        for d in _ring_dirs(8, 0.2, -0.4):
            g.dome(C + V((0, f * rs, 0)) + d * (rr_ + 0.016), d, 0.012, M["rivet"])
    # tore magenta SEGMENTÉ autour de la chambre (plan perpendiculaire à l'axe)
    for d in _ring_dirs(9, 0.0, -0.6):
        R = _Rax(d)
        g.box(C + d * (rs + 0.03), (TAU * (rs + 0.03) / 9 * 0.82, 0.03, 0.026), E, "flat", R=R, what="tore_seg")
        g.box(C + d * (rs + 0.008) + R.col[0] * 0.05 * k, (0.024, 0.05, 0.05), M["steel_dk"], "hard", R=R,
              what="tore_patte")
    # 3 INJECTEURS radiaux sur l'hémisphère arrière (céramique, bagues de cuivre, cœur orange)
    for dv in (V((0, -0.45, 0.89)), V((0.8, -0.45, 0.4)), V((-0.8, -0.45, 0.4))):
        d = dv.normalized()
        p = C + d * (rs + 0.07 * k)
        g.cyl(p, d, 0.05 * k, 0.18 * k, M["jacket"], n=16, what="injecteur")
        for t in (-0.05, 0.03):
            g.cyl(p + d * t * k, d, 0.058 * k, 0.02, M["copper"], n=16, style="hard", what="bague")
        g.cyl(p + d * 0.095 * k, d, 0.03 * k, 0.02, M["copper"], n=12, what="embout")
        g.cyl(p + d * 0.107 * k, d, 0.02 * k, 0.005, E2, n=10, style="flat", what="coeur")
    for s in (-1, 1):
        d = V((s * 0.85, 0.3, 0.42)).normalized()
        g.cyl(C + d * rs, d, 0.05 * k, 0.03, M["steel_dk"], n=14, what="hublot")
        g.cyl(C + d * (rs + 0.016), d, 0.034 * k, 0.005, M["void"], n=12, style="flat", what="hublot_verre")
    # tube unique, gros calibre, à AILETTES DE CÉRAMIQUE ; bandes de cuivre à segments magenta
    rB = R0 * 0.78
    ys, ye = cy + rs * 0.75, y0 + 0.84 * L
    g.cyl((x, (ys + ye) / 2, z), "y", rB, ye - ys, M["steel_dk"], n=28, what="tube_plasma")
    bands = (ys + (ye - ys) * 0.36, ys + (ye - ys) * 0.7)
    yy = ys + 0.07
    while yy < ye - 0.06:
        if all(abs(yy - b) > 0.06 for b in bands):
            g.tube_shell((x, yy, z), "y", rB + 0.08 * k, rB - 0.01, 0.024, M["jacket"], n=30, what="ailette")
        yy += 0.07
    for b in bands:
        g.tube_shell((x, b, z), "y", rB + 0.095 * k, rB - 0.01, 0.06, M["copper"], n=30, what="bande")
        for d in _ring_dirs(3, 0.5, -0.4):
            g.box(V((x, b, z)) + d * (rB + 0.097 * k), (0.045 * k, 0.03, 0.006), E, "flat", R=_Rax(d),
                  what="segment_lum")
    for s in (-1, 1):
        # conduits de céramique jumelés de la chambre à la buse
        p0 = V((x + s * (rB + 0.092 * k), ys - 0.05, z + 0.03))
        p1 = V((x + s * (rB + 0.092 * k), ye + 0.02, z + 0.03))
        g.tube([p0, p1], 0.02 * k, M["copper"], n=8, what="conduit")
        for f in (0.1, 0.5, 0.9):
            g.cyl(p0.lerp(p1, f), "y", 0.03 * k, 0.03, M["jacket"], n=10, style="hard", what="collier")
    # BUSE évasée en céramique, ailettes, cœur orange au fond
    lb = 0.3 * k
    yb = ye + lb / 2
    g.tube_shell((x, ye, z), "y", rB + 0.05 * k, rB * 0.6, 0.05, M["copper"], n=30, what="bague")
    g.cyl((x, yb, z), "y", rB * 1.05, lb, M["jacket"], n=30, r2=rB * 1.8, style="smooth", what="buse")
    for d in _ring_dirs(6, 0.0, -0.6):
        g.box(V((x, yb + 0.01, z)) + d * (rB * 1.42), (0.022, lb * 0.85, 0.1 * k), M["jacket"], "hard",
              R=_Rax(d), what="ailette")
    g.cyl((x, ye + lb + 0.002, z), "y", rB * 1.62, 0.008, M["void"], n=28, style="flat", what="fond")
    g.cyl((x, ye + lb + 0.006, z), "y", rB * 0.72, 0.006, E2, n=20, style="flat", what="coeur")
    muzzle_glow(g, x, ye + lb + 0.007, z, rB * 1.7, E)
    return ye + lb


# ------------------------------------------------------------------------------------------------
# 14 Orbite : canon électromagnétique à 2 rails, couverture d'or, cadre de bouche
# ------------------------------------------------------------------------------------------------
def _gun14(g, x, y0, z, L, nb, rb, rr):
    M = g.M
    E, E2 = M["emit"], M["emit2"]
    k = _k(rb, rr)
    R0 = rr + rb
    hwr, hhr, sep = 0.055 * k, R0 * 0.82, R0 * 0.56
    for s in (-1, 1):
        xr = x + s * sep
        g.box((xr, y0 + L / 2, z), (2 * hwr, L, 2 * hhr), M["gun"], "hard", what="rail")
        g.box((xr, y0 + L / 2, z + hhr + 0.004), (2 * hwr * 0.6, L * 0.99, 0.01), M["steel_hi"], "hard",
              what="arete")
        g.box((xr - s * (hwr + 0.004), y0 + L / 2, z), (0.008, L * 0.99, hhr * 1.2), M["copper"], "hard",
              what="conducteur")
        for i in range(int(L * 0.48 / 0.09)):
            g.dome((xr, y0 + L * 0.52 + 0.045 + i * 0.09, z + hhr + 0.01), (0, 0, 1), 0.013, M["rivet"])
            g.dome((xr + s * (hwr + 0.002), y0 + L * 0.52 + 0.045 + i * 0.09, z + hhr * 0.4), (s, 0, 0), 0.013,
                   M["rivet"])
    g.box((x, y0 + L * 0.5, z - hhr * 0.2), (2 * (sep - hwr) + 0.02, L * 0.98, hhr * 1.5), M["matte"], "hard",
          what="ame")
    # couverture thermique en FEUILLE D'OR froissée sur l'arrière, sangles blanc cassé à boucles
    Lb = 0.52 * L
    rbl = math.hypot(sep + hwr, hhr) + 0.03
    nseg = 4
    for i in range(nseg):
        g.crumple((x, y0 + Lb * (i + 0.5) / nseg, z), "y", rbl, Lb / nseg - 0.02, M["jacket"], n=20, k=3, amp=0.016)
    for i in range(nseg + 1):
        yy = y0 + Lb * i / nseg
        g.tube_shell((x, yy, z), "y", rbl + 0.022, rbl - 0.03, 0.04, M["ring"], n=30, what="sangle")
        g.box((x - rbl * 0.6, yy, z + rbl * 0.8), (0.045, 0.055, 0.03), M["steel_hi"], "hard", what="boucle")
    # colliers isolants en cadre (blanc cassé), lentille bleue
    for f in (0.6, 0.7, 0.8, 0.9):
        yy = y0 + f * L
        ow = sep + hwr + 0.03
        g.box((x, yy, z + hhr + 0.025), (2 * ow + 0.04, 0.055, 0.04), M["ring"], "hard", what="collier_isolant")
        g.box((x, yy, z - hhr - 0.02), (2 * ow + 0.04, 0.055, 0.03), M["ring"], "hard", what="collier_isolant")
        for s in (-1, 1):
            g.box((x + s * ow, yy, z), (0.04, 0.055, 2 * hhr + 0.06), M["ring"], "hard", what="collier_isolant")
            g.dome((x + s * (ow + 0.02), yy, z + hhr * 0.5), (s, 0, 0), 0.013, M["rivet"])
        g.cyl((x, yy, z + hhr + 0.05), "z", 0.018, 0.012, M["spec"], n=10, style="flat", what="lentille")
    # cadre de bouche à CAPTEUR ANNULAIRE, balise rouge, lueur bleue entre les rails
    ym = y0 + L + 0.04
    ow = sep + hwr + 0.05
    g.box((x, ym, z + hhr + 0.04), (2 * ow + 0.06, 0.08, 0.05), M["steel_dk"], "hard", what="cadre")
    g.box((x, ym, z - hhr - 0.03), (2 * ow + 0.06, 0.08, 0.04), M["steel_dk"], "hard", what="cadre")
    for s in (-1, 1):
        g.box((x + s * ow, ym, z), (0.05, 0.08, 2 * hhr + 0.1), M["steel_dk"], "hard", what="cadre")
    # fond du cadre (aucun jour entre rails et cadre) ; capteurs annulaires : 6 lentilles sur la face avant
    g.box((x, ym - 0.025, z + 0.005), (2 * ow, 0.03, 2 * hhr + 0.07), M["matte"], "hard", what="fond_cadre")
    for (u, w_) in ((-ow, hhr + 0.04), (ow, hhr + 0.04), (-ow, -hhr - 0.03), (ow, -hhr - 0.03), (0, hhr + 0.04),
                    (0, -hhr - 0.03)):
        g.cyl((x + u, ym + 0.045, z + w_), "y", 0.022, 0.012, M["steel_dk"], n=10, what="capteur")
        g.cyl((x + u, ym + 0.052, z + w_), "y", 0.015, 0.004, M["spec"], n=8, style="flat", what="lentille")
    g.cyl((x, ym, z + hhr + 0.09), "z", 0.026, 0.04, M["steel_dk"], n=10, what="balise_pied")
    g.cyl((x, ym, z + hhr + 0.115), "z", 0.018, 0.016, E, n=10, style="flat", what="balise")
    g.box((x, ym + 0.042, z), (2 * (sep - hwr), 0.006, hhr * 1.3), E2, "flat", what="bouche_lum")
    # petite PARABOLE de visée sur le dos de la couverture
    if k < 1.0:
        return ym + 0.05
    g.cyl((x, y0 + Lb * 0.7, z + rbl + 0.07), "z", 0.025, 0.16, M["steel_dk"], n=8, what="mat")
    dish(g, (x, y0 + Lb * 0.7, z + rbl + 0.15), 0.18 * k, 0.07 * k, M["jacket"], M["ring"], rx=-1.1)
    return ym + 0.05


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
