"""FEUILLES DE JEU DU FOUR (lot F2-B, 25/10) : sprites de production -> graphics/levels/four/ (PNG hors de git,
décision D-6), sprites.lua (généré, lu par prototypes/levels/furnace.lua), sprites.json et MANIFEST.json.

    py -3.9 tools/render/pieces/levels/four_e/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-10-25_F2/production/sprites (à GARDER : rendus à 128 échantillons, ombre à 32,
décision D-7). Pour chaque variante (e01-piece, eNN-socle, eNN-piece) : couches principale, lueur, halo, ombre en hr
(64 px par tuile) et normale (32 px par tuile), recopiées telles quelles (noms hr-four-… et four-…), shift et tailles du
spec.json du rendu. Par âge (2 à 15), en plus :
  - boite        drawing_box : union des couches principales du socle et de la pièce (tuiles) ;
  - fumee        bouche de fumée relevée au rendu (x, yn, z) et sa position de JEU, ESTIMÉE (x, −(yn + 0,7071 z)) ;
                 fumee_nom : « smoke », ou « turbine-smoke » (vapeur) aux âges 9 et 12 ;
  - gueule       centre de la bouche à l'écran (x, y en tuiles) et taille (w, h) : place du feu animé (cotes.py) ;
  - foyer        couleur de la lumière de l'âge (commun/ages.FOYER : teinte du feu animé) ;
  - teinte       teinte PROPOSÉE du niveau pair (socle × (0,82 + 0,18 × lumière normée), phase A2, planche.py) ;
  - map_color    couleur moyenne de la couche principale du socle (pondérée par l'alpha) ;
  - icone        icône 64 px à 4 niveaux de mipmaps (64 + 32 + 16 + 8), réduite du socle.
Feu animé (feu) : UNE feuille partagée par les 15 âges, flammes presque blanches (16 images, 8 × 2), teintée par âge
dans le prototype (une teinte multiplie, F36 : la flamme prend la couleur du foyer) ; générée ici, sans Blender.
"""
import argparse
import hashlib
import json
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
sys.path.insert(0, HERE)
sys.path.insert(0, COMMUN)
import cotes  # noqa: E402
import ages  # noqa: E402

RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
SRC_DEFAUT = os.path.join(LOGS, "2026-10-25_F2", "production", "sprites")
DEST_DEFAUT = os.path.join(MOD, "graphics", "levels", "four")
PREFIXE_JEU = "__factorio-overhaul__/graphics/levels/four/"
COUCHES = ("main", "glow", "light", "shadow")
COTE = {1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4, 10: 5, 11: 5, 12: 5, 13: 6, 14: 6, 15: 6}
K_PROJ = 0.7071
VAPEUR = (9, 12)
# hr : 1,5 × 0,656 tuile par image, le rapport des bouches (largeur / hauteur à l'écran, 2,27 à 2,29 : cotes.py)
FEU_IMAGES, FEU_COLS, FEU_W, FEU_H = 16, 8, 96, 42
FEU_REF = (1.5, 0.65625)
COMMANDE = "py -3.9 tools/render/pieces/levels/four_e/feuilles.py   (depuis la racine du mod ; sources : " \
           "fo-logs/2026-10-25_F2/production/sprites, à GARDER)"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def lire_spec(src, nom):
    p = os.path.join(src, nom, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-FOUR] variante absente : %s (%s)" % (nom, p))
    return json.load(open(p, encoding="utf-8"))


def copie_variante(src, dest, nom, fichiers):
    s = lire_spec(src, nom)
    out = {}
    for k in COUCHES:
        L = s["layers"].get(k)
        if not L:
            continue
        hr_f, lr_f = L["file"], L["lr"]["file"]
        for f in (hr_f, lr_f):
            shutil.copyfile(os.path.join(src, nom, f), os.path.join(dest, f))
            fichiers.append(f)
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": L["width"], "height": L["height"],
                         "shift": [L["shift"][0], L["shift"][1]]},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": L["lr"]["width"], "height": L["lr"]["height"],
                         "shift": [L["lr"]["shift"][0], L["lr"]["shift"][1]]}}
    return s, out


def rect(c):
    h = c["hr"]
    w, ht = h["width"] / 64.0, h["height"] / 64.0
    return (h["shift"][0] - w / 2, h["shift"][1] - ht / 2, h["shift"][0] + w / 2, h["shift"][1] + ht / 2)


def icone(src, nom, dest, e, fichiers):
    s = lire_spec(src, nom)
    im = Image.open(os.path.join(src, nom, s["layers"]["main"]["file"])).convert("RGBA")
    a = np.asarray(im)
    ys, xs = np.nonzero(a[..., 3] > 8)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    arr = np.asarray(sq).astype(np.float64) / 255.0
    pm = arr.copy()
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
    f = "four-e%02d-icone.png" % e
    out.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)
    return {"filename": PREFIXE_JEU + f, "icon_size": 64, "icon_mipmaps": 4}


def couleur_carte(src, nom):
    s = lire_spec(src, nom)
    a = np.asarray(Image.open(os.path.join(src, nom, s["layers"]["main"]["file"])).convert("RGBA")).astype(np.float64)
    w = a[..., 3] / 255.0
    rgb = (a[..., :3] * w[..., None]).sum((0, 1)) / max(1e-6, w.sum()) / 255.0
    return [round(float(c), 3) for c in rgb]


def feu(dest, fichiers):
    """Feuille du feu animé : 16 images de flammes presque blanches (alpha = intensité), en boucle (phases entières),
    hr 96 × 64 px par image (1,5 × 1 tuile) ; normale réduite de moitié (additive : moyenne des intensités)."""
    rng = np.random.RandomState(20261025)
    langues = [(rng.uniform(0.08, 0.92), rng.uniform(0.05, 0.1), rng.uniform(0.45, 0.95), int(rng.randint(1, 3)),
                rng.uniform(0, 2 * math.pi)) for _ in range(9)]
    yy, xx = np.mgrid[0:FEU_H, 0:FEU_W]
    u = xx / (FEU_W - 1.0)
    v = 1.0 - yy / (FEU_H - 1.0)             # 0 en bas, 1 en haut
    feuille = np.zeros((FEU_H * (FEU_IMAGES // FEU_COLS), FEU_W * FEU_COLS, 4))
    for k in range(FEU_IMAGES):
        t = 2 * math.pi * k / FEU_IMAGES
        I = np.zeros((FEU_H, FEU_W))
        for (x0, larg, haut, freq, ph) in langues:
            h = haut * (0.75 + 0.25 * math.sin(freq * t + ph))
            dx = x0 + 0.03 * math.sin(freq * t + ph * 1.7) * v
            prof = np.exp(-((u - dx) / (larg * (1.1 - 0.7 * np.clip(v / max(h, 1e-3), 0, 1)))) ** 2)
            I += prof * np.clip(1.0 - v / max(h, 1e-3), 0, 1) ** 0.7
        I += 0.55 * np.exp(-((v - 0.04) / 0.08) ** 2)           # lit de braises
        I = np.clip(I / 1.4, 0, 1)
        c = np.stack([np.ones_like(I), 0.93 + 0.07 * I, 0.82 + 0.18 * I], -1)
        img = np.concatenate([c, I[..., None]], -1)
        r, col = divmod(k, FEU_COLS)
        feuille[r * FEU_H:(r + 1) * FEU_H, col * FEU_W:(col + 1) * FEU_W] = img
    hr = (np.clip(feuille, 0, 1) * 255).round().astype(np.uint8)
    Image.fromarray(hr, "RGBA").save(os.path.join(dest, "hr-four-feu.png"), optimize=True)
    lr_img = feuille.reshape(feuille.shape[0] // 2, 2, feuille.shape[1] // 2, 2, 4).mean((1, 3))
    Image.fromarray((np.clip(lr_img, 0, 1) * 255).round().astype(np.uint8), "RGBA").save(
        os.path.join(dest, "four-feu.png"), optimize=True)
    fichiers += ["hr-four-feu.png", "four-feu.png"]
    return {"hr": {"filename": PREFIXE_JEU + "hr-four-feu.png", "width": FEU_W, "height": FEU_H},
            "lr": {"filename": PREFIXE_JEU + "four-feu.png", "width": FEU_W // 2, "height": FEU_H // 2},
            "frame_count": FEU_IMAGES, "line_length": FEU_COLS, "ref_w": FEU_REF[0], "ref_h": FEU_REF[1]}


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    fichiers = []
    tab = {"feu": feu(a.dest, fichiers), "ages": {}}
    _, piece1 = copie_variante(a.src, a.dest, "e01-piece", fichiers)
    tab["ages"][1] = {"piece": piece1}
    for e in range(2, 16):
        s, socle = copie_variante(a.src, a.dest, "e%02d-socle" % e, fichiers)
        _, piece = copie_variante(a.src, a.dest, "e%02d-piece" % e, fichiers)
        rs = [rect(socle["main"]), rect(piece["main"])]
        boite = [[min(r[0] for r in rs), min(r[1] for r in rs)], [max(r[2] for r in rs), max(r[3] for r in rs)]]
        T = cotes.TAILLES[COTE[e]]
        G = T["gueule"]
        fx, fyn, fz = s["fumee"]
        foyer = list(ages.FOYER[e]["rgb"])
        m = max(foyer)
        tab["ages"][e] = {
            "socle": socle, "piece": piece, "boite": boite,
            "fumee": {"x": fx, "yn": fyn, "z": fz, "position": [round(fx, 4), round(-(fyn + K_PROJ * fz), 4)]},
            "fumee_nom": "turbine-smoke" if e in VAPEUR else "smoke",
            "gueule": {"x": 0.0, "y": round(-(G["y_face"] + K_PROJ * (G["zb"] + G["h"] / 2)), 4), "w": G["w"],
                       "h": round(G["h"] * K_PROJ, 4)},
            "foyer": [round(c, 4) for c in foyer],
            "teinte": [round(0.82 + 0.18 * c / m, 4) for c in foyer],
            "map_color": couleur_carte(a.src, "e%02d-socle" % e),
            "icone": icone(a.src, "e%02d-socle" % e, a.dest, e, fichiers),
        }
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/levels/four_e/feuilles.py (lot F2-B) : ne pas modifier à la\n"
              "-- main. Tailles en pixels, shift et positions en tuiles ; hr = 64 px par tuile (scale 0,5), normale = 32.\n"
              "-- Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + lua(tab) + "\n")
    with open(os.path.join(a.dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(tab, f, indent=1, sort_keys=True, ensure_ascii=False)
    man = {"commande": COMMANDE, "arguments": [], "sources": a.src, "fichiers": {}}
    total = 0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        w, h = Image.open(p).size
        n = os.path.getsize(p)
        total += n
        man["fichiers"][fn] = {"sha256": sha(p), "taille": n, "largeur": w, "hauteur": h}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-FOUR] %d fichiers PNG, %.2f Mo, sources %s" % (len(fichiers), total / 1e6, a.src))


if __name__ == "__main__":
    main()
