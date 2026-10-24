"""Éclat de tir de la mitrailleuse EN JEU (lot A4) : où le moteur dessine-t-il la couche d'éclat ? Python 3.9.

    py -3.9 tools/autotest/a4_eclat_images.py --paire <captures a4-eclat du mod> <captures a4-eclat du TÉMOIN>
        [--paire <a4-eclat-impair du mod> <a4-eclat-impair du témoin>] [--feuilles <mod>/graphics/levels/gun]
        [--planche SORTIE.png]

Fait constaté au premier passage (24/10) : la couche d'attacking_animation n'est dessinée qu'un court instant à
chaque coup (21 captures en tir sur 126) ; aux autres instants, la différence est nulle. D'où 3 instants par site et
deux sessions décalées d'un tick : un site est en ÉCHEC s'il n'est vu dans aucune capture.

Le témoin est une copie jetable du mod dont gun.lua ne pose PAS la couche d'éclat (tout le reste identique) ; les deux
sessions fo-captures.bat a4-eclat jouent la même carte aux mêmes ticks (le jeu est déterministe ; le contrôle
« négatif » ci-dessous le vérifie). La différence (avec − sans) d'une capture EN TIR ne contient donc que la couche
d'éclat, additive. Pour chaque capture (table fo-shots/a4-eclat-sites.tsv) :
  - image montrée k : orientation relue (64 directions : arrondi de l'angle déprojeté, comme gun-rose ; 4 directions :
    N, E, S, O le plus proche) ;
  - centres ATTENDUS : bouts des canons mesurés sur la feuille de tête (sprites.json, outils.eclat_tir.bouts) avancés
    de AVANCE × longueur le long du tir (eclat_tir.py) ;
  - énergie de la différence, part de cette énergie à moins de 0,6 tuile d'un centre attendu, distance médiane
    (pondérée) au centre le plus proche, énergie NÉGATIVE (avec < sans : doit être nulle).
OK si l'énergie est présente, la part ≥ 0,8 et la médiane ≤ 0,35 tuile. Captures « arret » (tir coupé, munitions
retirées) : la différence doit être NULLE (la couche n'existe qu'en tir). Code 0 si tout passe.
"""
import argparse
import csv
import glob
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GUN_E = os.path.join(os.path.dirname(HERE), "render", "pieces", "levels", "gun_e")
sys.path.insert(0, GUN_E)
import eclat_tir as ET  # noqa: E402
import feuilles as FE  # noqa: E402

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PX = 64.0          # zoom 2 : 64 px par tuile
R_OK = 0.6         # tuile
PART_MIN = 0.8
MED_MAX = 0.35
BAR_MAX = 0.3      # tuile : barycentre de la différence contre milieu des centres attendus
SEUIL_PX = 6       # somme RGB (0 à 765) par pixel : en dessous, ignoré
E_MIN = 2000       # énergie (somme des pixels retenus) : en dessous, pas de couche d'éclat (bruit de fumée ou de
                   # particules ; premier passage : au plus 195 hors éclat, contre 6 × 10^4 à 1,4 × 10^6 avec)


def image_montree(o, n):
    th = math.atan2(math.sin(2 * math.pi * o), math.cos(2 * math.pi * o) / FE.PROJ_IMAGE)
    return int(math.floor(n * th / (2 * math.pi) + 0.5)) % n


def charge(d, nom):
    f = glob.glob(os.path.join(d, "[0-9][0-9][0-9]-%s.png" % nom))
    if len(f) != 1:
        return None
    return np.asarray(Image.open(f[0]).convert("RGB")).astype(np.int32)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--paire", nargs=2, action="append", required=True, metavar=("AVEC", "SANS"),
                    help="captures du mod et du témoin d'une même session (a4-eclat, a4-eclat-impair) ; répétable")
    ap.add_argument("--feuilles", default=FE.DEST_DEFAUT)
    ap.add_argument("--planche", default=None)
    a = ap.parse_args()
    import json
    donnees = json.load(open(os.path.join(a.feuilles, "sprites.json"), encoding="utf-8"))
    n_vues = n_ko = n_arret = 0
    bruit_max = 0
    vues = []
    par_site = {}
    for avec, sans in a.paire:
        sites = list(csv.DictReader(open(os.path.join(avec, "a4-eclat-sites.tsv"), encoding="utf-8"), delimiter="\t"))
        for s in sites:
            av, sa = charge(avec, s["capture"]), charge(sans, s["capture"])
            if av is None or sa is None:
                print("[FO-A4-ECLAT-IMG] ECHEC  %s : capture absente (%s)" % (s["capture"], avec))
                n_ko += 1
                continue
            diff = av - sa
            pos = np.clip(diff, 0, None).sum(-1)
            neg = np.clip(-diff, 0, None).sum(-1)
            e_pos, e_neg = int(pos[pos > SEUIL_PX].sum()), int(neg[neg > SEUIL_PX].sum())
            site = s["capture"].rsplit("-i", 1)[0] if s["etat"] == "tir" else s["capture"]
            if s["etat"] == "arret":
                n_arret += 1
                bruit_max = max(bruit_max, e_pos, e_neg)
                if max(e_pos, e_neg) >= E_MIN:
                    print("[FO-A4-ECLAT-IMG] ECHEC  %s (arrêt) : différence (+%d, -%d)" % (s["capture"], e_pos, e_neg))
                    n_ko += 1
                continue
            if e_pos < E_MIN:
                bruit_max = max(bruit_max, e_pos, e_neg)
                par_site.setdefault(site, [])
                continue
            e = int(s["age"])
            A = donnees["ages"][str(e)]
            nd = A["eclat"]["lr"]["direction_count"]
            k = image_montree(float(s["orientation"]), nd)
            nom = ("N", "E", "S", "O")[k] if nd == 4 else "d%02d" % k
            Lf = ET.L0_PX * ET.taille_age(e)
            (ux, uy), fz = ET._sol_vers_ecran(FE.direction_sol(nom), 0.0)
            cen = [(x + ux * ET.AVANCE * Lf * fz / 64.0, y + uy * ET.AVANCE * Lf * fz / 64.0)
                   for x, y in A["outils"]["eclat_tir"]["bouts"][nom]]
            H, W = pos.shape
            cx, cy = float(s["x"]), float(s["y"]) - 1.0
            tx, ty = float(s["x"]), float(s["y"])
            vv, uu = np.nonzero(pos > SEUIL_PX)
            wts = pos[vv, uu].astype(np.float64)
            wx = cx + (uu + 0.5 - W / 2.0) / PX - tx
            wy = cy + (vv + 0.5 - H / 2.0) / PX - ty
            # seuils à la taille de l'éclat de l'âge (longueur de base Lf : 0,53 tuile à l'âge 2, 1,59 à l'âge 15)
            r_ok = max(R_OK, 0.75 * Lf / 64.0)
            med_max = max(MED_MAX, 0.35 * Lf / 64.0)
            dist = np.min(np.stack([np.hypot(wx - x, wy - y) for x, y in cen]), axis=0)
            part = float(wts[dist <= r_ok].sum() / wts.sum())
            ordre = np.argsort(dist)
            cum = np.cumsum(wts[ordre]) / wts.sum()
            med = float(dist[ordre][np.searchsorted(cum, 0.5)])
            bar = (float((wx * wts).sum() / wts.sum()), float((wy * wts).sum() / wts.sum()))
            moy = (sum(x for x, _ in cen) / len(cen), sum(y for _, y in cen) / len(cen))
            e_bar = math.hypot(bar[0] - moy[0], bar[1] - moy[1])
            ok = part >= PART_MIN and med <= med_max and e_bar <= BAR_MAX and e_neg < E_MIN
            n_vues += 1
            n_ko += not ok
            par_site.setdefault(site, []).append(ok)
            print("[FO-A4-ECLAT-IMG] %s %s : image %s (%d dir.), énergie %d, part à %.2f tuile %.2f, médiane %.3f "
                  "tuile (max %.2f), barycentre (%.2f ; %.2f) à %.3f tuile du milieu attendu, centres attendus %s, "
                  "négatif %d" % (
                      "OK    " if ok else "ECHEC ", s["capture"], nom, nd, e_pos, r_ok, part, med, med_max, bar[0],
                      bar[1], e_bar, [(round(x, 2), round(y, 2)) for x, y in cen], e_neg))
            vues.append((avec, s, nom, (uu, vv, pos), cen))
    # sites de JOUR (3 instants par session) : chacun doit être vu ; sites de nuit (1 instant) : dit seulement
    jamais = sorted(k for k, v in par_site.items() if not v and not k.endswith("-nuit"))
    nuit = sorted(k for k, v in par_site.items() if k.endswith("-nuit"))
    nuit_vus = [k for k in nuit if par_site[k]]
    vus = sorted(k for k, v in par_site.items() if v and not k.endswith("-nuit"))
    print("[FO-A4-ECLAT-IMG] captures en tir où la couche d'éclat est dessinée : %d ; sites de jour vus au moins une "
          "fois : %d sur %d ; jamais vus : %s ; sites de nuit vus (1 instant par session, non exigé) : %d sur %d (%s)" % (
              n_vues, len(vus), len(vus) + len(jamais), ", ".join(jamais) or "aucun", len(nuit_vus), len(nuit),
              ", ".join(nuit_vus)))
    print("[FO-A4-ECLAT-IMG] captures à l'arrêt : %d ; plus grande différence hors éclat (bruit, somme RGB) : %d "
          "(seuil %d)" % (n_arret, bruit_max, E_MIN))
    n_ko += len(jamais)
    print("[FO-A4-ECLAT-IMG] BILAN : %d éclat(s) au bout des canons, %d ECHEC(S) (dont %d site(s) jamais vu(s))" % (
        n_vues - (n_ko - len(jamais)), n_ko, len(jamais)))
    if a.planche:
        planche(vues, a.planche)
    return 0 if n_ko == 0 else 1


def planche(vues, out):
    """Chaque capture en tir (10 × 10 tuiles, réduite de moitié) : à gauche la capture, à droite la différence (couche
    d'éclat seule, somme RGB bornée à 255) avec les centres attendus (croix vertes)."""
    from PIL import ImageDraw
    c = 320
    cases = []
    for d, s, nom, dd, cen in vues:
        im = Image.open(glob.glob(os.path.join(d, "[0-9][0-9][0-9]-%s.png" % s["capture"]))[0]).convert("RGB")
        W, H = im.size
        g = im.resize((c, c), Image.LANCZOS)
        dif = np.zeros((H, W, 3), np.uint8)
        if dd is not None:
            uu, vv, pos = dd
            v = np.clip(pos[vv, uu], 0, 255).astype(np.uint8)
            dif[vv, uu] = np.stack([v, v, v], -1)
        dr_ = Image.fromarray(dif).resize((c, c), Image.LANCZOS)
        both = Image.new("RGB", (2 * c, c))
        both.paste(g, (0, 0))
        both.paste(dr_, (c, 0))
        dr = ImageDraw.Draw(both)
        for x, y in cen:
            # capture centrée en (x, y − 1) de la tourelle, 64 px par tuile, réduite de moitié
            px = c + c // 2 + x * PX / 2
            py = c // 2 + (y + 1) * PX / 2
            dr.line([(px - 4, py), (px + 4, py)], fill=(0, 255, 0))
            dr.line([(px, py - 4), (px, py + 4)], fill=(0, 255, 0))
        dr.text((4, 4), "%s (%s)" % (s["capture"], nom), fill=(255, 255, 0))
        cases.append(both)
    ncol = 4
    M = Image.new("RGB", (ncol * 2 * c, ((len(cases) + ncol - 1) // ncol) * c))
    for i, b in enumerate(cases):
        M.paste(b, ((i % ncol) * 2 * c, (i // ncol) * c))
    M.save(out)
    print("[FO-A4-ECLAT-IMG] planche : %s (%d cases)" % (out, len(cases)))


if __name__ == "__main__":
    sys.exit(main())
