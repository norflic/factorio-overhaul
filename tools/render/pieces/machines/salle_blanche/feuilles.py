"""FEUILLES DE JEU de la salle blanche (lot CALC-SALLE-BLANCHE, 30/10) : des sorties de rendre.py vers
graphics/machines/salle-blanche/ (PNG commités : moins de 3 Mo en tout, la règle D-6 vise les grosses familles),
sprites.lua (GÉNÉRÉ, lu par prototypes/machines/salle_blanche.lua), sprites.json et MANIFEST.json.

    py -3.9 tools/render/pieces/machines/salle_blanche/feuilles.py --src DIR --nom s2 [--dest graphics/machines/salle-blanche]

Couches livrées (hr 64 px/tuile, scale 0,5 ; normale 32 px/tuile) :
  main      corps (baies ÉTEINTES : la couleur ambre ne vient que de la lueur) ;
  shadow    ombre (draw_as_shadow) ;
  fenetres  lueur SANS les voyants (baies ambre, hublot du sas) : working_visualisation, fadeout ;
  voyants   ANIMATION de 8 images (frame_sequence de l'âge 10) : la lueur des voyants bleus, découpée par groupe à partir
            de leurs positions à l'écran (spec.json « leds », modele.led) ; chaque image allume 2 groupes sur 3 ;
  light     halo de nuit au sol (draw_as_light), fadeout ;
  icone     64 px à 4 niveaux de mipmaps (64 + 32 + 16 + 8), réduite de la machine, fenêtres allumées.
"""
import argparse
import hashlib
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
import fo_post as P  # noqa: E402

DEST_DEFAUT = os.path.join(MOD, "graphics", "machines", "salle-blanche")
PREFIXE_JEU = "__factorio-overhaul__/graphics/machines/salle-blanche/"
IMAGES = 8
# groupes allumés par image (3 groupes de voyants : modele.GROUPES_LED) : chenillard lent, 2 groupes sur 3
MOTIF = [(1, 1, 0), (1, 1, 0), (0, 1, 1), (0, 1, 1), (1, 0, 1), (1, 0, 1), (1, 1, 1), (1, 0, 0)]
R_LED = 8   # demi-côté (px HR) de la zone d'un voyant dans la couche lueur


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def lire(src, nom):
    return json.load(open(os.path.join(src, nom, "spec.json"), encoding="utf-8"))


def lire_png(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float64) / 255.0


def defs(box, origin, fn, fn_lr):
    sd = P.sprite_def(box, origin, 64)
    sl = P.sprite_def(box, origin, 32)
    return {"hr": {"filename": PREFIXE_JEU + fn, "width": sd["width"], "height": sd["height"],
                   "shift": [sd["shift"][0], sd["shift"][1]]},
            "lr": {"filename": PREFIXE_JEU + fn_lr, "width": sl["width"], "height": sl["height"],
                   "shift": [sl["shift"][0], sl["shift"][1]]}}


def ecrire(img, dest, fn, fichiers):
    P.write_png(img, os.path.join(dest, fn))
    fichiers.append(fn)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--nom", required=True)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--essai", action="store_true", help="accepter un rendu de moins de 64 échantillons")
    a = ap.parse_args()
    s = lire(a.src, a.nom)
    if s["samples"] < 64 and not a.essai:
        raise SystemExit("[FO-FEUILLES-SB] %s rendue à %d échantillons (final : 128 ; essai : --essai)"
                         % (a.nom, s["samples"]))
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    d = os.path.join(a.src, a.nom)
    origin = tuple(s["origin_px"])
    fichiers = []
    tab = {"variante": a.nom, "echantillons": s["samples"], "images_voyants": IMAGES}
    # corps : pixels presque transparents retirés (bruit du liseré, rendre.ALPHA_MIN), feuille recadrée
    L = s["layers"]["main"]
    mh = lire_png(os.path.join(d, L["file"]))
    mh[..., 3] = np.where(mh[..., 3] < 12.0 / 255.0, 0.0, mh[..., 3])
    x0, y0 = L["box"][0], L["box"][1]
    b = P.trim_box(mh, (origin[0] - x0, origin[1] - y0))
    box = [x0 + b[0], y0 + b[1], x0 + b[2], y0 + b[3]]
    crop = mh[b[1]:b[3], b[0]:b[2]]
    ecrire(crop, a.dest, "hr-sb-main.png", fichiers)
    ecrire(P.downsample2(crop), a.dest, "sb-main.png", fichiers)
    tab["main"] = defs(box, origin, "hr-sb-main.png", "sb-main.png")
    s["layers"]["main"] = dict(L, box=box)
    for k, cle in (("shadow", "shadow"), ("light", "light")):
        L = s["layers"].get(k)
        if not L:
            continue
        fn, fl = "hr-sb-%s.png" % cle, "sb-%s.png" % cle
        shutil.copyfile(os.path.join(d, L["file"]), os.path.join(a.dest, fn))
        shutil.copyfile(os.path.join(d, L["lr"]["file"]), os.path.join(a.dest, fl))
        fichiers += [fn, fl]
        tab[cle] = defs(L["box"], origin, fn, fl)
    # lueur : fenêtres (sans voyants) + animation des voyants
    G = s["layers"]["glow"]
    glow = lire_png(os.path.join(d, G["file"]))
    gx0, gy0 = G["box"][0], G["box"][1]
    h, w = glow.shape[:2]
    grp = -np.ones((h, w), dtype=int)
    for (u, v, g_) in s["leds"]:
        cx, cy = int(round(origin[0] + u - gx0)), int(round(origin[1] + v - gy0))
        y0, y1, x0, x1 = max(0, cy - R_LED), min(h, cy + R_LED + 1), max(0, cx - R_LED), min(w, cx + R_LED + 1)
        if y1 > y0 and x1 > x0:
            grp[y0:y1, x0:x1] = g_
    led = grp >= 0
    fen = glow.copy()
    fen[led] = 0.0
    ecrire(fen, a.dest, "hr-sb-fenetres.png", fichiers)
    ecrire(P.downsample2_additive(fen), a.dest, "sb-fenetres.png", fichiers)
    tab["fenetres"] = defs(G["box"], origin, "hr-sb-fenetres.png", "sb-fenetres.png")
    # cadre des voyants : boîte paire relative à l'origine (la version normale tombe au pixel)
    ys, xs = np.nonzero(led & (glow[..., 3] > 1e-3))
    if len(xs):
        bx0, by0 = int(gx0 + xs.min() - 2), int(gy0 + ys.min() - 2)
        bx1, by1 = int(gx0 + xs.max() + 3), int(gy0 + ys.max() + 3)
        bx0 -= (bx0 - origin[0]) % 2
        by0 -= (by0 - origin[1]) % 2
        bx1 += (bx1 - origin[0]) % 2
        by1 += (by1 - origin[1]) % 2
        sub = glow[by0 - gy0:by1 - gy0, bx0 - gx0:bx1 - gx0]
        sg = grp[by0 - gy0:by1 - gy0, bx0 - gx0:bx1 - gx0]
        fh, fw = sub.shape[:2]
        sheet = np.zeros((fh, fw * IMAGES, 4))
        for f, motif in enumerate(MOTIF):
            fr = sub.copy()
            on = np.zeros((fh, fw), dtype=bool)
            for k_, v_ in enumerate(motif):
                if v_:
                    on |= sg == k_
            fr[~on] = 0.0
            sheet[:, f * fw:(f + 1) * fw] = fr
        ecrire(sheet, a.dest, "hr-sb-voyants.png", fichiers)
        lr = np.concatenate([P.downsample2_additive(sheet[:, f * fw:(f + 1) * fw]) for f in range(IMAGES)], 1)
        ecrire(lr, a.dest, "sb-voyants.png", fichiers)
        dv = defs([bx0, by0, bx1, by1], origin, "hr-sb-voyants.png", "sb-voyants.png")
        dv["hr"]["width"], dv["lr"]["width"] = fw, fw // 2
        tab["voyants"] = dv
    tab["nb_voyants"] = len(s["leds"])
    # boîte de dessin, couleur de carte, icône
    M_ = s["layers"]["main"]
    sd = P.sprite_def(M_["box"], origin, 64)
    ww, hh = sd["width"] / 64.0, sd["height"] / 64.0
    tab["boite"] = [[sd["shift"][0] - ww / 2, sd["shift"][1] - hh / 2], [sd["shift"][0] + ww / 2, sd["shift"][1] + hh / 2]]
    main = lire_png(os.path.join(a.dest, "hr-sb-main.png"))
    wgt = main[..., 3]
    tab["map_color"] = [round(float(c), 3) for c in (main[..., :3] * wgt[..., None]).sum((0, 1)) / max(1e-6, wgt.sum())]
    mx0, my0 = M_["box"][0], M_["box"][1]
    comp = main.copy()
    yo, xo = gy0 - my0, gx0 - mx0
    hh_, ww_ = glow.shape[:2]
    reg = comp[max(0, yo):yo + hh_, max(0, xo):xo + ww_]
    gl = glow[max(0, -yo):max(0, -yo) + reg.shape[0], max(0, -xo):max(0, -xo) + reg.shape[1]]
    reg[..., :3] = np.clip(reg[..., :3] + gl[..., :3] * gl[..., 3:4], 0, 1)
    tab["icone"] = icone(comp, a.dest, fichiers)
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/machines/salle_blanche/feuilles.py (lot CALC-SALLE-BLANCHE) :\n"
              "-- ne pas modifier à la main. Tailles en pixels, shift en tuiles ; hr = 64 px par tuile (scale 0,5).\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + lua(tab) + "\n")
    with open(os.path.join(a.dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(tab, f, indent=1, sort_keys=True, ensure_ascii=False)
    man = {"commande": "py -3.9 tools/render/pieces/machines/salle_blanche/feuilles.py --src <rendus> --nom %s" % a.nom,
           "sources": os.path.abspath(a.src), "variante": a.nom, "echantillons": s["samples"], "fichiers": {}}
    total = 0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        W, H = Image.open(p).size
        n = os.path.getsize(p)
        total += n
        man["fichiers"][fn] = {"sha256": sha(p), "taille": n, "largeur": W, "hauteur": H}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-SB] %d fichiers PNG, %.2f Mo, %d voyants, variante %s (%d échantillons)"
          % (len(fichiers), total / 1e6, len(s["leds"]), a.nom, s["samples"]))


def icone(arr, dest, fichiers):
    ys, xs = np.nonzero(arr[..., 3] > 0.03)
    arr = arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = arr.shape[:2]
    side = max(h, w)
    sq = np.zeros((side, side, 4))
    sq[(side - h) // 2:(side - h) // 2 + h, (side - w) // 2:(side - w) // 2 + w] = arr
    pm = sq.copy()
    pm[..., :3] *= pm[..., 3:4]
    base = Image.fromarray((pm * 255).round().astype(np.uint8), "RGBA")
    out = Image.new("RGBA", (64 + 32 + 16 + 8, 64), (0, 0, 0, 0))
    x = 0
    for t in (64, 32, 16, 8):
        r = np.asarray(base.resize((t, t), Image.LANCZOS)).astype(np.float64) / 255.0
        al = np.clip(r[..., 3:4], 1e-6, 1)
        rgb = np.where(r[..., 3:4] > 1e-4, r[..., :3] / al, 0)
        u = np.concatenate([np.clip(rgb, 0, 1), r[..., 3:4]], -1)
        out.paste(Image.fromarray((u * 255).round().astype(np.uint8), "RGBA"), (x, 0))
        x += t
    f = "sb-icone.png"
    out.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)
    return {"filename": PREFIXE_JEU + f, "icon_size": 64, "icon_mipmaps": 4}


def lua(v, ind=0):
    p = "  " * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        keys = sorted(v, key=lambda k: (isinstance(k, str), k))
        out = []
        for k in keys:
            kk = ("[%d]" % k) if isinstance(k, int) else k
            out.append("%s  %s = %s" % (p, kk, lua(v[k], ind + 1)))
        return "{\n" + ",\n".join(out) + "\n" + p + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x, ind) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(v, 6)) if isinstance(v, float) else str(v)
    return json.dumps(v, ensure_ascii=False)


if __name__ == "__main__":
    main()
