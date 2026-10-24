"""Essai moteur du MASQUE D'ÉQUIPE de la mitrailleuse (lot A4, 24/10/2026) : copie JETABLE du mod (rien n'est branché
dans le mod livré). Python 3.9 (numpy, Pillow).

    py -3.9 tools/autotest/a4/masque_jetable.py --dest <dossier neuf, hors du dépôt> [--age 4]
        [--forme dominante|bande-long|bande-trav|pastille]
    (formes étroites : correction M-2, pour MESURER le coût d'un masque étroit au D4m ; voir masque_geo)

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


def masque_geo(rgba, w, h, ll, noms, forme, echelle):
    """Masque GÉOMÉTRIQUE (correction M-2 du lot A4 : coût d'un masque étroit MESURÉ, pas supposé), cellule par
    cellule, dans le plan du sol déprojeté (même repère que feuilles.bouche_u : axe du tir de la direction) autour du
    barycentre de l'alpha de la cellule :
      bande-long : bande de LARG_BANDE px hr de large LE LONG du tir (traverse corps et canons) ;
      bande-trav : bande de LARG_BANDE px hr EN TRAVERS du tir (ceinture du corps) ;
      pastille   : disque de RAYON_PASTILLE px hr (insigne).
    Intersection avec l'alpha de la tête ; gris = luminance du pixel (modelé gardé). echelle : 1 en hr, 0,5 en normale."""
    import feuilles as FE
    a = rgba.astype(np.float64) / 255.0
    out = np.zeros_like(a)
    m_tot = np.zeros(a.shape[:2], bool)
    Pj = FE.PROJ_IMAGE
    for k, nom in enumerate(noms):
        r0, c0 = (k // ll) * h, (k % ll) * w
        al = a[r0:r0 + h, c0:c0 + w, 3]
        ys, xs = np.mgrid[0:h, 0:w]
        wt = al > 0.02
        if not wt.any():
            continue
        gx, gy = xs + 0.5, (ys + 0.5) / Pj
        mx, my = gx[wt].mean(), gy[wt].mean()
        wx, wy = FE.direction_sol(nom)
        s = (gx - mx) * wx + (gy - my) * wy          # le long du tir (sol)
        t = -(gx - mx) * wy + (gy - my) * wx         # en travers (sol)
        if forme == "bande-long":
            m = np.abs(t) <= LARG_BANDE * echelle / 2.0
        elif forme == "bande-trav":
            m = np.abs(s) <= LARG_BANDE * echelle / 2.0
        else:
            m = np.hypot(s, t) <= RAYON_PASTILLE * echelle
        m &= wt
        m_tot[r0:r0 + h, c0:c0 + w] = m
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = np.clip((0.2126 * r + 0.7152 * g + 0.0722 * b) * 1.6, 0, 1)
    out[..., 0] = out[..., 1] = out[..., 2] = np.where(m_tot, lum, 0)
    out[..., 3] = np.where(m_tot, a[..., 3], 0)
    return (out * 255).round().astype(np.uint8), m_tot


LARG_BANDE = 10       # px hr (0,16 tuile)
RAYON_PASTILLE = 8    # px hr (0,125 tuile)
FORMES = ("dominante", "bande-long", "bande-trav", "pastille")


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
    ap.add_argument("--forme", choices=FORMES, default="dominante",
                    help="dominante (essai E116) ; bande-long, bande-trav, pastille : masques étroits (correction M-2)")
    a = ap.parse_args()
    gun_e = os.path.join(MOD, "tools", "render", "pieces", "levels", "gun_e")
    for p_ in (os.path.join(MOD, "tools", "render"), os.path.join(os.path.dirname(gun_e), "commun"), gun_e):
        sys.path.insert(0, p_)
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
    rap = {"age": e, "forme": a.forme}
    if a.forme == "dominante":
        rap["selection"] = SEL[e]
    else:
        rap["geometrie_px_hr"] = {"largeur_bande": LARG_BANDE, "rayon_pastille": RAYON_PASTILLE}
    for r in ("hr", "lr"):
        d = td[r]
        src = os.path.join(MOD, "graphics", "levels", "gun", os.path.basename(d["filename"]))
        im = np.asarray(Image.open(src).convert("RGBA"))
        n = d["direction_count"]
        if a.forme == "dominante":
            mk, m = masque_de(im, SEL[e])
        else:
            noms = ["N", "E", "S", "O"] if n == 4 else ["d%02d" % k for k in range(n)]
            mk, m = masque_geo(im, d["width"], d["height"], d["line_length"], noms, a.forme,
                               1.0 if r == "hr" else 0.5)
        fn = os.path.basename(d["filename"]).replace("tete-main", "tete-masque")
        Image.fromarray(mk, "RGBA").save(os.path.join(dest, "graphics", "levels", "gun", fn), optimize=True)
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
