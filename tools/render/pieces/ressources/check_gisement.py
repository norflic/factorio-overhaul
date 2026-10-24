"""Contrôle d'une feuille de gisement livrée (lot M1, 24/10). Python système (py -3.9), sans Blender.

    py -3.9 tools/render/pieces/ressources/check_gisement.py [graphics/ressources/tungstene] [--nom tungstene]
        [--mutants]

Contrôles (bloquants, code 1 au moindre échec) :
  1. manifeste : chaque fichier listé existe et a la somme sha256 écrite ;
  2. format exact des minerais vanilla : hr 1024 × 1024 (8 × 8 cadres de 128), normale 512 × 512 (cadres de 64), effet
     (s'il existe) aux mêmes tailles, icônes 120 × 64 (64 + 32 + 16 + 8, icon_mipmaps = 4) ;
  3. stades : couverture (alpha > 0,5) DÉCROISSANTE de la ligne 0 (le plus riche) à la ligne 7, à ± 0,05 de la vanilla
     (fer, cuivre, pierre, charbon, directions.COUVERTURE_VANILLA) ; aucun cadre vide ;
  4. aucun pixel dans la bordure de 2 px de chaque cadre hr (un débord serait coupé par le moteur, ou mordrait sur le
     cadre voisin au filtrage) ;
  5. la normale est la réduction 2× de la hr (écart moyen d'alpha < 0,01 ; correction M1 : et de COULEUR prémultipliée
     < 0,02) ;
  6. (correction M1, MINEUR 5 de la vérification) couche d'effet, si elle existe : rien dans la bordure de 2 px, et
     aucun pixel d'effet (alpha > 0,02) hors du minerai (alpha de la hr < 0,05 au même endroit) ;
  7. (correction M1, MAJEUR 2) la répartition des couleurs VUES annoncée par MANIFEST.json (« repartition »,
     mesure.repartition) est celle du fichier hr (à 0,002 près) : aucune palette annoncée sans mesure.
--mutants : chaque contrôle doit REFUSER une copie abîmée (somme fausse, cadre décalé, stade vide, débord, normale
d'une autre feuille, effet décalé, effet dans la bordure, normale toute rouge aux bonnes alphas, répartition annoncée
fausse) ; « BILAN mutants : n/n refusés ».
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
import directions as D  # noqa: E402
import mesure as MS  # noqa: E402

DEFAUT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", "graphics", "ressources", "tungstene"))


def lire(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float64) / 255.0


def controler(dossier, nom, dire=print):
    ok, ko = 0, 0

    def check(c, quoi, detail=""):
        nonlocal ok, ko
        if c:
            ok += 1
            dire("[FO-GISEMENT-CHECK] OK     %s %s" % (quoi, detail))
        else:
            ko += 1
            dire("[FO-GISEMENT-CHECK] ECHEC  %s %s" % (quoi, detail))

    try:
        with open(os.path.join(dossier, "MANIFEST.json"), encoding="utf-8") as f:
            man = json.load(f)
    except (OSError, ValueError) as e:
        check(False, "manifeste lisible", str(e))
        return ok, ko
    faux = []
    for fn in sorted(man.get("sha256", {})):
        p = os.path.join(dossier, fn)
        if not os.path.exists(p):
            faux.append(fn + " absent")
            continue
        with open(p, "rb") as f:
            if hashlib.sha256(f.read()).hexdigest() != man["sha256"][fn]:
                faux.append(fn + " somme")
    check(not faux and len(man.get("sha256", {})) >= 6, "manifeste : fichiers et sommes sha256",
          "(%d fichiers%s)" % (len(man.get("sha256", {})), ("; " + ", ".join(faux)) if faux else ""))
    tailles = {"hr-%s.png" % nom: (1024, 1024), "%s.png" % nom: (512, 512)}
    if os.path.exists(os.path.join(dossier, "hr-%s-effet.png" % nom)):
        tailles["hr-%s-effet.png" % nom] = (1024, 1024)
        tailles["%s-effet.png" % nom] = (512, 512)
    for fn in ("icone.png", "icone-1.png", "icone-2.png", "icone-3.png"):
        tailles[fn] = (120, 64)
    mauvaises = []
    for fn in sorted(tailles):
        p = os.path.join(dossier, fn)
        if not os.path.exists(p):
            mauvaises.append(fn + " absent")
        elif Image.open(p).size != tailles[fn]:
            mauvaises.append("%s %s au lieu de %s" % (fn, Image.open(p).size, tailles[fn]))
    check(not mauvaises, "format des minerais vanilla (feuilles 8 x 8, icônes 64 px + 3 mipmaps)",
          "; ".join(mauvaises))
    hrp = os.path.join(dossier, "hr-%s.png" % nom)
    if not os.path.exists(hrp) or Image.open(hrp).size != (1024, 1024):
        return ok, ko
    hr = lire(hrp)
    a = hr[..., 3]
    couv, vides, bord = [], 0, 0
    for r in range(8):
        cv = []
        for c in range(8):
            t = a[r * 128:(r + 1) * 128, c * 128:(c + 1) * 128]
            cv.append((t > 0.5).mean())
            if (t > 0.5).sum() == 0:
                vides += 1
            m = np.ones_like(t, bool)
            m[2:-2, 2:-2] = False
            bord += int((t[m] > 0.02).sum())
        couv.append(float(np.mean(cv)))
    dec = all(couv[i] >= couv[i + 1] - 0.01 for i in range(7))
    ecart = max(abs(couv[i] - D.COUVERTURE_VANILLA[i]) for i in range(8))
    check(dec and ecart <= 0.05 and vides == 0, "stades : couverture décroissante, proche de la vanilla, aucun cadre vide",
          "(%s ; écart max %.3f ; cadres vides %d)" % (", ".join("%.3f" % x for x in couv), ecart, vides))
    check(bord == 0, "aucun pixel dans la bordure de 2 px des cadres hr", "(%d pixels)" % bord)
    nrp = os.path.join(dossier, "%s.png" % nom)
    if os.path.exists(nrp) and Image.open(nrp).size == (512, 512):
        nr = lire(nrp)[..., 3]
        red = a.reshape(512, 2, 512, 2).mean((1, 3))
        e = float(np.abs(red - nr).mean())
        nrc = lire(nrp)
        prem = (hr[..., :3] * hr[..., 3:4]).reshape(512, 2, 512, 2, 3).mean((1, 3))
        ec = float(np.abs(prem - nrc[..., :3] * nrc[..., 3:4]).mean())
        check(e < 0.01 and ec < 0.02, "la normale est la réduction 2x de la hr (alpha et couleur)",
              "(écart moyen d'alpha %.4f, de couleur prémultipliée %.4f)" % (e, ec))
    efp = os.path.join(dossier, "hr-%s-effet.png" % nom)
    if os.path.exists(efp) and Image.open(efp).size == (1024, 1024):
        ea = lire(efp)[..., 3]
        bord_e = 0
        for r in range(8):
            for c in range(8):
                t = ea[r * 128:(r + 1) * 128, c * 128:(c + 1) * 128]
                m = np.ones_like(t, bool)
                m[2:-2, 2:-2] = False
                bord_e += int((t[m] > 0.02).sum())
        allume = ea > 0.02
        # « hors du minerai » : là où la hr est (presque) transparente ; le fondu de bordure du cadre réduit l'alpha de
        # la hr et celui de l'effet du même facteur : quelques pixels d'effet sur une hr d'alpha 0,1 à 0,3 sont normaux
        hors = int((allume & (a < 0.05)).sum())
        check(bord_e == 0 and hors == 0, "couche d'effet : rien dans la bordure, rien hors du minerai",
              "(%d pixels allumés, %.2f %% du minerai ; bordure %d ; hors minerai %d)" % (
                  int(allume.sum()), 100.0 * allume.sum() / max(1, int((a > 0.5).sum())), bord_e, hors))
    rp_man = man.get("repartition")
    rp = MS.repartition(hr)
    if rp_man is None:
        check(False, "répartition des couleurs vues annoncée au manifeste", "(champ « repartition » absent)")
    else:
        dif = max(abs(rp[k] - rp_man.get(k, -1)) for k in ("sombres", "acier", "acier_bleutes", "chauds"))
        check(dif <= 0.002, "répartition des couleurs vues : annoncée = mesurée",
              "(sombres %.1f %%, acier %.1f %% dont bleutés %.1f %%, chauds %.1f %% ; écart max %.4f)" % (
                  100 * rp["sombres"], 100 * rp["acier"], 100 * rp["acier_bleutes"], 100 * rp["chauds"], dif))
    return ok, ko


def mutants(dossier, nom):
    cas = []

    def somme(d):
        p = os.path.join(d, "icone-2.png")
        im = Image.open(p).convert("RGBA")
        px = im.load()
        r, g, b, al = px[10, 10]
        px[10, 10] = ((r + 7) % 256, g, b, al)
        im.save(p)

    def decale(d):
        p = os.path.join(d, "hr-%s.png" % nom)
        im = lire(p)
        im = np.roll(im, 64, axis=1)
        Image.fromarray((im * 255).round().astype(np.uint8), "RGBA").save(p)

    def stade_vide(d):
        p = os.path.join(d, "hr-%s.png" % nom)
        im = lire(p)
        im[5 * 128:6 * 128, :, 3] = 0
        Image.fromarray((im * 255).round().astype(np.uint8), "RGBA").save(p)

    def deborde(d):
        p = os.path.join(d, "hr-%s.png" % nom)
        im = lire(p)
        im[127, 300:310] = (0.5, 0.5, 0.5, 1.0)
        Image.fromarray((im * 255).round().astype(np.uint8), "RGBA").save(p)

    def normale_autre(d):
        p = os.path.join(d, "%s.png" % nom)
        im = lire(p)
        im = np.flipud(im)
        Image.fromarray((im * 255).round().astype(np.uint8), "RGBA").save(p)

    def icone_taille(d):
        p = os.path.join(d, "icone.png")
        Image.open(p).crop((0, 0, 64, 64)).save(p)

    def resommer(d, fn):
        """Remet la somme du fichier muté dans le manifeste : seul le contrôle propre au défaut doit le refuser."""
        mp = os.path.join(d, "MANIFEST.json")
        with open(mp, encoding="utf-8") as f:
            man = json.load(f)
        with open(os.path.join(d, fn), "rb") as f:
            man["sha256"][fn] = hashlib.sha256(f.read()).hexdigest()
        with open(mp, "w", encoding="utf-8") as f:
            json.dump(man, f)

    def effet_decale(d):
        p = os.path.join(d, "hr-%s-effet.png" % nom)
        im = lire(p)
        im = np.roll(im, 300, axis=1)
        Image.fromarray((im * 255).round().astype(np.uint8), "RGBA").save(p)
        resommer(d, "hr-%s-effet.png" % nom)

    def effet_bordure(d):
        p = os.path.join(d, "hr-%s-effet.png" % nom)
        im = lire(p)
        im[128:130, 200:210] = (0.5, 0.8, 1.0, 0.5)
        Image.fromarray((im * 255).round().astype(np.uint8), "RGBA").save(p)
        resommer(d, "hr-%s-effet.png" % nom)

    def normale_rouge(d):
        p = os.path.join(d, "%s.png" % nom)
        im = lire(p)
        im[..., 0], im[..., 1], im[..., 2] = 1.0, 0.0, 0.0
        Image.fromarray((im * 255).round().astype(np.uint8), "RGBA").save(p)
        resommer(d, "%s.png" % nom)

    def repartition_fausse(d):
        mp = os.path.join(d, "MANIFEST.json")
        with open(mp, encoding="utf-8") as f:
            man = json.load(f)
        man["repartition"] = dict(man.get("repartition", {}), sombres=0.60, acier=0.30, chauds=0.10)
        with open(mp, "w", encoding="utf-8") as f:
            json.dump(man, f)

    for nomm, fn in (("somme fausse", somme), ("cadres décalés de 64 px", decale), ("stade 5 vide", stade_vide),
                     ("débord dans la bordure", deborde), ("normale d'une autre image", normale_autre),
                     ("icône sans mipmaps", icone_taille), ("effet décalé de 300 px", effet_decale),
                     ("effet dans la bordure", effet_bordure), ("normale toute rouge", normale_rouge),
                     ("répartition annoncée 60/30/10", repartition_fausse)):
        tmp = tempfile.mkdtemp(prefix="m1-mutant-")
        try:
            for f in os.listdir(dossier):
                shutil.copy(os.path.join(dossier, f), tmp)
            fn(tmp)
            _, ko = controler(tmp, nom, dire=lambda s: None)
            cas.append((nomm, ko > 0))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    refuses = sum(1 for _, r in cas if r)
    for nomm, r in cas:
        print("[FO-GISEMENT-CHECK] mutant %-28s %s" % (nomm, "REFUSE" if r else "ACCEPTE (FAUX)"))
    print("[FO-GISEMENT-CHECK] BILAN mutants : %d/%d refusés" % (refuses, len(cas)))
    return refuses == len(cas)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dossier", nargs="?", default=DEFAUT)
    ap.add_argument("--nom", default="tungstene")
    ap.add_argument("--mutants", action="store_true")
    a = ap.parse_args()
    ok, ko = controler(a.dossier, a.nom)
    print("[FO-GISEMENT-CHECK] BILAN : %d OK, %d ECHEC(S)" % (ok, ko))
    bon = ko == 0
    if a.mutants:
        bon = mutants(a.dossier, a.nom) and bon
    sys.exit(0 if bon else 1)


if __name__ == "__main__":
    main()
