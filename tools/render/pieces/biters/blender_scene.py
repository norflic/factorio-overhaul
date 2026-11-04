"""Maillage, attributs et matière des biters dans Blender (rendu_blender, serie_blender)."""
import bpy
import numpy as np
from mathutils import Vector

import fo_scene as S


def maillage(nom, V, Q, N):
    m = bpy.data.meshes.new(nom)
    m.vertices.add(len(V))
    m.loops.add(len(Q) * 4)
    m.polygons.add(len(Q))
    m.vertices.foreach_set("co", V.ravel())
    m.polygons.foreach_set("loop_start", np.arange(len(Q), dtype=np.int32) * 4)
    m.loops.foreach_set("vertex_index", Q.astype(np.int32).ravel())
    m.update(calc_edges=True)
    m.shade_smooth()
    m.normals_split_custom_set_from_vertices(N.tolist())
    return m


def attr_vec(m, nom, a):
    x = m.attributes.new(nom, "FLOAT_VECTOR", "POINT")
    x.data.foreach_set("vector", a.astype(np.float32).ravel())


def attr_coul(m, nom, c):
    x = m.attributes.new(nom, "FLOAT_COLOR", "POINT")
    x.data.foreach_set("color", np.concatenate([c, np.ones((len(c), 1), np.float32)], axis=1).astype(np.float32).ravel())


def matiere_peinte(echelle):
    """Toute la couleur vient des sommets ; le grain fin de la peau vient d'un bruit lu dans le repère de repos (attribut q)."""
    m = bpy.data.materials.new("fo_peau")
    m.use_nodes = True
    nt = m.node_tree
    n = nt.nodes
    l = nt.links
    p = n["Principled BSDF"]
    coul = n.new("ShaderNodeAttribute")
    coul.attribute_name = "coul"
    mat = n.new("ShaderNodeAttribute")
    mat.attribute_name = "mat"
    q = n.new("ShaderNodeAttribute")
    q.attribute_name = "q"
    l.new(coul.outputs[0], p.inputs["Base Color"])
    sep = n.new("ShaderNodeSeparateXYZ")
    l.new(mat.outputs[1], sep.inputs[0])
    l.new(sep.outputs[0], p.inputs["Roughness"])
    l.new(sep.outputs[1], p.inputs["Coat Weight"])
    p.inputs["Coat Roughness"].default_value = 0.24
    p.inputs["Specular IOR Level"].default_value = 0.5
    bruit = n.new("ShaderNodeTexNoise")
    bruit.inputs["Scale"].default_value = 22.0 / echelle
    bruit.inputs["Detail"].default_value = 5.0
    bruit.inputs["Roughness"].default_value = 0.62
    l.new(q.outputs[1], bruit.inputs["Vector"])
    bump = n.new("ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.010 * echelle
    l.new(bruit.outputs[0], bump.inputs["Height"])
    l.new(sep.outputs[2], bump.inputs["Strength"])
    l.new(bump.outputs[0], p.inputs["Normal"])
    return m


def boite_reflet(scene, puissance):
    """Grande source vue par les seuls rayons spéculaires : le large reflet vif des coques vanilla, sans changer la lumière diffuse.
    Éteinte avec l'appoint dans les passes au sol (S.EXTRA_LIGHTS)."""
    d = bpy.data.lights.new("fo_reflet", "AREA")
    d.size = 14.0
    d.energy = puissance
    ob = bpy.data.objects.new("fo_reflet", d)
    scene.collection.objects.link(ob)
    ob.location = (-6.0, -2.0, 25.0)
    ob.rotation_euler = Vector((6.0, 2.0, -25.0)).to_track_quat("-Z", "Y").to_euler()
    ob.visible_diffuse = False
    ob.visible_camera = False
    ob.visible_transmission = False
    ob.visible_volume_scatter = False
    S.EXTRA_LIGHTS.append(ob)
