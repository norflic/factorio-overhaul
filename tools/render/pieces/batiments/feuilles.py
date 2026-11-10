"""FEUILLES DE JEU DU KIT batiments (lot POLISSAGE-FX, 10/11) : coffre d'équipe, pylône haute tension, cuve d'électrolyse ->
graphics/batiments/ (PNG hors de git, D-6), sprites.lua (généré, lu par prototypes/batiments_visuels.lua), sprites.json, MANIFEST.json.

    py -3.9 tools/render/pieces/batiments/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-11-10_POLISSAGE-FX/rendu/<bâtiment> (à GARDER). Par bâtiment : couches principale, ombre, lueur ;
hr (64 px par tuile) copiée telle quelle, normale (32 px par tuile) réduite de moitié en alpha prémultiplié (Q.reduite du kit QG) ; boîte
de dessin, couleur de carte, icône à 4 mipmaps ; pylône : ANCRAGES des fils (pixels HR relatifs au pied -> tuiles, fil et ombre).
"""
import argparse
import importlib.util
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
SRC_DEFAUT = os.path.join(LOGS, "2026-11-10_POLISSAGE-FX", "rendu")
SRC_TOURELLES = os.path.join(LOGS, "2026-11-10_POLISSAGE-2", "rendu")
SRC_TETES = os.path.join(LOGS, "2026-11-10_POLISSAGE-3", "rendu")
DEST_DEFAUT = os.path.join(MOD, "graphics", "batiments")
PREFIXE_JEU = "__factorio-overhaul__/graphics/batiments/"
COMMANDE = ("py -3.9 tools/render/pieces/batiments/feuilles.py   (depuis la racine du mod ; sources : fo-logs/2026-11-10_POLISSAGE-FX/rendu "
            "fo-logs/2026-11-10_POLISSAGE-2/rendu et fo-logs/2026-11-10_POLISSAGE-3/rendu, à GARDER)")
BATIMENTS = ("coffre", "pylone", "cuve", "bastion2", "bastion3", "bastion4", "tesla", "laser_lourd", "bastion1", "lourde", "canon", "mortier")
# lot POLISSAGE-2 : tourelles électriques à tête non tournante ; leur lueur devient une bande de PULSE images (facteurs d'intensité
# précalculés, onde triangulaire : aucune trigonométrie), lue par prototypes/batiments_visuels.lua (têtes : direction_count 1)
TOURELLES = ("bastion2", "bastion3", "bastion4", "tesla", "laser_lourd")
PULSE = (0.5, 0.62, 0.76, 0.9, 1.0, 0.9, 0.76, 0.62)
# lot POLISSAGE-3 : tourelles à munitions, TÊTE TOURNANTE à 64 directions (rendre_tetes.py : 4 bandes de 16 directions × IMAGES colonnes
# par couche, dossier <src>/<cle>-tete) ; normale : chaque image réduite de moitié À PART (aucun débord d'une image sur sa voisine)
TETES = ("bastion1", "lourde", "canon", "mortier")
DIR_ICONE = 8      # direction de la tête dans l'icône (nord-est)
SOURCES = {b: (SRC_TETES if b in TETES else (SRC_TOURELLES if b in TOURELLES else SRC_DEFAUT)) for b in BATIMENTS}
COUCHES = ("main", "shadow", "glow")

_spec = importlib.util.spec_from_file_location("qg_feuilles", os.path.join(HERE, "..", "levels", "qg_e", "feuilles.py"))
Q = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(Q)


def _ecrit(im, dest, f, fichiers):
    if max(im.size) > 8192:
        raise SystemExit("[FO-FEUILLES-BATIMENTS] %s dépasse 8 192 px (F144)" % f)
    im.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)


def couches(src, dest, cle, fichiers):
    p = os.path.join(src, cle, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-BATIMENTS] %s absent : %s" % (cle, p))
    s = json.load(open(p, encoding="utf-8"))
    out = {}
    for k in COUCHES:
        c = s["layers"].get(k)
        if not c:
            continue
        im = Image.open(os.path.join(src, cle, c["file"])).convert("RGBA")
        if im.size != (c["width"], c["height"]):
            raise SystemExit("[FO-FEUILLES-BATIMENTS] %s : %s fait %s, spec.json %dx%d" % (cle, c["file"], im.size, c["width"], c["height"]))
        hr_f, lr_f = "hr-%s-%s.png" % (cle, k), "%s-%s.png" % (cle, k)
        _ecrit(im, dest, hr_f, fichiers)
        lr = Q.reduite(im)
        _ecrit(lr, dest, lr_f, fichiers)
        sh = [c["shift"][0], c["shift"][1]]
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": im.size[0], "height": im.size[1], "shift": sh},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": lr.size[0], "height": lr.size[1], "shift": sh}}
    if "main" not in out:
        raise SystemExit("[FO-FEUILLES-BATIMENTS] %s sans couche principale" % cle)
    anc = s.get("ancrages") or {}
    if anc:
        out["ancrages"] = {n: {"fil": [round(v["fil"][0] / 64.0, 4), round(v["fil"][1] / 64.0, 4)],
                               "ombre": [round(v["ombre"][0] / 64.0, 4), round(v["ombre"][1] / 64.0, 4)]} for n, v in sorted(anc.items())}
    return out


def pulse(src, dest, cle, c, fichiers):
    """Bande de len(PULSE) images de la lueur (hr et normale), intensité × facteur (alpha prémultiplié : la lueur additive baisse)."""
    g = c.get("glow")
    if not g:
        raise SystemExit("[FO-FEUILLES-BATIMENTS] %s : tourelle sans lueur" % cle)
    out = {}
    for res in ("hr", "lr"):
        p = os.path.join(dest, os.path.basename(g[res]["filename"]))
        a = np.asarray(Image.open(p).convert("RGBA")).astype(np.float64)
        imgs = []
        for f in PULSE:
            b = a.copy()
            b[..., 3] = b[..., 3] * f
            imgs.append(b)
        strip = Image.fromarray(np.concatenate(imgs, 1).round().astype(np.uint8), "RGBA")
        fn = ("hr-%s-pulse.png" if res == "hr" else "%s-pulse.png") % cle
        _ecrit(strip, dest, fn, fichiers)
        out[res] = {"filename": PREFIXE_JEU + fn, "width": a.shape[1], "height": a.shape[0], "shift": list(g[res]["shift"]),
                    "frame_count": len(PULSE), "line_length": len(PULSE)}
    return out


def tete(src, dest, cle, fichiers):
    """Bandes de la tête tournante : hr copiées telles quelles, normale réduite IMAGE PAR IMAGE (Q.reduite), mêmes bandes."""
    p = os.path.join(src, cle + "-tete", "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-BATIMENTS] tête de %s absente : %s" % (cle, p))
    s = json.load(open(p, encoding="utf-8"))
    ni, rangs = s["images"], s["rangs"]
    out = {"images": ni, "rangs": rangs, "directions": s["directions"], "bouche": s["bouche"]}
    for k in COUCHES:
        c = s["layers"].get(k)
        if not c:
            raise SystemExit("[FO-FEUILLES-BATIMENTS] tête de %s sans couche %s" % (cle, k))
        w, h = c["width"], c["height"]
        if w % 2 or h % 2:
            raise SystemExit("[FO-FEUILLES-BATIMENTS] tête de %s : image %dx%d impaire" % (cle, w, h))
        hr_l, lr_l = [], []
        for i, f in enumerate(c["files"]):
            im = Image.open(os.path.join(src, cle + "-tete", f["file"])).convert("RGBA")
            if im.size != (w * ni, h * rangs):
                raise SystemExit("[FO-FEUILLES-BATIMENTS] %s : %s fait %s, attendu %dx%d" % (cle, f["file"], im.size, w * ni, h * rangs))
            hr_f, lr_f = "hr-%s-tete-%s-%d.png" % (cle, k, i + 1), "%s-tete-%s-%d.png" % (cle, k, i + 1)
            _ecrit(im, dest, hr_f, fichiers)
            lr = Image.new("RGBA", (w // 2 * ni, h // 2 * rangs), (0, 0, 0, 0))
            for r in range(rangs):
                for j in range(ni):
                    lr.paste(Q.reduite(im.crop((j * w, r * h, (j + 1) * w, (r + 1) * h))), (j * w // 2, r * h // 2))
            _ecrit(lr, dest, lr_f, fichiers)
            hr_l.append(PREFIXE_JEU + hr_f)
            lr_l.append(PREFIXE_JEU + lr_f)
        sh = [c["shift"][0], c["shift"][1]]
        out[k] = {"hr": {"stripes": hr_l, "width": w, "height": h, "shift": sh},
                  "lr": {"stripes": lr_l, "width": w // 2, "height": h // 2, "shift": sh}}
    return out


def vue_tete(dest, c, k, direction, image=0):
    """Image (hr) d'une direction de la tête : couche k."""
    t = c["tete"][k]["hr"]
    rangs = c["rangs"]
    b, r = divmod(direction, rangs)
    im = Image.open(os.path.join(dest, os.path.basename(t["stripes"][b]))).convert("RGBA")
    w, h = t["width"], t["height"]
    return im.crop((image * w, r * h, (image + 1) * w, (r + 1) * h)), t["shift"]


def couleur_moyenne(dest, cle):
    a = np.asarray(Image.open(os.path.join(dest, "hr-%s-main.png" % cle)).convert("RGBA")).astype(np.float64)
    w = a[..., 3] / 255.0
    rgb = (a[..., :3] * w[..., None]).sum((0, 1)) / max(1e-6, w.sum()) / 255.0
    return [round(float(c), 3) for c in rgb]


def icone(dest, cle, fichiers, c=None):
    """Icône 64 px à 4 mipmaps (64 + 32 + 16 + 8), réduite de la couche principale (tourelle à tête tournante : socle + tête, DIR_ICONE)."""
    im = Image.open(os.path.join(dest, "hr-%s-main.png" % cle)).convert("RGBA")
    if c is not None and "tete" in c:
        t, sh_t = vue_tete(dest, c, "main", DIR_ICONE)
        sh_s = c["main"]["hr"]["shift"]
        x0 = min(sh_s[0] * 64 - im.width / 2.0, sh_t[0] * 64 - t.width / 2.0)
        y0 = min(sh_s[1] * 64 - im.height / 2.0, sh_t[1] * 64 - t.height / 2.0)
        x1 = max(sh_s[0] * 64 + im.width / 2.0, sh_t[0] * 64 + t.width / 2.0)
        y1 = max(sh_s[1] * 64 + im.height / 2.0, sh_t[1] * 64 + t.height / 2.0)
        cv = Image.new("RGBA", (int(round(x1 - x0)), int(round(y1 - y0))), (0, 0, 0, 0))
        for part, sh in ((im, sh_s), (t, sh_t)):
            cv.alpha_composite(part, (int(round(sh[0] * 64 - part.width / 2.0 - x0)), int(round(sh[1] * 64 - part.height / 2.0 - y0))))
        im = cv
    a = np.asarray(im)
    ys, xs = np.nonzero(a[..., 3] > 8)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    arr = np.asarray(sq).astype(np.float64) / 255.0
    arr[..., :3] *= arr[..., 3:4]
    base = Image.fromarray((arr * 255).round().astype(np.uint8), "RGBA")
    out = Image.new("RGBA", (64 + 32 + 16 + 8, 64), (0, 0, 0, 0))
    x = 0
    for t in (64, 32, 16, 8):
        r = np.asarray(base.resize((t, t), Image.LANCZOS)).astype(np.float64) / 255.0
        al = np.clip(r[..., 3:4], 1e-6, 1)
        rgb = np.where(r[..., 3:4] > 1e-4, r[..., :3] / al, 0)
        u = np.concatenate([np.clip(rgb, 0, 1), r[..., 3:4]], -1)
        out.paste(Image.fromarray((u * 255).round().astype(np.uint8), "RGBA"), (x, 0))
        x += t
    f = "%s-icone.png" % cle
    out.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)
    return {"filename": PREFIXE_JEU + f, "icon_size": 64, "icon_mipmaps": 4}


def rect(c):
    h = c["hr"]
    w, ht = h["width"] / 64.0, h["height"] / 64.0
    return (h["shift"][0] - w / 2, h["shift"][1] - ht / 2, h["shift"][0] + w / 2, h["shift"][1] + ht / 2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="", help="une seule source pour tous (défaut : SOURCES par bâtiment)")
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--batiments", default=",".join(BATIMENTS))
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    fichiers, tab, mpx = [], {}, 0.0
    for cle in [b for b in a.batiments.split(",") if b]:
        src = a.src or SOURCES[cle]
        c = couches(src, a.dest, cle, fichiers)
        if cle in TOURELLES:
            c["pulse"] = pulse(src, a.dest, cle, c, fichiers)
        if cle in TETES:
            c["tete"] = tete(src, a.dest, cle, fichiers)
            c["images"], c["rangs"], c["directions"] = c["tete"].pop("images"), c["tete"].pop("rangs"), c["tete"].pop("directions")
            c["bouche"] = c["tete"].pop("bouche")
        rs = [rect(v) for k, v in c.items() if k in ("main", "shadow", "glow")]
        if "tete" in c:
            rs += [rect(v) for v in c["tete"].values()]
        c["boite"] = [[round(min(r[0] for r in rs), 4), round(min(r[1] for r in rs), 4)],
                      [round(max(r[2] for r in rs), 4), round(max(r[3] for r in rs), 4)]]
        for k in ("main", "glow"):
            if k in c:
                mpx += c[k]["hr"]["width"] * c[k]["hr"]["height"] / 1e6
            if "tete" in c:
                mpx += c["tete"][k]["hr"]["width"] * c["tete"][k]["hr"]["height"] * c["images"] * c["directions"] / 1e6
        c["map_color"] = couleur_moyenne(a.dest, cle)
        c["icone"] = icone(a.dest, cle, fichiers, c)
        tab[cle] = c
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/batiments/feuilles.py (lot POLISSAGE-FX) : ne pas modifier à la main.\n"
              "-- Tailles en pixels, shift, boîtes et ancrages en tuiles ; hr = 64 px par tuile (scale 0,5), normale = 32.\n"
              "-- Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + Q.lua(tab) + "\n")
    with open(os.path.join(a.dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(tab, f, indent=1, sort_keys=True, ensure_ascii=False)
    man = {"commande": COMMANDE, "sources": a.src or sorted(set(SOURCES.values())), "fichiers": {}}
    total = 0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        w, h = Image.open(p).size
        n = os.path.getsize(p)
        total += n
        man["fichiers"][fn] = {"sha256": Q.sha(p), "taille": n, "largeur": w, "hauteur": h}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-BATIMENTS] %d fichiers PNG, %.2f Mo, %.2f Mpx HR (principale, lueur), sources %s" % (len(fichiers), total / 1e6, mpx,
          a.src or sorted(set(SOURCES.values()))))


if __name__ == "__main__":
    main()
