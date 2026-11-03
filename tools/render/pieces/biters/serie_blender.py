"""Une image de la série d'une souche, dans les 16 directions (lot BI-V1). Le maillage est fait une fois : seules les directions changent.
TOUJOURS par produire.py, qui passe par le verrou de rendu.
    blender -b --factory-startup -noaudio -P serie_blender.py -- --souche moucheron --anim course --image 2 --out <dossier> [--samples 32] [--dirs 0,1]
Sortie : <out>/<souche>-<anim>-<image>-<direction>.npz : main et ao (RGBA 8 bits ; le liseré de contact est composé par feuilles.py), ombre, masque (alpha 8 bits). Reprenable.
"""
import argparse
import math
import os
import sys
import time

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402
import anatomie  # noqa: E402
import sdf  # noqa: E402

PARTS = {"main": None, "ao": 4, "shadow": 8, "poids": 1}


def lire_png(path):
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return np.flipud(buf.reshape(h, w, 4))


def matiere_poids():
    """Passe du masque : la part de plaque teintable, en émission pure."""
    m = bpy.data.materials.new("fo_poids")
    m.use_nodes = True
    n, l = m.node_tree.nodes, m.node_tree.links
    n.remove(n["Principled BSDF"])
    a = n.new("ShaderNodeAttribute")
    a.attribute_name = "poids"
    e = n.new("ShaderNodeEmission")
    e.inputs["Strength"].default_value = 1.0
    l.new(a.outputs[0], e.inputs["Color"])
    l.new(e.outputs[0], n["Material Output"].inputs["Surface"])
    return m


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--souche", required=True)
    ap.add_argument("--anim", required=True)
    ap.add_argument("--image", type=int, required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--dirs", default="")
    a = ap.parse_args(argv)
    import importlib
    import blender_scene as B  # noqa: F401  (outils de maillage et de matière partagés avec rendu_blender)
    mod = importlib.import_module(a.souche)
    se = mod.SERIE
    nb = se[a.anim]
    t0 = time.time()
    dirs = [int(x) for x in a.dirs.split(",") if x] or list(range(16))
    nom_de = lambda k: os.path.join(a.out, "%s-%s-%02d-%02d.npz" % (a.souche, a.anim, a.image, k))
    dirs = [k for k in dirs if not os.path.exists(nom_de(k))]
    if not dirs:
        print("[FO-BITER] rien a faire", a.souche, a.anim, a.image, flush=True)
        return
    os.makedirs(a.out, exist_ok=True)
    C.PX_PER_UNIT_HR = se["densite"]
    C.AO_DISTANCE = mod.AO
    S.reset()
    S.HALO_LIGHTS.clear()
    S.EXTRA_LIGHTS.clear()
    S._BLACK = S._WHITE = S._AO = None
    S._BOOSTED.clear()
    scene = bpy.context.scene
    u = a.image / float(nb)
    forme = mod.construire(u) if a.anim == "course" else mod.construire(0.0, attaque=u)
    V, Q, _nb = sdf.extraire(forme)
    N = sdf.normales(forme, V, forme.voxel * 0.8)
    coul, att, q = anatomie.peindre(forme, V, N, mod.PALETTES, mod.CREUX)
    poids = forme.attributs(V, forme.selection(V, forme.voxel * 6.0))[0]
    noms = [g[0] for g in forme.groupes]
    w = sum(poids[:, noms.index(x)] for x in mod.MASQUE)
    m = B.maillage(a.souche, V, Q, N)
    B.attr_coul(m, "coul", coul)
    B.attr_vec(m, "mat", att)
    B.attr_vec(m, "q", q)
    B.attr_coul(m, "poids", np.stack([w, w, w], axis=1).astype(np.float32))
    mat = B.matiere_peinte(mod.CREUX / 0.05)
    ob = bpy.data.objects.new(a.souche, m)
    scene.collection.objects.link(ob)
    S._adopt(ob, mat, a.souche)
    t_mesh = time.time() - t0
    D = se["densite"]
    R, zmax = se["R"], se["zmax"]
    ox = int(math.ceil(R * D)) + 8
    oy = int(math.ceil((R * C.COS_T + zmax * C.SIN_T) * D)) + 8
    W = ox + int(math.ceil((R + zmax * 0.95) * D)) + 8
    H = oy + int(math.ceil((R * C.COS_T) * D)) + 8
    W += W % 2
    H += H % 2
    S.setup_render(scene, W, H, samples=a.samples)
    cy = scene.cycles
    cy.use_denoising = True
    cy.denoiser = "OPENIMAGEDENOISE"
    cy.denoising_input_passes = "RGB_ALBEDO_NORMAL"
    cy.denoising_prefilter = "ACCURATE"
    S.setup_camera(scene, W, H, center_px=(ox, oy))
    S.setup_world(scene)
    sun = S.add_sun(scene)
    S.add_fill(scene)
    ground = S.add_ground(scene)
    reflet = getattr(mod, "REFLET", 0.0)
    if reflet:
        B.boite_reflet(scene, reflet)
    m_poids = matiere_poids()
    _rt = S.render_to

    def rt(sc, path):
        ech = PARTS.get(os.path.basename(path)[:-4].rsplit("-", 1)[-1])
        avant = sc.cycles.samples
        if ech:
            sc.cycles.samples = ech
        try:
            return _rt(sc, path)
        finally:
            sc.cycles.samples = avant

    S.render_to = rt
    tmp = os.path.join(a.out, "_tmp-%s-%s-%02d" % (a.souche, a.anim, a.image))
    os.makedirs(tmp, exist_ok=True)
    for k in dirs:
        cap = k * 22.5
        ob.rotation_euler = (0.0, 0.0, math.atan2(math.cos(math.radians(cap)), math.sin(math.radians(cap))))
        bpy.context.view_layer.update()
        res = S.render_passes(scene, tmp, "f", ["main", "ao", "shadow"], sun, ground)
        main = lire_png(res["main"])
        ao = lire_png(res["ao"])
        ombre = lire_png(res["shadow"])[..., 3]
        # passe du masque : émission du poids, ni soleil ni débruitage
        ob.data.materials[0] = m_poids
        cy.use_denoising = False
        pp = os.path.join(tmp, "f-poids.png")
        S.render_to(scene, pp)
        pz = lire_png(pp)
        cy.use_denoising = True
        ob.data.materials[0] = mat
        masque = np.clip((pz[..., 0] + 0.055) / 1.055, 0.0, 1.0) ** 2.4 * pz[..., 3]     # couleur écrite en sRGB
        np.savez_compressed(nom_de(k), main=np.round(np.clip(main, 0, 1) * 255).astype(np.uint8), ao=np.round(np.clip(ao, 0, 1) * 255).astype(np.uint8),
                            ombre=np.round(np.clip(ombre, 0, 1) * 255).astype(np.uint8),
                            masque=np.round(np.clip(masque, 0, 1) * 255).astype(np.uint8), origine=np.array([ox, oy]), densite=np.array([D]))
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    print("[FO-BITER] %s %s %d : %d dir, %dx%d, %d sommets, maillage %.0fs, total %.0fs" % (a.souche, a.anim, a.image, len(dirs), W, H, len(V), t_mesh, time.time() - t0), flush=True)


main()
