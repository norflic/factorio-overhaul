"""Contrôle des feuilles de jeu de la mitrailleuse (lot A2, 24/10). Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/check_gun_sheets.py [--dest graphics/levels/gun] [--sources] [--mutants]

Contrôles (code 0 seulement si tout passe) :
  1. MANIFESTE : chaque fichier listé existe, avec la taille, le sha256 et les dimensions du manifeste ; aucun PNG du
     dossier hors du manifeste ; sha256 de sprites.lua et de sprites.json égaux à ceux du manifeste ;
  2. sprites.lua = texte régénéré depuis sprites.json (feuilles.texte_lua) : les deux disent la même chose ;
  3. RECTANGLES : chaque couche citée existe ; socle, pièce : une image = le fichier entier ; tête : 4 directions
     (colonne, line_length 1) ou 64 (8 × 8, line_length 8, noms d00 à d63 dans l'ordre ; lot A3-jeu) de
     width × height, hr ET normale (normale = hr / 2), 8 192 px au plus (F144) ; icônes 120 × 64 ; points de tir
     présents et écart de l'éclat sous le seuil (E68) pour chaque âge 2 à 15 ;
  4. --sources : chaque pose de tête recollée dans sa cellule a EXACTEMENT les pixels de son PNG source (hr et
     normale), le reste de la cellule est vide ; les copies de socle et de pièce ont le sha256 de leur source
     (spec.json) ; les poses VALIDÉES N (d00) et E (d16) sont donc inchangées au pixel ;
  5. --mutants : sur une copie jetable du dossier, 7 mutants (fichier supprimé, octet changé, taille du manifeste,
     PNG en trop, hauteur d'une tête dans sprites.json et sprites.lua, sprites.lua retouché, pose décalée), plus 3 si un
     âge est à 64 directions (cellules d06 et d07 échangées, feuille en miroir, line_length 1) doivent tous être
     REFUSÉS, et la copie intacte acceptée.
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

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # « ≠ » et accents : sinon plantage sur la console cp1252

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import feuilles as FE  # noqa: E402

PREFIX = FE.GRAPHICS_PREFIX


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def controler(dest, sources=False):
    err = []
    ok = []
    man_p = os.path.join(dest, "MANIFEST.json")
    if not os.path.exists(man_p):
        return ["MANIFEST.json absent (régénérer : %s)" % FE.COMMANDE], ok
    man = json.load(open(man_p, encoding="utf-8"))
    fich = man["fichiers"]
    pngs = sorted(f for f in os.listdir(dest) if f.endswith(".png"))
    for f in pngs:
        if f not in fich:
            err.append("PNG hors du manifeste : %s" % f)
    dims = {}
    for f, m in sorted(fich.items()):
        p = os.path.join(dest, f)
        if not os.path.exists(p):
            err.append("fichier manquant : %s (régénérer : %s)" % (f, man.get("commande")))
            continue
        if os.path.getsize(p) != m["taille"]:
            err.append("taille différente du manifeste : %s (%d contre %d)" % (f, os.path.getsize(p), m["taille"]))
        if sha(p) != m["sha256"]:
            err.append("sha256 différent du manifeste : %s" % f)
        with Image.open(p) as im:
            dims[f] = im.size
        if dims[f] != (m["largeur"], m["hauteur"]):
            err.append("dimensions différentes du manifeste : %s %s contre %s" % (f, dims[f], (m["largeur"], m["hauteur"])))
    ok.append("manifeste : %d fichiers" % len(fich))
    for f, k in (("sprites.lua", "sprites_lua_sha256"), ("sprites.json", "sprites_json_sha256")):
        p = os.path.join(dest, f)
        if not os.path.exists(p) or sha(p) != man.get(k):
            err.append("%s absent ou différent du manifeste" % f)
    try:
        donnees = json.load(open(os.path.join(dest, "sprites.json"), encoding="utf-8"))
    except Exception as ex:  # noqa: BLE001
        return err + ["sprites.json illisible : %s" % ex], ok
    pour_lua = FE.pour_lua(donnees)
    lua = open(os.path.join(dest, "sprites.lua"), encoding="utf-8").read() if os.path.exists(
        os.path.join(dest, "sprites.lua")) else ""
    if lua != FE.texte_lua(pour_lua):
        err.append("sprites.lua ne correspond pas à sprites.json")
    else:
        ok.append("sprites.lua = sprites.json")

    def fichier(defn):
        fn = defn["filename"]
        if not fn.startswith(PREFIX):
            err.append("chemin hors du dossier : %s" % fn)
            return None
        return fn[len(PREFIX):]

    nrect = 0
    n64 = 0
    cache_feuilles = {}
    for e, A in sorted(donnees["ages"].items(), key=lambda kv: int(kv[0])):
        e = int(e)
        for part in ("socle", "piece"):
            for lay, cd in sorted(A.get(part, {}).items()):
                for r in ("hr", "lr"):
                    f = fichier(cd[r])
                    if f is None:
                        continue
                    nrect += 1
                    if f not in dims:
                        err.append("âge %d %s %s %s : fichier absent %s" % (e, part, lay, r, f))
                    elif dims[f] != (cd[r]["width"], cd[r]["height"]):
                        err.append("âge %d %s %s %s : rectangle %dx%d, image %s" % (e, part, lay, r, cd[r]["width"],
                                                                                   cd[r]["height"], dims[f]))
                if (cd["lr"]["width"], cd["lr"]["height"]) != (cd["hr"]["width"] // 2, cd["hr"]["height"] // 2):
                    err.append("âge %d %s %s : normale ≠ hr / 2" % (e, part, lay))
        if e == 1:
            continue
        noms = (A.get("outils") or {}).get("noms") or donnees["directions"]
        ndir = len(noms)
        if ndir not in (4, FE.NDIR64):
            err.append("âge %d : %d directions (4 ou 64 attendues)" % (e, ndir))
        n64 += ndir == FE.NDIR64
        if ndir == FE.NDIR64 and noms != ["d%02d" % k for k in range(FE.NDIR64)]:
            err.append("âge %d : directions hors de l'ordre d00 à d63" % e)
        for lay, cd in sorted(A.get("tete", {}).items()):
            for r in ("hr", "lr"):
                f = fichier(cd[r])
                if f is None:
                    continue
                nrect += 1
                ll_voulu = 1 if ndir == 4 else FE.LIGNE64
                if cd[r]["direction_count"] != ndir or cd[r]["line_length"] != ll_voulu:
                    err.append("âge %d tête %s %s : direction_count %s, line_length %s (attendu %d et %d)" % (
                        e, lay, r, cd[r]["direction_count"], cd[r]["line_length"], ndir, ll_voulu))
                if f in dims and max(dims[f]) > FE.LIMITE_PX:
                    err.append("âge %d tête %s %s : feuille %s au-delà de %d px (F144)" % (e, lay, r, dims[f],
                                                                                           FE.LIMITE_PX))
                need = (cd[r]["width"] * cd[r]["line_length"],
                        cd[r]["height"] * -(-cd[r]["direction_count"] // cd[r]["line_length"]))
                if f not in dims:
                    err.append("âge %d tête %s %s : fichier absent %s" % (e, lay, r, f))
                elif dims[f] != need:
                    err.append("âge %d tête %s %s : feuille %s, attendu %s (%d directions de %dx%d)" % (
                        e, lay, r, dims[f], need, cd[r]["direction_count"], cd[r]["width"], cd[r]["height"]))
            if (cd["lr"]["width"] * 2, cd["lr"]["height"] * 2) != (cd["hr"]["width"], cd["hr"]["height"]):
                err.append("âge %d tête %s : normale ≠ hr / 2" % (e, lay))
            if sources:
                for k, dname in enumerate(noms):
                    pose = cd.get("poses", {}).get(dname)
                    if not pose:
                        continue
                    ll = cd["hr"]["line_length"]
                    src = man["sources"].get(pose["source"])
                    if not src:
                        err.append("âge %d tête %s %s : source inconnue du manifeste" % (e, lay, dname))
                        continue
                    spec = json.load(open(os.path.join(src["dossier"], "spec.json"), encoding="utf-8"))
                    L = spec["layers"][lay]
                    for r, LL, fac in (("hr", L, 1), ("lr", L["lr"], 2)):
                        s_im = np.asarray(Image.open(os.path.join(src["dossier"], LL["file"])).convert("RGBA"))
                        f = fichier(cd[r])
                        if f not in cache_feuilles:     # une lecture par feuille (64 poses par feuille, lot A3-jeu)
                            if len(cache_feuilles) >= 2:
                                cache_feuilles.clear()
                            cache_feuilles[f] = np.asarray(Image.open(os.path.join(dest, f)).convert("RGBA"))
                        feuille = cache_feuilles[f]
                        cw, chh = cd[r]["width"], cd[r]["height"]
                        cx0, cy0 = (k % ll) * cw, (k // ll) * chh
                        cell = feuille[cy0:cy0 + chh, cx0:cx0 + cw]
                        py_, px_ = pose["y"] // fac, pose["x"] // fac
                        part_ = cell[py_:py_ + s_im.shape[0], px_:px_ + s_im.shape[1]]
                        same = part_.shape == s_im.shape and np.array_equal(part_, s_im)
                        # hors de la pose, la cellule est transparente
                        masque = np.ones(cell.shape[:2], bool)
                        masque[py_:py_ + s_im.shape[0], px_:px_ + s_im.shape[1]] = False
                        vide = not cell[masque][:, 3].any()
                        if not (same and vide):
                            err.append("âge %d tête %s %s %s : pixels de la feuille ≠ source %s (identiques %s, reste vide %s)"
                                       % (e, lay, dname, r, pose["source"], same, vide))
                        elif sha(os.path.join(src["dossier"], LL["file"])) != src["couches"][lay][r]:
                            err.append("âge %d tête %s %s %s : source modifiée depuis la génération" % (e, lay, dname, r))
        ic = A.get("icone")
        f = fichier(ic) if ic else None
        if not f or dims.get(f) != (120, 64):
            err.append("âge %d : icône absente ou pas 120 × 64 (%s)" % (e, dims.get(f)))
        t = A.get("tir") or {}
        if not isinstance(t.get("projectile_creation_distance"), (int, float)) or len(t.get("projectile_center", [])) != 2:
            err.append("âge %d : points de tir absents" % e)
        em = A.get("ecart_max")
        if not isinstance(em, (int, float)) or em > donnees["eclat"]["seuil"]:
            err.append("âge %d : écart de l'éclat %s au-delà du seuil %s (E68)" % (e, em, donnees["eclat"]["seuil"]))
    ok.append("rectangles : %d définitions (hr et normale) ; têtes : %d âge(s) à 64 directions, %d à 4" % (
        nrect, n64, len(donnees["ages"]) - 1 - n64))
    if sources:
        nsrc = 0
        for nom, src in sorted(man["sources"].items()):
            if "tete" in nom:
                continue
            spec = json.load(open(os.path.join(src["dossier"], "spec.json"), encoding="utf-8"))
            for lay, L in spec["layers"].items():
                for LL in (L, L["lr"]):
                    p = os.path.join(dest, LL["file"])
                    nsrc += 1
                    if not os.path.exists(p) or sha(p) != LL["sha256"]:
                        err.append("copie de %s %s différente de la source" % (nom, LL["file"]))
        ok.append("sources : poses de tête au pixel, %d copies de socle et de pièce au sha256" % nsrc)
    return err, ok


def mutants(dest):
    base = tempfile.mkdtemp(prefix="fo-gunsheets-")
    res = []
    try:
        def copie(nom):
            d = os.path.join(base, nom)
            shutil.copytree(dest, d)
            return d

        def jdump(p, obj):
            with open(p, "w", encoding="utf-8", newline="\n") as f:
                json.dump(obj, f, indent=1, sort_keys=True)

        d = copie("temoin")
        e, _ = controler(d)
        res.append(("témoin intact accepté", not e, "; ".join(e[:2])))
        man = json.load(open(os.path.join(dest, "MANIFEST.json"), encoding="utf-8"))
        un = sorted(f for f in man["fichiers"] if "tete-main" in f and f.startswith("hr-"))[0]

        def m_supprime(d):
            os.remove(os.path.join(d, un))

        def m_octet(d):
            p = os.path.join(d, un)
            b = bytearray(open(p, "rb").read())
            b[-20] ^= 0xFF
            open(p, "wb").write(bytes(b))

        def m_taille(d):
            p = os.path.join(d, "MANIFEST.json")
            m = json.load(open(p, encoding="utf-8"))
            m["fichiers"][un]["taille"] += 1
            jdump(p, m)

        def m_en_trop(d):
            shutil.copyfile(os.path.join(d, un), os.path.join(d, "hr-gun-intrus.png"))

        def m_hauteur(d):
            # hauteur d'une tête changée dans sprites.json ET sprites.lua (manifeste recalculé) : rectangle hors feuille
            p = os.path.join(d, "sprites.json")
            j = json.load(open(p, encoding="utf-8"))
            j["ages"]["15"]["tete"]["main"]["hr"]["height"] += 2
            jdump(p, j)
            pl = json.loads(json.dumps(j))
            for A in pl["ages"].values():
                for cd in A.get("tete", {}).values():
                    cd.pop("poses", None)
            pl["ages"] = {int(k): v for k, v in pl["ages"].items()}
            open(os.path.join(d, "sprites.lua"), "w", encoding="utf-8", newline="\n").write(FE.texte_lua(pl))
            mp = os.path.join(d, "MANIFEST.json")
            m = json.load(open(mp, encoding="utf-8"))
            m["sprites_json_sha256"] = sha(p)
            m["sprites_lua_sha256"] = sha(os.path.join(d, "sprites.lua"))
            jdump(mp, m)

        def m_lua(d):
            p = os.path.join(d, "sprites.lua")
            s = open(p, encoding="utf-8").read().replace("line_length = 1", "line_length = 2", 1)
            open(p, "w", encoding="utf-8", newline="\n").write(s)
            mp = os.path.join(d, "MANIFEST.json")
            m = json.load(open(mp, encoding="utf-8"))
            m["sprites_lua_sha256"] = sha(p)
            jdump(mp, m)

        def m_pose(d):
            # pose N de l'âge 9 décalée d'un pixel dans la feuille hr (manifeste recalculé) : refusée par --sources
            f = "hr-gun-e09-tete-main.png"
            p = os.path.join(d, f)
            a = np.asarray(Image.open(p).convert("RGBA")).copy()
            a[:, 1:] = a[:, :-1].copy()
            Image.fromarray(a, "RGBA").save(p)
            mp = os.path.join(d, "MANIFEST.json")
            m = json.load(open(mp, encoding="utf-8"))
            m["fichiers"][f]["taille"] = os.path.getsize(p)
            m["fichiers"][f]["sha256"] = sha(p)
            jdump(mp, m)

        a64 = sorted(int(k) for k, A in json.load(open(os.path.join(dest, "sprites.json"), encoding="utf-8"))[
            "ages"].items() if len((A.get("outils") or {}).get("noms") or []) == FE.NDIR64)

        def remanifeste(d, f):
            p = os.path.join(d, f)
            mp = os.path.join(d, "MANIFEST.json")
            m = json.load(open(mp, encoding="utf-8"))
            m["fichiers"][f]["taille"] = os.path.getsize(p)
            m["fichiers"][f]["sha256"] = sha(p)
            jdump(mp, m)

        def m_echange(d):
            # 64 directions : cellules d06 et d07 échangées dans la feuille hr principale (décalage d'un cran)
            e = a64[0]
            j = json.load(open(os.path.join(d, "sprites.json"), encoding="utf-8"))
            w, h = j["ages"][str(e)]["tete"]["main"]["hr"]["width"], j["ages"][str(e)]["tete"]["main"]["hr"]["height"]
            f = "hr-gun-e%02d-tete-main.png" % e
            p = os.path.join(d, f)
            a = np.asarray(Image.open(p).convert("RGBA")).copy()
            c6 = a[0:h, 6 * w:7 * w].copy()
            a[0:h, 6 * w:7 * w] = a[0:h, 7 * w:8 * w]
            a[0:h, 7 * w:8 * w] = c6
            Image.fromarray(a, "RGBA").save(p)
            remanifeste(d, f)

        def m_miroir(d):
            # 64 directions : feuille normale principale retournée gauche-droite
            f = "gun-e%02d-tete-main.png" % a64[0]
            p = os.path.join(d, f)
            Image.open(p).convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT).save(p)
            remanifeste(d, f)

        def m_ligne(d):
            # 64 directions : line_length 1 au lieu de 8, dans sprites.json ET sprites.lua (manifeste recalculé)
            p = os.path.join(d, "sprites.json")
            j = json.load(open(p, encoding="utf-8"))
            for r in ("hr", "lr"):
                j["ages"][str(a64[0])]["tete"]["main"][r]["line_length"] = 1
            jdump(p, j)
            with open(os.path.join(d, "sprites.lua"), "w", encoding="utf-8", newline="") as fl:
                fl.write(FE.texte_lua(FE.pour_lua(j)))
            mp = os.path.join(d, "MANIFEST.json")
            m = json.load(open(mp, encoding="utf-8"))
            m["sprites_json_sha256"] = sha(p)
            m["sprites_lua_sha256"] = sha(os.path.join(d, "sprites.lua"))
            jdump(mp, m)

        cas = [("fichier supprimé", m_supprime, False), ("octet changé", m_octet, False),
               ("taille du manifeste", m_taille, False), ("PNG en trop", m_en_trop, False),
               ("hauteur de tête (json et lua, manifeste recalculé)", m_hauteur, False),
               ("sprites.lua retouché (line_length 2)", m_lua, False),
               ("pose N de l'âge 9 décalée d'1 px (manifeste recalculé, --sources)", m_pose, True)]
        if a64:
            cas += [("64 directions, âge %d : d06 et d07 échangées (un cran, --sources)" % a64[0], m_echange, True),
                    ("64 directions, âge %d : feuille normale en miroir (--sources)" % a64[0], m_miroir, True),
                    ("64 directions, âge %d : line_length 1 au lieu de 8 (json et lua)" % a64[0], m_ligne, False)]
        else:
            print("[FO-GUN-SHEETS] mutants à 64 directions NON JOUÉS : aucun âge à 64 directions")
        for nom, fn, src in cas:
            d = copie(nom.split(" ")[0] + "-" + str(abs(hash(nom)) % 1000))
            fn(d)
            e, _ = controler(d, sources=src)
            res.append(("mutant « %s » refusé" % nom, bool(e), e[0] if e else "ACCEPTÉ À TORT"))
    finally:
        shutil.rmtree(base, ignore_errors=True)
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=FE.DEST_DEFAUT)
    ap.add_argument("--sources", action="store_true")
    ap.add_argument("--mutants", action="store_true")
    a = ap.parse_args()
    err, ok = controler(a.dest, a.sources)
    for o in ok:
        print("[FO-GUN-SHEETS] OK     " + o)
    for e in err:
        print("[FO-GUN-SHEETS] ECHEC  " + e)
    n_ok, n_ko = len(ok), len(err)
    if a.mutants:
        for nom, bon, det in mutants(a.dest):
            print("[FO-GUN-SHEETS] %s %s : %s" % ("OK    " if bon else "ECHEC ", nom, det))
            n_ok += bon
            n_ko += not bon
    print("[FO-GUN-SHEETS] BILAN : %d OK, %d ECHEC(S)" % (n_ok, n_ko))
    return 0 if n_ko == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
