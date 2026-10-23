"""Lot A3 (24/10) : MASQUES RAPIDES de la tête de la mitrailleuse dans les 64 directions (alpha seulement). Blender 5.2.2.

Lancé UNIQUEMENT par masques.py, par le verrou de rendu (interdit n° 6) :
    blender -b --factory-startup -noaudio --python-exit-code 1 -P masques_blender.py -- --ages 2,3 --out DIR
        [--samples 16] [--dirs 0-63]

Pour chaque âge, la tête est construite UNE fois, exactement comme batch_blender.py (piece.build : même géométrie, mêmes
graines), avec le bouchon arrière POSÉ (FO_BOUCHON=force) aux âges de piece.BOUCHON_AGES et rangé dans une matière à
lui (copie de « seam ») pour qu'il forme son propre objet. Puis, pour chaque direction dKK : rotation de pose écrite
sur les objets (kit.Geo.flush écrit rotation_euler.z = rotz : c'est la même opération que la production), cadrage
EXACT de la production (projected_bounds + marge de piece.margin_px, canevas pair, origine), et rendu de la passe
principale avec toutes les matières remplacées par une émission noire (le bouchon : émission blanche), sans rebond,
sans sol, à --samples échantillons. Sorties par pose (<out>/eNN/eNN-dKK.npz) :
  alpha     uint8, couverture de la tête (avec le bouchon s'il est posé) ;
  bouchon   uint8, couverture VISIBLE du bouchon (pixels où il est devant tout le reste) ; absent hors des âges 4 à 7 ;
  alpha_sans uint8, couverture SANS le bouchon (objet masqué au rendu) ; âges 4 à 7 seulement ;
  canvas, origin : canevas et origine (px hr) identiques à ceux de batch_blender.py pour la même pose.
Le contrôle des trous et la comparaison à la production sont faits hors Blender (masques.py).
"""
import argparse
import importlib.util
import json
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402

BOUCHON_MAT = "fo_masque_bouchon"


def projected_bounds(objs):
    """Copie exacte de batch_blender.projected_bounds (batch_blender.py lance main() à l'import : pas d'import)."""
    sv = C.sun_vector()
    us, vs = [], []
    for o in objs:
        if o.type != "MESH":
            continue
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            u, v = C.blender_to_screen_px(w.x, w.y, w.z)
            us.append(u)
            vs.append(v)
            if w.z > 0 and sv[2] > 1e-6:
                k = w.z / sv[2]
                u, v = C.blender_to_screen_px(w.x - sv[0] * k, w.y - sv[1] * k, 0.0)
                us.append(u)
                vs.append(v)
    return min(us), min(vs), max(us), max(vs)


def emission(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    em.inputs["Strength"].default_value = 1.0
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def lire(png):
    img = bpy.data.images.load(png, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return np.flipud(buf.reshape(h, w, 4))


def u8(x):
    return np.clip(np.rint(np.asarray(x, np.float64) * 255.0), 0, 255).astype(np.uint8)


def plage(spec):
    res = []
    for x in [x for x in spec.split(",") if x]:
        a, b = x.split("-") if "-" in x else (x, x)
        res += list(range(int(a), int(b) + 1))
    return res


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--ages", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--dirs", default="0-63")
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    spec = importlib.util.spec_from_file_location("gune_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    import corps
    orig_bouchon = corps.bouchon_arriere

    forme = os.environ.get("FO_BOUCHON_FORME", "").strip()

    def bouchon_a_part(g, c):
        """Même bouchon, rangé dans sa propre matière (copie de « seam ») : il devient un objet à lui. Avec la variable
        FO_BOUCHON_FORME, la forme est remplacée par corps.bouchon_forme(g, c, forme) (essais de D-10)."""
        M0 = g.M
        M1 = dict(M0)
        mb = bpy.data.materials.get(BOUCHON_MAT) or M0["seam"].copy()
        mb.name = BOUCHON_MAT
        M1["seam"] = mb
        g.M = M1
        try:
            if forme:
                corps.bouchon_forme(g, c, forme)
            else:
                orig_bouchon(g, c)
        finally:
            g.M = M0

    corps.bouchon_arriere = bouchon_a_part
    dirs = plage(a.dirs)
    def construire(name):
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        piece.build(S, C, name)
        bpy.context.view_layer.update()
        objs = [o for o in S.piece_objects() if o.type == "MESH"]
        noir = emission("fo_masque_noir", (0.0, 0.0, 0.0))
        blanc = emission("fo_masque_blanc", (1.0, 1.0, 1.0))
        bouchons = []
        for o in objs:
            est_b = any(sl.material is not None and sl.material.name == BOUCHON_MAT for sl in o.material_slots)
            if est_b:
                bouchons.append(o)
            for i in range(len(o.data.materials)):
                o.data.materials[i] = blanc if est_b else noir
        return objs, bouchons

    for e in plage(a.ages):
        t0 = time.time()
        avec_bouchon = e in piece.BOUCHON_AGES
        os.environ["FO_BOUCHON"] = "force" if avec_bouchon else "non"
        # âges du bouchon : la forme dépend de la direction (rampe de D-10, piece.bouchon_fraction) : la tête est
        # reconstruite pour CHAQUE direction (construction de production : rotation de pose comprise) ; ailleurs, une
        # construction, puis la rotation de pose écrite sur les objets (même opération que kit.Geo.flush)
        par_dir = avec_bouchon and not forme
        name = "e%02d-tete-d00" % e
        objs, bouchons = construire(name)
        scene = bpy.context.scene
        rot0 = {o.name: tuple(o.rotation_euler) for o in objs}
        t_build = time.time() - t0
        m = piece.margin_px(name)
        dossier = os.path.join(a.out, "e%02d" % e)
        os.makedirs(dossier, exist_ok=True)
        poses = []
        for K in dirs:
            d = "d%02d" % K
            rz = piece.DIRS[d]
            if par_dir:
                objs, bouchons = construire("e%02d-tete-%s" % (e, d))
                scene = bpy.context.scene
            else:
                for o in objs:
                    o.rotation_euler = (rot0[o.name][0], rot0[o.name][1], rz)
            bpy.context.view_layer.update()
            l, t, r, b = projected_bounds(objs)
            left, top = int(math.floor(l)) - m, int(math.floor(t)) - m
            right, bottom = int(math.ceil(r)) + m, int(math.ceil(b)) + m
            W, H = right - left, bottom - top
            W += W % 2
            H += H % 2
            ox, oy = -left, -top
            for ob in [x for x in scene.objects if x.type == "CAMERA"]:
                bpy.data.objects.remove(ob, do_unlink=True)
            S.setup_render(scene, W, H, samples=a.samples)
            cy = scene.cycles
            cy.max_bounces = cy.diffuse_bounces = cy.glossy_bounces = 0
            cy.transmission_bounces = cy.volume_bounces = 0
            cy.transparent_max_bounces = 8
            S.setup_camera(scene, W, H, center_px=(ox, oy))
            t1 = time.time()
            for o in bouchons:
                o.hide_render = False
            p = os.path.join(dossier, "_tmp-%s.png" % d)
            S.render_to(scene, p)
            img = lire(p)
            os.remove(p)
            res = {"alpha": u8(img[..., 3]), "canvas": np.array([W, H]), "origin": np.array([ox, oy])}
            if avec_bouchon:
                res["bouchon"] = u8(img[..., 0])
                for o in bouchons:
                    o.hide_render = True
                S.render_to(scene, p)
                img2 = lire(p)
                os.remove(p)
                res["alpha_sans"] = u8(img2[..., 3])
                for o in bouchons:
                    o.hide_render = False
            np.savez_compressed(os.path.join(dossier, "e%02d-%s.npz" % (e, d)), **res)
            poses.append({"dir": d, "canvas": [W, H], "origin": [ox, oy], "seconds": round(time.time() - t1, 3)})
        with open(os.path.join(dossier, "masques.json"), "w", encoding="utf-8") as f:
            json.dump({"epoch": e, "samples": a.samples, "bouchon_pose": avec_bouchon, "bouchons": len(bouchons),
                       "objects": len(objs), "seconds_build": round(t_build, 2),
                       "seconds": round(time.time() - t0, 2), "blender": bpy.app.version_string, "poses": poses},
                      f, indent=1)
        print("[FO-MASQUES] âge %d : %d poses en %.1f s (construction %.1f s ; bouchon %s, %d objet(s))" % (
            e, len(poses), time.time() - t0, t_build, avec_bouchon, len(bouchons)), flush=True)
    corps.bouchon_arriere = orig_bouchon


main()
