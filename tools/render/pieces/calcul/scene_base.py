"""Socle des scènes Blender des icônes du calcul : matières riches, primitives, pivots, monde, caméra, rendu.
S'exécute DANS Blender (importé par scene_icones.py).

Règle d'échelle : un objet fait environ 5,5 unités de large, donc 1 unité = 11 px à 64 px et 5,5 px à 32 px. Tout ce qui
doit se lire à 32 px mesure au moins 0,4 unité ; tout ce qui doit se lire à 64 px, au moins 0,2 unité.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, "..", "..", "blender"))
sys.path.insert(0, os.path.join(ICI, "..", ".."))
sys.path.insert(0, ICI)
import fo_scene as S  # noqa: E402
import couleurs_calcul as K  # noqa: E402

_M = {}


# ------------------------------------------------------------------------------------------------------------------
# Matières
# ------------------------------------------------------------------------------------------------------------------
def _scale(N, L, vec, fac):
    n = N.new("ShaderNodeVectorMath")
    n.operation = "SCALE"
    L.new(vec, n.inputs[0])
    L.new(fac, n.inputs["Scale"])
    return n.outputs["Vector"]


def _map(N, L, val, a, b, c, d, lisse=False):
    n = N.new("ShaderNodeMapRange")
    if lisse:
        n.interpolation_type = "SMOOTHSTEP"
    n.inputs["From Min"].default_value = a
    n.inputs["From Max"].default_value = b
    n.inputs["To Min"].default_value = c
    n.inputs["To Max"].default_value = d
    n.clamp = True
    L.new(val, n.inputs["Value"])
    return n.outputs["Result"]


def _bruit(N, L, tc, echelle, detail=4.0):
    n = N.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = echelle
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = 0.55
    L.new(tc.outputs["Object"], n.inputs["Vector"])
    return n.outputs["Fac"]


def mat_riche(nom, c):
    """Grain fin, taches larges, occlusion des creux, usure claire des arêtes, surface légèrement ondulée (c'est ce qui
    donne un reflet qui varie sur une face plane, là où une caméra orthographique rendrait un aplat)."""
    m = bpy.data.materials.new(nom)
    nt, N, L = S._nodes(m)
    p = N["Principled BSDF"]
    rough, g = c.get("rough", 0.4), c.get("grain", 0.08)
    p.inputs["Metallic"].default_value = c.get("met", 0.6)
    tc = N.new("ShaderNodeTexCoord")
    fin = _bruit(N, L, tc, c.get("gs", 45.0), 5.0)
    large = _bruit(N, L, tc, 1.7, 3.0)
    base = N.new("ShaderNodeRGB")
    base.outputs[0].default_value = tuple(c["rgb"]) + (1,)
    col = _scale(N, L, base.outputs[0], _map(N, L, fin, 0.3, 0.7, 1 - g, 1 + g))
    col = _scale(N, L, col, _map(N, L, large, 0.32, 0.68, 1 - 2.2 * g, 1 + 2.2 * g))
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.samples = 6
    ao.inputs["Distance"].default_value = c.get("creux_d", 0.45)
    col = _scale(N, L, col, _map(N, L, ao.outputs["AO"], 0.15, 1.0, 1 - c.get("creux", 0.6), 1.0))
    arete = c.get("arete", 0.5)
    if arete > 0:
        ai = N.new("ShaderNodeAmbientOcclusion")
        ai.samples = 6
        ai.inside = True
        ai.inputs["Distance"].default_value = 0.05
        bord = _map(N, L, ai.outputs["AO"], 0.55, 1.0, 1.0, 0.0)
        clair = N.new("ShaderNodeVectorMath")
        clair.operation = "MULTIPLY_ADD"
        L.new(col, clair.inputs[0])
        clair.inputs[1].default_value = (1 + 1.2 * arete,) * 3
        clair.inputs[2].default_value = (0.05 * arete,) * 3
        mix = N.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        L.new(bord, mix.inputs[0])
        L.new(col, mix.inputs[6])
        L.new(clair.outputs["Vector"], mix.inputs[7])
        col = mix.outputs[2]
    L.new(col, p.inputs["Base Color"])
    L.new(_map(N, L, fin, 0.3, 0.7, max(0.03, rough - 0.08), rough + 0.12), p.inputs["Roughness"])
    bosse = c.get("bosse", 0.08)
    if bosse > 0:
        b = N.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = bosse
        b.inputs["Distance"].default_value = 0.4
        hb = N.new("ShaderNodeMath")
        hb.operation = "MULTIPLY_ADD"
        L.new(large, hb.inputs[0])
        hb.inputs[1].default_value = 1.0
        L.new(fin, hb.inputs[2])
        L.new(hb.outputs[0], b.inputs["Height"])
        L.new(b.outputs["Normal"], p.inputs["Normal"])
    return m


def mat_lum(nom, coeur, bord, force, mode="face", z0=0.0, z1=1.0):
    """Surface lumineuse à dégradé obligatoire : mode 'face' (coeur vu de face, bord au pourtour) ou 'z' (bord en bas,
    coeur en haut, de z0 à z1 en coordonnées d'objet). N'éclaire pas la scène."""
    m = bpy.data.materials.new(nom)
    nt, N, L = S._nodes(m)
    p = N["Principled BSDF"]
    p.inputs["Base Color"].default_value = tuple(v * 0.25 for v in bord) + (1,)
    p.inputs["Roughness"].default_value = 0.18
    p.inputs["Emission Strength"].default_value = force
    if mode == "face":
        lw = N.new("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = 0.55
        fac = _map(N, L, lw.outputs["Facing"], 0.1, 0.85, 0.0, 1.0, lisse=True)
    else:
        tc = N.new("ShaderNodeTexCoord")
        sz = N.new("ShaderNodeSeparateXYZ")
        L.new(tc.outputs["Object"], sz.inputs[0])
        fac = _map(N, L, sz.outputs["Z"], z0, z1, 1.0, 0.0, lisse=True)
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L.new(fac, mix.inputs[0])
    mix.inputs[6].default_value = tuple(coeur) + (1,)
    mix.inputs[7].default_value = tuple(bord) + (1,)
    L.new(mix.outputs[2], p.inputs["Emission Color"])
    m.cycles.emission_sampling = "NONE"
    return m


def mat_goutte(nom, coeur, bord, rough=0.10, met=0.55):
    """Fluide vanilla : goutte brillante, couleur vive au centre, sombre et saturée au pourtour, reflet coloré."""
    m = bpy.data.materials.new(nom)
    nt, N, L = S._nodes(m)
    p = N["Principled BSDF"]
    p.inputs["Metallic"].default_value = met
    p.inputs["Roughness"].default_value = rough
    p.inputs["Coat Weight"].default_value = 0.6
    p.inputs["Coat Roughness"].default_value = 0.04
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.55
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    L.new(_map(N, L, lw.outputs["Facing"], 0.15, 0.9, 0.0, 1.0, lisse=True), mix.inputs[0])
    mix.inputs[6].default_value = tuple(coeur) + (1,)
    mix.inputs[7].default_value = tuple(bord) + (1,)
    L.new(mix.outputs[2], p.inputs["Base Color"])
    return m


def mat_voile(nom, rgb, alpha, force):
    """Faisceau ou lueur translucide (émission + transparence, plus dense sur le pourtour vu de biais)."""
    m = bpy.data.materials.new(nom)
    nt, N, L = S._nodes(m)
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    em = N.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = tuple(rgb) + (1,)
    em.inputs["Strength"].default_value = force
    tr = N.new("ShaderNodeBsdfTransparent")
    mx = N.new("ShaderNodeMixShader")
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.5
    L.new(_map(N, L, lw.outputs["Facing"], 0.0, 1.0, alpha, alpha * 0.45), mx.inputs[0])
    L.new(tr.outputs[0], mx.inputs[1])
    L.new(em.outputs[0], mx.inputs[2])
    L.new(mx.outputs[0], out.inputs["Surface"])
    m.cycles.emission_sampling = "NONE"
    return m


def mat(nom):
    if not isinstance(nom, str):      # déjà une matière
        return nom
    if nom in _M:
        return _M[nom]
    if nom in K.LUM:
        c, b, f = K.LUM[nom]
        m = mat_lum("m_" + nom, c, b, f)
    else:
        c = K.MAT[nom]
        if c.get("plat"):
            m = S.mat_flat("m_" + nom, c["rgb"], rough=c.get("rough", 0.6), metallic=c.get("met", 0.0))
        else:
            m = mat_riche("m_" + nom, c)
    _M[nom] = m
    return m


def mat_direct(nom, m):
    _M[nom] = m
    return m


def vider_matieres():
    _M.clear()


# ------------------------------------------------------------------------------------------------------------------
# Primitives
# ------------------------------------------------------------------------------------------------------------------
def B(sx, sy, sz, x, y, z, m, bev=0.025, rot=None):
    """Boîte de taille (sx, sy, sz) dont la FACE INFÉRIEURE est à z ; rot : (rx, ry, rz) en degrés autour de son centre."""
    o = S.box((sx, sy, sz), (x, y, z + sz / 2.0), mat(m), bevel_w=bev)
    if rot:
        o.rotation_euler = tuple(math.radians(a) for a in rot)
    return o


def CY(r, h, x, y, z, m, verts=40, bev=0.015, r2=None):
    """Cylindre vertical dont la base est à z."""
    return S.cylinder(r, h, (x, y, z + h / 2.0), mat(m), verts=verts, bevel_w=bev, radius2=r2)


def CYX(r, L_, x, y, z, m, verts=24, bev=0.012, axe="x"):
    """Cylindre couché centré sur (x, y, z), d'axe x ou y."""
    rot = (0, math.radians(90), 0) if axe == "x" else (math.radians(90), 0, 0)
    return S.cylinder(r, L_, (x, y, z), mat(m), verts=verts, bevel_w=bev, rot=rot)


def TOR(R, r, x, y, z, m, rot=(0, 0, 0), minor=16):
    return S.torus(R, r, (x, y, z), mat(m), rot=tuple(math.radians(a) for a in rot), major_seg=96, minor_seg=minor)


def SPH(r, x, y, z, m, seg=48, rings=24):
    return S.sphere(r, (x, y, z), mat(m), seg=seg, rings=rings)


def _maille(nom, vs, fs, m, x=0.0, y=0.0, z=0.0, lisse=True):
    me = bpy.data.meshes.new(nom)
    me.from_pydata(vs, [], fs)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = lisse
    o = bpy.data.objects.new(nom, me)
    S.piece_collection().objects.link(o)
    o.location = (x, y, z)
    me.materials.append(m if not isinstance(m, str) else mat(m))
    return o


def lathe(profil, x, y, z, m, verts=72, lisse=True, bev=0.0, phase=0.0):
    """Solide de révolution d'axe Z : profil [(rayon, hauteur), ...] ; verts=6 : prisme hexagonal."""
    vs, fs = [], []
    n = len(profil)
    for r, zz in profil:
        for k in range(verts):
            a = phase + 2 * math.pi * k / verts
            vs.append((r * math.cos(a), r * math.sin(a), zz))
    for i in range(n - 1):
        for k in range(verts):
            k2 = (k + 1) % verts
            fs.append((i * verts + k, i * verts + k2, (i + 1) * verts + k2, (i + 1) * verts + k))
    if profil[0][0] > 0:
        fs.append(tuple(range(verts)))
    if profil[-1][0] > 0:
        fs.append(tuple((n - 1) * verts + k for k in range(verts)))
    o = _maille("lathe", vs, fs, m, x, y, z, lisse=lisse)
    if bev:
        S.bevel(o, bev)
    return o


def profil_goutte(H, R, m=1.8, pas=56):
    """Goutte vanilla : pointe fine en haut, panse ronde en bas (bas à 0, sommet à H)."""
    pts = []
    rmax = 0.0
    for i in range(pas + 1):
        t = math.pi * (1 - i / pas)
        r = math.sin(t) * math.sin(t / 2.0) ** m
        rmax = max(rmax, r)
        pts.append((r, H * (1 + math.cos(t)) / 2.0))
    return [(max(0.0, r / rmax * R), z) for r, z in pts]


def roche(r, x, y, z, m, graine, ecrase=0.8, rugueux=0.28, subdiv=2):
    """Bloc anguleux : icosphère déformée, facettes franches (les reflets y font des éclats, comme le charbon vanilla)."""
    rng = random.Random(graine)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    S._adopt(o, mat(m))
    for v in o.data.vertices:
        f = 1.0 + rng.uniform(-rugueux, rugueux)
        v.co = (v.co[0] * f, v.co[1] * f * (0.9 + rng.uniform(-0.1, 0.1)), v.co[2] * f * ecrase)
    S.bevel(o, 0.012)
    o.rotation_euler = (rng.uniform(0, 3), rng.uniform(0, 3), rng.uniform(0, 3))
    return o


def tube(points, r, m, rayons=None, res=14):
    """Tube lisse passant par les points (courbe de Bézier à poignées automatiques) ; rayons : facteur par point."""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 3
    cu.resolution_u = res
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for i, (bp, p) in enumerate(zip(sp.bezier_points, points)):
        bp.co = p
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
        if rayons:
            bp.radius = rayons[i]
    cu.materials.append(m if not isinstance(m, str) else mat(m))
    o = bpy.data.objects.new("tube", cu)
    S.piece_collection().objects.link(o)
    return o


# ------------------------------------------------------------------------------------------------------------------
# Regroupement
# ------------------------------------------------------------------------------------------------------------------
def noms():
    return set(o.name for o in S.piece_objects())


def capte(fn, *a, **k):
    """Lance fn et rend les objets qu'elle a créés."""
    av = noms()
    fn(*a, **k)
    return [o for o in S.piece_objects() if o.name not in av]


def pivoter(objs, rot=(0, 0, 0), loc=(0, 0, 0), s=1.0):
    """Tourne, déplace, met à l'échelle un ensemble d'objets, comme un seul (rot en degrés, ordre X, Y, Z)."""
    e = bpy.data.objects.new("pivot", None)
    bpy.context.scene.collection.objects.link(e)
    e.rotation_euler = tuple(math.radians(a) for a in rot)
    e.location = loc
    e.scale = (s, s, s)
    vus = set()
    for o in objs:
        t = o
        while t.parent is not None:
            t = t.parent
        if t is not e and t.name not in vus:
            vus.add(t.name)
            t.parent = e
    return objs


# ------------------------------------------------------------------------------------------------------------------
# Lumière, caméra, cadrage
# ------------------------------------------------------------------------------------------------------------------
def direction(az_deg, el_deg):
    """Du point visé VERS la caméra : az 0 = caméra au sud (−y), az positif = caméra vers l'ouest (−x)."""
    a, e = math.radians(az_deg), math.radians(el_deg)
    return Vector((-math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def soleil(scene, vers_soleil, force, couleur=(1.0, 0.97, 0.92), ombre=True, angle=6.0, nom="sun"):
    d = bpy.data.lights.new(nom, "SUN")
    d.energy = force
    d.color = couleur
    d.angle = math.radians(angle)
    d.use_shadow = ombre
    o = bpy.data.objects.new(nom, d)
    scene.collection.objects.link(o)
    o.rotation_euler = Vector(vers_soleil).normalized().to_track_quat("Z", "Y").to_euler()
    return o


def monde(scene, cle, contre):
    """Ciel à dégradé (zénith clair, sol presque noir), boîte à lumière côté clé, bande de contre-jour : les métaux ont
    enfin quelque chose à refléter ; c'est le reflet, pas la couleur, qui fait le modelé des icônes vanilla."""
    w = bpy.data.worlds.new("monde")
    w.use_nodes = True
    nt = w.node_tree
    N, L = nt.nodes, nt.links
    bg = N.get("Background")
    tc = N.new("ShaderNodeTexCoord")
    sz = N.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Generated"], sz.inputs[0])
    z = N.new("ShaderNodeValToRGB")
    r = z.color_ramp
    r.elements[0].position = 0.25
    r.elements[0].color = (0.012, 0.012, 0.016, 1)
    r.elements[1].position = 1.0
    r.elements[1].color = (0.62, 0.68, 0.78, 1)
    e = r.elements.new(0.60)
    e.color = (0.13, 0.145, 0.17, 1)
    zm = N.new("ShaderNodeMapRange")
    zm.inputs["From Min"].default_value = -1
    L.new(sz.outputs["Z"], zm.inputs["Value"])
    L.new(zm.outputs["Result"], z.inputs["Fac"])
    col = z.outputs["Color"]
    for dirv, a, b, force, teinte in ((cle, 0.80, 0.97, 2.6, (1.0, 0.96, 0.90)), (contre, 0.90, 0.985, 1.8, (0.85, 0.92, 1.0))):
        dp = N.new("ShaderNodeVectorMath")
        dp.operation = "DOT_PRODUCT"
        L.new(tc.outputs["Generated"], dp.inputs[0])
        dp.inputs[1].default_value = tuple(Vector(dirv).normalized())
        fac = _map(N, L, dp.outputs["Value"], a, b, 0.0, force, lisse=True)
        t = N.new("ShaderNodeRGB")
        t.outputs[0].default_value = teinte + (1,)
        ajout = _scale(N, L, t.outputs[0], fac)
        add = N.new("ShaderNodeVectorMath")
        add.operation = "ADD"
        L.new(col, add.inputs[0])
        L.new(ajout, add.inputs[1])
        col = add.outputs["Vector"]
    L.new(col, bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    scene.world = w


def cadrer(cam, remplir):
    """Caméra orthographique cadrée sur la boîte projetée de tous les sommets (modificateurs compris)."""
    dg = bpy.context.evaluated_depsgraph_get()
    R = cam.matrix_world.to_3x3()
    droite, haut = R.col[0], R.col[1]
    xs, ys = [], []
    for o in S.piece_objects():
        if o.type not in ("MESH", "CURVE"):
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        for v in me.vertices:
            p = mw @ v.co
            xs.append(p.dot(droite))
            ys.append(p.dot(haut))
        ev.to_mesh_clear()
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    ext = max(max(xs) - min(xs), max(ys) - min(ys))
    cam.data.ortho_scale = ext / remplir
    cam.location = cam.location + droite * (cx - cam.location.dot(droite)) + haut * (cy - cam.location.dot(haut))


def rendre(fn, chemin, samples, taille, el, az, remplir, etiquette):
    scene = S.reset()
    vider_matieres()
    S.setup_render(scene, taille, taille, samples=samples, seed=20261101)
    scene.cycles.max_bounces = 6
    scene.cycles.sample_clamp_indirect = 4.0
    fn()
    d = direction(az, el)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.clip_start = 0.1
    cam_data.clip_end = 400.0
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = d * 100.0
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    bpy.context.view_layer.update()
    cadrer(cam, remplir)
    R = cam.matrix_world.to_3x3()
    droite, haut = R.col[0], R.col[1]
    # clé du haut gauche (comme le vanilla), appoint froid à droite, contre-jour qui détache les arêtes
    cle = -droite * 0.72 + haut * 0.62 + d * 0.55
    contre = droite * 0.55 + haut * 0.65 - d * 0.55
    soleil(scene, cle, 2.7, nom="cle")
    soleil(scene, droite * 0.9 - haut * 0.1 + d * 0.5, 0.45, couleur=(0.82, 0.90, 1.0), ombre=False, nom="appoint")
    soleil(scene, contre, 1.5, couleur=(0.92, 0.96, 1.0), ombre=False, nom="contre")
    monde(scene, cle, contre)
    scene.render.filepath = chemin
    bpy.ops.render.render(write_still=True)
    print("[CALC-ICONES] rendu %s -> %s" % (etiquette, chemin))
