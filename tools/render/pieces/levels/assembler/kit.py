"""Kit de modélisation de la famille « machine d'assemblage 2 » (lot V3, phase 1). S'exécute DANS Blender.

Repère (CALIBRATION.md §2) : coordonnées de JEU en tuiles (tx vers l'est, ty vers le SUD, origine = position de
l'entité au sol) et hauteur z en unités Blender. Une tuile vers le sud vaut √2 unité Blender en Y (grille étirée
en profondeur, objets à leurs vraies proportions). À l'écran (tuiles) : x = tx, y = ty - 0,7071·z.

Chaque objet porte la propriété « fo_module » (corps, meca, piece) : la phase 2 rendra le corps fixe une fois et
le mécanisme animé image par image (bible §2.8, §3.3-4), la pièce paire en couche séparée (§1.9).

Ce module n'utilise que les aides publiques de tools/render/blender/fo_scene.py (S) et les constantes de
tools/render/fo_calib.py (C) : il ne modifie aucun fichier partagé du pipeline.
"""
import math

import bmesh
import bpy
from mathutils import Quaternion, Vector

R2 = math.sqrt(2.0)          # une tuile vers le sud = √2 unité Blender
K45 = math.sqrt(0.5)         # hauteur z -> hauteur à l'écran (tuiles)


def P(tx, ty, z=0.0):
    """Coordonnées de jeu (tuiles, y vers le sud) + hauteur -> Blender."""
    return Vector((tx, -ty * R2, z))


def lin(hexstr):
    """Couleur sRGB « #RRGGBB » -> linéaire (Blender)."""
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def scale(c, k):
    return tuple(min(1.0, x * k) for x in c)


class Kit:
    """Aides de modélisation en coordonnées de jeu, avec étiquette de module."""

    def __init__(self, S, C):
        self.S, self.C = S, C
        self.module = "corps"
        self.gain = 1.0          # gain d'albédo de l'époque (photométrie mesurée sur le rendu : bible §1.5, règle 1)
        self.n = 0
        self._mats = {}

    # -- étiquettes -----------------------------------------------------------------------------
    def _tag(self, o):
        if o is not None:
            o["fo_module"] = self.module
        return o

    def nm(self, base):
        self.n += 1
        return "%s_%s_%03d" % (self.module, base, self.n)

    # -- matériaux --------------------------------------------------------------------------------
    def metal(self, key, hexcol, k=1.0, rough=0.45, metallic=0.45, grain=0.16, grain_scale=55.0, rust=None,
              rust_amount=0.0, rust_scale=6.0, dirt=0.45, seed=0.0):
        if key not in self._mats:
            self._mats[key] = self.S.mat_metal(
                "m_" + key, scale(lin(hexcol), k * self.gain), rough=rough, metallic=metallic, grain=grain,
                grain_scale=grain_scale, rust=lin(rust) if rust else None, rust_amount=rust_amount,
                rust_scale=rust_scale, dirt=dirt, seed=seed)
        return self._mats[key]

    def flat(self, key, hexcol, k=1.0, rough=0.6, metallic=0.0):
        if key not in self._mats:
            self._mats[key] = self.S.mat_flat("m_" + key, scale(lin(hexcol), k * self.gain), rough=rough,
                                              metallic=metallic)
        return self._mats[key]

    def emit(self, key, hexcol, strength=1.2, base="#1A1A1A", night_only=False):
        """Surface lumineuse (couches lueur et halo). night_only : allumée la nuit seulement (époques 1-2) :
        éteinte dans la passe principale, absente de la lueur, présente dans le halo."""
        if key not in self._mats:
            m = self.S.mat_emissive("m_" + key, lin(hexcol), strength=strength, base=lin(base))
            if night_only:
                m["fo_night_only"] = True
            self._mats[key] = m
        return self._mats[key]

    def emit_below(self, key, glass_hex, liquid_hex, level, strength=1.1, rough=0.12, night_only=False):
        """Verre opaque (pas de transparence : pas de fantôme la nuit) dont la partie sous `level` (z local
        de l'objet) est un liquide lumineux. La force d'émission reste une valeur simple (gain du halo)."""
        if key in self._mats:
            return self._mats[key]
        m = self.S.mat_emissive("m_" + key, lin(liquid_hex), strength=strength, base=lin(glass_hex))
        nt = m.node_tree
        N, L = nt.nodes, nt.links
        p = N["Principled BSDF"]
        p.inputs["Roughness"].default_value = rough
        tc = N.new("ShaderNodeTexCoord")
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(tc.outputs["Object"], sep.inputs["Vector"])
        cmp_ = N.new("ShaderNodeMath")
        cmp_.operation = "LESS_THAN"
        cmp_.inputs[1].default_value = level
        L.new(sep.outputs["Z"], cmp_.inputs[0])
        rgb = N.new("ShaderNodeRGB")
        c = lin(liquid_hex)
        rgb.outputs[0].default_value = (c[0], c[1], c[2], 1.0)
        mix = N.new("ShaderNodeVectorMath")
        mix.operation = "SCALE"
        L.new(rgb.outputs[0], mix.inputs[0])
        L.new(cmp_.outputs[0], mix.inputs["Scale"])
        L.new(mix.outputs["Vector"], p.inputs["Emission Color"])
        # la couleur de base suit aussi : verre dessus, liquide (clair) dessous
        g = lin(glass_hex)
        rgb2 = N.new("ShaderNodeRGB")
        rgb2.outputs[0].default_value = (g[0], g[1], g[2], 1.0)
        mixc = N.new("ShaderNodeMix")
        mixc.data_type = "RGBA"
        L.new(cmp_.outputs[0], mixc.inputs["Factor"])
        L.new(rgb2.outputs[0], mixc.inputs[6])
        L.new(rgb.outputs[0], mixc.inputs[7])
        L.new(mixc.outputs[2], p.inputs["Base Color"])
        if night_only:
            m["fo_night_only"] = True
        self._mats[key] = m
        return m

    # -- primitives (coordonnées de jeu) -----------------------------------------------------------
    def box(self, x0, x1, y0, y1, z0, z1, mat, name="boite", bevel=0.012):
        c = P((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
        size = (abs(x1 - x0), abs(y1 - y0) * R2, abs(z1 - z0))
        bw = min(bevel, 0.45 * min(size)) if bevel else 0
        return self._tag(self.S.box(size, tuple(c), mat, self.nm(name), bevel_w=bw))

    def rbox(self, x0, x1, y0, y1, z0, z1, mat, name="coque", r=0.12, seg=4):
        """Boîte aux arêtes arrondies (carénages lisses) : biseau à `seg` segments, normales durcies."""
        o = self.box(x0, x1, y0, y1, z0, z1, mat, name, bevel=0)
        for p in o.data.polygons:
            p.use_smooth = True
        dims = (abs(x1 - x0), abs(y1 - y0) * R2, abs(z1 - z0))
        mod = o.modifiers.new("arrondi", "BEVEL")
        mod.width = min(r, 0.45 * min(dims))
        mod.segments = seg
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35)
        try:
            mod.harden_normals = True
        except Exception:
            pass
        return o

    def cyl(self, tx, ty, z0, z1, r, mat, name="cyl", verts=32, r2=None, caps=True, bevel=0.006):
        """Cylindre (ou cône si r2) vertical. r en unités Blender (= tuiles en largeur)."""
        c = P(tx, ty, (z0 + z1) / 2.0)
        bw = min(bevel, 0.3 * min(r, z1 - z0)) if bevel else 0
        return self._tag(self.S.cylinder(r, z1 - z0, tuple(c), mat, self.nm(name), verts=verts, bevel_w=bw,
                                         radius2=r2, caps=caps))

    def _align(self, o, a, b):
        pa, pb = P(*a), P(*b)
        d = pb - pa
        o.location = (pa + pb) / 2.0
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
        return d.length

    def rod(self, a, b, r, mat, name="tige", verts=16, r2=None, caps=True, bevel=0.0):
        """Cylindre entre deux points (tx, ty, z)."""
        L = (P(*b) - P(*a)).length
        o = self.S.cylinder(r, L, (0, 0, 0), mat, self.nm(name), verts=verts, bevel_w=bevel, radius2=r2, caps=caps)
        self._align(o, a, b)
        return self._tag(o)

    def beam(self, a, b, w, h, mat, name="poutre", bevel=0.006, roll=0.0):
        """Poutre rectangulaire (w × h) entre deux points ; roll : rotation autour de l'axe."""
        L = (P(*b) - P(*a)).length
        o = self.S.box((w, h, L), (0, 0, 0), mat, self.nm(name), bevel_w=min(bevel, 0.4 * min(w, h)) if bevel else 0)
        self._align(o, a, b)
        if roll:
            o.rotation_quaternion = o.rotation_quaternion @ Quaternion((0, 0, 1), roll)
        return self._tag(o)

    def obox(self, at, size, rot, mat, name="plaque", bevel=0.006):
        """Boîte orientée : centre `at` (tx, ty, z), taille en unités Blender, rotation d'Euler (rad)."""
        o = self.S.box(size, (0, 0, 0), mat, self.nm(name), bevel_w=min(bevel, 0.4 * min(size)) if bevel else 0)
        o.location = P(*at)
        o.rotation_mode = "XYZ"
        o.rotation_euler = rot
        return self._tag(o)

    def sphere(self, tx, ty, z, r, mat, name="sphere", seg=32, rings=16):
        return self._tag(self.S.sphere(r, tuple(P(tx, ty, z)), mat, self.nm(name), seg=seg, rings=rings))

    def torus(self, tx, ty, z, R, r, mat, name="tore", axis="z", major_seg=64, minor_seg=12, tilt=0.0):
        rot = {"z": (tilt, 0, 0), "y": (math.pi / 2, 0, 0), "x": (0, math.pi / 2, 0)}[axis]
        return self._tag(self.S.torus(R, r, tuple(P(tx, ty, z)), mat, self.nm(name), rot=rot,
                                      major_seg=major_seg, minor_seg=minor_seg))

    # -- maillages libres -------------------------------------------------------------------------
    def mesh(self, verts, faces, mat, name="maille", bevel=0.01, smooth_deg=None):
        me = bpy.data.meshes.new(self.nm(name))
        me.from_pydata([tuple(v) for v in verts], [], faces)
        me.update()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new(me.name, me)
        bpy.context.scene.collection.objects.link(o)
        self.S._adopt(o, mat)
        if smooth_deg:
            self.S.smooth(o, smooth_deg)
        if bevel:
            self.S.bevel(o, bevel)
        return self._tag(o)

    def loft(self, rings, mat, name="loft", bevel=0.01, cap0=True, cap1=True, smooth_deg=None):
        """Surface entre anneaux de même nombre de points (listes de Vector Blender), bouchée aux bouts."""
        n = len(rings[0])
        verts, faces = [], []
        for ring in rings:
            verts.extend(ring)
        for k in range(len(rings) - 1):
            for i in range(n):
                a, b = k * n + i, k * n + (i + 1) % n
                faces.append((a, b, b + n, a + n))
        if cap0:
            faces.append(tuple(reversed(range(n))))
        if cap1:
            m = (len(rings) - 1) * n
            faces.append(tuple(m + i for i in range(n)))
        return self.mesh(verts, faces, mat, name, bevel=bevel, smooth_deg=smooth_deg)

    def prism(self, poly, z0, z1, mat, name="prisme", bevel=0.012, top=None):
        """Prisme vertical : polygone (tx, ty) au sol, extrudé de z0 à z1 ; top : polygone du dessus (tronc)."""
        top = top or poly
        r0 = [P(x, y, z0) for x, y in poly]
        r1 = [P(x, y, z1) for x, y in top]
        return self.loft([r0, r1], mat, name, bevel=bevel)

    def plate(self, poly_xz, y0, y1, mat, name="plaque", bevel=0.006):
        """Plaque : polygone (tx, z) dans un plan vertical est-ouest, épaisse de y0 à y1 (tuiles)."""
        r0 = [P(x, y0, z) for x, z in poly_xz]
        r1 = [P(x, y1, z) for x, z in poly_xz]
        return self.loft([r0, r1], mat, name, bevel=bevel)

    def plate_yz(self, poly_yz, x0, x1, mat, name="plaque", bevel=0.006):
        """Plaque : polygone (ty, z) dans un plan vertical nord-sud, épaisse de x0 à x1."""
        r0 = [P(x0, y, z) for y, z in poly_yz]
        r1 = [P(x1, y, z) for y, z in poly_yz]
        return self.loft([r0, r1], mat, name, bevel=bevel)

    def lathe(self, at, profile, mat, name="tour", verts=32, axis=None, bevel=0.0, smooth_deg=50, cap0=True,
              cap1=True):
        """Solide de révolution : profile = [(z, r), ...] le long de l'axe (Z local), posé en `at` (tx, ty, z) ;
        axis : direction (Vector Blender) de l'axe, verticale par défaut."""
        rings = []
        for z, r in profile:
            rr = max(r, 1e-4)
            rings.append([Vector((rr * math.cos(2 * math.pi * i / verts), rr * math.sin(2 * math.pi * i / verts), z))
                          for i in range(verts)])
        o = self.loft(rings, mat, name, bevel=bevel, cap0=cap0, cap1=cap1, smooth_deg=smooth_deg)
        o.location = P(*at)
        if axis is not None:
            o.rotation_mode = "QUATERNION"
            o.rotation_quaternion = Vector(axis).normalized().to_track_quat("Z", "Y")
        return o

    def crystal(self, at, h, r, mat, name="cristal", tilt=(0.0, 0.0), sides=6, spin=0.0):
        """Cristal : prisme à `sides` pans terminé en pointe, pied enterré ; tilt = (vers l'est, vers le sud) en rad."""
        ring = lambda z, rr: [Vector((rr * math.cos(spin + 2 * math.pi * i / sides),
                                      rr * math.sin(spin + 2 * math.pi * i / sides), z)) for i in range(sides)]
        rings = [ring(-0.15 * h, r * 0.7), ring(0.0, r), ring(0.72 * h, r * 0.92), ring(h, r * 0.02)]
        o = self.loft(rings, mat, name, bevel=0.0)
        o.location = P(*at)
        o.rotation_mode = "XYZ"
        o.rotation_euler = (tilt[1], tilt[0], 0.0)
        return o

    def gear(self, at, axis, R, th, teeth, mat, name="engrenage", phase=0.0, hub=None):
        """Roue dentée : centre `at`, axe 'x', 'y' (face au sud, lisible à l'écran) ou 'z' ; phase en rad."""
        objs = []
        S = self.S
        objs.append(S.cylinder(R * 0.84, th, (0, 0, 0), mat, self.nm(name + "_disque"), verts=48, bevel_w=0.004))
        tooth = 2 * math.pi * R / teeth * 0.45
        for i in range(teeth):
            a = phase + 2 * math.pi * i / teeth
            b = S.box((R * 0.26, tooth, th * 0.9), (math.cos(a) * R * 0.9, math.sin(a) * R * 0.9, 0), mat,
                      self.nm(name + "_dent"), bevel_w=0)
            b.rotation_euler = (0, 0, a)
            objs.append(b)
        objs.append(S.cylinder(hub or R * 0.22, th * 1.6, (0, 0, 0), mat, self.nm(name + "_moyeu"), verts=24,
                               bevel_w=0.003))
        o = S.join(objs, self.nm(name))
        o.location = P(*at)
        o.rotation_mode = "XYZ"
        o.rotation_euler = {"z": (0, 0, 0), "y": (math.pi / 2, 0, 0), "x": (0, math.pi / 2, 0)}[axis]
        return self._tag(o)

    def wheel(self, at, axis, R, th, spokes, mat_rim, mat_spoke, name="volant", phase=0.0):
        """Volant à rayons (jante torique, moyeu, rayons)."""
        S = self.S
        objs = [S.torus(R - th * 0.5, th * 0.5, (0, 0, 0), mat_rim, self.nm(name + "_jante"), minor_seg=10)]
        objs.append(S.cylinder(R * 0.16, th * 1.8, (0, 0, 0), mat_rim, self.nm(name + "_moyeu"), verts=24,
                               bevel_w=0.003))
        for i in range(spokes):
            a = phase + 2 * math.pi * i / spokes
            b = S.box((R * 0.9, th * 0.42, th * 0.6), (math.cos(a) * R * 0.45, math.sin(a) * R * 0.45, 0),
                      mat_spoke, self.nm(name + "_rayon"), bevel_w=0)
            b.rotation_euler = (0, 0, a)
            objs.append(b)
        o = S.join(objs, self.nm(name))
        o.location = P(*at)
        o.rotation_mode = "XYZ"
        o.rotation_euler = {"z": (0, 0, 0), "y": (math.pi / 2, 0, 0), "x": (0, math.pi / 2, 0)}[axis]
        return self._tag(o)

    def tube(self, pts, r, mat, name="tube", res=6):
        """Tuyau, câble ou serpentin : courbe passant par pts (tx, ty, z), section ronde de rayon r."""
        cu = bpy.data.curves.new(self.nm(name), "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = r
        cu.bevel_resolution = 3
        cu.use_fill_caps = True
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for i, p in enumerate(pts):
            v = P(*p)
            sp.points[i].co = (v.x, v.y, v.z, 1.0)
        o = bpy.data.objects.new(cu.name, cu)
        bpy.context.scene.collection.objects.link(o)
        bpy.context.view_layer.objects.active = o
        for ob in bpy.context.view_layer.objects:
            ob.select_set(False)
        o.select_set(True)
        bpy.ops.object.convert(target="MESH")
        o = bpy.context.active_object
        self.S._adopt(o, mat)
        self.S.smooth(o, 60)
        return self._tag(o)

    def rivets(self, a, b, n, r, mat, name="rivets"):
        """Rangée de n rivets (demi-sphères) de a à b (tx, ty, z)."""
        objs = []
        for i in range(n):
            f = (i + 0.5) / n
            p = [a[k] + (b[k] - a[k]) * f for k in range(3)]
            objs.append(self.S.sphere(r, tuple(P(*p)), mat, self.nm(name), seg=10, rings=5))
        return self._tag(self.S.join(objs, self.nm(name)))

    def halo(self, tx, ty, z, hexcol, power, radius=0.05):
        """Source ponctuelle de la seule passe halo (draw_as_light)."""
        return self.S.halo_light(tuple(P(tx, ty, z)), lin(hexcol), power, radius=radius, name=self.nm("halo"))

    def join(self, objs, name):
        o = self.S.join([x for x in objs if x is not None], self.nm(name))
        return self._tag(o)
