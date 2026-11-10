"""TÊTES TOURNANTES des tourelles à munitions (lot POLISSAGE-3, 10/11) dans UNE session Blender par appel : pour chaque tourelle de
piece.TETES, la tête (module.tete, une maille par image) est posée UNE fois, enfant d'un vide de rotation lui-même enfant d'un vide
d'échelle (1, D, 1) : direction k -> rotation -2πk/64 autour de z (sens horaire vu de dessus, nord = direction 0, comme les
RotatedAnimation), puis l'étirement des emprises (tourelle_tete.py). Toile COMMUNE aux 64 directions et aux images (union des
silhouettes projetées et de leurs ombres), même origine que le socle (pied de l'entité) : toutes les images ont la même taille et le
même décalage, comme l'exige une feuille d'animation.
Passes par image : main (débruitée), lueur, ombre ; sorties <out>/<nom>-tete/<nom>-dKK-iI.npz (octets) et tete.json. TOUJOURS par le
verrou de rendu (lancé par rendre_tetes.py). Dossier de travail propre au processus (leçon de KAIJUS-MUTANTS).
"""
import argparse
import importlib
import importlib.util
import json
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


def lire_png(path):
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return np.flipud(buf.reshape(h, w, 4))


def bornes(V, n, D):
    """Union, sur les n directions, des boîtes écran (px HR) de la tête et de son ombre au sol. V : sommets (N, 3) du repère monde."""
    sv = C.sun_vector()
    us0 = vs0 = 1e9
    us1 = vs1 = -1e9
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    for k in range(n):
        t = 2.0 * math.pi * k / n
        c, s = math.cos(t), math.sin(t)
        xr = x * c + y * s
        yr = (-x * s + y * c) * D
        u = xr * C.PX_PER_UNIT_HR
        v = -(yr * C.COS_T + z * C.SIN_T) * C.PX_PER_UNIT_HR
        kk = np.maximum(z, 0.0) / sv[2]
        us = (xr - sv[0] * kk) * C.PX_PER_UNIT_HR
        vs = -((yr - sv[1] * kk) * C.COS_T) * C.PX_PER_UNIT_HR
        us0 = min(us0, u.min(), us.min())
        us1 = max(us1, u.max(), us.max())
        vs0 = min(vs0, v.min(), vs.min())
        vs1 = max(vs1, v.max(), vs.max())
    return us0, vs0, us1, vs1


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=32, help="passe principale (débruitée)")
    ap.add_argument("--samples-glow", type=int, default=16)
    ap.add_argument("--samples-shadow", type=int, default=8)
    ap.add_argument("--dirs", default="", help="directions à rendre (défaut : toutes) ; une vue déjà rendue est sautée")
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    spec = importlib.util.spec_from_file_location("bat_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for kk, v in piece.PIECE.get("calib", {}).items():
        setattr(C, kk, v)
    import geo as G
    import organes as O
    import titans_mat as TM
    nd = piece.DIRECTIONS
    for name in [n for n in a.names.split(",") if n]:
        if name not in piece.TETES:
            raise SystemExit("[FO-TETES] %s n'est pas une tête tournante (piece.TETES)" % name)
        t0 = time.time()
        mod = importlib.import_module(piece.BATIMENTS[name][3])
        nimg = int(mod.IMAGES)
        d = os.path.join(a.out, name + "-tete")
        os.makedirs(d, exist_ok=True)
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        scene = bpy.context.scene
        M = TM.matieres(S, "bt_" + name + "_")
        M.update(noir=M["struct"], acier=M["canon"], acier_clair=M["os"], riv=M["os"], grille=M["struct"])
        import marques as MQ
        MQ.matiere(S, M, "bt_" + name + "_", name)      # lot VISUELS-DISTINCTS : liseré et motif de toit de fonction
        jeux, anc = [], None
        for img in range(nimg):
            lot = G.Lot(S, "tete_%s_%d" % (name, img))
            kit = O.Kit(lot, M, seed=sum(ord(c) for c in name) + img)
            r = mod.tete(kit, M, img)
            anc = anc or r
            objs = lot.flush()
            TM.sans_ombre(objs)
            jeux.append(objs)
        bpy.context.view_layer.update()
        V = []
        for objs in jeux:
            for o in objs:
                m = np.empty(len(o.data.vertices) * 3, dtype=np.float64)
                o.data.vertices.foreach_get("co", m)
                V.append(m.reshape(-1, 3))
        V = np.concatenate(V, 0)
        l, t, rr, b = bornes(V, nd, O.D)
        marge = 12
        left, top = int(math.floor(l)) - marge, int(math.floor(t)) - marge
        right, bottom = int(math.ceil(rr)) + marge, int(math.ceil(b)) + marge
        W, H = right - left, bottom - top
        W += W % 2
        H += H % 2
        ox, oy = -left, -top
        es = bpy.data.objects.new("tete_echelle", None)
        er = bpy.data.objects.new("tete_rotation", None)
        scene.collection.objects.link(es)
        scene.collection.objects.link(er)
        es.scale = (1.0, O.D, 1.0)
        er.parent = es
        for objs in jeux:
            for o in objs:
                o.parent = er
        S.setup_render(scene, W, H, samples=a.samples)
        S.setup_camera(scene, W, H, center_px=(ox, oy))
        S.setup_world(scene)
        sun = S.add_sun(scene)
        S.add_fill(scene)
        ground = S.add_ground(scene)
        cy = scene.cycles
        _rt = S.render_to
        par = {"glow": a.samples_glow, "shadow": a.samples_shadow}

        def rt(sc, path):
            passe = os.path.basename(path)[:-4].rsplit("-", 1)[-1]
            avant, den = sc.cycles.samples, sc.cycles.use_denoising
            if passe in par:
                sc.cycles.samples = par[passe]
                sc.cycles.use_denoising = False
            else:
                sc.cycles.use_denoising = True
                sc.cycles.denoiser = "OPENIMAGEDENOISE"
                sc.cycles.denoising_input_passes = "RGB_ALBEDO_NORMAL"
            try:
                return _rt(sc, path)
            finally:
                sc.cycles.samples, sc.cycles.use_denoising = avant, den
        S.render_to = rt
        tmp = os.path.join(d, "_tmp-%d" % os.getpid())
        os.makedirs(tmp, exist_ok=True)
        dirs = [int(x) for x in a.dirs.split(",") if x] if a.dirs else list(range(nd))
        rendues = 0
        for k in dirs:
            er.rotation_euler = (0.0, 0.0, -2.0 * math.pi * k / nd)
            bpy.context.view_layer.update()
            for img in range(nimg):
                f = os.path.join(d, "%s-d%02d-i%d.npz" % (name, k, img))
                if os.path.exists(f):
                    continue
                t1 = time.time()
                for j, objs in enumerate(jeux):
                    for o in objs:
                        o.hide_render = (j != img)
                res = S.render_passes(scene, tmp, "f", ["main", "glow", "shadow"], sun, ground)
                main = lire_png(res["main"])
                glow = lire_png(res["glow"]) if "glow" in res else np.zeros_like(main)
                om = lire_png(res["shadow"])[..., 3]
                u8 = lambda x: np.round(np.clip(x, 0, 1) * 255).astype(np.uint8)
                np.savez_compressed(f, main=u8(main), glow=u8(glow), ombre=u8(om))
                rendues += 1
                print("[FO-RENDER] %s dir %d image %d %.1fs" % (name, k, img, time.time() - t1), flush=True)
        S.render_to = _rt
        for x in os.listdir(tmp):
            os.remove(os.path.join(tmp, x))
        os.rmdir(tmp)
        info = {"variant": name, "canvas": [W, H], "origin_px": [ox, oy], "directions": nd, "images": nimg,
                "bouche": [round(v, 5) for v in anc["bouche"]], "samples": a.samples, "samples_glow": a.samples_glow,
                "samples_shadow": a.samples_shadow, "seed": scene.cycles.seed, "blender": bpy.app.version_string,
                "verts": int(V.shape[0]), "seconds": round(time.time() - t0, 1), "rendues": rendues}
        if os.path.exists(os.path.join(d, "tete.json")):
            old = json.load(open(os.path.join(d, "tete.json"), encoding="utf-8"))
            if old.get("canvas") != info["canvas"] or old.get("origin_px") != info["origin_px"]:
                raise SystemExit("[FO-TETES] %s : toile changée depuis le rendu précédent (effacer %s)" % (name, d))
            info["seconds"] = round(info["seconds"] + old.get("seconds", 0.0), 1)
        with open(os.path.join(d, "tete.json"), "w", encoding="utf-8") as fh:
            json.dump(info, fh, indent=1, sort_keys=True)
        print("[FO-RENDER] %s tete %dx%d %d sommets, %d vues rendues, %.0fs" % (name, W, H, V.shape[0], rendues, time.time() - t0), flush=True)


main()
