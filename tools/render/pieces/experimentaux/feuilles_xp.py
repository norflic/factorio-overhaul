"""FEUILLES DE JEU DES EXPÉRIMENTAUX (lot EXPERIMENTAUX, 3/11) : rendus validés (famille EXP2, Ixion) + effets procéduraux ->
graphics/robots/experimentaux/ (PNG hors de git, D-6), sprites.lua (généré, lu par prototypes/experimentaux.lua et
script/robots/experimentaux.lua) et MANIFEST.json. Hors Blender : RÉDUCTION des sources, aucun nouveau rendu.

    py -3.9 tools/render/pieces/experimentaux/feuilles_xp.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut (à GARDER, lecture seule) : fo-logs/2026-10-31_ROBOTS/experimentaux/final/sprites/<nom>/ (main.png, glow_*.png, shadow.png,
spec.json ; petits rendus à 48 px/tuile, géants à 40).
Résolutions : corps et lueurs « haute » à la résolution du rendu (pas de rééchantillonnage), « normale » (plancher) 16 px/tuile ; ombres haute
16, normale 8 ; effets procéduraux haute 32, normale 16 (déterministes, graine fixe). Chaque couche est rognée à ses pixels non transparents
(le moteur les rogne aussi, F147) ; le décalage (`shift`, en tuiles, centre de l'image depuis la position au sol) est recalculé.
Aucune image au-delà de 4 096 px (une page d'atlas, F148, F144). Icônes 64 px.
"""
import argparse
import hashlib
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
LOGS = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs")
SRC_DEFAUT = os.path.join(LOGS, "2026-10-31_ROBOTS", "experimentaux", "final", "sprites")
DEST_DEFAUT = os.path.join(MOD, "graphics", "robots", "experimentaux")
PREFIXE = "__factorio-overhaul__/graphics/robots/experimentaux/"
COMMANDE = ("py -3.9 tools/render/pieces/experimentaux/feuilles_xp.py   (depuis la racine du mod ; sources : "
            "fo-logs/2026-10-31_ROBOTS/experimentaux/final/sprites, à GARDER)")
PPT = 32.0
LR_PPT = 16.0
OMBRE_HR, OMBRE_LR = 16.0, 8.0
SEUIL_ALPHA = 2  # rognage : alpha > 2 / 255

# id du jeu (shared/robots/experimentaux.lua) -> dossier source
PETITS = [("mat-foudre", "mat_foudre"), ("geode", "geode"), ("sarracenie", "sarracenie"), ("demi-vie", "demi_vie"), ("veilleuse", "veilleuse")]


def lanczos(a, w, h):
    """Réduction d'une image RGBA (uint8) : alpha prémultiplié, pour ne pas assombrir les bords."""
    x = a.astype(np.float32) / 255.0
    x[..., :3] *= x[..., 3:4]
    ch = [np.asarray(Image.fromarray(x[..., c], "F").resize((w, h), Image.LANCZOS), np.float32) for c in range(4)]
    o = np.stack(ch, -1)
    al = np.clip(o[..., 3:4], 1e-4, 1)
    o[..., :3] = np.clip(o[..., :3] / al, 0, 1)
    o[..., 3] = np.clip(o[..., 3], 0, 1)
    return np.round(o * 255).astype(np.uint8)


def rogne(a):
    """Rend (image rognée, x0, y0) ; une image vide garde 1 pixel."""
    al = a[..., 3] > SEUIL_ALPHA
    ys, xs = np.nonzero(al)
    if len(xs) == 0:
        return a[:1, :1], 0, 0
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    return a[y0:y1, x0:x1], int(x0), int(y0)


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def lua(v, ind=""):
    """Sérialisation Lua déterministe (clés triées)."""
    if isinstance(v, dict):
        if not v:
            return "{}"
        sub = ind + "  "
        parts = []
        for k in sorted(v):
            kk = k if (isinstance(k, str) and k.replace("_", "a").isalnum() and not k[0].isdigit()) else '["%s"]' % k
            parts.append("%s%s = %s" % (sub, kk, lua(v[k], sub)))
        return "{\n" + ",\n".join(parts) + ",\n" + ind + "}"
    if isinstance(v, (list, tuple)):
        if all(not isinstance(x, (dict, list, tuple)) for x in v):
            return "{ " + ", ".join(lua(x, ind) for x in v) + " }"
        sub = ind + "  "
        return "{\n" + ",\n".join(sub + lua(x, sub) for x in v) + ",\n" + ind + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    if isinstance(v, (float, np.floating)):
        return repr(round(float(v), 4))
    if isinstance(v, str):
        return '"%s"' % v.replace("\\", "\\\\").replace('"', '\\"')
    raise TypeError(type(v))


class Sortie:
    def __init__(self, dest):
        self.dest = dest
        self.fichiers = []

    def ecrit(self, a, nom):
        assert a.shape[0] <= 4096 and a.shape[1] <= 4096, nom
        Image.fromarray(a, "RGBA").save(os.path.join(self.dest, nom), compress_level=6)
        self.fichiers.append(nom)
        return PREFIXE + nom

    def couche(self, cle, hr, hr_ppt, lr, lr_ppt, shift):
        """Une couche haute + normale. `scale` = 32 / px par tuile de l'image."""
        fh = self.ecrit(hr, "hr-%s.png" % cle)
        fl = self.ecrit(lr, "%s.png" % cle)
        return {"hr": {"filename": fh, "width": hr.shape[1], "height": hr.shape[0], "scale": PPT / hr_ppt},
                "lr": {"filename": fl, "width": lr.shape[1], "height": lr.shape[0], "scale": PPT / lr_ppt},
                "shift": [round(float(shift[0]), 4), round(float(shift[1]), 4)]}


def lit_couche(src, var, couche):
    s = json.load(open(os.path.join(src, var, "spec.json"), encoding="utf-8"))
    info = s["layers"][couche]
    px = float(s["px"])
    a = np.asarray(Image.open(os.path.join(src, var, info["file"])).convert("RGBA"))
    h, w = a.shape[0], a.shape[1]
    c, x0, y0 = rogne(a)
    ch, cw = c.shape[0], c.shape[1]
    # centre rogné depuis le centre d'origine, en pixels, puis en tuiles
    dx = (x0 + cw / 2.0) - w / 2.0
    dy = (y0 + ch / 2.0) - h / 2.0
    shift = (info["shift"][0] + dx / px, info["shift"][1] + dy / px)
    return c, px, shift


def reduit(a, px_src, ppt):
    if abs(ppt - px_src) < 1e-9:
        return a
    k = ppt / px_src
    return lanczos(a, max(1, int(round(a.shape[1] * k))), max(1, int(round(a.shape[0] * k))))


def corps(S, src, cle, var):
    """main, lueurs (glow_*), ombre d'un expérimental. Rend l'entrée de sprites.lua."""
    spec = json.load(open(os.path.join(src, var, "spec.json"), encoding="utf-8"))
    out = {"lueurs": []}
    c, px, sh = lit_couche(src, var, "main")
    out["main"] = S.couche(cle, c, px, reduit(c, px, LR_PPT), LR_PPT, sh)
    out["px_rendu"] = px
    for nom in sorted(spec["layers"]):
        if not nom.startswith("glow_"):
            continue
        g, gpx, gsh = lit_couche(src, var, nom)
        if g.shape[0] * g.shape[1] <= 1:
            continue
        e = S.couche("%s-%s" % (cle, nom[5:]), g, gpx, reduit(g, gpx, LR_PPT), LR_PPT, gsh)
        e["nom"] = nom[5:]
        out["lueurs"].append(e)
    if not out["lueurs"]:
        # rendu sans couche de lueur (Géode) : les cristaux violets du corps deviennent la lueur (vue de nuit, règle D2)
        g = lueur_cristaux(c)
        e = S.couche("%s-cristal" % cle, g, px, reduit(g, px, LR_PPT), LR_PPT, sh)
        e["nom"] = "cristal"
        out["lueurs"].append(e)
    o, opx, osh = lit_couche(src, var, "shadow")
    out["ombre"] = S.couche(cle + "-ombre", reduit(o, opx, OMBRE_HR), OMBRE_HR, reduit(o, opx, OMBRE_LR), OMBRE_LR, osh)
    # icône : le corps tenu dans 60 px, centré dans 64
    k = 60.0 / max(c.shape[0], c.shape[1])
    ic = lanczos(c, max(1, int(round(c.shape[1] * k))), max(1, int(round(c.shape[0] * k))))
    cadre = np.zeros((64, 64, 4), np.uint8)
    oy, ox = (64 - ic.shape[0]) // 2, (64 - ic.shape[1]) // 2
    cadre[oy:oy + ic.shape[0], ox:ox + ic.shape[1]] = ic
    out["icone"] = {"filename": S.ecrit(cadre, "icone-%s.png" % cle), "size": 64}
    return out


def lueur_cristaux(a):
    """Lueur additive tirée des pixels violets saturés du corps (même cadre que le corps) : bleu et rouge au-dessus du vert."""
    x = a.astype(np.float32) / 255.0
    r, g, b, al = x[..., 0], x[..., 1], x[..., 2], x[..., 3]
    violet = np.clip((np.minimum(r, b) - g) * 3.0, 0, 1) * np.clip((b - 0.25) * 2.0, 0, 1) * al
    e = x[..., :3] * violet[..., None] * 0.85
    return additif(e)


# ---------------------------------------------------------------------------------------------- effets procéduraux
def additif(c):
    """c : énergie RGB (float). Codage additif du pipeline : RGB = c / max, A = max."""
    c = np.clip(c, 0, 1)
    m = c.max(-1, keepdims=True)
    rgb = np.where(m > 1e-6, c / np.maximum(m, 1e-6), 0)
    return np.round(np.concatenate([rgb, m], -1) * 255).astype(np.uint8)


def pointe(ppt, lueur=False):
    """Pointe de cristal violet (Géode) : 1,1 × 2,6 tuiles, deux faces, arête claire ; base au bas de l'image."""
    ss = 4
    w, h = int(round(1.1 * ppt)) * ss, int(round(2.6 * ppt)) * ss
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, top, base, half = w / 2.0, 0.02 * h, 0.96 * h, 0.46 * w
    gauche = [(cx, top), (cx - half, base * 0.78), (cx - half * 0.55, base), (cx, base * 0.9)]
    droite = [(cx, top), (cx, base * 0.9), (cx + half * 0.55, base), (cx + half, base * 0.78)]
    if lueur:
        d.polygon(gauche + droite, fill=(190, 120, 255, 255))
        im = im.filter(ImageFilter.GaussianBlur(ss * 2))
        a = np.asarray(im.resize((w // ss, h // ss), Image.LANCZOS)).astype(np.float32) / 255.0
        e = a[..., :3] * a[..., 3:4] * 0.9
        return additif(e)
    d.polygon(gauche, fill=(176, 112, 240, 255))
    d.polygon(droite, fill=(96, 44, 160, 255))
    d.line([(cx, top), (cx, base * 0.9)], fill=(236, 210, 255, 255), width=ss)
    d.line([(cx, top), (cx - half, base * 0.78)], fill=(214, 170, 255, 255), width=max(1, ss // 2))
    return np.asarray(im.resize((w // ss, h // ss), Image.LANCZOS)).copy()


def disque(n, couleur, coeur=0.35, puissance=2.0):
    """Éclat radial additif (Veilleuse) : coeur blanc, couronne colorée."""
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.sqrt((x - n / 2 + 0.5) ** 2 + (y - n / 2 + 0.5) ** 2) / (n / 2)
    f = np.clip(1 - r, 0, 1) ** puissance
    blanc = np.clip(1 - r / coeur, 0, 1) ** 2
    e = np.asarray(couleur, np.float32)[None, None, :] * f[..., None] + blanc[..., None] * 0.9
    return additif(e)


def verre(n, graine):
    """Plaque de verre fondu (Veilleuse) : disque irrégulier translucide, bord clair, fêlures sombres. Mélange normal."""
    r = np.random.RandomState(graine)
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    cx = cy = n / 2 - 0.5
    ang = np.arctan2(y - cy, x - cx)  # outil hors jeu : la trigonométrie est permise ici
    bord = 0.86 + 0.08 * np.sin(ang * 5 + r.rand() * 6) + 0.04 * np.sin(ang * 11 + r.rand() * 6)
    rr = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (n / 2)
    dedans = np.clip((bord - rr) * n / 6, 0, 1)
    liseré = np.clip(1 - np.abs(bord - rr) * n / 5, 0, 1)
    col = np.zeros((n, n, 3), np.float32)
    col[...] = (0.78, 0.86, 0.92)
    col = col * (0.75 + 0.25 * (1 - rr[..., None]))
    al = dedans * 0.42 + liseré * 0.35
    im = Image.fromarray(np.round(np.clip(np.concatenate([col, al[..., None]], -1), 0, 1) * 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(im)
    for _ in range(7):
        a0 = r.rand() * 6.283
        x0, y0 = cx + np.cos(a0) * n * 0.05, cy + np.sin(a0) * n * 0.05
        pts = [(x0, y0)]
        for k in range(4):
            a0 += (r.rand() - 0.5) * 0.9
            x0 += np.cos(a0) * n * 0.1
            y0 += np.sin(a0) * n * 0.1
            pts.append((x0, y0))
        d.line(pts, fill=(40, 52, 64, 150), width=max(1, n // 120))
    out = np.asarray(im).copy()
    out[..., 3] = np.minimum(out[..., 3], np.round(dedans * 255 + liseré * 90).clip(0, 255).astype(np.uint8))
    return out


def effets(S):
    e = {}
    e["pointe"] = S.couche("pointe", pointe(PPT), PPT, pointe(LR_PPT), LR_PPT, (0.0, -1.3))
    e["pointe-lueur"] = S.couche("pointe-lueur", pointe(PPT, True), PPT, pointe(LR_PPT, True), LR_PPT, (0.0, -1.3))
    e["eclair"] = S.couche("eclair", disque(256, (1.0, 0.25, 0.85)), PPT, disque(128, (1.0, 0.25, 0.85)), LR_PPT, (0.0, 0.0))
    e["verre"] = S.couche("verre", verre(160, 7), PPT, verre(80, 7), LR_PPT, (0.0, 0.0))
    e["pointe"]["base"] = 1.3
    for k in ("pointe-lueur", "eclair"):
        e[k]["additif"] = True
    return e


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    S = Sortie(a.dest)
    spr = {"corps": {}, "effets": effets(S)}
    for cle, var in PETITS:
        spr["corps"][cle] = corps(S, a.src, cle, var)
    p = os.path.join(a.dest, "sprites.lua")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/render/pieces/experimentaux/feuilles_xp.py (lot EXPERIMENTAUX) : ne pas modifier à la main.\n")
        f.write("-- Images hors de git (D-6) : MANIFEST.json, « commande ». shift : centre de l'image depuis la position au sol, en tuiles.\n")
        f.write("return " + lua(spr) + "\n")
    fichiers = {}
    total = 0
    mpx_hr, mpx_lr = 0.0, 0.0
    for f in sorted(os.listdir(a.dest)):
        if f.endswith(".png"):
            pp = os.path.join(a.dest, f)
            im = Image.open(pp)
            fichiers[f] = {"largeur": im.size[0], "hauteur": im.size[1], "taille": os.path.getsize(pp), "sha256": sha(pp)}
            total += os.path.getsize(pp)
            if f.startswith("hr-"):
                mpx_hr += im.size[0] * im.size[1] / 1e6
            elif not f.startswith("icone-"):
                mpx_lr += im.size[0] * im.size[1] / 1e6
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"commande": COMMANDE, "arguments": [], "fichiers": fichiers}, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-XP] %d fichiers PNG, %.2f Mo ; haute %.2f Mpx, normale %.2f Mpx" % (len(fichiers), total / 1e6, mpx_hr, mpx_lr),
          flush=True)


if __name__ == "__main__":
    main()
