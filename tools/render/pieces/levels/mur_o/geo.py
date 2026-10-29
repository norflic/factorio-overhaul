"""Mur MUR-OPUS (29/10) : outils de modélisation et matières, DANS Blender.

Le constructeur G garde une pile de repères (matrices) : chaque primitive est créée à l'origine, puis sa géométrie est
transformée par le repère courant (miroir permis : les normales sont retournées). Les objets restent à l'origine du
monde : les coordonnées « Object » des matières sont donc les coordonnées du monde de la case (motifs périodiques par
case, raccords sans couture).

Unités : 1 = largeur d'une tuile ; +X est, +Y nord, +Z haut ; une tuile vers le sud = 1,414 en Y (CALIBRATION §2).
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

SQ2 = math.sqrt(2.0)


class G:
    def __init__(self, S, C, seed=1):
        self.S, self.C = S, C
        self.stack = [Matrix.Identity(4)]
        self.n = 0
        self.seed = seed
        self._r = (seed * 2654435761) % 2 ** 32 or 1

    # --- aléa déterministe (xorshift) ---
    def rnd(self, a=0.0, b=1.0):
        x = self._r
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        self._r = x & 0xFFFFFFFF
        return a + (b - a) * (self._r / 4294967295.0)

    # --- repères ---
    def push(self, M):
        self.stack.append(self.stack[-1] @ M)

    def pop(self):
        self.stack.pop()

    @staticmethod
    def T(x, y, z):
        return Matrix.Translation((x, y, z))

    @staticmethod
    def Rz(a):
        return Matrix.Rotation(a, 4, "Z")

    @staticmethod
    def Sc(sx, sy, sz):
        return Matrix.Diagonal((sx, sy, sz, 1.0))

    # --- finition commune ---
    def _fin(self, o, mat, M=None, bev=0.0, seg=2, weight=False, smooth=None, hidden=False):
        Mw = self.stack[-1] @ (M if M is not None else Matrix.Identity(4))
        o.data.transform(Mw)
        if Mw.to_3x3().determinant() < 0:
            o.data.flip_normals()
        o.matrix_world = Matrix.Identity(4)
        self.n += 1
        self.S._adopt(o, mat, "mur_%04d" % self.n)
        if smooth is not None:
            self.S.smooth(o, smooth)
        if bev > 0:
            mod = o.modifiers.new("bevel", "BEVEL")
            mod.width = bev
            mod.segments = seg
            if weight:
                mod.limit_method = "WEIGHT"
            else:
                mod.limit_method = "ANGLE"
                mod.angle_limit = math.radians(35)
            mod.harden_normals = False
        if hidden:
            self.S.mark_hidden(o)
        return o

    def _mesh_obj(self, bm, name="m"):
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        return o

    # --- primitives ---
    def box(self, x0, x1, y0, y1, z0, z1, mat, bev=0.012, seg=2):
        """Boîte alignée (coordonnées du repère courant)."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x = x0 if v.co.x < 0 else x1
            v.co.y = y0 if v.co.y < 0 else y1
            v.co.z = z0 if v.co.z < 0 else z1
        return self._fin(self._mesh_obj(bm), mat, bev=bev, seg=seg)

    def prism(self, prof, x0, x1, mat, bev=0.012, seg=2, ends=False, smooth=None):
        """Prisme : profil fermé [(y, z), …] (sens trigonométrique vu depuis +X) extrudé de x0 à x1. ends=False : les
        arêtes des deux bouts ne sont PAS chanfreinées (raccord bord à bord avec la case voisine)."""
        bm = bmesh.new()
        bw = bm.edges.layers.float.get("bevel_weight_edge") or bm.edges.layers.float.new("bevel_weight_edge")
        a = [bm.verts.new((x0, y, z)) for (y, z) in prof]
        b = [bm.verts.new((x1, y, z)) for (y, z) in prof]
        n = len(prof)
        bm.faces.new(list(reversed(a)))
        bm.faces.new(b)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
        bm.edges.ensure_lookup_table()
        bm.normal_update()
        for e in bm.edges:
            v0, v1 = e.verts
            longi = abs(v0.co.x - v1.co.x) > 1e-6
            if longi:
                # arête longitudinale : chanfrein seulement si l'angle du profil est vif
                f = e.link_faces
                if len(f) == 2 and f[0].normal.angle(f[1].normal) > math.radians(30):
                    e[bw] = 1.0
            elif ends:
                e[bw] = 1.0
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self._fin(self._mesh_obj(bm), mat, bev=bev, seg=seg, weight=True, smooth=smooth)

    def loft_z(self, poly, z0, z1, mat, poly1=None, bev=0.01, seg=2):
        """Prisme vertical : polygone [(x, y), …] (sens trigonométrique) en z0, poly1 (même nombre de points) en z1."""
        poly1 = poly1 or poly
        bm = bmesh.new()
        a = [bm.verts.new((x, y, z0)) for (x, y) in poly]
        b = [bm.verts.new((x, y, z1)) for (x, y) in poly1]
        n = len(poly)
        bm.faces.new(list(reversed(a)))
        bm.faces.new(b)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self._fin(self._mesh_obj(bm), mat, bev=bev, seg=seg)

    def hull(self, pts, mat, bev=0.008, seg=1):
        """Enveloppe convexe d'un nuage de points (éclats, blocs taillés)."""
        bm = bmesh.new()
        vs = [bm.verts.new(p) for p in pts]
        bmesh.ops.convex_hull(bm, input=vs)
        for v in [v for v in bm.verts if not v.link_faces]:
            bm.verts.remove(v)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self._fin(self._mesh_obj(bm), mat, bev=bev, seg=seg)

    def cyl(self, c, axis, r, length, mat, n=24, r2=None, bev=0.006, caps=True):
        """Cylindre (ou tronc de cône) centré sur c, d'axe « x », « y » ou « z »."""
        bm = bmesh.new()
        if r2 is None:
            r2 = r
        bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=n, radius1=r, radius2=r2, depth=length)
        R = {"z": Matrix.Identity(4), "x": Matrix.Rotation(math.pi / 2, 4, "Y"),
             "y": Matrix.Rotation(-math.pi / 2, 4, "X")}[axis]
        bmesh.ops.transform(bm, matrix=self.T(*c) @ R, verts=bm.verts)
        o = self._mesh_obj(bm)
        return self._fin(o, mat, bev=bev, seg=2, smooth=50)

    def sphere(self, c, r, mat, seg=24, rings=12, sz=1.0):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
        bmesh.ops.transform(bm, matrix=self.T(*c) @ self.Sc(1, 1, sz), verts=bm.verts)
        return self._fin(self._mesh_obj(bm), mat, smooth=80)

    def rivets(self, pts, r, mat, h=None):
        """Têtes de rivet (demi-sphères aplaties) aux points donnés, normale +Y vers le SUD par défaut : ici on pose des
        petites sphères aplaties orientées par l'axe donné dans chaque point (x, y, z, axe)."""
        for (x, y, z, ax) in pts:
            sz = 0.55
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=r)
            S = {"z": self.Sc(1, 1, sz), "y": self.Sc(1, sz, 1), "x": self.Sc(sz, 1, 1)}[ax]
            bmesh.ops.transform(bm, matrix=self.T(x, y, z) @ S, verts=bm.verts)
            self._fin(self._mesh_obj(bm), mat, smooth=80)


# ------------------------------------------------------------------------------------------------------------------
# Matières procédurales (une seule fonction, réglée par âge ; c'est la GÉOMÉTRIE qui porte le design)
# ------------------------------------------------------------------------------------------------------------------
def _nn(N, kind, **kw):
    n = N.new(kind)
    for k, v in kw.items():
        setattr(n, k, v)
    return n


def surface(name, col, col2=None, rough=0.75, metal=0.0, var=0.5, var_scale=6.0, grain=0.12, grain_scale=90.0,
            bump=0.25, bump_scale=70.0, edge=None, cavity=0.45, cavity_dist=0.10, streak=0.0, top=None,
            bottom=None, brick=None, rough2=None, spec=0.5, seed=0.0, stain=None, veins=None):
    """Surface « usée » :
    col, col2  : couleurs (linéaires) mêlées par un bruit lent (var : part de col2 au plus) ;
    grain      : ± grain fin ; bump : relief fin ;
    edge       : (couleur, part) arêtes vives éclaircies/usées (AO intérieure) ;
    cavity     : assombrissement des creux (AO extérieure, portée cavity_dist) ;
    streak     : coulures verticales sur les faces verticales (assombrissement) ;
    top        : (couleur, part, seuil) dépôt sur les faces tournées vers le haut (poussière, mousse) ;
    bottom     : (couleur, z1, part) salissure/humidité près du sol, jusqu'à z1 ;
    brick      : dict(w, h, mortar, col_m, offset, scale_xyz) motif de maçonnerie (coordonnées Object) ;
    """
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    p.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in p.inputs:
        p.inputs["Specular IOR Level"].default_value = spec
    tc = N.new("ShaderNodeTexCoord")
    geo = N.new("ShaderNodeNewGeometry")
    pos = tc.outputs["Object"]

    def noise(scale, detail=4.0, rough_=0.55, vec=None, distortion=0.0):
        n = N.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough_
        if "Distortion" in n.inputs:
            n.inputs["Distortion"].default_value = distortion
        L.new(vec if vec is not None else pos, n.inputs["Vector"])
        return n.outputs["Fac"]

    def rng(src, f0, f1, t0, t1, smooth=True):
        r = N.new("ShaderNodeMapRange")
        if smooth:
            r.interpolation_type = "SMOOTHSTEP"
        r.inputs["From Min"].default_value = f0
        r.inputs["From Max"].default_value = f1
        r.inputs["To Min"].default_value = t0
        r.inputs["To Max"].default_value = t1
        r.clamp = True
        L.new(src, r.inputs["Value"])
        return r.outputs["Result"]

    def mix(fac, a, b):
        x = N.new("ShaderNodeMix")
        x.data_type = "RGBA"
        if isinstance(fac, float):
            x.inputs["Factor"].default_value = fac
        else:
            L.new(fac, x.inputs["Factor"])
        for i, v in ((6, a), (7, b)):
            if isinstance(v, (tuple, list)):
                x.inputs[i].default_value = (v[0], v[1], v[2], 1.0)
            else:
                L.new(v, x.inputs[i])
        return x.outputs[2]

    def mulc(c, f):
        x = N.new("ShaderNodeVectorMath")
        x.operation = "SCALE"
        L.new(c, x.inputs[0])
        if isinstance(f, float):
            x.inputs["Scale"].default_value = f
        else:
            L.new(f, x.inputs["Scale"])
        return x.outputs["Vector"]

    def math_(op, a, b):
        x = N.new("ShaderNodeMath")
        x.operation = op
        for i, v in ((0, a), (1, b)):
            if isinstance(v, float):
                x.inputs[i].default_value = v
            else:
                L.new(v, x.inputs[i])
        return x.outputs[0]

    # décalage de graine : on translate les coordonnées
    if seed:
        vm = N.new("ShaderNodeVectorMath")
        vm.operation = "ADD"
        vm.inputs[1].default_value = (seed * 3.17, seed * 1.91, seed * 0.73)
        L.new(pos, vm.inputs[0])
        pos = vm.outputs["Vector"]

    # couleur de base : deux tons par un bruit lent
    c2 = col2 if col2 is not None else tuple(0.75 * c for c in col)
    v = rng(noise(var_scale, 5.0, 0.6, distortion=0.3), 0.35, 0.7, 0.0, var)
    color = mix(v, tuple(col), tuple(c2))
    height = None
    if brick:
        b = N.new("ShaderNodeTexBrick")
        b.offset = brick.get("offset", 0.5)
        b.squash = 1.0
        b.inputs["Scale"].default_value = 1.0
        b.inputs["Mortar Size"].default_value = brick.get("mortar", 0.012)
        b.inputs["Mortar Smooth"].default_value = 0.3
        b.inputs["Bias"].default_value = 0.0
        b.inputs["Brick Width"].default_value = brick["w"]
        b.inputs["Row Height"].default_value = brick["h"]
        # coordonnées : (x + y, z) : sur une face de normale ±Y les briques courent en X, de normale ±X en Y
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(pos, sep.inputs["Vector"])
        com = N.new("ShaderNodeCombineXYZ")
        L.new(math_("ADD", sep.outputs["X"], sep.outputs["Y"]), com.inputs["X"])
        L.new(sep.outputs["Z"], com.inputs["Y"])
        L.new(com.outputs["Vector"], b.inputs["Vector"])
        bc1 = brick.get("c1", col)
        bc2 = brick.get("c2", c2)
        b.inputs["Color1"].default_value = (bc1[0], bc1[1], bc1[2], 1)
        b.inputs["Color2"].default_value = (bc2[0], bc2[1], bc2[2], 1)
        cm = brick.get("col_m", (0.2, 0.19, 0.17))
        b.inputs["Mortar"].default_value = (cm[0], cm[1], cm[2], 1)
        # teinte par brique (Color de la texture) modulée par le bruit lent
        color = mix(0.5, b.outputs["Color"], color) if brick.get("blend", True) else b.outputs["Color"]
        height = b.outputs["Fac"]
    # grain fin
    g = rng(noise(grain_scale, 6.0, 0.65), 0.3, 0.7, 1.0 - grain, 1.0 + grain, smooth=False)
    color = mulc(color, g)
    # faces verticales / dessus
    sepn = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Normal"], sepn.inputs["Vector"])
    nz = sepn.outputs["Z"]
    vert = rng(nz, 0.35, 0.8, 1.0, 0.0)
    if streak > 0:
        mp = N.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (28.0, 28.0, 1.6)
        L.new(pos, mp.inputs["Vector"])
        s = rng(noise(1.0, 3.0, 0.5, vec=mp.outputs["Vector"]), 0.45, 0.75, 0.0, streak)
        s = math_("MULTIPLY", s, vert)
        color = mulc(color, math_("SUBTRACT", 1.0, s))
    if top:
        tcol, tpart, tthr = top[0], top[1], top[2] if len(top) > 2 else 0.55
        up = rng(nz, tthr, tthr + 0.25, 0.0, 1.0)
        tn = rng(noise(14.0, 4.0, 0.6), 0.35, 0.65, 0.4, 1.0)
        f = math_("MULTIPLY", math_("MULTIPLY", up, tn), tpart)
        color = mix(f, color, tuple(tcol))
    if bottom:
        bcol, z1, bpart = bottom
        sep2 = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Position"], sep2.inputs["Vector"])
        bz = rng(sep2.outputs["Z"], 0.0, z1, bpart, 0.0)
        bnz = rng(noise(10.0, 3.0, 0.6), 0.3, 0.7, 0.5, 1.0)
        color = mix(math_("MULTIPLY", bz, bnz), color, tuple(bcol))
    if stain:
        scol, spart, sscale = stain
        sn = rng(noise(sscale, 6.0, 0.7, distortion=0.6), 0.5, 0.72, 0.0, spart)
        color = mix(sn, color, tuple(scol))
    if edge:
        # arêtes : écart entre la normale arrondie (nœud Bevel, rayon edge[2]) et la normale vraie
        ecol, epart = edge[0], edge[1]
        bv = N.new("ShaderNodeBevel")
        bv.samples = 8
        bv.inputs["Radius"].default_value = edge[2] if len(edge) > 2 else 0.03
        dp = N.new("ShaderNodeVectorMath")
        dp.operation = "DOT_PRODUCT"
        L.new(bv.outputs["Normal"], dp.inputs[0])
        L.new(geo.outputs["Normal"], dp.inputs[1])
        e = rng(dp.outputs["Value"], 0.90, 0.995, 1.0, 0.0)
        en = rng(noise(35.0, 4.0, 0.65), 0.3, 0.6, 0.1, 1.0)
        f = math_("MULTIPLY", math_("MULTIPLY", e, en), epart)
        color = mix(f, color, tuple(ecol))
    metal_out = None
    if veins:
        # veines (kintsugi) : distance au bord des cellules de Voronoi déformées par un bruit, mêlées d'or métallique
        vcol, vw, vscale = veins[0], veins[1], veins[2]
        dist = N.new("ShaderNodeVectorMath")
        dist.operation = "ADD"
        nv = N.new("ShaderNodeTexNoise")
        nv.inputs["Scale"].default_value = vscale * 0.8
        nv.inputs["Detail"].default_value = 3.0
        L.new(pos, nv.inputs["Vector"])
        sc = N.new("ShaderNodeVectorMath")
        sc.operation = "SCALE"
        sc.inputs["Scale"].default_value = 0.18
        L.new(nv.outputs["Color"], sc.inputs[0])
        L.new(pos, dist.inputs[0])
        L.new(sc.outputs["Vector"], dist.inputs[1])
        vo = N.new("ShaderNodeTexVoronoi")
        vo.feature = "DISTANCE_TO_EDGE"
        vo.inputs["Scale"].default_value = vscale
        L.new(dist.outputs["Vector"], vo.inputs["Vector"])
        vm = rng(vo.outputs["Distance"], 0.0, vw, 1.0, 0.0)
        color = mix(vm, color, tuple(vcol))
        metal_out = vm
    if cavity > 0:
        ao2 = N.new("ShaderNodeAmbientOcclusion")
        ao2.samples = 6
        ao2.inputs["Distance"].default_value = cavity_dist
        cf = rng(ao2.outputs["AO"], 0.2, 1.0, 1.0 - cavity, 1.0, smooth=False)
        color = mulc(color, cf)
    L.new(color, p.inputs["Base Color"])
    # rugosité
    r = rng(noise(20.0, 3.0, 0.5), 0.3, 0.7, rough, rough2 if rough2 is not None else min(1.0, rough + 0.12))
    L.new(r, p.inputs["Roughness"])
    if metal_out is not None:
        mm = rng(metal_out, 0.0, 1.0, metal, 1.0, smooth=False)
        L.new(mm, p.inputs["Metallic"])
    # relief
    if bump > 0:
        bn = N.new("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        bn.inputs["Distance"].default_value = 0.004
        hsrc = noise(bump_scale, 6.0, 0.6)
        if height is not None:
            hsrc = math_("ADD", math_("MULTIPLY", height, -0.8), math_("MULTIPLY", hsrc, 0.4))
        L.new(hsrc, bn.inputs["Height"])
        L.new(bn.outputs["Normal"], p.inputs["Normal"])
    m["fo_kind"] = "surface"
    return m


def emissive(S, name, color, strength=1.0, base=(0.04, 0.03, 0.02), crust=None):
    """Lueur : la passe glow est écrêtée à 1 (PNG) : couleur × force ≤ 1 sinon la teinte part au jaune ou au blanc."""
    m = S.mat_emissive(name, color, strength=strength, base=base, main_scale=0.0, crust=crust)
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
    return m
