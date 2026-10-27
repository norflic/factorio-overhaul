"""SATELLITES DU CENTRE : la MITRAILLEUSE VALIDÉE du même âge posée aux deux coins avant (ronde F5-A2, 27/10). Python
3.9, hors Blender. Bible des familles (fo-logs/2026-10-23_plan-suite/familles.md §1.1) : « satellites de la
mitrailleuse ».

    py -3.9 tools/render/pieces/levels/centre_e/satellites.py --src <sprites rendus> --dest <sprites composés>

Le rendu Blender du centre ne pose aux coins avant qu'une ASSISE (corps.assise_satellite) ; ce script y COMPOSE, en 2D,
les sprites de production de la mitrailleuse du même âge (socle et tête : ceux qui sont en jeu), réduits à la taille du
satellite (cotes.cote_satellite) : tête tournée vers le sud-ouest (direction 40 sur 64) à gauche, vers le sud-est (24) à
droite (âge 1 : la mitrailleuse vanilla). Couches principale, ombre, lueur et halo, chacune dans la couche du même genre du
centre ; le cadre de chaque couche est agrandi s'il le faut ; la couche normale (32 px par tuile) est refaite par réduction
2×2 ; spec.json mis à jour (shift, tailles, sha256, « satellites »). Projection : celle du pipeline (fo_calib) avec le
repère étiré du kit : un point (x, y, z) en tuiles se projette à (64 x, −64 (y + z / √2)) px de l'origine de l'entité.
"""
import argparse
import json
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
for d in (RENDER, COMMUN, HERE):
    if d not in sys.path:
        sys.path.insert(0, d)
import importlib.util  # noqa: E402


def _charger(nom_module, fichier):
    """Module du kit du centre chargé par son CHEMIN (gun_e a aussi cotes.py et epoques.py : pas de confusion)."""
    spec = importlib.util.spec_from_file_location(nom_module, os.path.join(HERE, fichier))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


cotes = _charger("cen_cotes", "cotes.py")
E = _charger("cen_epoques", "epoques.py")
import fo_post as P  # noqa: E402
import compo as K  # noqa: E402

LOGS = K.ROOT + "/fo-logs"
# sprites de production de la mitrailleuse (socles : V3E ; têtes à 64 directions : A3, en jeu)
SOCLES = {e: LOGS + "/2026-10-23_V3E-p5/bas/sprites" for e in range(1, 10)}
SOCLES.update({e: LOGS + "/2026-10-23_V3E-p5/haut/sprites" for e in (10, 11, 12)})
SOCLES.update({e: LOGS + "/2026-10-23_V3E-ereV/sprites" for e in (13, 14, 15)})
TETES = LOGS + "/2026-10-24_A3/sprites"
GUN_SIDE = {e: (2, 3, 4, 5, 6)[(e - 1) // 3] for e in range(1, 16)}
DIR_GAUCHE, DIR_DROITE = 40, 24
KINDS = ("main", "shadow", "glow", "light")


def couches_mitrailleuse(e, d):
    """Couches de la mitrailleuse de l'âge e, tête vers la direction d (sur 64) ; âge 1 : vanilla (pose N)."""
    if e == 1:
        K.utiliser("gun_e")
        return K.level_layers(SOCLES[1], 1, "N", False, kinds=KINDS)
    pre = "e%02d" % e
    lays = K.own(SOCLES[e], pre + "-socle", KINDS)
    tete = K.own(TETES, "%s-tete-d%02d" % (pre, d), KINDS)
    if not tete:
        raise SystemExit("[FO-SATELLITES] tête absente : %s-tete-d%02d dans %s" % (pre, d, TETES))
    return lays + tete


def reduire(img, k):
    """Réduction d'une image RGBA (0..1) d'un facteur k, en prémultiplié."""
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * k))), max(1, int(round(h * k)))
    pm = img.copy()
    pm[..., :3] *= pm[..., 3:4]
    chans = []
    for i in range(4):
        ch = Image.fromarray((pm[..., i] * 65535).astype(np.float32), "F").resize((nw, nh), Image.LANCZOS)
        chans.append(np.asarray(ch) / 65535.0)
    out = np.clip(np.stack(chans, -1), 0, 1)
    a = out[..., 3:4]
    out[..., :3] = np.where(a > 1e-6, out[..., :3] / np.maximum(a, 1e-6), 0)
    return np.clip(out, 0, 1)


def coller(base, top, x0, y0, additif):
    """Colle top (RGBA 0..1) dans base à (x0, y0) (coin haut gauche, pixels entiers)."""
    h, w = top.shape[:2]
    b = base[y0:y0 + h, x0:x0 + w]
    if additif:
        pm = b[..., :3] * b[..., 3:4] + top[..., :3] * top[..., 3:4]
        a = np.clip(np.maximum(b[..., 3:4], top[..., 3:4]), 0, 1)
        m = np.maximum(pm.max(-1, keepdims=True), 1e-6)
        a = np.clip(np.maximum(a, m), 0, 1)
        rgb = np.where(a > 1e-6, np.clip(pm / np.maximum(a, 1e-6), 0, 1), 0)
        base[y0:y0 + h, x0:x0 + w] = np.concatenate([rgb, a], -1)
    else:
        base[y0:y0 + h, x0:x0 + w] = P.over(top, b)


def composer(src, dest, nom, e):
    sd = os.path.join(src, nom)
    spec = json.load(open(os.path.join(sd, "spec.json"), encoding="utf-8"))
    side = spec["side"]
    plan = E.SILHOUETTES[e][0]
    avant, _ = cotes.coins_satellites(side, plan)
    zt = cotes.taille(side)["zt"]
    k = cotes.cote_satellite(side) / GUN_SIDE[e]
    # pièces à coller par genre : (image réduite, centre de l'image en px par rapport à l'origine du centre)
    morceaux = {kd: [] for kd in KINDS}
    for (x, y), d in zip(avant, (DIR_GAUCHE, DIR_DROITE)):
        ux, vy = 64.0 * x, -64.0 * (y + zt / math.sqrt(2.0))
        for l in couches_mitrailleuse(e, d):
            im = reduire(l["img"], k)
            cx = ux + l["shift"][0] * 64.0 * k
            cy = vy + l["shift"][1] * 64.0 * k
            if l["kind"] in morceaux:
                morceaux[l["kind"]].append((im, cx, cy))
    od = os.path.join(dest, nom)
    os.makedirs(od, exist_ok=True)
    for f in os.listdir(sd):
        if not f.endswith(".png") and f != "spec.json":
            shutil.copy2(os.path.join(sd, f), os.path.join(od, f))
    for kd in KINDS:
        L = spec["layers"].get(kd)
        if not L and not morceaux[kd]:
            continue
        if L:
            img = np.asarray(Image.open(os.path.join(sd, L["file"])).convert("RGBA")).astype(np.float64) / 255.0
            W, H = img.shape[1], img.shape[0]
            ox, oy = W / 2.0 - L["shift"][0] * 64.0, H / 2.0 - L["shift"][1] * 64.0
        else:
            img = np.zeros((2, 2, 4))
            W, H, ox, oy = 2, 2, 1.0, 1.0
        # cadre agrandi pour contenir les morceaux (pair, pour la réduction 2×2)
        x0, y0, x1, y1 = 0, 0, W, H
        for im, cx, cy in morceaux[kd]:
            h, w = im.shape[:2]
            px, py = int(round(ox + cx - w / 2.0)), int(round(oy + cy - h / 2.0))
            x0, y0, x1, y1 = min(x0, px), min(y0, py), max(x1, px + w), max(y1, py + h)
        x0 -= (x1 - x0) % 2
        y0 -= (y1 - y0) % 2
        can = np.zeros((y1 - y0, x1 - x0, 4))
        can[-y0:-y0 + H, -x0:-x0 + W] = img
        ox, oy = ox - x0, oy - y0
        for im, cx, cy in morceaux[kd]:
            h, w = im.shape[:2]
            px, py = int(round(ox + cx - w / 2.0)), int(round(oy + cy - h / 2.0))
            coller(can, im, px, py, kd in ("glow", "light"))
        if kd == "shadow":
            can[..., :3] = 0.0
        fn = "hr-cen-%s-%s.png" % (nom, kd)
        fn_lr = "cen-%s-%s.png" % (nom, kd)
        sha = P.write_png(can, os.path.join(od, fn))
        lr = P.downsample2_additive(can) if kd in ("glow", "light") else P.downsample2(can)
        sha_lr = P.write_png(lr, os.path.join(od, fn_lr))
        Hc, Wc = can.shape[:2]
        sd_hr = P.sprite_def((0, 0, Wc, Hc), (ox, oy), 64)
        sd_lr = P.sprite_def((0, 0, Wc, Hc), (ox, oy), 32)
        draw_as = {"shadow": "shadow", "glow": "glow", "light": "light"}.get(kd, "main")
        spec["layers"][kd] = {"file": fn, "width": sd_hr["width"], "height": sd_hr["height"], "shift": sd_hr["shift"],
                              "sha256": sha, "draw_as": draw_as, "lr": dict(sd_lr, file=fn_lr, sha256=sha_lr)}
    spec["satellites"] = {"age": e, "cote_tuiles": round(cotes.cote_satellite(side), 3), "echelle": round(k, 4),
                          "directions": [DIR_GAUCHE, DIR_DROITE], "socles": SOCLES[e], "tetes": TETES if e > 1 else None}
    json.dump(spec, open(os.path.join(od, "spec.json"), "w", encoding="utf-8"), indent=1, sort_keys=True,
              ensure_ascii=False)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    a = ap.parse_args()
    n = 0
    for nom in sorted(os.listdir(a.src)):
        sd = os.path.join(a.src, nom)
        if not os.path.isfile(os.path.join(sd, "spec.json")):
            continue
        if nom.startswith("e") and nom.endswith("-centre"):
            composer(a.src, a.dest, nom, int(nom[1:3]))
            n += 1
        else:
            shutil.copytree(sd, os.path.join(a.dest, nom), dirs_exist_ok=True)
    print("[FO-SATELLITES] %d centre(s) composé(s) avec la mitrailleuse de leur âge, sources %s" % (n, a.src))


if __name__ == "__main__":
    main()
