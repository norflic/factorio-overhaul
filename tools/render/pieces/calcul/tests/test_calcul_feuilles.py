"""Contrôle des feuilles des 20 machines du calcul (lot MACHINES-CALCUL, 3/11) : graphics/machines/calcul/ contre ses sources GARDÉES.

    PYTHONUTF8=1 py -3.9 -B tools/render/pieces/calcul/tests/test_calcul_feuilles.py      (depuis la racine du mod ; environ 40 s)

Contrôles :
- MANIFESTE : chaque PNG listé existe, sha256, taille et dimensions justes ; aucun PNG du dossier hors du manifeste ;
- RÉGÉNÉRATION : feuilles.py, relancé dans un dossier jetable, redonne les mêmes sha256 (déterminisme, sources inchangées) ;
- RECTANGLES : sprites.lua = sprites.json ; hr paire, normale = hr / 2, même shift ; bande mobile = largeur × images ; 8 192 px au
  plus (F144) ; icône 120 × 64 ; boîte de dessin qui contient l'emprise et toutes les couches sauf l'ombre ;
- AU PIXEL (aucun décalage) : chaque couche hr replacée par son shift redonne la source nettoyée à l'octet près (corps, ombre,
  lueur ; chaque image de la pièce mobile contre sa case de la bande) ; la normale est la moyenne 2 × 2 exacte de la hr ; coins sur
  la grille paire de l'origine de l'entité ;
- CALAGE contre l'emprise : le corps opaque (alpha >= 200) ne déborde pas de plus de 8 px hr (1/8 de tuile) à l'ouest, à l'est, au sud ;
- MUTANTS refusés : octet changé (sha256), shift décalé de 1 px hr, image retirée, couche impaire.
"""
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.dirname(HERE)
MOD = os.path.normpath(os.path.join(KIT, "..", "..", "..", ".."))
sys.path.insert(0, KIT)
import feuilles as FE  # noqa: E402

DEST = os.path.join(MOD, "graphics", "machines", "calcul")
PX = FE.PX
OK, KO = [], []


def check(nom, cond, detail=""):
    (OK if cond else KO).append(nom)
    if not cond:
        print("ECHEC %s %s" % (nom, detail))
    return cond


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def charge(p):
    return np.asarray(Image.open(p).convert("RGBA"))


def manifeste(dest):
    """Écarts entre le dossier et son manifeste."""
    man = json.load(open(os.path.join(dest, "MANIFEST.json"), encoding="utf-8"))
    ec = []
    for fn, m in sorted(man["fichiers"].items()):
        p = os.path.join(dest, fn)
        if not os.path.isfile(p):
            ec.append("manquant " + fn)
            continue
        w, h = Image.open(p).size
        if sha(p) != m["sha256"] or os.path.getsize(p) != m["taille"] or (w, h) != (m["largeur"], m["hauteur"]):
            ec.append("différent " + fn)
    for fn in sorted(os.listdir(dest)):
        if fn.endswith(".png") and fn not in man["fichiers"]:
            ec.append("hors manifeste " + fn)
    return ec


def source_nettoyee(src, nom, couche):
    spec = json.load(open(os.path.join(FE.dossier_source(nom, src), "spec.json"), encoding="utf-8"))
    s = spec["layers"][couche]
    a = np.asarray(Image.open(os.path.join(FE.dossier_source(nom, src), s["file"])).convert("RGBA")).astype(np.float64) / 255.0
    a, _ = FE.nettoie(a, couche)
    return FE.u8(a), spec


def au_pixel(dest, src, tab):
    """Écarts : couches hr replacées par leur shift contre les sources nettoyées ; normale = moyenne 2 × 2 de la hr ; parité."""
    ec = []
    for proto in sorted(tab):
        ent = tab[proto]
        nom = ent["variante"]
        spec = json.load(open(os.path.join(FE.dossier_source(nom, src), "spec.json"), encoding="utf-8"))
        m = spec["layers"]["main"]
        c0 = (int(round(m["width"] / 2.0 - m["shift"][0] * PX)), int(round(m["height"] / 2.0 - m["shift"][1] * PX)))
        for couche, c in sorted(ent["couches"].items()):
            hr = charge(os.path.join(dest, os.path.basename(c["hr"]["filename"])))
            lr = charge(os.path.join(dest, os.path.basename(c["lr"]["filename"])))
            n = c.get("images", 1)
            w, h = c["hr"]["width"], c["hr"]["height"]
            x = c0[0] + c["hr"]["shift"][0] * PX - w / 2.0
            y = c0[1] + c["hr"]["shift"][1] * PX - h / 2.0
            if abs(x - round(x)) > 1e-6 or abs(y - round(y)) > 1e-6:
                ec.append("%s %s : coin hors de la grille des pixels (%.3f, %.3f)" % (proto, couche, x, y))
                continue
            x, y = int(round(x)), int(round(y))
            if (x - c0[0]) % 2 or (y - c0[1]) % 2 or w % 2 or h % 2:
                ec.append("%s %s : coin ou taille impairs" % (proto, couche))
            if c["lr"]["shift"] != c["hr"]["shift"] or c["lr"]["width"] * 2 != w or c["lr"]["height"] * 2 != h:
                ec.append("%s %s : normale différente de hr / 2" % (proto, couche))
            # normale = moyenne 2 × 2 exacte de la hr (à l'arrondi près)
            if hr.shape[0] % 2 == 0 and hr.shape[1] % 2 == 0:
                attendu = FE.u8(FE.moitie(hr.astype(np.float64) / 255.0))
                d = np.abs(attendu.astype(int) - lr.astype(int))
                if d.max() > 1:
                    ec.append("%s %s : normale différente de la moyenne 2 x 2 (écart %d)" % (proto, couche, d.max()))
            if couche == "mobile":
                s = spec["layers"]["mobile"]
                bande = charge(os.path.join(FE.dossier_source(nom, src), s["file"]))
                pw, ph = s["width"], s["height"]
                px0 = c0[0] + s["shift"][0] * PX - pw / 2.0
                py0 = c0[1] + s["shift"][1] * PX - ph / 2.0
                ox, oy = x - int(round(px0)), y - int(round(py0))
                for k in range(n):
                    case = bande[oy:oy + h, k * pw + ox:k * pw + ox + w]
                    if not np.array_equal(case, hr[:, k * w:(k + 1) * w]):
                        ec.append("%s mobile image %d : différente de la source" % (proto, k + 1))
                        break
                continue
            srcn, _ = source_nettoyee(src, nom, couche)
            s = spec["layers"][couche]
            sx = int(round(c0[0] + s["shift"][0] * PX - s["width"] / 2.0))
            sy = int(round(c0[1] + s["shift"][1] * PX - s["height"] / 2.0))
            # canevas commun : la source et la sortie replacées
            X0, Y0 = min(sx, x), min(sy, y)
            X1, Y1 = max(sx + srcn.shape[1], x + w), max(sy + srcn.shape[0], y + h)
            A = np.zeros((Y1 - Y0, X1 - X0, 4), np.uint8)
            B = np.zeros_like(A)
            A[sy - Y0:sy - Y0 + srcn.shape[0], sx - X0:sx - X0 + srcn.shape[1]] = srcn
            B[y - Y0:y - Y0 + h, x - X0:x - X0 + w] = hr
            if not np.array_equal(A, B):
                ec.append("%s %s : hr replacée différente de la source nettoyée (%d px)" % (proto, couche, int((A != B).any(-1).sum())))
    return ec


def main():
    tab = json.load(open(os.path.join(DEST, "sprites.json"), encoding="utf-8"))
    man = json.load(open(os.path.join(DEST, "MANIFEST.json"), encoding="utf-8"))
    src = FE.SRC_DEFAUT

    # --- manifeste
    ec = manifeste(DEST)
    check("manifeste : %d PNG, sha256, tailles, dimensions" % len(man["fichiers"]), not ec, ec[:5])
    check("reprises DA-CALCUL : %s lues dans %s" % (", ".join(FE.REPRISES_DA), FE.SRC_DA_DEFAUT),
          man.get("reprises_da") == list(FE.REPRISES_DA) and all(os.path.isfile(os.path.join(FE.dossier_source(n), "spec.json")) and FE.dossier_source(n).startswith(FE.SRC_DA_DEFAUT) for n in FE.REPRISES_DA))
    check("20 machines", len(tab) == 20 and man["machines"] == 20 and sorted(tab) == sorted(v[0] for v in FE.MACHINES.values()))

    # --- sprites.lua = sprites.json (mêmes fichiers, mêmes tailles : relu par lua5.2)
    lua_exe = shutil.which("lua5.2.exe") or shutil.which("lua5.2") or os.path.expanduser(os.path.join("~", "bin", "lua5.2.exe"))
    lua = subprocess.run([lua_exe, "-e", "local t = dofile([[%s]]) local n = 0 for k, v in pairs(t) do for c, x in pairs(v.couches) do "
                          "io.write(k, ' ', c, ' ', x.hr.width, ' ', x.hr.height, ' ', x.lr.width, ' ', x.lr.height, ' ', x.hr.shift[1], ' ', "
                          "x.hr.shift[2], '\\n') end end" % os.path.join(DEST, "sprites.lua").replace("\\", "/")],
                         capture_output=True, text=True)
    lignes = sorted(l.split() for l in lua.stdout.splitlines())
    attendu = sorted([p, c, str(x["hr"]["width"]), str(x["hr"]["height"]), str(x["lr"]["width"]), str(x["lr"]["height"]),
                      x["hr"]["shift"][0], x["hr"]["shift"][1]] for p, v in tab.items() for c, x in v["couches"].items())
    same = len(lignes) == len(attendu) and all(l[:6] == a[:6] and abs(float(l[6]) - a[6]) < 1e-9 and abs(float(l[7]) - a[7]) < 1e-9
                                                for l, a in zip(lignes, attendu))
    check("sprites.lua = sprites.json (%d couches relues par lua5.2)" % len(lignes), lua.returncode == 0 and same, lua.stderr[:200])

    # --- rectangles
    ec = []
    for p, v in sorted(tab.items()):
        h = v["cote"] / 2.0
        b = v["boite"]
        if not (b[0][0] <= -h + 1e-9 and b[0][1] <= -h + 1e-9 and b[1][0] >= h - 1e-9 and b[1][1] >= h - 1e-9):
            ec.append("%s : boîte %s ne couvre pas l'emprise %d" % (p, b, v["cote"]))
        for c, x in v["couches"].items():
            n = x.get("images", 1)
            if max(x["hr"]["width"] * n, x["hr"]["height"]) > 8192:
                ec.append("%s %s : > 8 192 px" % (p, c))
            if c != "shadow":
                w, ht = x["hr"]["width"] / PX, x["hr"]["height"] / PX
                sx, sy = x["hr"]["shift"]
                if sx - w / 2 < b[0][0] - 1e-9 or sy - ht / 2 < b[0][1] - 1e-9 or sx + w / 2 > b[1][0] + 1e-9 or sy + ht / 2 > b[1][1] + 1e-9:
                    ec.append("%s %s hors de la boîte de dessin" % (p, c))
        ic = os.path.join(DEST, os.path.basename(v["icone"]["icon"]))
        if Image.open(ic).size != (120, 64):
            ec.append("%s : icône %s" % (p, Image.open(ic).size))
        if "main" not in v["couches"] or "shadow" not in v["couches"]:
            ec.append("%s : sans corps ou sans ombre" % p)
    check("rectangles : boîtes, 8 192 px, icônes 120 x 64, corps et ombre", not ec, ec[:5])
    mobiles = sorted(p for p, v in tab.items() if "mobile" in v["couches"])
    check("12 machines à pièce mobile, 8 images chacune", len(mobiles) == 12 and all(tab[p]["couches"]["mobile"]["images"] == 8 for p in mobiles))

    # --- au pixel
    ec = au_pixel(DEST, src, tab)
    check("au pixel : hr replacées = sources nettoyées, normale = moyenne 2 x 2, grille paire", not ec, ec[:5])

    # --- calage contre l'emprise
    ec = ["%s %s" % (p, v["calage_px"]) for p, v in sorted(tab.items()) if min(v["calage_px"].values()) < -8]
    check("calage : corps opaque dans l'emprise à 8 px hr près (ouest, est, sud)", not ec, ec)
    pires = sorted((min(v["calage_px"].values()), p) for p, v in tab.items())[:3]
    print("  calage le plus débordant : " + ", ".join("%s %d px" % (p, d) for d, p in pires))

    # --- nettoyage : plus aucun pixel isolé de 4 px au plus dans corps et ombre
    from scipy import ndimage
    ec = []
    for p, v in sorted(tab.items()):
        for c in ("main", "shadow"):
            a = charge(os.path.join(DEST, os.path.basename(v["couches"][c]["hr"]["filename"])))[..., 3]
            lab, n = ndimage.label(a > 0, structure=np.ones((3, 3)))
            if n and np.bincount(lab.ravel())[1:].min() <= FE.STRAY_MAX_PX:
                ec.append("%s %s" % (p, c))
    check("nettoyage : aucun pixel isolé (<= 4 px) dans corps et ombre", not ec, ec[:5])
    # nappes faibles (critique DA-METALLURGIE) : aucun pixel à plus de 3 px de la silhouette utile (alpha >= 16), et rectangle rogné
    # <= 1,2 fois la boîte de la silhouette pour le corps et l'ombre (les lueurs de quelques pixels sont exemptées du rapport)
    ec, pire = [], (0.0, "")
    for p, v in sorted(tab.items()):
        for c in ("main", "shadow", "glow"):
            if c not in v["couches"]:
                continue
            a = charge(os.path.join(DEST, os.path.basename(v["couches"][c]["hr"]["filename"])))[..., 3]
            utile = a >= 16
            garde = ndimage.binary_dilation(utile, structure=np.ones((3, 3)), iterations=FE.UTILE_MARGE_PX)
            loin = int(((a > 0) & ~garde).sum())
            if loin:
                ec.append("%s %s : %d px loin de la silhouette" % (p, c, loin))
            if c != "glow":
                ys, xs = np.nonzero(utile)
                r = a.size / float((xs.max() - xs.min() + 1) * (ys.max() - ys.min() + 1))
                pire = max(pire, (r, "%s %s" % (p, c)))
                if r > 1.2:
                    ec.append("%s %s : rectangle rogné %.2f fois la silhouette" % (p, c, r))
    check("nappes faibles : 0 px loin de la silhouette, rectangle <= 1,2 x silhouette (corps, ombre ; pire %.2f %s)" % pire, not ec, ec[:5])

    # --- régénération dans un dossier jetable : mêmes sha256
    tmp = tempfile.mkdtemp(prefix="fo-calc-")
    try:
        r = subprocess.run([sys.executable, "-B", os.path.join(KIT, "feuilles.py"), "--dest", tmp], capture_output=True, text=True)
        man2 = json.load(open(os.path.join(tmp, "MANIFEST.json"), encoding="utf-8")) if r.returncode == 0 else {"fichiers": {}}
        same = {k: v["sha256"] for k, v in man2["fichiers"].items()} == {k: v["sha256"] for k, v in man["fichiers"].items()}
        same = same and open(os.path.join(tmp, "sprites.lua"), "rb").read() == open(os.path.join(DEST, "sprites.lua"), "rb").read()
        check("régénération : mêmes sha256 et même sprites.lua (déterministe)", r.returncode == 0 and same, r.stdout[-300:] + r.stderr[-300:])

        # --- mutants, sur la copie jetable
        p0 = os.path.join(tmp, "hr-salle-main.png")
        im = np.asarray(Image.open(p0).convert("RGBA")).copy()
        ys, xs = np.nonzero(im[..., 3] > 200)
        im[ys[0], xs[0], 0] ^= 1
        Image.fromarray(im).save(p0)
        check("mutant octet changé : refusé (sha256)", any("hr-salle-main.png" in e for e in manifeste(tmp)))
        os.remove(os.path.join(tmp, "testeur-glow.png"))
        check("mutant image retirée : refusé", any("manquant testeur-glow.png" in e for e in manifeste(tmp)))
        tab2 = copy.deepcopy(tab)
        tab2["fo-chiller"]["couches"]["main"]["hr"]["shift"][0] += 1.0 / PX
        tab2["fo-chiller"]["couches"]["main"]["lr"]["shift"][0] += 1.0 / PX
        check("mutant shift décalé de 1 px hr : refusé (au pixel)", any("fo-chiller main" in e for e in au_pixel(DEST, src, {"fo-chiller": tab2["fo-chiller"]})))
        tab3 = copy.deepcopy(tab)
        tab3["fo-wire-saw"]["couches"]["glow"]["hr"]["shift"][1] += 0.5 / PX
        check("mutant demi-pixel : refusé (grille)", any("fo-wire-saw glow" in e for e in au_pixel(DEST, src, {"fo-wire-saw": tab3["fo-wire-saw"]})))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("[CALCUL-FEUILLES] BILAN : %d OK, %d ECHEC(S)" % (len(OK), len(KO)))
    return 0 if not KO else 1


if __name__ == "__main__":
    sys.exit(main())
