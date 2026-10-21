"""Kit de modélisation de la famille « mitrailleuse » (clé gun), lot V3 phase 1.

S'exécute DANS Blender (importé par gun.py, lui-même chargé par tools/render/blender/render_piece.py).
Ne modifie aucun fichier partagé du pipeline : n'utilise que l'API publique de fo_scene (S) et de
fo_calib (C), plus bpy pour les maillages sur mesure (prismes, ailerons, cristaux).

Conventions (tools/render/README.md, CALIBRATION.md §2) :
- 1 unité Blender = largeur d'une tuile ; +X est, +Y nord, +Z haut ; origine = position de l'entité au sol ;
- une tuile de jeu vers le sud = 1,414 unité en Y (C.tile_to_blender) ; emprise 2×2 : X ±1, Y ±1,414 ;
- tête : modélisée canons vers +Y (« N »), puis tournée autour de Z (E = -90°, S = 180°, O = +90° ;
  direction k sur 64 : angle = -k × 5,625°) ;
- socle (base_picture, couche lower-object) : BAS (z ≤ 0,5) ; tout ce qui monte appartient à la tête
  (couche object), sinon une entité placée au nord serait dessinée par-dessus (ordre des couches) ;
- pièce du niveau pair : sur le socle, dans la zone toujours visible (F46 : y de jeu ≥ +0,11 tuile).

Bible : docs/DESIGN_EPOQUES.md §1.4 (enveloppes), §1.5 (palette), §1.6 (lumière), §5 (fiches « Mitrailleuse »).
"""
import math
import random

import bpy
import bmesh

TAU = 2 * math.pi
SQ2 = math.sqrt(2.0)


# ------------------------------------------------------------------------------------------------
# Couleurs
# ------------------------------------------------------------------------------------------------
def lin(hexstr, gain=1.0, cap=0.86):
    """sRGB hexadécimal -> couleur linéaire (× gain, bornée : p95 ≤ 240, bible §1.5)."""
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        c = c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
        out.append(min(cap, c * gain))
    return tuple(out)


def emit_rgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# ------------------------------------------------------------------------------------------------
# Constructeur : collecte les objets d'un module (tête ou socle) pour pouvoir les tourner
# ------------------------------------------------------------------------------------------------
class K:
    def __init__(self, S, C, tag):
        self.S, self.C, self.tag = S, C, tag
        self.objs = []
        self.lights = []
        self.n = 0

    def _name(self, base):
        self.n += 1
        return "%s_%s_%03d" % (self.tag, base, self.n)

    def _keep(self, o):
        self.objs.append(o)
        return o

    # --- primitives -------------------------------------------------------------------------------
    def box(self, size, loc, mat, rot=(0, 0, 0), bevel=0.012, name="box"):
        o = self.S.box(size, loc, mat, self._name(name), bevel_w=bevel)
        o.rotation_euler = rot
        return self._keep(o)

    def cyl(self, r, h, loc, mat, axis="z", r2=None, verts=32, bevel=0.006, caps=True, spin=0.0, name="cyl"):
        if axis == "z":
            rot = (0.0, 0.0, spin)
        elif axis == "y":
            rot = (-math.pi / 2, spin, 0.0)    # +Z local -> +Y (radius2 vers +Y)
        elif axis == "-y":
            rot = (math.pi / 2, spin, 0.0)
        elif axis == "x":
            rot = (0.0, math.pi / 2, spin)     # +Z local -> +X
        elif axis == "-z":
            rot = (math.pi, 0.0, spin)
        else:
            rot = axis
        o = self.S.cylinder(r, h, loc, mat, self._name(name), verts=verts, rot=rot, bevel_w=bevel, radius2=r2, caps=caps)
        return self._keep(o)

    def sph(self, r, loc, mat, scale=None, seg=24, rings=12, name="sph"):
        o = self.S.sphere(r, loc, mat, self._name(name), seg=seg, rings=rings)
        if scale:
            o.scale = scale
        return self._keep(o)

    def tor(self, R, r, loc, mat, axis="z", seg=48, mseg=10, name="tor"):
        rot = {"z": (0, 0, 0), "y": (math.pi / 2, 0, 0), "x": (0, math.pi / 2, 0)}.get(axis, axis)
        o = self.S.torus(R, r, loc, mat, self._name(name), rot=rot, major_seg=seg, minor_seg=mseg)
        return self._keep(o)

    def mesh(self, verts, faces, mat, bevel=0.0, name="mesh", smooth_deg=None, mats=None, mat_index=None):
        me = bpy.data.meshes.new(self._name(name))
        me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
        me.validate()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
        o = bpy.data.objects.new(me.name, me)
        self.S.piece_collection().objects.link(o)
        if mats:
            for m in mats:
                o.data.materials.append(m)
            if mat_index:
                for p, i in zip(o.data.polygons, mat_index(o.data.polygons)):
                    p.material_index = i
        else:
            o.data.materials.append(mat)
        if smooth_deg:
            self.S.smooth(o, smooth_deg)
        if bevel:
            self.S.bevel(o, bevel)
        return self._keep(o)

    def prism_x(self, poly_yz, x0, width, mat, bevel=0.01, name="prx"):
        """Prisme : profil (y, z) extrudé selon X, centré sur x0."""
        n = len(poly_yz)
        v = [(x0 - width / 2, y, z) for y, z in poly_yz] + [(x0 + width / 2, y, z) for y, z in poly_yz]
        f = [list(range(n)), list(range(n, 2 * n))[::-1]]
        f += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
        return self.mesh(v, f, mat, bevel, name)

    def prism_y(self, poly_xz, y0, depth, mat, bevel=0.01, name="pry"):
        """Prisme : profil (x, z) extrudé selon Y, centré sur y0."""
        n = len(poly_xz)
        v = [(x, y0 - depth / 2, z) for x, z in poly_xz] + [(x, y0 + depth / 2, z) for x, z in poly_xz]
        f = [list(range(n)), list(range(n, 2 * n))[::-1]]
        f += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
        return self.mesh(v, f, mat, bevel, name)

    def prism_z(self, poly_xy, z0, height, mat, bevel=0.01, name="prz"):
        """Prisme vertical : polygone (x, y) de z0 à z0 + height."""
        n = len(poly_xy)
        v = [(x, y, z0) for x, y in poly_xy] + [(x, y, z0 + height) for x, y in poly_xy]
        f = [list(range(n))[::-1], list(range(n, 2 * n))]
        f += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
        return self.mesh(v, f, mat, bevel, name)

    def frustum_poly(self, poly_xy, z0, z1, k_top, mat, bevel=0.01, name="frp"):
        """Tronc de pyramide : polygone de base (x, y) à z0, réduit de k_top autour de son centre à z1."""
        n = len(poly_xy)
        cx = sum(p[0] for p in poly_xy) / n
        cy = sum(p[1] for p in poly_xy) / n
        top = [(cx + (x - cx) * k_top, cy + (y - cy) * k_top) for x, y in poly_xy]
        v = [(x, y, z0) for x, y in poly_xy] + [(x, y, z1) for x, y in top]
        f = [list(range(n))[::-1], list(range(n, 2 * n))]
        f += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
        return self.mesh(v, f, mat, bevel, name)

    def spike(self, base, tip, r, mat, sides=6, name="spike", r_tip=0.0):
        """Pointe (cristal, flèche) : prisme à `sides` faces de base -> pointe, axe quelconque."""
        bx, by, bz = base
        tx, ty, tz = tip
        ax = (tx - bx, ty - by, tz - bz)
        L = math.sqrt(sum(a * a for a in ax))
        a = tuple(c / L for c in ax)
        # repère orthonormé autour de l'axe
        ref = (0, 0, 1) if abs(a[2]) < 0.9 else (1, 0, 0)
        u = (a[1] * ref[2] - a[2] * ref[1], a[2] * ref[0] - a[0] * ref[2], a[0] * ref[1] - a[1] * ref[0])
        nu = math.sqrt(sum(c * c for c in u))
        u = tuple(c / nu for c in u)
        w = (a[1] * u[2] - a[2] * u[1], a[2] * u[0] - a[0] * u[2], a[0] * u[1] - a[1] * u[0])
        verts = []
        shoulder = 0.72
        for ring, (t, rr) in enumerate(((0.0, r), (shoulder, r * 0.92))):
            for i in range(sides):
                ang = TAU * i / sides
                c, s = math.cos(ang) * rr, math.sin(ang) * rr
                verts.append((bx + a[0] * L * t + u[0] * c + w[0] * s,
                              by + a[1] * L * t + u[1] * c + w[1] * s,
                              bz + a[2] * L * t + u[2] * c + w[2] * s))
        verts.append((tx, ty, tz))
        n = sides
        faces = [list(range(n))[::-1]]
        faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
        faces += [[n + i, n + (i + 1) % n, 2 * n] for i in range(n)]
        return self.mesh(verts, faces, mat, 0.0, name)

    def halo(self, loc, color, power=30.0):
        o = self.S.halo_light(loc, color, power, radius=0.06, name=self._name("halo"))
        self.lights.append(o)
        return o

    # --- motifs -----------------------------------------------------------------------------------
    def rivets_line(self, p0, p1, n, r, mat):
        objs = []
        for i in range(n):
            t = (i + 0.5) / n
            p = tuple(p0[j] + (p1[j] - p0[j]) * t for j in range(3))
            objs.append(self.S.sphere(r, p, mat, self._name("riv"), seg=8, rings=4))
        o = self.S.join(objs, self._name("rivets"))
        return self._keep(o)

    def rivet_ring(self, R, z, n, r, mat, cx=0.0, cy=0.0, phase=0.0):
        o = self.S.rivet_ring(R, z, n, r, mat, center=(cx, cy), name=self._name("rring"), phase=phase)
        return self._keep(o)

    def gatling(self, n, ring_r, br, y0, y1, x, z, m_barrel, m_ring, rings=(0.12, 0.55, 0.92), phase=0.0,
                core=True, verts=12):
        objs = []
        ym, L = (y0 + y1) / 2, y1 - y0
        for i in range(n):
            a = phase + TAU * i / n
            objs.append(self.S.cylinder(br, L, (x + ring_r * math.cos(a), ym, z + ring_r * math.sin(a)), m_barrel,
                                        self._name("canon"), verts=verts, rot=(-math.pi / 2, 0, 0), bevel_w=0))
        self._keep(self.S.join(objs, self._name("canons")))
        if core:
            self.cyl(ring_r * 0.45, L * 0.98, (x, ym, z), m_ring, axis="y", verts=12, bevel=0, name="axe")
        for t in rings:
            self.cyl(ring_r + br + 0.018, 0.04, (x, y0 + t * L, z), m_ring, axis="y", verts=28, bevel=0.004, name="bague")

    def disc_stack(self, x, y, z0, n, r_big, r_small, h, mat, cap=None):
        """Pile d'isolateurs (disques alternés) : colonne « crantée »."""
        z = z0
        for i in range(n):
            self.cyl(r_big if i % 2 == 0 else r_small, h, (x, y, z + h / 2), mat, verts=24, bevel=0.01, name="iso")
            z += h
        if cap is not None:
            self.cyl(r_small * 0.8, 0.06, (x, y, z + 0.03), cap, verts=16, name="iso_cap")
            z += 0.06
        return z

    # --- rotation de la tête ----------------------------------------------------------------------
    def rotate(self, angle):
        """Tourne tous les objets et sources collectés autour de l'axe Z du monde (origine de l'entité)."""
        bpy.context.view_layer.update()
        c, s = math.cos(angle), math.sin(angle)
        for o in self.objs + self.lights:
            x, y, z = o.location
            o.location = (c * x - s * y, s * x + c * y, z)
            r = o.rotation_euler
            o.rotation_euler = (r[0], r[1], r[2] + angle)
        bpy.context.view_layer.update()


# ------------------------------------------------------------------------------------------------
# Matériaux par époque (bible §1.5 ; albédos sRGB convertis en linéaire × gain, gain réglé sur la
# luminance médiane mesurée du rendu)
# ------------------------------------------------------------------------------------------------
def materials(S, e, g):
    M = {}

    def metal(key, hexc, rough=0.42, met=0.75, grain=0.22, rust=None, ra=0.0, dirt=0.45, gain=None, seed=None):
        M[key] = S.mat_metal("e%02d_%s" % (e, key), lin(hexc, g if gain is None else gain), rough=rough, metallic=met,
                             grain=grain, grain_scale=55.0, rust=lin(rust, 1.4) if rust else None, rust_amount=ra,
                             rust_scale=5.0, dirt=dirt, seed=float(seed if seed is not None else len(M) + 10 * e))

    def emissive(key, hexc, strength=1.6, base="#141210"):
        M[key] = S.mat_emissive("e%02d_%s" % (e, key), emit_rgb(hexc), strength=strength, base=lin(base))

    # communs à toutes les époques : acier sombre de mécanique, canon bruni, caoutchouc
    metal("gun", "#3C3A38", rough=0.38, met=0.85, grain=0.15, rust="#4A2A18", ra=0.15)
    metal("dark", "#262422", rough=0.55, met=0.6, grain=0.18)
    if e == 1:
        metal("toile", "#8A7A5A", rough=0.95, met=0.0, grain=0.35, dirt=0.6)
        metal("bois", "#6B4F35", rough=0.85, met=0.0, grain=0.35)
        metal("fer", "#5A5048", rough=0.5, met=0.7, rust="#5A3018", ra=0.4)
    elif e == 2:
        metal("main", "#5C6168", rough=0.38, met=0.75, rust="#4A2C1C", ra=0.25)
        metal("band", "#2E2C2A", rough=0.45, met=0.7, gain=g * 1.2)
        metal("brass", "#8C7440", rough=0.3, met=0.9, grain=0.12)
        metal("bois", "#6B4F35", rough=0.85, met=0.0, grain=0.35)
    elif e == 3:
        metal("main", "#8A5A3A", rough=0.35, met=0.85, rust="#2E4A3A", ra=0.2)      # cuivre (vert-de-gris léger)
        metal("brass", "#9C7E45", rough=0.3, met=0.9, grain=0.12)
        metal("fonte", "#3A3634", rough=0.6, met=0.55, gain=g * 1.15)
        emissive("emit", "#FFC060", 2.2)
    elif e == 4:
        metal("main", "#8C7A3A", rough=0.5, met=0.25, rust="#4A3A20", ra=0.3, dirt=0.55)  # tôle jaune délavée
        metal("galva", "#6E7378", rough=0.38, met=0.8)
        metal("black", "#1C1C1C", rough=0.6, met=0.3, gain=g * 1.2)
        emissive("emit", "#FF8C1A", 2.4)
    elif e == 5:
        metal("main", "#3E3D42", rough=0.42, met=0.8, rust="#5A3A2A", ra=0.35)
        metal("rouille", "#5A3A2A", rough=0.6, met=0.4)
        emissive("emit", "#FF4A10", 2.6)
    elif e == 6:
        metal("main", "#D8D4C8", rough=0.35, met=0.0, grain=0.12, dirt=0.55, gain=g * 0.62)  # céramique
        metal("coil", "#B0703A", rough=0.3, met=0.9, grain=0.12)
        metal("steel", "#5C6168", rough=0.4, met=0.75)
        emissive("emit", "#60D0FF", 2.4)
    elif e == 7:
        metal("main", "#6A5236", rough=0.38, met=0.85, rust="#2F4A3C", ra=0.25)   # bronze
        metal("pierre", "#4A4038", rough=0.85, met=0.0, grain=0.4)
        emissive("emit", "#B070FF", 1.7, base="#3A2266")                        # cristal
    elif e == 8:
        metal("main", "#4F6B5A", rough=0.5, met=0.55, rust="#2E3A2E", ra=0.2)     # vert-de-gris
        metal("glass", "#8FBF4A", rough=0.12, met=0.0, grain=0.06, dirt=0.2, gain=g * 0.7)
        metal("rubber", "#2A2A28", rough=0.8, met=0.0, grain=0.1, gain=g * 1.3)
        emissive("emit", "#A8FF3A", 1.8)
    elif e == 9:
        metal("main", "#4A5058", rough=0.55, met=0.6)                             # plomb
        metal("jaune", "#C9A227", rough=0.5, met=0.1, dirt=0.5, gain=g * 0.75)
        metal("beton", "#7A7670", rough=0.9, met=0.0, grain=0.3, gain=g * 0.85)
        emissive("emit", "#5CFF4A", 2.0)
    elif e == 10:
        metal("main", "#A8ADB3", rough=0.28, met=0.3, grain=0.06, dirt=0.35, gain=g * 0.75)  # carénage
        metal("noir", "#222428", rough=0.45, met=0.4, grain=0.08, gain=g * 1.2)
        emissive("emit", "#3AA8FF", 2.4)
    elif e == 11:
        metal("main", "#C9C6BE", rough=0.32, met=0.4, grain=0.08, dirt=0.5, gain=g * 0.62)   # alliage blanc
        metal("titane", "#8E9AA6", rough=0.32, met=0.85, grain=0.1)
        emissive("emit", "#BFE6FF", 2.2)
    elif e == 12:
        metal("main", "#26282E", rough=0.3, met=0.6, grain=0.08, gain=g * 1.3)    # noir profond
        metal("chrome", "#9AA3AD", rough=0.14, met=1.0, grain=0.05)
        metal("givre", "#DDEEFF", rough=0.75, met=0.0, grain=0.35, gain=g * 0.6)
        emissive("emit", "#4AF0FF", 2.2)
    elif e == 13:
        metal("main", "#D9D6CF", rough=0.32, met=0.0, grain=0.08, dirt=0.5, gain=g * 0.62)   # céramique blanche
        metal("cuivre", "#B0703A", rough=0.3, met=0.9, grain=0.12)
        emissive("emit", "#FF4FD8", 2.4)
        emissive("emit2", "#FF9A3A", 2.6)
    elif e == 14:
        metal("main", "#C9A23A", rough=0.32, met=1.0, grain=0.45, dirt=0.45, gain=g * 0.75)  # feuille d'or froissée
        metal("blanc", "#CFCBC2", rough=0.4, met=0.1, grain=0.1, dirt=0.5, gain=g * 0.62)
        metal("cells", "#1E2A55", rough=0.18, met=0.35, grain=0.06, gain=g * 1.1)
        emissive("emit", "#FF2A2A", 2.6)
        emissive("emit2", "#2F6BFF", 1.6)
    elif e == 15:
        metal("main", "#E8DCB0", rough=0.28, met=0.9, grain=0.1, dirt=0.5, gain=g * 0.62)   # or blanc patiné
        metal("nacre", "#D8D2C8", rough=0.22, met=0.2, grain=0.08, dirt=0.5, gain=g * 0.62)
        emissive("emit", "#FFF2C0", 2.0)
    return M


# ------------------------------------------------------------------------------------------------
# Repères
# ------------------------------------------------------------------------------------------------
def gy(ty):
    """y de jeu (tuiles, vers le sud) -> Y Blender."""
    return -ty * SQ2


# ------------------------------------------------------------------------------------------------
# Époque 1 : pièce du niveau 2, posée sur le socle VANILLA (arc de sacs de sable)
# ------------------------------------------------------------------------------------------------
def sandbag(k, x, y, z, ang, m, length=0.30, depth=0.17, h=0.105):
    o = k.box((length, depth, h), (x, y, z + h / 2), m, rot=(0, 0, ang), bevel=0.035, name="sac")
    # léger affaissement : un sac est plus large en bas (deux boîtes)
    k.box((length * 0.92, depth * 1.08, h * 0.45), (x, y, z + h * 0.24), m, rot=(0, 0, ang), bevel=0.03, name="sac_b")
    return o


def piece_e01(k, M, part):
    """Arc de sacs de sable : coins avant et flancs (y de jeu ≥ -0,66), avant-centre libre.
    Dépasse de 0,10 de chaque côté (x ±1,10) et de 0,15 sous l'emprise (y de jeu +1,15).
    part = "avant" (devant le socle : jamais masqué) ou "flancs" (à côté du socle : masqué au pixel par
    l'alpha du socle vanilla, comme la variante « four » de V0)."""
    m = M["toile"]
    rnd = random.Random(101)
    if part == "flancs":
        # deux colonnes de sacs le long des flancs, de y de jeu -0,62 à +0,40
        for side in (-1, 1):
            xs = side * 1.015
            ys = [gy(t) for t in (-0.50, -0.25, 0.0, 0.25, 0.47)]
            for i, y in enumerate(ys):
                sandbag(k, xs + rnd.uniform(-0.01, 0.01), y, 0.0, math.pi / 2 + rnd.uniform(-0.08, 0.08), m,
                        length=0.36, depth=0.17)
            for i in range(len(ys) - 1):
                y = (ys[i] + ys[i + 1]) / 2
                sandbag(k, xs + side * 0.005, y, 0.105, math.pi / 2 + rnd.uniform(-0.1, 0.1), m, length=0.34,
                        depth=0.16)
    else:
        # coins avant : arc de la fin du flanc jusqu'à l'avant, avant-centre (|x| < 0,30) libre
        for side in (-1, 1):
            pts = []
            # arc de cercle en coordonnées de jeu, centré (side*0.62, +0.62), rayon 0,45
            for a in (0.0, 0.33, 0.66, 1.0):
                th = a * math.pi / 2
                tx = side * (0.60 + 0.415 * math.cos(th))
                ty = 0.62 + 0.45 * math.sin(th)
                pts.append((tx, ty, th))
            for tx, ty, th in pts:
                sandbag(k, tx, gy(ty), 0.0, (math.pi / 2 - th) * side + rnd.uniform(-0.06, 0.06), m, length=0.36)
            # bout de rangée vers le centre
            sandbag(k, side * 0.40, gy(1.07), 0.0, rnd.uniform(-0.05, 0.05), m, length=0.30)
            # 2e rangée sur l'arc
            for j in range(3):
                tx = (pts[j][0] + pts[j + 1][0]) / 2
                ty = (pts[j][1] + pts[j + 1][1]) / 2
                th = (pts[j][2] + pts[j + 1][2]) / 2
                sandbag(k, tx * 0.985, gy(ty) + 0.02, 0.105, (math.pi / 2 - th) * side + rnd.uniform(-0.08, 0.08), m,
                        length=0.34, depth=0.16)
        # piquets de bois qui retiennent l'arc
        for side in (-1, 1):
            k.cyl(0.022, 0.30, (side * 1.07, gy(0.62), 0.15), M["bois"], verts=8, name="piquet")


# ------------------------------------------------------------------------------------------------
# Socles (fixes) des époques 2 à 15, puis pièces des niveaux pairs
# ------------------------------------------------------------------------------------------------
def socle(k, e, M):
    """Renvoie la hauteur du dessus du socle (z de la couronne de rotation)."""
    if e == 2:   # socle octogonal cerclé, cornières aux 4 coins
        k.cyl(0.84, 0.24, (0, 0, 0.12), M["main"], verts=8, spin=math.pi / 8, bevel=0.02, name="plinthe")
        k.cyl(0.86, 0.06, (0, 0, 0.21), M["band"], verts=8, spin=math.pi / 8, bevel=0.01, name="cerclage")
        k.cyl(0.70, 0.08, (0, 0, 0.28), M["main"], verts=8, spin=math.pi / 8, bevel=0.015, name="gradin")
        k.rivet_ring(0.865, 0.21, 24, 0.018, M["brass"])
        for i in range(4):
            a = math.pi / 4 + i * math.pi / 2
            x, y = 0.80 * math.cos(a), 0.80 * math.sin(a)
            k.box((0.14, 0.30, 0.30), (x, y, 0.15), M["band"], rot=(0, 0, a), bevel=0.01, name="corniere")
            k.box((0.05, 0.30, 0.34), (x * 1.08, y * 1.08, 0.17), M["main"], rot=(0, 0, a), bevel=0.008, name="corniere2")
        return 0.32
    if e == 3:   # socle en fonte rond, nervuré
        k.cyl(0.82, 0.18, (0, 0, 0.09), M["fonte"], verts=48, bevel=0.02, name="pied")
        k.cyl(0.80, 0.16, (0, 0, 0.26), M["fonte"], r2=0.62, verts=48, bevel=0.01, name="collet")
        for i in range(10):
            a = TAU * i / 10 + 0.3
            k.box((0.05, 0.26, 0.26), (0.72 * math.cos(a), 0.72 * math.sin(a), 0.16), M["fonte"], rot=(0, 0, a),
                  bevel=0.01, name="nervure")
        k.tor(0.81, 0.025, (0, 0, 0.18), M["brass"], name="jonc")
        return 0.34
    if e == 4:   # plate-forme galvanisée à bande d'avertissement, 4 patins boulonnés
        k.cyl(0.80, 0.16, (0, 0, 0.08), M["galva"], verts=40, bevel=0.015, name="plate")
        for i in range(16):
            a = TAU * i / 16
            k.box((0.30, 0.03, 0.07), (0.805 * math.cos(a), 0.805 * math.sin(a), 0.11),
                  M["black"] if i % 2 else M["main"], rot=(0, 0, a + math.pi / 2), bevel=0.0, name="bande")
        k.cyl(0.66, 0.12, (0, 0, 0.22), M["main"], verts=40, bevel=0.012, name="tambour")
        for i in range(4):
            a = math.pi / 4 + i * math.pi / 2
            k.box((0.26, 0.22, 0.10), (0.78 * math.cos(a), 0.78 * math.sin(a), 0.05), M["galva"], rot=(0, 0, a),
                  bevel=0.01, name="patin")
        return 0.28
    if e == 5:   # tronc de pyramide en tungstène, contreforts inclinés, fentes de braise
        sq = [(0.86, 0.86), (-0.86, 0.86), (-0.86, -0.86), (0.86, -0.86)]
        k.frustum_poly(sq, 0.0, 0.34, 0.66, M["main"], bevel=0.02, name="pyramide")
        for i in range(4):
            a = math.pi / 4 + i * math.pi / 2
            c, s = math.cos(a), math.sin(a)
            poly = [(0.0, 0.0), (0.42, 0.0), (0.0, 0.36)]   # coin : profil (r, z)
            v = []
            for d in (-0.07, 0.07):
                for r, z in poly:
                    rr = 0.80 + r
                    v.append((rr * c - d * s, rr * s + d * c, z))
            k.mesh(v, [[0, 1, 2], [5, 4, 3], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]], M["rouille"], 0.008, "contrefort")
        # fentes de braise sur les faces avant et latérales (zones ≥ 8 × 8 px hr)
        for ang, (fx, fy) in ((0.0, (0.0, -0.74)), (math.pi / 2, (0.74, 0.0)), (-math.pi / 2, (-0.74, 0.0))):
            k.box((0.30, 0.04, 0.11), (fx, fy, 0.15), M["emit"], rot=(0.62 if ang == 0 else 0, 0, ang), bevel=0.0,
                  name="braise")
            for j in (-1, 1):
                k.box((0.035, 0.06, 0.13), (fx + (j * 0.16 if ang == 0 else 0), fy + (0 if ang == 0 else j * 0.16), 0.15),
                      M["rouille"], rot=(0, 0, ang), bevel=0.0, name="grille")
        return 0.36
    if e == 6:   # socle d'acier, couronne d'isolateurs qui DÉPASSE du plateau (bord « cranté » en silhouette)
        k.cyl(0.70, 0.16, (0, 0, 0.08), M["steel"], verts=40, bevel=0.015, name="plate")
        k.cyl(0.58, 0.10, (0, 0, 0.21), M["steel"], verts=40, bevel=0.012, name="moyeu")
        for i in range(8):
            a = TAU * i / 8 + math.pi / 8
            k.disc_stack(0.80 * math.cos(a), 0.80 * math.sin(a), 0.0, 5, 0.085, 0.06, 0.055, M["main"], cap=M["coil"])
        return 0.26
    if e == 7:   # bloc de pierre taillée irrégulier (arêtes vives, contour en dents) cerclé de bronze
        rnd = random.Random(7)
        poly = []
        for i in range(11):
            a = TAU * i / 11 + 0.2
            r = (0.84 if i % 2 == 0 else 0.70) + rnd.uniform(-0.05, 0.05)
            poly.append((r * math.cos(a), r * math.sin(a)))
        k.frustum_poly(poly, 0.0, 0.26, 0.82, M["pierre"], bevel=0.02, name="roc")
        # trois éclats de roche levés sur le pourtour arrière et latéral (asymétrie de l'ère III)
        for a, h in ((2.2, 0.42), (0.9, 0.34), (3.3, 0.30)):
            c, s = math.cos(a), math.sin(a)
            k.spike((0.70 * c, 0.70 * s, 0.10), (0.80 * c, 0.80 * s, 0.10 + h), 0.09, M["pierre"], sides=5, name="eclat_roc")
        k.tor(0.66, 0.035, (0, 0, 0.26), M["main"], name="sertissure")
        k.cyl(0.58, 0.08, (0, 0, 0.29), M["main"], verts=40, name="plateau")
        return 0.33
    if e == 8:   # base bombée vert-de-gris, jonc de caoutchouc, tubulures
        k.cyl(0.80, 0.12, (0, 0, 0.06), M["main"], verts=48, bevel=0.03, name="base")
        k.sph(0.70, (0, 0, 0.10), M["main"], scale=(1, 1, 0.30), seg=40, rings=16, name="dome")
        k.tor(0.80, 0.045, (0, 0, 0.11), M["rubber"], name="jonc")
        for i in range(4):
            a = math.pi / 4 + i * math.pi / 2
            k.cyl(0.05, 0.30, (0.70 * math.cos(a), 0.70 * math.sin(a), 0.16), M["main"], axis=(0.9, 0, a + math.pi / 2),
                  verts=12, name="tubulure")
        return 0.30
    if e == 9:   # base octogonale chanfreinée en béton, bande jaune
        k.cyl(0.84, 0.18, (0, 0, 0.09), M["beton"], verts=8, spin=math.pi / 8, bevel=0.01, name="beton")
        k.cyl(0.85, 0.06, (0, 0, 0.13), M["jaune"], verts=8, spin=math.pi / 8, bevel=0.0, name="bande")
        k.cyl(0.84, 0.10, (0, 0, 0.23), M["main"], r2=0.66, verts=8, spin=math.pi / 8, bevel=0.01, name="chanfrein")
        return 0.28
    if e == 10:  # disque caréné sur 3 pieds courts (vides sous le corps), bandeau bleu
        k.cyl(0.58, 0.10, (0, 0, 0.36), M["main"], verts=48, bevel=0.03, name="disque")
        k.cyl(0.59, 0.035, (0, 0, 0.36), M["emit"], verts=48, bevel=0.0, name="bandeau")
        k.cyl(0.30, 0.20, (0, 0, 0.22), M["noir"], verts=32, name="moyeu")
        for i in range(3):
            a = -math.pi / 2 + TAU * i / 3 + math.pi / 3
            c, s = math.cos(a), math.sin(a)
            k.spike((0.30 * c, 0.30 * s, 0.34), (0.86 * c, 0.86 * s * 1.15, 0.03), 0.05, M["main"], sides=8, name="pied")
            k.cyl(0.09, 0.04, (0.86 * c, 0.86 * s * 1.15, 0.02), M["noir"], verts=16, name="patin")
        return 0.41
    if e == 11:  # tripode à pieds en V, moyeu léger
        k.cyl(0.26, 0.10, (0, 0, 0.40), M["titane"], verts=32, name="moyeu")
        for i in range(3):
            a = -math.pi / 2 + TAU * i / 3 + math.pi / 3
            c, s = math.cos(a), math.sin(a)
            for d in (-0.16, 0.16):
                k.spike((0.20 * c, 0.20 * s, 0.40), (0.92 * c - d * s, 0.92 * s * 1.2 + d * c, 0.0), 0.035,
                        M["main"], sides=6, name="jambe")
            k.box((0.18, 0.10, 0.03), (0.92 * c, 0.92 * s * 1.2, 0.015), M["titane"], rot=(0, 0, a), name="semelle")
        return 0.45
    if e == 12:  # socle annulaire noir et chrome (vide au centre)
        k.tor(0.62, 0.11, (0, 0, 0.16), M["main"], mseg=14, name="anneau")
        k.tor(0.62, 0.035, (0, 0, 0.27), M["chrome"], name="jonc")
        k.tor(0.50, 0.03, (0, 0, 0.20), M["emit"], name="lueur")
        for i in range(4):
            a = math.pi / 4 + i * math.pi / 2
            k.box((0.16, 0.16, 0.10), (0.62 * math.cos(a), 0.62 * math.sin(a), 0.05), M["chrome"], rot=(0, 0, a),
                  name="plot")
        return 0.30
    if e == 13:  # trépied de céramique et cuivre, coupelle
        k.cyl(0.24, 0.10, (0, 0, 0.46), M["cuivre"], r2=0.30, verts=32, name="coupelle")
        for i in range(3):
            a = -math.pi / 2 + TAU * i / 3 + math.pi / 3
            c, s = math.cos(a), math.sin(a)
            k.spike((0.22 * c, 0.22 * s, 0.46), (0.90 * c, 0.90 * s * 1.15, 0.0), 0.05, M["main"], sides=8, name="jambe")
            k.sph(0.07, (0.90 * c, 0.90 * s * 1.15, 0.04), M["cuivre"], seg=12, rings=6, name="pied")
            k.sph(0.06, (0.55 * c, 0.55 * s * 1.08, 0.26), M["cuivre"], seg=12, rings=6, name="genou")
        return 0.51
    if e == 14:  # tambour en feuille d'or + 3 jambes d'atterrisseur
        k.cyl(0.46, 0.26, (0, 0, 0.19), M["main"], verts=8, spin=math.pi / 8, bevel=0.02, name="tambour")
        k.cyl(0.48, 0.04, (0, 0, 0.33), M["blanc"], verts=8, spin=math.pi / 8, name="anneau")
        for i in range(3):
            a = -math.pi / 2 + TAU * i / 3 + math.pi / 3
            c, s = math.cos(a), math.sin(a)
            k.spike((0.40 * c, 0.40 * s, 0.24), (0.88 * c, 0.88 * s * 1.15, 0.03), 0.035, M["blanc"], sides=6, name="jambe")
            k.cyl(0.10, 0.03, (0.88 * c, 0.88 * s * 1.15, 0.015), M["blanc"], verts=16, name="patin")
        return 0.35
    if e == 15:  # socle-disque flottant au-dessus d'un petit pied (vide sous le disque)
        k.cyl(0.20, 0.22, (0, 0, 0.11), M["nacre"], r2=0.12, verts=32, name="pied")
        k.cyl(0.72, 0.06, (0, 0, 0.27), M["main"], verts=64, bevel=0.02, name="disque")
        k.tor(0.56, 0.025, (0, 0, 0.305), M["emit"], seg=64, name="halo_disque")
        k.cyl(0.34, 0.05, (0, 0, 0.325), M["nacre"], verts=48, name="plateau")
        k.tor(0.73, 0.02, (0, 0, 0.27), M["nacre"], seg=64, name="jonc")
        return 0.35
    raise ValueError(e)


def fin(k, base, ang, pts, thick, mat, name):
    """Aileron plan : profil (s, z) dans le plan vertical de direction `ang` (radians, depuis +X), épaisseur `thick`."""
    ux, uy = math.cos(ang), math.sin(ang)
    nx, ny = -uy, ux
    v = []
    for side in (-0.5, 0.5):
        for s, z in pts:
            v.append((base[0] + ux * s + nx * thick * side, base[1] + uy * s + ny * thick * side, base[2] + z))
    n = len(pts)
    f = [list(range(n)), list(range(n, 2 * n))[::-1]] + [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    return k.mesh(v, f, mat, 0.006, name)


def piece(k, e, M):
    """Pièce du niveau pair 2e, sur le socle de l'époque e (zone toujours visible, y de jeu ≥ +0,11)."""
    FL, FR = (-0.86, gy(0.80)), (0.86, gy(0.80))   # coins avant de l'emprise (y de jeu +0,80)
    if e == 2:   # caisse de munitions cerclée sur le flanc gauche, dépasse de 0,10 à gauche
        x, y = -0.90, gy(0.40)
        k.box((0.36, 0.52, 0.30), (x, y, 0.15), M["bois"], bevel=0.015, name="caisse")
        for dy in (-0.18, 0.18):
            k.box((0.38, 0.04, 0.32), (x, y + dy, 0.155), M["band"], bevel=0.005, name="cercle")
        k.box((0.30, 0.44, 0.08), (x + 0.01, y, 0.34), M["bois"], rot=(0, 0.12, 0), bevel=0.01, name="couvercle")
        k.box((0.22, 0.30, 0.18), (x + 0.04, gy(0.86), 0.09), M["bois"], rot=(0, 0, 0.2), bevel=0.012, name="caisse2")
        return
    if e == 3:   # réservoir de vapeur debout au coin avant droit, dépasse de 0,10 à droite
        x, y = 0.93, gy(0.66)
        k.cyl(0.17, 0.56, (x, y, 0.28), M["main"], verts=32, bevel=0.01, name="reservoir")
        k.sph(0.17, (x, y, 0.56), M["main"], scale=(1, 1, 0.55), name="dome")
        for z in (0.12, 0.42):
            k.tor(0.172, 0.014, (x, y, z), M["brass"], name="cercle")
        k.cyl(0.035, 0.18, (x, y, 0.70), M["brass"], verts=12, name="soupape")
        k.cyl(0.07, 0.03, (x - 0.12, y - 0.10, 0.36), M["brass"], axis=(math.pi / 2, 0, -0.6), verts=20, name="manometre")
        k.cyl(0.035, 0.40, (x - 0.25, y + 0.05, 0.10), M["main"], axis="x", verts=12, name="tuyau")
        return
    if e == 4:   # passerelle à garde-corps autour de l'avant, dépasse de 0,15 de chaque côté
        yb, yf = gy(0.15), gy(1.05)
        k.box((2.30, yb - yf, 0.04), (0, (yb + yf) / 2, 0.10), M["galva"], bevel=0.005, name="caillebotis")
        for i in range(9):
            k.box((0.02, yb - yf - 0.04, 0.02), (-1.0 + i * 0.25, (yb + yf) / 2, 0.125), M["dark"], bevel=0, name="latte")
        posts = [(-1.13, yb), (-1.13, (yb + yf) / 2), (-1.13, yf), (-0.40, yf), (0.40, yf), (1.13, yf),
                 (1.13, (yb + yf) / 2), (1.13, yb)]
        for x, y in posts:
            k.cyl(0.022, 0.42, (x, y, 0.33), M["main"], verts=8, bevel=0, name="poteau")
        for z in (0.30, 0.52):
            k.box((0.03, yb - yf, 0.03), (-1.13, (yb + yf) / 2, z), M["main"], bevel=0, name="lisse")
            k.box((0.03, yb - yf, 0.03), (1.13, (yb + yf) / 2, z), M["main"], bevel=0, name="lisse")
            k.box((2.26, 0.03, 0.03), (0, yf, z), M["main"], bevel=0, name="lisse")
        k.box((2.30, 0.03, 0.08), (0, yf, 0.16), M["black"], bevel=0, name="plinthe")
        return
    if e == 5:   # jupe d'écailles inclinées autour de l'avant, dépasse de 0,15 au sud et sur les côtés
        for i in range(9):
            t = i / 8.0
            ang = math.pi * (1.0 + t)            # de l'ouest (π) au sud (3π/2) puis à l'est (2π)
            cx, cy = 1.02 * math.cos(ang), 1.02 * math.sin(ang) * 1.38
            if cy > 0.25:
                continue
            k.box((0.34, 0.06, 0.30), (cx, cy, 0.15), M["main"], rot=(0.55, 0, ang + math.pi / 2), bevel=0.012,
                  name="ecaille")
            k.sph(0.025, (cx * 1.04, cy * 1.04, 0.24), M["rouille"], seg=8, rings=4, name="rivet")
        return
    if e == 6:   # 2 condensateurs (piles d'isolateurs courtes) aux coins avant
        for x, y in (FL, FR):
            k.cyl(0.15, 0.08, (x, y, 0.04), M["steel"], verts=24, name="embase")
            ztop = k.disc_stack(x, y, 0.08, 6, 0.14, 0.10, 0.06, M["main"], cap=M["coil"])
            k.sph(0.07, (x, y, ztop + 0.05), M["emit"], seg=16, rings=8, name="eclateur")
            k.halo((x, y, ztop + 0.15), emit_rgb("#60D0FF"), 6.0)
        return
    if e == 7:   # grappes de cristaux aux coins avant
        rnd = random.Random(14)
        for x, y in (FL, FR):
            k.cyl(0.13, 0.08, (x, y, 0.04), M["main"], verts=7, name="sertissure")
            for j in range(4):
                a = TAU * j / 4 + rnd.uniform(-0.3, 0.3)
                L = rnd.uniform(0.30, 0.52)
                tilt = rnd.uniform(0.15, 0.45)
                tip = (x + math.cos(a) * tilt * L, y + math.sin(a) * tilt * L, 0.06 + L)
                k.spike((x + math.cos(a) * 0.03, y + math.sin(a) * 0.03, 0.04), tip, 0.06, M["emit"], sides=6, name="cristal")
            k.halo((x, y, 0.30), emit_rgb("#B070FF"), 6.0)
        return
    if e == 8:   # bonbonne de verre sur le flanc gauche (berceau de caoutchouc)
        x, y = -0.92, gy(0.42)
        k.cyl(0.22, 0.06, (x, y, 0.03), M["rubber"], verts=24, name="berceau")
        k.sph(0.24, (x, y, 0.27), M["glass"], seg=32, rings=16, name="bonbonne")
        k.sph(0.20, (x, y, 0.22), M["emit"], scale=(1, 1, 0.7), seg=24, rings=12, name="liquide")
        k.cyl(0.07, 0.14, (x, y, 0.55), M["glass"], verts=20, name="col")
        k.cyl(0.08, 0.04, (x, y, 0.63), M["rubber"], verts=20, name="bouchon")
        k.tor(0.24, 0.02, (x, y, 0.27), M["rubber"], name="sangle")
        k.halo((x, y, 0.3), emit_rgb("#A8FF3A"), 5.0)
        return
    if e == 9:   # plaques plombées avec trèfle devant les coins
        for x, y in (FL, FR):
            yy = y - 0.12
            k.box((0.42, 0.07, 0.42), (x, yy, 0.21), M["main"], rot=(-0.28, 0, 0), bevel=0.012, name="plaque")
            k.cyl(0.13, 0.02, (x, yy - 0.08, 0.24), M["jaune"], axis=(math.pi / 2 - 0.28, 0, 0), verts=24, name="disque")
            for j in range(3):
                a = math.pi / 2 + TAU * j / 3
                k.box((0.07, 0.015, 0.09), (x + 0.07 * math.cos(a), yy - 0.095, 0.24 + 0.07 * math.sin(a)), M["dark"],
                      rot=(-0.28, a - math.pi / 2, 0), bevel=0, name="pale")
            k.cyl(0.03, 0.022, (x, yy - 0.095, 0.24), M["dark"], axis=(math.pi / 2 - 0.28, 0, 0), verts=12, name="centre")
        return
    if e == 10:  # petit radôme de visée au coin avant droit
        x, y = FR
        k.cyl(0.05, 0.22, (x, y, 0.11), M["noir"], verts=16, name="mat")
        k.cyl(0.16, 0.06, (x, y, 0.03), M["main"], verts=32, name="embase")
        k.sph(0.19, (x, y, 0.34), M["main"], seg=32, rings=16, name="radome")
        k.cyl(0.192, 0.04, (x, y, 0.30), M["emit"], verts=32, name="voyant")
        k.halo((x, y, 0.45), emit_rgb("#3AA8FF"), 5.0)
        return
    if e == 11:  # ailerons de socle aux coins avant, orientés à 45° (lisibles de face comme de profil)
        for x, y in (FL, FR):
            a = math.radians(135 if x < 0 else 45)
            fin(k, (x, y, 0.0), a, [(-0.32, 0.0), (0.30, 0.0), (-0.20, 0.78)], 0.05, M["main"], "aileron")
            fin(k, (x, y, 0.0), a, [(-0.25, 0.30), (-0.17, 0.30), (-0.21, 0.66), (-0.27, 0.62)], 0.065, M["emit"], "ligne")
            k.box((0.12, 0.62, 0.05), (x, y, 0.025), M["titane"], rot=(0, 0, a - math.pi / 2), name="pied")
        return
    if e == 12:  # anneau flottant au sol, dépasse de 0,10 de chaque côté
        k.tor(1.04, 0.055, (0, 0, 0.30), M["chrome"], seg=72, mseg=12, name="anneau_flottant")
        k.tor(1.04, 0.03, (0, 0, 0.245), M["emit"], seg=72, name="anneau_lueur")
        k.halo((0, gy(0.7), 0.3), emit_rgb("#4AF0FF"), 6.0)
        return
    if e == 13:  # injecteurs aux coins avant
        for x, y in (FL, FR):
            sgn = 1 if x < 0 else -1
            k.cyl(0.12, 0.08, (x, y, 0.04), M["cuivre"], verts=20, name="embase")
            k.cyl(0.08, 0.40, (x + sgn * 0.03, y, 0.27), M["main"], r2=0.05, verts=20, name="injecteur")
            k.tor(0.085, 0.02, (x + sgn * 0.03, y, 0.18), M["cuivre"], name="bague")
            k.sph(0.075, (x + sgn * 0.05, y, 0.50), M["emit"], seg=16, rings=8, name="pointe")
            k.halo((x, y, 0.55), emit_rgb("#FF4FD8"), 6.0)
        return
    if e == 14:  # mât-balise au coin avant gauche, avec son coffret
        x, y = FL
        k.box((0.30, 0.30, 0.30), (x, y, 0.15), M["main"], bevel=0.02, name="coffret")
        k.cyl(0.035, 0.80, (x + 0.02, y + 0.04, 0.70), M["blanc"], verts=12, name="mat")
        k.sph(0.075, (x + 0.02, y + 0.04, 1.13), M["emit"], seg=16, rings=8, name="balise")
        k.cyl(0.10, 0.02, (x + 0.02, y + 0.04, 0.80), M["blanc"], verts=16, name="collerette")
        k.halo((x, y, 1.15), emit_rgb("#FF2A2A"), 6.0)
        return
    if e == 15:  # petites flèches aux coins avant
        for x, y in (FL, FR):
            k.cyl(0.11, 0.06, (x, y, 0.03), M["nacre"], verts=24, name="embase")
            k.spike((x, y, 0.06), (x, y, 0.72), 0.075, M["main"], sides=8, name="fleche")
            k.tor(0.085, 0.018, (x, y, 0.24), M["nacre"], name="bague")
            k.sph(0.06, (x, y, 0.76), M["emit"], seg=16, rings=8, name="feu")
            k.halo((x, y, 0.8), emit_rgb("#FFF2C0"), 6.0)
        return
    raise ValueError(e)

