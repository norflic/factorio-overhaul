"""FEUILLES DE JEU DE LA FAMILLE MÉTALLURGIE (lot DA-METALLURGIE, phase 3, 4/11) -> graphics/metallurgie/ (PNG hors de git,
décision D-6), sprites.lua (généré, lu par prototypes/metallurgie_machines.lua), sprites.json et MANIFEST.json.

    py -3.9 tools/render/pieces/metallurgie/feuilles.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut : fo-logs/2026-11-04_DA-METALLURGIE/final/<variante> (rendus à 256 échantillons des variantes retenues par la
critique, À GARDER). Par machine : couches principale, ombre, lueur ; hr (64 px par tuile) copiée telle quelle, normale (32 px par
tuile) réduite de moitié en alpha prémultiplié ; boîte de dessin, couleur de carte, icône 64 px à 4 mipmaps. Le pylône a 4 directions
(tête tournée, 4 images d'une rangée, même cadre et même shift) et ses points de fil (fils_py.py). Mêmes règles que
usines_robots/feuilles.py ; fonctions d'image de levels/qg_e/feuilles.py.
"""
import argparse
import importlib.util
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
SRC_DEFAUT = os.path.join(LOGS, "2026-11-04_DA-METALLURGIE", "final")
DEST_DEFAUT = os.path.join(MOD, "graphics", "metallurgie")
PREFIXE_JEU = "__factorio-overhaul__/graphics/metallurgie/"
COUCHES = ("main", "shadow", "glow")
# entité : variante(s) retenue(s) par la critique ; le pylône : 4 directions du moteur (0 à 3)
MACHINES = {"fo-blast-furnace": "hf_b", "fo-coke-oven": "co_b", "fo-kroll-reactor": "kr_b", "fo-ore-concentrator": "cc_b"}
POTEAUX = {"fo-ht-pylon": ("py_c", "py_c1", "py_c2", "py_c3")}
# la cuve d'électrolyse n'entre que validée par la critique : --avec-cuve (variante rc_a)
CUVE = {"fo-reduction-cell": "rc_a"}
COMMANDE = "py -3.9 tools/render/pieces/metallurgie/feuilles.py   (depuis la racine du mod ; sources : " \
           "fo-logs/2026-11-04_DA-METALLURGIE/final, à GARDER)"

_spec = importlib.util.spec_from_file_location("qg_feuilles", os.path.join(HERE, "..", "levels", "qg_e", "feuilles.py"))
Q = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(Q)
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fils_py as F  # noqa: E402


def lua(v, ind=0):
    """Table Lua lisible ; clés non identifiantes entre crochets (noms d'entités à tirets)."""
    p = "  " * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        out = []
        for k in sorted(v, key=lambda k: (isinstance(k, str), k)):
            if isinstance(k, int):
                kk = "[%d]" % k
            elif k.replace("_", "a").isalnum() and not k[0].isdigit():
                kk = k
            else:
                kk = "[%s]" % json.dumps(k)
            out.append("%s  %s = %s" % (p, kk, lua(v[k], ind + 1)))
        return "{\n" + ",\n".join(out) + "\n" + p + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x, ind + 1) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(v, 6)) if isinstance(v, float) else str(v)
    return json.dumps(v, ensure_ascii=False)


def spec_de(src, nom):
    p = os.path.join(src, nom, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("[FO-FEUILLES-METAL] %s absente : %s" % (nom, p))
    return json.load(open(p, encoding="utf-8"))


def ecrire(im, dest, base, fichiers):
    if max(im.size) > 8192:
        raise SystemExit("[FO-FEUILLES-METAL] %s dépasse 8 192 px (F144)" % base)
    hr_f, lr_f = "hr-%s.png" % base, "%s.png" % base
    im.save(os.path.join(dest, hr_f), optimize=True)
    lr = Q.reduite(im)
    lr.save(os.path.join(dest, lr_f), optimize=True)
    fichiers.extend([hr_f, lr_f])
    return hr_f, lr_f, lr


def copie(src, dest, entite, nom, fichiers):
    s = spec_de(src, nom)
    out = {}
    for k in COUCHES:
        c = s["layers"].get(k)
        if not c:
            continue
        im = Image.open(os.path.join(src, nom, c["file"])).convert("RGBA")
        if im.size != (c["width"], c["height"]):
            raise SystemExit("[FO-FEUILLES-METAL] %s : %s fait %s, spec.json %dx%d" % (nom, c["file"], im.size, c["width"], c["height"]))
        hr_f, lr_f, lr = ecrire(im, dest, "%s-%s" % (entite, k), fichiers)
        sh = [c["shift"][0], c["shift"][1]]
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": im.size[0], "height": im.size[1], "shift": sh},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": lr.size[0], "height": lr.size[1], "shift": sh}}
    if "main" not in out:
        raise SystemExit("[FO-FEUILLES-METAL] %s sans couche principale" % nom)
    return out


def copie_directions(src, dest, entite, noms, fichiers):
    """Les N directions d'une couche dans UNE rangée : même cadre (union des cadres, côtés pairs), même shift."""
    specs = [spec_de(src, n) for n in noms]
    out = {}
    for k in COUCHES:
        cs = [s["layers"].get(k) for s in specs]
        if not all(cs):
            continue
        # coin haut-gauche de chaque image en px HR relatifs à l'entité
        boites = []
        for c in cs:
            x0 = c["shift"][0] * 64 - c["width"] / 2.0
            y0 = c["shift"][1] * 64 - c["height"] / 2.0
            boites.append((x0, y0, x0 + c["width"], y0 + c["height"]))
        X0 = int(np.floor(min(b[0] for b in boites)))
        Y0 = int(np.floor(min(b[1] for b in boites)))
        X1 = int(np.ceil(max(b[2] for b in boites)))
        Y1 = int(np.ceil(max(b[3] for b in boites)))
        W, H = X1 - X0, Y1 - Y0
        W += (W % 4 and 4 - W % 4)
        H += (H % 4 and 4 - H % 4)
        feuille = Image.new("RGBA", (W * len(noms), H), (0, 0, 0, 0))
        for i, (n, c, b) in enumerate(zip(noms, cs, boites)):
            im = Image.open(os.path.join(src, n, c["file"])).convert("RGBA")
            feuille.paste(im, (i * W + int(round(b[0] - X0)), int(round(b[1] - Y0))))
        # réduite image par image (le bord d'une image ne bave pas sur la voisine)
        hr_f = "hr-%s-%s.png" % (entite, k)
        lr_f = "%s-%s.png" % (entite, k)
        if max(feuille.size) > 8192:
            raise SystemExit("[FO-FEUILLES-METAL] %s dépasse 8 192 px (F144)" % hr_f)
        feuille.save(os.path.join(dest, hr_f), optimize=True)
        lr = Image.new("RGBA", (W // 2 * len(noms), H // 2), (0, 0, 0, 0))
        for i in range(len(noms)):
            lr.paste(Q.reduite(feuille.crop((i * W, 0, (i + 1) * W, H))), (i * W // 2, 0))
        lr.save(os.path.join(dest, lr_f), optimize=True)
        fichiers.extend([hr_f, lr_f])
        sh = [round((X0 + W / 2.0) / 64.0, 6), round((Y0 + H / 2.0) / 64.0, 6)]
        out[k] = {"hr": {"filename": PREFIXE_JEU + hr_f, "width": W, "height": H, "shift": sh, "direction_count": len(noms)},
                  "lr": {"filename": PREFIXE_JEU + lr_f, "width": W // 2, "height": H // 2, "shift": sh, "direction_count": len(noms)}}
    return out


def couleur_moyenne(dest, base):
    a = np.asarray(Image.open(os.path.join(dest, "hr-%s-main.png" % base)).convert("RGBA")).astype(np.float64)
    w = a[..., 3] / 255.0
    rgb = (a[..., :3] * w[..., None]).sum((0, 1)) / max(1e-6, w.sum()) / 255.0
    return [round(float(c), 3) for c in rgb]


def icone(dest, base, fichiers, largeur=None):
    """Icône 64 px à 4 niveaux de mipmaps (64 + 32 + 16 + 8), réduite de la couche principale (1re image si plusieurs)."""
    im = Image.open(os.path.join(dest, "hr-%s-main.png" % base)).convert("RGBA")
    if largeur:
        im = im.crop((0, 0, largeur, im.height))
    a = np.asarray(im)
    ys, xs = np.nonzero(a[..., 3] > 8)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    arr = np.asarray(sq).astype(np.float64) / 255.0
    arr[..., :3] *= arr[..., 3:4]
    base_im = Image.fromarray((arr * 255).round().astype(np.uint8), "RGBA")
    out = Image.new("RGBA", (64 + 32 + 16 + 8, 64), (0, 0, 0, 0))
    x = 0
    for t in (64, 32, 16, 8):
        r = np.asarray(base_im.resize((t, t), Image.LANCZOS)).astype(np.float64) / 255.0
        al = np.clip(r[..., 3:4], 1e-6, 1)
        rgb = np.where(r[..., 3:4] > 1e-4, r[..., :3] / al, 0)
        u = np.concatenate([np.clip(rgb, 0, 1), r[..., 3:4]], -1)
        out.paste(Image.fromarray((u * 255).round().astype(np.uint8), "RGBA"), (x, 0))
        x += t
    f = "%s-icone.png" % base
    out.save(os.path.join(dest, f), optimize=True)
    fichiers.append(f)
    return {"filename": PREFIXE_JEU + f, "icon_size": 64, "icon_mipmaps": 4}


def rect(c):
    h = c["hr"]
    w, ht = h["width"] / 64.0, h["height"] / 64.0
    return (h["shift"][0] - w / 2, h["shift"][1] - ht / 2, h["shift"][0] + w / 2, h["shift"][1] + ht / 2)


def boite(couches):
    rs = [rect(c) for k, c in couches.items() if k in COUCHES and k != "shadow"]
    return [[round(min(r[0] for r in rs), 4), round(min(r[1] for r in rs), 4)],
            [round(max(r[2] for r in rs), 4), round(max(r[3] for r in rs), 4)]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--avec-cuve", action="store_true", help="ajoute la cuve d'électrolyse (après validation par la critique)")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    fichiers = []
    tab = {"machines": {}, "poteaux": {}}
    mpx = 0.0
    machines = dict(MACHINES)
    if a.avec_cuve:
        machines.update(CUVE)
    for entite in sorted(machines):
        nom = machines[entite]
        couches = copie(a.src, a.dest, entite, nom, fichiers)
        for k in ("main", "glow"):
            if k in couches:
                mpx += couches[k]["hr"]["width"] * couches[k]["hr"]["height"] / 1e6
        couches["boite"] = boite(couches)
        couches["map_color"] = couleur_moyenne(a.dest, entite)
        couches["icone"] = icone(a.dest, entite, fichiers)
        couches["variante"] = nom
        tab["machines"][entite] = couches
    for entite in sorted(POTEAUX):
        noms = POTEAUX[entite]
        couches = copie_directions(a.src, a.dest, entite, noms, fichiers)
        for k in ("main", "glow"):
            if k in couches:
                mpx += couches[k]["hr"]["width"] * couches[k]["hr"]["height"] / 1e6
        couches["boite"] = boite(couches)
        couches["map_color"] = couleur_moyenne(a.dest, entite)
        couches["icone"] = icone(a.dest, entite, fichiers, couches["main"]["hr"]["width"])
        couches["connection_points"] = [F.connection_point(d, C) for d in range(len(noms))]
        couches["variantes"] = list(noms)
        tab["poteaux"][entite] = couches
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/metallurgie/feuilles.py (lot DA-METALLURGIE) : ne pas modifier à la main.\n"
              "-- Tailles en pixels, shift, boîtes et points de fil en tuiles ; hr = 64 px par tuile (scale 0,5), normale = 32.\n"
              "-- Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + lua(tab) + "\n")
    with open(os.path.join(a.dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(tab, f, indent=1, sort_keys=True, ensure_ascii=False)
    man = {"commande": COMMANDE, "arguments": ["--avec-cuve"] if a.avec_cuve else [], "sources": a.src, "fichiers": {}}
    total = 0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        w, h = Image.open(p).size
        n = os.path.getsize(p)
        total += n
        man["fichiers"][fn] = {"sha256": Q.sha(p), "taille": n, "largeur": w, "hauteur": h}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-METAL] %d fichiers PNG, %.2f Mo, %.2f Mpx HR (principale + lueur), sources %s" % (len(fichiers), total / 1e6, mpx, a.src))


if __name__ == "__main__":
    main()
