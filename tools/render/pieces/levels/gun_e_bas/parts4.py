"""Kit d'époque de la mitrailleuse (lot V3-E, époques 1 à 9). S'exécute DANS Blender.

Le corps reste celui de la lignée « industriel lourd » (parts, parts2, parts3 : colonne, coupole, jupe, trémie,
réservoirs, groupe électrogène, radiateurs, armoires). Ce module fournit ce qui CHANGE d'une époque à l'autre, selon
le catalogue fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md (§A.2, emplacements E1 à E6) :
  E1 canons (jaquette, frein ou couronne de bouche, culasse, entraînement, alimentation),
  E2 tuyaux et liaisons, E3 et E4 accents et matières, E5 foyers, E6 signature et pièce du niveau pair.
La taille des petits détails reste CONSTANTE (rivets 0,015 à 0,02 ; tôles 0,22 à 0,30) : une grande époque porte plus
de pièces, jamais de plus grosses.
"""
import math

from mathutils import Matrix, Vector

import parts as PT
import parts2 as P2
import parts3 as P3
from kit import SQ2, TAU, basis

V = Vector


# ------------------------------------------------------------------------------------------------
# Aides géométriques
# ------------------------------------------------------------------------------------------------
def Ry(d):
    """Rotation dont l'axe y local suit d."""
    a, u, w = basis(V(d))
    return Matrix((u, a, w)).transposed()


def Rz(a):
    return Matrix.Rotation(a, 3, "Z")


def prism(g, pts, z0, z1, mat, style="hard", what="prisme"):
    """Polygone convexe (x, y) extrudé de z0 à z1 (sens direct vu de dessus)."""
    n = len(pts)
    vs = [(p[0], p[1], z0) for p in pts] + [(p[0], p[1], z1) for p in pts]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(mat, style, vs, fs, what)


def sphere(g, c, r, mat, n=24, m=12, sz=1.0, style="smooth", what="sphere"):
    c = V(c)
    vs = [(c.x, c.y, c.z - r * sz)]
    for k in range(1, m):
        ph = -math.pi / 2 + math.pi * k / m
        for j in range(n):
            th = TAU * j / n
            vs.append((c.x + r * math.cos(ph) * math.cos(th), c.y + r * math.cos(ph) * math.sin(th),
                       c.z + r * sz * math.sin(ph)))
    vs.append((c.x, c.y, c.z + r * sz))
    fs = []
    for j in range(n):
        fs.append((0, 1 + (j + 1) % n, 1 + j))
    for k in range(m - 2):
        for j in range(n):
            a = 1 + k * n + j
            b = 1 + k * n + (j + 1) % n
            fs.append((a, b, b + n, a + n))
    top = len(vs) - 1
    for j in range(n):
        a = 1 + (m - 2) * n + j
        b = 1 + (m - 2) * n + (j + 1) % n
        fs.append((a, b, top))
    g._add(mat, style, vs, fs, what)


def bolts_ring(g, c, axis, R, n, mat, r=0.016, phase=0.0, skip_down=None):
    a, u, w = basis(V(axis))
    c = V(c)
    for k in range(n):
        ang = phase + TAU * k / n
        d = u * math.cos(ang) + w * math.sin(ang)
        if skip_down is not None and d.z < skip_down:
            continue
        g.dome(c + d * R, a, r, mat)


def lit_ring(g, c, axis, r, emat, w=0.026, t=0.012):
    """Anneau lumineux (pourtour de bouche, catalogue §A.6 : ≥ 8 × 8 px hr, < 0,03 t²) : 1,5 px hr de large au
    moins, sinon il ne se voit pas (F37)."""
    g.tube_shell(c, axis, r, r - w, t, emat, n=28, what="anneau_bouche")


def ears(g, x, y, z, rx, L, h, mat, vent=True):
    """Oreilles latérales du frein de bouche (évents sur les flancs) : en pose N, elles font du bout du canon un
    « T » horizontal, jamais le chapeau rond d'une cheminée (défaut relevé par les juges)."""
    M = g.M
    for s in (-1, 1):
        g.box((x + s * rx, y, z), (0.07, L, h), mat, "hard", what="oreille")
        if vent:
            for k in range(2):
                g.box((x + s * (rx + 0.036), y - L * 0.22 + k * L * 0.44, z), (0.006, L * 0.26, h * 0.62), M["void"],
                      "flat", what="event")
        g.dome((x + s * rx, y, z + h / 2 + 0.002), (0, 0, 1), 0.015, M["rivet"])


def polyline_pts(ctrl):
    return [V(p) for p in ctrl]


# ------------------------------------------------------------------------------------------------
# E1 : faisceau de tubes et bouches (commun : tubes séparés, collier de maintien, rosace, pourtour éclairé)
# ------------------------------------------------------------------------------------------------
def barrels(g, x, y0, z, L, nb, rb, rr, mat, phase=0.3, collar_mat=None, collars=(0.8,), ends=True, arr="ring"):
    """Tubes, âme centrale assez grosse pour qu'aucun jour ne traverse le faisceau (contrôle des trous enfermés),
    plaque de culasse, colliers de maintien (tubes visibles séparés entre la jaquette et la bouche).
    arr : « ring » (faisceau rotatif), « row » (tubes côte à côte à plat : canon-orgue forgé de l'époque 2),
    « square » (2 × 2, gros calibre sous un fourreau blindé : époque 5)."""
    M = g.M
    pos = []
    if arr == "row":
        pitch = rb * 2.25
        for i in range(nb):
            pos.append((x + (i - (nb - 1) / 2) * pitch, z))
    elif arr == "square":
        for i in range(nb):
            a = math.pi / 4 + TAU * i / nb
            pos.append((x + rr * math.cos(a), z + rr * math.sin(a)))
    else:
        for i in range(nb):
            a = phase + TAU * i / nb
            pos.append((x + rr * math.cos(a), z + rr * math.sin(a)))
    for bx, bz in pos:
        g.cyl((bx, y0 + L / 2, bz), "y", rb, L, mat, n=12, what="canon")
        if ends:
            g.cyl((bx, y0 + L + 0.002, bz), "y", rb * 0.62, 0.008, M["void"], n=10, style="flat", what="bouche")
    cm = collar_mat or M["steel_dk"]
    if arr == "row":
        w = (nb - 1) * rb * 2.25
        g.box((x, y0 + L * 0.48, z - rb * 0.3), (w, L * 0.94, rb * 0.9), M["steel_dk"], "hard", what="ame")
        g.box((x, y0 + 0.02, z), (w + 2 * rb + 0.03, 0.04, 2 * rb + 0.03), M["steel_dk"], "soft",
              what="plaque_culasse")
        for f in collars:
            yy = y0 + f * L
            g.box((x, yy, z), (w + 2 * rb + 0.03, 0.035, 2 * rb + 0.026), cm, "hard", what="collier")
            for s in (-1, 1):
                g.bolt((x + s * (w / 2 + rb * 0.4), yy, z + rb + 0.013), (0, 0, 1), 0.012, M["steel_hi"])
        return pos
    core = max(rr - rb * 0.55, rr * 0.55)
    g.cyl((x, y0 + L * 0.5, z), "y", core, L * 0.96, M["steel_dk"], n=14, what="ame")
    g.cyl((x, y0 + 0.02, z), "y", rr + rb + 0.01, 0.04, M["steel_dk"], n=24, style="soft", what="plaque_culasse")
    for f in collars:
        yy = y0 + f * L
        g.tube_shell((x, yy, z), "y", rr + rb + 0.016, core * 0.8, 0.035, cm, n=28, what="collier")
        bolts_ring(g, (x, yy, z), (0, 1, 0), rr + rb + 0.016, 6, M["rivet"], r=0.014, phase=0.5, skip_down=-0.3)
    return pos


def bores(g, x, y, z, pos, rb, rim_mat):
    """Rosace : bouts de tubes sombres cerclés sur la face avant d'un frein ou d'une couronne."""
    M = g.M
    for bx, bz in pos:
        g.cyl((bx, y + 0.004, bz), "y", rb * 0.66, 0.008, M["void"], n=10, style="flat", what="bouche")
        g.tube_shell((bx, y + 0.002, bz), "y", rb * 0.98, rb * 0.66, 0.012, rim_mat, n=12, what="levre")


def gun_e(g, st, H, x, side):
    """Canon de flanc complet d'une époque : faisceau, jaquette et bouche (fonctions de l'époque), retourne le rayon
    de jaquette. st : style d'époque (dict de design.py)."""
    M = g.M
    y1 = H["recv"][1]
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    zg = H["zg"]
    arr = st.get("arr", "ring")
    rs = rr + rb + 0.028 if arr != "row" else (nb - 1) * rb * 1.125 + rb + 0.02
    bm = M[st.get("barrel", "gun")]
    pos = barrels(g, x, y1, zg, L, nb, rb, rr, bm, collar_mat=M[st["band"]], collars=st.get("collars", (0.8,)),
                  ends=False, arr=arr)
    Lj = L * st.get("jacket_f", 0.46)
    JACKETS[st["jacket"]](g, st, x, y1, zg, Lj, rs, H)
    yb = y1 + L
    BRAKES[st["brake"]](g, st, x, yb, zg, rs, pos, H)
    return rs


# --- jaquettes ------------------------------------------------------------------------------------
def jk_forge(g, st, x, y0, z, Lj, rs, H):
    """Époque 2 : manchon d'acier plein, colliers boulonnés tous les 0,12 (pas de perforations)."""
    M = g.M
    g.cyl((x, y0 + Lj / 2, z), "y", rs, Lj, M["blackiron"], n=28, style="smooth", what="jaquette")
    n = max(2, int(Lj / 0.12))
    for i in range(n + 1):
        yy = y0 + 0.03 + (Lj - 0.06) * i / n
        g.tube_shell((x, yy, z), "y", rs + 0.02, rs - 0.01, 0.034, M["rawiron"], n=28, what="collier")
        bolts_ring(g, (x, yy, z), (0, 1, 0), rs + 0.021, 4, M["brass"], r=0.015, phase=0.785, skip_down=-0.2)


def jk_steam(g, st, x, y0, z, Lj, rs, H):
    """Époque 3 : manchon de cuivre à ailettes annulaires rapprochées, cerclé de laiton."""
    M = g.M
    g.cyl((x, y0 + Lj / 2, z), "y", rs - 0.006, Lj, M["copper_pol"], n=28, what="jaquette")
    n = max(6, int((Lj - 0.08) / 0.028))
    for i in range(n):
        yy = y0 + 0.05 + (Lj - 0.1) * (i + 0.5) / n
        g.tube_shell((x, yy, z), "y", rs + 0.022, rs - 0.01, 0.011, M["copper_pol"], n=28, what="ailette")
    for yy in (y0 + 0.025, y0 + Lj - 0.02):
        g.tube_shell((x, yy, z), "y", rs + 0.03, rs - 0.01, 0.04, M["brass"], n=28, what="cerclage")
        bolts_ring(g, (x, yy, z), (0, 1, 0), rs + 0.031, 6, M["rivet"], r=0.014, skip_down=-0.3)


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
        bolts_ring(g, (x, yy, z), (0, 1, 0), rs + 0.024, 6, M["rivet"], r=0.015, phase=0.2, skip_down=-0.3)
    for k in range(coils):
        yc = y0 + Lj * (0.25 + 0.5 * k / max(1, coils - 1)) if coils > 1 else y0 + Lj * 0.5
        g.tube_shell((x, yc, z), "y", rs + 0.03, rs - 0.01, 0.07, M["steel_dk"], n=28, what="bobine")
        for t in range(4):
            g.torus((x, yc - 0.027 + t * 0.018, z), "y", rs + 0.036, 0.0095, M["copper"], n=28, m=6, what="spire")


def jk_galva(g, st, x, y0, z, Lj, rs, H):
    jk_perforated(g, st, x, y0, z, Lj, rs, H, mat="galva")


def jk_coils(g, st, x, y0, z, Lj, rs, H):
    jk_perforated(g, st, x, y0, z, Lj, rs, H, mat="steel", coils=3)


def jk_hex(g, st, x, y0, z, Lj, rs, H):
    """Époque 5 : manchon blindé à pans (section hexagonale), tungstène sombre, rivets lourds."""
    M = g.M
    R6 = rs * 1.08
    g.cyl((x, y0 + Lj / 2, z), "y", R6, Lj, M["tungsten"], n=6, style="hard", phase=math.pi / 6, what="jaquette")
    nr = max(3, int((Lj - 0.08) / 0.11))
    for f in range(6):
        a = math.pi / 6 + TAU * f / 6 + TAU / 12
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.3:
            continue
        rf = R6 * math.cos(math.pi / 6)
        for i in range(nr):
            yy = y0 + 0.05 + (Lj - 0.1) * (i + 0.5) / nr
            g.dome(V((x, yy, z)) + d * (rf + 0.004), d, 0.02, M["rivet"])
    for yy in (y0 + 0.03, y0 + Lj - 0.02):
        g.cyl((x, yy, z), "y", R6 + 0.025, 0.05, M["burnrust"], n=6, style="hard", phase=math.pi / 6, what="bague")
    # fentes de braise entre les pans (foyers fins et nombreux, catalogue époque 5)
    for f in range(6):
        a = math.pi / 6 + TAU * f / 6
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.2:
            continue
        for i in range(2):
            yy = y0 + Lj * (0.3 + 0.35 * i)
            g.box(V((x, yy, z)) + d * (R6 + 0.003), (0.012, 0.07, 0.012), M["emit"], "flat",
                  R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="braise")


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
        g.tube_shell(c + d * 0.008, d, 0.04, 0.024, 0.02, M["bronze"], n=16, what="sertissure")
        g.cyl(c + d * 0.016, d, 0.026, 0.04, M["emit"], n=6, r2=0.008, style="hard", what="cristal")
        for s in (-1, 1):
            g.box(c + d * 0.018 + V((0, s * 0.035, 0)), (0.016, 0.02, 0.016), M["brass"], "hard", what="griffe")
    for yy in (y0 + 0.025, y0 + Lj - 0.02):
        g.tube_shell((x, yy, z), "y", rs + 0.026, rs - 0.01, 0.045, M["stone"], n=28, what="bague")


def jk_marsh(g, st, x, y0, z, Lj, rs, H):
    """Époque 8 : manchon de vert-de-gris à 2 fenêtres de verre longues (liquide vert-jaune, bulles)."""
    M = g.M
    g.cyl((x, y0 + Lj / 2, z), "y", rs, Lj, M["verdigris"], n=28, what="jaquette")
    for a in (math.pi * 0.5 + 0.55, math.pi * 0.5 - 0.55):
        d = V((math.cos(a), 0, math.sin(a)))
        Rr = Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed()
        c = V((x, y0 + Lj * 0.52, z)) + d * (rs + 0.004)
        g.box(c, (0.07, Lj * 0.7, 0.012), M["emit_soft"], "flat", R=Rr, what="fenetre")
        for s in (-1, 1):
            g.box(c + Rr @ V((s * 0.045, 0, 0.006)), (0.02, Lj * 0.74, 0.02), M["brass"], "hard", R=Rr,
                  what="cadre")
        for t in range(4):
            g.box(c + Rr @ V((0, (t - 1.5) * Lj * 0.17, 0.007)), (0.09, 0.016, 0.014), M["verdigris"], "hard", R=Rr,
                  what="barreau")
        for t in range(3):
            g.dome(c + Rr @ V((0.015 * ((t % 2) * 2 - 1), (t - 1) * Lj * 0.2 + 0.03, 0.008)), d, 0.011, M["emit"])
    for yy in (y0 + 0.025, y0 + Lj - 0.02):
        g.tube_shell((x, yy, z), "y", rs + 0.03, rs - 0.01, 0.05, M["rubber"], n=28, what="joint")
        bolts_ring(g, (x, yy, z), (0, 1, 0), rs + 0.031, 6, M["brass"], r=0.014, skip_down=-0.3)


def jk_atom(g, st, x, y0, z, Lj, rs, H):
    """Époque 9 : jaquette octogonale chanfreinée en plomb, manchons de refroidissement annelés."""
    M = g.M
    R8 = rs * 1.06
    g.cyl((x, y0 + Lj / 2, z), "y", R8, Lj, M["lead"], n=8, style="hard", phase=math.pi / 8, what="jaquette")
    for i in range(2):
        yc = y0 + Lj * (0.3 + 0.42 * i)
        for t in range(5):
            g.torus((x, yc - 0.05 + t * 0.025, z), "y", R8 + 0.012, 0.013, M["copper"], n=28, m=6, what="annelure")
    for yy in (y0 + 0.03, y0 + Lj - 0.02):
        g.cyl((x, yy, z), "y", R8 + 0.024, 0.05, M["lead"], n=8, style="hard", phase=math.pi / 8, what="bague")
        g.tube_shell((x, yy + 0.034, z), "y", R8 + 0.02, R8 - 0.01, 0.018, M["hazy"], n=8, what="liseré")


JACKETS = {"forge": jk_forge, "steam": jk_steam, "galva": jk_galva, "hex": jk_hex, "coils": jk_coils,
           "bronze": jk_bronze, "marsh": jk_marsh, "atom": jk_atom}


# --- bouches -----------------------------------------------------------------------------------------
def br_crown(g, st, x, yb, z, rs, pos, H):
    """Époque 2 : couronne de bouche plate en fer noirci, à 4 boulons, sans frein."""
    M = g.M
    rb = H["rb"]
    rc = rs + 0.034
    g.cyl((x, yb - 0.025, z), "y", rc, 0.07, M["blackiron"], n=28, style="soft", what="couronne")
    g.cyl((x, yb + 0.011, z), "y", rc - 0.012, 0.008, M["bolted"], n=28, style="flat", what="face")
    ears(g, x, yb - 0.025, z, rc + 0.02, 0.07, rs * 1.1, M["blackiron"], vent=False)
    for k in range(4):
        a = 0.785 + TAU * k / 4
        d = V((math.cos(a), 0, math.sin(a)))
        g.bolt(V((x, yb + 0.014, z)) + d * (rc - 0.026), (0, 1, 0), 0.016, M["steel_hi"])
    bores(g, x, yb + 0.016, z, pos, rb, M["steel_hi"])
    lit_ring(g, (x, yb + 0.017, z), "y", rc - 0.002, M["emit"])


def br_steam(g, st, x, yb, z, rs, pos, H):
    """Époque 3 : frein de bouche en laiton à 4 évents ronds, plus large que le faisceau."""
    M = g.M
    rb = H["rb"]
    ro = rs + 0.036
    g.tube_shell((x, yb + 0.04, z), "y", ro, H["rr"] * 0.4, 0.15, M["brass"], n=28, what="frein")
    for a in (math.pi * 0.25, math.pi * 0.75, -math.pi * 0.25, -math.pi * 0.75, math.pi * 0.5):
        d = V((math.cos(a), 0, math.sin(a)))
        g.cyl(V((x, yb + 0.05, z)) + d * (ro - 0.002), d, 0.024, 0.01, M["void"], n=10, style="flat", what="event")
    g.tube_shell((x, yb + 0.115, z), "y", ro + 0.008, ro - 0.02, 0.02, M["copper_pol"], n=28, what="levre")
    g.cyl((x, yb + 0.1, z), "y", ro - 0.012, 0.02, M["brass"], n=28, what="face")
    for s in (-1, 1):  # évents latéraux en tubulures de laiton
        g.cyl((x + s * (ro + 0.03), yb + 0.05, z), "x", 0.03, 0.07, M["brass"], n=12, what="tubulure")
        g.cyl((x + s * (ro + 0.066), yb + 0.05, z), "x", 0.02, 0.004, M["void"], n=10, style="flat", what="event")
    bores(g, x, yb + 0.112, z, pos, rb, M["brass"])
    lit_ring(g, (x, yb + 0.126, z), "y", ro - 0.002, M["emit"])


def br_slots(g, st, x, yb, z, rs, pos, H):
    """Époque 4 : frein de bouche à 2 fentes latérales, acier galvanisé."""
    M = g.M
    rb = H["rb"]
    w = rs * 2 + 0.07
    g.box((x, yb + 0.06, z), (w, 0.17, rs * 1.6), M["galva"], "soft", what="frein")
    for s in (-1, 1):
        for k in range(2):
            g.box((x + s * (w / 2 + 0.002), yb + 0.02 + k * 0.08, z), (0.012, 0.045, rs * 1.15), M["void"], "flat",
                  what="fente")
        g.box((x + s * (w / 2 + 0.008), yb + 0.06, z + rs * 0.82), (0.02, 0.16, 0.022), M["galva"], "hard",
              what="joue")
    g.box((x, yb + 0.06, z + rs * 0.8 + 0.012), (w * 0.6, 0.12, 0.012), M["hazk"], "flat", what="bande")
    g.cyl((x, yb + 0.15, z), "y", rs + 0.006, 0.012, M["galva"], n=28, what="face")
    bores(g, x, yb + 0.157, z, pos, rb, M["steel_hi"])
    lit_ring(g, (x, yb + 0.158, z), "y", rs + 0.004, M["emit"])


def br_wedge(g, st, x, yb, z, rs, pos, H):
    """Époque 5 : frein de bouche en coin (bloc trapézoïdal à évents obliques), lèvres de braise dans les évents."""
    M = g.M
    rb = H["rb"]
    w0, w1 = rs * 2.2, rs * 2.6
    h0, h1 = rs * 1.7, rs * 1.25
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
            g.box((xx, yy, z + 0.01), (0.012, 0.034, h1 * 0.7), M["emit"], "flat", R=Rr, what="braise")
            g.box((xx + s * 0.006, yy + 0.022, z + 0.01), (0.014, 0.012, h1 * 0.8), M["tungsten"], "hard", R=Rr,
                  what="lame")
    for k in range(4):
        g.dome((x - w1 * 0.3 + k * w1 * 0.2, y0 + 0.11, z + (h0 + h1) / 4 + 0.006), (0, 0, 1), 0.02, M["rivet"])
    g.cyl((x, y1 + 0.004, z), "y", rs * 0.95, 0.01, M["burnrust"], n=24, what="face")
    bores(g, x, y1 + 0.01, z, pos, rb, M["burnrust"])
    lit_ring(g, (x, y1 + 0.012, z), "y", rs * 0.95, M["emit"])


def br_insul(g, st, x, yb, z, rs, pos, H):
    """Époque 6 : frein de bouche à évents et anneau isolateur en céramique ; 2 points d'arc à la bouche."""
    M = g.M
    rb = H["rb"]
    ro = rs + 0.035
    g.tube_shell((x, yb + 0.06, z), "y", ro, H["rr"] * 0.5, 0.16, M["steel"], n=28, what="frein")
    for k in range(8):
        a = TAU * k / 8 + 0.2
        d = V((math.cos(a), 0.0, math.sin(a)))
        if d.z < -0.5:
            continue
        g.box(V((x, yb + 0.06, z)) + d * (ro + 0.001), (0.04, 0.1, 0.02), M["void"], "flat",
              R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="event")
    for i, (yy, rr_) in enumerate(((yb - 0.04, ro + 0.012), (yb - 0.075, ro - 0.006), (yb - 0.11, ro + 0.012))):
        g.tube_shell((x, yy, z), "y", rr_, rs - 0.01, 0.03, M["accent"], n=28, what="isolateur")
    g.tube_shell((x, yb + 0.15, z), "y", ro + 0.006, ro - 0.02, 0.02, M["copper"], n=28, what="levre")
    bores(g, x, yb + 0.145, z, pos, rb, M["copper"])
    lit_ring(g, (x, yb + 0.162, z), "y", ro, M["emit"])
    for s in (-1, 1):
        g.box((x + s * (ro + 0.012), yb + 0.17, z + 0.02), (0.014, 0.05, 0.014), M["emit"], "flat", what="arc")
        g.cyl((x + s * (ro + 0.012), yb + 0.13, z + 0.02), "y", 0.012, 0.06, M["copper"], n=8, what="electrode")


def br_claws(g, st, x, yb, z, rs, pos, H):
    """Époque 7 : couronne de bronze à 3 griffes qui tient un cristal-lentille taillé, éclairé de violet."""
    M = g.M
    rb = H["rb"]
    ro = rs + 0.03
    g.tube_shell((x, yb + 0.02, z), "y", ro, H["rr"] * 0.3, 0.1, M["bronze"], n=28, what="couronne")
    g.tube_shell((x, yb + 0.075, z), "y", ro + 0.01, ro - 0.025, 0.02, M["brass"], n=28, what="levre")
    bores(g, x, yb + 0.072, z, pos, rb, M["bronze"])
    lit_ring(g, (x, yb + 0.087, z), "y", ro + 0.006, M["emit"])
    lens_y = yb + 0.2
    # nez conique plein entre la couronne et la lentille (les griffes y sont posées : aucun jour au travers)
    g.cyl((x, (yb + 0.08 + lens_y - 0.06) / 2, z), "y", ro - 0.035, lens_y - 0.06 - (yb + 0.08), M["castiron"],
          n=24, r2=H["rr"] * 0.55, what="nez")
    for k in range(3):
        a = math.pi / 2 + TAU * k / 3
        d = V((math.cos(a), 0, math.sin(a)))
        p0 = V((x, yb + 0.07, z)) + d * (ro - 0.02)
        p1 = V((x, lens_y, z)) + d * (H["rr"] * 0.62)
        g.cyl((p0 + p1) / 2, p1 - p0, 0.018, (p1 - p0).length, M["bronze"], n=6, style="hard", what="griffe")
        g.dome(p1, d, 0.02, M["brass"])
    # cristal-lentille (bipyramide taillée)
    g.cyl((x, lens_y - 0.04, z), "y", H["rr"] * 0.62, 0.08, M["emit"], n=8, r2=H["rr"] * 0.62, style="hard",
          what="lentille")
    g.cyl((x, lens_y + 0.035, z), "y", H["rr"] * 0.62, 0.07, M["emit"], n=8, r2=0.01, style="hard", what="pointe")
    g.cyl((x, lens_y - 0.1, z), "y", 0.01, 0.05, M["emit"], n=8, r2=H["rr"] * 0.62, style="hard", what="pointe")


def br_nozzle(g, st, x, yb, z, rs, pos, H):
    """Époque 8 : buse à collerette de caoutchouc et anneau de joint, plus large que le faisceau."""
    M = g.M
    rb = H["rb"]
    g.cyl((x, yb + 0.05, z), "y", rs + 0.01, 0.12, M["verdigris"], n=28, r2=rs + 0.05, what="buse")
    g.torus((x, yb + 0.115, z), "y", rs + 0.05, 0.022, M["rubber"], n=28, m=8, what="collerette")
    g.torus((x, yb - 0.01, z), "y", rs + 0.012, 0.016, M["rubber"], n=28, m=8, what="joint")
    bolts_ring(g, (x, yb + 0.03, z), (0, 1, 0), rs + 0.024, 6, M["brass"], r=0.014, skip_down=-0.3)
    g.cyl((x, yb + 0.112, z), "y", rs + 0.035, 0.012, M["glass_dk"], n=28, what="face")
    bores(g, x, yb + 0.118, z, pos, rb, M["verdigris"])
    lit_ring(g, (x, yb + 0.124, z), "y", rs + 0.03, M["emit"])


def br_octo(g, st, x, yb, z, rs, pos, H):
    """Époque 9 : frein de bouche octogonal à évents."""
    M = g.M
    rb = H["rb"]
    R8 = rs * 1.12 + 0.03
    g.cyl((x, yb + 0.06, z), "y", R8, 0.17, M["lead"], n=8, style="hard", phase=math.pi / 8, what="frein")
    for f in range(8):
        a = math.pi / 8 + TAU * f / 8 + TAU / 16
        d = V((math.cos(a), 0, math.sin(a)))
        if d.z < -0.4:
            continue
        rf = R8 * math.cos(math.pi / 8)
        for k in range(2):
            g.box(V((x, yb + 0.02 + k * 0.08, z)) + d * (rf + 0.002), (0.05, 0.035, 0.01), M["void"], "flat",
                  R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="event")
    g.cyl((x, yb + 0.15, z), "y", R8 - 0.02, 0.012, M["concrete"], n=8, phase=math.pi / 8, what="face")
    ears(g, x, yb + 0.06, z, R8 + 0.025, 0.12, R8 * 0.9, M["lead"])
    bores(g, x, yb + 0.156, z, pos, rb, M["copper"])
    lit_ring(g, (x, yb + 0.158, z), "y", rs + 0.01, M["emit"])
    g.tube_shell((x, yb - 0.025, z), "y", R8 + 0.006, R8 - 0.03, 0.022, M["hazy"], n=8, what="liseré")


BRAKES = {"crown": br_crown, "steam": br_steam, "slots": br_slots, "wedge": br_wedge, "insul": br_insul,
          "claws": br_claws, "nozzle": br_nozzle, "octo": br_octo}


# --- entraînement (moteur arrière de la lignée) --------------------------------------------------
def drive(g, st, c, r, L):
    """Organe arrière du canon : manivelle (2), cylindre à vapeur à bielle (3), moteur (4 à 9, habillé)."""
    M = g.M
    x, y, z = c
    kind = st["drive"]
    if kind == "crank":
        g.cyl((x, y, z), "y", r, L, M["blackiron"], n=20, style="soft", what="carter")
        for k in range(3):
            g.tube_shell((x, y - L / 2 + 0.04 + k * (L - 0.08) / 2, z), "y", r + 0.015, r - 0.01, 0.025,
                         M["rawiron"], n=20, what="nervure")
        g.cyl((x, y - L / 2 - 0.025, z), "y", r * 0.8, 0.05, M["rawiron"], n=20, style="soft", what="flasque")
        bolts_ring(g, (x, y - L / 2 - 0.05, z), (0, -1, 0), r * 0.6, 6, M["brass"], r=0.015)
        # manivelle : bras, poignée laiton
        g.box((x, y - L / 2 - 0.07, z - r * 0.4), (0.03, 0.02, r * 1.2), M["blackiron"], "hard", what="bras")
        g.cyl((x + 0.04, y - L / 2 - 0.07, z - r), "x", 0.016, 0.09, M["brass"], n=8, what="poignee")
        return
    if kind == "steam":
        # cylindre à vapeur horizontal, tige de piston, crosse et bielle apparente vers un plateau-manivelle
        g.cyl((x, y - L * 0.1, z), "y", r, L * 0.8, M["castiron"], n=22, style="soft", what="cylindre")
        for yy in (y - L * 0.5, y + L * 0.3):
            g.tube_shell((x, yy, z), "y", r + 0.02, r - 0.01, 0.04, M["brass"], n=22, what="bride")
            bolts_ring(g, (x, yy, z), (0, 1, 0), r + 0.02, 8, M["rivet"], r=0.013)
        g.cyl((x, y - L * 0.55, z), "y", r * 0.7, 0.05, M["castiron"], n=18, what="fond")
        P2.gauge(g, (x + r * 0.3, y - L * 0.2, z + r + 0.005), (0.3, 0, 1), 0.04, M)
        g.cyl((x, y + L * 0.42, z), "y", 0.016, L * 0.22, M["steel_hi"], n=8, what="tige")
        g.box((x, y + L * 0.55, z), (0.06, 0.05, 0.06), M["brass"], "hard", what="crosse")
        g.box((x + r * 0.55, y + L * 0.62, z + r * 0.35), (0.022, L * 0.34, 0.022), M["steel_hi"], "hard",
              R=Matrix.Rotation(0.35, 3, "Y"), what="bielle")
        g.tube([V((x, y - L * 0.2, z + r)), V((x + r * 0.8, y - L * 0.25, z + r + 0.06)),
                V((x + r * 1.2, y - L * 0.45, z + 0.02))], 0.017, M["copper_pol"], n=8, what="admission")
        return
    # moteur (lignée) habillé de la matière de l'époque
    body = M[st.get("drive_mat", "steel_dk")]
    g.cyl((x, y, z), "y", r, L, body, n=28 if st.get("drive_n") is None else st["drive_n"],
          style="soft" if st.get("drive_n") is None else "hard", phase=math.pi / 8, what="moteur")
    nf = int((L * 0.5) / 0.045)
    fm = M[st.get("fin_mat", "steel_hi")]
    for kk in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + kk * 0.045, z), "y", r + 0.026, r - 0.01, 0.014, fm, n=28, what="ailette")
    if kind == "coil":
        for kk in range(4):
            g.torus((x, y + L / 2 - 0.05 - kk * 0.034, z), "y", r + 0.006, 0.017, M["copper"], n=28, m=6,
                    what="bobinage")
    elif kind == "scale":
        for kk in range(5):
            a = math.pi / 2 + (kk - 2) * 0.55
            d = V((math.cos(a), 0, math.sin(a)))
            g.box(V((x, y + L * 0.25, z)) + d * (r + 0.012), (0.08, L * 0.42, 0.018), M["tungsten"], "hard",
                  R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed() @ Matrix.Rotation(0.12, 3, "X"),
                  what="ecaille")
    elif kind == "crystal":
        g.tube_shell((x, y + L * 0.3, z), "y", r + 0.02, r - 0.01, 0.05, M["stone"], n=24, what="bague")
        g.cyl((x, y + L * 0.3, z + r + 0.02), (0, 0.3, 1), 0.02, 0.07, M["emit"], n=6, r2=0.005, style="hard",
              what="cristal")
    elif kind == "lead":
        g.tube_shell((x, y + L * 0.3, z), "y", r + 0.015, r - 0.01, 0.03, M["hazy"], n=8, what="bande")
    g.cyl((x, y - L / 2 - 0.03, z), "y", r * 0.85, 0.06, M[st.get("flange_mat", "olive")], n=24, style="soft",
          what="flasque")
    bolts_ring(g, (x, y - L / 2 - 0.06, z), (0, -1, 0), r * 0.66, 8, M["rivet"], r=0.016)
    g.cyl((x, y - L / 2 - 0.08, z), "y", r * 0.3, 0.05, M[st["band"]], n=12, what="moyeu")


# --- culasse ---------------------------------------------------------------------------------------------
def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) habillée par l'époque, et pièce de signature de la culasse."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    T = PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)
    kind = st.get("recv_sig")
    zc = z1 + 0.012
    if kind == "lever":  # levier d'armement (forge)
        g.box((x + w * 0.52, (y0 + y1) / 2 - 0.08, (z0 + z1) / 2), (0.02, 0.2, 0.02), M["blackiron"], "hard",
              R=Matrix.Rotation(0.5, 3, "X"), what="levier")
        g.cyl((x + w * 0.52, (y0 + y1) / 2 - 0.16, z1 + 0.03), "x", 0.02, 0.04, M["brass"], n=8, what="pommeau")
    elif kind == "stripes":  # bandes noires de danger, écaillées (pétrole)
        for k in range(3):
            yy = y0 + (y1 - y0) * (0.2 + 0.3 * k)
            g.box((x, yy, zc + 0.002), (w * 0.9, 0.04, 0.008), M["hazk"], "flat", what="bande")
    elif kind == "scales":  # écailles de blindage (volcan)
        for i in range(3):
            for j in range(2):
                yy = y0 + 0.08 + (y1 - y0 - 0.16) * i / 2
                g.box((x + (j - 0.5) * w * 0.45, yy, zc + 0.02 + 0.006 * i), (w * 0.44, 0.13, 0.016), M["tungsten"],
                      "hard", R=Matrix.Rotation(-0.18, 3, "X"), what="ecaille")
    elif kind == "stone":  # bloc de pierre taillée (cristal)
        g.box((x, y0 + 0.08, zc + 0.03), (w * 0.8, 0.14, 0.06), M["stone"], "hard", what="pierre")
    elif kind == "porthole":  # hublot vert rond (atome)
        for s in (-1, 1):
            c = V((x + s * (w / 2 + 0.004), (y0 + y1) / 2, (z0 + z1) / 2))
            g.cyl(c, (s, 0, 0), 0.055, 0.02, M["steel_hi"], n=18, what="cadre")
            g.cyl(c + V((s * 0.012, 0, 0)), (s, 0, 0), 0.038, 0.006, M["emit"], n=18, style="flat", what="hublot")
            bolts_ring(g, c + V((s * 0.012, 0, 0)), (s, 0, 0), 0.047, 6, M["rivet"], r=0.012)
    return T


# --- alimentation ----------------------------------------------------------------------------------------
def feed(g, st, H, x, sx, xo):
    """Alimentation du canon (bande, tambour, bidons-chargeurs, caisson, cellules…), côté extérieur xo."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    kind = st["feed"]
    if kind == "crate_belt":  # caisse cerclée de fer posée sur le bras, bande de cartouches laiton
        c = V((xo + sx * 0.08, y0 + 0.12, zg - hr * 0.6))
        PT.crate(g, tuple(c), (0.16, 0.2, 0.14), mat=M["wood"])
        PT.belt(g, [(xo + sx * 0.08, y0 + 0.16, zg - hr * 0.6 + 0.16), (xo, y0 + 0.24, zg + 0.1),
                    (x + sx * wr * 0.3, y0 + 0.3, zg + hr + 0.02)], scale=0.8)
    elif kind == "drum":  # tambour à cartouches en laiton (vapeur) / tambours de la lignée (électricité)
        c = (xo + sx * 0.066, y0 + 0.12, zg - 0.02)
        r = 0.13 if H["R"] < 0.5 else 0.17
        g.cyl(c, (1, 0, 0), r, 0.13, M[st.get("drum_mat", "armor2")], n=32, style="soft", what="tambour")
        for s in (-1, 1):
            g.tube_shell(V(c) + V((s * 0.055, 0, 0)), (1, 0, 0), r + 0.016, r - 0.03, 0.026, M["brass"], n=32,
                         what="flasque")
            g.cyl(V(c) + V((s * 0.075, 0, 0)), (1, 0, 0), r * 0.32, 0.03, M["brass"], n=12, what="moyeu")
        bolts_ring(g, V(c) + V((sx * 0.08, 0, 0)), (sx, 0, 0), r - 0.025, 8, M["rivet"], r=0.014)
        PT.belt(g, [(xo + sx * 0.08, y0 + 0.2, zg + r * 0.9), (xo, y0 + 0.3, zg + r + 0.04),
                    (x + sx * wr * 0.3, y0 + 0.36, zg + hr + 0.02)], scale=0.85)
    elif kind == "barrels":  # 2 bidons-chargeurs couchés le long du canon (fûts à bandes noires)
        r = 0.115 if H["R"] < 0.8 else 0.13
        Lb = H["L"] * 0.46
        for k, mat in enumerate(("yellowpaint", "galva")):
            c = V((xo + sx * (r - 0.01), y0 + 0.1 + Lb / 2, zg - 0.03))
            if k == 1:
                c = V((xo + sx * (r - 0.01), y1 + 0.02 + Lb / 2, zg - 0.03))
            g.cyl(c, "y", r, Lb, M[mat], n=24, what="fut")
            for f in (-0.36, 0.0, 0.36):
                g.tube_shell(c + V((0, f * Lb, 0)), "y", r + 0.012, r - 0.01, 0.03, M["hazk"], n=24, what="bande")
            g.cyl(c + V((0, Lb / 2 + 0.012, 0)), "y", r * 0.86, 0.02, M[mat], n=24, what="fond")
            g.cyl(c + V((r * 0.4 * sx, Lb / 2 + 0.03, r * 0.4)), "y", 0.022, 0.03, M["brass"], n=8, what="bouchon")
            g.box(c + V((0, 0, r + 0.02)), (0.03, Lb * 0.3, 0.02), M["steel_hi"], "hard", what="poignee")
        P2.feed_chute(g, [(xo + sx * 0.1, y0 + 0.3, zg + r + 0.02), (xo, y0 + 0.36, zg + hr + 0.08),
                          (x + sx * wr * 0.25, y0 + 0.4, zg + hr + 0.06)], 0.1, M)
    elif kind == "armored":  # caisson blindé incliné à goulotte (volcan)
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
    elif kind == "crystal_mag":  # chargeurs à cartouches de cristal (étuis translucides violets)
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
    elif kind == "hoses":  # tuyaux souples depuis le bulbe dorsal (marais) : petite boîte d'alimentation
        bw, bl, bh = 0.18, H["L"] * 0.3, 0.2
        bx0, bx1 = sorted((xo, xo + sx * bw))
        PT.hull(g, bx0, bx1, y0 - 0.05, y0 - 0.05 + bl, zg - bh * 0.6, zg + bh * 0.4, ins=(0.015, 0.015, 0.015),
                panel=0.24, mats=[M["verdigris"], M["olive"]], rivet_step=0.11)
        bc = (bx0 + bx1) / 2
        g.cyl((bc, y0 + bl * 0.4, zg + bh * 0.4 + 0.03), "z", 0.05, 0.06, M["brass"], n=16, what="raccord")
        P2.gauge(g, (bc, y0 - 0.06, zg), (0, -1, 0.3), 0.04, M)
    elif kind == "lead_mag":  # magasins plombés à trèfle, goulotte annelée
        bw, bl, bh = 0.2, H["L"] * 0.34, 0.22
        bx0, bx1 = sorted((xo, xo + sx * bw))
        PT.hull(g, bx0, bx1, y0 - 0.05, y0 - 0.05 + bl, zg - bh * 0.62, zg + bh * 0.42, ins=(0.025, 0.025, 0.025),
                panel=0.24, mats=[M["lead"], M["lead"]], rivet_step=0.11)
        bc = (bx0 + bx1) / 2
        trefoil(g, (bc, y0 + bl * 0.4, zg + bh * 0.42 + 0.004), (0, 0, 1), 0.06)
        g.hose([(bc, y0 + bl * 0.75, zg + bh * 0.42), (bc - sx * 0.05, y0 + bl * 0.7, zg + hr + 0.06),
                (x + sx * wr * 0.2, y0 + bl * 0.6, zg + hr + 0.05)], 0.04, M["copper"], step=0.028)


def trefoil(g, c, nrm, r):
    """Trèfle de radioactivité (≤ 0,02 t²) : disque jaune, 3 secteurs et centre noirs."""
    M = g.M
    a, u, w = basis(V(nrm))
    c = V(c)
    g.cyl(c, a, r, 0.006, M["hazy"], n=20, style="flat", what="trefle")
    g.cyl(c + a * 0.004, a, r * 0.18, 0.004, M["hazk"], n=10, style="flat", what="trefle")
    for k in range(3):
        ang = math.pi / 2 + TAU * k / 3
        d = u * math.cos(ang) + w * math.sin(ang)
        g.cyl(c + a * 0.004 + d * r * 0.55, a, r * 0.3, 0.004, M["hazk"], n=10, style="flat", what="trefle")


# ------------------------------------------------------------------------------------------------
# E2 : tuyaux et liaisons du socle et de la tête
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne, dans le style de l'époque (catalogue, rubrique « Tuyaux »)."""
    M = g.M
    P = polyline_pts(ctrl)
    if e <= 2:
        # tuyau de fer noir à brides CARRÉES à 4 boulons (aucun cuivre)
        S_ = g.spline(P, 8)
        S_, T = g.tube(S_, r * 0.8, M["blackiron"], n=12, what="tuyau")
        for i in (0, len(S_) // 2, len(S_) - 1):
            Rr = Ry(T[i])
            g.box(S_[i], (r * 2.6, 0.03, r * 2.6), M["rawiron"], "hard", R=Rr, what="bride")
            for sx_ in (-1, 1):
                for sz_ in (-1, 1):
                    g.dome(S_[i] + Rr @ V((sx_ * r * 0.9, 0.016, sz_ * r * 0.9)), T[i], 0.014, M["brass"])
    elif e == 3:
        g.pipe(P, r * 0.85, M["copper_pol"], fl_mat=M["brass"], bolt_mat=M["rivet"])
    elif e == 4:
        g.pipe(P, r * 0.8, M["galva"], fl_mat=M["steel_dk"], bolt_mat=M["rivet"])
    elif e == 5:
        # conduit trapu en fonte à coudes VIFS, brides lourdes à 6 boulons, fente de braise sur le coude
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
    elif e == 6:
        PT.cable_run(g, P, 3, 0.02, 0.045, [M["rubber"], M["redcable"], M["rubber"]])
        for p in P[1:-1]:
            zz = p.z
            g.cyl((p.x, p.y, zz - 0.07), "z", 0.02, 0.1, M["steel_dk"], n=8, what="support")
            PT.insulators(g, (p.x, p.y, zz - 0.02), 2, 0.032, h=0.026)
    elif e == 7:
        # guide d'onde de bronze à section carrée, joints cannelés, coudes à 45°
        for i in range(len(P) - 1):
            a, b = P[i], P[i + 1]
            d = b - a
            Rr = Ry(d)
            g.box((a + b) / 2, (r * 1.7, d.length, r * 1.7), M["bronze"], "hard", R=Rr, what="guide")
            n = max(1, int(d.length / 0.16))
            for k in range(n + 1):
                q = a + d * (k / n)
                g.box(q, (r * 2.1, 0.03, r * 2.1), M["brass"] if k % 2 else M["stone"], "hard", R=Rr, what="joint")
    elif e == 8:
        S_ = g.hose(P, r * 0.9, M["rubber"], step=0.03)
        mid = len(S_) // 2
        if len(S_) > 6:
            a, b = S_[mid - 3], S_[mid + 3]
            d = b - a
            g.cyl((a + b) / 2, d, r * 0.95, d.length, M["emit_soft"], n=14, what="tube_verre")
            for q in (a, b):
                g.cyl(q, d, r * 1.25, 0.03, M["brass"], n=14, style="hard", what="virole")
    else:
        # gaine annelée de cuivre (réacteur vanilla) et raccords à bandes jaunes et noires
        S_ = g.hose(P, r, M["copper"], step=0.03)
        for q in (S_[0], S_[-1]):
            g.tube_shell(q, (S_[1] - S_[0]) if q is S_[0] else (S_[-1] - S_[-2]), r * 1.35, r * 0.8, 0.05,
                         M["hazy"], n=14, what="raccord")
    return P


# ------------------------------------------------------------------------------------------------
# E5 : petits groupes de voyants (au plus 3, espacements inégaux, formes mêlées) au lieu des rangées
# ------------------------------------------------------------------------------------------------
def lamp_group(g, p, along, nrm, emat, n=3, sizes=(0.028, 0.02, 0.024), gaps=(0.07, 0.045)):
    M = g.M
    a, u, w = basis(V(nrm))
    t = V(along).normalized()
    p = V(p)
    off = 0.0
    for i in range(min(3, n)):
        q = p + t * off
        s = sizes[i % len(sizes)]
        if i == 1:
            Rr = Matrix((t, a.cross(t).normalized(), a)).transposed()
            g.box(q + a * 0.012, (s * 2.2, s * 1.1, 0.02), M["steel_dk"], "hard", R=Rr, what="bague")
            g.box(q + a * 0.024, (s * 1.6, s * 0.6, 0.006), emat, "flat", R=Rr, what="voyant")
        else:
            g.cyl(q + a * 0.01, a, s * 0.95, 0.02, M["steel_dk"], n=10, style="hard", what="bague")
            g.cyl(q + a * 0.022, a, s * 0.62, 0.006, emat, n=10, style="flat", what="voyant")
        off += gaps[i % len(gaps)]


def cabinet_e(g, x0, x1, y0, y1, z0, z1, M, emat, mats, lamps=2):
    """Armoire de commande de la lignée, sans rangée régulière de voyants (catalogue §A.6)."""
    PT.hull(g, x0, x1, y0, y1, z0, z1, ins=(0.015, 0.015, 0.015), panel=0.24, mats=mats, rivet_step=0.12)
    w = x1 - x0
    if lamps:
        lamp_group(g, (x0 + w * 0.16, y0 - 0.02, z0 + (z1 - z0) * 0.72), (1, 0, 0), (0, -1, 0), emat, n=lamps)
    P2.gauge(g, (x0 + w * 0.3, y0 - 0.02, z0 + (z1 - z0) * 0.32), (0, -1, 0.2), 0.045, M)
    P2.gauge(g, (x0 + w * 0.72, y0 - 0.02, z0 + (z1 - z0) * 0.38), (0, -1, 0.2), 0.038, M)
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, z1 + 0.02), (w + 0.06, y1 - y0 + 0.06, 0.03), M["steel_dk"], "hard",
          what="toit")


# ------------------------------------------------------------------------------------------------
# Socle : machines de la lignée habillées (groupe, réservoir) et signatures d'époque
# ------------------------------------------------------------------------------------------------
def engine_e(g, e, x0, x1, y0, y1, z0, z1, ncyl, emat=None):
    """Groupe électrogène de la lignée (P2.engine) : même volume, habillage d'époque, signature posée dessus."""
    M = g.M
    hullm = {2: ["bolted", "blackiron"], 3: ["castiron", "olive"], 4: ["yellowpaint", "steel_dk"],
             5: ["tungsten", "burnrust"], 6: ["olive", "steel_dk"], 7: ["bronze", "stone"],
             8: ["verdigris", "olive"], 9: ["lead", "steel_dk"]}[e]
    head = {2: "rawiron", 3: "copper_pol", 4: "redpaint", 5: "burnrust", 6: "redpaint", 7: "bronze",
            8: "verdigris", 9: "lead"}[e]
    PT.hull(g, x0, x1, y0, y1, z0, z1, ins=(0.05, 0.03, 0.03), panel=0.3, mats=[M[k] for k in hullm],
            rivet_step=0.14)
    cx = (x0 + x1) / 2
    wx = x1 - x0
    L = (y1 - y0) - 0.24
    pitch = L / ncyl
    zt = z1
    for i in range(ncyl):
        y = y0 + 0.12 + pitch * (i + 0.5)
        g.box((cx - wx * 0.08, y, zt + 0.06), (wx * 0.42, pitch * 0.78, 0.12), M[head], "soft", what="culasse")
        for k in range(3):
            g.box((cx - wx * 0.08 + (k - 1) * wx * 0.12, y, zt + 0.125), (0.03, pitch * 0.66, 0.02), M[head],
                  "hard", what="nervure")
        for sy in (-1, 1):
            g.bolt((cx - wx * 0.28, y + sy * pitch * 0.3, zt + 0.12), (0, 0, 1), 0.016, M["steel_hi"])
        g.tube([V((cx + wx * 0.12, y, zt + 0.06)), V((cx + wx * 0.24, y, zt + 0.12)), V((cx + wx * 0.3, y, zt + 0.2))],
               0.03, M["soot"], n=8, what="tubulure")
    zm = zt + 0.24
    g.cyl((cx + wx * 0.3, (y0 + y1) / 2, zm), "y", 0.09, L * 0.92, M["soot"], n=20, style="smooth", what="silencieux")
    for f in (-0.36, 0.0, 0.36):
        g.tube_shell((cx + wx * 0.3, (y0 + y1) / 2 + f * L, zm), "y", 0.108, 0.07, 0.035,
                     M[{2: "rawiron", 3: "brass", 4: "galva", 5: "tungsten", 6: "steel_dk", 7: "bronze",
                        8: "rubber", 9: "hazy"}[e]], n=20, what="collier")
    # signature d'époque sur le groupe
    yf = y0 - 0.08
    zc = (z0 + z1) * 0.55
    rf = (z1 - z0) * 0.48
    if e == 2:  # volant d'inertie à rayons, chaîne de transmission
        g.cyl((cx, yf, zc), "y", rf * 1.15, 0.08, M["blackiron"], n=40, style="soft", what="volant")
        g.tube_shell((cx, yf - 0.01, zc), "y", rf * 1.15, rf * 0.95, 0.1, M["rawiron"], n=40, what="jante")
        for k in range(6):
            ang = TAU * k / 6
            d = V((math.cos(ang), 0, math.sin(ang)))
            g.box(V((cx, yf - 0.05, zc)) + d * rf * 0.5, (0.035, 0.03, rf * 0.9), M["blackiron"], "hard",
                  R=Matrix((d.cross(V((0, 1, 0))), V((0, 1, 0)), d)).transposed(), what="rayon")
        g.cyl((cx, yf - 0.07, zc), "y", 0.05, 0.06, M["brass"], n=12, what="moyeu")
    elif e == 3:  # régulateur à boules
        zb = zt + 0.16
        g.cyl((cx - wx * 0.3, y1 - 0.2, zb + 0.08), "z", 0.014, 0.2, M["steel_hi"], n=8, what="axe")
        for s in (-1, 1):
            g.cyl((cx - wx * 0.3 + s * 0.05, y1 - 0.2, zb + 0.12), (s * 0.7, 0, 0.7), 0.008, 0.12, M["steel_hi"], n=6,
                  what="bras")
            sphere(g, (cx - wx * 0.3 + s * 0.1, y1 - 0.2, zb + 0.08), 0.035, M["brass"], n=12, m=8, what="boule")
        g.cyl((cx - wx * 0.3, y1 - 0.2, zb + 0.19), "z", 0.03, 0.03, M["brass"], n=12, what="chapeau")
        P2.gauge(g, (x0 - 0.01, (y0 + y1) / 2, (z0 + z1) * 0.6), (-1, 0, 0.2), 0.05, M)
    elif e == 4:  # capot jaune à pochoirs, vanne à volant rouge
        g.box((cx - wx * 0.08, y0 + 0.06, zt + 0.02), (wx * 0.6, 0.12, 0.04), M["hazk"], "flat", what="pochoir")
        P2.handwheel(g, (x0 - 0.06, y0 + 0.2, (z0 + z1) * 0.5), (-1, 0, 0.2), 0.08, M)
    elif e == 5:  # pointes de basalte aux arêtes, fentes de braise
        for k in range(3):
            yy = y0 + 0.12 + (y1 - y0 - 0.24) * k / 2
            g.cyl((x0 + 0.02, yy, z1 + 0.05), (-0.4, 0, 1), 0.035, 0.14, M["basalt"], n=5, r2=0.004, style="hard",
                  what="pointe")
            g.box((x0 - 0.004, yy + 0.06, (z0 + z1) * 0.5), (0.008, 0.08, 0.016), M["emit"], "flat", what="braise")
    elif e == 6:  # bobines de cuivre rondes
        for s in (0, 1):
            yy = y0 + 0.2 + s * 0.3
            g.cyl((x0 - 0.06, yy, (z0 + z1) * 0.5), "x", 0.08, 0.1, M["steel_dk"], n=20, what="noyau")
            for t in range(4):
                g.torus((x0 - 0.1 + t * 0.026, yy, (z0 + z1) * 0.5), "x", 0.085, 0.012, M["copper"], n=24, m=6,
                        what="spire")
    elif e == 7:  # grappe de cristaux sertie
        crystals(g, (cx + wx * 0.2, y1 - 0.18, zt + 0.02), 0.6)
    elif e == 8:  # bocaux de prélèvement
        for k in range(2):
            jar(g, (x0 - 0.05, y0 + 0.2 + k * 0.22, (z0 + z1) * 0.35), 0.045, 0.1)
    elif e == 9:  # trèfle, bande jaune
        trefoil(g, (cx - wx * 0.15, y0 + 0.3, zt + 0.004), (0, 0, 1), 0.06)
        g.box((x0 - 0.004, (y0 + y1) / 2, (z0 + z1) * 0.7), (0.008, y1 - y0 - 0.1, 0.035), M["hazy"], "flat",
              what="bande")
    if emat is not None and e >= 3:
        lamp_group(g, (cx - wx * 0.35, y1 + 0.01, (z0 + z1) * 0.6), (1, 0, 0), (0, 1, 0), emat, n=2)


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


def jar(g, c, r, h):
    """Bocal de prélèvement (marais) : verre lumineux, couvercle et cerclage laiton."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + h / 2), "z", r, h, M["emit_soft"], n=14, what="bocal")
    g.cyl((x, y, z + h + 0.012), "z", r + 0.008, 0.024, M["brass"], n=14, what="couvercle")
    g.tube_shell((x, y, z + 0.01), "z", r + 0.008, r - 0.004, 0.02, M["brass"], n=14, what="cerclage")
    g.box((x + r, y, z + h / 2), (0.02, 0.02, h), M["steel_dk"], "hard", what="patte")


def tank_e(g, e, x, y, r, h, emat, ladder_dir=(1, 0.3), stub_dir=(-1, 0), gauges=2, rings=0):
    """Réservoir debout de la lignée (P3.vtank), habillé par l'époque ; à l'époque 4 il devient une cuve couchée sur
    berceau (même place, même masse)."""
    M = g.M
    if e == 4:
        L = h * 1.4
        zc = 0.08 + r * 0.82
        P2.tank(g, (x, y, zc), r * 0.82, L, (0, 1, 0), M, paint=M["yellowpaint"], band=M["galva"], gauges=1)
        for f in (-0.3, 0.3):
            g.box((x, y + f * L, zc - r * 0.5), (r * 1.7, 0.08, zc), M["steel_dk"], "hard", what="berceau")
        # jauge de niveau verticale (tube de verre ambré dans un cadre), garde-corps
        g.box((x - r * 0.84, y - L * 0.15, zc), (0.02, 0.05, r * 1.2), M["emit_soft"], "flat", what="jauge")
        for s in (-1, 1):
            g.box((x - r * 0.86, y - L * 0.15 + s * 0.035, zc), (0.02, 0.016, r * 1.3), M["steel_hi"], "hard",
                  what="cadre")
        rail(g, [(x - r * 0.5, y - L * 0.45, zc + r * 0.82), (x - r * 0.5, y + L * 0.45, zc + r * 0.82)], 0.14)
        rail(g, [(x + r * 0.5, y - L * 0.45, zc + r * 0.82), (x + r * 0.5, y + L * 0.45, zc + r * 0.82)], 0.14)
        P2.handwheel(g, (x, y - L / 2 - 0.12, zc), (0, -1, 0), 0.07, M)
        return
    paint = {2: "bolted", 3: "rawiron", 5: "tungsten", 6: "cream", 7: "bronze", 8: "verdigris", 9: "lead"}[e]
    P3.vtank(g, x, y, r, h, M, paint=M[paint], emat=(emat if e >= 3 else None), ladder_dir=ladder_dir,
             stub_dir=stub_dir, gauges=gauges, glow_gauges=(e >= 6), glow_rings=rings)
    bandm = {2: "blackiron", 3: "brass", 5: "burnrust", 6: "brass", 7: "stone", 8: "rubber", 9: "hazy"}[e]
    zb, zt = 0.08, h
    for i in range(2):
        g.tube_shell((x, y, zb + (zt - zb) * (0.2 + 0.6 * i)), "z", r + 0.024, r - 0.01, 0.03, M[bandm], n=40,
                     what="cerclage")
    if e == 3:  # chaudière : hublot ambré, sifflet
        d = V((-0.6, -0.8, 0)).normalized()
        c = V((x, y, zb + (zt - zb) * 0.35)) + d * (r + 0.006)
        g.cyl(c, d, 0.05, 0.02, M["brass"], n=16, what="hublot_cadre")
        g.cyl(c + d * 0.012, d, 0.034, 0.006, emat, n=16, style="flat", what="hublot")
        bolts_ring(g, c + d * 0.012, d, 0.043, 6, M["rivet"], r=0.012)
        g.cyl((x + r * 0.3, y + r * 0.3, zt + r * 0.42 + 0.06), "z", 0.018, 0.12, M["brass"], n=10, what="sifflet")
        g.cyl((x + r * 0.3, y + r * 0.3, zt + r * 0.42 + 0.13), "z", 0.026, 0.03, M["brass"], n=10, what="cloche")
    elif e == 5:  # écailles et fente de braise
        for k in range(5):
            a = -math.pi / 2 + (k - 2) * 0.45
            d = V((math.cos(a), math.sin(a), 0))
            g.box(V((x, y, zt * 0.55)) + d * (r + 0.016), (0.1, 0.02, 0.16), M["tungsten"], "hard",
                  R=Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed() @ Matrix.Rotation(-0.2, 3, "X"),
                  what="ecaille")
        d = V((0, -1, 0))
        g.box(V((x, y, zt * 0.32)) + d * (r + 0.004), (0.12, 0.008, 0.02), emat, "flat", what="braise")
    elif e == 7:
        crystals(g, (x - r * 0.2, y + r * 0.1, zt + r * 0.3), 0.55)
        g.cyl((x, y, 0.05), "z", r + 0.1, 0.1, M["stone"], n=8, style="hard", what="plinthe")
    elif e == 8:  # bande de verre sur la hauteur (même volume)
        d = V((-0.5, -0.86, 0))
        Rr = Matrix((V((-d.y, d.x, 0)), d, V((0, 0, 1)))).transposed()
        g.box(V((x, y, (zb + zt) / 2)) + d * (r + 0.004), (0.07, 0.012, (zt - zb) * 0.7), M["emit_soft"], "flat",
              R=Rr, what="verre")
        for s in (-1, 1):
            g.box(V((x, y, (zb + zt) / 2)) + d * (r + 0.01) + V((-d.y, d.x, 0)) * s * 0.045,
                  (0.02, 0.02, (zt - zb) * 0.74), M["brass"], "hard", R=Rr, what="cadre")
        jar(g, (x + r * 0.75, y - r * 0.75, 0.0), 0.04, 0.09)
    elif e == 9:
        for a in (-math.pi / 2 - 0.4, -math.pi / 2 + 0.6):
            d = V((math.cos(a), math.sin(a), 0))
            c = V((x, y, zt * 0.62)) + d * (r + 0.004)
            g.cyl(c, d, 0.05, 0.02, M["steel_hi"], n=18, what="cadre")
            g.cyl(c + d * 0.012, d, 0.034, 0.006, emat, n=18, style="flat", what="hublot")
        trefoil(g, V((x, y, zt * 0.32)) + V((0, -1, 0)) * (r + 0.006), (0, -1, 0), 0.05)


def rail(g, pts, h):
    """Garde-corps : montants et lisses fines (lignes fines, en plus de la masse)."""
    M = g.M
    P = polyline_pts(pts)
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        d = b - a
        n = max(1, int(d.length / 0.2))
        for k in range(n + 1):
            q = a + d * (k / n)
            g.cyl(q + V((0, 0, h / 2)), "z", 0.01, h, M["hazy"], n=6, what="montant")
        for zz in (h, h * 0.55):
            g.cyl((a + b) / 2 + V((0, 0, zz)), d, 0.009, d.length, M["hazy"], n=6, what="lisse")


def chain(g, p0, p1, sag=0.05):
    """Chaîne de transmission (forge) : maillons alternés."""
    M = g.M
    p0, p1 = V(p0), V(p1)
    n = max(4, int((p1 - p0).length / 0.035))
    for i in range(n):
        t = (i + 0.5) / n
        p = p0.lerp(p1, t)
        p.z -= sag * 4 * t * (1 - t)
        d = (p1 - p0).normalized()
        if i % 2:
            g.torus(p, d.cross(V((0, 0, 1))), 0.016, 0.006, M["blackiron"], n=8, m=4, what="maillon")
        else:
            g.torus(p, V((0, 0, 1)), 0.016, 0.006, M["blackiron"], n=8, m=4, what="maillon")


def duct(g, pts, w, h):
    """Conduit d'air rectangulaire en tôle rivetée (forge, venu d'un soufflet)."""
    M = g.M
    P = polyline_pts(pts)
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        d = b - a
        Rr = Ry(d)
        g.box((a + b) / 2, (w, d.length + w * 0.5, h), M["rawiron"], "hard", R=Rr, what="conduit")
        n = max(2, int(d.length / 0.11))
        for k in range(n):
            q = a + d * ((k + 0.5) / n)
            for s in (-1, 1):
                g.dome(q + Rr @ V((s * w * 0.38, 0, h / 2 + 0.002)), (0, 0, 1), 0.013, M["rivet"])
        g.box(b, (w + 0.03, 0.03, h + 0.03), M["blackiron"], "hard", R=Rr, what="bride")


def chimney(g, c, r, h, emat=None):
    """Cheminée ronde courte à collerette (vapeur) : fût riveté, cerclages laiton, collerette, suie."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + 0.03), "z", r * 1.35, 0.06, M["castiron"], n=20, style="soft", what="embase")
    bolts_ring(g, (x, y, z + 0.06), (0, 0, 1), r * 1.15, 8, M["rivet"], r=0.012)
    g.cyl((x, y, z + h / 2), "z", r, h, M["bolted"], n=20, r2=r * 0.92, what="fut")
    for f in (0.35, 0.75):
        g.tube_shell((x, y, z + h * f), "z", r + 0.014, r - 0.01, 0.025, M["brass"], n=20, what="cerclage")
    g.tube_shell((x, y, z + h + 0.01), "z", r * 1.45, r * 0.8, 0.03, M["steel_dk"], n=20, what="collerette")
    g.cyl((x, y, z + h + 0.002), "z", r * 0.8, 0.01, M["soot"], n=16, style="flat", what="suie")


def tower(g, c, r, h):
    """Petite tour de refroidissement hyperboloïde (atome), béton à bandes."""
    M = g.M
    x, y, z = c
    prof = [(0.0, 1.0), (0.3, 0.8), (0.55, 0.72), (0.8, 0.78), (1.0, 0.86)]
    for i in range(len(prof) - 1):
        z0_, r0 = prof[i]
        z1_, r1 = prof[i + 1]
        g.cyl((x, y, z + h * (z0_ + z1_) / 2), "z", r * r0, h * (z1_ - z0_), M["concrete"], n=24, r2=r * r1,
              what="tour")
    g.tube_shell((x, y, z + h), "z", r * 0.88, r * 0.74, 0.03, M["steel_dk"], n=24, what="levre")
    g.cyl((x, y, z + h - 0.01), "z", r * 0.75, 0.01, M["void"], n=20, style="flat", what="bouche")
    g.tube_shell((x, y, z + h * 0.15), "z", r * 0.98, r * 0.85, 0.03, M["hazy"], n=24, what="bande")
    for k in range(6):
        a = TAU * k / 6
        g.box((x + math.cos(a) * r * 0.95, y + math.sin(a) * r * 0.95, z + 0.04), (0.03, 0.03, 0.08), M["steel_dk"],
              "hard", what="pied")


def flare(g, c, h, emat):
    """Petite torchère (pétrole) : tige fine, brûleur, flamme (≤ 0,05 t²)."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + h / 2), "z", 0.018, h, M["galva"], n=8, what="tige")
    g.cyl((x, y, z + h + 0.02), "z", 0.03, 0.04, M["soot"], n=10, what="bruleur")
    g.cyl((x, y, z + h + 0.07), "z", 0.024, 0.08, emat, n=8, r2=0.004, what="flamme")
    g.box((x, y, z + 0.04), (0.08, 0.08, 0.02), M["steel_dk"], "hard", what="pied")


# ------------------------------------------------------------------------------------------------
# E6 : pièces des niveaux pairs (paire, coins avant, ≥ 0,10 t² de masque nouveau)
# ------------------------------------------------------------------------------------------------
def sandbag(g, c, rz, L=0.26, w=0.13, h=0.08, mat=None):
    """Sac de sable : coussin aplati à plis (coutures, coins pincés)."""
    M = g.M
    m = mat or M["canvas"]
    g.push(c, rz=rz)
    n, mseg = 14, 7
    vs = []
    for i in range(mseg + 1):
        t = -1 + 2 * i / mseg
        for j in range(n):
            a = TAU * j / n
            sx = math.cos(a)
            sz = math.sin(a)
            k = (1 - 0.35 * abs(t) ** 3)
            vs.append((t * L / 2 * (1 - 0.08 * abs(sz)), sx * w / 2 * k, h / 2 + sz * h / 2 * k * (0.9 + 0.1 * math.cos(9 * t))))
    fs = []
    for i in range(mseg):
        for j in range(n):
            j2 = (j + 1) % n
            fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
    fs.append(tuple(range(n))[::-1])
    fs.append(tuple(range(mseg * n, (mseg + 1) * n)))
    g._add(m, "smooth", vs, fs, "sac")
    g.box((L * 0.47, 0, h * 0.55), (0.02, w * 0.5, h * 0.4), M["canvas2"], "soft", what="ligature")
    g.pop()


def sandbag_wall(g, pts, rows=2, L=0.26, w=0.13, h=0.075):
    """Muret de sacs de sable le long d'une polyligne (sol), rangs décalés."""
    M = g.M
    P = polyline_pts(pts)
    k = 0
    for row in range(rows):
        for i in range(len(P) - 1):
            a, b = P[i], P[i + 1]
            d = b - a
            n = max(1, int(round(d.length / (L * 0.92))))
            ang = math.atan2(d.y, d.x)
            for s in range(n):
                t = (s + 0.5 + 0.5 * (row % 2)) / (n + 0.5 * (row % 2))
                if t > 1.0:
                    continue
                p = a + d * t
                inset = row * 0.02
                nrm = V((-d.y, d.x, 0)).normalized()
                p = p + nrm * inset
                k += 1
                sandbag(g, (p.x, p.y, row * h * 0.86), ang + 0.08 * ((k * 7) % 3 - 1), L, w, h,
                        M["canvas"] if (k % 3) else M["canvas2"])


def wood_crate(g, c, size, rz=0.0, open_=True, belts=True):
    """Caisse de munitions en bois cerclée de fer, ouverte, bandes de cartouches laiton qui pendent."""
    M = g.M
    sx, sy, sz = size
    g.push(c, rz=rz)
    n = max(2, int(sz / 0.05))
    for side in ((0, -sy / 2, sx, 0.025), (0, sy / 2, sx, 0.025)):
        for k in range(n):
            g.box((side[0], side[1], sz * (k + 0.5) / n), (side[2], side[3], sz / n - 0.006),
                  M["wood"] if k % 2 else M["wood2"], "hard", what="planche")
    for xx in (-sx / 2, sx / 2):
        for k in range(n):
            g.box((xx, 0, sz * (k + 0.5) / n), (0.025, sy, sz / n - 0.006), M["wood"] if k % 2 else M["wood2"], "hard",
                  what="planche")
    g.box((0, 0, sz * 0.45), (sx - 0.04, sy - 0.04, sz * 0.9), M["seam"], "flat", what="fond")
    for zz in (0.03, sz - 0.03):
        for (cx, cy, w_, d_) in ((0, -sy / 2 - 0.014, sx + 0.03, 0.012), (0, sy / 2 + 0.014, sx + 0.03, 0.012),
                                 (-sx / 2 - 0.014, 0, 0.012, sy + 0.03), (sx / 2 + 0.014, 0, 0.012, sy + 0.03)):
            g.box((cx, cy, zz), (w_, d_, 0.025), M["rawiron"], "hard", what="cerclage")
    for (cx, cy) in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2)):
        g.box((cx, cy, sz / 2), (0.035, 0.035, sz + 0.01), M["rawiron"], "hard", what="cornière")
        g.dome((cx, cy - 0.02 if cy < 0 else cy + 0.02, sz * 0.5), (0, -1 if cy < 0 else 1, 0), 0.012, M["rivet"])
    if open_:
        nx = max(1, int((sx - 0.06) / 0.05))
        ny = max(1, int((sy - 0.06) / 0.05))
        for i in range(nx):
            for j in range(ny):
                x = -(nx - 1) * 0.025 + i * 0.05
                y = -(ny - 1) * 0.025 + j * 0.05
                g.cyl((x, y, sz - 0.02), "z", 0.016, 0.04, M["brass"], n=8, what="etui")
                g.cyl((x, y, sz + 0.012), "z", 0.012, 0.024, M["copper"], n=8, r2=0.004, what="balle")
        g.box((0, sy / 2 + 0.03, sz + 0.09), (sx * 0.96, 0.025, 0.2), M["wood"], "hard",
              R=Matrix.Rotation(-0.3, 3, "X"), what="couvercle")
    if belts:
        PT.belt(g, [(-sx * 0.3, -sy / 2 + 0.02, sz + 0.02), (-sx * 0.32, -sy / 2 - 0.05, sz * 0.6),
                    (-sx * 0.2, -sy / 2 - 0.1, 0.03)], scale=0.6)
    g.pop()


def lantern(g, c, emat):
    """Lanterne à huile (nuit seulement) : cage de fer, verre, anse."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + 0.01), "z", 0.03, 0.02, M["rawiron"], n=10, what="pied")
    g.cyl((x, y, z + 0.05), "z", 0.022, 0.06, emat, n=10, what="verre")
    for k in range(4):
        a = TAU * k / 4 + 0.4
        g.box((x + math.cos(a) * 0.024, y + math.sin(a) * 0.024, z + 0.05), (0.008, 0.008, 0.07), M["rawiron"], "hard",
              what="cage")
    g.cyl((x, y, z + 0.09), "z", 0.028, 0.02, M["rawiron"], n=10, r2=0.012, what="chapeau")
    g.torus((x, y, z + 0.115), (1, 0, 0), 0.02, 0.005, M["rawiron"], n=10, m=4, what="anse")


def mantlet(g, c, rz, w=0.36, h=0.28):
    """Mantelet d'acier (forge) : bouclier plat sur pieds, riveté, à créneau de visée, appuyé contre 2 caisses."""
    M = g.M
    g.push(c, rz=rz)
    t = 0.04
    PT.hull(g, -w / 2, w / 2, -t / 2, t / 2, 0.0, h, ins=(0.0, 0.0, 0.0), panel=0.2, mats=[M["bolted"], M["rawiron"]],
            faces="tsn", rivet_step=0.1)
    g.box((0, -t / 2 - 0.004, h * 0.72), (0.07, 0.01, 0.04), M["void"], "flat", what="creneau")
    for s in (-1, 1):
        g.box((s * w * 0.36, t / 2 + 0.07, h * 0.3), (0.03, 0.16, 0.025), M["blackiron"], "hard",
              R=Matrix.Rotation(0.75, 3, "X"), what="bequille")
        g.box((s * w * 0.36, t / 2 + 0.13, 0.015), (0.06, 0.06, 0.03), M["blackiron"], "hard", what="semelle")
    g.box((0, -t / 2 - 0.01, h - 0.02), (w + 0.02, 0.02, 0.035), M["rawiron"], "hard", what="rebord")
    g.pop()


def mortar(g, c, rz, s=1.0):
    """Mortier trapu blindé (volcan) : tube court et gros incliné vers l'avant, affût à écailles."""
    M = g.M
    g.push(c, rz=rz)
    prism(g, [(-0.17 * s, -0.17 * s), (0.17 * s, -0.17 * s), (0.17 * s, 0.17 * s), (-0.17 * s, 0.17 * s)], 0.0,
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


def spark_stack(g, c, emat, s=1.0):
    """Pile de condensateurs à éclateur (électricité) : colonne d'isolateurs trapue coiffée d'un tore de Tesla."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z + 0.04), "z", 0.12 * s, 0.08, M["steel_dk"], n=20, style="soft", what="embase")
    bolts_ring(g, (x, y, z + 0.08), (0, 0, 1), 0.1 * s, 6, M["rivet"], r=0.013)
    g.cyl((x, y, z + 0.08 + 0.07 * s), "z", 0.08 * s, 0.14 * s, M["olive"], n=18, what="condensateur")
    g.tube_shell((x, y, z + 0.12 + 0.07 * s), "z", 0.088 * s, 0.07 * s, 0.025, M["brass"], n=18, what="cerclage")
    zt = PT.insulators(g, (x, y, z + 0.08 + 0.14 * s), 4, 0.06 * s, h=0.035)
    g.torus((x, y, zt + 0.03), "z", 0.075 * s, 0.024 * s, M["copper"], n=24, m=8, what="tore")
    g.cyl((x, y, zt + 0.03), "z", 0.035, 0.05, M["copper"], n=10, what="borne")
    return zt + 0.06


def focaliser(g, c, rz, s=1.0):
    """Focalisateur à cristal (cristal) : plinthe de pierre, affût de bronze, grappe de 3 cristaux vers l'avant."""
    M = g.M
    g.push(c, rz=rz)
    prism(g, [(-0.16 * s, -0.16 * s), (0.16 * s, -0.16 * s), (0.16 * s, 0.16 * s), (-0.16 * s, 0.16 * s)], 0.0,
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


def demijohn(g, c, emat, s=1.0):
    """Bonbonne de verre sur berceau à pompe (marais) : sphère cerclée, cage, manomètre."""
    M = g.M
    x, y, z = c
    r = 0.13 * s
    g.box((x, y, z + 0.035), (0.3 * s, 0.3 * s * SQ2 * 0.8, 0.07), M["steel_dk"], "hard", what="berceau")
    zc = z + 0.07 + r * 0.95
    sphere(g, (x, y, zc), r, emat, n=20, m=12, what="bonbonne")
    g.torus((x, y, zc), "z", r + 0.004, 0.012, M["brass"], n=24, m=6, what="cerclage")
    for k in range(6):
        a = TAU * k / 6
        g.box((x + math.cos(a) * (r + 0.012), y + math.sin(a) * (r + 0.012), zc), (0.016, 0.016, r * 2.0),
              M["verdigris"], "hard", what="cage")
    g.cyl((x, y, zc + r + 0.025), "z", 0.04, 0.05, M["brass"], n=12, what="col")
    g.cyl((x + 0.12 * s, y - 0.06 * s, z + 0.13), "z", 0.035, 0.12, M["olive"], n=12, what="pompe")
    P2.gauge(g, (x + 0.12 * s, y - 0.06 * s - 0.036, z + 0.16), (0, -1, 0.3), 0.032, M)
    g.hose([(x + 0.12 * s, y - 0.06 * s, z + 0.19), (x + 0.08 * s, y - 0.02, zc + r * 0.7), (x, y, zc + r + 0.04)],
           0.016, M["rubber"], step=0.02)


def lead_chest(g, c, rz, emat, s=1.0):
    """Conteneur plombé (atome) : coffre chanfreiné, trèfle, hublot vert, poignées."""
    M = g.M
    g.push(c, rz=rz)
    w, d, h = 0.34 * s, 0.26 * s, 0.22 * s
    ch = 0.05 * s
    bot = [(-w / 2 + ch, -d / 2), (w / 2 - ch, -d / 2), (w / 2, -d / 2 + ch), (w / 2, d / 2 - ch),
           (w / 2 - ch, d / 2), (-w / 2 + ch, d / 2), (-w / 2, d / 2 - ch), (-w / 2, -d / 2 + ch)]
    prism(g, bot, 0.0, h, M["lead"])
    prism(g, [(px * 0.86, py * 0.86) for px, py in bot], h, h + 0.04, M["lead"])
    g.box((0, 0, h * 0.25), (w + 0.01, d + 0.01, 0.03), M["hazy"], "hard", what="bande")
    trefoil(g, (0, 0, h + 0.042), (0, 0, 1), 0.06 * s)
    g.cyl((w * 0.28, -d / 2 - 0.004, h * 0.6), "y", 0.04, 0.02, M["steel_hi"], n=16, what="cadre")
    g.cyl((w * 0.28, -d / 2 - 0.014, h * 0.6), "y", 0.027, 0.006, emat, n=16, style="flat", what="hublot")
    for sx in (-1, 1):
        g.box((sx * (w / 2 + 0.015), 0, h * 0.7), (0.02, d * 0.4, 0.03), M["steel_hi"], "hard", what="poignee")
    for (px, py) in bot[::2]:
        g.dome((px * 0.9, py * 0.9, h + 0.042), (0, 0, 1), 0.015, M["rivet"])
    g.pop()
