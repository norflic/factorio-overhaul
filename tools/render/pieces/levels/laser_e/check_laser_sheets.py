"""CONTRÔLE des feuilles de jeu de la tourelle laser (lot F1-C, 4/11 ; modèle : gun_e/check_gun_sheets.py). Python 3.9.

    py -3.9 tools/render/pieces/levels/laser_e/check_laser_sheets.py [--dest graphics/levels/laser] [--sources] [--mutants]

Sans option : chaque PNG du MANIFEST.json existe, à sa taille, son sha256 et ses dimensions ; sprites.lua et sprites.json
ont les sha256 du manifeste ; manifeste de production (pas d'essai) ; pour chaque âge 2 à 15, tête de 32 ou 64 directions
(celles du manifeste), line_length 8, feuille = 8 cellules × N/8 rangées de la taille déclarée, 8 192 px au plus (F144),
normale = hr / 2 ; socle, pièce, icône et tir présents.
--sources : en plus, chaque pose de chaque feuille de tête est comparée AU PIXEL à son PNG source (hr et normale), le
reste de la cellule est transparent, et chaque copie (socle, pièce) a le sha256 de sa source (sources dans fo-logs, à
GARDER).
--mutants : sur une copie jetable du dossier, des feuilles faussées doivent être refusées (pixel changé, deux poses
échangées avec un manifeste recalculé, direction_count faux, fichier absent). Code 0 si tout est juste.
"""
import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import feuilles as FE  # noqa: E402


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def fichier(r):
    return os.path.basename(r["filename"])


ESSAI_OK = False     # --essai-ok : contrôler des feuilles d'essai (essai de l'outil lui-même), jamais pour livrer


def controle(dest, sources=False):
    err = []
    pm = os.path.join(dest, "MANIFEST.json")
    if not os.path.exists(pm):
        return ["MANIFEST.json absent : régénérer (%s)" % FE.COMMANDE]
    man = json.load(open(pm, encoding="utf-8"))
    if man.get("essai") and not ESSAI_OK:
        err.append("manifeste d'ESSAI (feuilles.py --essai)")
    dims = {}
    for f, m in sorted(man["fichiers"].items()):
        p = os.path.join(dest, f)
        if not os.path.exists(p):
            err.append("fichier absent : %s" % f)
            continue
        with Image.open(p) as im:
            dims[f] = im.size
        if os.path.getsize(p) != m["taille"] or sha(p) != m["sha256"] or dims[f] != (m["largeur"], m["hauteur"]):
            err.append("fichier différent du manifeste : %s" % f)
    pngs = sorted(f for f in os.listdir(dest) if f.endswith(".png"))
    hors = [f for f in pngs if f not in man["fichiers"]]
    if hors:
        err.append("PNG hors du manifeste : %s" % hors[:5])
    for nom in ("sprites.lua", "sprites.json"):
        p = os.path.join(dest, nom)
        if not os.path.exists(p) or sha(p) != man.get(nom.replace(".", "_") + "_sha256"):
            err.append("%s absent ou différent du manifeste" % nom)
    spr = json.load(open(os.path.join(dest, "sprites.json"), encoding="utf-8"))
    if spr.get("essai") and not ESSAI_OK:
        err.append("sprites.json d'ESSAI")
    A = spr["ages"]

    def fixe(partie, quoi):
        if not partie or "main" not in partie:
            err.append("%s : sans couche principale" % quoi)
            return
        for lay, cd in partie.items():
            for r in ("hr", "lr"):
                f = fichier(cd[r])
                if f not in dims:
                    err.append("%s %s %s : fichier absent %s" % (quoi, lay, r, f))
                elif dims[f] != (cd[r]["width"], cd[r]["height"]):
                    err.append("%s %s %s : %s, déclaré %dx%d" % (quoi, lay, r, dims[f], cd[r]["width"], cd[r]["height"]))
            if sources:
                src = man["sources"].get(partie_source(cd))
                if not src:
                    err.append("%s %s : source inconnue du manifeste" % (quoi, lay))
                    continue
                for r in ("hr", "lr"):
                    if sha(os.path.join(dest, fichier(cd[r]))) != src["couches"][lay][r]:
                        err.append("%s %s %s : copie différente de la source" % (quoi, lay, r))

    def partie_source(cd):
        # hr-lase-eNN-socle-main.png -> eNN-socle
        b = fichier(cd["hr"])[len("hr-lase-"):-4]
        return b.rsplit("-", 1)[0]

    fixe(A.get("1", {}).get("piece"), "âge 1 pièce")
    cache = {}
    for e in range(2, 16):
        a = A.get(str(e))
        if not a:
            err.append("âge %d absent" % e)
            continue
        fixe(a.get("socle"), "âge %d socle" % e)
        fixe(a.get("piece"), "âge %d pièce" % e)
        n = man.get("directions", {}).get(str(e))
        if n not in (32, 64):
            err.append("âge %d : directions %s au manifeste" % (e, n))
        for x in ("icone", "tir", "boite"):
            if x not in a:
                err.append("âge %d : sans %s" % (e, x))
        if "main" not in a.get("tete", {}) or "shadow" not in a.get("tete", {}):
            err.append("âge %d : tête sans couche principale ou sans ombre" % e)
        for lay, cd in sorted(a.get("tete", {}).items()):
            for r in ("hr", "lr"):
                t = cd[r]
                f = fichier(t)
                if t["direction_count"] != n or t["line_length"] != FE.LIGNE:
                    err.append("âge %d tête %s %s : direction_count %s, line_length %s (attendu %s et %d)" % (
                        e, lay, r, t["direction_count"], t["line_length"], n, FE.LIGNE))
                    continue
                need = (t["width"] * FE.LIGNE, t["height"] * (n // FE.LIGNE))
                if f not in dims:
                    err.append("âge %d tête %s %s : fichier absent %s" % (e, lay, r, f))
                elif dims[f] != need:
                    err.append("âge %d tête %s %s : feuille %s, attendu %s" % (e, lay, r, dims[f], need))
                elif max(dims[f]) > FE.LIMITE_PX:
                    err.append("âge %d tête %s %s : au-delà de %d px (F144)" % (e, lay, r, FE.LIMITE_PX))
            if (cd["lr"]["width"] * 2, cd["lr"]["height"] * 2) != (cd["hr"]["width"], cd["hr"]["height"]):
                err.append("âge %d tête %s : normale ≠ hr / 2" % (e, lay))
            if not sources:
                continue
            for dname, pose in sorted(cd.get("poses", {}).items()):
                src = man["sources"].get(pose["source"])
                if not src:
                    err.append("âge %d tête %s %s : source inconnue" % (e, lay, dname))
                    continue
                spec = json.load(open(os.path.join(src["dossier"], "spec.json"), encoding="utf-8"))
                L = spec["layers"][lay]
                k = pose["k"]
                for r, LL, fac in (("hr", L, 1), ("lr", L["lr"], 2)):
                    ps = os.path.join(src["dossier"], LL["file"])
                    if sha(ps) != src["couches"][lay][r]:
                        err.append("âge %d tête %s %s %s : source modifiée depuis la génération" % (e, lay, dname, r))
                        continue
                    s_im = np.asarray(Image.open(ps).convert("RGBA"))
                    f = fichier(cd[r])
                    if f not in cache:
                        if len(cache) >= 2:
                            cache.clear()
                        cache[f] = np.asarray(Image.open(os.path.join(dest, f)).convert("RGBA"))
                    cw, chh = cd[r]["width"], cd[r]["height"]
                    cell = cache[f][(k // FE.LIGNE) * chh:(k // FE.LIGNE + 1) * chh, (k % FE.LIGNE) * cw:(k % FE.LIGNE + 1) * cw]
                    py_, px_ = pose["y"] // fac, pose["x"] // fac
                    part = cell[py_:py_ + s_im.shape[0], px_:px_ + s_im.shape[1]]
                    s_cmp = s_im.copy()
                    s_cmp[s_cmp[..., 3] == 0, :3] = 0
                    same = part.shape == s_cmp.shape and np.array_equal(part, s_cmp)
                    masque = np.ones(cell.shape[:2], bool)
                    masque[py_:py_ + s_im.shape[0], px_:px_ + s_im.shape[1]] = False
                    vide = not cell[masque][:, 3].any()
                    if not (same and vide):
                        err.append("âge %d tête %s %s %s : pixels ≠ source %s (identiques %s, reste vide %s)" % (
                            e, lay, dname, r, pose["source"], same, vide))
    return err


def remanifeste(d, f):
    """Recalcule l'entrée du manifeste d'un fichier (mutant : la faute doit être vue par le contrôle au pixel)."""
    pm = os.path.join(d, "MANIFEST.json")
    man = json.load(open(pm, encoding="utf-8"))
    p = os.path.join(d, f)
    with Image.open(p) as im:
        w, h = im.size
    man["fichiers"][f] = {"taille": os.path.getsize(p), "sha256": sha(p), "largeur": w, "hauteur": h}
    json.dump(man, open(pm, "w", encoding="utf-8"), indent=1, sort_keys=True)


def mutants(dest):
    spr = json.load(open(os.path.join(dest, "sprites.json"), encoding="utf-8"))
    tete = spr["ages"]["15"]["tete"]["main"]
    f_hr = fichier(tete["hr"])
    res = []
    racine = tempfile.mkdtemp(prefix="laser-mut-")
    try:
        def copie():
            d = os.path.join(racine, "m%d" % len(res))
            shutil.copytree(dest, d)
            return d

        # 1. un pixel opaque changé dans la feuille de tête : sha256 du manifeste
        d = copie()
        im = np.array(Image.open(os.path.join(d, f_hr)).convert("RGBA"))
        ys, xs = np.nonzero(im[..., 3] > 200)
        im[ys[0], xs[0], 0] ^= 0x40
        Image.fromarray(im, "RGBA").save(os.path.join(d, f_hr))
        res.append(("pixel changé", controle(d)))
        # 2. deux cellules échangées, manifeste recalculé : seul le contrôle au pixel la voit
        d = copie()
        im = np.array(Image.open(os.path.join(d, f_hr)).convert("RGBA"))
        cw, ch = tete["hr"]["width"], tete["hr"]["height"]
        a = im[0:ch, 0:cw].copy()
        im[0:ch, 0:cw] = im[0:ch, cw:2 * cw]
        im[0:ch, cw:2 * cw] = a
        Image.fromarray(im, "RGBA").save(os.path.join(d, f_hr))
        remanifeste(d, f_hr)
        res.append(("deux poses échangées, manifeste recalculé", controle(d, sources=True)))
        # 3. direction_count faux dans sprites.json (sha recalculé)
        d = copie()
        pj = os.path.join(d, "sprites.json")
        s = json.load(open(pj, encoding="utf-8"))
        s["ages"]["2"]["tete"]["main"]["hr"]["direction_count"] = 16
        json.dump(s, open(pj, "w", encoding="utf-8"), indent=1, sort_keys=True)
        man = json.load(open(os.path.join(d, "MANIFEST.json"), encoding="utf-8"))
        man["sprites_json_sha256"] = sha(pj)
        json.dump(man, open(os.path.join(d, "MANIFEST.json"), "w", encoding="utf-8"), indent=1, sort_keys=True)
        res.append(("direction_count faux", controle(d)))
        # 4. fichier absent
        d = copie()
        os.remove(os.path.join(d, f_hr))
        res.append(("feuille absente", controle(d)))
    finally:
        shutil.rmtree(racine, ignore_errors=True)
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=FE.DEST_DEFAUT)
    ap.add_argument("--sources", action="store_true")
    ap.add_argument("--mutants", action="store_true")
    ap.add_argument("--essai-ok", action="store_true", help="accepter un manifeste d'essai (essai de l'outil seulement)")
    a = ap.parse_args()
    global ESSAI_OK
    ESSAI_OK = a.essai_ok
    ok = 0
    err = controle(a.dest, sources=False)
    print("[FO-LASER-SHEETS] manifeste, dimensions, directions : %s" % ("OK" if not err else "%d ECHEC(S)" % len(err)))
    ok += not err
    n = 1
    if a.sources:
        e2 = controle(a.dest, sources=True)
        print("[FO-LASER-SHEETS] poses au pixel contre les sources, copies : %s" % (
            "OK" if not e2 else "%d ECHEC(S)" % len(e2)))
        err += [x for x in e2 if x not in err]
        ok += not e2
        n += 1
    for x in err[:20]:
        print("  " + x)
    if a.mutants:
        for quoi, e in mutants(a.dest):
            vu = bool(e)
            print("[FO-LASER-SHEETS] mutant « %s » : %s%s" % (quoi, "REFUSÉ" if vu else "ACCEPTÉ (faute)",
                                                               (" (%s)" % e[0]) if vu else ""))
            ok += vu
            n += 1
    print("[FO-LASER-SHEETS] BILAN : %d OK, %d ECHEC(S)" % (ok, n - ok))
    return 0 if ok == n else 1


if __name__ == "__main__":
    sys.exit(main())
