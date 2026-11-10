"""Lot MURS-2 (10/11) : feuilles des murs renforce et blinde (fo-reinforced-wall, fo-armored-wall).

Les murs gardent la GEOMETRIE exacte des pieces du mur vanilla (memes feuilles, memes variantes, memes raccords :
single, straight_vertical, straight_horizontal, corner_right_down, corner_left_down, t_up, ending_right, ending_left,
filling, water_connection_patch, gate_connection_patch), mais leur MATIERE est refaite dans la direction artistique des
tourelles et des titans : acier argent iridescent (#9FA8B8, reflet bleu-violet selon la hauteur), plus sombre et plus
bleu pour le blinde, et un LISERE de fonction juste sous l'arete superieure (cyan pour le renforce, magenta pour le
blinde, table MARQUES de marques.py), double d'une couche de lueur de nuit. Les ombres restent celles du vanilla.

Pas de rendu Blender : la geometrie des raccords de mur est celle du moteur (les pieces se recouvrent au pixel pres) ;
la refaire en 3D demandait un rendu par piece et par variante, hors du temps du sprint. Deterministe.

Usage : py -3.9 -B tools/render/pieces/batiments/murs.py <dossier data du jeu> <dossier du mod>
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marques import MARQUES  # noqa: E402

PIECES = ["wall-single", "wall-vertical", "wall-horizontal", "wall-corner-right", "wall-corner-left", "wall-t",
          "wall-ending-right", "wall-ending-left", "wall-filling", "wall-patch", "wall-gate"]
# pieces a couche de lueur : celles dont l'image du prototype est un calque (layers) ; filling et patchs : corps seul
LUEUR = {"wall-single", "wall-vertical", "wall-horizontal", "wall-corner-right", "wall-corner-left", "wall-t",
         "wall-ending-right", "wall-ending-left"}

MURS = {
    "fo-reinforced-wall": {"dossier": "renforce", "marque": "mur_renforce", "acier": (0.624, 0.659, 0.722), "sombre": 1.0},
    "fo-armored-wall": {"dossier": "blinde", "marque": "mur_blinde", "acier": (0.50, 0.56, 0.72), "sombre": 0.78},
}


def matiere(rgba, acier, sombre, lisere, hr):
    """Recolore une feuille vanilla : (corps RGBA, lueur RGBA, pixels du lisere)."""
    a = rgba[..., 3].astype(np.float32) / 255.0
    rgb = rgba[..., :3].astype(np.float32) / 255.0
    lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    op = a > 0.5
    if op.any():
        lo, hi = np.percentile(lum[op], 4), np.percentile(lum[op], 97)
    else:
        lo, hi = 0.0, 1.0
    ln = np.clip((lum - lo) / max(1e-3, hi - lo), 0, 1)
    h, w = lum.shape
    yy = (np.arange(h, dtype=np.float32) / max(1, h - 1))[:, None]
    irid = np.stack([0.96 + 0.08 * yy, 0.98 + 0.0 * yy, 1.04 - 0.02 * yy], axis=-1)
    irid = np.broadcast_to(irid, (h, w, 3))
    shade = (0.28 + 0.92 * ln)[..., None] * np.array(acier, np.float32)[None, None, :] * irid * sombre
    k1, k2 = (5, 9) if hr else (3, 5)
    band = np.zeros((h, w), bool)
    for x in range(w):
        col = np.nonzero(op[:, x])[0]
        if col.size < k2 + 4:
            continue
        top = col[0]
        band[top + k1:min(h, top + k2), x] = True
    band &= op
    lis = np.array(lisere, np.float32)
    out = np.array(shade)
    out[band] = 0.35 * out[band] + 0.65 * lis[None, :]
    corps = np.dstack([np.clip(out, 0, 1), a])
    lueur = np.zeros((h, w, 4), np.float32)
    lueur[band, :3] = lis
    lueur[band, 3] = a[band] * 0.9
    return (corps * 255 + 0.5).astype(np.uint8), (lueur * 255 + 0.5).astype(np.uint8), int(band.sum())


def main(data_dir, mod_dir):
    src = os.path.join(data_dir, "base", "graphics", "entity", "wall")
    sortie, rapport = {}, {}
    for nom in sorted(MURS):
        m = MURS[nom]
        lisere = MARQUES[m["marque"]]["lisere"]
        d = os.path.join(mod_dir, "graphics", "batiments", "murs", m["dossier"])
        os.makedirs(d, exist_ok=True)
        fichiers, lueurs, bandes = [], [], 0
        for p in PIECES:
            for pre, hr in (("", False), ("hr-", True)):
                f = pre + p + ".png"
                im = np.array(Image.open(os.path.join(src, f)).convert("RGBA"))
                corps, lueur, n = matiere(im, m["acier"], m["sombre"], lisere, hr)
                bandes += n
                Image.fromarray(corps, "RGBA").save(os.path.join(d, f), optimize=True)
                fichiers.append(f)
                if p in LUEUR:
                    g = pre + p + "-glow.png"
                    Image.fromarray(lueur, "RGBA").save(os.path.join(d, g), optimize=True)
                    lueurs.append(g)
        ic = np.array(Image.open(os.path.join(data_dir, "base", "graphics", "icons", "wall.png")).convert("RGBA"))
        icorps, _, _ = matiere(ic, m["acier"], m["sombre"], lisere, True)
        Image.fromarray(icorps, "RGBA").save(os.path.join(d, "icone.png"), optimize=True)
        base = "__factorio-overhaul__/graphics/batiments/murs/" + m["dossier"] + "/"
        sortie[nom] = {"dossier": base, "fichiers": sorted(fichiers), "lueurs": sorted(lueurs), "icone": base + "icone.png",
                       "map_color": [round(c * 0.8 * m["sombre"], 3) for c in m["acier"]], "lisere": list(lisere),
                       "marque": m["marque"]}
        rapport[nom] = {"feuilles": len(fichiers) + len(lueurs) + 1, "pixels_lisere": bandes}
    L = ["-- Genere par tools/render/pieces/batiments/murs.py (lot MURS-2) : ne pas editer a la main.", "return {"]
    for nom in sorted(sortie):
        s = sortie[nom]
        L.append('  ["%s"] = {' % nom)
        L.append('    dossier = "%s",' % s["dossier"])
        L.append("    fichiers = { " + ", ".join('["%s"] = true' % f for f in s["fichiers"]) + " },")
        L.append("    lueurs = { " + ", ".join('["%s"] = true' % f for f in s["lueurs"]) + " },")
        L.append('    icone = { filename = "%s", icon_size = 64, icon_mipmaps = 4 },' % s["icone"])
        L.append("    map_color = { %s }," % ", ".join(str(c) for c in s["map_color"]))
        L.append("    lisere = { %s }," % ", ".join("%.3f" % c for c in s["lisere"]))
        L.append('    marque = "%s",' % s["marque"])
        L.append("  },")
    L.append("}")
    with open(os.path.join(mod_dir, "graphics", "batiments", "murs", "sprites.lua"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(L) + "\n")
    with open(os.path.join(mod_dir, "graphics", "batiments", "murs", "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"generateur": "tools/render/pieces/batiments/murs.py", "murs": rapport}, fh, indent=1, sort_keys=True)
    print(json.dumps(rapport, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
