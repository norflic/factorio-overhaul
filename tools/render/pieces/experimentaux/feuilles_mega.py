"""FEUILLES DE JEU DU MÉGA-BOURDON (lot MEGA-BOURDON, 11/11) : rendu de la variante « mega » (rendre.py --names mega) ->
graphics/robots/megabourdon/ : corps cuirassé, vitraux, cristaux, lueur cyan des vortex, ombre (PNG hors de git, D-6), icône (suivie),
sprites.lua (généré, lu par prototypes/bourdon.lua et script/robots/bourdon.lua) et MANIFEST.json. Hors Blender.

    py -3.9 tools/render/pieces/experimentaux/feuilles_mega.py [--src DIR] [--cache DIR] [--dest DIR]      (depuis la racine du mod)

Sources par défaut (à GARDER) : fo-logs/2026-11-11_MEGA-BOURDON/rendu (spec.json, PNG) et fo-logs/2026-11-11_MEGA-BOURDON/cache/mega/render.json
(« canons » : bouches des casemates, en tuiles depuis la position au sol). Résolutions : celles du Bourdon (feuilles.py) : corps et lueurs hr
40 px/tuile, normale 16 ; ombre hr 16, normale 8. Le reste de la cloche (battant, chaînes, ancres, Glas) est celui du Bourdon.
Noms de sprite : fo-mega-bourdon-<cle>.

Lot ART-MEGA2 (ordre du DC du 11/11, 9 h 47) : le Méga-Bourdon est rendu à l'échelle MEGA_ECHELLE (bourdon.py, 2,2) : rendre.py --px 88
(40 × 2,2) ; une tuile du jeu vaut px / MEGA_ECHELLE pixels du rendu, décalages et pivots sont multipliés par l'échelle, écrite dans
sprites.lua (« echelle »). Une feuille plus grande que LIMITE_PX de côté est découpée en TUILES (fichiers -t<ligne><colonne>), qui
deviennent les `layers` d'un même sprite (chaque couche à son décalage, hr_version couche par couche) : la limite par fichier ne borne
plus la taille ; pour un sprite fixe (une image), c'est l'équivalent des `stripes` des animations, qui découpent la suite des images
mais jamais une image.
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
SRC_DEFAUT = os.path.join(LOGS, "2026-11-11_MEGA2", "rendu")
CACHE_DEFAUT = os.path.join(LOGS, "2026-11-11_MEGA2", "cache")
DEST_DEFAUT = os.path.join(MOD, "graphics", "robots", "megabourdon")
PREFIXE = "__factorio-overhaul__/graphics/robots/megabourdon/"
COMMANDE = ("py -3.9 tools/render/pieces/experimentaux/feuilles_mega.py   (depuis la racine du mod ; sources : fo-logs/2026-11-11_MEGA2/rendu "
            "et cache/mega/render.json, à GARDER ; rendu : rendre.py --names mega --px 88 --samples 32 --denoise --ombre-pct 40, puis "
            "tourelle-00..15 --px 88 --samples 32 --denoise --sans-ombre)")
PX_RENDU = 40.0
PPT = 32.0
LIMITE_PX = 4096  # côté maximal d'un fichier ; au-delà, tuiles (Factorio 1.1 refuse plus de 8192)


def _echelle():
    """MEGA_ECHELLE de bourdon.py (lu dans le texte : bourdon.py importe Blender)."""
    import re
    t = open(os.path.join(HERE, "bourdon.py"), encoding="utf-8").read()
    return float(re.search(r"^MEGA_ECHELLE = ([0-9.]+)", t, re.M).group(1))


ECH = _echelle()


def _coupes(n, morceaux, pas):
    """Bornes de `morceaux` tranches de n pixels, sur des multiples de `pas` (les tuiles hr et normales se recouvrent exactement)."""
    b = [0]
    for i in range(1, morceaux):
        b.append(int(round(n * i / morceaux / pas)) * pas)
    b.append(n)
    return b


class Sortie:
    def __init__(self, dest):
        self.dest = dest
        self.spr = {}

    def tuiles(self, a, ppt, nom, ys, xs):
        """Découpe a aux bornes ys (lignes) et xs (colonnes) ; rend la liste des tuiles (fichier, taille, échelle, décalage du centre de
        la tuile depuis le centre de l'image, en tuiles du jeu)."""
        h, w = a.shape[0], a.shape[1]
        out = []
        for i in range(len(ys) - 1):
            for j in range(len(xs) - 1):
                t = a[ys[i]:ys[i + 1], xs[j]:xs[j + 1]]
                assert t.shape[0] <= LIMITE_PX and t.shape[1] <= LIMITE_PX, nom
                f = F.ecrit(np.ascontiguousarray(t), self.dest, "%s-t%d%d.png" % (nom, i, j))
                dx = ((xs[j] + xs[j + 1]) / 2.0 - w / 2.0) / ppt
                dy = ((ys[i] + ys[i + 1]) / 2.0 - h / 2.0) / ppt
                out.append({"filename": PREFIXE + f, "width": int(t.shape[1]), "height": int(t.shape[0]), "scale": PPT / ppt,
                            "decal": [round(dx, 4), round(dy, 4)]})
        return out

    def pose(self, cle, hr, hr_ppt, lr, lr_ppt, shift=(0.0, 0.0), blend=None, ombre=False, lueur=False):
        lignes = -(-hr.shape[0] // LIMITE_PX)
        colonnes = -(-hr.shape[1] // LIMITE_PX)
        if lignes * colonnes > 1:
            # même découpe aux deux résolutions : bornes hr sur des multiples de ph pixels, bornes normales = bornes hr × pl / ph
            import math
            g = math.gcd(int(hr_ppt), int(lr_ppt))
            ph, pl = int(hr_ppt) // g, int(lr_ppt) // g
            ys, xs = _coupes(hr.shape[0], lignes, ph), _coupes(hr.shape[1], colonnes, ph)
            ysl = [min(lr.shape[0], y * pl // ph) for y in ys[:-1]] + [lr.shape[0]]
            xsl = [min(lr.shape[1], x * pl // ph) for x in xs[:-1]] + [lr.shape[1]]
            th = self.tuiles(hr, hr_ppt, "hr-%s" % cle, ys, xs)
            tl = self.tuiles(lr, lr_ppt, cle, ysl, xsl)
            e = {"hr": {"tuiles": th, "width": int(hr.shape[1]), "height": int(hr.shape[0]), "scale": PPT / hr_ppt},
                 "lr": {"tuiles": tl, "width": int(lr.shape[1]), "height": int(lr.shape[0]), "scale": PPT / lr_ppt},
                 "shift": [round(float(shift[0]), 4), round(float(shift[1]), 4)]}
        else:
            for a in (hr, lr):
                assert a.shape[0] <= LIMITE_PX and a.shape[1] <= LIMITE_PX, cle
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
        px = float(s["px"])
        if abs(px - PX_RENDU * ECH) > 1e-6:
            print("[FO-FEUILLES-MEGA] %s : rendu à %s px par unité au lieu de %s : agrandi" % (cle, px, PX_RENDU * ECH), flush=True)
        info = s["layers"][couche]
        a = np.asarray(Image.open(os.path.join(src, info["file"])).convert("RGBA"))
        w, h = a.shape[1], a.shape[0]
        ppt_src = px / ECH  # pixels du rendu par tuile du jeu
        k = hr_ppt / ppt_src
        hr = a if abs(k - 1.0) < 1e-9 else F.lanczos(a, max(1, int(round(w * k))), max(1, int(round(h * k))))
        k2 = lr_ppt / ppt_src
        lr = F.lanczos(a, max(1, int(round(w * k2))), max(1, int(round(h * k2))))
        sh = (info["shift"][0] * ECH, info["shift"][1] * ECH)
        self.pose(cle, hr, hr_ppt, lr, lr_ppt, shift=sh, **kw)
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
    ap.add_argument("--src-tourelles", default=None)  # dossier des rendus de tourelles, s'il diffère de --src
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
        st = os.path.join(a.src_tourelles or a.src, nom)
        S.rendu(st, "main", nom)
        S.rendu(st, "glow_vortex", "tourelle-lueur-%02d" % k, blend="additive", lueur=True)
    info = json.load(open(os.path.join(a.cache, "mega", "render.json"), encoding="utf-8"))
    canons, sols = info.get("canons") or [], info.get("canons_sol") or []
    assert len(canons) == 4 and len(sols) == 4, "4 pivots attendus, %d et %d" % (len(canons), len(sols))
    S.spr["canons"] = [[round(float(c[0]) * ECH, 3), round(float(c[1]) * ECH, 3)] for c in canons]
    S.spr["canons_sol"] = [[round(float(c[0]) * ECH, 3), round(float(c[1]) * ECH, 3)] for c in sols]
    S.spr["echelle"] = ECH
    icone(src, a.dest)
    p = os.path.join(a.dest, "sprites.lua")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/render/pieces/experimentaux/feuilles_mega.py (lot MEGA-BOURDON) : ne pas modifier à la main.\n")
        f.write("-- Images hors de git (D-6), sauf l'icône : MANIFEST.json, « commande ». shift : centre de l'image depuis la position au sol, en tuiles ;\n")
        f.write("-- canons : pivots des 4 tourelles à l'écran ; canons_sol : le sol sous chacun (origine des feuilles de tourelle), en tuiles.\n")
        f.write("-- echelle : MEGA_ECHELLE du rendu (bourdon.py) ; hr.tuiles / lr.tuiles : feuille découpée (decal : centre de la tuile depuis\n")
        f.write("-- celui de l'image, en tuiles), une couche par tuile (prototypes/bourdon.lua).\n")
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
