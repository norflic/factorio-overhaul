"""RENDU DES ROBOTS (lot RB-V0) : copie de vaisseau_o/rendre.py (noms de fichiers « rb », étalonnage et définition par variante).

    py -3.9 tools/render/pieces/robots/rendre.py --names trotte-pose,levite-pose --out DIR [--cache DIR] [--samples 16] [--post-only]

UNE session Blender pour toutes les variantes, lancée par le verrou de rendu (interdit n° 6 : « with_render_lock.py »,
une seule place prise). Passes de jour (main, ao, shadow, glow ; pas de halo de nuit : concept). Post-traitement par
fo_post (inchangé) : liseré de contact, ombre, lueur ; sorties hr-fus-<nom>-<couche>.png et spec.json (format lu par
commun/compo.py : couches, shift) dans <out>/<nom>/.
"""
import argparse
import json
import os
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import piece  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BATCH = os.path.join(HERE, "batch_blender.py")


def etalonne(img, grade):
    """Étalonnage de la couche principale (refonte QG, 31/10), hors Blender, rejouable par --post-only. Il n'agit que sur
    les EXTRÉMITÉS de la courbe : pied (sous tp, puissance tk : noirs plus noirs), épaule (au-dessus de sp, pente g :
    clairs plus clairs), puis gamma ga des tons moyens et saturation s. Une courbe en S sur les tons moyens ferme des
    cellules (mesure « damier » : de 0,45 à 0,62). FO_GRADE="tp,tk,sp,g,ga,s"."""
    tp, tk, sp, g, ga, sat = grade
    out = img.copy()
    rgb = np.clip(out[..., :3], 0.0, 1.0)
    lu = np.maximum((0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2])[..., None], 1e-5)
    l2 = lu ** ga
    l2 = np.where(l2 < tp, tp * (l2 / tp) ** tk, l2)
    l2 = np.where(l2 > sp, sp + (l2 - sp) * g, l2)
    rgb = rgb * l2 / lu
    rgb = l2 + (rgb - l2) * sat
    out[..., :3] = np.clip(rgb, 0.0, 1.0)
    return out


def pres_du_corps(alpha, rayon=9):
    """Masque du liseré de contact : 1 à moins de `rayon` px du corps opaque, 0 ailleurs (le bruit du liseré coûterait toute la toile dans l'atlas)."""
    from PIL import Image, ImageFilter
    im = Image.fromarray((alpha > 0.5).astype(np.uint8) * 255, "L").filter(ImageFilter.MaxFilter(2 * rayon + 1))
    return np.asarray(im).astype(np.float64) / 255.0


def post(name, cache, out_root):
    d = os.path.join(cache, name)
    info = json.load(open(os.path.join(d, "render.json"), encoding="utf-8"))
    origin = tuple(info["origin_px"])

    def npy(layer):
        p = os.path.join(d, "%s-%s.npy" % (name, layer))
        return np.load(p).astype(np.float64) if layer in info["layers"] and os.path.exists(p) else None

    meta = piece.PIECE["variants"][name]
    ao = npy("ao")
    hr = {"main": P.compose_main(npy("main"), ao, C) if ao is not None else npy("main")}     # pièce de patte : sans occlusion
    if not os.environ.get("FO_GRIS"):
        hr["main"] = etalonne(hr["main"], meta["grade"])
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    gl = npy("glow")
    if gl is not None:
        hr["glow"] = P.additive_layer(gl)
    ms = npy("mask")
    if ms is not None:
        # teinte du propriétaire : gris de la couche principale (normalisé), alpha = part de peinture visible
        lum = (0.299 * hr["main"][..., 0] + 0.587 * hr["main"][..., 1] + 0.114 * hr["main"][..., 2]) * 1.7
        a_m = np.clip(ms[..., 0], 0.0, 1.0) * ms[..., 3] * np.clip(hr["main"][..., 3], 0.0, 1.0)
        hr["mask"] = np.dstack([np.clip(lum, 0.0, 1.0)] * 3 + [a_m])
    if meta.get("serie"):
        # le liseré de contact très faible couvre toute la toile : coupé, sinon la case de la feuille vaut la toile entière
        hr["main"] = hr["main"].copy()
        hr["main"][..., 3] = hr["main"][..., 3] * pres_du_corps(hr["main"][..., 3])
        if "shadow" in hr:
            hr["shadow"] = hr["shadow"].copy()
            hr["shadow"][..., 3] = np.where(hr["shadow"][..., 3] < 10.0 / 255.0, 0.0, hr["shadow"][..., 3])
    out = os.path.join(out_root, name)
    os.makedirs(out, exist_ok=True)
    spec = {"variant": name, "epoch": piece.PIECE["variants"][name]["epoch"], "samples": info["samples"],
            "seconds": info["seconds"], "seconds_render": info.get("seconds_render"), "verts": info.get("verts"),
            "canvas": info["canvas"], "kit": "robots", "layers": {}, "ppu": info.get("ppu", 64.0), "tris": info.get("tris")}
    for layer in ("main", "shadow", "glow", "mask"):
        if layer not in hr:
            continue
        box = P.trim_box(hr[layer], origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop = hr[layer][y0:y1, x0:x1]
        fn = "hr-rb-%s-%s.png" % (name, layer)
        sha = P.write_png(crop, os.path.join(out, fn))
        ppu = info.get("ppu", 64.0)
        spec["layers"][layer] = {"file": fn, "width": x1 - x0, "height": y1 - y0,
                                 "shift": [((x0 + x1) / 2.0 - origin[0]) / ppu, ((y0 + y1) / 2.0 - origin[1]) / ppu],
                                 "sha256": sha, "draw_as": {"shadow": "shadow", "glow": "glow"}.get(layer, "main")}
    json.dump(spec, open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n"), indent=1, sort_keys=True)
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", default="")
    ap.add_argument("--serie", default="", help="un robot : toutes ses variantes de série, sorties par défaut dans fo-logs/2026-11-01_RBV1/<robot>/")
    ap.add_argument("--out", default="")
    ap.add_argument("--cache", default="")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--post-only", action="store_true")
    ap.add_argument("--reprise", action="store_true", help="saute les variantes déjà rendues")
    ap.add_argument("--passes", default="", help="échantillons par passe, ex. shadow=16,ao=16 (D-7, F140) ; les autres passes gardent --samples")
    ap.add_argument("--quick", action="store_true", help="passes main, glow, shadow seulement (essais)")
    a = ap.parse_args()
    if a.serie and not a.out:
        base = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs", piece.lot(a.serie), a.serie)
        a.out = os.path.join(base, "sprites")
        a.cache = a.cache or os.path.join(base, "cache")
    if a.serie:
        a.names = ",".join(piece.noms_serie(a.serie))
    a.cache = a.cache or os.path.join(os.path.dirname(os.path.abspath(a.out)), "cache_" + os.path.basename(a.out))
    names = [n for n in a.names.split(",") if n]
    bad = [n for n in names if n not in piece.PIECE["variants"]]
    if bad:
        raise SystemExit("variantes inconnues : %s" % ", ".join(bad))
    os.makedirs(a.cache, exist_ok=True)
    t0 = time.time()
    if not a.post_only:
        cmd = [sys.executable, LOCK, "--disque", a.cache, "--disque", a.out, "--", BLENDER, "-b", "--factory-startup",
               "-noaudio", "--python-exit-code", "1", "-P", BATCH, "--", "--names", ",".join(names), "--out", a.cache,
               "--samples", str(a.samples), "--samples-passes", a.passes] + (["--quick"] if a.quick else ["--apercu"]) + (["--reprise"] if a.reprise else [])
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
        log = []
        for raw in p.stdout:
            line = raw.decode("utf-8", "replace").rstrip()
            log.append(line)
            if line.startswith("[FO-RENDER]") and not os.environ.get("FO_SERIE_SILENCE") or "Error" in line or "Traceback" in line or "line " in line:
                print(line, flush=True)
        rc = p.wait()
        open(os.path.join(a.cache, "rendre.log"), "a", encoding="utf-8").write("\n".join(log[-300:]) + "\n")
        print("[FO-BATCH] %d variante(s), %.0f s, code %d" % (len(names), time.time() - t0, rc), flush=True)
        if rc:
            print("\n".join(log[-40:]))
            sys.exit(rc)
    for n in names:
        if a.reprise and os.path.isfile(os.path.join(a.out, n, "spec.json")):
            continue
        s = post(n, a.cache, a.out)
        print("[FO-POST] %s %s %.0f s de rendu Blender" % (n, sorted(s["layers"]), s["seconds"]), flush=True)
    print("[FO-RENDRE] %.0f s en tout" % (time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
