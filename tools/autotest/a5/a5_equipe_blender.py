"""Lot A5-ESSAI (25/10) : COUVERTURE VISIBLE de pièces choisies de la mitrailleuse (masque d'équipe). Blender 5.2.2.

Lancé UNIQUEMENT par a5_equipe.py, par le verrou de rendu (interdit n° 6) :
    blender -b --factory-startup -noaudio --python-exit-code 1 -P a5_equipe_blender.py -- --ages 3 --out DIR
        --groupes FICHIER.json [--samples 32] [--dirs 0-63] [--socle]

Même méthode que gun_e/masques_blender.py (masques rapides du lot A3, validés à 99,7 % contre la production) : la
tête est construite UNE fois par piece.build (même géométrie, mêmes graines ; aucune image de base n'est rendue ni
changée), puis pour chaque direction dKK la rotation de pose est écrite sur les objets (même opération que
kit.Geo.flush) et le cadrage est celui de la production (projected_bounds + marge, canevas pair, origine).
Ajout de ce lot : chaque face porte l'ÉTIQUETTE de la pièce qui l'a produite (argument « what » de kit.Geo._add :
« liseré », « cerclage », « voyant »…), relevée par un enrobage de kit.Geo._add et kit.Geo.flush qui ne touche pas à la
géométrie. Pour chaque GROUPE d'étiquettes (fichier --groupes : {"nom": ["étiquette", …]}), toutes les matières sont
une émission noire, sauf les faces du groupe (émission blanche) ; sans rebond, sans sol. Le rouge rendu est donc la
couverture VISIBLE du groupe (devant tout le reste), l'alpha la silhouette.
Sorties par pose (<out>/eNN/eNN-dKK.npz ; --socle : <out>/eNN/eNN-socle.npz) :
  alpha    uint8, silhouette (toutes les pièces) ;
  g_<nom>  uint8, couverture visible du groupe, PRÉMULTIPLIÉE (part du pixel couverte par le groupe) ;
  canvas, origin : identiques à ceux de batch_blender.py pour la même pose.
<out>/eNN/equipe.json : étiquettes trouvées (faces par étiquette), écarts de comptage, durées.
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
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
RENDER = os.path.join(MOD, "tools", "render")
GUN = os.path.join(RENDER, "pieces", "levels", "gun_e")
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(os.path.dirname(GUN), "commun"))
sys.path.insert(0, GUN)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402
import kit  # noqa: E402

TAGS = {}           # étiquette -> numéro (1…)
TAGMAP = {}         # nom d'objet -> np.array des numéros d'étiquette par face
ECARTS = []         # objets dont le nombre de faces a changé (validate) : étiquettes inutilisables


def tag_id(w):
    if w not in TAGS:
        TAGS[w] = len(TAGS) + 1
    return TAGS[w]


_orig_add = kit.Geo._add
_orig_flush = kit.Geo.flush


def _add(self, mat, style, verts, faces, what="part"):
    T = self.__dict__.setdefault("_a5_tags", {}).setdefault((mat, style), [])
    T.extend([tag_id(what)] * len(faces))
    return _orig_add(self, mat, style, verts, faces, what)


def _flush(self):
    tags = self.__dict__.pop("_a5_tags", {})
    keys = [k for k, (V, F) in sorted(self.data.items(), key=lambda kv: (kv[0][0].name, kv[0][1])) if F]
    objs = _orig_flush(self)
    if len(objs) != len(keys):
        raise RuntimeError("flush : %d objets pour %d clés" % (len(objs), len(keys)))
    for o, k in zip(objs, keys):
        t = np.array(tags.get(k, []), np.int32)
        n = len(o.data.polygons)
        if n != len(t):
            ECARTS.append({"objet": o.name, "faces": n, "etiquettes": int(len(t))})
            t = np.zeros(n, np.int32)
        TAGMAP[o.name] = t
    return objs


kit.Geo._add = _add
kit.Geo.flush = _flush


def projected_bounds(objs):
    """Copie exacte de batch_blender.projected_bounds."""
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
    ap.add_argument("--groupes", required=True)
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--dirs", default="0-63")
    ap.add_argument("--socle", action="store_true")
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    groupes = json.load(open(a.groupes, encoding="utf-8"))
    spec = importlib.util.spec_from_file_location("gune_piece", os.path.join(GUN, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    # jamais de bouchon (âges 4 à 7 seulement ; ce lot vise 3, 9 et 15) : le mode de production est gardé
    os.environ.pop("FO_BOUCHON", None)

    def construire(name):
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        TAGMAP.clear()
        info = piece.build(S, C, name)
        bpy.context.view_layer.update()
        objs = [o for o in S.piece_objects() if o.type == "MESH"]
        noir = emission("fo_a5_noir", (0.0, 0.0, 0.0))
        blanc = emission("fo_a5_blanc", (1.0, 1.0, 1.0))
        for o in objs:
            o.data.materials.clear()
            o.data.materials.append(noir)
            o.data.materials.append(blanc)
            o.data.polygons.foreach_set("material_index", np.zeros(len(o.data.polygons), np.int32))
        return objs, info

    def choisir(objs, ids):
        for o in objs:
            t = TAGMAP.get(o.name)
            n = len(o.data.polygons)
            mi = np.zeros(n, np.int32) if t is None else np.isin(t, ids).astype(np.int32)
            o.data.polygons.foreach_set("material_index", mi)
            o.data.update()

    for e in plage(a.ages):
        t0 = time.time()
        if e in piece.BOUCHON_AGES:
            raise SystemExit("âge %d : âge du bouchon, non traité par cet essai" % e)
        name = "e%02d-socle" % e if a.socle else "e%02d-tete-d00" % e
        objs, info = construire(name)
        scene = bpy.context.scene
        rot0 = {o.name: tuple(o.rotation_euler) for o in objs}
        faces_par_tag = {}
        for o in objs:
            t = TAGMAP.get(o.name)
            if t is None:
                continue
            for k, c in zip(*np.unique(t, return_counts=True)):
                faces_par_tag[int(k)] = faces_par_tag.get(int(k), 0) + int(c)
        inv = {v: k for k, v in TAGS.items()}
        ids_groupes = {g: [TAGS[t] for t in ts if t in TAGS] for g, ts in groupes.items()}
        t_build = time.time() - t0
        m = piece.margin_px(name)
        dossier = os.path.join(a.out, "e%02d" % e)
        os.makedirs(dossier, exist_ok=True)
        poses = []
        for K in ([None] if a.socle else plage(a.dirs)):
            if K is not None:
                d = "d%02d" % K
                rz = piece.DIRS[d]
                for o in objs:
                    o.rotation_euler = (rot0[o.name][0], rot0[o.name][1], rz)
            else:
                d = "socle"
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
            res = {"canvas": np.array([W, H]), "origin": np.array([ox, oy])}
            p = os.path.join(dossier, "_tmp-%s.png" % d)
            for g in sorted(groupes):
                choisir(objs, ids_groupes[g])
                S.render_to(scene, p)
                img = lire(p)
                os.remove(p)
                res["alpha"] = u8(img[..., 3])
                # PNG à alpha DROIT : la couverture du groupe est rouge × alpha
                res["g_" + g] = u8(img[..., 0] * img[..., 3])
            np.savez_compressed(os.path.join(dossier, "e%02d-%s.npz" % (e, d)), **res)
            poses.append({"dir": d, "canvas": [W, H], "origin": [ox, oy], "seconds": round(time.time() - t1, 3)})
        with open(os.path.join(dossier, "equipe%s.json" % ("-socle" if a.socle else "")), "w", encoding="utf-8") as f:
            json.dump({"epoch": e, "part": "socle" if a.socle else "tete", "samples": a.samples,
                       "groupes": groupes, "etiquettes_absentes": {g: [t for t in ts if t not in TAGS]
                                                                   for g, ts in groupes.items()},
                       "faces_par_etiquette": {inv[k]: v for k, v in sorted(faces_par_tag.items())},
                       "count_build": info["count"], "ecarts_faces": list(ECARTS),
                       "objects": len(objs), "seconds_build": round(t_build, 2),
                       "seconds": round(time.time() - t0, 2), "blender": bpy.app.version_string, "poses": poses},
                      f, indent=1, ensure_ascii=False)
        print("[FO-A5] âge %d (%s) : %d pose(s) × %d groupe(s) en %.1f s (construction %.1f s ; %d écart(s) de faces)" % (
            e, "socle" if a.socle else "tête", len(poses), len(groupes), time.time() - t0, t_build, len(ECARTS)),
            flush=True)
        ECARTS.clear()


main()
