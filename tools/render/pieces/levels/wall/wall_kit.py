"""Boîte à outils de modélisation du mur (lot V3, famille « wall », phase 1). S'exécute DANS Blender.

Complète tools/render/blender/fo_scene.py (fichier partagé, NON modifié) par :
- des primitives en coordonnées de JEU (x vers l'est, ty vers le sud, en tuiles ; z en unités Blender) ;
- des maillages libres (prismes extrudés d'un profil, tubes le long d'un chemin, pyramides) ;
- des matériaux propres à la famille (brique, bandes d'avertissement, feuille d'or froissée, champ de
  plasma semi-transparent, givre), construits avec les mêmes conventions que fo_scene (fo_kind,
  fo_emit_strength, nœud « Principled BSDF » présent pour la passe halo).

Projection (CALIBRATION.md §2) : un point (x, ty, z) se projette à l'écran en u = x, v = ty - z·cos 45°
(en tuiles). zv(v, ty) donne la hauteur z qui place un point de profondeur ty à l'ordonnée écran v.
"""
import math

import bmesh
import bpy
from mathutils import Vector

SQ2 = math.sqrt(2.0)
K = 1.0 / SQ2


def zv(v, ty):
    """Hauteur z (unités Blender) d'un point de profondeur ty (tuiles) projeté à l'ordonnée écran v."""
    return (ty - v) / K


# Albédo linéaire maximal après gain d'époque : aucun blanc pur (bible §1.5 règle 2, p95 ≤ 240) ; un albédo
# borné à 1 donnait des dessus blancs saturés (aperçu du 21/10, époque 2 : chapeaux des merlons à 255).
ALB_MAX = 0.80
EMIT_MAX = 1.3


def lin(hexs, mul=1.0, cap=1.0):
    """Couleur sRGB « #RRGGBB » -> linéaire (Blender), multipliée par mul (bornée à cap)."""
    h = hexs.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        c = c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
        out.append(min(cap, c * mul))
    return tuple(out)


class Kit:
    def __init__(self, S, C):
        self.S = S
        self.C = C
        self.mcache = {}
        self.n = 0
        self.pending_rivets = []
        self.gain = 1.0          # gain d'albédo de l'époque (réglé sur la luminance médiane rendue, bible §1.5)
        self.metal_cap = 0.5     # métal plafonné : un métal pur reflète le ciel faible et noircit les façades

    # ------------------------------------------------------------------ coordonnées
    @staticmethod
    def P(x, ty, z=0.0):
        return (x, -ty * SQ2, z)

    def _name(self, name):
        self.n += 1
        return "%s_%03d" % (name, self.n)

    # ------------------------------------------------------------------ primitives
    def box(self, x0, x1, t0, t1, z0, z1, mat, name="boite", bev=0.008):
        sx, sy, sz = x1 - x0, (t1 - t0) * SQ2, z1 - z0
        b = min(bev, 0.3 * min(sx, sy, sz))
        return self.S.box((sx, sy, sz), self.P((x0 + x1) / 2, (t0 + t1) / 2, (z0 + z1) / 2), mat, self._name(name),
                          bevel_w=b if b > 0.0015 else 0)

    def cylv(self, x, t, z0, z1, r, mat, name="cyl", verts=32, r2=None, caps=True, bev=0.004, rotz=0.0):
        o = self.S.cylinder(r, z1 - z0, self.P(x, t, (z0 + z1) / 2), mat, self._name(name), verts=verts,
                            bevel_w=bev if bev and r > 3 * bev else 0, radius2=r2, caps=caps)
        if rotz:
            o.rotation_euler = (0, 0, rotz)
        return o

    def cylx(self, x0, x1, t, z, r, mat, name="cylx", verts=24, bev=0.0):
        return self.S.cylinder(r, x1 - x0, self.P((x0 + x1) / 2, t, z), mat, self._name(name), verts=verts,
                               rot=(0, math.pi / 2, 0), bevel_w=bev)

    def cyly(self, x, t0, t1, z, r, mat, name="cyly", verts=24, bev=0.0):
        """Cylindre d'axe nord-sud (disque face à la caméra : ellipse à l'écran)."""
        return self.S.cylinder(r, (t1 - t0) * SQ2, self.P(x, (t0 + t1) / 2, z), mat, self._name(name), verts=verts,
                               rot=(math.pi / 2, 0, 0), bevel_w=bev)

    def sph(self, x, t, z, r, mat, name="sphere", seg=24, rings=12):
        return self.S.sphere(r, self.P(x, t, z), mat, self._name(name), seg=seg, rings=rings)

    def tor_h(self, x, t, z, R, r, mat, name="anneau", seg=48, mseg=10):
        """Anneau horizontal (axe vertical)."""
        return self.S.torus(R, r, self.P(x, t, z), mat, self._name(name), major_seg=seg, minor_seg=mseg)

    def tor_f(self, x, t, z, R, r, mat, name="anneau_face", seg=48, mseg=10, tilt=0.0):
        """Anneau vertical face au sud (axe nord-sud) ; tilt : inclinaison autour de x (radians)."""
        return self.S.torus(R, r, self.P(x, t, z), mat, self._name(name), rot=(math.pi / 2 + tilt, 0, 0),
                            major_seg=seg, minor_seg=mseg)

    def pyr(self, x, t, z0, z1, r, mat, name="pointe", sides=4, rotz=None, r2=0.0, bev=0.0):
        o = self.S.cylinder(r, z1 - z0, self.P(x, t, (z0 + z1) / 2), mat, self._name(name), verts=sides,
                            radius2=r2, bevel_w=bev)
        o.rotation_euler = (0, 0, math.pi / sides if rotz is None else rotz)
        return o

    def rivet(self, x, t, z, r, mat):
        self.pending_rivets.append(self.S.sphere(r, self.P(x, t, z), mat, self._name("rivet"), seg=10, rings=5))

    def flush_rivets(self, name="rivets"):
        if self.pending_rivets:
            self.S.join(self.pending_rivets, self._name(name))
            self.pending_rivets = []

    # ------------------------------------------------------------------ maillages libres
    def mesh(self, verts, faces, mat, name="maillage", bev=0.0, smooth_deg=None):
        me = bpy.data.meshes.new(self._name(name))
        me.from_pydata([tuple(v) for v in verts], [], faces)
        me.validate()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
        o = bpy.data.objects.new(me.name, me)
        self.S.piece_collection().objects.link(o)
        o.data.materials.append(mat)
        if smooth_deg:
            self.S.smooth(o, smooth_deg)
        if bev:
            self.S.bevel(o, bev)
        return o

    def prism_x(self, prof, x0, x1, mat, name="prisme_x", bev=0.0):
        """Extrusion le long de x d'un profil (ty, z) (polygone simple)."""
        n = len(prof)
        verts = [self.P(x0, t, z) for t, z in prof] + [self.P(x1, t, z) for t, z in prof]
        faces = [list(range(n)), list(range(n, 2 * n))]
        for i in range(n):
            j = (i + 1) % n
            faces.append([i, j, n + j, n + i])
        return self.mesh(verts, faces, mat, name, bev)

    def prism_t(self, prof, t0, t1, mat, name="prisme_t", bev=0.0):
        """Extrusion le long de ty d'un profil (x, z) (polygone simple)."""
        n = len(prof)
        verts = [self.P(x, t0, z) for x, z in prof] + [self.P(x, t1, z) for x, z in prof]
        faces = [list(range(n)), list(range(n, 2 * n))]
        for i in range(n):
            j = (i + 1) % n
            faces.append([i, j, n + j, n + i])
        return self.mesh(verts, faces, mat, name, bev)

    def frustum(self, bot, top, z0, z1, mat, name="tronc", bev=0.0):
        """Tronc de pyramide rectangulaire : bot = (x0, x1, t0, t1) à z0, top = (x0, x1, t0, t1) à z1."""
        def ring(r, z):
            x0, x1, t0, t1 = r
            return [self.P(x0, t1, z), self.P(x1, t1, z), self.P(x1, t0, z), self.P(x0, t0, z)]
        verts = ring(bot, z0) + ring(top, z1)
        faces = [[0, 1, 2, 3], [4, 5, 6, 7]] + [[i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i] for i in range(4)]
        return self.mesh(verts, faces, mat, name, bev)

    def slab(self, quad, thick, mat, name="plaque", bev=0.0):
        """Plaque d'épaisseur `thick` (vers le nord) à partir d'un quadrilatère (4 points jeu (x, ty, z))."""
        P = [Vector(self.P(*p)) for p in quad]
        nrm = (P[1] - P[0]).cross(P[3] - P[0]).normalized()
        if nrm.y < 0:          # épaisseur vers le nord (+Y Blender)
            nrm = -nrm
        Q = [p + nrm * thick for p in P]
        verts = P + Q
        faces = [[0, 1, 2, 3], [4, 5, 6, 7]] + [[i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i] for i in range(4)]
        return self.mesh(verts, faces, mat, name, bev)

    def tube(self, pts, r, mat, name="tube", sides=6, smooth=True):
        """Tube de rayon r le long d'un chemin (points jeu (x, ty, z)), repère transporté (pas de torsion)."""
        Pp = [Vector(self.P(*p)) for p in pts]
        n = len(Pp)
        tang = []
        for i in range(n):
            a, b = Pp[max(i - 1, 0)], Pp[min(i + 1, n - 1)]
            tang.append((b - a).normalized())
        ref = Vector((0, 0, 1)) if abs(tang[0].z) < 0.9 else Vector((1, 0, 0))
        u = tang[0].cross(ref).normalized()
        verts = []
        for i in range(n):
            t = tang[i]
            u = (u - t * u.dot(t))
            if u.length < 1e-6:
                u = t.orthogonal()
            u.normalize()
            w = t.cross(u).normalized()
            for k in range(sides):
                a = 2 * math.pi * k / sides
                verts.append(Pp[i] + (u * math.cos(a) + w * math.sin(a)) * r)
        faces = []
        for i in range(n - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                faces.append([i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k])
        faces.append(list(range(sides))[::-1])
        faces.append([(n - 1) * sides + k for k in range(sides)])
        return self.mesh(verts, faces, mat, name, smooth_deg=70 if smooth else None)

    def gem(self, x, t, z, r, h, mat, name="gemme", sides=6, tilt=(0.0, 0.0), tip=0.35):
        """Cristal : prisme à `sides` pans de rayon r et de hauteur h (base à z), pointe pyramidale de
        hauteur tip·h ; incliné de tilt = (vers l'est, vers le nord) en radians autour de sa base."""
        hb = h * (1 - tip)
        verts = []
        for z_ in (0.0, hb):
            for k in range(sides):
                a = 2 * math.pi * k / sides + math.pi / sides
                verts.append(Vector((r * math.cos(a), r * math.sin(a), z_)))
        verts.append(Vector((0, 0, h)))
        faces = [list(range(sides))[::-1]]
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append([k, k2, sides + k2, sides + k])
            faces.append([sides + k, sides + k2, 2 * sides])
        o = self.mesh([tuple(v) for v in verts], faces, mat, name)
        o.location = self.P(x, t, z)
        o.rotation_euler = (-tilt[1], tilt[0], 0.0)
        return o

    def halo(self, x, t, z, hexs, power, radius=0.04):
        return self.S.halo_light(self.P(x, t, z), lin(hexs), power, radius=radius, name=self._name("halo"))

    # ------------------------------------------------------------------ matériaux
    def _cache(self, name, fn):
        if name not in self.mcache:
            self.mcache[name] = fn()
        return self.mcache[name]

    def metal(self, name, hexs, mul=1.0, rough=0.45, metallic=0.8, grain=0.18, gscale=60.0, rust=None, rust_amount=0.0,
              rust_scale=6.0, dirt=0.4, seed=0.0):
        mul = mul * self.gain
        metallic = min(metallic, self.metal_cap)
        return self._cache(name, lambda: self.S.mat_metal(
            name, lin(hexs, mul, ALB_MAX), rough=rough, metallic=metallic, grain=grain, grain_scale=gscale,
            rust=lin(rust) if rust else None, rust_amount=rust_amount, rust_scale=rust_scale, dirt=dirt, seed=seed))

    def stone(self, name, hexs, mul=1.0, rough=0.85, grain=0.28, gscale=30.0, dirt=0.5, seed=0.0, stain=None, stain_amount=0.0):
        return self.metal(name, hexs, mul, rough=rough, metallic=0.0, grain=grain, gscale=gscale, rust=stain,
                          rust_amount=stain_amount, rust_scale=4.0, dirt=dirt, seed=seed)

    def flat(self, name, hexs, mul=1.0, rough=0.5, metallic=0.0):
        mul = mul * self.gain
        return self._cache(name, lambda: self.S.mat_flat(name, lin(hexs, mul, ALB_MAX), rough=rough, metallic=metallic))

    def emit(self, name, hexs, strength=2.0, base=None):
        # Émission bornée (reprise V3, 21/10) : au-delà d'environ 1,3, la couleur sature à l'écran et vire au
        # jaune-blanc (aperçus : orange #FF8C1A rendu jaune, cyan rendu blanc) ; la teinte d'époque se perd.
        strength = min(strength, EMIT_MAX)
        b = lin(base) if base else (0.05, 0.03, 0.02)
        return self._cache(name, lambda: self.S.mat_emissive(name, lin(hexs), strength=strength, base=b))

    def _new(self, name):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        return m, nt.nodes, nt.links, nt.nodes["Principled BSDF"]

    def _dirt(self, N, L, col_socket, amount, dist=0.25):
        ao = N.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = dist
        ao.samples = 8
        mr = N.new("ShaderNodeMapRange")
        mr.inputs["To Min"].default_value = 1.0 - amount
        mr.inputs["To Max"].default_value = 1.0
        L.new(ao.outputs["AO"], mr.inputs["Value"])
        mul = N.new("ShaderNodeVectorMath")
        mul.operation = "SCALE"
        L.new(col_socket, mul.inputs[0])
        L.new(mr.outputs["Result"], mul.inputs["Scale"])
        return mul.outputs["Vector"]

    def _xz_coords(self, N, L):
        """Coordonnées objet (x, z, y) : motifs dessinés sur les faces verticales orientées au sud."""
        tc = N.new("ShaderNodeTexCoord")
        sep = N.new("ShaderNodeSeparateXYZ")
        comb = N.new("ShaderNodeCombineXYZ")
        L.new(tc.outputs["Object"], sep.inputs[0])
        L.new(sep.outputs["X"], comb.inputs["X"])
        L.new(sep.outputs["Z"], comb.inputs["Y"])
        L.new(sep.outputs["Y"], comb.inputs["Z"])
        return comb.outputs[0], sep

    def brick(self, name, c1, c2, mortar, mul=1.0, width=0.25, row=0.105, mortar_size=0.012):
        mul = mul * self.gain

        def make():
            m, N, L, p = self._new(name)
            p.inputs["Roughness"].default_value = 0.85
            p.inputs["Metallic"].default_value = 0.0
            vec, _ = self._xz_coords(N, L)
            br = N.new("ShaderNodeTexBrick")
            br.inputs["Scale"].default_value = 1.0
            br.inputs["Color1"].default_value = lin(c1, mul, ALB_MAX) + (1,)
            br.inputs["Color2"].default_value = lin(c2, mul, ALB_MAX) + (1,)
            br.inputs["Mortar"].default_value = lin(mortar, mul, ALB_MAX) + (1,)
            br.inputs["Mortar Size"].default_value = mortar_size
            br.inputs["Brick Width"].default_value = width
            br.inputs["Row Height"].default_value = row
            br.inputs["Bias"].default_value = 0.0
            L.new(vec, br.inputs["Vector"])
            noise = N.new("ShaderNodeTexNoise")
            noise.inputs["Scale"].default_value = 40.0
            L.new(vec, noise.inputs["Vector"])
            mr = N.new("ShaderNodeMapRange")
            mr.inputs["To Min"].default_value = 0.8
            mr.inputs["To Max"].default_value = 1.2
            L.new(noise.outputs["Fac"], mr.inputs["Value"])
            sc = N.new("ShaderNodeVectorMath")
            sc.operation = "SCALE"
            L.new(br.outputs["Color"], sc.inputs[0])
            L.new(mr.outputs["Result"], sc.inputs["Scale"])
            L.new(self._dirt(N, L, sc.outputs["Vector"], 0.5), p.inputs["Base Color"])
            m["fo_kind"] = "surface"
            return m
        return self._cache(name, make)

    def stripes(self, name, ca, cb, mul=1.0, period=0.2, rough=0.6, metallic=0.2):
        """Bandes diagonales (avertissement) ; la période divise la tuile (raccord)."""
        mul = mul * self.gain

        def make():
            m, N, L, p = self._new(name)
            p.inputs["Roughness"].default_value = rough
            p.inputs["Metallic"].default_value = metallic
            vec, sep = self._xz_coords(N, L)
            add = N.new("ShaderNodeMath")
            add.operation = "ADD"
            L.new(sep.outputs["X"], add.inputs[0])
            L.new(sep.outputs["Z"], add.inputs[1])
            mul_ = N.new("ShaderNodeMath")
            mul_.operation = "MULTIPLY"
            mul_.inputs[1].default_value = 1.0 / period
            L.new(add.outputs[0], mul_.inputs[0])
            fr = N.new("ShaderNodeMath")
            fr.operation = "FRACT"
            L.new(mul_.outputs[0], fr.inputs[0])
            gt = N.new("ShaderNodeMath")
            gt.operation = "GREATER_THAN"
            gt.inputs[1].default_value = 0.5
            L.new(fr.outputs[0], gt.inputs[0])
            mix = N.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.inputs[6].default_value = lin(ca, mul, ALB_MAX) + (1,)
            mix.inputs[7].default_value = lin(cb, mul, ALB_MAX) + (1,)
            L.new(gt.outputs[0], mix.inputs["Factor"])
            noise = N.new("ShaderNodeTexNoise")
            noise.inputs["Scale"].default_value = 30.0
            L.new(vec, noise.inputs["Vector"])
            mr = N.new("ShaderNodeMapRange")
            mr.inputs["To Min"].default_value = 0.75
            mr.inputs["To Max"].default_value = 1.15
            L.new(noise.outputs["Fac"], mr.inputs["Value"])
            sc = N.new("ShaderNodeVectorMath")
            sc.operation = "SCALE"
            L.new(mix.outputs[2], sc.inputs[0])
            L.new(mr.outputs["Result"], sc.inputs["Scale"])
            L.new(self._dirt(N, L, sc.outputs["Vector"], 0.45), p.inputs["Base Color"])
            m["fo_kind"] = "surface"
            return m
        return self._cache(name, make)

    def foil(self, name, hexs, mul=1.0, rough=0.32, bump=0.55):
        """Feuille d'or froissée (jamais lisse) : métal, bosselage de Voronoi."""
        mul = mul * self.gain

        def make():
            m, N, L, p = self._new(name)
            p.inputs["Base Color"].default_value = lin(hexs, mul, ALB_MAX) + (1,)
            p.inputs["Metallic"].default_value = 0.8
            p.inputs["Roughness"].default_value = rough
            tc = N.new("ShaderNodeTexCoord")
            vo = N.new("ShaderNodeTexVoronoi")
            vo.inputs["Scale"].default_value = 22.0
            L.new(tc.outputs["Object"], vo.inputs["Vector"])
            bp = N.new("ShaderNodeBump")
            bp.inputs["Strength"].default_value = bump
            bp.inputs["Distance"].default_value = 0.02
            L.new(vo.outputs["Distance"], bp.inputs["Height"])
            L.new(bp.outputs["Normal"], p.inputs["Normal"])
            m["fo_kind"] = "surface"
            return m
        return self._cache(name, make)

    def frost(self, name, hexs, frost_hex, mul=1.0, amount=0.35, rough=0.4, metallic=0.3):
        """Métal sombre givré par plaques (bruit) : givre clair et mat dans le bas des pièces."""
        mul = mul * self.gain

        def make():
            m, N, L, p = self._new(name)
            p.inputs["Metallic"].default_value = metallic
            tc = N.new("ShaderNodeTexCoord")
            noise = N.new("ShaderNodeTexNoise")
            noise.inputs["Scale"].default_value = 26.0   # givre fin (reprise V3 : taches de 0,1 tuile illisibles)
            noise.inputs["Detail"].default_value = 8.0
            L.new(tc.outputs["Object"], noise.inputs["Vector"])
            mr = N.new("ShaderNodeMapRange")
            mr.inputs["From Min"].default_value = 0.62 - 0.2 * amount
            mr.inputs["From Max"].default_value = 0.68 - 0.2 * amount
            L.new(noise.outputs["Fac"], mr.inputs["Value"])
            mix = N.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.inputs[6].default_value = lin(hexs, mul, ALB_MAX) + (1,)
            mix.inputs[7].default_value = lin(frost_hex, mul, ALB_MAX) + (1,)
            L.new(mr.outputs["Result"], mix.inputs["Factor"])
            rr = N.new("ShaderNodeMapRange")
            rr.inputs["To Min"].default_value = rough
            rr.inputs["To Max"].default_value = 0.85
            L.new(mr.outputs["Result"], rr.inputs["Value"])
            L.new(rr.outputs["Result"], p.inputs["Roughness"])
            L.new(self._dirt(N, L, mix.outputs[2], 0.35), p.inputs["Base Color"])
            m["fo_kind"] = "surface"
            return m
        return self._cache(name, make)

    def field(self, name, hexs, strength=2.0, alpha=0.25):
        """Champ émissif semi-transparent (« hors masque » : alpha < 0,5 dans la couche principale)."""
        def make():
            m, N, L, p = self._new(name)
            p.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1)
            p.inputs["Emission Color"].default_value = lin(hexs) + (1,)
            p.inputs["Emission Strength"].default_value = strength
            tr = N.new("ShaderNodeBsdfTransparent")
            mix = N.new("ShaderNodeMixShader")
            mix.inputs["Fac"].default_value = 1.0 - alpha
            L.new(p.outputs["BSDF"], mix.inputs[1])
            L.new(tr.outputs["BSDF"], mix.inputs[2])
            out = N["Material Output"]
            L.new(mix.outputs["Shader"], out.inputs["Surface"])
            m.cycles.emission_sampling = "NONE"
            m["fo_kind"] = "emissive"
            m["fo_emit_color"] = list(lin(hexs))
            m["fo_emit_strength"] = strength
            return m
        return self._cache(name, make)
