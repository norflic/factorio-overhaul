"""Lot A3 (24/10) : ESTIMATION, pour le lot A3-jeu, des feuilles de tête à 64 directions (dimensions, découpe en fichiers,
mégapixels, mémoire vidéo). Rien n'est écrit dans le mod. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/estime_feuilles.py [--produits DIR] [--masques DIR] [--dest DIR]
        [--line-length 8]

Par âge (2 à 15), couche (main, glow, shadow) et résolution (hr 64 px/tuile, normale 32) :
  - boîte de chaque pose relative à l'origine (px hr) : spec.json de la pose quand elle est rendue (validées N et E,
    d32 et d48 du lot A2, têtes produites par produire_a3.py dans --produits) ; sinon ESTIMÉE : couche principale = boîte
    du masque rapide (alpha > 0) élargie de 2 px (recadrage pair de rendre.py) ; lueur = boîte de la couche principale
    (la lueur est sous la silhouette ; vérifié sur les poses rendues : colonne « lueur ⊂ main ») ; ombre = boîte de la
    couche principale décalée comme en moyenne sur les poses rendues de l'âge (côtés gauche, haut, droit, bas) ;
  - cadre commun = union des 64 poses aux bords PAIRS (comme feuilles.py) ; feuille = line_length colonnes ×
    64 / line_length lignes ; découpe si une dimension dépasse 8192 px (limite du moteur 1.1.91 : « The game engine
    limits the width of any input files to 8192px », prototype-api.json ; « Width and height may only be in the range
    of 0-8192 ») ;
  - mégapixels : feuille entière (borne haute : le moteur range chaque image entière) et somme des boîtes propres des
    poses (borne basse, si le moteur rognait le transparent de chaque image : NON prouvé) ;
  - comparaison aux feuilles à 4 directions d'aujourd'hui (graphics/levels/gun/sprites.json) et au relevé D4m d'A2
    (haute 1,087 Gpx, normale 0,339, plancher 0,199 + pages) ; mémoire vidéo par le rapport octets / pixel MESURÉ par
    A2 (estimation de vram.py sur le journal : haute 1,12 à 1,27 Go pour 1,087 Gpx ; normale 0,41 à 0,45 Go pour 0,339).
Sortie : DIR/estimation.txt et DIR/estimation.json.
"""
import argparse
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
sys.path.insert(0, HERE)
import masques as MQ  # noqa: E402

A3 = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-24_A3"
LIMITE = 8192
COUCHES = ("main", "glow", "shadow")
A2_GPX = {"haute": 1.087, "normale": 0.339, "plancher": 0.199}
A2_GO = {"haute": (1.12, 1.27), "normale": (0.41, 0.45)}


def boite(L):
    w, h = L["width"], L["height"]
    gx = L["shift"][0] * 64 - w / 2.0
    gy = L["shift"][1] * 64 - h / 2.0
    return [int(round(gx)), int(round(gy)), int(round(gx)) + w, int(round(gy)) + h]


def pose_rendue(e, k, produits):
    cands = []
    if k == 0:
        cands.append((MQ.plages(MQ.VALIDES)[e], "e%02d-tete-N" % e))
    if k == 16:
        cands.append((MQ.plages(MQ.VALIDES)[e], "e%02d-tete-E" % e))
    if k in (32, 48):
        cands.append((MQ.SO, "e%02d-tete-d%02d" % (e, k)))
    cands.append((produits, "e%02d-tete-d%02d" % (e, k)))
    for d, n in cands:
        p = os.path.join(d, n, "spec.json")
        if os.path.exists(p):
            s = json.load(open(p, encoding="utf-8"))
            return {c: boite(s["layers"][c]) for c in COUCHES if c in s["layers"]}
    return None


def boite_masque(masques, e, k):
    z = MQ.charge(masques, e, "d%02d" % k)
    a = MQ.alpha_prod(z, e, "d%02d" % k)
    ys, xs = np.nonzero(a > 0)
    ox, oy = (int(v) for v in z["origin"])
    return [int(xs.min()) - ox - 2, int(ys.min()) - oy - 2, int(xs.max()) + 1 - ox + 2, int(ys.max()) + 1 - oy + 2]


def union_paire(bs):
    x0 = min(b[0] for b in bs)
    y0 = min(b[1] for b in bs)
    x1 = max(b[2] for b in bs)
    y1 = max(b[3] for b in bs)
    x0 -= x0 % 2
    y0 -= y0 % 2
    x1 += x1 % 2
    y1 += y1 % 2
    return [x0, y0, x1, y1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--produits", default=os.path.join(A3, "sprites"))
    ap.add_argument("--masques", default=os.path.join(A3, "masques", "m16"))
    ap.add_argument("--masques-bouchon", default=os.path.join(A3, "bouchon", "rampe80"))
    ap.add_argument("--dest", default=os.path.join(A3, "estimation"))
    ap.add_argument("--line-length", type=int, default=8)
    a = ap.parse_args()
    MQ.AUTRES.update({e: a.masques_bouchon for e in (4, 5, 6, 7)})
    sj = json.load(open(os.path.join(MOD, "graphics", "levels", "gun", "sprites.json"), encoding="utf-8"))
    L = ["Estimation des feuilles de tête à 64 directions (lot A3, pour A3-jeu) ; line_length %d ; limite %d px par "
         "fichier" % (a.line_length, LIMITE),
         "âge couche  poses rendues  cadre hr (l x h)  feuille hr (l x h)  fichiers  Mpx hr feuille / rognée  "
         "Mpx normale feuille  | 4 dir. aujourd'hui Mpx hr / normale"]
    res = {}
    tot = {"hr_plein": 0.0, "hr_rogne": 0.0, "lr_plein": 0.0, "lr_rogne": 0.0, "hr_4": 0.0, "lr_4": 0.0}
    controle_lueur = []
    for e in range(2, 16):
        rend = {k: pose_rendue(e, k, a.produits) for k in range(64)}
        connues = [k for k in range(64) if rend[k]]
        # décalage moyen de l'ombre par rapport à la couche principale, sur les poses rendues de l'âge
        dsh = np.mean([[rend[k]["shadow"][i] - rend[k]["main"][i] for i in range(4)] for k in connues], 0)
        for k in connues:
            if "glow" in rend[k]:
                g, m = rend[k]["glow"], rend[k]["main"]
                controle_lueur.append(g[0] >= m[0] - 2 and g[1] >= m[1] - 2 and g[2] <= m[2] + 2 and g[3] <= m[3] + 2)
        boxes = {c: [] for c in COUCHES}
        for k in range(64):
            if rend[k]:
                for c in COUCHES:
                    if c in rend[k]:
                        boxes[c].append(rend[k][c])
            else:
                bm = boite_masque(a.masques, e, k)
                boxes["main"].append(bm)
                boxes["glow"].append(bm)
                boxes["shadow"].append([int(round(bm[i] + dsh[i])) for i in range(4)])
        res[e] = {"poses_rendues": len(connues)}
        for c in COUCHES:
            u = union_paire(boxes[c])
            fw, fh = u[2] - u[0], u[3] - u[1]
            ll = a.line_length
            while ll > 1 and ll * fw > LIMITE:
                ll //= 2
            lignes = 64 // ll
            lignes_par_fichier = max(1, min(lignes, LIMITE // fh))
            fichiers = int(math.ceil(lignes / float(lignes_par_fichier)))
            plein = 64 * fw * fh / 1e6
            rogne = sum((b[2] - b[0]) * (b[3] - b[1]) for b in boxes[c]) / 1e6
            t4 = sj["ages"][str(e)]["tete"][c]
            hr4 = t4["hr"]["width"] * t4["hr"]["height"] * 4 / 1e6
            lr4 = t4["lr"]["width"] * t4["lr"]["height"] * 4 / 1e6
            res[e][c] = {"cadre_hr": [fw, fh], "cadre_lr": [fw // 2, fh // 2], "line_length": ll,
                         "feuille_hr": [ll * fw, lignes_par_fichier * fh], "feuille_lr": [ll * fw // 2,
                                                                                         lignes_par_fichier * fh // 2],
                         "fichiers": fichiers, "mpx_hr_feuille": round(plein, 3), "mpx_hr_rognee": round(rogne, 3),
                         "mpx_lr_feuille": round(plein / 4, 3), "mpx_hr_4dir": round(hr4, 3),
                         "mpx_lr_4dir": round(lr4, 3)}
            tot["hr_plein"] += plein
            tot["hr_rogne"] += rogne
            tot["lr_plein"] += plein / 4
            tot["lr_rogne"] += rogne / 4
            tot["hr_4"] += hr4
            tot["lr_4"] += lr4
            L.append("%3d %-6s %13d  %7d x %-5d  %7d x %-6d  %8d  %9.2f / %6.2f  %10.2f  | %6.2f / %5.2f" % (
                e, c, len(connues), fw, fh, ll * fw, lignes_par_fichier * fh, fichiers, plein, rogne, plein / 4, hr4,
                lr4))
    L.append("")
    L.append("lueur dans la boîte de la couche principale (±2 px) sur les poses rendues : %d / %d" % (
        sum(controle_lueur), len(controle_lueur)))
    d_hr = (tot["hr_plein"] - tot["hr_4"]) / 1e3
    d_hr_r = (tot["hr_rogne"] - tot["hr_4"]) / 1e3
    d_lr = (tot["lr_plein"] - tot["lr_4"]) / 1e3
    d_lr_r = (tot["lr_rogne"] - tot["lr_4"]) / 1e3
    L.append("TOTAL têtes 64 directions : hr %.1f Mpx (feuilles) / %.1f Mpx (rognées) ; normale %.1f / %.1f Mpx ; "
             "aujourd'hui (4 directions) hr %.1f, normale %.1f Mpx" % (tot["hr_plein"], tot["hr_rogne"], tot["lr_plein"],
                                                                       tot["lr_rogne"], tot["hr_4"], tot["lr_4"]))
    for q, d1, d2 in (("haute", d_hr, d_hr_r), ("normale", d_lr, d_lr_r)):
        g0 = A2_GPX[q]
        lo, hi = A2_GO[q]
        L.append("%-8s : relevé A2 %.3f Gpx (%.2f à %.2f Go) ; ajout %.3f Gpx (rognées : %.3f) -> %.3f Gpx (+%.0f %%) ; "
                 "mémoire estimée %.2f à %.2f Go (rognées : %.2f à %.2f)" % (
                     q, g0, lo, hi, d1, d2, g0 + d1, 100 * d1 / g0, (g0 + d1) * lo / g0, (g0 + d1) * hi / g0,
                     (g0 + d2) * lo / g0, (g0 + d2) * hi / g0))
    L.append("plancher : relevé A2 0,199 Gpx d'atlas + 151 Mpx de pages d'atlas virtuel ; les sprites de la qualité "
             "normale ajoutés (%.3f Gpx, rognées %.3f) iraient à l'atlas virtuel en flux (pages fixes, F102 / E55) : "
             "mémoire vidéo des pages inchangée PAR HYPOTHÈSE, RAM des sources + environ %.0f Mo (RGBA 4 octets/px) ; "
             "NON mesuré" % (d_lr, d_lr_r, d_lr * 4e3))
    txt = "\n".join(L)
    print(txt)
    os.makedirs(a.dest, exist_ok=True)
    open(os.path.join(a.dest, "estimation.txt"), "w", encoding="utf-8").write(txt + "\n")
    json.dump({"ages": res, "totaux_mpx": tot}, open(os.path.join(a.dest, "estimation.json"), "w", encoding="utf-8"),
              indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
