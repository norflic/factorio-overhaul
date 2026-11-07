"""ESSAI 3D de la direction D « Plaquette » (lot DESIGN-MODULES, 7/11) : script BLENDER (5.2.2), PROPOSITION, rien n'est remplacé.

But (3e critique sévère du 7/11, priorités) : rendre D EXACTEMENT (même silhouette, mêmes proportions que icones_plaquette.py :
boîtier chanfreiné, 5 voyants en dôme dans leur bague, emblème du type en relief émaillé bordé de métal, contacts dorés), et
apporter ce que la 2D ne sait pas faire : métal peint écaillé aux arêtes, reflets francs, occlusion, ombre au sol, lumière du
nord-ouest cohérente sur toutes les faces. Un seul essai autorisé par le lead (fenêtre « pleine puissance » du 7/11).

Lancement (TOUJOURS par le verrou de rendu, interdit n° 6) :
  python tools/render/with_render_lock.py -- C:\\Users\\evan2\\tools\\blender-5.2.2\\blender.exe --background --factory-startup
      --python tools/render/pieces/modules/plaquette_3d_blender.py -- --out <dossier> [--cas speed:5,productivity:5]
      [--samples 64] [--taille 512]
Sortie : <dossier>/3d-<type>-<palier>.png (RGBA, fond transparent, ombre au sol comprise). La composition à 64 et 32 px, plaque du
chiffre romain comprise, est faite par plaquette_3d_planche.py (Python système).
Unités : celles des icônes (0 à 64, y vers le bas) ; Blender : x = X - 32, y = 32 - Y, z vers le haut.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

# -- mêmes constantes que icones_plaquette.py (recopiées : ce script tourne dans le Python de Blender, sans numpy du mod) --
CORPS = (6.0, 9.0, 61.0, 57.0, 7.5)
LED_XS = (30.6, 36.9, 43.2, 49.5, 55.8)
LED_Y, LED_R = 15.75, 2.6
GC = (33.0, 38.5)
ECHELLE_EMB = 1.18
HZ = 10.0           # épaisseur du boîtier (sa paroi avant fait ~6 px à l'écran sous 35°, comme la 2D)
HE = 2.4            # hauteur de l'emblème
ANGLE = -7.0        # rotation du boîtier (degrés, sens horaire vu de dessus)
INCLIN = 35.0       # inclinaison de la caméra depuis la verticale (raccourci de la face : cos 35° = 0,82, comme la 2D)

PEINTURE = {"speed": (0.055, 0.160, 0.420), "productivity": (0.500, 0.115, 0.030), "effectivity": (0.045, 0.165, 0.040)}
LUMIERE = {"speed": (0.35, 0.75, 1.0), "productivity": (1.0, 0.72, 0.22), "effectivity": (0.55, 1.0, 0.45)}
GARNITURE = {1: ((0.40, 0.21, 0.085), 0.40), 2: ((0.50, 0.52, 0.56), 0.28), 3: ((0.86, 0.57, 0.16), 0.22), 4: ((0.92, 0.66, 0.24), 0.16)}


def marche(k):
    return 1 if k <= 3 else 2 if k <= 6 else 3 if k <= 9 else 4


def b(X, Y):
    """Point des icônes (0..64, y vers le bas) -> plan de Blender."""
    return (X - 32.0, 32.0 - Y)


# ------------------------------------------------------------------------------------------------------------------
# Contours (mêmes formes que icones_plaquette.glyphe_base, agrandies de ECHELLE_EMB autour de GC)
# ------------------------------------------------------------------------------------------------------------------
def _echelle(pts):
    cx, cy = GC
    return [(cx + (x - cx) * ECHELLE_EMB, cy + (y - cy) * ECHELLE_EMB) for x, y in pts]


def chevron_epais(a, m, c, w):
    """Polygone d'un trait en V de demi-largeur w (A -> M -> C), angles vifs."""
    def norm(p, q):
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = math.hypot(dx, dy)
        return (-dy / L, dx / L)
    n1, n2 = norm(a, m), norm(m, c)

    def inter(p1, d1, p2, d2):
        den = d1[0] * d2[1] - d1[1] * d2[0]
        t = ((p2[0] - p1[0]) * d2[1] - (p2[1] - p1[1]) * d2[0]) / den
        return (p1[0] + d1[0] * t, p1[1] + d1[1] * t)
    d1 = (m[0] - a[0], m[1] - a[1])
    d2 = (c[0] - m[0], c[1] - m[1])
    out = []
    for sg in (1, -1):
        pa = (a[0] + sg * w * n1[0], a[1] + sg * w * n1[1])
        pc = (c[0] + sg * w * n2[0], c[1] + sg * w * n2[1])
        pm = inter(pa, d1, (m[0] + sg * w * n2[0], m[1] + sg * w * n2[1]), d2)
        out.append((pa, pm, pc))
    (pa, pm, pc), (qa, qm, qc) = out
    return [pa, pm, pc, qc, qm, qa]


def engrenage(cx, cy, n, r_pied, r_tete, f_tete, f_pied, arc=6):
    pts = []
    pas = 2 * math.pi / n
    for i in range(n):
        a0 = i * pas - math.pi / 2
        for a, r in [(a0 - f_pied * pas / 2, r_pied), (a0 - f_tete * pas / 2, r_tete), (a0 + f_tete * pas / 2, r_tete), (a0 + f_pied * pas / 2, r_pied)]:
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        a_deb, a_fin = a0 + f_pied * pas / 2, a0 + pas - f_pied * pas / 2
        for j in range(1, arc):
            a = a_deb + (a_fin - a_deb) * j / arc
            pts.append((cx + r_pied * math.cos(a), cy + r_pied * math.sin(a)))
    return pts


def contours(t):
    """Liste de (polygone, trou ou None) de l'emblème du type t, en unités des icônes."""
    cx, cy = GC
    if t == "speed":
        out = []
        for x0 in (cx - 7.0, cx + 6.5):
            out.append((_echelle(chevron_epais((x0 - 5.6, cy - 10.0), (x0 + 5.6, cy), (x0 - 5.6, cy + 10.0), 3.0)), None))
        return out
    if t == "productivity":
        trou = [(cx + 3.6 * math.cos(2 * math.pi * i / 32), cy + 3.6 * math.sin(2 * math.pi * i / 32)) for i in range(32)]
        return [(_echelle(engrenage(cx, cy, 8, 8.8, 12.6, 0.40, 0.60)), _echelle(trou))]
    ax, ay, bx, by = cx - 10.5, cy + 10.0, cx + 14.5, cy - 10.5
    L = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / L, (by - ay) / L
    nx, ny = -uy, ux
    us = [i / 40.0 for i in range(41)]
    haut = [(ax + ux * L * u + nx * 9.0 * math.sin(math.pi * u) ** 0.75 * (1.0 - 0.35 * u),
             ay + uy * L * u + ny * 9.0 * math.sin(math.pi * u) ** 0.75 * (1.0 - 0.35 * u)) for u in us]
    bas = [(ax + ux * L * u - nx * 5.0 * math.sin(math.pi * u), ay + uy * L * u - ny * 5.0 * math.sin(math.pi * u)) for u in reversed(us[1:-1])]
    tige = chevron_epais((ax - 5.0, ay + 4.0), (ax - 2.0, ay + 1.75), (ax + 1.0, ay - 0.5), 1.15)
    return [(_echelle(haut + bas), None), (_echelle(tige), None)]


# ------------------------------------------------------------------------------------------------------------------
# Matières
# ------------------------------------------------------------------------------------------------------------------
def principled(name, color, rough, metal, emis=None, emis_force=0.0, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = tuple(color) + (1.0,)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emis is not None:
        p.inputs["Emission Color"].default_value = tuple(emis) + (1.0,)
        p.inputs["Emission Strength"].default_value = emis_force
    if coat:
        p.inputs["Coat Weight"].default_value = coat
    return m


def peinture_usee(name, color):
    """Peinture du type : teinte qui varie (bruit), écaillée sur les arêtes vives (Pointiness de Cycles, bruitée) vers le métal nu,
    crasse dans les creux (occlusion ambiante)."""
    m = principled(name, color, 0.55, 0.25)
    nt = m.node_tree
    L = nt.links.new
    p = nt.nodes["Principled BSDF"]
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    bruit = nt.nodes.new("ShaderNodeTexNoise")
    bruit.inputs["Scale"].default_value = 40.0
    bruit.inputs["Detail"].default_value = 6.0
    # teinte : la peinture, plus sombre par plaques
    var = nt.nodes.new("ShaderNodeMix")
    var.data_type = "RGBA"
    var.inputs[6].default_value = tuple(color) + (1.0,)
    var.inputs[7].default_value = tuple(v * 0.78 for v in color) + (1.0,)
    fv = nt.nodes.new("ShaderNodeMapRange")
    fv.inputs["From Min"].default_value = 0.45
    fv.inputs["From Max"].default_value = 0.75
    L(bruit.outputs["Fac"], fv.inputs["Value"])
    L(fv.outputs["Result"], var.inputs[0])
    # usure : arêtes vives, seuil bruité
    som = nt.nodes.new("ShaderNodeMath")
    som.operation = "MULTIPLY_ADD"
    L(bruit.outputs["Fac"], som.inputs[0])
    som.inputs[1].default_value = 0.08
    L(geo.outputs["Pointiness"], som.inputs[2])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.54
    ramp.color_ramp.elements[1].position = 0.57
    L(som.outputs["Value"], ramp.inputs["Fac"])
    mix_c = nt.nodes.new("ShaderNodeMix")
    mix_c.data_type = "RGBA"
    L(var.outputs[2], mix_c.inputs[6])
    mix_c.inputs[7].default_value = (0.45, 0.45, 0.47, 1.0)
    L(ramp.outputs["Color"], mix_c.inputs[0])
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 2.5
    L(mix_c.outputs[2], ao.inputs["Color"])
    crasse = nt.nodes.new("ShaderNodeMix")
    crasse.data_type = "RGBA"
    crasse.blend_type = "MULTIPLY"
    crasse.inputs[0].default_value = 1.0
    L(mix_c.outputs[2], crasse.inputs[6])
    L(ao.outputs["AO"], crasse.inputs[7])
    L(crasse.outputs[2], p.inputs["Base Color"])
    mm = nt.nodes.new("ShaderNodeMapRange")
    L(ramp.outputs["Color"], mm.inputs["Value"])
    mm.inputs["To Min"].default_value = 0.25
    mm.inputs["To Max"].default_value = 0.95
    L(mm.outputs["Result"], p.inputs["Metallic"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    L(bruit.outputs["Fac"], mr.inputs["Value"])
    mr.inputs["To Min"].default_value = 0.40
    mr.inputs["To Max"].default_value = 0.72
    L(mr.outputs["Result"], p.inputs["Roughness"])
    return m


# ------------------------------------------------------------------------------------------------------------------
# Géométrie
# ------------------------------------------------------------------------------------------------------------------
def objet_de(bm, name, mats, parent):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    for m in mats:
        ob.data.materials.append(m)
    bpy.context.collection.objects.link(ob)
    ob.parent = parent
    return ob


def prisme(points, z0, z1, name, mats, parent, inset=None, trous=None):
    """Polygone (unités des icônes) extrudé de z0 à z1 ; `inset` : retrait du dessus (matière 1 = dessus en retrait)."""
    bm = bmesh.new()
    vs = [bm.verts.new((b(x, y)[0], b(x, y)[1], z0)) for x, y in points]
    f = bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=[f])
    if f.normal.z > 0:
        f.normal_flip()
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    top_v = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top_v, vec=(0, 0, z1 - z0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    tops = [fc for fc in bm.faces if fc.normal.z > 0.9 and fc.calc_center_median().z > z1 - 1e-4]
    for fc in bm.faces:
        fc.material_index = 0
    if inset is not None:
        ins = bmesh.ops.inset_region(bm, faces=tops, thickness=inset, depth=0.0)
        for fc in tops:
            fc.material_index = 1
        for fc in ins["faces"]:
            fc.material_index = 0
    ob = objet_de(bm, name, mats, parent)
    if trous:
        for tp in trous:
            cut = prisme(tp, z0 - 1.0, z1 + 1.0, name + "-trou", mats[:1], parent)
            mod = ob.modifiers.new("trou", "BOOLEAN")
            mod.operation = "DIFFERENCE"
            mod.object = cut
            cut.hide_render = True
    return ob


def chanfrein(x0, y0, x1, y1, c):
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def construire(t, k, parent):
    mk = marche(k)
    lum = LUMIERE[t]
    e = (k - 1) / 9.0
    peint = peinture_usee("peinture", tuple(v * 0.72 for v in PEINTURE[t]))
    g_col, g_rough = GARNITURE[mk]
    gar = principled("garniture", g_col, g_rough, 1.0)
    or_ = principled("or", GARNITURE[3][0], 0.22, 1.0)
    email = principled("email", tuple(v * 0.6 for v in lum), 0.15, 0.0, emis=lum, emis_force=0.12 + 0.30 * e, coat=0.6)
    # boîtier chanfreiné, arêtes arrondies (biseau) puis densifié pour l'usure (Pointiness)
    corps = prisme(chanfrein(*CORPS), 0.0, HZ, "boitier", [peint], parent)  # peinture : PEINTURE x 0,72 (vanilla plus sombre)
    bv = corps.modifiers.new("biseau", "BEVEL")
    bv.width = 0.9
    bv.segments = 3
    sd = corps.modifiers.new("dense", "SUBSURF")
    sd.subdivision_type = "SIMPLE"
    sd.levels = sd.render_levels = 2
    if mk == 4:   # X : coins d'or sur les chanfreins
        for (cx, cy), (dx, dy) in (((CORPS[0], CORPS[1]), (1, 1)), ((CORPS[2], CORPS[1]), (-1, 1)), ((CORPS[2], CORPS[3]), (-1, -1)),
                                   ((CORPS[0], CORPS[3]), (1, -1))):
            c = CORPS[4] + 4.5
            tri = [(cx + dx * 0.0, cy + dy * c), (cx + dx * c, cy + dy * 0.0), (cx + dx * (c + 2.0), cy + dy * 0.0),
                   (cx + dx * 0.0, cy + dy * (c + 2.0))]
            prisme(tri, HZ - 0.2, HZ + 0.5, "coin", [or_], parent)
    # contacts dorés sur la paroi avant (sud)
    for i in range(10):
        x = 15.0 + 4.0 * i
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(2.2, 0.5, 5.0), verts=bm.verts)
        bmesh.ops.translate(bm, vec=(b(x, 0)[0], b(0, CORPS[3])[1] - 0.2, 3.0), verts=bm.verts)
        objet_de(bm, "contact", [or_], parent)
    # voyants : bague (tore) et dôme ; allumés = ceil(k / 2), le dernier à demi aux paliers impairs
    n_on = (k + 1) // 2
    for i, lx in enumerate(LED_XS):
        x, y = b(lx, LED_Y)
        bpy.ops.mesh.primitive_torus_add(major_radius=LED_R + 0.5, minor_radius=0.55, location=(x, y, HZ + 0.15))
        tor = bpy.context.active_object
        tor.data.materials.append(gar)
        tor.parent = parent
        bpy.ops.mesh.primitive_uv_sphere_add(radius=LED_R, location=(x, y, HZ - 0.4), segments=32, ring_count=16)
        sph = bpy.context.active_object
        sph.scale = (1.0, 1.0, 0.75)
        bpy.ops.object.shade_smooth()
        if i < n_on:
            demi = 0.42 if (k % 2 == 1 and i == n_on - 1) else 1.0
            col = tuple(v * 0.8 + 0.12 for v in lum)
            mled = principled("led-on", tuple(v * 0.5 for v in lum), 0.08, 0.0, emis=lum, emis_force=(1.6 + 0.8 * e) * demi, coat=1.0)
        else:
            mled = principled("led-off", tuple(v * 0.04 + 0.004 for v in lum), 0.06, 0.0, coat=1.0)
        sph.data.materials.append(mled)
        sph.parent = parent
    # emblème : métal de la matière du palier (or au X), dessus en retrait émaillé
    mat_e = principled("embleme", GARNITURE[4][0], 0.16, 1.0) if mk == 4 else gar
    for poly, trou in contours(t):
        ob = prisme(poly, HZ - 0.3, HZ + HE, "embleme", [mat_e, email], parent, inset=0.9, trous=[trou] if trou else None)
        bv = ob.modifiers.new("biseau", "BEVEL")
        bv.width = 0.35
        bv.segments = 2
        bv.limit_method = "ANGLE"


def scene(samples, taille):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = taille
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.render.threads_mode = "FIXED"
    sc.render.threads = 8
    w = bpy.data.worlds.new("monde")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.36, 1.0)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.40
    sc.world = w
    # soleil du nord-ouest (même direction que icones.LUM : ouest, nord, haut)
    sun_d = bpy.data.lights.new("soleil", "SUN")
    sun_d.energy = 4.6
    sun_d.angle = math.radians(6.0)
    sun = bpy.data.objects.new("soleil", sun_d)
    sun.rotation_euler = Vector((-0.55, 0.75, 0.95)).to_track_quat("Z", "Y").to_euler()
    sc.collection.objects.link(sun)
    # sol qui ne garde que l'ombre
    bpy.ops.mesh.primitive_plane_add(size=300.0, location=(0, 0, 0))
    sol = bpy.context.active_object
    sol.is_shadow_catcher = True
    # caméra orthographique : 35° depuis la verticale, depuis le sud
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = 72.0
    cam = bpy.data.objects.new("cam", cam_d)
    a = math.radians(INCLIN)
    cam.location = (0.0, -200.0 * math.sin(a) + 3.0, 200.0 * math.cos(a))
    cam.rotation_euler = (a, 0.0, 0.0)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out, cas, samples, taille = None, "speed:5", 64, 512
    i = 0
    while i < len(argv):
        if argv[i] == "--out":
            out = argv[i + 1]
        elif argv[i] == "--cas":
            cas = argv[i + 1]
        elif argv[i] == "--samples":
            samples = int(argv[i + 1])
        elif argv[i] == "--taille":
            taille = int(argv[i + 1])
        i += 2
    assert out, "--out requis"
    os.makedirs(out, exist_ok=True)
    for c in cas.split(","):
        t, k = c.split(":")
        k = int(k)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        sc = scene(samples, taille)
        racine = bpy.data.objects.new("module", None)
        sc.collection.objects.link(racine)
        racine.rotation_euler = (0.0, 0.0, math.radians(ANGLE))
        construire(t, k, racine)
        sc.render.filepath = os.path.join(out, "3d-%s-%d.png" % (t, k))
        bpy.ops.render.render(write_still=True)
        print("[FO-MODULES-3D] %s" % sc.render.filepath)


main()
