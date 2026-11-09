"""FEUILLES DE JEU DES TITANS (lot TITANS, 9/11) : rendus -> graphics/robots/titans/ (PNG hors de git, D-6), sprites.lua (généré, lu
par prototypes/titans.lua et prototypes/titans_kaiju.lua) et MANIFEST.json (commité). Hors Blender : réduction, rognage, feuilles.

    PYTHONUTF8=1 py -3.9 tools/render/pieces/titans/feuilles_titans.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources (à GARDER) : fo-logs/2026-11-09_TITANS/rendu/ : juggernaut-<stage>/ (main.png, glow_*.png, shadow.png, spec.json : post des géants) ;
kaiju/kaiju-<anim>-<image>-<dir>.npz (main, ao, ombre, glow, origine, densite ; batch_titans.py).
- Juggernaut : même traitement que les géants (feuilles_xp.geant : corps haute 32 px/tuile, normale 16 ; lueurs fondues en UNE couche ;
  ombre 16 / 8 ; icône 64), un corps par stade (1 à 3).
- Kaiju : par animation (course 8 images, attaque 4) et par couche (main, glow, shadow), UN fichier PAR DIRECTION (8), images en lecture
  continue (`line_length` colonnes, `lines_per_file` lignes : convention vanilla `filenames`), cellule = union des rognages de toutes les
  images et directions, alignée sur 2 ; hr- : densité du rendu (24 px/tuile) ; sans préfixe : la moitié (12). Aucune feuille au-delà de
  2 048 px (règle du lot). Liseré de contact composé sous le corps (fo_post.compose_main, points isolés retirés comme les souches).
  La lueur est rendue BLANCHE (batch_titans) : le prototype la teinte par ère.
"""
import argparse
import glob
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "pieces", "experimentaux"))
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import feuilles_xp as FX  # noqa: E402

LOGS = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs", "2026-11-09_TITANS")
SRC_DEFAUT = os.path.join(LOGS, "rendu")
DEST_DEFAUT = os.path.join(MOD, "graphics", "robots", "titans")
PREFIXE = "__factorio-overhaul__/graphics/robots/titans/"
COMMANDE = "PYTHONUTF8=1 py -3.9 tools/render/pieces/titans/feuilles_titans.py   (depuis la racine du mod ; sources : fo-logs/2026-11-09_TITANS/rendu, à GARDER)"
STAGES = (1, 2, 3)
ANIMS = (("course", 8), ("attaque", 4))
DIRS = 8
REDUC = 2
SEUIL = 2
SEUIL_OMBRE = 24
PLUS_PETIT_AMAS = 12
MAX_PX = 2048


def sans_points_isoles(a, seuil, mini=PLUS_PETIT_AMAS):
    m = a > seuil
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n == 0:
        return m
    tailles = ndimage.sum(m, lab, range(1, n + 1))
    garde = np.zeros(n + 1, bool)
    garde[1:] = tailles >= mini
    return garde[lab]


def alpha(x):
    """Canal alpha d'une image RGBA, ou l'image elle-même si elle n'a qu'un canal (ombre)."""
    return x if x.ndim == 2 else x[..., 3]


def boite(a):
    ys, xs = np.where(a > SEUIL)
    if not len(xs):
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def reduit2(img, additif=False):
    """RGBA 8 bits -> moitié (lumière linéaire prémultipliée ; additif : énergie)."""
    f = img.astype(np.float64) / 255.0
    out = P.downsample2_additive(f) if additif else P.downsample2(f)
    return np.round(np.clip(out, 0, 1) * 255).astype(np.uint8)


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def kaiju(S, src, poids):
    """Feuilles du Kaiju. Rend l'entrée de sprites.lua."""
    d = os.path.join(src, "kaiju")
    out = {"K": 1.0, "foulee": None, "reduc": REDUC, "directions": DIRS}
    # FOULEE : constante lue dans le texte de kaiju.py (le module importe bpy : pas d'import hors Blender)
    import re
    src = open(os.path.join(HERE, "kaiju.py"), encoding="utf-8").read()
    m = re.search(r"^FOULEE\s*=\s*([0-9.*+\- ()]+)", src, re.M)
    out["foulee"] = round(float(eval(m.group(1), {"__builtins__": {}})), 4)
    icone = None
    for anim, nb in ANIMS:
        images = {}
        for k in range(DIRS):
            for i in range(nb):
                p = os.path.join(d, "kaiju-%s-%02d-%02d.npz" % (anim, i, k))
                if not os.path.exists(p):
                    raise SystemExit("MANQUE : " + p)
                z = np.load(p)
                fr = P.contact_fringe(z["ao"].astype(np.float64) / 255.0, C.AO_STRENGTH, C.AO_GAMMA, C.AO_COLOR)
                fr[..., 3] *= sans_points_isoles(fr[..., 3], SEUIL / 255.0)
                mn = P.over(z["main"].astype(np.float64) / 255.0, fr)
                mn = np.round(np.clip(mn, 0, 1) * 255).astype(np.uint8)
                om = np.where(sans_points_isoles(z["ombre"], SEUIL_OMBRE), z["ombre"], 0).astype(np.uint8)
                gl = np.round(np.clip(P.additive_layer(z["glow"].astype(np.float64) / 255.0), 0, 1) * 255).astype(np.uint8)
                gl[..., 3] = np.where(sans_points_isoles(gl[..., 3], SEUIL), gl[..., 3], 0)
                images[(k, i)] = (mn, gl, om, z["origine"], float(z["densite"][0]))
        D = images[(0, 0)][4]
        ox, oy = images[(0, 0)][3]
        H0, W0 = images[(0, 0)][0].shape[:2]
        uni = {}
        for c, idx in (("main", 0), ("glow", 1), ("shadow", 2)):
            l = [boite(alpha(v[idx])) for v in images.values()]
            l = [x for x in l if x is not None]
            x0, y0 = min(x[0] for x in l), min(x[1] for x in l)
            x1, y1 = max(x[2] for x in l), max(x[3] for x in l)
            x0, y0 = x0 - x0 % REDUC, y0 - y0 % REDUC
            x1, y1 = min(W0, x1 + (-x1) % REDUC), min(H0, y1 + (-y1) % REDUC)
            uni[c] = (x0, y0, x1 - (x1 - x0) % REDUC, y1 - (y1 - y0) % REDUC)
        couches = {}
        for c, idx in (("main", 0), ("glow", 1), ("shadow", 2)):
            x0, y0, x1, y1 = uni[c]
            cw, ch = x1 - x0, y1 - y0
            # grille EXACTE (ll × lpf = nb images) : le moteur lit `filenames` en continu, ll × lpf images par fichier (F-TITANS : une
            # grille 3 × 3 pour 8 images décalait la direction suivante d'une cellule) ; la plus large qui tient dans MAX_PX
            ll = None
            for cand in range(nb, 0, -1):
                if nb % cand == 0 and cand * cw <= MAX_PX and (nb // cand) * ch <= MAX_PX:
                    ll = cand
                    break
            assert ll is not None, (anim, c, cw, ch, nb)
            lpf = nb // ll
            fichiers_hr, fichiers_lr = [], []
            for k in range(DIRS):
                feuille = np.zeros((ch * lpf, cw * ll, 4), np.uint8)
                for i in range(nb):
                    t = images[(k, i)][idx][y0:y1, x0:x1]
                    if t.ndim == 2:  # ombre : alpha seul -> RGBA noir
                        tt = np.zeros((ch, cw, 4), np.uint8)
                        tt[..., 3] = t
                        t = tt
                    lig, col = divmod(i, ll)
                    feuille[lig * ch:(lig + 1) * ch, col * cw:(col + 1) * cw] = t
                    bx = boite(t[..., 3])
                    if bx:
                        aire = (bx[2] - bx[0]) * (bx[3] - bx[1]) / 1e6
                        poids["kaiju"]["haute"] += aire
                        poids["kaiju"]["normale"] += aire / (REDUC * REDUC)
                nom_hr = "hr-kaiju-%s-%s-%d.png" % (anim, c, k)
                nom_lr = "kaiju-%s-%s-%d.png" % (anim, c, k)
                fichiers_hr.append(S.ecrit(feuille, nom_hr))
                fichiers_lr.append(S.ecrit(reduit2(feuille, additif=(c == "glow")), nom_lr))
                if c == "main" and k == 3 and icone is None:
                    icone = images[(k, 0)][0][y0:y1, x0:x1]
            sft = ((x0 + x1) / 2.0 - ox, (y0 + y1) / 2.0 - oy)
            couches[c] = {"hr": fichiers_hr, "lr": fichiers_lr, "w": int(cw), "h": int(ch), "lw": int(cw // REDUC), "lh": int(ch // REDUC),
                          "ll": int(ll), "lpf": int(lpf), "sx": round(sft[0] / D, 5), "sy": round(sft[1] / D, 5)}
            poids["kaiju"]["images"] += nb * DIRS if c == "main" else 0
        out[anim] = {"images": nb, "densite": D, "couches": couches}
    # icône : direction sud-est, image 0 de la course, tenue dans 60 px
    k = 60.0 / max(icone.shape[0], icone.shape[1])
    ic = FX.lanczos(icone, max(1, int(round(icone.shape[1] * k))), max(1, int(round(icone.shape[0] * k))))
    cadre = np.zeros((64, 64, 4), np.uint8)
    oy_, ox_ = (64 - ic.shape[0]) // 2, (64 - ic.shape[1]) // 2
    cadre[oy_:oy_ + ic.shape[0], ox_:ox_ + ic.shape[1]] = ic
    out["icone"] = {"filename": S.ecrit(cadre, "icone-kaiju.png"), "size": 64}
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--sans-kaiju", action="store_true")
    ap.add_argument("--sans-juggernaut", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in glob.glob(os.path.join(a.dest, "*.png")):
        os.remove(f)
    FX.PREFIXE = PREFIXE
    S = FX.Sortie(a.dest)
    spr = {"juggernaut": {}, "kaiju": {}}
    poids = {"juggernaut": {"haute": 0.0, "normale": 0.0, "images": 0}, "kaiju": {"haute": 0.0, "normale": 0.0, "images": 0}}
    if not a.sans_juggernaut:
        for st in STAGES:
            e = FX.geant(S, a.src, "juggernaut-%d" % st, "juggernaut-%d" % st)
            spr["juggernaut"][st] = e
            for c in [e["main"], e["ombre"]] + e["lueurs"]:
                poids["juggernaut"]["haute"] += c["hr"]["width"] * c["hr"]["height"] / 1e6
                poids["juggernaut"]["normale"] += c["lr"]["width"] * c["lr"]["height"] / 1e6
            poids["juggernaut"]["images"] += 1
    if not a.sans_kaiju:
        spr["kaiju"] = kaiju(S, a.src, poids)
    p = os.path.join(a.dest, "sprites.lua")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/render/pieces/titans/feuilles_titans.py (lot TITANS) : ne pas modifier à la main.\n")
        f.write("-- Images hors de git (D-6) : MANIFEST.json, « commande ». shift : centre de l'image depuis la position au sol, en tuiles.\n")
        f.write("return " + FX.lua(spr) + "\n")
    fichiers = {}
    total = 0
    for f in sorted(os.listdir(a.dest)):
        if f.endswith(".png"):
            pp = os.path.join(a.dest, f)
            im = Image.open(pp)
            fichiers[f] = {"largeur": im.size[0], "hauteur": im.size[1], "taille": os.path.getsize(pp), "sha256": sha(pp)}
            total += os.path.getsize(pp)
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"commande": COMMANDE, "arguments": [], "poids_mpx": {k: {kk: round(vv, 2) for kk, vv in v.items()} for k, v in poids.items()},
                   "fichiers": fichiers}, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-TITANS] %d fichiers PNG, %.2f Mo" % (len(fichiers), total / 1e6), flush=True)
    for k, v in poids.items():
        print("  %s : %d images ; haute %.1f Mpx ; normale %.2f Mpx" % (k, v["images"], v["haute"], v["normale"]))


if __name__ == "__main__":
    main()
