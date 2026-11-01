"""Contrôle des feuilles de jeu des QG (lot QG-JEU, 1/11). Python 3.9.

    py -3.9 tools/render/pieces/levels/qg_e/check_qg_sheets.py [--dest graphics/levels/centre] [--sources] [--mutants]

Contrôles (code 0 seulement si tout passe) :
  1. MANIFESTE : chaque fichier listé existe, avec la taille, le sha256 et les dimensions du manifeste ; aucun PNG du dossier
     hors du manifeste ;
  2. sprites.json : les 16 états (âge 0 = l'épave, âges 1 à 15), trois couches chacun (principale, ombre, lueur), hr ET normale
     de dimensions égales à celles du fichier, normale = moitié (arrondie au-dessus) de hr, même shift, 8 192 px au plus
     (F144) ; icône 120 × 64 ; boîte de dessin = union des couches ; sprites.lua porte les mêmes tailles (lecture du texte) ;
  3. ÉCHELLE : l'emprise de l'âge (8×4 aux âges 0 à 3, 10×5, 12×6, 14×7, 16×8 : shared/levels/config.lua, L.footprints.command)
     et le sprite principal s'accordent : largeur de la silhouette opaque entre 0,95 et 1,35 fois la largeur de l'emprise,
     centre horizontal à 0,75 tuile de l'origine au plus, bas de la silhouette à 1,2 tuile au plus de l'arête sud de l'emprise
     (le bâtiment est posé sur son emprise, ses masses montent vers le nord) ;
  4. --sources : chaque PNG hr a EXACTEMENT les pixels de son source (spec.json du rendu) ; chaque PNG normale est la réduction
     recalculée de hr ; shift et tailles de la source ;
  5. --mutants : sur une copie jetable, fichier supprimé, octet changé, taille du manifeste, PNG en trop, largeur dans
     sprites.json, shift décalé, image d'un âge échangée avec celle d'un autre (--sources), doivent être REFUSÉS ; la copie
     intacte acceptée.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile

import numpy as np
from PIL import Image

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import feuilles as FE  # noqa: E402

# Emprise (largeur, hauteur) par âge : l'âge 0 (l'épave) a celle de l'âge 1.
EMPRISE = {0: (8, 4), 1: (8, 4), 2: (8, 4), 3: (8, 4), 4: (10, 5), 5: (10, 5), 6: (10, 5), 7: (12, 6), 8: (12, 6), 9: (12, 6),
           10: (14, 7), 11: (14, 7), 12: (14, 7), 13: (16, 8), 14: (16, 8), 15: (16, 8)}


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def controler(dest, sources=None):
    err = []
    man_p = os.path.join(dest, "MANIFEST.json")
    if not os.path.exists(man_p):
        return ["MANIFEST.json absent (régénérer : %s)" % FE.COMMANDE]
    man = json.load(open(man_p, encoding="utf-8"))
    fich = man["fichiers"]
    pngs = sorted(f for f in os.listdir(dest) if f.endswith(".png"))
    for f in pngs:
        if f not in fich:
            err.append("PNG hors du manifeste : %s" % f)
    for f, m in sorted(fich.items()):
        p = os.path.join(dest, f)
        if not os.path.exists(p):
            err.append("fichier manquant : %s (régénérer : %s)" % (f, FE.COMMANDE))
            continue
        if os.path.getsize(p) != m["taille"]:
            err.append("%s : %d octets, manifeste %d" % (f, os.path.getsize(p), m["taille"]))
        elif sha(p) != m["sha256"]:
            err.append("%s : sha256 différent du manifeste" % f)
        w, h = Image.open(p).size
        if (w, h) != (m["largeur"], m["hauteur"]):
            err.append("%s : %dx%d, manifeste %dx%d" % (f, w, h, m["largeur"], m["hauteur"]))
    sj_p = os.path.join(dest, "sprites.json")
    sl_p = os.path.join(dest, "sprites.lua")
    if not os.path.exists(sj_p) or not os.path.exists(sl_p):
        return err + ["sprites.json ou sprites.lua absent"]
    tab = json.load(open(sj_p, encoding="utf-8"))
    lua = open(sl_p, encoding="utf-8").read()
    if lua.split("return ", 1)[1].strip() != FE.lua({"ages": {int(k): v for k, v in tab["ages"].items()}}).strip():
        err.append("sprites.lua n'est pas le texte régénéré de sprites.json")
    ages = tab.get("ages", {})
    for age in range(0, 16):
        a = ages.get(str(age))
        if not a:
            err.append("âge %d absent de sprites.json" % age)
            continue
        for k in ("main", "shadow", "glow"):
            c = a.get(k)
            if not c:
                err.append("âge %d : couche %s absente" % (age, k))
                continue
            for q in ("hr", "lr"):
                d = c[q]
                f = os.path.basename(d["filename"])
                p = os.path.join(dest, f)
                if not os.path.exists(p):
                    err.append("âge %d %s %s : %s absent" % (age, k, q, f))
                    continue
                if Image.open(p).size != (d["width"], d["height"]):
                    err.append("âge %d %s %s : %s fait %s, sprites.json %dx%d" % (age, k, q, f, Image.open(p).size, d["width"], d["height"]))
                if max(d["width"], d["height"]) > 8192:
                    err.append("âge %d %s %s dépasse 8 192 px (F144)" % (age, k, q))
            if c["lr"]["width"] != (c["hr"]["width"] + 1) // 2 or c["lr"]["height"] != (c["hr"]["height"] + 1) // 2:
                err.append("âge %d %s : la normale n'est pas la moitié de hr" % (age, k))
            if c["lr"]["shift"] != c["hr"]["shift"]:
                err.append("âge %d %s : shift différent entre hr et normale" % (age, k))
            for q in ("hr", "lr"):
                d = c[q]
                if ("width = %d" % d["width"]) not in lua or ("height = %d" % d["height"]) not in lua:
                    err.append("âge %d %s %s : tailles absentes de sprites.lua" % (age, k, q))
        ic = a.get("icone")
        if not ic or Image.open(os.path.join(dest, os.path.basename(ic["filename"]))).size != (120, 64):
            err.append("âge %d : icône absente ou pas 120 × 64" % age)
        if "main" in a and "shadow" in a and "glow" in a:
            rs = [FE.rect(a[k]) for k in ("main", "shadow", "glow")]
            want = [[round(min(r[0] for r in rs), 4), round(min(r[1] for r in rs), 4)],
                    [round(max(r[2] for r in rs), 4), round(max(r[3] for r in rs), 4)]]
            if want != a["boite"]:
                err.append("âge %d : boîte de dessin %s, union des couches %s" % (age, a["boite"], want))
            # 3. échelle
            p = os.path.join(dest, os.path.basename(a["main"]["hr"]["filename"]))
            if os.path.exists(p):
                al = np.asarray(Image.open(p).convert("RGBA"))[..., 3] > 40
                ys, xs = np.nonzero(al)
                sx, sy = a["main"]["hr"]["shift"]
                W, H = a["main"]["hr"]["width"], a["main"]["hr"]["height"]
                x0, x1 = (xs.min() - W / 2) / 64 + sx, (xs.max() + 1 - W / 2) / 64 + sx
                y1 = (ys.max() + 1 - H / 2) / 64 + sy
                ew, eh = EMPRISE[age]
                larg = x1 - x0
                if not (0.95 * ew <= larg <= 1.35 * ew):
                    err.append("âge %d : silhouette de %.1f tuiles de large, emprise %d×%d (0,95 à 1,35 fois la largeur)" % (age, larg, ew, eh))
                if abs((x0 + x1) / 2) > 0.75:
                    err.append("âge %d : silhouette décentrée de %.2f tuile" % (age, (x0 + x1) / 2))
                if abs(y1 - eh / 2) > 1.2:
                    err.append("âge %d : bas de la silhouette à %.2f, arête sud de l'emprise à %.1f" % (age, y1, eh / 2))
    if sources:
        for age in range(0, 16):
            sp = os.path.join(sources, "qg%02d" % age, "spec.json")
            if not os.path.exists(sp):
                err.append("source de l'âge %d absente : %s" % (age, sp))
                continue
            s = json.load(open(sp, encoding="utf-8"))
            for k in ("main", "shadow", "glow"):
                L = s["layers"].get(k)
                a = ages.get(str(age), {}).get(k)
                if not (L and a):
                    err.append("âge %d %s : couche absente (source ou sprites.json)" % (age, k))
                    continue
                src = Image.open(os.path.join(sources, "qg%02d" % age, L["file"])).convert("RGBA")
                hr = Image.open(os.path.join(dest, "hr-qg%02d-%s.png" % (age, k))).convert("RGBA")
                if src.size != hr.size or not np.array_equal(np.asarray(src), np.asarray(hr)):
                    err.append("âge %d %s : pixels hr différents de la source" % (age, k))
                lr = Image.open(os.path.join(dest, "qg%02d-%s.png" % (age, k))).convert("RGBA")
                if not np.array_equal(np.asarray(FE.reduite(hr)), np.asarray(lr)):
                    err.append("âge %d %s : la normale n'est pas la réduction de hr" % (age, k))
                if [L["shift"][0], L["shift"][1]] != a["hr"]["shift"]:
                    err.append("âge %d %s : shift %s, source %s" % (age, k, a["hr"]["shift"], L["shift"]))
    return err


def mutants(dest, sources):
    base = tempfile.mkdtemp(prefix="qg-mut-")
    refus, manques = 0, []

    def essai(nom, f, src=False):
        nonlocal refus
        d = os.path.join(base, "m")
        if os.path.exists(d):
            shutil.rmtree(d)
        shutil.copytree(dest, d)
        f(d)
        e = controler(d, sources if src else None)
        if e:
            refus += 1
        else:
            manques.append(nom)

    def sup(d): os.remove(os.path.join(d, "hr-qg08-main.png"))

    def octet(d):
        p = os.path.join(d, "qg05-glow.png")
        b = bytearray(open(p, "rb").read())
        b[-20] ^= 0xFF
        open(p, "wb").write(bytes(b))

    def taille(d):
        m = json.load(open(os.path.join(d, "MANIFEST.json"), encoding="utf-8"))
        m["fichiers"]["qg03-main.png"]["taille"] += 1
        json.dump(m, open(os.path.join(d, "MANIFEST.json"), "w", encoding="utf-8"))

    def trop(d): shutil.copy(os.path.join(d, "qg03-main.png"), os.path.join(d, "qg99-main.png"))

    def largeur(d):
        t = json.load(open(os.path.join(d, "sprites.json"), encoding="utf-8"))
        t["ages"]["7"]["main"]["hr"]["width"] += 2
        json.dump(t, open(os.path.join(d, "sprites.json"), "w", encoding="utf-8"), indent=1, sort_keys=True)

    def shift(d):
        for n in ("sprites.json",):
            t = json.load(open(os.path.join(d, n), encoding="utf-8"))
            t["ages"]["12"]["main"]["hr"]["shift"][0] += 0.5
            json.dump(t, open(os.path.join(d, n), "w", encoding="utf-8"), indent=1, sort_keys=True)

    def echange(d):
        a, b = os.path.join(d, "hr-qg04-main.png"), os.path.join(d, "hr-qg05-main.png")
        ia, ib = Image.open(a), Image.open(b)
        ib.resize(ia.size).save(a)
        m = json.load(open(os.path.join(d, "MANIFEST.json"), encoding="utf-8"))
        m["fichiers"]["hr-qg04-main.png"] = {"sha256": sha(a), "taille": os.path.getsize(a), "largeur": ia.size[0], "hauteur": ia.size[1]}
        json.dump(m, open(os.path.join(d, "MANIFEST.json"), "w", encoding="utf-8"))

    essai("fichier supprimé", sup)
    essai("octet changé", octet)
    essai("taille du manifeste", taille)
    essai("PNG en trop", trop)
    essai("largeur dans sprites.json", largeur)
    essai("shift décalé (silhouette décentrée)", shift)
    if sources:
        essai("image d'un âge remplacée (sources)", echange, src=True)
    intact = not controler(dest, sources)
    shutil.rmtree(base, ignore_errors=True)
    return refus, manques, intact


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=FE.DEST_DEFAUT)
    ap.add_argument("--src", default=FE.SRC_DEFAUT)
    ap.add_argument("--sources", action="store_true")
    ap.add_argument("--mutants", action="store_true")
    a = ap.parse_args()
    err = controler(a.dest, a.src if a.sources else None)
    for e in err[:30]:
        print("  ECHEC : " + e)
    n_ok = 0 if err else 1
    print("[FO-CHECK-QG] feuilles : %s (%d écart(s))" % ("OK" if not err else "ECHEC", len(err)))
    code = 1 if err else 0
    if a.mutants and not err:
        refus, manques, intact = mutants(a.dest, a.src if a.sources else None)
        print("[FO-CHECK-QG] mutants : %d refusé(s), %d non détecté(s) %s, copie intacte %s" % (
            refus, len(manques), manques, "acceptée" if intact else "REFUSÉE"))
        if manques or not intact:
            code = 1
    print("[FO-CHECK-QG] BILAN : %s" % ("OK" if code == 0 else "ECHEC"))
    sys.exit(code)


if __name__ == "__main__":
    main()
