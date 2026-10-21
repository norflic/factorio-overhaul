"""Boîte à outils de modélisation du centre de commandement (lot V3-a, phase 1).

S'exécute DANS Blender (appelé par centre.py) : reçoit S (tools/render/blender/fo_scene.py) et C
(tools/render/fo_calib.py). Ne modifie aucun fichier partagé du pipeline : tout ce qui manque au pipeline
(lofts, surfaces de révolution, repère de jeu, étiquettes de couches) est écrit ici.

Repère de JEU (celui de la bible) : x vers l'est, ty vers le SUD, en tuiles, origine au centre de l'entité,
z vers le haut en unités Blender (1 unité de hauteur = 45,25 px HR à l'écran, soit 0,707 tuile).
Une tuile vers le sud vaut 1/cos 45° = 1,414 unité Blender en Y (CALIBRATION.md §2).
Écran (tuiles) : u = x ; v = ty - 0,707·z (v vers le bas).

Étiquettes de pièces (propriété « fo_role ») :
  mass : masse principale (compte dans O et dans tous les masques) ;
  tige : tige fine, mât, antenne, drapeau du mât (compte dans les masques, PAS dans O, bible §1.4) ;
  flat : couche plate posée au sol (dalle, plate-forme basse) : exclue du masque D1-3 amendé (Q13).
Variantes : « -sil » omet les pièces flat ; « -mass » omet flat et tige ; « -jour » éteint les émissifs
(époques 1 et 2 : lumière de nuit seulement) ; « -nuit » les allume (passes lueur et halo).
"""
import math

R2 = 2.0 ** 0.5          # profondeur Blender d'une tuile de jeu vers le sud (1/cos 45°)
K = 0.5 ** 0.5           # projection de la hauteur et de la profondeur à l'écran (cos 45° = sin 45°)


def srgb(hexcol):
    """'#5A5048' -> couleur LINÉAIRE (r, g, b)."""
    h = hexcol.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def mix(a, b, t):
    return tuple(x * (1 - t) + y * t for x, y in zip(a, b))


def scale(c, g):
    return tuple(min(1.0, x * g) for x in c)


class Kit:
    def __init__(self, S, C, level, flags, gain=1.0):
        import bpy  # noqa: F401  (présent : on est dans Blender)
        self.S, self.C = S, C
        self.level = level
        self.flags = set(flags)
        self.skip_flat = "sil" in self.flags or "mass" in self.flags
        self.skip_tige = "mass" in self.flags
        # émissifs : allumés sauf « -jour » (époques 1-2 de jour)
        self.lit = "jour" not in self.flags
        self.gain = gain
        self._mats = {}
        self._seed = 1.0
        self.objects = []

    # ---------------------------------------------------------------- repère
    @staticmethod
    def P(tx, ty, z=0.0):
        """Point du jeu -> Blender."""
        return (tx, -ty * R2, z)

    def _skip(self, role):
        return (role == "flat" and self.skip_flat) or (role == "tige" and self.skip_tige)

    def _tag(self, o, role):
        if o is None:
            return None
        o["fo_role"] = role
        self.objects.append(o)
        return o

    # ---------------------------------------------------------------- matériaux
    def _next_seed(self):
        self._seed += 1.37
        return self._seed

    def metal(self, key, hexcol, rough=0.45, metallic=0.6, grain=0.18, grain_scale=55.0, rust=None,
              rust_amount=0.0, dirt=0.45, gain=None):
        name = "c%02d_%s" % (self.level, key)
        if name in self._mats:
            return self._mats[name]
        g = self.gain if gain is None else gain
        col = scale(srgb(hexcol), g)
        rc = scale(srgb(rust), g) if rust else None
        m = self.S.mat_metal(name, col, rough=rough, metallic=metallic, grain=grain, grain_scale=grain_scale,
                             rust=rc, rust_amount=rust_amount, dirt=dirt, seed=self._next_seed())
        self._mats[name] = m
        return m

    def matte(self, key, hexcol, rough=0.75, grain=0.22, grain_scale=40.0, dirt=0.5, gain=None):
        """Matière non métallique (bois, toile, pierre, brique, béton, céramique) : grain + crasse des creux."""
        return self.metal(key, hexcol, rough=rough, metallic=0.0, grain=grain, grain_scale=grain_scale, dirt=dirt,
                          gain=gain)

    def glass(self, key, hexcol, gain=None):
        """Verre stylisé OPAQUE (alpha 1, bible §5 époque 8 : le verre doit compter dans la silhouette) :
        brillant, peu rugueux, non métallique."""
        name = "c%02d_%s" % (self.level, key)
        if name in self._mats:
            return self._mats[name]
        g = self.gain if gain is None else gain
        m = self.S.mat_flat(name, scale(srgb(hexcol), g), rough=0.12, metallic=0.0)
        self._mats[name] = m
        return m

    def emit(self, key, hexcol, strength=1.4, off_hex="#2A2622"):
        """Surface lumineuse (couches lueur et halo). Éteinte (verre sombre) dans la variante « -jour »."""
        name = "c%02d_%s%s" % (self.level, key, "" if self.lit else "_off")
        if name in self._mats:
            return self._mats[name]
        if self.lit:
            m = self.S.mat_emissive(name, srgb(hexcol), strength=strength)
        else:
            m = self.S.mat_flat(name, scale(srgb(off_hex), 1.0), rough=0.25, metallic=0.0)
        self._mats[name] = m
        return m

    # ---------------------------------------------------------------- objets
    def adopt(self, o, mat=None, name=None):
        coll = self.S.piece_collection()
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
        if name:
            o.name = name
        if mat is not None:
            o.data.materials.clear()
            o.data.materials.append(mat)
        return o

    def box(self, x0, x1, ty0, ty1, z0, z1, mat, name, bevel=0.012, role="mass", rot_z=0.0):
        """Boîte alignée sur la grille du jeu (étendues en tuiles de jeu, hauteurs en unités)."""
        if self._skip(role):
            return None
        cx, cty, cz = (x0 + x1) / 2.0, (ty0 + ty1) / 2.0, (z0 + z1) / 2.0
        o = self.S.box((abs(x1 - x0), abs(ty1 - ty0) * R2, abs(z1 - z0)), self.P(cx, cty, cz), mat, name,
                       bevel_w=bevel)
        if rot_z:
            o.rotation_euler = (0, 0, rot_z)
        return self._tag(o, role)

    def bbox(self, cx, cty, cz, sx, sy, sz, mat, name, rot=(0, 0, 0), bevel=0.01, role="mass"):
        """Boîte en unités BLENDER (sx, sy, sz), centrée en un point du jeu, avec rotation libre."""
        if self._skip(role):
            return None
        o = self.S.box((sx, sy, sz), self.P(cx, cty, cz), mat, name, bevel_w=bevel)
        o.rotation_euler = rot
        return self._tag(o, role)

    def cyl(self, tx, ty, r, z0, z1, mat, name, verts=40, r2=None, caps=True, bevel=0.006, role="mass", rot_z=0.0):
        """Cylindre (ou tronc de cône) VERTICAL, rond en 3D, pied en (tx, ty)."""
        if self._skip(role):
            return None
        o = self.S.cylinder(r, z1 - z0, self.P(tx, ty, (z0 + z1) / 2.0), mat, name, verts=verts, bevel_w=bevel,
                            radius2=r2, caps=caps, rot=(0, 0, rot_z))
        return self._tag(o, role)

    def hcyl(self, axis, a0, a1, tx, ty, zc, r, mat, name, verts=32, bevel=0.006, role="mass", r2=None):
        """Cylindre HORIZONTAL : axis 'x' (de x=a0 à a1, à ty) ou 'y' (de ty=a0 à a1, à x=tx)."""
        if self._skip(role):
            return None
        if axis == "x":
            c = self.P((a0 + a1) / 2.0, ty, zc)
            depth = abs(a1 - a0)
            rot = (0, math.pi / 2, 0)
        else:
            c = self.P(tx, (a0 + a1) / 2.0, zc)
            depth = abs(a1 - a0) * R2
            rot = (math.pi / 2, 0, 0)
        o = self.S.cylinder(r, depth, c, mat, name, verts=verts, rot=rot, bevel_w=bevel, radius2=r2)
        return self._tag(o, role)

    def sphere(self, tx, ty, zc, R, mat, name, seg=48, rings=24, sz=1.0, role="mass"):
        if self._skip(role):
            return None
        o = self.S.sphere(R, self.P(tx, ty, zc), mat, name, seg=seg, rings=rings)
        if sz != 1.0:
            o.scale = (1, 1, sz)
        return self._tag(o, role)

    def torus(self, tx, ty, zc, R, r, mat, name, rot=(0, 0, 0), major_seg=72, minor_seg=14, role="mass"):
        if self._skip(role):
            return None
        o = self.S.torus(R, r, self.P(tx, ty, zc), mat, name, rot=rot, major_seg=major_seg, minor_seg=minor_seg)
        return self._tag(o, role)

    def mesh(self, name, verts, faces, mat, smooth=None, bevel=0.0, role="mass"):
        """Maillage libre (sommets Blender), normales recalculées vers l'extérieur."""
        if self._skip(role):
            return None
        import bpy
        import bmesh
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
        me.validate()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
        o = bpy.data.objects.new(name, me)
        self.adopt(o, mat)
        if smooth:
            self.S.smooth(o, smooth)
        if bevel:
            self.S.bevel(o, bevel)
        return self._tag(o, role)

    def loft(self, rings, mat, name, cap0=True, cap1=True, smooth=None, bevel=0.0, role="mass"):
        """Surface qui relie des anneaux de points 3D Blender (même nombre de points, ou 1 point = pointe)."""
        verts, faces, idx = [], [], []
        for ring in rings:
            start = len(verts)
            verts.extend(ring)
            idx.append(list(range(start, start + len(ring))))
        for a, b in zip(idx[:-1], idx[1:]):
            if len(a) == 1 and len(b) == 1:
                continue
            if len(b) == 1:
                for i in range(len(a)):
                    faces.append((a[i], a[(i + 1) % len(a)], b[0]))
            elif len(a) == 1:
                for i in range(len(b)):
                    faces.append((b[(i + 1) % len(b)], b[i], a[0]))
            else:
                n = len(a)
                for i in range(n):
                    faces.append((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
        if cap0 and len(idx[0]) > 2:
            faces.append(tuple(reversed(idx[0])))
        if cap1 and len(idx[-1]) > 2:
            faces.append(tuple(idx[-1]))
        return self.mesh(name, verts, faces, mat, smooth=smooth, bevel=bevel, role=role)

    def prism(self, poly_game, z0, z1, mat, name, top_poly_game=None, bevel=0.01, role="mass", smooth=None):
        """Prisme (ou tronc) vertical : polygone en coordonnées de JEU (x, ty), de z0 à z1 ; le polygone du
        haut peut différer (même nombre de sommets) pour un tronc, un coin, un contrefort."""
        top = top_poly_game or poly_game
        r0 = [self.P(x, ty, z0) for x, ty in poly_game]
        r1 = [self.P(x, ty, z1) for x, ty in top]
        return self.loft([r0, r1], mat, name, bevel=bevel, role=role, smooth=smooth)

    def lathe(self, tx, ty, profile, mat, name, segs=48, smooth=70, role="mass", sx=1.0, sy=1.0):
        """Surface de révolution autour d'un axe vertical en (tx, ty) : profile = [(rayon, z), ...] (unités
        Blender, du bas vers le haut ; rayon 0 = pôle). sx, sy : étirement de la section (ellipse)."""
        cx, cy, _ = self.P(tx, ty, 0)
        rings = []
        for r, z in profile:
            if r <= 1e-6:
                rings.append([(cx, cy, z)])
            else:
                rings.append([(cx + sx * r * math.cos(2 * math.pi * i / segs),
                               cy + sy * r * math.sin(2 * math.pi * i / segs), z) for i in range(segs)])
        return self.loft(rings, mat, name, smooth=smooth, role=role)

    def ngon(self, tx, ty, r, n, z0, z1, mat, name, r_top=None, rot=0.0, sy=1.0, bevel=0.01, role="mass"):
        """Prisme régulier à n côtés (r en unités Blender ; sy étire en profondeur), tronc si r_top."""
        cx, cy, _ = self.P(tx, ty, 0)
        rt = r if r_top is None else r_top

        def ring(rr, z):
            if rr <= 1e-6:
                return [(cx, cy, z)]
            return [(cx + rr * math.cos(rot + 2 * math.pi * i / n), cy + sy * rr * math.sin(rot + 2 * math.pi * i / n), z)
                    for i in range(n)]
        return self.loft([ring(r, z0), ring(rt, z1)], mat, name, bevel=bevel, role=role)

    def rod(self, p0, p1, r, mat, name, verts=10, role="mass", bevel=0.0):
        """Barre cylindrique entre deux points BLENDER (poutres, haubans, pieds, arcs segmentés)."""
        if self._skip(role):
            return None
        from mathutils import Vector
        a, b = Vector(p0), Vector(p1)
        d = b - a
        L = d.length
        o = self.S.cylinder(r, L, tuple((a + b) / 2), mat, name, verts=verts, bevel_w=bevel)
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        return self._tag(o, role)

    def join(self, objs, name):
        objs = [o for o in objs if o is not None]
        if not objs:
            return None
        role = objs[0].get("fo_role", "mass")
        for o in objs:
            if o in self.objects:
                self.objects.remove(o)
        j = self.S.join(objs, name)
        return self._tag(j, role)

    def halo(self, tx, ty, z, hexcol, power, radius=0.06, name="halo"):
        """Source ponctuelle de la seule passe halo (draw_as_light)."""
        return self.S.halo_light(self.P(tx, ty, z), srgb(hexcol), power, radius=radius, name=name)

    # ---------------------------------------------------------------- éléments récurrents
    def door(self, x0, x1, ty, z1, frame_mat, leaf_mat, name="porte", depth=0.06, arch=False):
        """Porte centrale au SUD (invariant de famille) : cadre + vantail, plaquée sur une façade à ty."""
        objs = []
        objs.append(self.box(x0 - 0.05, x1 + 0.05, ty - 0.02, ty + depth, 0.0, z1 + 0.06, frame_mat, name + "_cadre",
                             bevel=0.008))
        objs.append(self.box(x0, x1, ty, ty + depth + 0.02, 0.02, z1, leaf_mat, name + "_vantail", bevel=0.006))
        return objs

    def mast(self, tx, ty, z0, z1, r, mat, name="mat", verts=10):
        """Mât de commandement (tige : ne compte pas dans O)."""
        return self.cyl(tx, ty, r, z0, z1, mat, name, verts=verts, bevel=0, role="tige")

    def flag(self, tx, ty, z_top, w, h, mat, name="drapeau", side=1):
        """Drapeau rectangulaire légèrement ondulé, accroché au mât (rôle tige : accessoire du mât)."""
        if self._skip("tige"):
            return None
        cx, cy, _ = self.P(tx, ty, 0)
        n = 6
        verts, faces = [], []
        for i in range(n + 1):
            t = i / n
            x = cx + side * (0.02 + t * w)
            yy = cy + 0.05 * math.sin(t * math.pi * 1.6)
            zz = z_top - 0.03 * t
            verts.append((x, yy, zz))
            verts.append((x, yy, zz - h + 0.04 * t))
        for i in range(n):
            a = 2 * i
            faces.append((a, a + 2, a + 3, a + 1))
        o = self.mesh(name, verts, faces, mat, role="tige")
        if o is not None:
            mod = o.modifiers.new("epais", "SOLIDIFY")
            mod.thickness = 0.012
        return o

    def lattice_mast(self, tx, ty, z0, z1, w0, w1, mat, name="treillis", panels=6, r=0.012):
        """Mât en treillis à 4 montants (tige), largeur w0 en bas, w1 en haut (unités Blender)."""
        if self._skip("tige"):
            return None
        cx, cy, _ = self.P(tx, ty, 0)
        parts = []
        cs = ((-1, -1), (1, -1), (1, 1), (-1, 1))
        for i in range(panels + 1):
            t = i / panels
            z = z0 + (z1 - z0) * t
            w = w0 + (w1 - w0) * t
            pts = [(cx + sx * w / 2, cy + sy * w / 2, z) for sx, sy in cs]
            if i < panels:
                t2 = (i + 1) / panels
                z2 = z0 + (z1 - z0) * t2
                w2 = w0 + (w1 - w0) * t2
                pts2 = [(cx + sx * w2 / 2, cy + sy * w2 / 2, z2) for sx, sy in cs]
                for k in range(4):
                    parts.append(self.rod(pts[k], pts2[k], r * 1.3, mat, "%s_m%d_%d" % (name, i, k), verts=6, role="tige"))
                    parts.append(self.rod(pts[k], pts2[(k + 1) % 4], r * 0.8, mat, "%s_d%d_%d" % (name, i, k), verts=6,
                                          role="tige"))
            for k in range(4):
                parts.append(self.rod(pts[k], pts[(k + 1) % 4], r * 0.8, mat, "%s_h%d_%d" % (name, i, k), verts=6,
                                      role="tige"))
        return self.join(parts, name)

    def rivets_line(self, p0, p1, n, r, mat, name):
        """Rangée de rivets (demi-sphères) entre deux points Blender."""
        objs = []
        for i in range(n):
            t = (i + 0.5) / n
            p = tuple(a + (b - a) * t for a, b in zip(p0, p1))
            objs.append(self.S.sphere(r, p, mat, "%s_%d" % (name, i), seg=10, rings=5))
        for o in objs:
            self._tag(o, "mass")
        return self.join(objs, name)

    def railing(self, pts_game, z, h, mat, name, posts_every=0.35, r=0.008):
        """Garde-corps (tige fine) le long d'une polyligne de jeu, à la hauteur z."""
        parts = []
        P = [self.P(x, ty, z) for x, ty in pts_game]
        for a, b in zip(P[:-1], P[1:]):
            parts.append(self.rod((a[0], a[1], a[2] + h), (b[0], b[1], b[2] + h), r, mat, name + "_main", verts=6, role="tige"))
            parts.append(self.rod((a[0], a[1], a[2] + h * 0.5), (b[0], b[1], b[2] + h * 0.5), r * 0.8, mat, name + "_mi",
                                  verts=6, role="tige"))
            L = math.dist(a[:2], b[:2])
            n = max(1, int(L / posts_every))
            for i in range(n + 1):
                t = i / n
                p = tuple(u + (v - u) * t for u, v in zip(a, b))
                parts.append(self.rod(p, (p[0], p[1], p[2] + h), r, mat, name + "_p", verts=6, role="tige"))
        return self.join(parts, name)
