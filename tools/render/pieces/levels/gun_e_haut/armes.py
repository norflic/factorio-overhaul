"""Canons d'époque (lot V3-E, époques 10 à 15) : faisceau rotatif, jaquette, colliers, frein de bouche, bouche
éclairée et alimentation, sur la lignée de l'industriel (gun_s_industriel/parts.py:gatling, design.py:gun_side).
S'exécute DANS Blender.

Ce qui reste de la lignée à toutes les époques : 6 tubes séparés autour d'un axe, culasse (PT.receiver), moteur
arrière bobiné, bras de tourillon, masque de canon, caisse d'alimentation latérale. Ce qui change (catalogue
DA_PAR_EPOQUE §A.2, emplacement E1) : jaquette, bagues, frein de bouche, alimentation, pièces de culasse.

Corrections des juges (catalogue §A.6) appliquées à toutes les époques :
  - frein de bouche PLUS LARGE que le faisceau, à évents latéraux, différent à chaque époque ;
  - bouche lisible : rosace des bouts de tubes (disques sombres) et anneau lumineux fin de la couleur d'époque
    (< 0,03 t²) ;
  - entre la jaquette et le frein, les tubes restent SÉPARÉS, tenus par 2 colliers rivetés ;
  - aucune bague blanche : les bagues sont dans la matière d'accent de l'époque ;
  - l'axe central remplit le cœur du faisceau (aucun jour à travers le faisceau : contrôle des trous enfermés).
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


# ------------------------------------------------------------------------------------------------
# Faisceau commun
# ------------------------------------------------------------------------------------------------
def tubes(g, x, y0, z, L, nb, rb, rr, phase=0.3):
    M = g.M
    for i in range(nb):
        a = phase + TAU * i / nb
        bx, bz = x + rr * math.cos(a), z + rr * math.sin(a)
        g.cyl((bx, y0 + L / 2, bz), "y", rb, L, M["gun"], n=10, what="canon")
        # rosace : bout de tube sombre cerclé
        g.cyl((bx, y0 + L + 0.003, bz), "y", rb * 0.62, 0.008, M["void"], n=8, style="flat", what="bouche")
    # axe plein : remplit le cœur du faisceau (pas de jour entre les tubes)
    g.cyl((x, y0 + L * 0.5, z), "y", max(rr * 0.42, rr - rb * 0.7), L * 0.97, M["steel_dk"], n=12, what="axe")


def collars(g, x, y0, z, L, rr, rb, fs=(0.62, 0.9)):
    """Colliers de maintien entre la jaquette et le frein : on voit les tubes séparés."""
    M = g.M
    for f in fs:
        yy = y0 + f * L
        g.tube_shell((x, yy, z), "y", rr + rb + 0.022, rr * 0.3, 0.045, M["ring"], n=28, what="collier")
        for d in _ring_dirs(6, 0.2, -0.3):
            g.dome(V((x, yy, z)) + d * (rr + rb + 0.024), d, 0.016, M["rivet"])


def muzzle_glow(g, x, y, z, r, mat=None):
    """Anneau lumineux fin autour de la rosace (couleur d'époque, < 0,03 t²)."""
    g.tube_shell((x, y, z), "y", r, r * 0.78, 0.012, mat or g.M["emit"], n=28, what="bouche_lum")


# ------------------------------------------------------------------------------------------------
# Jaquettes
# ------------------------------------------------------------------------------------------------
def jacket(g, ep, x, y0, z, Ls, rs, rr):
    M = g.M
    yc = y0 + Ls / 2
    if ep == 10:
        # manchon caréné gris clair patiné, fentes de ventilation LONGITUDINALES, bagues noir mat, voyants bleus
        g.cyl((x, yc, z), "y", rs, Ls, M["jacket"], n=32, style="smooth", what="jaquette")
        for a in (0.5, 0.95, 1.4, 1.85, 2.3, 2.75):
            d = V((math.cos(a), 0.0, math.sin(a)))
            g.box(V((x, yc - 0.03, z)) + d * (rs + 0.003), (0.05, Ls * 0.6, 0.01), M["void"], "flat", R=_Rax(d),
                  what="fente")
            for s_ in (-1, 1):
                g.box(V((x, yc - 0.03, z)) + d * (rs + 0.008) + _Rax(d).col[0] * s_ * 0.033,
                      (0.016, Ls * 0.62, 0.018), M["steel_hi"] if s_ > 0 else M["matte"], "hard", R=_Rax(d),
                      what="levre")
        for f in (0.03, 0.97):
            g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.024, rs - 0.01, 0.06, M["ring"], n=32, what="bague")
        g.tube_shell((x, y0 + 0.82 * Ls, z), "y", rs + 0.018, rs - 0.01, 0.035, M["ring"], n=32, what="bague")
        # boîtier de capteurs carénés sur le dessus, 2 voyants bleus
        g.box((x, y0 + Ls * 0.86, z + rs + 0.02), (rs * 0.9, Ls * 0.16, 0.05), M["matte"], "hard", what="capteurs")
        P3.lamp_group(g, (x - rs * 0.25, y0 + Ls * 0.82, z + rs + 0.045), (0, 1, 0), (0, 0, 1), M["emit"], M, n=2,
                      size=0.022, shapes=("carre", "rond"))
    elif ep == 11:
        # manchon de titane, AILERONS RADIAUX TRIANGULAIRES (4 rangées de 6) en alliage blanc : profil en flèche
        g.cyl((x, yc, z), "y", rs, Ls, M["jacket"], n=32, style="smooth", what="jaquette")
        for f in (0.03, 0.97):
            g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.02, rs - 0.01, 0.05, M["ring"], n=32, what="bague")
        nrow = 4
        for i in range(nrow):
            ya = y0 + 0.07 + (Ls - 0.12) * i / nrow
            yb = ya + (Ls - 0.12) / nrow * 0.9
            hf = 0.15 - 0.015 * i
            g.tube_shell((x, ya + 0.012, z), "y", rs + 0.016, rs - 0.01, 0.03, M["ring"], n=32, what="pied_ailerons")
            for d in _ring_dirs(6, 0.0, -0.5):
                t = _Rax(d).col[0] * 0.026
                c = V((x, 0, z))
                p0 = c + d * rs + V((0, ya, 0))
                p1 = c + d * rs + V((0, yb, 0))
                p2 = c + d * (rs + hf) + V((0, ya + 0.025, 0))
                P2.wedge(g, p0, p1, p2, t, M["ring"], what="aileron")
                g.dome(c + d * (rs + 0.02) + V((0, ya + 0.05, 0)) + _Rax(d).col[0] * 0.03, d, 0.013, M["rivet"])
        for d in _ring_dirs(6, math.pi / 6, -0.5):
            g.box(V((x, yc, z)) + d * (rs + 0.003), (0.012, Ls * 0.92, 0.008), M["steel_dk"], "hard", R=_Rax(d),
                  what="joint")
    elif ep == 12:
        # manchon noir profond, colliers chromés givrés
        g.cyl((x, yc, z), "y", rs, Ls, M["jacket"], n=32, style="smooth", what="jaquette")
        for f in (0.03, 0.5, 0.97):
            g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.022, rs - 0.01, 0.055, M["ring"], n=32, what="bague")
            for d in _ring_dirs(5, 0.4, -0.2):
                g.box(V((x, y0 + f * Ls, z)) + d * (rs + 0.024), (0.03, 0.04, 0.012), M["trim"], "flat", R=_Rax(d),
                      what="givre")
        for d in _ring_dirs(8, 0.0, -0.4):
            g.box(V((x, yc, z)) + d * (rs + 0.004), (0.016, Ls * 0.8, 0.01), M["ring"], "hard", R=_Rax(d),
                  what="nervure")
        for k, (f, a) in enumerate(((0.2, 1.2), (0.36, 2.2), (0.68, 0.8), (0.82, 1.9))):
            d = V((math.cos(a), 0, math.sin(a)))
            g.box(V((x, y0 + f * Ls, z)) + d * (rs + 0.01), (0.06, 0.09, 0.012), M["trim"], "flat", R=_Rax(d),
                  what="givre")
    elif ep == 13:
        # tubes à AILETTES DE CÉRAMIQUE (disques annulaires rapprochés), bandes de cuivre
        g.cyl((x, yc, z), "y", rs - 0.01, Ls, M["steel_dk"], n=28, style="smooth", what="jaquette")
        nf = int((Ls - 0.12) / 0.06)
        for i in range(nf):
            yy = y0 + 0.08 + (Ls - 0.16) * (i + 0.5) / nf
            g.tube_shell((x, yy, z), "y", rs + 0.045, rs - 0.012, 0.02, M["jacket"], n=28, what="ailette")
        for f in (0.02, 0.98):
            g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.055, rs - 0.01, 0.045, M["copper"], n=32, what="bague")
    elif ep == 14:
        # couverture thermique en FEUILLE D'OR FROISSÉE, ceinturée de sangles blanc cassé
        nseg = 4
        for i in range(nseg):
            ya = y0 + Ls * i / nseg
            g.crumple((x, ya + Ls / nseg / 2, z), "y", rs + 0.008, Ls / nseg - 0.03, M["jacket"], n=18, k=4,
                      amp=0.014)
        for i in range(nseg + 1):
            yy = y0 + Ls * i / nseg
            g.tube_shell((x, yy, z), "y", rs + 0.026, rs - 0.01, 0.04, M["ring"], n=28, what="sangle")
            g.box((x - rs * 0.7, yy, z + rs * 0.72), (0.04, 0.05, 0.03), M["steel_hi"], "hard", what="boucle")
    else:
        # or blanc CISELÉ : bandes gravées en relief (losanges de nacre sertis dans l'or), pas de perforations
        g.cyl((x, yc, z), "y", rs, Ls, M["jacket"], n=32, style="smooth", what="jaquette")
        for f in (0.03, 0.97):
            g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.026, rs - 0.01, 0.06, M["ring"], n=32, what="bague")
        for f in (0.3, 0.64):
            g.tube_shell((x, y0 + f * Ls, z), "y", rs + 0.03, rs - 0.01, 0.1, M["trim"], n=32, what="bande_nacre")
            for d in _ring_dirs(10, 0.0, -0.5):
                R = _Rax(d) @ Matrix.Rotation(math.pi / 4, 3, "Z")
                for dy in (-0.035, 0.035):
                    g.box(V((x, y0 + f * Ls + dy, z)) + d * (rs + 0.03), (0.028, 0.028, 0.01), M["jacket"], "hard",
                          R=R, what="ciselure")
        for i in range(3):
            yy = y0 + Ls * (0.13 + 0.34 * i) + 0.02
            for d in _ring_dirs(9, 0.35 * (i % 2), -0.45):
                R = _Rax(d) @ Matrix.Rotation(math.pi / 4, 3, "Z")
                g.box(V((x, yy, z)) + d * (rs + 0.004), (0.05, 0.05, 0.014), M["trim"], "hard", R=R, what="ciselure")
                g.box(V((x, yy, z)) + d * (rs + 0.012), (0.024, 0.024, 0.008), M["jacket"], "hard", R=R,
                      what="ciselure")


# ------------------------------------------------------------------------------------------------
# Freins de bouche
# ------------------------------------------------------------------------------------------------
def brake(g, ep, x, y, z, rs, rr, rb):
    """Frein de bouche posé en avant des bouches (y = bout des tubes). Plus large que le faisceau."""
    M = g.M
    E, E2 = M["emit"], M["emit2"]
    if ep == 10:
        # frein à 3 DÉFLECTEURS : lames verticales larges, longerons, noyau noir mat
        yc = y + 0.13
        g.cyl((x, yc, z), "y", rr * 0.95, 0.27, M["matte"], n=20, what="frein_noyau")
        for k, dy in enumerate((-0.09, 0.0, 0.09)):
            g.box((x, yc + dy, z), (2 * rs + 0.26 - 0.04 * k, 0.034, 2 * rs * 0.95), M["jacket"], "hard",
                  what="deflecteur")
        for s in (-1, 1):
            g.box((x + s * (rs + 0.1), yc, z), (0.03, 0.24, 0.06), M["matte"], "hard", what="longeron")
        g.box((x, yc, z + rs * 0.86), (rs * 0.8, 0.24, 0.025), M["steel_dk"], "hard", what="longeron")
        muzzle_glow(g, x, yc + 0.14, z, rr * 0.62)
        g.box((x, yc + 0.04, z + rs * 0.86 + 0.016), (0.05, 0.03, 0.01), E, "flat", what="voyant")
        return yc + 0.14
    if ep == 11:
        # frein EFFILÉ en pointe de flèche, évents obliques, 4 ailerons à la base
        yc = y + 0.16
        g.tube_shell((x, y + 0.02, z), "y", rs + 0.035, rr * 0.4, 0.05, M["ring"], n=28, what="bague")
        g.cyl((x, yc, z), "y", rs + 0.035, 0.28, M["jacket"], n=28, r2=rr * 0.62, style="smooth", what="frein")
        for s in (-1, 1):
            for k in range(3):
                d = V((s, 0, 0))
                R = Matrix.Rotation(s * 0.5, 3, "Z") @ _Rax(d)
                g.box(V((x, yc - 0.08 + k * 0.08, z)) + d * (rs + 0.02 - k * 0.035), (0.016, 0.07, 0.05),
                      M["void"], "flat", R=R, what="event")
        for d in _ring_dirs(4, 0.0, -0.9):
            t = _Rax(d).col[0] * 0.024
            c = V((x, 0, z))
            P2.wedge(g, c + d * rs + V((0, y + 0.0, 0)), c + d * (rr * 0.9) + V((0, yc + 0.1, 0)),
                     c + d * (rs + 0.13) + V((0, y + 0.0, 0)), t, M["ring"], what="aileron")
        muzzle_glow(g, x, yc + 0.141, z, rr * 0.56)
        return yc + 0.14
    if ep == 12:
        # ANNEAU-BOUCHE chromé à fente cyan
        yc = y + 0.09
        g.tube_shell((x, yc, z), "y", rs + 0.06, rr * 0.42, 0.17, M["ring"], n=36, what="anneau_bouche")
        g.tube_shell((x, yc, z), "y", rs + 0.064, rs + 0.03, 0.02, E, n=36, what="fente_lum")
        for d in _ring_dirs(6, 0.26, -0.5):
            g.box(V((x, yc - 0.06, z)) + d * (rs + 0.062), (0.04, 0.03, 0.012), M["trim"], "flat", R=_Rax(d),
                  what="givre")
        muzzle_glow(g, x, yc + 0.088, z, rr * 0.6)
        return yc + 0.085
    if ep == 13:
        # BUSE de céramique à ailettes, cœur orange au fond
        yc = y + 0.14
        g.tube_shell((x, y + 0.02, z), "y", rs + 0.03, rr * 0.4, 0.05, M["copper"], n=28, what="bague")
        g.cyl((x, yc, z), "y", rs * 0.9, 0.26, M["jacket"], n=28, r2=rs * 1.32, style="smooth", what="buse")
        for d in _ring_dirs(6, 0.0, -0.6):
            R = _Rax(d)
            g.box(V((x, yc + 0.01, z)) + d * (rs * 1.12 + 0.03), (0.022, 0.22, 0.08), M["jacket"], "hard", R=R,
                  what="ailette")
        g.cyl((x, yc + 0.128, z), "y", rs * 1.15, 0.008, M["void"], n=24, style="flat", what="fond")
        g.cyl((x, yc + 0.132, z), "y", rr * 0.75, 0.006, E2, n=20, style="flat", what="coeur")
        muzzle_glow(g, x, yc + 0.133, z, rs * 1.25, E)
        return yc + 0.13
    if ep == 14:
        # frein à CAPTEUR ANNULAIRE : manchon à évents, couronne de lentilles, balise rouge
        yc = y + 0.12
        g.tube_shell((x, yc, z), "y", rs + 0.04, rr * 0.45, 0.22, M["ring"], n=32, what="frein")
        for d in _ring_dirs(6, 0.0, -0.5):
            g.box(V((x, yc - 0.03, z)) + d * (rs + 0.041), (0.05, 0.1, 0.008), M["void"], "flat", R=_Rax(d),
                  what="event")
        g.torus((x, yc + 0.12, z), "y", rs + 0.02, 0.028, M["steel_dk"], n=32, m=8, what="capteur")
        for d in _ring_dirs(8, 0.2, -0.6):
            g.cyl(V((x, yc + 0.14, z)) + d * (rs + 0.02), "y", 0.018, 0.012, M["spec"], n=8, style="flat",
                  what="lentille")
        g.cyl((x, yc - 0.02, z + rs + 0.06), "z", 0.018, 0.03, E, n=10, style="flat", what="balise")
        g.cyl((x, yc - 0.02, z + rs + 0.045), "z", 0.026, 0.02, M["steel_dk"], n=10, what="balise_pied")
        muzzle_glow(g, x, yc + 0.111, z, rr * 0.6, E2)
        return yc + 0.11
    # 15 : frein EN COURONNE, 5 pétales-flèches courts autour de la rosace
    yc = y + 0.07
    g.tube_shell((x, yc, z), "y", rs + 0.045, rr * 0.42, 0.12, M["ring"], n=36, what="couronne")
    for d in _ring_dirs(5, math.pi / 2, -2):
        t = _Rax(d).col[0] * 0.024
        c = V((x, 0, z))
        P2.wedge(g, c + d * (rs - 0.01) + V((0, yc - 0.08, 0)), c + d * (rs + 0.13) + V((0, yc - 0.03, 0)),
                 c + d * (rs + 0.08) + V((0, yc + 0.3, 0)), t * 1.5, M["ring"], what="petale")
        P2.wedge(g, c + d * (rs - 0.02) + V((0, yc + 0.0, 0)), c + d * (rs + 0.04) + V((0, yc + 0.0, 0)),
                 c + d * (rs + 0.01) + V((0, yc + 0.17, 0)), V((0, 0, 0)) + t * 1.4, M["trim"], what="petale")
    muzzle_glow(g, x, yc + 0.062, z, rr * 0.6)
    return yc + 0.06


# ------------------------------------------------------------------------------------------------
# Canon complet (faisceau + jaquette + colliers + frein)
# ------------------------------------------------------------------------------------------------
def barrel(g, ep, x, y0, z, L, nb, rb, rr, Ls):
    tubes(g, x, y0, z, L, nb, rb, rr)
    rs = rr + rb + 0.028
    jacket(g, ep, x, y0, z, Ls, rs, rr)
    collars(g, x, y0, z, L, rr, rb, fs=(0.53,) if ep == 12 else (0.64, 0.9))
    if ep == 12:
        # 4 ANNEAUX D'ACCÉLÉRATION chromés enfilés sur le faisceau, tenus par des entretoises visibles
        for f in (0.58, 0.68, 0.78, 0.88):
            yy = y0 + f * L
            g.tube_shell((x, yy, z), "y", rs + 0.11, rs + 0.028, 0.075, g.M["ring"], n=36, what="anneau_acc")
            g.torus((x, yy, z), "y", rs + 0.11, 0.012, g.M["ring"], n=36, m=6, what="jonc")
            for d in _ring_dirs(4, math.pi / 4, -2):
                g.box(V((x, yy, z)) + d * (rr + rb + 0.01 + (rs + 0.03 - rr - rb) / 2), (0.034, 0.05,
                      rs + 0.03 - rr - rb + 0.02), g.M["steel_dk"], "hard", R=_Rax(d), what="entretoise")
            for d in (V((0.6, 0, 0.8)), V((-0.6, 0, 0.8)), V((1, 0, 0)), V((-1, 0, 0))):
                g.box(V((x, yy, z)) + d * (rs + 0.124), (0.05, 0.03, 0.006), g.M["emit"], "flat", R=_Rax(d),
                      what="segment_lum")
    yend = brake(g, ep, x, y0 + L, z, rs, rr, rb)
    return rs, yend


# ------------------------------------------------------------------------------------------------
# Culasse, alimentation et pièces d'époque autour du canon de flanc
# ------------------------------------------------------------------------------------------------
def breech_extra(g, ep, x, sx, y0, y1, zg, wr, hr):
    M = g.M
    if ep == 11:
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
    elif ep == 13:
        # CHAMBRE DE CONFINEMENT sphérique (0,30), céramique cerclée de cuivre, tore segmenté magenta
        c = V((x, (y0 + y1) / 2 - 0.05, zg + hr + 0.15))
        r = 0.16
        g.sphere(c, r, M["jacket"], n=24, m=12)
        for zz in (-0.06, 0.06):
            rr_ = math.sqrt(r * r - zz * zz)
            g.torus(c + V((0, 0, zz)), "z", rr_ + 0.004, 0.012, M["copper"], n=28, m=6, what="cerclage")
        nseg = 6
        for k in range(nseg):
            a = TAU * (k + 0.5) / nseg
            d = V((math.cos(a), math.sin(a), 0))
            R = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
            g.box(c + d * (r + 0.035), (0.09, 0.03, 0.03), M["emit"], "flat", R=R, what="tore_seg")
            g.box(c + d * (r + 0.012), (0.03, 0.04, 0.05), M["steel_dk"], "hard", R=R, what="tore_patte")
        g.cyl(c - V((0, 0, r * 0.9)), "z", 0.08, 0.1, M["steel_dk"], n=16, what="col")
        g.cyl(c + V((0, 0, r - 0.01)), "z", 0.05, 0.05, M["copper"], n=14, what="bride")
    elif ep == 15:
        # chapeau de nacre et liseré d'or blanc sur la culasse
        g.box((x, (y0 + y1) / 2, zg + hr + 0.03), (wr * 0.7, (y1 - y0) * 0.5, 0.025), M["trim"], "hard",
              what="nacre")
        g.box((x, (y0 + y1) / 2, zg + hr + 0.046), (wr * 0.74, 0.02, 0.012), M["jacket"], "hard", what="liseré")


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
    mats = {10: [M["matte"], M["olive"]], 11: [M["olive"], M["ochre"]], 12: [M["jacket"], M["steel_dk"]],
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
            g.box((bc + sx * bw * 0.28, yy, ztop + 0.102), (0.05, bl * 0.08, 0.006), E if k != 1 else M["amber"], "flat",
                  what="voyant")
            g.box((bc - sx * bw * 0.1, yy, ztop + 0.101), (bw * 0.3, bl * 0.1, 0.004), M["matte"], "flat",
                  what="etiquette")
        ribbon(g, [(bc - sx * 0.04, yb0 + bl * 0.85, ztop + 0.09), (bc - sx * 0.1, y0 + bl * 0.75, zg + bh * 0.7),
                   (x + sx * wr * 0.25, y0 + bl * 0.62, zg + hr + 0.05)], 0.06, M["cable_a"])
        ribbon(g, [(bc + sx * 0.02, yb0 + bl * 0.85, ztop + 0.1), (bc - sx * 0.04, y0 + bl * 0.8, zg + bh * 0.75),
                   (x + sx * wr * 0.32, y0 + bl * 0.68, zg + hr + 0.06)], 0.05, M["cable_b"])
    elif ep == 11:
        P2.feed_chute(g, chute, cw, M)
        # 2 ailerons d'alliage blanc patiné sur la caisse (signature)
        for k in range(2):
            yy = yb0 + bl * (0.35 + 0.35 * k)
            P2.wedge(g, V((bc, yy - 0.1, ztop)), V((bc, yy + 0.08, ztop)), V((bc, yy - 0.08, ztop + 0.11)),
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
        P2.feed_chute(g, chute, cw, M)
    elif ep == 13:
        # INJECTEURS debout (céramique, bagues de cuivre) reliés à la chambre
        for k in range(3):
            yy = yb0 + bl * (0.22 + 0.28 * k)
            c = V((bc, yy, ztop + 0.09))
            g.cyl(c, "z", 0.045, 0.18, M["jacket"], n=16, what="injecteur")
            for zz in (-0.06, 0.0, 0.06):
                g.tube_shell(c + V((0, 0, zz)), "z", 0.052, 0.04, 0.018, M["copper"], n=16, what="bague")
            g.cyl(c + V((0, 0, 0.1)), "z", 0.025, 0.03, M["emit2"], n=10, style="flat", what="coeur")
            g.tube([c + V((0, 0, 0.08)), c + V((-sx * 0.12, 0, 0.16)), V((x + sx * 0.05, (y0 + y1) / 2 - 0.05,
                                                                              zg + hr + 0.2))], 0.016,
                   M["copper"], n=8, what="liaison")
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
            P2.wedge(g, c + d * 0.06 + V((0, 0, 0.16)), c + d * 0.07 + V((0, 0, 0.16)), c + d * 0.065 + V((0, 0, 0.23)),
                     V((-d.y, d.x, 0)) * 0.018, M["jacket"], what="fleche")
        P2.feed_chute(g, [(bc, yb0 + bl * 0.7, ztop + 0.005), (bc - sx * 0.05, y0 + bl * 0.65, zg + bh * 0.62),
                          (x + sx * wr * 0.25, y0 + bl * 0.55, zg + hr + 0.06)], cw, M)
    if ep in (10, 12, 13, 14, 15):
        P3.lamp_group(g, (bc + sx * bw * 0.3, yb0 + bl * 0.08, ztop - 0.005), (0, 1, 0), (0, 0, 1),
                      E, M, n=2 if ep < 13 else 3, shapes=("rond", "carre", "fente"))
    return bc


def mantle_extra(g, ep, x, y1, zg, wr, hr):
    """Pièces du masque de canon : capteur optique (10), balise (14)."""
    M = g.M
    if ep == 10:
        c = V((x + wr * 0.45, y1 + 0.02, zg + hr * 1.35 + 0.06))
        g.box(c, (0.12, 0.12, 0.1), M["matte"], "hard", what="capteur")
        g.cyl(c + V((0, 0.07, 0.0)), "y", 0.035, 0.03, M["steel_hi"], n=14, what="capteur_bague")
        g.cyl(c + V((0, 0.088, 0.0)), "y", 0.025, 0.006, M["emit"], n=12, style="flat", what="lentille")
        g.box(c + V((0, -0.02, 0.06)), (0.08, 0.06, 0.02), M["jacket"], "hard", what="visiere")
