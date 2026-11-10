"""Rendu Blender des TITANS (lot TITANS, 9/11), dans UNE session Blender, TOUJOURS par le verrou de rendu (rendre_titans.py).

    blender -b --factory-startup -noaudio -P batch_titans.py -- --what juggernaut --stages 1,2,3 --out DIR [--samples 48] [--px 40]
    blender -b --factory-startup -noaudio -P batch_titans.py -- --what kaiju --anim course --images 0,1,... --dirs 0..7 --out DIR [--samples 32]

Alliés : Juggernaut, Sentinelle, Léviathan (1 direction, comme les géants : batch_blender.py ; --what <allié> --stages 1,2,3[,drone]) : passes main, lueur PAR GROUPE (conduits, cristal), ombre réduite ;
sortie <out>/juggernaut-<stage>/{juggernaut-<stage>-main.npy, -shadow.npy, -glow_<g>.npy, render.json} (format de rendre.post).
Kaiju (8 directions × images, comme serie_blender.py des souches) : le maillage d'une image est fait une fois, tourné 8 fois ;
passes main (débruitée), ao, shadow, glow (émissifs en BLANC : la teinte d'ère vient du prototype) ;
sortie <out>/kaiju/kaiju-<anim>-<image>-<dir>.npz (main, ao, ombre, glow, origine, densite). Reprenable : ce qui existe n'est pas refait.
--glb : exporte la géométrie en .glb (tools/render/pieces/titans/export/).
Déterminisme : graine fixe (fo_calib.SEED), Cycles CPU, 8 fils, échantillons fixes ; débruitage OIDN (comme les souches).
"""
import argparse
import json
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "pieces", "experimentaux"))
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402
import geo as G  # noqa: E402
import titans_mat as TM  # noqa: E402

ALLIES = ("juggernaut", "sentinelle", "leviathan")


def groupes(prefix):
    """Groupes de lueur d'un allié (fondus en une couche par feuilles_xp.geant) : conduits + cœurs + halos + anneaux + accents ; cristal."""
    return {"conduits": tuple(prefix + x for x in ("conduit", "coeur", "halo", "anneau", "accent")), "cristal": (prefix + "cristal",)}
EXPORT = os.path.join(HERE, "export")


def projected_bounds(objs):
    sv = C.sun_vector()
    us, vs, su, sv2 = [], [], [], []
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
                su.append(u)
                sv2.append(v)
    return (min(us + su), min(vs + sv2), max(us + su), max(vs + sv2)), (min(us), min(vs), max(us), max(vs))


def lire_png(path):
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return np.flipud(buf.reshape(h, w, 4))


def scene_neuve():
    S.reset()
    S.HALO_LIGHTS.clear()
    S.EXTRA_LIGHTS.clear()
    S._BLACK = S._WHITE = S._AO = None
    S._BOOSTED.clear()
    _BLANCS.clear()  # les matières de la scène précédente n'existent plus (read_factory_settings)
    return bpy.context.scene


_BLANCS = {}


def _blanc_de(mat):
    """Copie d'un émissif dont la couleur d'émission est BLANCHE (même force) : passe de lueur teintable par le prototype."""
    b = _BLANCS.get(mat.name)
    if b is None:
        b = mat.copy()
        b.name = mat.name + "_blanc"
        b.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (1.0, 1.0, 1.0, 1.0)
        _BLANCS[mat.name] = b
    return b


def passe_lueur(scene, objs, sun, ground, world, path, samples, fn):
    """Passe additive : matières choisies par fn(mat) (émissif ou noir), ciel et soleil coupés, sol caché."""
    bg = world.node_tree.nodes["Background"]
    sky = bg.inputs["Strength"].default_value
    sun.hide_render = True
    for x in S.EXTRA_LIGHTS:
        x.hide_render = True
    bg.inputs["Strength"].default_value = 0.0
    S._sync_sky(world)
    ground.visible_camera = False
    ground.is_shadow_catcher = False
    for o in objs:
        o.visible_camera = True
    avant = scene.cycles.samples
    scene.cycles.samples = samples
    den = scene.cycles.use_denoising
    scene.cycles.use_denoising = False
    saved = S._swap_materials(objs, fn)
    S.render_to(scene, path)
    S._restore(saved)
    scene.cycles.use_denoising = den
    scene.cycles.samples = avant
    bg.inputs["Strength"].default_value = sky
    S._sync_sky(world)
    sun.hide_render = False


def export_glb(nom):
    os.makedirs(EXPORT, exist_ok=True)
    p = os.path.join(EXPORT, nom + ".glb")
    try:
        bpy.ops.export_scene.gltf(filepath=p, export_format="GLB", use_selection=False, export_apply=True, export_yup=True)
        print("[FO-TITAN] export", p, os.path.getsize(p), "octets", flush=True)
    except Exception as e:  # l'export n'est pas une passe de rendu : on le dit, on continue
        print("[FO-TITAN] export .glb impossible :", e, flush=True)


# ------------------------------------------------------------------------------------------------ alliés (1 direction, stades)
def allie(a):
    """Juggernaut, Sentinelle, Léviathan : module du même nom, `build(S, lot, stage)`, PREFIX des matières ; stades `--stages`
    (entiers, ou « drone » pour l'escorte du Léviathan : build(S, lot, "drone"))."""
    MOD = __import__(a.what)
    C.PX_PER_UNIT_HR = a.px
    C.LIGHT_HOLDOUT = True
    C.SKY_GLOSSY_FACTOR = TM.SKY_GLOSSY
    stages = [x for x in a.stages.split(",") if x]
    for st in stages:
        stage = int(st) if st.isdigit() else st
        name = "%s-%s" % (a.what, st)
        d = os.path.join(a.out, name)
        if os.path.exists(os.path.join(d, "render.json")):
            print("[FO-TITAN] %s deja rendu" % name, flush=True)
            continue
        t0 = time.time()
        scene = scene_neuve()
        lot = G.Lot(S, "%s%s_" % (MOD.PREFIX[:2], st))
        info_build = MOD.build(S, lot, stage)
        n_pieces = lot.n
        TM.sans_ombre(lot.flush())
        t_build = time.time() - t0
        bpy.context.view_layer.update()
        if a.glb and st == stages[-1]:
            export_glb(a.what)
        objs = S.piece_objects()
        nverts = sum(len(o.data.vertices) for o in objs if o.type == "MESH")
        (l, t, r, b), corps = projected_bounds(objs)
        m = int(a.px)
        left, top = int(math.floor(l)) - m, int(math.floor(t)) - m
        right, bottom = int(math.ceil(r)) + m, int(math.ceil(b)) + m
        W, H = right - left, bottom - top
        W += W % 2
        H += H % 2
        ox, oy = -left, -top
        S.setup_render(scene, W, H, samples=a.samples)
        cy = scene.cycles
        cy.use_denoising = True
        cy.denoiser = "OPENIMAGEDENOISE"
        cy.denoising_input_passes = "RGB_ALBEDO_NORMAL"
        cy.denoising_prefilter = "ACCURATE"
        cam = S.setup_camera(scene, W, H, center_px=(ox, oy))
        kk = 320.0 / 60.0
        cam.location = (cam.location[0], cam.location[1] * kk, cam.location[2] * kk)
        cam.data.clip_end = 900.0
        S.setup_world(scene)
        sun = S.add_sun(scene)
        S.add_fill(scene)
        ground = S.add_ground(scene, size=400.0)
        os.makedirs(d, exist_ok=True)
        rd = scene.render
        rd.use_border = True
        rd.use_crop_to_border = False
        rd.border_min_x = max(0.0, (corps[0] - left - m) / float(W))
        rd.border_max_x = min(1.0, (corps[2] - left + m) / float(W))
        rd.border_min_y = max(0.0, 1.0 - (corps[3] - top + m) / float(H))
        rd.border_max_y = min(1.0, 1.0 - (corps[1] - top - m) / float(H))
        t1 = time.time()
        res = S.render_passes(scene, d, name, ["main"], sun, ground)
        print("[FO-TITAN] %s main %dx%d %.1fs" % (name, W, H, time.time() - t1), flush=True)
        world = scene.world
        for g, noms in groupes(MOD.PREFIX).items():
            def fn(mat, noms=noms):
                if mat is not None and mat.get("fo_kind") == "emissive" and any(mat.name.startswith(x) for x in noms):
                    return mat
                return S._black_mat()
            p = os.path.join(d, "%s-glow_%s.png" % (name, g))
            t2 = time.time()
            passe_lueur(scene, objs, sun, ground, world, p, a.lueur_spp, fn)
            res["glow_" + g] = p
            print("[FO-TITAN] %s glow_%s %.1fs" % (name, g, time.time() - t2), flush=True)
        # ombre : résolution et échantillons réduits (elle couvre dix fois le corps)
        rd.use_border = False
        cy.samples = a.ombre_spp
        cy.use_denoising = False
        rd.resolution_percentage = a.ombre_pct
        ground.is_shadow_catcher = True
        ground.visible_camera = True
        sun.hide_render = False
        for o in objs:
            o.visible_camera = False
        p = os.path.join(d, "%s-shadow.png" % name)
        t2 = time.time()
        S.render_to(scene, p)
        res["shadow"] = p
        rd.resolution_percentage = 100
        print("[FO-TITAN] %s shadow %.1fs" % (name, time.time() - t2), flush=True)
        for k, path in res.items():
            np.save(path[:-4] + ".npy", lire_png(path))
            os.remove(path)
        info = {"variant": name, "canvas": [W, H], "origin_px": [ox, oy], "layers": sorted(res), "px": a.px, "ombre_pct": a.ombre_pct,
                "samples": a.samples, "blender": bpy.app.version_string, "seconds": round(time.time() - t0, 2), "seconds_build": round(t_build, 2),
                "verts": nverts, "objects": len(objs), "pieces": n_pieces, "count": info_build}
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-TITAN] %s %dx%d %d sommets, %d pieces, build %.1fs, total %.1fs" % (name, W, H, nverts, n_pieces, t_build, time.time() - t0), flush=True)


# ------------------------------------------------------------------------------------------------ Kaiju
def kaiju(a):
    import kaiju as KA
    se = KA.SERIE
    D = float(se["densite"])
    C.PX_PER_UNIT_HR = D
    C.AO_DISTANCE = KA.AO
    C.SKY_GLOSSY_FACTOR = TM.SKY_GLOSSY
    nb = se[a.anim]
    d = os.path.join(a.out, "kaiju")
    os.makedirs(d, exist_ok=True)
    dirs_all = [int(x) for x in a.dirs.split(",") if x] or list(range(8))
    images = [int(x) for x in a.images.split(",") if x] or list(range(nb))
    for i in images:
        nom_de = lambda k: os.path.join(d, "kaiju-%s-%02d-%02d.npz" % (a.anim, i, k))
        dirs = [k for k in dirs_all if not os.path.exists(nom_de(k))]
        if not dirs:
            print("[FO-TITAN] kaiju %s %d : rien a faire" % (a.anim, i), flush=True)
            continue
        t0 = time.time()
        scene = scene_neuve()
        lot = G.Lot(S, "ka_")
        u = i / float(nb)
        KA.build(S, lot, u) if a.anim == "course" else KA.build(S, lot, 0.0, attaque=u)
        n_pieces = lot.n
        objs = lot.flush()
        TM.sans_ombre(objs)
        bpy.context.view_layer.update()
        if a.glb and i == 0 and a.anim == "course":
            export_glb("kaiju")
        nverts = sum(len(o.data.vertices) for o in objs)
        t_mesh = time.time() - t0
        R_, zmax = se["R"], se["zmax"]
        ox = int(math.ceil(R_ * D)) + 8
        oy = int(math.ceil((R_ * C.COS_T + zmax * C.SIN_T) * D)) + 8
        W = ox + int(math.ceil((R_ + zmax * 0.95) * D)) + 8
        H = oy + int(math.ceil((R_ * C.COS_T) * D)) + 8
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
        ground = S.add_ground(scene, size=120.0)
        world = scene.world
        _rt = S.render_to
        parts = {"ao": 4, "shadow": 8}

        def rt(sc, path):
            ech = parts.get(os.path.basename(path)[:-4].rsplit("-", 1)[-1])
            avant, den = sc.cycles.samples, sc.cycles.use_denoising
            if ech:
                sc.cycles.samples = ech
                sc.cycles.use_denoising = False
            try:
                return _rt(sc, path)
            finally:
                sc.cycles.samples, sc.cycles.use_denoising = avant, den
        S.render_to = rt
        tmp = os.path.join(d, "_tmp-%s-%02d" % (a.anim, i))
        os.makedirs(tmp, exist_ok=True)
        def blanc(mat):
            if mat is not None and mat.get("fo_kind") == "emissive":
                return _blanc_de(mat)
            return S._black_mat()
        for k in dirs:
            cap = k * 45.0
            yaw = math.atan2(math.cos(math.radians(cap)), math.sin(math.radians(cap)))
            for o in objs:
                o.rotation_euler = (0.0, 0.0, yaw)
            bpy.context.view_layer.update()
            res = S.render_passes(scene, tmp, "f", ["main", "ao", "shadow"], sun, ground)
            main = lire_png(res["main"])
            ao = lire_png(res["ao"])
            ombre = lire_png(res["shadow"])[..., 3]
            pg = os.path.join(tmp, "f-glow.png")
            passe_lueur(scene, objs, sun, ground, world, pg, a.lueur_spp, blanc)
            glow = lire_png(pg)
            np.savez_compressed(nom_de(k), main=np.round(np.clip(main, 0, 1) * 255).astype(np.uint8), ao=np.round(np.clip(ao, 0, 1) * 255).astype(np.uint8),
                                ombre=np.round(np.clip(ombre, 0, 1) * 255).astype(np.uint8), glow=np.round(np.clip(glow, 0, 1) * 255).astype(np.uint8),
                                origine=np.array([ox, oy]), densite=np.array([D]))
            print("[FO-TITAN] kaiju %s %d dir %d %.1fs" % (a.anim, i, k, time.time() - t0), flush=True)
        S.render_to = _rt
        for f in os.listdir(tmp):
            os.remove(os.path.join(tmp, f))
        os.rmdir(tmp)
        print("[FO-TITAN] kaiju %s %d : %d dir, %dx%d, %d sommets, %d pieces, maillage %.0fs, total %.0fs" % (
            a.anim, i, len(dirs), W, H, nverts, n_pieces, t_mesh, time.time() - t0), flush=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--what", required=True, choices=ALLIES + ("kaiju",))
    ap.add_argument("--out", required=True)
    ap.add_argument("--stages", default="1,2,3")
    ap.add_argument("--anim", default="course")
    ap.add_argument("--images", default="")
    ap.add_argument("--dirs", default="")
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--px", type=float, default=40.0)
    ap.add_argument("--ombre-pct", type=int, default=50)
    ap.add_argument("--ombre-spp", type=int, default=16)
    ap.add_argument("--lueur-spp", type=int, default=16)
    ap.add_argument("--glb", action="store_true")
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    if a.what in ALLIES:
        allie(a)
    else:
        kaiju(a)


main()
