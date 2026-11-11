"""FEUILLES DE JEU DU MÉGA-BOURDON (lot MEGA-BOURDON, 11/11) : rendu de la variante « mega » (rendre.py --names mega) ->
graphics/robots/megabourdon/ : corps cuirassé, vitraux, cristaux, lueur cyan des vortex, ombre (PNG hors de git, D-6), icône (suivie),
sprites.lua (généré, lu par prototypes/bourdon.lua et script/robots/bourdon.lua) et MANIFEST.json. Hors Blender.

    py -3.9 tools/render/pieces/experimentaux/feuilles_mega.py [--src DIR] [--cache DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut (à GARDER) : fo-logs/2026-11-11_MEGA-BOURDON/rendu (spec.json, PNG) et fo-logs/2026-11-11_MEGA-BOURDON/cache/mega/render.json
(« canons » : bouches des casemates, en tuiles depuis la position au sol). Résolutions : celles du Bourdon (feuilles.py) : corps et lueurs hr
40 px/tuile, normale 16 ; ombre hr 16, normale 8. Le reste de la cloche (battant, chaînes, ancres, Glas) est celui du Bourdon.
Noms de sprite : fo-mega-bourdon-<cle>.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import feuilles as F  # noqa: E402  (lanczos, lua, sha : mêmes réductions et même écriture que le Bourdon)

RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
LOGS = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs")
SRC_DEFAUT = os.path.join(LOGS, "2026-11-11_MEGA-BOURDON", "rendu")
CACHE_DEFAUT = os.path.join(LOGS, "2026-11-11_MEGA-BOURDON", "cache")
DEST_DEFAUT = os.path.join(MOD, "graphics", "robots", "megabourdon")
PREFIXE = "__factorio-overhaul__/graphics/robots/megabourdon/"
COMMANDE = ("py -3.9 tools/render/pieces/experimentaux/feuilles_mega.py   (depuis la racine du mod ; sources : fo-logs/2026-11-11_MEGA-BOURDON/rendu "
            "et cache/mega/render.json, à GARDER)")
PX_RENDU = 40.0
PPT = 32.0


class Sortie:
    def __init__(self, dest):
        self.dest = dest
        self.spr = {}

    def pose(self, cle, hr, hr_ppt, lr, lr_ppt, shift=(0.0, 0.0), blend=None, ombre=False, lueur=False):
        for a in (hr, lr):
            assert a.shape[0] <= 4096 and a.shape[1] <= 4096, cle
        fh = F.ecrit(hr, self.dest, "hr-%s.png" % cle)
        fl = F.ecrit(lr, self.dest, "%s.png" % cle)
        e = {"hr": {"filename": PREFIXE + fh, "width": hr.shape[1], "height": hr.shape[0], "scale": PPT / hr_ppt},
             "lr": {"filename": PREFIXE + fl, "width": lr.shape[1], "height": lr.shape[0], "scale": PPT / lr_ppt},
             "shift": [round(float(shift[0]), 4), round(float(shift[1]), 4)]}
        if blend:
            e["blend"] = blend
        if ombre:
            e["ombre"] = True
        if lueur:
            e["lueur"] = True
        self.spr[cle] = e

    def rendu(self, src, couche, cle, hr_ppt=PX_RENDU, lr_ppt=16.0, **kw):
        s = json.load(open(os.path.join(src, "spec.json"), encoding="utf-8"))
        assert float(s["px"]) == PX_RENDU, "rendu à %s px/tuile, attendu %s" % (s["px"], PX_RENDU)
        info = s["layers"][couche]
        a = np.asarray(Image.open(os.path.join(src, info["file"])).convert("RGBA"))
        w, h = a.shape[1], a.shape[0]
        k = hr_ppt / PX_RENDU
        hr = a if k == 1.0 else F.lanczos(a, max(1, int(round(w * k))), max(1, int(round(h * k))))
        k2 = lr_ppt / PX_RENDU
        lr = F.lanczos(a, max(1, int(round(w * k2))), max(1, int(round(h * k2))))
        self.pose(cle, hr, hr_ppt, lr, lr_ppt, shift=info["shift"], **kw)
        return info


def icone(src, dest):
    """Icône 64 px + 3 mipmaps (64, 32, 16, 8 côte à côte), tirée du corps rendu : la cloche entière, centrée, sur fond transparent."""
    s = json.load(open(os.path.join(src, "spec.json"), encoding="utf-8"))
    a = np.asarray(Image.open(os.path.join(src, s["layers"]["main"]["file"])).convert("RGBA"))
    h, w = a.shape[0], a.shape[1]
    c = max(h, w)
    carre = np.zeros((c, c, 4), np.uint8)
    carre[(c - h) // 2:(c - h) // 2 + h, (c - w) // 2:(c - w) // 2 + w] = a
    tailles = (64, 32, 16, 8)
    out = np.zeros((64, sum(tailles), 4), np.uint8)
    x = 0
    for t in tailles:
        m = F.lanczos(carre, t, t)
        out[0:t, x:x + t] = m
        x += t
    Image.fromarray(out, "RGBA").save(os.path.join(dest, "icone.png"), compress_level=9)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--cache", default=CACHE_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    src = os.path.join(a.src, "mega")
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    S = Sortie(a.dest)
    S.rendu(src, "main", "corps")
    S.rendu(src, "glow_vitrail", "vitrail", blend="additive", lueur=True)
    S.rendu(src, "glow_cristal", "cristal", blend="additive", lueur=True)
    S.rendu(src, "glow_vortex", "vortex", blend="additive", lueur=True)
    S.rendu(src, "shadow", "corps-ombre", hr_ppt=16.0, lr_ppt=8.0, ombre=True)
    # les tourelles : 16 directions rendues à part (variantes tourelle-00 à tourelle-15), sans ombre (celle du corps suffit)
    for k in range(16):
        nom = "tourelle-%02d" % k
        st = os.path.join(a.src, nom)
        S.rendu(st, "main", nom)
        S.rendu(st, "glow_vortex", "tourelle-lueur-%02d" % k, blend="additive", lueur=True)
    info = json.load(open(os.path.join(a.cache, "mega", "render.json"), encoding="utf-8"))
    canons, sols = info.get("canons") or [], info.get("canons_sol") or []
    assert len(canons) == 4 and len(sols) == 4, "4 pivots attendus, %d et %d" % (len(canons), len(sols))
    S.spr["canons"] = [[round(float(c[0]), 3), round(float(c[1]), 3)] for c in canons]
    S.spr["canons_sol"] = [[round(float(c[0]), 3), round(float(c[1]), 3)] for c in sols]
    icone(src, a.dest)
    p = os.path.join(a.dest, "sprites.lua")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/render/pieces/experimentaux/feuilles_mega.py (lot MEGA-BOURDON) : ne pas modifier à la main.\n")
        f.write("-- Images hors de git (D-6), sauf l'icône : MANIFEST.json, « commande ». shift : centre de l'image depuis la position au sol, en tuiles ;\n")
        f.write("-- canons : pivots des 4 tourelles à l'écran ; canons_sol : le sol sous chacun (origine des feuilles de tourelle), en tuiles.\n")
        f.write("return " + F.lua(S.spr) + "\n")
    fichiers = {}
    total = 0
    mpx_hr, mpx_lr = 0.0, 0.0
    for f in sorted(os.listdir(a.dest)):
        if f.endswith(".png"):
            pp = os.path.join(a.dest, f)
            im = Image.open(pp)
            fichiers[f] = {"largeur": im.size[0], "hauteur": im.size[1], "taille": os.path.getsize(pp), "sha256": F.sha(pp)}
            total += os.path.getsize(pp)
            if f.startswith("hr-"):
                mpx_hr += im.size[0] * im.size[1] / 1e6
            elif f != "icone.png":
                mpx_lr += im.size[0] * im.size[1] / 1e6
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"commande": COMMANDE, "arguments": [], "fichiers": fichiers}, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-MEGA] %d fichiers PNG, %.2f Mo ; haute %.2f Mpx, normale %.2f Mpx ; pivots %s" % (len(fichiers), total / 1e6, mpx_hr, mpx_lr,
          S.spr["canons"]), flush=True)


if __name__ == "__main__":
    main()
