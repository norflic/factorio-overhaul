"""Essai moteur du MASQUE D'ÉQUIPE de la mitrailleuse (lot A4, 24/10/2026) : copie JETABLE du mod (rien n'est branché
dans le mod livré). Python 3.9 (numpy, Pillow).

    py -3.9 tools/autotest/a4/masque_jetable.py --dest <dossier neuf, hors du dépôt> [--age 4]

Ce que fait la copie :
  - copie du mod (sans .git ni tools/render) ;
  - feuilles de MASQUE de la tête de l'âge (hr et normale, mêmes cellules que la couche principale) : pixels de la
    dominante de l'âge (âge 4 : jaune de signalisation, teinte 35 à 70°, saturation > 0,35, valeur > 0,25), en GRIS
    (luminance du pixel, relevée pour garder le modelé), alpha = alpha de la tête ; ailleurs transparent ;
  - gun.lua de la copie : couche ajoutée au-dessus de la couche principale de la tête, dans les 5 animations, avec
    flags = { "mask" } et apply_runtime_tint = true (comme le masque vanilla de la mitrailleuse,
    data/base/prototypes/entity/turrets.lua) ;
  - masque.json : pixels du masque (part de la tête), boîtes d'alpha par cellule, et l'estimation de mémoire vidéo
    (règle F147 : 1,10 à 1,18 × les pixels des boîtes d'alpha).
Puis : & '<racine>\\fo-captures.bat' a4-masque '<dest>' et py -3.9 tools/autotest/a4/masque_images.py <fo-shots>.
"""
import argparse
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))

SEL = {4: dict(teinte=(35, 70), sat=0.35, val=0.25)}


def masque_de(rgba, sel):
    a = rgba.astype(np.float64) / 255.0
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    mx, mn = a[..., :3].max(-1), a[..., :3].min(-1)
    v = mx
    s = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    m = (h >= sel["teinte"][0]) & (h <= sel["teinte"][1]) & (s > sel["sat"]) & (v > sel["val"]) & (al > 0.02)
    lum = np.clip((0.2126 * r + 0.7152 * g + 0.0722 * b) * 1.6, 0, 1)
    out = np.zeros_like(a)
    out[..., 0] = out[..., 1] = out[..., 2] = np.where(m, lum, 0)
    out[..., 3] = np.where(m, al, 0)
    return (out * 255).round().astype(np.uint8), m


def boites(alpha, w, h, ll, n):
    px = 0
    for k in range(n):
        c = alpha[(k // ll) * h:(k // ll + 1) * h, (k % ll) * w:(k % ll + 1) * w]
        ys, xs = np.nonzero(c > 0)
        if ys.size:
            px += (ys.max() - ys.min() + 1) * (xs.max() - xs.min() + 1)
    return int(px)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--age", type=int, default=4)
    a = ap.parse_args()
    dest = os.path.abspath(a.dest)
    if os.path.exists(dest):
        raise SystemExit("dossier déjà là : %s (un dossier NEUF)" % dest)

    def ign(d, names):
        out = {".git"}
        if os.path.normpath(d) == os.path.join(MOD, "tools"):
            out.add("render")
        return [x for x in names if x in out]

    shutil.copytree(MOD, dest, ignore=ign)
    e = a.age
    sp = json.load(open(os.path.join(MOD, "graphics", "levels", "gun", "sprites.json"), encoding="utf-8"))
    td = sp["ages"][str(e)]["tete"]["main"]
    rap = {"age": e, "selection": SEL[e]}
    for r in ("hr", "lr"):
        d = td[r]
        src = os.path.join(MOD, "graphics", "levels", "gun", os.path.basename(d["filename"]))
        im = np.asarray(Image.open(src).convert("RGBA"))
        mk, m = masque_de(im, SEL[e])
        fn = os.path.basename(d["filename"]).replace("tete-main", "tete-masque")
        Image.fromarray(mk, "RGBA").save(os.path.join(dest, "graphics", "levels", "gun", fn), optimize=True)
        n = d["direction_count"]
        rap[r] = {"fichier": fn, "pixels_masque": int(m.sum()), "pixels_tete": int((im[..., 3] > 0).sum()),
                  "part_de_la_tete": round(float(m.sum()) / max(1, int((im[..., 3] > 0).sum())), 4),
                  "boites_alpha_masque_px": boites(mk[..., 3], d["width"], d["height"], d["line_length"], n),
                  "boites_alpha_tete_px": boites(im[..., 3], d["width"], d["height"], d["line_length"], n)}
        rap[r]["vram_estimee_px"] = [round(1.10 * rap[r]["boites_alpha_masque_px"]),
                                    round(1.18 * rap[r]["boites_alpha_masque_px"])]
    # gun.lua de la copie : couche de masque sur la tête de l'âge, dans les 5 animations
    p = os.path.join(dest, "prototypes", "levels", "gun.lua")
    t = open(p, encoding="utf-8", newline="").read()
    ancre = 'for _, k in ipairs(TETE) do p[k] = tete(age, k == "attacking_animation" and age.eclat or nil) end'
    if t.count(ancre) != 1:
        raise SystemExit("gun.lua : ancre introuvable")
    hr, lr = td["hr"], td["lr"]

    def couche(d, f, hrv):
        return ('{ filename = "__factorio-overhaul__/graphics/levels/gun/%s", width = %d, height = %d, shift = { %r, %r }, '
                'direction_count = %d, line_length = %d, frame_count = 1, axially_symmetrical = false, flags = { "mask" }, '
                'apply_runtime_tint = true, priority = "medium"%s }' % (f, d["width"], d["height"], d["shift"][0],
                                                                     d["shift"][1], d["direction_count"],
                                                                     d["line_length"], hrv))
    lua_hr = couche(hr, rap["hr"]["fichier"], ", scale = 0.5")
    lua_lr = couche(lr, rap["lr"]["fichier"], ", hr_version = " + lua_hr)
    ajout = ancre + ('\n  -- ESSAI A4 (copie jetable) : masque d\'équipe de l\'âge %d\n  if e == %d then\n'
                     '    for _, k in ipairs(TETE) do\n      local c = %s\n'
                     '      local L = p[k].layers\n      local rc = L[1].repeat_count\n'
                     '      if rc then c.repeat_count = rc ; c.hr_version.repeat_count = rc end\n'
                     '      table.insert(L, 2, c)\n    end\n  end') % (e, e, lua_lr)
    t = t.replace(ancre, ajout)
    open(p, "w", encoding="utf-8", newline="").write(t)
    with open(os.path.join(dest, "masque.json"), "w", encoding="utf-8") as f:
        json.dump(rap, f, indent=1, sort_keys=True)
    print(json.dumps(rap, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
