"""Kit de géométrie en Python PUR (aucune dépendance) pour l'exploration « hybride progressive » de la
mitrailleuse (lot V3-S, 22/10/2026).

Pourquoi un kit à part (et pas les primitives bpy de fo_scene) :
- une pièce de 6×6 porte des milliers de petites pièces (rivets, boulons, lamelles, cartouches, colliers) ;
  créées une par une avec bpy.ops, elles coûtent des minutes ; ici elles sont accumulées en listes de sommets et
  de faces, UN maillage par matériau, puis remis à Blender en une fois (blender_build.py) ;
- la même géométrie sert à un APERÇU HORS BLENDER (apercu.py : projection du pipeline, peintre, Lambert) pour
  régler masse, remplissage, dépassement et composition sans prendre le verrou de rendu.

Conventions (tools/render/README.md, CALIBRATION.md §2) : 1 unité = largeur d'une tuile ; +X est, +Y nord,
+Z haut ; origine = position de l'entité au sol ; une tuile de jeu vers le sud = 1,414 unité en Y (gy()).
Tout élément fait au moins 2 px HR (0,031 unité) : MIN_T.
Déterministe : aucune source d'aléa autre que random.Random(graine) passé explicitement.
"""
import math

SQ2 = math.sqrt(2.0)
TAU = 2.0 * math.pi
MIN_T = 0.032          # épaisseur minimale (2 px HR)


def gy(ty):
    """y de jeu (tuiles, vers le sud) -> Y Blender."""
    return -ty * SQ2


# ------------------------------------------------------------------------------------------------
# Algèbre minimale
# ------------------------------------------------------------------------------------------------
def v_add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def v_sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def v_mul(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def v_dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def v_cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def v_len(a):
    return math.sqrt(v_dot(a, a))


def v_norm(a):
    n = v_len(a)
    return (a[0] / n, a[1] / n, a[2] / n) if n > 1e-12 else (0.0, 0.0, 1.0)


def m_mul(A, B):
    return tuple(tuple(sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def m_vec(A, v):
    return (A[0][0] * v[0] + A[0][1] * v[1] + A[0][2] * v[2],
            A[1][0] * v[0] + A[1][1] * v[1] + A[1][2] * v[2],
            A[2][0] * v[0] + A[2][1] * v[1] + A[2][2] * v[2])


def rot(axis, a):
    c, s = math.cos(a), math.sin(a)
    if axis == "x":
        return ((1, 0, 0), (0, c, -s), (0, s, c))
    if axis == "y":
        return ((c, 0, s), (0, 1, 0), (-s, 0, c))
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))


I3 = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


def basis_from_z(z):
    """Repère orthonormé (colonnes x, y, z) dont l'axe z local suit `z` (pour boulons, lampes sur une face)."""
    z = v_norm(z)
    ref = (0.0, 0.0, 1.0) if abs(z[2]) < 0.9 else (1.0, 0.0, 0.0)
    x = v_norm(v_cross(ref, z))
    y = v_cross(z, x)
    return ((x[0], y[0], z[0]), (x[1], y[1], z[1]), (x[2], y[2], z[2]))


def newell(pts):
    n = [0.0, 0.0, 0.0]
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n[0] += (a[1] - b[1]) * (a[2] + b[2])
        n[1] += (a[2] - b[2]) * (a[0] + b[0])
        n[2] += (a[0] - b[0]) * (a[1] + b[1])
    return tuple(n)


def centroid(pts):
    k = 1.0 / len(pts)
    return (sum(p[0] for p in pts) * k, sum(p[1] for p in pts) * k, sum(p[2] for p in pts) * k)


# ------------------------------------------------------------------------------------------------
# Accumulateur
# ------------------------------------------------------------------------------------------------
class MeshData:
    __slots__ = ("v", "f", "s")

    def __init__(self):
        self.v = []
        self.f = []
        self.s = []


class Geo:
    """Géométrie d'un module (socle ou tête), un maillage par clé de matériau.

    lights : sources ponctuelles du halo de nuit [(position monde, couleur, puissance W)] ;
    counts : nombre de pièces posées par type (pour la fiche des systèmes et le comptage des détails)."""

    def __init__(self, name):
        self.name = name
        self.meshes = {}
        self.R = I3
        self.K = 1.0       # échelle uniforme : monde = R·(K·p) + T
        self.T = (0.0, 0.0, 0.0)
        self.stack = []
        self.lights = []
        self.counts = {}

    # --- transformations ------------------------------------------------------------------------
    def push(self):
        self.stack.append((self.R, self.T, self.K))

    def pop(self):
        self.R, self.T, self.K = self.stack.pop()

    def move(self, d):
        self.T = v_add(self.T, m_vec(self.R, v_mul(d, self.K)))

    def scale_about(self, q, s):
        """Agrandit d'un facteur s autour du point local q tout ce qui sera posé ensuite (jusqu'au pop)."""
        self.T = v_add(self.T, m_vec(self.R, v_mul(q, self.K * (1.0 - s))))
        self.K *= s

    def turn(self, axis, a):
        self.R = m_mul(self.R, rot(axis, a))

    def frame(self, origin, B):
        """Repère local : origine `origin` (locale), base B (matrice 3×3, colonnes = axes)."""
        self.move(origin)
        self.R = m_mul(self.R, B)

    def xf(self, p):
        return v_add(m_vec(self.R, v_mul(p, self.K)), self.T)

    def xn(self, n):
        return m_vec(self.R, n)

    def count(self, kind, n=1):
        self.counts[kind] = self.counts.get(kind, 0) + n

    # --- ajout bas niveau ------------------------------------------------------------------------
    def add(self, mat, verts, faces, smooth=None, ref=None, refs=None):
        """verts locaux ; faces (indices) ; smooth : booléen ou liste par face ; orientation des faces vers
        l'extérieur : ref (point local unique, solide convexe) ou refs (un point local par face)."""
        md = self.meshes.setdefault(mat, MeshData())
        base = len(md.v)
        wv = [self.xf(p) for p in verts]
        md.v.extend(wv)
        for i, f in enumerate(faces):
            r = refs[i] if refs is not None else ref
            if r is not None:
                pts = [verts[j] for j in f]
                n = newell(pts)
                if v_dot(n, v_sub(centroid(pts), r)) < 0:
                    f = list(f)[::-1]
            md.f.append(tuple(base + j for j in f))
            md.s.append(smooth[i] if isinstance(smooth, (list, tuple)) else bool(smooth))

    def light(self, p, color, power):
        self.lights.append((self.xf(p), tuple(color), float(power)))

    # --- primitives --------------------------------------------------------------------------------
    def box(self, mat, size, c=(0, 0, 0), ch=0.012):
        """Boîte chanfreinée (arêtes à 45° de largeur ch : elles attrapent la lumière comme le vanilla)."""
        hx, hy, hz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
        ch = max(0.0, min(ch, 0.45 * min(hx, hy, hz) * 2))
        cx, cy, cz = c
        if ch <= 1e-6:
            v = [(cx + sx * hx, cy + sy * hy, cz + sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
            idx = lambda sx, sy, sz: ((sx > 0) * 4 + (sy > 0) * 2 + (sz > 0))
            f = [[idx(1, -1, -1), idx(1, 1, -1), idx(1, 1, 1), idx(1, -1, 1)],
                 [idx(-1, -1, -1), idx(-1, -1, 1), idx(-1, 1, 1), idx(-1, 1, -1)],
                 [idx(-1, 1, -1), idx(-1, 1, 1), idx(1, 1, 1), idx(1, 1, -1)],
                 [idx(-1, -1, -1), idx(1, -1, -1), idx(1, -1, 1), idx(-1, -1, 1)],
                 [idx(-1, -1, 1), idx(1, -1, 1), idx(1, 1, 1), idx(-1, 1, 1)],
                 [idx(-1, -1, -1), idx(-1, 1, -1), idx(1, 1, -1), idx(1, -1, -1)]]
            self.add(mat, v, f, False, ref=c)
            self.count("boite")
            return
        v = []
        key = {}
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    for ax in range(3):
                        p = [hx - ch if ax != 0 else hx, hy - ch if ax != 1 else hy, hz - ch if ax != 2 else hz]
                        key[(sx, sy, sz, ax)] = len(v)
                        v.append((cx + sx * p[0], cy + sy * p[1], cz + sz * p[2]))
        f = []
        S = (-1, 1)
        for ax in range(3):
            for s in S:
                quad = []
                for a in S:
                    for b in (S if a < 0 else S[::-1]):
                        sg = [0, 0, 0]
                        sg[ax] = s
                        o = [i for i in range(3) if i != ax]
                        sg[o[0]] = a
                        sg[o[1]] = b
                        quad.append(key[(sg[0], sg[1], sg[2], ax)])
                f.append(quad)
        # chanfreins d'arête : arête parallèle à l'axe `ax`, entre les faces des deux autres axes
        for ax in range(3):
            o = [i for i in range(3) if i != ax]
            for a in S:
                for b in S:
                    q = []
                    for s, ff in ((-1, o[0]), (1, o[0]), (1, o[1]), (-1, o[1])):
                        sg = [0, 0, 0]
                        sg[ax] = s
                        sg[o[0]] = a
                        sg[o[1]] = b
                        q.append(key[(sg[0], sg[1], sg[2], ff)])
                    f.append(q)
        for sx in S:
            for sy in S:
                for sz in S:
                    f.append([key[(sx, sy, sz, 0)], key[(sx, sy, sz, 1)], key[(sx, sy, sz, 2)]])
        self.add(mat, v, f, False, ref=c)
        self.count("boite")

    def prism(self, mat, poly, z0, z1, smooth=False):
        """Prisme droit : polygone (x, y) local (convexe ou non), de z0 à z1."""
        a = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
                for i in range(len(poly)))
        if a < 0:
            poly = poly[::-1]
        n = len(poly)
        v = [(x, y, z0) for x, y in poly] + [(x, y, z1) for x, y in poly]
        f = [list(range(n))[::-1], list(range(n, 2 * n))]
        f += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
        self.add(mat, v, f, [False, False] + [smooth] * n)
        self.count("prisme")

    def slab(self, mat, poly_xz, y0, y1):
        """Prisme dont le profil (x, z) est extrudé selon Y (blindages inclinés, coins chanfreinés)."""
        a = sum(poly_xz[i][0] * poly_xz[(i + 1) % len(poly_xz)][1] - poly_xz[(i + 1) % len(poly_xz)][0] *
                poly_xz[i][1] for i in range(len(poly_xz)))
        if a < 0:
            poly_xz = poly_xz[::-1]
        n = len(poly_xz)
        v = [(x, y0, z) for x, z in poly_xz] + [(x, y1, z) for x, z in poly_xz]
        mid = ((y0 + y1) / 2.0)
        cx = sum(p[0] for p in poly_xz) / n
        cz = sum(p[1] for p in poly_xz) / n
        f = [list(range(n)), list(range(n, 2 * n))]
        # face à y0 : normale -Y ; face à y1 : normale +Y (y0 < y1)
        refs = [(cx, y0 + 1e3, cz), (cx, y1 - 1e3, cz)]
        for i in range(n):
            f.append([i, (i + 1) % n, n + (i + 1) % n, n + i])
            # normale du côté : extérieure au profil (profil CCW en (x, z))
            p, q = poly_xz[i], poly_xz[(i + 1) % n]
            mx, mz = (p[0] + q[0]) / 2.0, (p[1] + q[1]) / 2.0
            dx, dz = q[0] - p[0], q[1] - p[1]
            nx, nz = dz, -dx
            refs.append((mx - nx, mid, mz - nz))
        self.add(mat, v, f, False, refs=refs)
        self.count("prisme")

    def slab_x(self, mat, poly_yz, x0, x1):
        """Prisme dont le profil (y, z) est extrudé selon X."""
        a = sum(poly_yz[i][0] * poly_yz[(i + 1) % len(poly_yz)][1] - poly_yz[(i + 1) % len(poly_yz)][0] *
                poly_yz[i][1] for i in range(len(poly_yz)))
        if a < 0:
            poly_yz = poly_yz[::-1]
        n = len(poly_yz)
        v = [(x0, y, z) for y, z in poly_yz] + [(x1, y, z) for y, z in poly_yz]
        cy = sum(p[0] for p in poly_yz) / n
        cz = sum(p[1] for p in poly_yz) / n
        mid = (x0 + x1) / 2.0
        f = [list(range(n)), list(range(n, 2 * n))]
        refs = [(x0 + 1e3, cy, cz), (x1 - 1e3, cy, cz)]
        for i in range(n):
            f.append([i, (i + 1) % n, n + (i + 1) % n, n + i])
            p, q = poly_yz[i], poly_yz[(i + 1) % n]
            my, mz = (p[0] + q[0]) / 2.0, (p[1] + q[1]) / 2.0
            dy, dz = q[0] - p[0], q[1] - p[1]
            ny, nz = dz, -dy
            refs.append((mid, my - ny, mz - nz))
        self.add(mat, v, f, False, refs=refs)
        self.count("prisme")

    def cyl(self, mat, r, h, c=(0, 0, 0), axis="z", n=24, r2=None, caps=True, ch=0.0, spin=0.0):
        """Cylindre (tronc de cône si r2) d'axe local `axis` ('x', 'y', 'z' ou vecteur), centré sur c.
        ch : chanfrein des deux bords (anneau à 45°, il attrape la lumière). Faces latérales lissées."""
        r2 = r if r2 is None else r2
        self.push()
        self.move(c)
        if axis == "x":
            self.turn("y", math.pi / 2)
        elif axis == "y":
            self.turn("x", -math.pi / 2)
        elif axis == "-y":
            self.turn("x", math.pi / 2)
        elif axis == "-x":
            self.turn("y", -math.pi / 2)
        elif axis != "z":
            self.R = m_mul(self.R, basis_from_z(axis))
        if spin:
            self.turn("z", spin)
        h2 = h / 2.0
        ch = min(ch, 0.4 * h, 0.4 * min(r, r2))
        rings = []
        if ch > 0:
            rings = [(-h2, r - ch, False), (-h2 + ch, r, True), (h2 - ch, r2, True), (h2, r2 - ch, False)]
        else:
            rings = [(-h2, r, True), (h2, r2, True)]
        v, f, sm, refs = [], [], [], []
        # bandes latérales (chacune avec ses propres sommets : arêtes vives entre bandes)
        for (za, ra, _), (zb, rb, _) in zip(rings[:-1], rings[1:]):
            b0 = len(v)
            for (z, rr) in ((za, ra), (zb, rb)):
                for i in range(n):
                    a = TAU * i / n
                    v.append((rr * math.cos(a), rr * math.sin(a), z))
            for i in range(n):
                f.append([b0 + i, b0 + (i + 1) % n, b0 + n + (i + 1) % n, b0 + n + i])
                sm.append(True)
                refs.append((0.0, 0.0, (za + zb) / 2.0))
        if caps:
            for z, rr, top in ((rings[0][0], rings[0][1], False), (rings[-1][0], rings[-1][1], True)):
                b0 = len(v)
                for i in range(n):
                    a = TAU * i / n
                    v.append((rr * math.cos(a), rr * math.sin(a), z))
                f.append(list(range(b0, b0 + n)))
                sm.append(False)
                refs.append((0.0, 0.0, z - 1.0 if top else z + 1.0))
        self.add(mat, v, f, sm, refs=refs)
        self.pop()
        self.count("cylindre")

    def tube(self, mat, r_out, r_in, h, c=(0, 0, 0), axis="z", n=32):
        """Anneau épais (bague, bride percée)."""
        self.push()
        self.move(c)
        if axis == "x":
            self.turn("y", math.pi / 2)
        elif axis == "y":
            self.turn("x", -math.pi / 2)
        elif axis != "z":
            self.R = m_mul(self.R, basis_from_z(axis))
        h2 = h / 2.0
        v, f, sm, refs = [], [], [], []
        for rr in (r_out, r_in):
            for z in (-h2, h2):
                for i in range(n):
                    a = TAU * i / n
                    v.append((rr * math.cos(a), rr * math.sin(a), z))
        o0, o1, i0, i1 = 0, n, 2 * n, 3 * n
        for i in range(n):
            j = (i + 1) % n
            f.append([o0 + i, o0 + j, o1 + j, o1 + i]); sm.append(True); refs.append((0, 0, 0))
            f.append([i0 + i, i1 + i, i1 + j, i0 + j]); sm.append(True)
            a = TAU * (i + 0.5) / n
            refs.append((r_in * 2 * math.cos(a), r_in * 2 * math.sin(a), 0.0))
            f.append([o1 + i, o1 + j, i1 + j, i1 + i]); sm.append(False); refs.append((0, 0, -1.0))
            f.append([o0 + i, i0 + i, i0 + j, o0 + j]); sm.append(False); refs.append((0, 0, 1.0))
        self.add(mat, v, f, sm, refs=refs)
        self.pop()
        self.count("bague")

    def torus(self, mat, R, r, c=(0, 0, 0), axis="z", n=40, m=10):
        self.push()
        self.move(c)
        if axis == "x":
            self.turn("y", math.pi / 2)
        elif axis == "y":
            self.turn("x", -math.pi / 2)
        elif axis != "z":
            self.R = m_mul(self.R, basis_from_z(axis))
        v, f, refs = [], [], []
        for i in range(n):
            a = TAU * i / n
            for j in range(m):
                b = TAU * j / m
                rr = R + r * math.cos(b)
                v.append((rr * math.cos(a), rr * math.sin(a), r * math.sin(b)))
        for i in range(n):
            for j in range(m):
                i2, j2 = (i + 1) % n, (j + 1) % m
                f.append([i * m + j, i2 * m + j, i2 * m + j2, i * m + j2])
                a = TAU * (i + 0.5) / n
                refs.append((R * math.cos(a), R * math.sin(a), 0.0))
        self.add(mat, v, f, True, refs=refs)
        self.pop()
        self.count("tore")

    def dome(self, mat, r, c=(0, 0, 0), axis="z", n=16, rings=4, squash=1.0):
        """Demi-sphère (rivet, hublot bombé, dôme) posée sur le plan z = 0 local, bombée vers +z."""
        self.push()
        self.move(c)
        if axis != "z":
            self.R = m_mul(self.R, basis_from_z(axis) if not isinstance(axis, str) else
                           {"x": basis_from_z((1, 0, 0)), "-x": basis_from_z((-1, 0, 0)),
                            "y": basis_from_z((0, 1, 0)), "-y": basis_from_z((0, -1, 0)),
                            "-z": basis_from_z((0, 0, -1))}[axis])
        v, f = [], []
        for k in range(rings):
            ph = (math.pi / 2) * k / rings
            for i in range(n):
                a = TAU * i / n
                v.append((r * math.cos(ph) * math.cos(a), r * math.cos(ph) * math.sin(a), r * squash * math.sin(ph)))
        top = len(v)
        v.append((0.0, 0.0, r * squash))
        for k in range(rings - 1):
            for i in range(n):
                j = (i + 1) % n
                f.append([k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i])
        k = rings - 1
        for i in range(n):
            f.append([k * n + i, k * n + (i + 1) % n, top])
        f.append(list(range(n))[::-1])
        sm = [True] * (len(f) - 1) + [False]
        self.add(mat, v, f, sm, ref=(0.0, 0.0, 0.0001))
        self.pop()
        self.count("dome")

    def path_tube(self, mat, pts, r, n=12, caps=True, closed=False):
        """Tube le long d'une polyligne (repères transportés : pas de torsion)."""
        if len(pts) < 2:
            return
        P = [tuple(p) for p in pts]
        T = []
        for i in range(len(P)):
            if i == 0:
                t = v_sub(P[1], P[0])
            elif i == len(P) - 1:
                t = v_sub(P[-1], P[-2])
            else:
                t = v_add(v_norm(v_sub(P[i], P[i - 1])), v_norm(v_sub(P[i + 1], P[i])))
            T.append(v_norm(t))
        ref = (0.0, 0.0, 1.0) if abs(T[0][2]) < 0.9 else (1.0, 0.0, 0.0)
        N = v_norm(v_cross(ref, T[0]))
        v, f, sm, refs = [], [], [], []
        frames = []
        for i in range(len(P)):
            if i > 0:
                b = v_cross(T[i - 1], T[i])
                if v_len(b) > 1e-9:
                    N = v_norm(v_sub(N, v_mul(T[i], v_dot(N, T[i]))))
            B = v_cross(T[i], N)
            frames.append((N, B))
        for i, p in enumerate(P):
            N, B = frames[i]
            for j in range(n):
                a = TAU * j / n
                v.append(v_add(p, v_add(v_mul(N, math.cos(a) * r), v_mul(B, math.sin(a) * r))))
        for i in range(len(P) - 1):
            for j in range(n):
                j2 = (j + 1) % n
                f.append([i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j])
                sm.append(True)
                refs.append(v_mul(v_add(P[i], P[i + 1]), 0.5))
        if caps:
            for i, s in ((0, -1), (len(P) - 1, 1)):
                b0 = len(v)
                N, B = frames[i]
                for j in range(n):
                    a = TAU * j / n
                    v.append(v_add(P[i], v_add(v_mul(N, math.cos(a) * r), v_mul(B, math.sin(a) * r))))
                f.append(list(range(b0, b0 + n)))
                sm.append(False)
                refs.append(v_sub(P[i], v_mul(T[i], s)))
        self.add(mat, v, f, sm, refs=refs)
        self.count("tube")


# ------------------------------------------------------------------------------------------------
# Courbes
# ------------------------------------------------------------------------------------------------
def catmull(ctrl, per_seg=6):
    """Polyligne lissée (Catmull-Rom centripète simplifiée) passant par les points de contrôle."""
    P = [tuple(p) for p in ctrl]
    if len(P) < 3:
        return P
    out = []
    ext = [v_sub(v_mul(P[0], 2), P[1])] + P + [v_sub(v_mul(P[-1], 2), P[-2])]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(per_seg):
            t = k / float(per_seg)
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 +
                                    (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(3)))
    out.append(P[-1])
    return out


def resample(pts, step):
    """Points régulièrement espacés de `step` le long d'une polyligne : [(point, tangente)]."""
    seg = []
    total = 0.0
    for a, b in zip(pts[:-1], pts[1:]):
        L = v_len(v_sub(b, a))
        seg.append((a, b, L))
        total += L
    out = []
    if total <= 1e-9:
        return out
    k = max(1, int(total / step))
    for i in range(k + 1):
        s = total * i / k
        acc = 0.0
        for a, b, L in seg:
            if acc + L >= s - 1e-9 or (a, b, L) is seg[-1]:
                t = 0.0 if L < 1e-9 else min(1.0, max(0.0, (s - acc) / L))
                out.append((v_add(a, v_mul(v_sub(b, a), t)), v_norm(v_sub(b, a))))
                break
            acc += L
    return out
