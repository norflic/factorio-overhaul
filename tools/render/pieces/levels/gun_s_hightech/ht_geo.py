"""Géométrie de l'explorateur « haute technologie à la Factorio » (lot V3-S, mitrailleuse), Python PUR + numpy.

Pourquoi un module sans bpy : le verrou de rendu (2 places pour tout le PC) est très disputé ; la géométrie est donc
écrite une fois, en tableaux (sommets, faces, lissage) par groupe (matériau, biseau), et sert :
  - dans Blender (ht_blender.py) : un objet par groupe, `from_pydata`, modificateur de biseau ;
  - hors Blender (ht_apercu.py) : une projection rapide (peintre, ombrage plat) pour régler silhouette, masse,
    emprise et dépassement O sans prendre le verrou.

Repère (tools/render/README.md, CALIBRATION §2) : 1 unité = largeur d'une tuile ; +X est, +Y nord, +Z haut ;
origine = position de l'entité au sol ; une tuile de jeu vers le sud = 1,414 unité en Y (TD).
Déterministe : aucun aléa hors de `random.Random(graine)` explicite.
"""
import math
import random

import numpy as np

TAU = 2.0 * math.pi
TD = math.sqrt(2.0)          # unités Blender par tuile de jeu en Y


# ------------------------------------------------------------------------------------------------
# Rotations
# ------------------------------------------------------------------------------------------------
def Rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], float)


def Ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], float)


def Rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], float)


I3 = np.eye(3)
# matrice qui porte l'axe local +Z sur l'axe demandé
AX = {"z": I3, "-z": Rx(math.pi), "x": Ry(math.pi / 2), "-x": Ry(-math.pi / 2), "y": Rx(-math.pi / 2),
      "-y": Rx(math.pi / 2)}


def frame_from_axis(d):
    """Matrice dont la 3e colonne est le vecteur unitaire d (repère orthonormé direct)."""
    d = np.asarray(d, float)
    d = d / np.linalg.norm(d)
    ref = np.array([0.0, 0.0, 1.0]) if abs(d[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(ref, d)
    u /= np.linalg.norm(u)
    w = np.cross(d, u)
    return np.stack([u, w, d], 1)


# ------------------------------------------------------------------------------------------------
# Générateurs de maillages (repère local)
# ------------------------------------------------------------------------------------------------
def _box():
    v = np.array([[x, y, z] for z in (-0.5, 0.5) for y in (-0.5, 0.5) for x in (-0.5, 0.5)], float)
    # indices : 0(-,-,-) 1(+,-,-) 2(-,+,-) 3(+,+,-) 4(-,-,+) 5(+,-,+) 6(-,+,+) 7(+,+,+)
    f = [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
    return v, f, [False] * 6


BOX = _box()


def g_cyl(r1, r2, h, n, caps=True, phase=0.0):
    a = phase + np.arange(n) * TAU / n
    bot = np.stack([r1 * np.cos(a), r1 * np.sin(a), np.full(n, -h / 2)], 1)
    top = np.stack([r2 * np.cos(a), r2 * np.sin(a), np.full(n, h / 2)], 1)
    v = np.concatenate([bot, top])
    f = [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    s = [True] * n
    if caps:
        f.append(list(range(n))[::-1])
        f.append(list(range(n, 2 * n)))
        s += [False, False]
    return v, f, s


def g_torus(R, r, n, m):
    v = []
    for i in range(n):
        a = TAU * i / n
        for j in range(m):
            b = TAU * j / m
            rr = R + r * math.cos(b)
            v.append((rr * math.cos(a), rr * math.sin(a), r * math.sin(b)))
    f = []
    for i in range(n):
        for j in range(m):
            i2, j2 = (i + 1) % n, (j + 1) % m
            f.append([i * m + j, i2 * m + j, i2 * m + j2, i * m + j2])
    return np.array(v, float), f, [True] * len(f)


def g_sphere(r, n, m):
    v = [(0.0, 0.0, r)]
    for k in range(1, m):
        t = math.pi * k / m
        for i in range(n):
            a = TAU * i / n
            v.append((r * math.sin(t) * math.cos(a), r * math.sin(t) * math.sin(a), r * math.cos(t)))
    v.append((0.0, 0.0, -r))
    f = []
    for i in range(n):
        f.append([0, 1 + i, 1 + (i + 1) % n])
    for k in range(m - 2):
        b0, b1 = 1 + k * n, 1 + (k + 1) * n
        for i in range(n):
            f.append([b0 + i, b1 + i, b1 + (i + 1) % n, b0 + (i + 1) % n])
    last = len(v) - 1
    b0 = 1 + (m - 2) * n
    for i in range(n):
        f.append([b0 + i, last, b0 + (i + 1) % n])
    return np.array(v, float), f, [True] * len(f)


def g_prism(poly, z0, z1):
    """Prisme droit : polygone (x, y) (sens quelconque) de z0 à z1. Faces planes."""
    p = np.asarray(poly, float)
    n = len(p)
    area = 0.5 * np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1])
    if area < 0:
        p = p[::-1]
    v = np.concatenate([np.c_[p, np.full(n, z0)], np.c_[p, np.full(n, z1)]])
    f = [list(range(n))[::-1], list(range(n, 2 * n))]
    f += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    return v, f, [False] * len(f)


def g_frustum(poly, z0, z1, k):
    """Tronc de pyramide : polygone de base à z0, réduit de k autour de son centre à z1."""
    p = np.asarray(poly, float)
    n = len(p)
    area = 0.5 * np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1])
    if area < 0:
        p = p[::-1]
    c = p.mean(0)
    q = c + (p - c) * k
    v = np.concatenate([np.c_[p, np.full(n, z0)], np.c_[q, np.full(n, z1)]])
    f = [list(range(n))[::-1], list(range(n, 2 * n))]
    f += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    return v, f, [False] * len(f)


def g_tube(pts, r, n, caps=True):
    """Tube le long d'une polyligne (repères transportés) ; rayon r scalaire ou liste par point."""
    P = np.asarray(pts, float)
    m = len(P)
    rr = np.full(m, r, float) if np.isscalar(r) else np.asarray(r, float)
    T = []
    for i in range(m):
        if i == 0:
            t = P[1] - P[0]
        elif i == m - 1:
            t = P[-1] - P[-2]
        else:
            a = P[i] - P[i - 1]
            b = P[i + 1] - P[i]
            t = a / (np.linalg.norm(a) + 1e-12) + b / (np.linalg.norm(b) + 1e-12)
        T.append(t / (np.linalg.norm(t) + 1e-12))
    F0 = frame_from_axis(T[0])
    u = F0[:, 0]
    v = []
    for i in range(m):
        if i > 0:
            # transport parallèle
            t0, t1 = T[i - 1], T[i]
            ax = np.cross(t0, t1)
            s = np.linalg.norm(ax)
            if s > 1e-9:
                ax /= s
                ang = math.atan2(s, float(np.dot(t0, t1)))
                u = (u * math.cos(ang) + np.cross(ax, u) * math.sin(ang) + ax * np.dot(ax, u) * (1 - math.cos(ang)))
        w = np.cross(T[i], u)
        for j in range(n):
            a = TAU * j / n
            v.append(P[i] + rr[i] * (math.cos(a) * u + math.sin(a) * w))
    f = []
    for i in range(m - 1):
        for j in range(n):
            j2 = (j + 1) % n
            f.append([i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j])
    s = [True] * len(f)
    if caps:
        f.append(list(range(n))[::-1])
        f.append(list(range((m - 1) * n, m * n)))
        s += [False, False]
    return np.array(v, float), f, s


# ------------------------------------------------------------------------------------------------
# Constructeur : pile de repères, groupes (matériau, biseau), sources de halo, inventaire des systèmes
# ------------------------------------------------------------------------------------------------
class B:
    def __init__(self, seed=1):
        self.groups = {}
        self.stack = [(I3.copy(), np.zeros(3))]
        self.lights = []          # (position monde, couleur, puissance)
        self.rng = random.Random(seed)
        self.systems = []         # systèmes fonctionnels (fiche, compte à la main)
        self.nprim = 0

    # --- repères ---
    def push(self, R=None, t=(0.0, 0.0, 0.0)):
        R0, t0 = self.stack[-1]
        R = I3 if R is None else np.asarray(R, float)
        self.stack.append((R0 @ R, R0 @ np.asarray(t, float) + t0))

    def pop(self):
        self.stack.pop()

    def world(self, p):
        R, t = self.stack[-1]
        return R @ np.asarray(p, float) + t

    # --- émission ---
    def emit(self, mat, v, f, s, bev=None, M=None, t=None):
        """v local (déjà mis à l'échelle) -> monde ; M, t : transformation locale supplémentaire."""
        R, t0 = self.stack[-1]
        v = np.asarray(v, float)
        if M is not None:
            v = v @ np.asarray(M, float).T
        if t is not None:
            v = v + np.asarray(t, float)
        v = v @ R.T + t0
        key = (mat, bev)
        g = self.groups.setdefault(key, {"v": [], "f": [], "s": [], "n": 0})
        base = g["n"]
        g["v"].append(v)
        g["f"].extend([[base + i for i in fc] for fc in f])
        g["s"].extend(s)
        g["n"] += len(v)
        self.nprim += 1

    def light(self, p, color, power):
        self.lights.append((tuple(float(x) for x in self.world(p)), tuple(color), float(power)))

    # --- primitives ---
    def box(self, mat, c, size, R=None, bev=0.012):
        v, f, s = BOX
        M = np.diag(size) if R is None else np.asarray(R, float) @ np.diag(size)
        self.emit(mat, v, f, s, bev, M=M, t=c)

    def cyl(self, mat, c, r, h, axis="z", r2=None, n=16, caps=True, bev=0.006, phase=0.0, R=None):
        v, f, s = g_cyl(r, r if r2 is None else r2, h, n, caps, phase)
        M = AX[axis] if isinstance(axis, str) else frame_from_axis(axis)
        if R is not None:
            M = np.asarray(R, float) @ M
        self.emit(mat, v, f, s, bev, M=M, t=c)

    def torus(self, mat, c, Rm, r, axis="z", n=32, m=8, R=None):
        v, f, s = g_torus(Rm, r, n, m)
        M = AX[axis] if isinstance(axis, str) else frame_from_axis(axis)
        if R is not None:
            M = np.asarray(R, float) @ M
        self.emit(mat, v, f, s, None, M=M, t=c)

    def sphere(self, mat, c, r, n=12, m=6, scale=(1, 1, 1)):
        v, f, s = g_sphere(r, n, m)
        self.emit(mat, v * np.asarray(scale, float), f, s, None, t=c)

    def prism(self, mat, poly, z0, z1, R=None, t=None, bev=0.012):
        v, f, s = g_prism(poly, z0, z1)
        self.emit(mat, v, f, s, bev, M=R, t=t)

    def frustum(self, mat, poly, z0, z1, k, R=None, t=None, bev=0.012):
        v, f, s = g_frustum(poly, z0, z1, k)
        self.emit(mat, v, f, s, bev, M=R, t=t)

    def tube(self, mat, pts, r, n=10, caps=True, bev=None):
        v, f, s = g_tube(pts, r, n, caps)
        self.emit(mat, v, f, s, bev)

    # --- motifs ---------------------------------------------------------------------------------
    def bolt(self, mat, c, r=0.028, h=0.022, axis="z"):
        """Boulon hexagonal (6 pans) posé sur une face de normale `axis`."""
        self.cyl(mat, c, r, h, axis=axis, n=6, bev=0.005, phase=math.pi / 6)

    def bolts_line(self, mat, p0, p1, n, r=0.026, axis="z", h=0.02):
        p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
        for i in range(n):
            t = (i + 0.5) / n
            self.bolt(mat, p0 + (p1 - p0) * t, r, h, axis)

    def bolts_rect(self, mat, x0, x1, y0, y1, z, r=0.026, inset=0.07, n=(2, 2)):
        """Boulons aux coins (et le long des bords si n > 2) d'un rectangle horizontal à la cote z."""
        nx, ny = n
        xs = np.linspace(x0 + inset, x1 - inset, nx)
        ys = np.linspace(y0 + inset, y1 - inset, ny)
        for i, x in enumerate(xs):
            for j, y in enumerate(ys):
                if 0 < i < nx - 1 and 0 < j < ny - 1:
                    continue
                self.bolt(mat, (x, y, z + 0.008), r)

    def plates_top(self, mat, x0, x1, y0, y1, z, nx, ny, th=0.035, gap=0.03, bolt_mat=None, bev=0.012,
                   bolts=True, skip=None):
        """Tôles d'un dessus (rectangle horizontal) : nx × ny plaques séparées par des joints, boulons aux coins."""
        w = (x1 - x0 - gap * (nx + 1)) / nx
        d = (y1 - y0 - gap * (ny + 1)) / ny
        for i in range(nx):
            for j in range(ny):
                if skip and (i, j) in skip:
                    continue
                cx = x0 + gap + w / 2 + i * (w + gap)
                cy = y0 + gap + d / 2 + j * (d + gap)
                self.box(mat, (cx, cy, z + th / 2), (w, d, th), bev=bev)
                if bolts and bolt_mat:
                    self.bolts_rect(bolt_mat, cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2, z + th, r=0.022,
                                    inset=0.055)

    def plates_face(self, mat, c, u, v, nu, nv, size_u, size_v, th=0.03, gap=0.034, bolt_mat=None, bev=0.012,
                    bolts=True, tones=None):
        """Tôles sur une face verticale : centre c, axes unitaires u (largeur) et v (hauteur) ; normale = u × v."""
        c, u, v = (np.asarray(x, float) for x in (c, u, v))
        nrm = np.cross(u, v)
        w = (size_u - gap * (nu + 1)) / nu
        h = (size_v - gap * (nv + 1)) / nv
        R = np.stack([u, v, nrm], 1)
        for i in range(nu):
            for j in range(nv):
                pc = c + u * (-size_u / 2 + gap + w / 2 + i * (w + gap)) + v * (-size_v / 2 + gap + h / 2 + j * (h + gap)) \
                    + nrm * th / 2
                self.box(self.rng.choice(tones) if tones else mat, pc, (w, h, th), R=R, bev=bev)
                if bolts and bolt_mat:
                    for su in (-1, 1):
                        for sv in (-1, 1):
                            self.bolt(bolt_mat, pc + u * su * (w / 2 - 0.05) + v * sv * (h / 2 - 0.05) + nrm * (th / 2 + 0.006),
                                      r=0.02, h=0.016, axis=nrm)

    def vent_face(self, frame_mat, slat_mat, back_mat, c, u, v, w, h, n, depth=0.04):
        """Grille d'aération sur une face : fond sombre en retrait, cadre, n lames horizontales inclinées."""
        c, u, v = (np.asarray(x, float) for x in (c, u, v))
        nrm = np.cross(u, v)
        R = np.stack([u, v, nrm], 1)
        self.box(back_mat, c - nrm * 0.005, (w, h, 0.02), R=R, bev=0)
        fw = 0.035
        for s in (-1, 1):
            self.box(frame_mat, c + u * s * (w / 2 - fw / 2) + nrm * depth / 2, (fw, h, depth), R=R, bev=0.006)
            self.box(frame_mat, c + v * s * (h / 2 - fw / 2) + nrm * depth / 2, (w, fw, depth), R=R, bev=0.006)
        nb = max(2, int((h - 2 * fw) / 0.095))
        for i in range(nb):
            t = (i + 0.5) / nb
            pc = c + v * (-h / 2 + fw + (h - 2 * fw) * t) + nrm * depth * 0.5
            self.cyl(slat_mat, pc, 0.017, w - 2 * fw, axis=u, n=8, bev=0)

    def grille_top(self, frame_mat, bar_mat, back_mat, x0, x1, y0, y1, z, n, along="x", glow_mat=None):
        """Grille horizontale (caillebotis) : fond (sombre ou lumineux), barreaux parallèles, cadre."""
        self.box(glow_mat or back_mat, ((x0 + x1) / 2, (y0 + y1) / 2, z - 0.01), (x1 - x0, y1 - y0, 0.02), bev=0)
        fw = 0.035
        self.box(frame_mat, ((x0 + x1) / 2, y0 + fw / 2, z + 0.02), (x1 - x0, fw, 0.04), bev=0.006)
        self.box(frame_mat, ((x0 + x1) / 2, y1 - fw / 2, z + 0.02), (x1 - x0, fw, 0.04), bev=0.006)
        self.box(frame_mat, (x0 + fw / 2, (y0 + y1) / 2, z + 0.02), (fw, y1 - y0, 0.04), bev=0.006)
        self.box(frame_mat, (x1 - fw / 2, (y0 + y1) / 2, z + 0.02), (fw, y1 - y0, 0.04), bev=0.006)
        for i in range(n):
            t = (i + 1) / (n + 1)
            if along == "x":
                y = y0 + (y1 - y0) * t
                self.box(bar_mat, ((x0 + x1) / 2, y, z + 0.015), (x1 - x0 - 2 * fw, 0.032, 0.03), bev=0)
            else:
                x = x0 + (x1 - x0) * t
                self.box(bar_mat, (x, (y0 + y1) / 2, z + 0.015), (0.032, y1 - y0 - 2 * fw, 0.03), bev=0)

    def fins(self, mat, c, along, length, height, n, pitch=0.07, th=0.032, base_mat=None, R=None):
        """Radiateur : n ailettes verticales minces (épaisseur th) réparties selon `along` (x ou y)."""
        c = np.asarray(c, float)
        Rl = I3 if R is None else np.asarray(R, float)
        span = pitch * (n - 1)
        for i in range(n):
            o = -span / 2 + i * pitch
            if along == "x":
                p = c + Rl @ np.array([o, 0.0, height / 2])
                self.box(mat, p, (th, length, height), R=Rl, bev=0.004)
            else:
                p = c + Rl @ np.array([0.0, o, height / 2])
                self.box(mat, p, (length, th, height), R=Rl, bev=0.004)
        if base_mat:
            sz = (span + 0.08, length + 0.04, 0.05) if along == "x" else (length + 0.04, span + 0.08, 0.05)
            self.box(base_mat, c + Rl @ np.array([0, 0, 0.025]), sz, R=Rl, bev=0.008)
            sz2 = (span + 0.08, 0.05, 0.05) if along == "x" else (0.05, span + 0.08, 0.05)
            for s in (-1, 1):
                off = np.array([0, s * length / 2, height]) if along == "x" else np.array([s * length / 2, 0, height])
                self.box(base_mat, c + Rl @ off, sz2, R=Rl, bev=0.006)

    def hazard_band(self, mat_y, mat_k, p0, p1, width, th=0.02, n=None, z_up=True, normal="z"):
        """Bande de danger jaune et noire : losanges inclinés à 45°, de p0 à p1, sur une face de normale `normal`."""
        p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
        d = p1 - p0
        L = float(np.linalg.norm(d))
        u = d / L
        nz = AX[normal] @ np.array([0, 0, 1.0]) if isinstance(normal, str) else np.asarray(normal, float)
        w = np.cross(nz, u)
        k = n or max(2, int(round(L / (width * 0.9))))
        seg = L / k
        for i in range(k):
            a = i * seg
            poly = [(a, -width / 2), (a + seg, -width / 2), (a + seg + width * 0.5, width / 2), (a + width * 0.5, width / 2)]
            poly = [(min(max(x, 0.0), L), y) for x, y in poly]
            M = np.stack([u, w, nz], 1)
            self.prism(mat_y if i % 2 == 0 else mat_k, poly, 0.0, th, R=M, t=p0, bev=0.0)

    def hose(self, mat, ring_mat, pts, r, pitch=0.07, n=10, ring_r=None):
        """Gaine annelée (cuivre du réacteur et de la centrifugeuse vanilla) : tube + bagues espacées de `pitch`."""
        P = np.asarray(pts, float)
        self.tube(mat, P, r, n=n, caps=True)
        rr = ring_r or r * 1.18
        seglen = np.linalg.norm(np.diff(P, axis=0), axis=1)
        tot = float(seglen.sum())
        k = int(tot / pitch)
        acc = np.concatenate([[0.0], np.cumsum(seglen)])
        for i in range(1, k):
            s = i * pitch
            j = int(np.searchsorted(acc, s) - 1)
            j = min(max(j, 0), len(seglen) - 1)
            t = (s - acc[j]) / max(seglen[j], 1e-9)
            p = P[j] + (P[j + 1] - P[j]) * t
            d = P[j + 1] - P[j]
            self.cyl(ring_mat, p, rr, pitch * 0.38, axis=d, n=n, bev=0)

    def cable(self, mat, p0, p1, sag=0.1, r=0.025, n=8, k=10):
        p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
        pts = []
        for i in range(k + 1):
            t = i / k
            p = p0 + (p1 - p0) * t
            p[2] -= sag * 4 * t * (1 - t)
            pts.append(p)
        self.tube(mat, pts, r, n=n)

    def gatling(self, mat_barrel, mat_ring, mat_dark, c, nb, ring_r, br, L, axis_dir="y", rings=(0.15, 0.55, 0.9),
                phase=0.0, muzzle_mat=None):
        """Faisceau de nb canons autour d'un axe (repère local : axe +Y), bagues, moyeu et frein de bouche."""
        self.push(None, c)
        R = I3 if axis_dir == "y" else AX[axis_dir] @ Rx(math.pi / 2)
        self.push(R)
        for i in range(nb):
            a = phase + TAU * i / nb
            self.cyl(mat_barrel, (ring_r * math.cos(a), L / 2, ring_r * math.sin(a)), br, L, axis="y", n=10, bev=0)
            # bouche sombre
            self.cyl(mat_dark, (ring_r * math.cos(a), L + 0.004, ring_r * math.sin(a)), br * 0.62, 0.012, axis="y", n=8,
                     bev=0)
        self.cyl(mat_dark, (0, L * 0.5, 0), ring_r * 0.5, L * 0.98, axis="y", n=10, bev=0)
        for t in rings:
            self.cyl(mat_ring, (0, L * t, 0), ring_r + br + 0.02, 0.05, axis="y", n=20, bev=0.006)
        if muzzle_mat:
            self.cyl(muzzle_mat, (0, L - 0.05, 0), ring_r + br + 0.035, 0.1, axis="y", n=20, bev=0.008)
            for i in range(6):
                a = TAU * (i + 0.5) / 6
                self.box(mat_dark, ((ring_r + br + 0.03) * math.cos(a), L - 0.05, (ring_r + br + 0.03) * math.sin(a)),
                         (0.035, 0.06, 0.035), R=Ry(-a), bev=0)
        self.pop()
        self.pop()

    def ammo_belt(self, mat_case, mat_link, pts, w=0.12, pitch=0.045):
        """Bande de cartouches (laiton) le long d'une polyligne : une cartouche tous les `pitch`."""
        P = np.asarray(pts, float)
        seglen = np.linalg.norm(np.diff(P, axis=0), axis=1)
        acc = np.concatenate([[0.0], np.cumsum(seglen)])
        tot = float(acc[-1])
        k = int(tot / pitch)
        for i in range(k):
            s = (i + 0.5) * pitch
            j = min(max(int(np.searchsorted(acc, s) - 1), 0), len(seglen) - 1)
            t = (s - acc[j]) / max(seglen[j], 1e-9)
            p = P[j] + (P[j + 1] - P[j]) * t
            d = (P[j + 1] - P[j]) / max(seglen[j], 1e-9)
            F = frame_from_axis(d)
            # cartouche couchée en travers de la bande (axe = F[:,0])
            self.cyl(mat_case, p, 0.018, w, axis=F[:, 0], n=6, bev=0)
            self.box(mat_link, p - F[:, 1] * 0.012, (0.02, 0.02, 0.02), bev=0)

    def lamp(self, glow_mat, frame_mat, c, size, axis="z", lens=True):
        """Voyant : boîtier, verre lumineux (lueur d'époque), visière."""
        c = np.asarray(c, float)
        M = AX[axis] if isinstance(axis, str) else frame_from_axis(axis)
        self.box(frame_mat, c, (size[0] + 0.05, size[1] + 0.05, 0.04), R=M, bev=0.006)
        self.box(glow_mat, c + M @ np.array([0, 0, 0.022]), (size[0], size[1], 0.02), R=M, bev=0)

    def label(self, name):
        """Inscrit un système fonctionnel (inventaire de la fiche, compté à la main)."""
        if name not in self.systems:
            self.systems.append(name)
