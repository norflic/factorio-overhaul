"""GÉOMÉTRIE du kit vaisseau_o (lot CENTRE-OPUS, 29/10) : mailles construites sommet par sommet, avec UV, regroupées
par matière dans un « Lot » (un objet Blender par matière : des milliers de rivets sans un appel bpy.ops chacun).

Conventions de tools/render/README.md : 1 unité = largeur d'une tuile, +X est, +Y nord, +Z haut, origine = position
de l'entité au sol. Le NEZ du vaisseau pointe vers +X (la DROITE de l'écran, règle du DC du 29/10).
Toutes les primitives rendent (sommets, faces, uv) ; uv = coordonnées de surface EN UNITÉS (une tôle de 0,6 fait 0,6).
"""
import math

TAU = 2.0 * math.pi


# ------------------------------------------------------------------------------------------------ vecteurs
def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    n = math.sqrt(dot(a, a)) or 1.0
    return (a[0] / n, a[1] / n, a[2] / n)


def length(a):
    return math.sqrt(dot(a, a))


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def rot_z(p, ang, c=(0.0, 0.0, 0.0)):
    s, co = math.sin(ang), math.cos(ang)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * co - y * s, c[1] + x * s + y * co, p[2])


def rot_x(p, ang, c=(0.0, 0.0, 0.0)):
    s, co = math.sin(ang), math.cos(ang)
    y, z = p[1] - c[1], p[2] - c[2]
    return (p[0], c[1] + y * co - z * s, c[2] + y * s + z * co)


def rot_y(p, ang, c=(0.0, 0.0, 0.0)):
    s, co = math.sin(ang), math.cos(ang)
    x, z = p[0] - c[0], p[2] - c[2]
    return (c[0] + x * co + z * s, p[1], c[2] - x * s + z * co)


class Rnd:
    """Générateur pseudo-aléatoire déterministe (pas de random global : mêmes entrées, mêmes octets)."""

    def __init__(self, seed):
        self.s = (seed * 2654435761 + 12345) & 0xFFFFFFFF

    def f(self, a=0.0, b=1.0):
        self.s = (1103515245 * self.s + 12345) & 0x7FFFFFFF
        return a + (b - a) * (self.s / 2147483647.0)

    def i(self, a, b):
        return int(math.floor(self.f(a, b + 1 - 1e-9)))


# ------------------------------------------------------------------------------------------------ lot
class Lot:
    """Accumule les mailles par matière ; flush() crée un objet par matière dans la collection de la pièce."""

    def __init__(self, S, prefix="vo"):
        self.S = S
        self.prefix = prefix
        self.parts = {}
        self.n = 0
        self.halos = []

    xf = None      # transformation appliquée à tout ce qui est posé (épave : vaisseau renversé et enfoncé)

    def put(self, mat, mesh, xf=None):
        verts, faces, uvs = mesh
        xf = xf or self.xf
        if xf is not None:
            verts = [xf(v) for v in verts]
        p = self.parts.setdefault(mat.name, [mat, [], [], []])
        off = len(p[1])
        p[1].extend(verts)
        p[2].extend(tuple(i + off for i in f) for f in faces)
        p[3].extend(uvs)
        self.n += 1

    def flush(self):
        import bpy
        objs = []
        for key in sorted(self.parts):
            mat, verts, faces, uvs = self.parts[key]
            me = bpy.data.meshes.new("%s_%s" % (self.prefix, key))
            me.from_pydata(verts, [], faces)
            uv = me.uv_layers.new(name="UVMap")
            flat = []
            for f in faces:
                for vi in f:
                    flat.extend(uvs[vi])
            uv.data.foreach_set("uv", flat)
            me.validate(clean_customdata=False)
            import bmesh
            bm = bmesh.new()
            bm.from_mesh(me)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(me)
            bm.free()
            ob =bpy.data.objects.new("%s_%s" % (self.prefix, key), me)
            bpy.context.scene.collection.objects.link(ob)
            self.S._adopt(ob, mat)
            me.shade_smooth()
            if hasattr(me, "set_sharp_from_angle"):
                me.set_sharp_from_angle(angle=math.radians(38))
            objs.append(ob)
        self.parts = {}
        return objs


# ------------------------------------------------------------------------------------------------ primitives
def boite(c, s, rz=0.0, rx=0.0, ry=0.0):
    """Boîte de centre c, tailles s ; rotations (radians) autour de son centre : y, puis x, puis z."""
    hx, hy, hz = s[0] / 2.0, s[1] / 2.0, s[2] / 2.0
    faces_def = [  # (normale, 4 coins en signes)
        ((0, 0, 1), [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
        ((0, 0, -1), [(-1, 1, -1), (1, 1, -1), (1, -1, -1), (-1, -1, -1)]),
        ((0, -1, 0), [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)]),
        ((0, 1, 0), [(1, 1, -1), (-1, 1, -1), (-1, 1, 1), (1, 1, 1)]),
        ((1, 0, 0), [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)]),
        ((-1, 0, 0), [(-1, 1, -1), (-1, -1, -1), (-1, -1, 1), (-1, 1, 1)]),
    ]
    verts, faces, uvs = [], [], []
    for n, cs in faces_def:
        base = len(verts)
        for sx, sy, sz in cs:
            p = (sx * hx, sy * hy, sz * hz)
            if n[2]:
                uvs.append((p[0], p[1]))
            elif n[1]:
                uvs.append((p[0], p[2]))
            else:
                uvs.append((p[1], p[2]))
            p = rot_y(p, ry)
            p = rot_x(p, rx)
            p = rot_z(p, rz)
            verts.append(add(p, c))
        faces.append((base, base + 1, base + 2, base + 3))
    return verts, faces, uvs


def prisme(poly, z0, z1, top_scale=1.0, top_shift=(0.0, 0.0)):
    """Prisme sur un polygone CONVEXE (x, y) du plan, de z0 à z1 ; le dessus peut être réduit et décalé (biseau)."""
    n = len(poly)
    cx = sum(p[0] for p in poly) / n
    cy = sum(p[1] for p in poly) / n
    bot = [(p[0], p[1], z0) for p in poly]
    top = [(cx + (p[0] - cx) * top_scale + top_shift[0], cy + (p[1] - cy) * top_scale + top_shift[1], z1) for p in poly]
    verts, faces, uvs = [], [], []
    verts += top
    uvs += [(p[0], p[1]) for p in top]
    faces.append(tuple(range(n)))
    base = len(verts)
    verts += list(reversed(bot))
    uvs += [(p[0], p[1]) for p in reversed(bot)]
    faces.append(tuple(range(base, base + n)))
    acc = 0.0
    for i in range(n):
        a, b = bot[i], bot[(i + 1) % n]
        ta, tb = top[i], top[(i + 1) % n]
        L = length(sub(b, a))
        base = len(verts)
        verts += [a, b, tb, ta]
        uvs += [(acc, z0), (acc + L, z0), (acc + L, z1), (acc, z1)]
        faces.append((base, base + 1, base + 2, base + 3))
        acc += L
    return verts, faces, uvs


def loft(rings, cap0=False, cap1=False, closed=True, uv_u=None):
    """Surface par sections : rings = listes de points de même longueur. uv : u = distance le long des sections
    (ou uv_u[i]), v = longueur d'arc dans la section."""
    m = len(rings[0])
    verts, faces, uvs = [], [], []
    us = uv_u or [0.0]
    if uv_u is None:
        acc = 0.0
        for i in range(1, len(rings)):
            c0 = mul(add(rings[i - 1][0], rings[i - 1][m // 2]), 0.5)
            c1 = mul(add(rings[i][0], rings[i][m // 2]), 0.5)
            acc += length(sub(c1, c0))
            us.append(acc)
    for i, r in enumerate(rings):
        acc = 0.0
        for j in range(m + (1 if closed else 0)):
            p = r[j % m]
            if j:
                acc += length(sub(p, r[j - 1]))
            verts.append(p)
            uvs.append((us[i], acc))
    w = m + (1 if closed else 0)
    for i in range(len(rings) - 1):
        for j in range(w - 1):
            a = i * w + j
            faces.append((a, a + 1, a + w + 1, a + w))
    if cap0:
        c = mul(tuple(sum(p[k] for p in rings[0]) for k in range(3)), 1.0 / m)
        ci = len(verts)
        verts.append(c)
        uvs.append((0.0, 0.0))
        for j in range(w - 1):
            faces.append((ci, j + 1, j))
    if cap1:
        r = rings[-1]
        c = mul(tuple(sum(p[k] for p in r) for k in range(3)), 1.0 / m)
        ci = len(verts)
        verts.append(c)
        uvs.append((0.0, 0.0))
        b = (len(rings) - 1) * w
        for j in range(w - 1):
            faces.append((ci, b + j, b + j + 1))
    return verts, faces, uvs


def tour(prof, segs=32, axe="x", c=(0.0, 0.0, 0.0), a0=0.0, a1=TAU, cap0=False, cap1=False):
    """Révolution d'un profil [(position sur l'axe, rayon)] autour d'un axe (x, y ou z) passant par c."""
    closed = abs(a1 - a0 - TAU) < 1e-9
    nseg = segs if closed else segs + 1
    rings = []
    for t, r in prof:
        ring = []
        for j in range(nseg):
            a = a0 + (a1 - a0) * j / float(segs)
            u, v = r * math.cos(a), r * math.sin(a)
            if axe == "x":
                p = (t, u, v)
            elif axe == "y":
                p = (v, t, u)
            else:
                p = (u, v, t)
            ring.append(add(p, c))
        rings.append(ring)
    uv_u = []
    acc = 0.0
    for i, (t, r) in enumerate(prof):
        if i:
            acc += math.hypot(t - prof[i - 1][0], r - prof[i - 1][1])
        uv_u.append(acc)
    return loft(rings, cap0, cap1, closed=closed, uv_u=uv_u)


def _frames(pts):
    """Repères à transport parallèle le long d'une polyligne."""
    n = len(pts)
    tans = []
    for i in range(n):
        a = pts[max(0, i - 1)]
        b = pts[min(n - 1, i + 1)]
        tans.append(norm(sub(b, a)))
    t0 = tans[0]
    ref = (0.0, 0.0, 1.0) if abs(t0[2]) < 0.9 else (1.0, 0.0, 0.0)
    nrm = norm(cross(t0, ref))
    out = []
    for i in range(n):
        t = tans[i]
        nrm = norm(sub(nrm, mul(t, dot(nrm, t))))
        out.append((t, nrm, cross(t, nrm)))
    return out


def tube(pts, r, segs=12, cap0=True, cap1=True, rfun=None):
    """Tube le long d'une polyligne ; rfun(s, i) donne le rayon (s = distance parcourue) : flexibles annelés."""
    fr = _frames(pts)
    rings = []
    s = 0.0
    uv_u = []
    for i, p in enumerate(pts):
        if i:
            s += length(sub(p, pts[i - 1]))
        uv_u.append(s)
        rr = rfun(s, i) if rfun else r
        t, n1, n2 = fr[i]
        ring = []
        for j in range(segs):
            a = TAU * j / segs
            ring.append(add(p, add(mul(n1, rr * math.cos(a)), mul(n2, rr * math.sin(a)))))
        rings.append(ring)
    return loft(rings, cap0, cap1, uv_u=uv_u)


def catmull(ctrl, n=8):
    """Courbe de Catmull-Rom passant par les points de contrôle."""
    if len(ctrl) < 3:
        return [lerp(ctrl[0], ctrl[-1], i / float(n)) for i in range(n + 1)]
    P = [ctrl[0]] + list(ctrl) + [ctrl[-1]]
    out = []
    for k in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[k - 1], P[k], P[k + 1], P[k + 2]
        for i in range(n):
            t = i / float(n)
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2
                                    + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3) for c in range(3)))
    out.append(ctrl[-1])
    return out


def coudee(poly, rb=0.12, n=6):
    """Polyligne à coudes arrondis (tuyauterie) : chaque angle est remplacé par un arc de rayon rb."""
    out = [poly[0]]
    for i in range(1, len(poly) - 1):
        a, b, c = poly[i - 1], poly[i], poly[i + 1]
        d1, d2 = norm(sub(a, b)), norm(sub(c, b))
        k = min(rb, length(sub(a, b)) * 0.45, length(sub(c, b)) * 0.45)
        p, q = add(b, mul(d1, k)), add(b, mul(d2, k))
        for j in range(n + 1):
            t = j / float(n)
            out.append(lerp(lerp(p, b, t), lerp(b, q, t), t))
    out.append(poly[-1])
    return out


def chainette(a, b, fl, n=14):
    """Câble qui pend entre a et b (flèche fl au milieu)."""
    return [add(lerp(a, b, i / float(n)), (0.0, 0.0, -fl * 4.0 * (i / float(n)) * (1.0 - i / float(n)))) for i in range(n + 1)]


def sphere(c, r, seg=12, rings=6, zmin=-1.0):
    """Sphère (ou calotte : zmin = 0 pour une demi-sphère posée vers +Z)."""
    prof = []
    a0 = math.asin(max(-1.0, min(1.0, zmin)))
    for i in range(rings + 1):
        a = a0 + (math.pi / 2 - a0) * i / float(rings)
        prof.append((r * math.sin(a), r * math.cos(a)))
    prof[-1] = (r, 0.0)
    return tour(prof, seg, "z", c, cap0=zmin > -1.0)


def merge(*meshes):
    verts, faces, uvs = [], [], []
    for v, f, u in meshes:
        off = len(verts)
        verts += v
        uvs += u
        faces += [tuple(i + off for i in ff) for ff in f]
    return verts, faces, uvs


def rivets_le_long(pts_normals, r=0.022, h=0.012):
    """Rivets (petites calottes) posés en (point, normale)."""
    out = []
    for p, n in pts_normals:
        prof = [(0.0, r), (h * 0.6, r * 0.8), (h, 0.0)]
        out.append(oriente(tour(prof, 6, "z", cap0=True), p, n))
    return merge(*out) if out else ([], [], [])


def oriente(mesh, p, n):
    """Pose une maille modélisée autour de +Z au point p, son +Z le long de la normale n."""
    n = norm(n)
    ref = (1.0, 0.0, 0.0) if abs(n[0]) < 0.9 else (0.0, 1.0, 0.0)
    e1 = norm(cross(ref, n))
    e2 = cross(n, e1)
    v, f, u = mesh
    out = [add(p, add(add(mul(e1, q[0]), mul(e2, q[1])), mul(n, q[2]))) for q in v]
    return out, f, u


def butte(c, rx, ry, h, rnd, n=18, bosses=0.3):
    """Butte de terre (champ de hauteur sur une ellipse), bosselée ; c = (x, y, z du pied)."""
    ph = [rnd.f(0, TAU) for _ in range(6)]
    verts, faces, uvs = [], [], []
    for i in range(n + 1):
        for j in range(n + 1):
            u, v = 2.0 * i / n - 1.0, 2.0 * j / n - 1.0
            r2 = u * u + v * v
            x, y = c[0] + u * rx, c[1] + v * ry
            z = 0.0
            if r2 < 1.0:
                b = 1.0 + bosses * (math.sin(5.1 * u + ph[0]) * math.sin(4.3 * v + ph[1]) + 0.5 * math.sin(11.0 * u + ph[2])
                                    * math.sin(9.0 * v + ph[3]))
                z = h * (1.0 - r2) ** 1.3 * b
            verts.append((x, y, c[2] + max(-0.02, z) - 0.02))
            uvs.append((x, y))
    w = n + 1
    for i in range(n):
        for j in range(n):
            a_ = i * w + j
            u = 2.0 * (i + 0.5) / n - 1.0
            v = 2.0 * (j + 0.5) / n - 1.0
            if u * u + v * v < 1.0:
                faces.append((a_, a_ + w, a_ + w + 1, a_ + 1))
    return verts, faces, uvs
