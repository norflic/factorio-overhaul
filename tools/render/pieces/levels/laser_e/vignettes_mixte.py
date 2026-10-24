"""VIGNETTES MÊLÉES « LASER OU MITRAILLEUSE ? » (lot F1-A, 24/10) : test de NON-CONFUSION entre les deux tourelles d'un
même âge (FICHES_LASER.md §4). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/levels/laser_e/vignettes_mixte.py --dest DOSSIER --laser DOSSIER_SPRITES_LASER
        [--laser 10-15=DOSSIER …] [--ages 1,…,15] [--pose E|N]

Pour chaque âge : une vignette de la mitrailleuse VALIDÉE (sprites de production, planche_gun.GUN) et une du laser,
même cadrage que commun/vignettes.py (12 tuiles, zoom 1, jour, sol vanilla, 384 × 384), chacune avec un NUMÉRO (1 à 30)
tiré au sort sur un cartouche. Mêmes protections contre les fuites de clé que vignettes.py : numéros, noms de fichier
et ordre d'écriture tirés au sort, PNG sans métadonnées, même date de modification, clé (numéro, famille, âge) écrite
SEULEMENT sur la sortie standard (JSON) ; messages sur la sortie d'erreur. Le dossier doit être vide.
Question au lecteur : « pour chaque numéro : laser ou mitrailleuse ? », puis « quels numéros vont par paires (même
âge) ? ». Seuil : 30 sur 30 à la première question (une erreur est bloquante).
"""
import argparse
import json
import os
import secrets
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402
import vignettes as VG  # noqa: E402
import importlib.util  # noqa: E402
# planche_gun est chargé par son chemin : famille.charger retire de sys.path le dossier d'une famille non choisie
_spec = importlib.util.spec_from_file_location("planche_gun_f1", os.path.join(HERE, "planche_gun.py"))
_pg = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_pg)
GUN = _pg.GUN


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--laser", action="append", required=True)
    ap.add_argument("--ages", default="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15")
    ap.add_argument("--pose", default="E", choices=("E", "N"))
    a = ap.parse_args()
    ages = [int(x) for x in a.ages.split(",") if x]
    src_laser = VG.sources(a.laser, ages)
    os.makedirs(a.dest, exist_ok=True)
    if any(f.lower().endswith(".png") for f in os.listdir(a.dest)):
        raise SystemExit("le dossier %s contient déjà des vignettes" % a.dest)
    rnd = secrets.SystemRandom()
    items = [(fam, e) for e in ages for fam in ("gun_e", "laser_e")]
    nums = rnd.sample(range(1, len(items) + 1), len(items))
    imgs = []
    for (fam, e), n in zip(items, nums):
        K.utiliser(fam)
        src = GUN[e] if fam == "gun_e" else src_laser[e]
        rgb, occ = VG.rendu(src, e, a.pose)
        img = K.to_im(rgb)
        cache, nom, x0, y0 = VG.coin(occ)
        if cache:
            print("attention : la vignette %d cache %d px (coin %s)" % (n, cache, nom), file=sys.stderr)
        imgs.append((n, fam, e, VG.lettrer(img, str(n), x0, y0)))
    rnd.shuffle(imgs)
    t_fixe = time.mktime((2026, 1, 1, 12, 0, 0, 0, 1, -1))
    cle = []
    for n, fam, e, img in imgs:
        while True:
            p = os.path.join(a.dest, secrets.token_hex(4) + ".png")
            if not os.path.exists(p):
                break
        img.save(p, optimize=False)
        os.utime(p, (t_fixe, t_fixe))
        cle.append({"numero": n, "famille": "laser" if fam == "laser_e" else "mitrailleuse", "age": e,
                    "fichier": os.path.abspath(p)})
    cle.sort(key=lambda r: r["numero"])
    print("%d vignettes mêlées (pose %s) dans %s" % (len(cle), a.pose, a.dest), file=sys.stderr)
    print(json.dumps({"nom": "mixte-%s" % a.pose, "pose": a.pose, "dossier": os.path.abspath(a.dest), "cle": cle},
                     ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
