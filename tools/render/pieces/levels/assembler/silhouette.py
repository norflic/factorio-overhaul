"""Silhouette RAPIDE (hors Blender) des niveaux de la machine d'assemblage 2 (lot V3, phase 1). Python système.

    python -P tools/render/pieces/levels/assembler/silhouette.py [--levels 3,5,...] [--png <dossier>]

But : itérer sur la FORME (masques D1) sans lancer Blender, donc sans prendre le verrou de rendu. Le module modeles.py
est exécuté tel quel avec un faux `mathutils` et un faux `kit` : chaque primitive du kit est projetée exactement
comme la caméra de V0 (CALIBRATION §2 : u = X, v = -(Y·cos 45° + Z·sin 45°), 64 px par unité) puis remplie
(enveloppe convexe d'une primitive convexe, ou faces d'un maillage). Ce n'est qu'une ESTIMATION : biseaux, rivets et
roulis des poutres sont approchés ; la mesure qui fait foi reste celle des rendus (mesures_d1.py). L'écart avec les
rendus est imprimé (IoU estimation / rendu) quand un rendu existe.
"""
import argparse
import importlib
import math
import os
import sys
import types

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import params  # noqa: E402

R2 = math.sqrt(2.0)
PPT = 64
X0, X1, Y0, Y1 = -4.0, 7.0, -5.5, 3.0          # même toile que mesures_d1.py
W, H = int((X1 - X0) * PPT), int((Y1 - Y0) * PPT)
OX, OY = -X0 * PPT, -Y0 * PPT
SS = 4                                          # sur-échantillonnage du remplissage


# ------------------------------------------------------------------------------------------------
# Faux mathutils (le strict nécessaire de modeles.py et du kit)
# ------------------------------------------------------------------------------------------------
class Vector:
    def __init__(self, v=(0.0, 0.0, 0.0)):
        self.v = [float(a) for a in v]

    x = property(lambda s: s.v[0], lambda s, a: s.v.__setitem__(0, a))
    y = property(lambda s: s.v[1], lambda s, a: s.v.__setitem__(1, a))
    z = property(lambda s: s.v[2], lambda s, a: s.v.__setitem__(2, a))

    def __getitem__(self, i):
        return self.v[i]

    def __iter__(self):
        return iter(self.v)

    def __len__(self):
        return 3

    def __add__(self, o):
        return Vector([a + b for a, b in zip(self.v, o)])

    def __sub__(self, o):
        return Vector([a - b for a, b in zip(self.v, o)])

    def __mul__(self, k):
        return Vector([a * k for a in self.v])

    __rmul__ = __mul__

    def __truediv__(self, k):
        return Vector([a / k for a in self.v])

    def __neg__(self):
        return Vector([-a for a in self.v])

    def cross(self, o):
        a, b = self.v, list(o)
        return Vector((a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]))

    def dot(self, o):
        return sum(a * b for a, b in zip(self.v, o))

    @property
    def length(self):
        return math.sqrt(self.dot(self))

    def normalized(self):
        L = self.length or 1.0
        return self / L

    def copy(self):
        return Vector(self.v)

    def to_track_quat(self, track="Z", up="Y"):
        return ("frame", self.normalized())


class Quaternion:
    def __init__(self, *a):
        self.a = a

    def __matmul__(self, o):
        return o


def frame(d):
    """Repère orthonormé dont l'axe Z local suit d (approximation de to_track_quat('Z', 'Y'))."""
    z = np.array(list(d), float)
    z /= np.linalg.norm(z) or 1.0
    up = np.array([0.0, 0.0, 1.0]) if abs(z[2]) < 0.95 else np.array([0.0, 1.0, 0.0])
    x = np.cross(up, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    return np.stack([x, y, z], 1)          # colonnes = axes locaux


def euler(rx, ry, rz):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx                     # ordre XYZ de Blender


def P(tx, ty, z=0.0):
    return Vector((tx, -ty * R2, z))


def lin(h):
    return h


# ------------------------------------------------------------------------------------------------
# Raster
# ------------------------------------------------------------------------------------------------
def proj(pts):
    """Points Blender (N, 3) -> pixels de la toile (sur-échantillonnée)."""
    p = np.asarray(pts, float).reshape(-1, 3)
    u = (OX + p[:, 0] * PPT) * SS
    v = (OY - (p[:, 1] * math.sqrt(0.5) + p[:, 2] * math.sqrt(0.5)) * PPT) * SS
    return np.stack([u, v], 1)


def hull(pts):
    pts = sorted(set(map(tuple, np.round(pts, 3))))
    if len(pts) <= 2:
        return pts
    def cr(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cr(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


CONTACT_PX = 3                                  # portée du liseré à alpha ≥ 0,5 (mesurée sur les rendus d'aperçu)


def dilate(m, r):
    k = 2 * r + 1
    I = np.zeros((m.shape[0] + k, m.shape[1] + k), np.int32)
    I[r + 1:r + 1 + m.shape[0], r + 1:r + 1 + m.shape[1]] = m.astype(np.int32)
    I = I.cumsum(0).cumsum(1)
    return (I[k:, k:] - I[:-k, k:] - I[k:, :-k] + I[:-k, :-k])[:m.shape[0], :m.shape[1]] > 0


class Canvas:
    def __init__(self):
        self.img = {}
        self.cur = None

    def layer(self, mod):
        if mod not in self.img:
            self.img[mod] = Image.new("L", (W * SS, H * SS), 0)
        return ImageDraw.Draw(self.img[mod])

    def _sol(self, pts3):
        """Liseré de contact (occlusion du ciel au sol, composée sous la couche principale) : empreinte au sol des
        parties posées (z < 0,08), dilatée au masquage (CONTACT_PX)."""
        p = np.asarray(pts3, float).reshape(-1, 3)
        low = p[p[:, 2] < 0.08]
        if len(low) >= 3:
            low = low.copy()
            low[:, 2] = 0.0
            h = hull(proj(low))
            if len(h) >= 3:
                self.layer("_sol").polygon([tuple(q) for q in h], fill=255)

    def convex(self, mod, pts3):
        h = hull(proj(pts3))
        if len(h) >= 3:
            self.layer(mod).polygon([tuple(p) for p in h], fill=255)
        self._sol(pts3)

    def poly(self, mod, pts3):
        q = proj(pts3)
        if len(q) >= 3:
            self.layer(mod).polygon([tuple(p) for p in q], fill=255)
        self._sol(pts3)

    def mask(self, mods=None, contact=True):
        out = np.zeros((H, W), bool)
        for k, im in self.img.items():
            if k == "_sol" or (mods is not None and k not in mods):
                continue
            a = np.asarray(im.resize((W, H), Image.BOX)) >= 128
            out |= a
        if contact and mods is None and "_sol" in self.img:
            g = np.asarray(self.img["_sol"].resize((W, H), Image.BOX)) >= 128
            out |= dilate(g, CONTACT_PX)
        return out


def circle_pts(c, R, axis_frame, n=24, r2=None):
    a = np.linspace(0, 2 * math.pi, n, endpoint=False)
    loc = np.stack([np.cos(a), np.sin(a), np.zeros(n)], 1) * R
    return np.asarray(c) + loc @ axis_frame.T


class FakeKit:
    """Même interface que kit.Kit : chaque primitive remplit sa silhouette projetée dans le calque de son module."""

    def __init__(self, S=None, C=None, canvas=None):
        self.cv = canvas or Canvas()
        self.module = "corps"
        self.gain = 1.0
        self.n = 0
        self.power = 1.0
        self.halo_pts = []
        self.S = types.SimpleNamespace(piece_objects=lambda: [])

    # matériaux : jetons
    def metal(self, key, *a, **k):
        return key

    def flat(self, key, *a, **k):
        return key

    def emit(self, key, *a, **k):
        return key

    def emit_below(self, key, *a, **k):
        return key

    def nm(self, base):
        self.n += 1
        return base

    # primitives
    def _box_pts(self, c, size, R=np.eye(3)):
        sx, sy, sz = size
        pts = []
        for i in (-0.5, 0.5):
            for j in (-0.5, 0.5):
                for k in (-0.5, 0.5):
                    pts.append(np.asarray(c) + R @ np.array([i * sx, j * sy, k * sz]))
        return pts

    def box(self, x0, x1, y0, y1, z0, z1, mat, name="boite", bevel=0.012):
        c = P((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
        size = (abs(x1 - x0), abs(y1 - y0) * R2, abs(z1 - z0))
        self.cv.convex(self.module, self._box_pts(list(c), size))
        return name

    def rbox(self, x0, x1, y0, y1, z0, z1, mat, name="coque", r=0.12, seg=4):
        """Arêtes arrondies (biseau de largeur r) : enveloppe convexe de sphères de rayon r aux coins de la boîte
        réduite de r."""
        c = np.asarray(list(P((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)))
        size = np.array([abs(x1 - x0), abs(y1 - y0) * R2, abs(z1 - z0)])
        rr = min(r, 0.45 * size.min())
        F = frame(np.array([0.0, 1.0, -1.0]))
        pts = []
        for i in (-0.5, 0.5):
            for j in (-0.5, 0.5):
                for k in (-0.5, 0.5):
                    q = c + (size - 2 * rr) * np.array([i, j, k])
                    pts += list(circle_pts(q, rr, F, 12))
        self.cv.convex(self.module, pts)
        return name

    def cyl(self, tx, ty, z0, z1, r, mat, name="cyl", verts=32, r2=None, caps=True, bevel=0.006):
        c0, c1 = list(P(tx, ty, z0)), list(P(tx, ty, z1))
        F = np.eye(3)
        pts = list(circle_pts(c0, r, F, max(verts, 8))) + list(circle_pts(c1, r if r2 is None else r2, F, max(verts, 8)))
        self.cv.convex(self.module, pts)
        return name

    def _seg(self, a3, b3, r0, r1, n=16):
        a3, b3 = np.asarray(a3, float), np.asarray(b3, float)
        d = b3 - a3
        if np.linalg.norm(d) < 1e-9:
            d = np.array([0, 0, 1e-6])
        F = frame(d)
        pts = list(circle_pts(a3, r0, F, n)) + list(circle_pts(b3, r1, F, n))
        self.cv.convex(self.module, pts)

    def rod(self, a, b, r, mat, name="tige", verts=16, r2=None, caps=True, bevel=0.0):
        self._seg(list(P(*a)), list(P(*b)), r, r if r2 is None else r2, max(verts, 8))
        return name

    def beam(self, a, b, w, h, mat, name="poutre", bevel=0.006, roll=0.0):
        A, B = np.asarray(list(P(*a))), np.asarray(list(P(*b)))
        F = frame(B - A)
        pts = []
        for e in (A, B):
            for i in (-0.5, 0.5):
                for j in (-0.5, 0.5):
                    pts.append(e + F @ np.array([i * w, j * h, 0.0]))
        self.cv.convex(self.module, pts)
        return name

    def obox(self, at, size, rot, mat, name="plaque", bevel=0.006):
        self.cv.convex(self.module, self._box_pts(list(P(*at)), size, euler(*rot)))
        return name

    def sphere(self, tx, ty, z, r, mat, name="sphere", seg=32, rings=16):
        c = np.asarray(list(P(tx, ty, z)))
        # projection orthographique d'une sphère : disque de rayon r
        a = np.linspace(0, 2 * math.pi, 32, endpoint=False)
        F = frame(np.array([0.0, 1.0, -1.0]))     # axe de vue (u = X, v = -(Y + Z)/√2 : direction (0, 1, -1))
        self.cv.convex(self.module, list(circle_pts(c, r, F, 32)))
        return name

    def torus(self, tx, ty, z, R, r, mat, name="tore", axis="z", major_seg=64, minor_seg=12, tilt=0.0):
        rot = {"z": (tilt, 0, 0), "y": (math.pi / 2, 0, 0), "x": (0, math.pi / 2, 0)}[axis]
        M = euler(*rot)
        c = np.asarray(list(P(tx, ty, z)))
        ring = circle_pts(c, R, M, 48)
        for i in range(len(ring)):
            self._seg(ring[i], ring[(i + 1) % len(ring)], r, r, 10)
        return name

    def mesh(self, verts, faces, mat, name="maille", bevel=0.01, smooth_deg=None):
        V = [list(v) for v in verts]
        for f in faces:
            self.cv.poly(self.module, [V[i] for i in f])
        return name

    def _loft_pts(self, rings, M=np.eye(3), at=(0, 0, 0)):
        out = []
        for ring in rings:
            out.append([np.asarray(at) + M @ np.asarray(list(v), float) for v in ring])
        return out

    def _loft_fill(self, rr):
        for k in range(len(rr) - 1):
            self.cv.convex(self.module, list(rr[k]) + list(rr[k + 1]))
        for ring in (rr[0], rr[-1]):
            self.cv.poly(self.module, ring)

    def loft(self, rings, mat, name="loft", bevel=0.01, cap0=True, cap1=True, smooth_deg=None):
        rr = self._loft_pts(rings)
        n = len(rr[0])
        for k in range(len(rr) - 1):          # faces quadrilatères (anneaux non convexes possibles)
            for i in range(n):
                self.cv.poly(self.module, [rr[k][i], rr[k][(i + 1) % n], rr[k + 1][(i + 1) % n], rr[k + 1][i]])
        for ring in (rr[0], rr[-1]):
            self.cv.poly(self.module, ring)
        return name

    def prism(self, poly, z0, z1, mat, name="prisme", bevel=0.012, top=None):
        top = top or poly
        return self.loft([[P(x, y, z0) for x, y in poly], [P(x, y, z1) for x, y in top]], mat, name)

    def plate(self, poly_xz, y0, y1, mat, name="plaque", bevel=0.006):
        return self.loft([[P(x, y0, z) for x, z in poly_xz], [P(x, y1, z) for x, z in poly_xz]], mat, name)

    def plate_yz(self, poly_yz, x0, x1, mat, name="plaque", bevel=0.006):
        return self.loft([[P(x0, y, z) for y, z in poly_yz], [P(x1, y, z) for y, z in poly_yz]], mat, name)

    def lathe(self, at, profile, mat, name="tour", verts=32, axis=None, bevel=0.0, smooth_deg=50, cap0=True,
              cap1=True):
        M = frame(axis) if axis is not None else np.eye(3)
        c = np.asarray(list(P(*at)))
        rings = []
        for z, r in profile:
            a = np.linspace(0, 2 * math.pi, 32, endpoint=False)
            rings.append([c + M @ np.array([max(r, 1e-4) * math.cos(t), max(r, 1e-4) * math.sin(t), z]) for t in a])
        self._loft_fill(rings)
        return name

    def crystal(self, at, h, r, mat, name="cristal", tilt=(0.0, 0.0), sides=6, spin=0.0):
        M = euler(tilt[1], tilt[0], 0.0)
        c = np.asarray(list(P(*at)))

        def ring(z, rr):
            return [c + M @ np.array([rr * math.cos(spin + 2 * math.pi * i / sides),
                                      rr * math.sin(spin + 2 * math.pi * i / sides), z]) for i in range(sides)]
        self._loft_fill([ring(-0.15 * h, r * 0.7), ring(0.0, r), ring(0.72 * h, r * 0.92), ring(h, r * 0.02)])
        return name

    def gear(self, at, axis, R, th, teeth, mat, name="engrenage", phase=0.0, hub=None):
        M = euler(*{"z": (0, 0, 0), "y": (math.pi / 2, 0, 0), "x": (0, math.pi / 2, 0)}[axis])
        c = np.asarray(list(P(*at)))
        d = M @ np.array([0, 0, th / 2])
        self._seg(c - d, c + d, R * 0.97, R * 0.97, 32)
        return name

    def wheel(self, at, axis, R, th, spokes, mat_rim, mat_spoke, name="volant", phase=0.0):
        M = euler(*{"z": (0, 0, 0), "y": (math.pi / 2, 0, 0), "x": (0, math.pi / 2, 0)}[axis])
        c = np.asarray(list(P(*at)))
        ring = circle_pts(c, R - th * 0.5, M, 40)
        for i in range(len(ring)):
            self._seg(ring[i], ring[(i + 1) % len(ring)], th * 0.5, th * 0.5, 8)
        d = M @ np.array([0, 0, th * 0.9])
        self._seg(c - d, c + d, R * 0.16, R * 0.16, 16)
        for i in range(spokes):
            a = phase + 2 * math.pi * i / spokes
            e = c + M @ np.array([math.cos(a) * R * 0.9, math.sin(a) * R * 0.9, 0])
            self._seg(c, e, th * 0.3, th * 0.3, 8)
        return name

    def tube(self, pts, r, mat, name="tube", res=6):
        Q = [np.asarray(list(P(*p))) for p in pts]
        for a, b in zip(Q, Q[1:]):
            self._seg(a, b, r, r, 10)
        return name

    def rivets(self, a, b, n, r, mat, name="rivets"):
        return name

    def halo(self, tx, ty, z, hexcol, power, radius=0.05):
        return None

    def join(self, objs, name):
        return name


def load_modeles():
    fm = types.ModuleType("mathutils")
    fm.Vector, fm.Quaternion = Vector, Quaternion
    fk = types.ModuleType("kit")
    fk.Kit, fk.P, fk.R2, fk.lin = FakeKit, P, R2, lin
    # les faux modules restent en place (modeles.py importe aussi mathutils à l'intérieur de fonctions) : ce
    # processus ne sert qu'à l'estimation
    sys.modules["mathutils"], sys.modules["kit"] = fm, fk
    sys.modules.pop("modeles", None)
    mod = importlib.import_module("modeles")
    sys.modules.pop("modeles", None)
    return mod


def level_masks(n, modeles=None, t=0.0):
    """{module: masque} estimés pour le niveau n (2 à 30) ; niveau 2 : la pièce seule (sans le vanilla)."""
    modeles = modeles or load_modeles()
    K = FakeKit()
    K.power = params.halo_puissance(n)
    modeles.BUILDERS[params.epoque(n)](K, t, params.est_pair(n))
    out = {k: K.cv.mask([k]) for k in K.cv.img if k != "_sol"}
    out["_tout"] = K.cv.mask()
    return out, K


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="3,5,7,9,11,13,15,17,19,21,23,25,27,29")
    ap.add_argument("--png", default="")
    a = ap.parse_args()
    import mesures_d1 as M
    mod = load_modeles()
    for n in [int(x) for x in a.levels.split(",")]:
        mm, _ = level_masks(n, mod)
        est = mm["_tout"]
        try:
            real = M.level_rgba(n, "complet")[..., 3] >= 0.5
            if n == 2:
                real = real & ~M.vanilla().__getitem__((Ellipsis, 3)).__ge__(0.5) | (est & False)
            s = "IoU estimation/rendu %.3f" % M.iou(est, real)
        except Exception as ex:  # noqa: BLE001
            s = "pas de rendu (%s)" % type(ex).__name__
        print("niveau %2d : aire estimée %.2f t² ; %s" % (n, est.sum() / PPT ** 2, s))
        if a.png:
            os.makedirs(a.png, exist_ok=True)
            Image.fromarray((~est * 255).astype(np.uint8)).save(os.path.join(a.png, "est-n%02d.png" % n))


if __name__ == "__main__":
    main()
