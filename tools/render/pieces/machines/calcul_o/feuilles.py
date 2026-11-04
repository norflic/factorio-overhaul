"""FEUILLES DE JEU des machines du calcul (lot CALCUL-DESIGN, 01/11) : des sorties de rendre.py (64 px par tuile) vers
graphics/machines/calcul/ : couches hr et normale, feuille des pièces mobiles, icône 64 px à 4 mipmaps, sprites.lua (GÉNÉRÉ, lu
par prototypes/calcul_visuels.lua), MANIFEST.json. PNG HORS de git (D-6), régénérés sans argument depuis les sources à GARDER.

    py -3.9 tools/render/pieces/machines/calcul_o/feuilles.py [--src DIR] [--dest DIR]
"""
import argparse
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, HERE)
import piece as PC  # noqa: E402

LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
SRC_DEFAUT = os.path.join(LOGS, "2026-11-01_CALCUL-DESIGN", "final")
DEST_DEFAUT = os.path.join(MOD, "graphics", "machines", "calcul")
PREFIXE = "__factorio-overhaul__/graphics/machines/calcul/"
COMMANDE = "py -3.9 tools/render/pieces/machines/calcul_o/feuilles.py   (depuis la racine du mod ; sources : " \
           "fo-logs/2026-11-01_CALCUL-DESIGN/final, à GARDER)"


def charge(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float64) / 255.0


def ecrit(a, p):
    u = np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8)
    u[u[..., 3] == 0, :3] = 0
    Image.fromarray(u, "RGBA").save(p, optimize=True, compress_level=9)


def pair(a):
    """Dimensions paires (la moitié tombe juste) : une ligne ou colonne vide à droite et en bas ; rend le décalage en pixels."""
    h, w = a.shape[:2]
    H, W = h + h % 2, w + w % 2
    if (H, W) == (h, w):
        return a, 0.0, 0.0
    out = np.zeros((H, W, 4))
    out[:h, :w] = a
    return out, (W - w) / 2.0, (H - h) / 2.0


def moitie(a):
    """Réduction ÷ 2 en prémultiplié."""
    h, w = a.shape[:2]
    p = a.copy()
    p[..., :3] *= p[..., 3:4]
    q = p[:h // 2 * 2, :w // 2 * 2].reshape(h // 2, 2, w // 2, 2, 4).mean((1, 3))
    al = np.maximum(q[..., 3:4], 1e-6)
    q[..., :3] = np.clip(q[..., :3] / al, 0, 1)
    return q


def reduit(a, W, H):
    p = a.copy()
    p[..., :3] *= p[..., 3:4]
    ims = []
    for c in range(4):
        ims.append(np.asarray(Image.fromarray((p[..., c]).astype(np.float32), "F").resize((W, H), Image.LANCZOS)))
    q = np.clip(np.stack(ims, -1), 0, 1)
    al = np.maximum(q[..., 3:4], 1e-6)
    q[..., :3] = np.clip(q[..., :3] / al, 0, 1)
    return q


def icone(main, glow, dest):
    """Icône : la machine (lueur ajoutée) dans 64 px, puis 32, 16, 8 à la suite (feuille 120 × 64, comme le vanilla)."""
    h, w = main.shape[:2]
    im = main.copy()
    if glow is not None:
        gh, gw = glow.shape[:2]
        if (gh, gw) == (h, w):
            im[..., :3] = np.clip(im[..., :3] + glow[..., :3] * glow[..., 3:4] * 0.6, 0, 1)
    k = 62.0 / max(w, h)
    W, H = max(1, int(w * k)), max(1, int(h * k))
    red = reduit(im, W, H)
    feuille = np.zeros((64, 120, 4))
    x = 0
    for s in (64, 32, 16, 8):
        wx, hx = max(1, W * s // 64), max(1, H * s // 64)
        r = reduit(red, wx, hx) if s != 64 else red
        ox, oy = x + (s - wx) // 2, (s - hx) // 2
        feuille[oy:oy + hx, ox:ox + wx] = r
        x += s
    ecrit(feuille, dest)


def table_lua(v, ind=0):
    pad = "  " * ind
    if isinstance(v, dict):
        out = ["{"]
        for k in sorted(v):
            key = "[%d]" % k if isinstance(k, int) else ('["%s"]' % k if "-" in k else k)
            out.append("%s  %s = %s," % (pad, key, table_lua(v[k], ind + 1)))
        out.append(pad + "}")
        return "\n".join(out)
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(table_lua(x, ind) for x in v) + " }"
    if isinstance(v, str):
        return '"%s"' % v
    return repr(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    table, fichiers, sources = {}, {}, 0

    def sauve(arr, nom):
        p = os.path.join(a.dest, nom)
        ecrit(arr, p)
        h = hashlib.sha256(open(p, "rb").read()).hexdigest()
        fichiers[nom] = {"sha256": h, "taille": os.path.getsize(p), "largeur": arr.shape[1], "hauteur": arr.shape[0]}

    for nom in sorted(PC.MACHINES):
        proto, age, cote = PC.MACHINES[nom][:3]
        d = os.path.join(a.src, nom)
        spec = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
        ent = {"age": age, "cote": cote, "couches": {}}
        mx0, my0, mx1, my1 = 99.0, 99.0, -99.0, -99.0
        for couche in ("main", "shadow", "glow"):
            s = spec["layers"].get(couche)
            if not s:
                continue
            sources += 1
            im, dw, dh = pair(charge(os.path.join(d, s["file"])))
            hr, lr = "hr-%s-%s.png" % (nom, couche), "%s-%s.png" % (nom, couche)
            sauve(im, hr)
            sauve(moitie(im), lr)
            sh = [s["shift"][0] + dw / 64.0, s["shift"][1] + dh / 64.0]
            ent["couches"][couche] = {"hr": {"filename": PREFIXE + hr, "width": im.shape[1], "height": im.shape[0], "shift": sh},
                                      "lr": {"filename": PREFIXE + lr, "width": im.shape[1] // 2, "height": im.shape[0] // 2, "shift": sh}}
            if couche != "shadow":
                mx0, my0 = min(mx0, sh[0] - im.shape[1] / 128.0), min(my0, sh[1] - im.shape[0] / 128.0)
                mx1, my1 = max(mx1, sh[0] + im.shape[1] / 128.0), max(my1, sh[1] + im.shape[0] / 128.0)
        s = spec["layers"].get("mobile")
        if s:
            sources += 1
            feuille = charge(os.path.join(d, s["file"]))
            n, w, h = s["images"], s["width"], s["height"]
            W2, H2 = w - w % 2, h - h % 2
            # une image : largeur paire ; la feuille entière garde n colonnes régulières
            cases = [feuille[:H2, k * w:k * w + W2] for k in range(n)]
            f = np.concatenate(cases, 1)
            hr, lr = "hr-%s-mobile.png" % nom, "%s-mobile.png" % nom
            sauve(f, hr)
            sauve(moitie(f), lr)
            ent["couches"]["mobile"] = {"images": n,
                                        "hr": {"filename": PREFIXE + hr, "width": W2, "height": H2, "shift": s["shift"]},
                                        "lr": {"filename": PREFIXE + lr, "width": W2 // 2, "height": H2 // 2, "shift": s["shift"]}}
        main_i = charge(os.path.join(d, spec["layers"]["main"]["file"]))
        g = spec["layers"].get("glow")
        glow_i = charge(os.path.join(d, g["file"])) if g and g["width"] == spec["layers"]["main"]["width"] and g["height"] == spec["layers"]["main"]["height"] else None
        ic = "icone-%s.png" % nom
        icone(main_i, glow_i, os.path.join(a.dest, ic))
        p = os.path.join(a.dest, ic)
        fichiers[ic] = {"sha256": hashlib.sha256(open(p, "rb").read()).hexdigest(), "taille": os.path.getsize(p), "largeur": 120, "hauteur": 64}
        ent["icone"] = {"icon": PREFIXE + ic, "icon_size": 64, "icon_mipmaps": 4}
        # couleur de carte : moyenne du corps
        al = main_i[..., 3:4]
        ent["map_color"] = [round(float(x), 3) for x in ((main_i[..., :3] * al).sum((0, 1)) / max(1.0, al.sum()))]
        ent["boite"] = [[round(mx0, 3), round(my0, 3)], [round(mx1, 3), round(my1, 3)]]
        table[proto] = ent

    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/render/pieces/machines/calcul_o/feuilles.py (lot CALCUL-DESIGN) : ne pas modifier à la main.\n")
        f.write("-- hr = 64 px par tuile (scale 0,5), normale = 32 ; shift en tuiles. Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
        f.write("return " + table_lua(table) + "\n")
    total = sum(x["taille"] for x in fichiers.values())
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"commande": COMMANDE, "fichiers": fichiers, "machines": len(table), "sources": sources}, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-CALCUL] %d machines, %d fichiers PNG, %.2f Mo, %d sources" % (len(table), len(fichiers), total / 1e6, sources))


if __name__ == "__main__":
    main()
