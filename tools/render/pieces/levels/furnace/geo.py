"""Outils de modélisation propres à la famille four (lot V3). S'exécute DANS Blender (bpy).

Complète tools/render/blender/fo_scene.py SANS le modifier (fichier partagé du pipeline, lot V0b) :
révolution (lathe), lofts de polygones (troncs de pyramide, octogones), plaques épaisses (ailerons,
pétales), tubes le long d'un chemin, cylindres entre deux points, anneaux de rivets libres.

Toutes les positions sont données en tuiles de JEU (x est, y SUD) et z en unités Blender, puis converties
par G() : (x, y, z) -> (x, -y·√2, z). Les rayons et tailles sont en unités Blender (vraies proportions).
"""
import math

import bpy
import bmesh
from mathutils import Vector

K = math.sqrt(2.0)
S = None  # fo_scene, injecté par furnace_levels.build


def G(x, y, z=0.0):
    """Tuiles de jeu (y sud) -> Blender."""
    return (x, -y * K, z)


def _finish(o, mat, smooth_deg, bevel_w):
    S.piece_collection().objects.link(o)
    if mat is not None:
        o.data.materials.append(mat)
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    if smooth_deg:
        S.smooth(o, smooth_deg)
    if bevel_w:
        S.bevel(o, bevel_w)
    return o


def mesh(name, verts, faces, mat=None, smooth_deg=None, bevel_w=0.0):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    return _finish(o, mat, smooth_deg, bevel_w)


def loft(rings, name, mat=None, cap_bottom=True, cap_top=True, smooth_deg=None, bevel_w=0.0, closed=True):
    """rings : liste d'anneaux (même nombre de sommets), coordonnées Blender absolues."""
    verts, faces = [], []
    n = len(rings[0])
    for r in rings:
        verts.extend(r)
    for k in range(len(rings) - 1):
        a, b = k * n, (k + 1) * n
        for i in range(n if closed else n - 1):
            j = (i + 1) % n
            faces.append((a + i, a + j, b + j, b + i))
    if cap_bottom and closed:
        faces.append(tuple(reversed(range(0, n))))
    if cap_top and closed:
        last = (len(rings) - 1) * n
        faces.append(tuple(range(last, last + n)))
    return mesh(name, verts, faces, mat, smooth_deg, bevel_w)


def ring_pts(cx, cy, r, z, segs, phase=0.0, sx=1.0, sy=1.0):
    """Anneau horizontal en coordonnées Blender (cx, cy Blender)."""
    return [(cx + sx * r * math.cos(phase + 2 * math.pi * i / segs), cy + sy * r * math.sin(phase + 2 * math.pi * i / segs), z)
            for i in range(segs)]


def lathe(profile, at, name, mat=None, segs=48, phase=0.0, cap_bottom=True, cap_top=True, smooth_deg=40, bevel_w=0.0,
          sx=1.0, sy=1.0):
    """Révolution d'un profil [(rayon, z), ...] autour de l'axe vertical passant par at=(x, y) de JEU."""
    cx, cy, _ = G(at[0], at[1], 0)
    rings = [ring_pts(cx, cy, max(r, 1e-4), z, segs, phase, sx, sy) for r, z in profile]
    return loft(rings, name, mat, cap_bottom, cap_top, smooth_deg, bevel_w)


def prism(poly, z0, z1, name, mat=None, bevel_w=0.01, smooth_deg=None):
    """Prisme vertical : poly = [(x, y) de JEU], de z0 à z1."""
    b = [G(x, y, z0) for x, y in poly]
    t = [G(x, y, z1) for x, y in poly]
    return loft([b, t], name, mat, True, True, smooth_deg, bevel_w)


def frustum(poly0, z0, poly1, z1, name, mat=None, bevel_w=0.01, smooth_deg=None):
    """Tronc entre deux polygones de JEU (même nombre de sommets)."""
    return loft([[G(x, y, z0) for x, y in poly0], [G(x, y, z1) for x, y in poly1]], name, mat, True, True, smooth_deg,
                bevel_w)


def rect(cx, cy, w, d):
    """Rectangle de JEU centré (cx, cy), largeur w (x), profondeur d (y), sens trigonométrique."""
    return [(cx - w / 2, cy + d / 2), (cx + w / 2, cy + d / 2), (cx + w / 2, cy - d / 2), (cx - w / 2, cy - d / 2)]


def regular(cx, cy, r, n, phase=0.0, depth_scale=None):
    """Polygone régulier de JEU ; r en unités Blender (vraies proportions) : profondeur de jeu = r/√2."""
    ds = (1.0 / K) if depth_scale is None else depth_scale
    return [(cx + r * math.cos(phase + 2 * math.pi * i / n), cy - ds * r * math.sin(phase + 2 * math.pi * i / n))
            for i in range(n)]


def box(cx, cy, z0, w, d_units, h, name, mat=None, bevel_w=0.012, rot_z=0.0):
    """Boîte : centre de jeu (cx, cy), base à z0 ; w, d_units (profondeur en UNITÉS Blender), h en unités."""
    o = S.box((w, d_units, h), G(cx, cy, z0 + h / 2), mat, name, bevel_w=bevel_w)
    if rot_z:
        o.rotation_euler = (0, 0, rot_z)
    return o


def cyl(cx, cy, z0, r, h, name, mat=None, verts=48, bevel_w=0.008, r2=None, caps=True):
    return S.cylinder(r, h, G(cx, cy, z0 + h / 2), mat, name, verts=verts, bevel_w=bevel_w, radius2=r2, caps=caps)


def cyl_between(p0, p1, r, name, mat=None, verts=24, bevel_w=0.0, r2=None, caps=True):
    """Cylindre entre deux points BLENDER."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    L = d.length
    o = S.cylinder(r, L, tuple((a + b) / 2), mat, name, verts=verts, bevel_w=bevel_w, radius2=r2, caps=caps)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
    return o


def pipe(points, r, name, mat=None, segs=16, smooth=True, caps=True):
    """Tube le long d'un chemin (points BLENDER), converti en maillage (les passes ne traitent que les MESH)."""
    cu = bpy.data.curves.new(name + "_c", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = max(2, segs // 4)
    cu.use_fill_caps = caps
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
    o = bpy.data.objects.new(name, cu)
    S.piece_collection().objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.name = name
    if mat is not None:
        o.data.materials.clear()
        o.data.materials.append(mat)
    if smooth:
        S.smooth(o, 60)
    return o


def arc_points(center, radius, a0, a1, n, plane="xz", z_off=0.0):
    """Points BLENDER d'un arc de cercle (plan vertical xz ou yz passant par center)."""
    pts = []
    for i in range(n + 1):
        t = a0 + (a1 - a0) * i / n
        if plane == "xz":
            pts.append((center[0] + radius * math.cos(t), center[1], center[2] + radius * math.sin(t)))
        else:
            pts.append((center[0], center[1] + radius * math.cos(t), center[2] + radius * math.sin(t)))
    return pts


def slab(points_uv, origin, u_axis, v_axis, thickness, name, mat=None, bevel_w=0.006, smooth_deg=None):
    """Plaque épaisse : polygone (u, v) dans le plan (origin, u_axis, v_axis) BLENDER, épaisseur selon u×v."""
    o_, u, v = Vector(origin), Vector(u_axis).normalized(), Vector(v_axis).normalized()
    nrm = u.cross(v).normalized() * (thickness / 2)
    front = [tuple(o_ + u * a + v * b + nrm) for a, b in points_uv]
    back = [tuple(o_ + u * a + v * b - nrm) for a, b in points_uv]
    return loft([back, front], name, mat, True, True, smooth_deg, bevel_w)


def rivets(points, r, mat, name):
    objs = [S.sphere(r, p, mat, "%s_%02d" % (name, i), seg=10, rings=5) for i, p in enumerate(points)]
    return S.join(objs, name) if objs else None


def rivets_line(p0, p1, count, r, mat, name):
    a, b = Vector(p0), Vector(p1)
    pts = [tuple(a + (b - a) * (i / max(1, count - 1))) for i in range(count)]
    return rivets(pts, r, mat, name)


def rivet_ring_at(x, y, radius, z, count, r, mat, name, phase=0.0):
    cx, cy, _ = G(x, y, 0)
    return S.rivet_ring(radius, z, count, r, mat, center=(cx, cy), name=name, phase=phase)


def halo(x, y, z, color, power, name, radius=0.06):
    return S.halo_light(G(x, y, z), color, power, radius=radius, name=name)


def join(objs, name):
    objs = [o for o in objs if o is not None]
    return S.join(objs, name) if len(objs) > 1 else (objs[0] if objs else None)


def mat_brick(name, brick, mortar, brick_w=0.17, row_h=0.075, mortar_size=0.010, grain=0.25, dirt=0.6, rough=0.85,
              soot=None, seed=0.0):
    """Briques procédurales (nœud Brick de Blender) sur les faces avant (plan X-Z) et les dessus (plan X-Y),
    choisies par la normale ; grain fin, suie et crasse des creux comme S.mat_metal. Couleurs linéaires.
    Les faces est et ouest se voient par la tranche (caméra au sud) : elles reprennent le plan X-Z."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = 0.0
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Object"], sep.inputs["Vector"])

    def brick_tex(a, b):
        cmb = N.new("ShaderNodeCombineXYZ")
        L.new(sep.outputs[a], cmb.inputs["X"])
        L.new(sep.outputs[b], cmb.inputs["Y"])
        t = N.new("ShaderNodeTexBrick")
        t.offset = 0.5
        t.inputs["Scale"].default_value = 1.0
        t.inputs["Brick Width"].default_value = brick_w
        t.inputs["Row Height"].default_value = row_h
        t.inputs["Mortar Size"].default_value = mortar_size
        t.inputs["Mortar Smooth"].default_value = 0.2
        t.inputs["Bias"].default_value = 0.0
        t.inputs["Color1"].default_value = (brick[0], brick[1], brick[2], 1)
        t.inputs["Color2"].default_value = (brick[0] * 0.72, brick[1] * 0.76, brick[2] * 0.80, 1)
        t.inputs["Mortar"].default_value = (mortar[0], mortar[1], mortar[2], 1)
        L.new(cmb.outputs["Vector"], t.inputs["Vector"])
        return t.outputs["Color"]

    c_front = brick_tex("X", "Z")
    c_top = brick_tex("X", "Y")
    geom = N.new("ShaderNodeNewGeometry")
    sn = N.new("ShaderNodeSeparateXYZ")
    L.new(geom.outputs["Normal"], sn.inputs["Vector"])
    ab = N.new("ShaderNodeMath")
    ab.operation = "ABSOLUTE"
    L.new(sn.outputs["Z"], ab.inputs[0])
    gt = N.new("ShaderNodeMath")
    gt.operation = "GREATER_THAN"
    gt.inputs[1].default_value = 0.6
    L.new(ab.outputs[0], gt.inputs[0])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L.new(gt.outputs[0], mix.inputs["Factor"])
    L.new(c_front, mix.inputs[6])
    L.new(c_top, mix.inputs[7])
    col = mix.outputs[2]
    n1 = N.new("ShaderNodeTexNoise")
    n1.inputs["Scale"].default_value = 40.0
    n1.inputs["Detail"].default_value = 6.0
    if "W" in n1.inputs:
        n1.noise_dimensions = "4D"
        n1.inputs["W"].default_value = seed
    L.new(tc.outputs["Object"], n1.inputs["Vector"])
    g = N.new("ShaderNodeMapRange")
    g.inputs["From Min"].default_value = 0.3
    g.inputs["From Max"].default_value = 0.7
    g.inputs["To Min"].default_value = 1.0 - grain
    g.inputs["To Max"].default_value = 1.0 + grain
    L.new(n1.outputs["Fac"], g.inputs["Value"])
    mul = N.new("ShaderNodeVectorMath")
    mul.operation = "SCALE"
    L.new(col, mul.inputs[0])
    L.new(g.outputs["Result"], mul.inputs["Scale"])
    col = mul.outputs["Vector"]
    if soot:
        n2 = N.new("ShaderNodeTexNoise")
        n2.inputs["Scale"].default_value = 4.0
        n2.inputs["Detail"].default_value = 4.0
        L.new(tc.outputs["Object"], n2.inputs["Vector"])
        mr = N.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 0.45
        mr.inputs["From Max"].default_value = 0.65
        mr.inputs["To Min"].default_value = 1.0
        mr.inputs["To Max"].default_value = 1.0 - soot
        L.new(n2.outputs["Fac"], mr.inputs["Value"])
        m2 = N.new("ShaderNodeVectorMath")
        m2.operation = "SCALE"
        L.new(col, m2.inputs[0])
        L.new(mr.outputs["Result"], m2.inputs["Scale"])
        col = m2.outputs["Vector"]
    if dirt > 0:
        ao = N.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.25
        ao.samples = 8
        dm = N.new("ShaderNodeMapRange")
        dm.inputs["To Min"].default_value = 1.0 - dirt
        dm.inputs["To Max"].default_value = 1.0
        L.new(ao.outputs["AO"], dm.inputs["Value"])
        dmul = N.new("ShaderNodeVectorMath")
        dmul.operation = "SCALE"
        L.new(col, dmul.inputs[0])
        L.new(dm.outputs["Result"], dmul.inputs["Scale"])
        col = dmul.outputs["Vector"]
    L.new(col, p.inputs["Base Color"])
    m["fo_kind"] = "surface"
    return m
