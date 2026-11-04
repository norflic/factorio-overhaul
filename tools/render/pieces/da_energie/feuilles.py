"""FEUILLES DE JEU DU LOT DA-ENERGIE (4/11) : piscine d'entreposage, dépôt géologique, amplificateur de résonance (puis
réacteur à sels fondus et capteur géothermique) -> graphics/da/energie/ (PNG hors de git, décision D-6), sprites.lua (généré,
lu par prototypes/da_energie.lua), sprites.json et MANIFEST.json.

    py -3.9 tools/render/pieces/da_energie/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-11-04_DA-ENERGIE/final/<variante> (à GARDER : rendus à 256 échantillons validés par la
critique, CRITIQUE.md). Par bâtiment : couches principale, ombre, lueur ; images des pièces mobiles (une rangée, ramenées à
des côtés pairs pour la réduction) et leur lueur ; flaque de lumière dessinée ici (draw_as_light : projecteur du dépôt, halo
teinté par les modules de l'amplificateur) ; hr (64 px par tuile) copiée telle quelle, normale (32 px par tuile) réduite de
moitié en alpha prémultiplié ; boîte de dessin, couleur de carte, icône à 4 mipmaps.
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
SRC_DEFAUT = os.path.join(LOGS, "2026-11-04_DA-ENERGIE", "final")
DEST_DEFAUT = os.path.join(MOD, "graphics", "da", "energie")
PREFIXE_JEU = "__factorio-overhaul__/graphics/da/energie/"
COMMANDE = "py -3.9 tools/render/pieces/da_energie/feuilles.py   (depuis la racine du mod ; sources : " \
           "fo-logs/2026-11-04_DA-ENERGIE/final, à GARDER)"
# bâtiment : variante retenue (CRITIQUE.md), flaque de lumière (centre et demi-axes en tuiles, couleur) ou None
BATIMENTS = {
    "piscine": {"variante": "piscine_c", "lumiere": None},
    "depot": {"variante": "depot_a", "lumiere": {"centre": (0.35, -0.3), "axes": (1.05, 0.78), "couleur": (1.0, 0.9, 0.72)}},
    "reso": {"variante": "reso_c", "lumiere": {"centre": (0.0, -0.15), "axes": (1.7, 1.25), "couleur": (1.0, 1.0, 1.0)}},
    # réacteur : heat_picture = SEULE la lueur du collecteur rendu chauffé (msr_h, couche glow), jamais son main
    # chaleur_force : la capture en moteur (4/11, 800 °C) montrait un cadre pêche plein de jour : alpha × 0,5
    "msr": {"variante": "msr_a", "lumiere": None, "chaleur": "msr_h", "chaleur_force": 0.5},
    # capteur : une base par direction de pose ; icône de la direction sud
    "geo": {"directions": {"north": "geo_n", "east": "geo_e", "south": "geo_s", "west": "geo_w"}, "icone": "south", "lumiere": None},
}
COUCHES = ("main", "shadow", "glow")

_spec = importlib.util.spec_from_file_location("qg_feuilles", os.path.join(HERE, "..", "levels", "qg_e", "feuilles.py"))
Q = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(Q)


def _ecrit(im, dest, f, fichiers):
    if max(im.size) > 8192:
        raise SystemExit("[FO-FEUILLES-DA-ENERGIE] %s dépasse 8 192 px (F144)" % f)
    im.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)


def couche_seule(src, dest, cle, var, k, nom, fichiers, force=1.0):
    """Une seule couche d'une variante rendue à part (chaleur du réacteur : la couche glow de msr_h) ; force : × alpha."""
    s = json.load(open(os.path.join(src, var, "spec.json"), encoding="utf-8"))
    c = s["layers"][k]
    im = Image.open(os.path.join(src, var, c["file"])).convert("RGBA")
    if force != 1.0:
        a = np.asarray(im).astype(np.float64)
        a[..., 3] = np.clip(a[..., 3] * force, 0, 255)
        im = Image.fromarray(a.round().astype(np.uint8), "RGBA")
    hr_f, lr_f = "hr-%s-%s.png" % (cle, nom), "%s-%s.png" % (cle, nom)
    _ecrit(im, dest, hr_f, fichiers)
    lr = Q.reduite(im)
    _ecrit(lr, dest, lr_f, fichiers)
    sh = [c["shift"][0], c["shift"][1]]
    return {"hr": {"filename": PREFIXE_JEU + hr_f, "width": im.size[0], "height": im.size[1], "shift": sh},
            "lr": {"filename": PREFIXE_JEU + lr_f, "width": lr.size[0], "height": lr.size[1], "shift": sh}}


def couches(src, dest, cle, var, fichiers):
    p = os.path.join(src, var, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-DA-ENERGIE] %s absente : %s" % (var, p))
    s = json.load(open(p, encoding="utf-8"))
    out = {}
    for k in COUCHES:
        c = s["layers"].get(k)
        if not c:
            continue
        im = Image.open(os.path.join(src, var, c["file"])).convert("RGBA")
        if im.size != (c["width"], c["height"]):
            raise SystemExit("[FO-FEUILLES-DA-ENERGIE] %s : %s fait %s, spec.json %dx%d" % (var, c["file"], im.size, c["width"], c["height"]))
        hr_f, lr_f = "hr-%s-%s.png" % (cle, k), "%s-%s.png" % (cle, k)
        _ecrit(im, dest, hr_f, fichiers)
        lr = Q.reduite(im)
        _ecrit(lr, dest, lr_f, fichiers)
        sh = [c["shift"][0], c["shift"][1]]
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": im.size[0], "height": im.size[1], "shift": sh},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": lr.size[0], "height": lr.size[1], "shift": sh}}
    if "main" not in out:
        raise SystemExit("[FO-FEUILLES-DA-ENERGIE] %s sans couche principale" % var)
    for k in ("mobile", "mobile_glow"):
        c = s["layers"].get(k)
        if c:
            out[k] = images(src, dest, cle, var, k, c, fichiers)
    return out


def images(src, dest, cle, var, k, c, fichiers):
    """Rangée d'images d'une pièce mobile : chaque image ramenée à des côtés PAIRS (une colonne ou une ligne transparente à
    droite ou en bas ; shift corrigé d'une demi-colonne), réduite image par image (aucun mélange entre voisines)."""
    sheet = Image.open(os.path.join(src, var, c["file"])).convert("RGBA")
    n, w, h = c["images"], c["width"], c["height"]
    if sheet.size != (n * w, h):
        raise SystemExit("[FO-FEUILLES-DA-ENERGIE] %s : %s fait %s, attendu %dx%d" % (var, c["file"], sheet.size, n * w, h))
    w2, h2 = w + (w % 2), h + (h % 2)
    hr = Image.new("RGBA", (n * w2, h2), (0, 0, 0, 0))
    lr = Image.new("RGBA", (n * w2 // 2, h2 // 2), (0, 0, 0, 0))
    for i in range(n):
        fr = Image.new("RGBA", (w2, h2), (0, 0, 0, 0))
        fr.paste(sheet.crop((i * w, 0, (i + 1) * w, h)), (0, 0))
        hr.paste(fr, (i * w2, 0))
        lr.paste(Q.reduite(fr), (i * w2 // 2, 0))
    sh = [c["shift"][0] + (w2 - w) / 128.0, c["shift"][1] + (h2 - h) / 128.0]
    suffixe = k.replace("_", "-")
    hr_f, lr_f = "hr-%s-%s.png" % (cle, suffixe), "%s-%s.png" % (cle, suffixe)
    _ecrit(hr, dest, hr_f, fichiers)
    _ecrit(lr, dest, lr_f, fichiers)
    return {"images": n, "hr": {"filename": PREFIXE_JEU + hr_f, "width": w2, "height": h2, "shift": sh},
            "lr": {"filename": PREFIXE_JEU + lr_f, "width": w2 // 2, "height": h2 // 2, "shift": sh}}


def lumiere(dest, cle, L, fichiers):
    """Flaque de lumière (draw_as_light) : ellipse à bord doux, centre et demi-axes en tuiles ; pic 0,75."""
    ax, ay = L["axes"]
    W, H = int(round(ax * 2 * 64)) // 2 * 2, int(round(ay * 2 * 64)) // 2 * 2
    yy, xx = np.mgrid[0:H, 0:W]
    u = (xx + 0.5 - W / 2.0) / (W / 2.0)
    v = (yy + 0.5 - H / 2.0) / (H / 2.0)
    r = np.sqrt(u * u + v * v)
    a = np.clip(1.0 - r, 0.0, 1.0) ** 1.6 * 0.75
    rgb = np.ones((H, W, 3)) * np.array(L["couleur"])
    im = Image.fromarray((np.concatenate([rgb, a[..., None]], -1) * 255).round().astype(np.uint8), "RGBA")
    hr_f, lr_f = "hr-%s-lumiere.png" % cle, "%s-lumiere.png" % cle
    _ecrit(im, dest, hr_f, fichiers)
    lr = Q.reduite(im)
    _ecrit(lr, dest, lr_f, fichiers)
    sh = [L["centre"][0], L["centre"][1]]
    return {"hr": {"filename": PREFIXE_JEU + hr_f, "width": W, "height": H, "shift": sh},
            "lr": {"filename": PREFIXE_JEU + lr_f, "width": lr.size[0], "height": lr.size[1], "shift": sh}}


def couleur_moyenne(dest, cle):
    a = np.asarray(Image.open(os.path.join(dest, "hr-%s-main.png" % cle)).convert("RGBA")).astype(np.float64)
    w = a[..., 3] / 255.0
    rgb = (a[..., :3] * w[..., None]).sum((0, 1)) / max(1e-6, w.sum()) / 255.0
    return [round(float(c), 3) for c in rgb]


def icone(dest, cle, fichiers):
    """Icône 64 px à 4 mipmaps (64 + 32 + 16 + 8), réduite de la couche principale (et de la 1re image mobile)."""
    im = Image.open(os.path.join(dest, "hr-%s-main.png" % cle)).convert("RGBA")
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
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--batiments", default=",".join(BATIMENTS))
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    fichiers = []
    tab = {}
    mpx = 0.0
    for cle in [b for b in a.batiments.split(",") if b]:
        b = BATIMENTS[cle]
        if "directions" in b:
            dirs = {d: couches(a.src, a.dest, "%s-%s" % (cle, d), v, fichiers) for d, v in sorted(b["directions"].items())}
            c = {"directions": dirs}
            rs = [rect(v) for dd in dirs.values() for k, v in dd.items() if k in ("main", "shadow", "glow")]
            c["boite"] = [[round(min(r[0] for r in rs), 4), round(min(r[1] for r in rs), 4)],
                          [round(max(r[2] for r in rs), 4), round(max(r[3] for r in rs), 4)]]
            for dd in dirs.values():
                for k in ("main", "glow"):
                    if k in dd:
                        mpx += dd[k]["hr"]["width"] * dd[k]["hr"]["height"] / 1e6
            ic = "%s-%s" % (cle, b["icone"])
            c["map_color"] = couleur_moyenne(a.dest, ic)
            c["icone"] = icone(a.dest, ic, fichiers)
            c["variante"] = ",".join(v for _, v in sorted(b["directions"].items()))
            tab[cle] = c
            continue
        c = couches(a.src, a.dest, cle, b["variante"], fichiers)
        if b["lumiere"]:
            c["lumiere"] = lumiere(a.dest, cle, b["lumiere"], fichiers)
        if b.get("chaleur"):
            c["chaleur"] = couche_seule(a.src, a.dest, cle, b["chaleur"], "glow", "chaleur", fichiers, b.get("chaleur_force", 1.0))
        rs = [rect(v) for k, v in c.items() if k in ("main", "shadow", "glow", "mobile", "mobile_glow", "chaleur", "lumiere")]
        c["boite"] = [[round(min(r[0] for r in rs), 4), round(min(r[1] for r in rs), 4)],
                      [round(max(r[2] for r in rs), 4), round(max(r[3] for r in rs), 4)]]
        for k in ("main", "glow", "mobile", "mobile_glow", "lumiere", "chaleur"):
            if k in c:
                mpx += c[k]["hr"]["width"] * c[k]["hr"]["height"] * c[k].get("images", 1) / 1e6
        c["map_color"] = couleur_moyenne(a.dest, cle)
        c["icone"] = icone(a.dest, cle, fichiers)
        c["variante"] = b["variante"]
        tab[cle] = c
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/da_energie/feuilles.py (lot DA-ENERGIE) : ne pas modifier à la main.\n"
              "-- Tailles en pixels, shift et boîtes en tuiles ; hr = 64 px par tuile (scale 0,5), normale = 32 ; « images » :\n"
              "-- nombre d'images d'une rangée (pièce mobile). Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + Q.lua(tab) + "\n")
    with open(os.path.join(a.dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(tab, f, indent=1, sort_keys=True, ensure_ascii=False)
    man = {"commande": COMMANDE, "arguments": [], "sources": a.src, "fichiers": {}}
    total = 0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        w, h = Image.open(p).size
        n = os.path.getsize(p)
        total += n
        man["fichiers"][fn] = {"sha256": Q.sha(p), "taille": n, "largeur": w, "hauteur": h}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-DA-ENERGIE] %d fichiers PNG, %.2f Mo, %.2f Mpx HR (principale, lueur, images, lumière), sources %s"
          % (len(fichiers), total / 1e6, mpx, a.src))


if __name__ == "__main__":
    main()
