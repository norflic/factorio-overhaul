"""Scène Blender étalonnée « style Factorio » (lot V0, H-V1). S'exécute DANS Blender (module bpy).

Fournit :
- la caméra orthographique, le soleil, le ciel, le sol (constantes : tools/render/fo_calib.py) ;
- une petite boîte à outils de modélisation pour les fichiers de pièces (tools/render/pieces/*.py) ;
- les quatre passes de sortie : principale, ombre, lueur, halo.

Conventions (CALIBRATION.md §2) : unité Blender = largeur d'une tuile ; +X est, +Y nord, +Z haut ;
l'origine est la position de l'entité au niveau du sol ; une tuile vers le sud = 1/cos θ unité en Y.
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import fo_calib as C  # noqa: E402

PIECE_COLL = "fo_piece"
OCCLUDER_COLL = "fo_occluders"   # volumes de remplacement d'un bâtiment porteur (passe halo seulement, V0b)
HALO_LIGHTS = []    # sources ponctuelles de la seule passe halo (lumière portée sans bruit)
EXTRA_LIGHTS = []   # lumières d'appoint (sans ombre), allumées avec le soleil
GROUND_NAME = "fo_ground"


# ------------------------------------------------------------------------------------------------
# Scène
# ------------------------------------------------------------------------------------------------
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    coll = bpy.data.collections.new(PIECE_COLL)
    scene.collection.children.link(coll)
    return scene


def piece_collection():
    return bpy.data.collections[PIECE_COLL]


def setup_render(scene, width, height, samples=None, seed=None):
    r = scene.render
    r.engine = "CYCLES"
    cy = scene.cycles
    cy.device = "CPU"
    cy.samples = samples or C.SAMPLES
    cy.seed = C.SEED if seed is None else seed
    cy.use_animated_seed = False
    cy.use_adaptive_sampling = False
    cy.use_denoising = False
    cy.use_guiding = False
    cy.use_light_tree = True
    cy.max_bounces = C.MAX_BOUNCES
    cy.diffuse_bounces = 4
    cy.glossy_bounces = 4
    cy.transparent_max_bounces = 8
    cy.sample_clamp_direct = 0.0
    cy.sample_clamp_indirect = 10.0
    cy.pixel_filter_type = "BLACKMAN_HARRIS"
    cy.filter_width = C.FILTER_WIDTH_PX
    r.resolution_x = width
    r.resolution_y = height
    r.resolution_percentage = 100
    r.pixel_aspect_x = 1.0
    r.pixel_aspect_y = 1.0
    r.film_transparent = True
    r.dither_intensity = 0.0
    r.threads_mode = "FIXED"
    r.threads = 8
    r.use_compositing = False
    r.use_sequencer = False
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "16"
    r.image_settings.compression = 15
    vs = scene.view_settings
    vs.view_transform = "Standard"
    vs.look = "None"
    vs.exposure = 0.0
    vs.gamma = 1.0
    scene.display_settings.display_device = "sRGB"
    scene.sequencer_colorspace_settings.name = "sRGB"


def setup_camera(scene, width, height, center_px=None):
    """Caméra orthographique : l'origine Blender se projette au centre de l'image (ou à center_px)."""
    cam_data = bpy.data.cameras.new("fo_cam")
    cam_data.type = "ORTHO"
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.ortho_scale = width / C.PX_PER_UNIT_HR
    cam_data.clip_start = 0.1
    cam_data.clip_end = 200.0
    cam = bpy.data.objects.new("fo_cam", cam_data)
    scene.collection.objects.link(cam)
    t = math.radians(C.THETA_DEG)
    dist = 60.0
    cam.location = (0.0, -math.sin(t) * dist, math.cos(t) * dist)
    cam.rotation_euler = (t, 0.0, 0.0)
    if center_px is not None:
        # décalage optique (en fraction de la plus grande dimension) pour placer l'origine en center_px
        cx, cy = center_px
        cam_data.shift_x = (width / 2.0 - cx) / width
        cam_data.shift_y = -(height / 2.0 - cy) / width
    scene.camera = cam
    return cam


def setup_world(scene, strength=None, color=None):
    w = bpy.data.worlds.new("fo_world")
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background") or w.node_tree.nodes.new("ShaderNodeBackground")
    col = color or C.SKY_COLOR
    bg.inputs["Color"].default_value = (col[0], col[1], col[2], 1.0)
    bg.inputs["Strength"].default_value = C.SKY_STRENGTH if strength is None else strength
    out = w.node_tree.nodes.get("World Output") or w.node_tree.nodes.new("ShaderNodeOutputWorld")
    if not bg.outputs["Background"].links:
        w.node_tree.links.new(bg.outputs["Background"], out.inputs["Surface"])
    sg = getattr(C, "SKY_GLOSSY_FACTOR", None)
    if sg is not None and sg != 1.0:
        # V0b (facultatif) : ciel vu par les seuls rayons spéculaires × SKY_GLOSSY_FACTOR (bords rasants des
        # métaux sombres, comme en vanilla). Le nœud « Background » garde son nom et sa force (render_passes
        # éteint le ciel en mettant sa force à 0 : la multiplication suit).
        nt = w.node_tree
        lp = nt.nodes.new("ShaderNodeLightPath")
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["To Min"].default_value = 1.0
        mr.inputs["To Max"].default_value = float(sg)
        nt.links.new(lp.outputs["Is Glossy Ray"], mr.inputs["Value"])
        bg2 = nt.nodes.new("ShaderNodeBackground")
        bg2.inputs["Color"].default_value = (col[0], col[1], col[2], 1.0)
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        nt.links.new(mr.outputs["Result"], mul.inputs[0])
        # la force du nœud « Background » est lue par render_passes : on la reprend par un pilote simple
        # (valeur copiée à chaque changement d'état, voir _sync_sky)
        mul.inputs[1].default_value = bg.inputs["Strength"].default_value
        mul.name = "fo_sky_glossy_mul"
        nt.links.new(mul.outputs[0], bg2.inputs["Strength"])
        nt.links.new(bg2.outputs["Background"], out.inputs["Surface"])
    scene.world = w
    return w


def _sync_sky(world):
    """Recopie la force du nœud « Background » dans le montage SKY_GLOSSY_FACTOR (s'il existe)."""
    nt = world.node_tree
    mul = nt.nodes.get("fo_sky_glossy_mul")
    if mul is not None:
        mul.inputs[1].default_value = nt.nodes["Background"].inputs["Strength"].default_value


def add_sun(scene, strength=None, elev=None, azimuth=None, name="fo_sun", color=None, angle=None):
    d = bpy.data.lights.new(name, "SUN")
    d.energy = C.SUN_STRENGTH if strength is None else strength
    col = color or C.SUN_COLOR
    d.color = col
    d.angle = math.radians(C.SUN_ANGLE_DEG if angle is None else angle)
    o = bpy.data.objects.new(name, d)
    scene.collection.objects.link(o)
    e = math.radians(C.SUN_ELEV_DEG if elev is None else elev)
    a = math.radians(C.SUN_AZIMUTH_DEG if azimuth is None else azimuth)
    # La lumière part selon -Z local. On aligne -Z local sur -(vecteur vers le soleil).
    to_sun = (math.cos(e) * math.sin(a), math.cos(e) * math.cos(a), math.sin(e))
    from mathutils import Vector
    o.rotation_euler = Vector(to_sun).to_track_quat("Z", "Y").to_euler()
    return o


def add_fill(scene):
    """Appoint sans ombre (C.FILL_*) : n'existe que si FILL_STRENGTH > 0."""
    if C.FILL_STRENGTH <= 0:
        return None
    o = add_sun(scene, strength=C.FILL_STRENGTH, elev=C.FILL_ELEV_DEG, azimuth=C.FILL_AZIMUTH_DEG,
                name="fo_fill", color=(1.0, 1.0, 1.0))
    o.data.use_shadow = False
    EXTRA_LIGHTS.append(o)
    return o


def halo_light(loc, color, power, radius=0.1, name="fo_halo"):
    """Source ponctuelle (W) qui n'existe que dans la passe halo : la lumière portée par une pièce
    émissive y est échantillonnée sans bruit (une surface émissive petite donne un sol plein de grains)."""
    d = bpy.data.lights.new(name, "POINT")
    d.energy = power
    d.color = color
    d.shadow_soft_size = radius
    o = bpy.data.objects.new(name, d)
    o.location = loc
    bpy.context.scene.collection.objects.link(o)
    o.hide_render = True
    HALO_LIGHTS.append(o)
    return o


def add_ground(scene, size=60.0):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    g = bpy.context.active_object
    g.name = GROUND_NAME
    for c in list(g.users_collection):
        c.objects.unlink(g)
    scene.collection.objects.link(g)
    m = bpy.data.materials.new("fo_ground_mat")
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    a = C.GROUND_ALBEDO
    p.inputs["Base Color"].default_value = (a, a, a, 1)
    p.inputs["Roughness"].default_value = 1.0
    ga = getattr(C, "GROUND_GLOSSY_ALBEDO", None)
    if ga is not None and ga != a:
        # V0b (facultatif) : sol plus clair pour les SEULS rayons spéculaires (reflets des métaux tournés vers la
        # caméra, comme les rendus vanilla : sol clair, ciel sombre). Les rayons diffus voient GROUND_ALBEDO :
        # l'équilibre façade/dessus (CALIBRATION §3.3) ne change pas.
        lp = nt.nodes.new("ShaderNodeLightPath")
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs[6].default_value = (a, a, a, 1)
        mix.inputs[7].default_value = (ga, ga, ga, 1)
        nt.links.new(lp.outputs["Is Glossy Ray"], mix.inputs["Factor"])
        nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    g.data.materials.append(m)
    return g


# ------------------------------------------------------------------------------------------------
# Pièces posées sur un bâtiment vanilla (V0b) : parties cachées et volume de remplacement
# ------------------------------------------------------------------------------------------------
def mark_hidden(obj):
    """Partie cachée par le bâtiment porteur (pied d'une cheminée derrière le corps d'un four...).

    - couche principale : rendue normalement (le moteur la recouvre par le bâtiment, dont les couches sont
      dessinées APRÈS celles de la pièce) ;
    - passe halo : invisible à la caméra, mais elle bloque toujours la lumière (aucun « trou » à sa forme) ;
    - passe AO : retirée (son liseré de contact tomberait sans cause visible à côté du bâtiment) ;
    - passe ombre : garde son ombre."""
    if obj is not None:
        obj["fo_hidden"] = 1
    return obj


def is_hidden(obj):
    return bool(obj.get("fo_hidden", 0))


def occluder_collection():
    if OCCLUDER_COLL not in bpy.data.collections:
        coll = bpy.data.collections.new(OCCLUDER_COLL)
        bpy.context.scene.collection.children.link(coll)
    return bpy.data.collections[OCCLUDER_COLL]


def add_occluder(size, loc, name="fo_occluder"):
    """Volume de remplacement du bâtiment porteur (boîte noire, unités Blender) : présent dans la SEULE passe
    halo, où il bloque la lumière des sources et cache ce qui est derrière lui. Il ne reçoit aucune lumière
    (aucun halo sur le corps du bâtiment : rapport V0, F64) et n'apparaît dans aucune autre passe."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for c in list(o.users_collection):
        c.objects.unlink(o)
    occluder_collection().objects.link(o)
    o.name = name
    o.data.materials.clear()
    o.data.materials.append(_black_mat())
    o.hide_render = True
    return o


def occluder_objects():
    if OCCLUDER_COLL not in bpy.data.collections:
        return []
    return sorted(bpy.data.collections[OCCLUDER_COLL].all_objects, key=lambda o: o.name)


def link_exclude(light_obj, objs, name):
    """Lien de lumière : `light_obj` n'éclaire pas `objs` (receveurs exclus)."""
    coll = bpy.data.collections.new(name)
    for o in objs:
        coll.objects.link(o)
    light_obj.light_linking.receiver_collection = coll
    for o in objs:
        coll.collection_objects[o.name].light_linking.link_state = "EXCLUDE"
    return coll


# ------------------------------------------------------------------------------------------------
# Matériaux
# ------------------------------------------------------------------------------------------------
def _nodes(mat):
    mat.use_nodes = True
    nt = mat.node_tree
    return nt, nt.nodes, nt.links


def mat_metal(name, color, rough=0.45, metallic=0.85, grain=0.18, grain_scale=60.0, rust=None,
              rust_amount=0.0, rust_scale=6.0, dirt=0.0, seed=0.0):
    """Métal peint ou brut : couleur de base modulée par un grain fin (bruit) et des taches de rouille.

    grain : amplitude relative du grain (0,18 = ±18 %), mesurée contre le « grain » vanilla.
    dirt  : assombrissement des creux par occlusion ambiante (0 à 1).
    """
    m = bpy.data.materials.new(name)
    nt, N, L = _nodes(m)
    p = N["Principled BSDF"]
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metallic
    tc = N.new("ShaderNodeTexCoord")
    # grain fin
    n1 = N.new("ShaderNodeTexNoise")
    n1.inputs["Scale"].default_value = grain_scale
    n1.inputs["Detail"].default_value = 6.0
    n1.inputs["Roughness"].default_value = 0.6
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
    base = N.new("ShaderNodeRGB")
    base.outputs[0].default_value = (color[0], color[1], color[2], 1)
    mul = N.new("ShaderNodeVectorMath")
    mul.operation = "SCALE"
    L.new(base.outputs[0], mul.inputs[0])
    L.new(g.outputs["Result"], mul.inputs["Scale"])
    col_out = mul.outputs["Vector"]
    if rust is not None and rust_amount > 0:
        n2 = N.new("ShaderNodeTexNoise")
        n2.inputs["Scale"].default_value = rust_scale
        n2.inputs["Detail"].default_value = 8.0
        n2.inputs["Roughness"].default_value = 0.65
        if "W" in n2.inputs:
            n2.noise_dimensions = "4D"
            n2.inputs["W"].default_value = seed + 7.3
        L.new(tc.outputs["Object"], n2.inputs["Vector"])
        mr = N.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 0.62 - 0.25 * rust_amount
        mr.inputs["From Max"].default_value = 0.70 - 0.25 * rust_amount
        L.new(n2.outputs["Fac"], mr.inputs["Value"])
        rc = N.new("ShaderNodeRGB")
        rc.outputs[0].default_value = (rust[0], rust[1], rust[2], 1)
        rmul = N.new("ShaderNodeVectorMath")
        rmul.operation = "SCALE"
        L.new(rc.outputs[0], rmul.inputs[0])
        L.new(g.outputs["Result"], rmul.inputs["Scale"])
        mix = N.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        L.new(mr.outputs["Result"], mix.inputs["Factor"])
        L.new(col_out, mix.inputs[6])
        L.new(rmul.outputs["Vector"], mix.inputs[7])
        col_out = mix.outputs[2]
        # la rouille est mate et non métallique
        rr = N.new("ShaderNodeMapRange")
        rr.inputs["To Min"].default_value = rough
        rr.inputs["To Max"].default_value = min(1.0, rough + 0.4)
        L.new(mr.outputs["Result"], rr.inputs["Value"])
        L.new(rr.outputs["Result"], p.inputs["Roughness"])
        rm = N.new("ShaderNodeMapRange")
        rm.inputs["To Min"].default_value = metallic
        rm.inputs["To Max"].default_value = 0.1
        L.new(mr.outputs["Result"], rm.inputs["Value"])
        L.new(rm.outputs["Result"], p.inputs["Metallic"])
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
        L.new(col_out, dmul.inputs[0])
        L.new(dm.outputs["Result"], dmul.inputs["Scale"])
        col_out = dmul.outputs["Vector"]
    L.new(col_out, p.inputs["Base Color"])
    m["fo_kind"] = "surface"
    return m


def mat_flat(name, color, rough=0.6, metallic=0.0):
    m = bpy.data.materials.new(name)
    nt, N, L = _nodes(m)
    p = N["Principled BSDF"]
    p.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metallic
    m["fo_kind"] = "surface"
    return m


def mat_emissive(name, color, strength=8.0, base=(0.05, 0.03, 0.02), main_scale=1.0):
    """Surface lumineuse : sert aux couches lueur (draw_as_glow) et halo (draw_as_light).

    main_scale (V0b, facultatif) : facteur de l'émission dans la passe PRINCIPALE. En jeu, la lueur additive
    s'ajoute à la couche principale : avec 1,0 (défaut, comportement V0) l'émission compte deux fois et les
    braises sortent jaune pâle. Avec 0,0, la couche principale montre la surface éteinte (sombre) et la lueur
    seule donne la couleur, comme le feu vanilla (foyer sombre + feu additif)."""
    m = bpy.data.materials.new(name)
    m["fo_main_scale"] = float(main_scale)
    nt, N, L = _nodes(m)
    p = N["Principled BSDF"]
    p.inputs["Base Color"].default_value = (base[0], base[1], base[2], 1)
    p.inputs["Roughness"].default_value = 0.5
    p.inputs["Emission Color"].default_value = (color[0], color[1], color[2], 1)
    p.inputs["Emission Strength"].default_value = strength
    # La surface n'éclaire pas la scène (pas de bruit) : la lumière portée vient des sources ponctuelles
    # déclarées par la pièce (halo_light), dans la seule passe halo.
    m.cycles.emission_sampling = "NONE"
    m["fo_kind"] = "emissive"
    m["fo_emit_color"] = list(color)
    m["fo_emit_strength"] = strength
    return m


# ------------------------------------------------------------------------------------------------
# Modélisation (aides pour les fichiers de pièces)
# ------------------------------------------------------------------------------------------------
def _adopt(obj, mat=None, name=None):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    piece_collection().objects.link(obj)
    if name:
        obj.name = name
    if mat is not None:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    return obj


def smooth(obj, angle_deg=40.0):
    """Ombrage lissé jusqu'à angle_deg (arêtes plus vives conservées)."""
    for p in obj.data.polygons:
        p.use_smooth = True
    try:
        mod = obj.modifiers.new("smooth", "SMOOTH_BY_ANGLE")
        mod["Input_1"] = math.radians(angle_deg)
    except Exception:
        if hasattr(obj.data, "set_sharp_from_angle"):
            obj.data.set_sharp_from_angle(angle=math.radians(angle_deg))
    return obj


def bevel(obj, width=0.015, segments=2):
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(35)
    return obj


def box(size, loc, mat=None, name=None, bevel_w=0.012):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    _adopt(o, mat, name)
    if bevel_w:
        bevel(o, bevel_w)
    return o


def cylinder(radius, depth, loc, mat=None, name=None, verts=48, rot=(0, 0, 0), bevel_w=0.008,
             radius2=None, caps=True):
    """Cylindre (ou tronc de cône si radius2) d'axe Z avant rotation, centré sur loc ; caps=False : tube ouvert."""
    fill = "NGON" if caps else "NOTHING"
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot,
                                            end_fill_type=fill)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius2, depth=depth, location=loc,
                                        rotation=rot, end_fill_type=fill)
    o = bpy.context.active_object
    _adopt(o, mat, name)
    smooth(o, 50)
    if bevel_w:
        bevel(o, bevel_w)
    return o


def torus(major, minor, loc, mat=None, name=None, rot=(0, 0, 0), major_seg=64, minor_seg=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=major_seg, minor_segments=minor_seg)
    o = bpy.context.active_object
    _adopt(o, mat, name)
    smooth(o, 80)
    return o


def sphere(radius, loc, mat=None, name=None, seg=32, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc, segments=seg, ring_count=rings)
    o = bpy.context.active_object
    _adopt(o, mat, name)
    smooth(o, 80)
    return o


def rivet_ring(radius, z, count, rivet_r, mat, center=(0.0, 0.0), name="rivets", phase=0.0):
    """Anneau de rivets (demi-sphères) autour d'un cylindre vertical."""
    objs = []
    for i in range(count):
        a = phase + 2 * math.pi * i / count
        x = center[0] + radius * math.cos(a)
        y = center[1] + radius * math.sin(a)
        objs.append(sphere(rivet_r, (x, y, z), mat, "%s_%02d" % (name, i), seg=12, rings=6))
    return join(objs, name)


def join(objs, name):
    if not objs:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o


def piece_objects():
    return sorted(piece_collection().all_objects, key=lambda o: o.name)


# ------------------------------------------------------------------------------------------------
# Passes de sortie
# ------------------------------------------------------------------------------------------------
_BLACK = None


def _black_mat():
    global _BLACK
    if _BLACK is None:
        _BLACK = mat_flat("fo_black", (0, 0, 0), rough=1.0)
    return _BLACK


def _swap_materials(objs, fn):
    """Remplace les matériaux selon fn(mat) -> mat ; renvoie l'état pour restaurer."""
    saved = []
    for o in objs:
        if o.type != "MESH":
            continue
        mats = [s.material for s in o.material_slots]
        saved.append((o, mats))
        for i, s in enumerate(o.material_slots):
            s.material = fn(s.material)
    return saved


def _restore(saved):
    for o, mats in saved:
        for i, m in enumerate(mats):
            o.material_slots[i].material = m


def _emissive_only(mat):
    if mat is not None and mat.get("fo_kind") == "emissive":
        return mat
    return _black_mat()


_WHITE = None
_AO = None


def _ao_ground_mat():
    global _AO
    if _AO is None:
        m = bpy.data.materials.new("fo_ao_ground")
        nt, N, L = _nodes(m)
        N.remove(N["Principled BSDF"])
        ao = N.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = C.AO_DISTANCE
        ao.samples = 16
        ao.inputs["Color"].default_value = (1, 1, 1, 1)
        em = N.new("ShaderNodeEmission")
        em.inputs["Strength"].default_value = 1.0
        L.new(ao.outputs["Color"], em.inputs["Color"])
        L.new(em.outputs["Emission"], N["Material Output"].inputs["Surface"])
        _AO = m
    return _AO


def _white_mat():
    global _WHITE
    if _WHITE is None:
        _WHITE = mat_flat("fo_white", (0.8, 0.8, 0.8), rough=1.0)
    return _WHITE


_BOOSTED = {}


def _emissive_or_white(mat):
    """Passe halo : sources plus fortes (C.LIGHT_GAIN) pour que la lumière portée se voie au sol ;
    tout le reste en gris clair mat (la carte des lumières révèle la couleur de jour : game.frag)."""
    if mat is not None and mat.get("fo_kind") == "emissive":
        b = _BOOSTED.get(mat.name)
        if b is None:
            b = mat.copy()
            b.name = mat.name + "_halo"
            p = b.node_tree.nodes["Principled BSDF"]
            p.inputs["Emission Strength"].default_value = mat["fo_emit_strength"] * C.LIGHT_EMIT_GAIN
            _BOOSTED[mat.name] = b
        return b
    return _white_mat()


def _main_emission_swapper():
    """Passe principale : émission × fo_main_scale (1,0 : matériau inchangé, comportement V0). Copies
    locales à l'appel (aucun cache de module : les boucles de rendu des lots V3 réinitialisent la scène)."""
    made = {}

    def fn(mat):
        if mat is None or mat.get("fo_kind") != "emissive":
            return mat
        k = float(mat.get("fo_main_scale", 1.0))
        if k == 1.0:
            return mat
        b = made.get(mat.name)
        if b is None:
            b = mat.copy()
            b.name = mat.name + "_main"
            p = b.node_tree.nodes["Principled BSDF"]
            p.inputs["Emission Strength"].default_value = mat["fo_emit_strength"] * k
            made[mat.name] = b
        return b
    return fn


def render_to(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def render_passes(scene, out_dir, prefix, layers, sun, ground):
    """Rend les couches demandées dans out_dir/<prefix>-<couche>.png (PNG 16 bits RGBA).

    main   : la pièce éclairée (soleil + ciel). Le sol n'apparaît pas à l'image mais renvoie la lumière.
    ao     : occlusion de contact du ciel sur le sol (sol attrape-ombre, soleil éteint, pièce invisible
             à la caméra) ; composée SOUS la couche principale au post-traitement, comme le contact
             sombre et doux intégré aux sprites vanilla.
    shadow : ombre portée du seul soleil sur le sol (attrape-ombre, ciel éteint, pièce invisible).
    glow   : émission seule, cachée par les parties opaques (rendues noires).
    light  : lumière reçue des seules sources sur le sol blanc. V0b (C.LIGHT_HOLDOUT, défaut) : la pièce est
             DÉCOUPÉE (holdout : alpha 0 sur sa silhouette, elle garde son ombre) car draw_as_light révèle la
             couleur de jour de tout ce qu'il recouvre (F64) ; les parties cachées (mark_hidden) sont
             invisibles à la caméra ; les volumes de remplacement (add_occluder) bloquent la lumière et restent
             noirs. Avec LIGHT_HOLDOUT = False : comportement V0 (pièce gris clair éclairée + sources).

    Parties cachées (mark_hidden) : retirées de la passe ao ; invisibles à la caméra dans la passe light.
    Volumes de remplacement : présents dans la seule passe light.
    """
    objs = piece_objects()
    occ = occluder_objects()
    hidden = [o for o in objs if is_hidden(o)]
    world = scene.world
    bg = world.node_tree.nodes["Background"]
    sky = bg.inputs["Strength"].default_value
    has_emit = any(s.material is not None and s.material.get("fo_kind") == "emissive"
                   for o in objs if o.type == "MESH" for s in o.material_slots)
    results = {}
    for o in occ:
        o.hide_render = True

    def state(sun_on, sky_on, catcher, ground_cam, obj_cam, fill_on=False):
        sun.hide_render = not sun_on
        for x in EXTRA_LIGHTS:
            x.hide_render = not fill_on
        bg.inputs["Strength"].default_value = sky if sky_on else 0.0
        _sync_sky(world)
        ground.is_shadow_catcher = catcher
        ground.visible_camera = ground_cam
        for o in objs:
            o.visible_camera = obj_cam

    if "main" in layers:
        state(True, True, False, False, True, fill_on=True)
        saved = _swap_materials(objs, _main_emission_swapper())
        p = os.path.join(out_dir, "%s-main.png" % prefix)
        render_to(scene, p)
        results["main"] = p
        _restore(saved)
    if "ao" in layers:
        # Sol émissif dont la couleur = facteur d'occlusion ambiante à courte portée (nœud AO limité à
        # AO_DISTANCE) : 1 = dégagé, 0 = occulté. Pièce invisible à la caméra, aucune lumière.
        gsaved = _swap_materials([ground], lambda m: _ao_ground_mat())
        state(False, False, False, True, False)
        for o in hidden:
            o.hide_render = True
        p = os.path.join(out_dir, "%s-ao.png" % prefix)
        render_to(scene, p)
        results["ao"] = p
        for o in hidden:
            o.hide_render = False
        _restore(gsaved)
    if "shadow" in layers:
        state(True, False, True, True, False)
        p = os.path.join(out_dir, "%s-shadow.png" % prefix)
        render_to(scene, p)
        results["shadow"] = p
    if "glow" in layers and has_emit:
        saved = _swap_materials(objs, _emissive_only)
        state(False, False, False, False, True)
        p = os.path.join(out_dir, "%s-glow.png" % prefix)
        render_to(scene, p)
        results["glow"] = p
        _restore(saved)
    if "light" in layers and has_emit:
        saved = _swap_materials(objs, _emissive_or_white)
        gsaved = _swap_materials([ground], lambda m: _white_mat())
        state(False, False, False, True, True)
        holdout = bool(getattr(C, "LIGHT_HOLDOUT", False))
        if holdout:
            for o in objs:
                if is_hidden(o):
                    o.visible_camera = False
                else:
                    o.is_holdout = True
            for o in occ:
                o.hide_render = False
        for x in HALO_LIGHTS:
            x.hide_render = False
        # les surfaces émissives restent vues par la caméra mais pas par les rayons indirects
        # (sinon : grains lumineux sur tout le sol)
        emit_objs = [o for o in objs if o.type == "MESH" and any(
            sl.material is not None and sl.material.get("fo_kind") == "emissive" for sl in o.material_slots)]
        for o in emit_objs:
            o.visible_diffuse = False
            o.visible_glossy = False
        # éclairage direct seul : halo sans grain (les rebonds de petites surfaces très éclairées
        # donnent des points lumineux épars à tout nombre d'échantillons raisonnable)
        cyc = scene.cycles
        bounces = (cyc.max_bounces, cyc.diffuse_bounces, cyc.glossy_bounces)
        cyc.max_bounces, cyc.diffuse_bounces, cyc.glossy_bounces = 0, 0, 0
        p = os.path.join(out_dir, "%s-light.png" % prefix)
        render_to(scene, p)
        results["light"] = p
        cyc.max_bounces, cyc.diffuse_bounces, cyc.glossy_bounces = bounces
        for o in emit_objs:
            o.visible_diffuse = True
            o.visible_glossy = True
        for x in HALO_LIGHTS:
            x.hide_render = True
        if holdout:
            for o in objs:
                o.is_holdout = False
            for o in occ:
                o.hide_render = True
        _restore(saved)
        _restore(gsaved)
    state(True, True, False, False, True, fill_on=True)
    return results
