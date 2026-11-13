"""FEUILLES DE JEU DES TITANS (lot TITANS, 9/11 ; FINITIONS 10/11) : rendus -> graphics/robots/titans/ (PNG hors de git, D-6), sprites.lua
(généré, lu par prototypes/titans.lua et prototypes/titans_kaiju.lua) et MANIFEST.json (commité). Hors Blender : réduction, rognage, feuilles.

    PYTHONUTF8=1 py -3.9 tools/render/pieces/titans/feuilles_titans.py [--src DIR] [--dest DIR]      (depuis la racine du mod)

Sources (à GARDER) : fo-logs/2026-11-10_TITANS-FINITIONS/rendu/ : <allié>-<stage>/ (main.png, glow_*.png, shadow.png, spec.json : post des géants) ;
kaiju/kaiju-<anim>-<image>-<dir>.npz et juggernaut-anime-<stage>/juggernaut-<stage>-<anim>-<image>-<dir>.npz (main, ao, ombre, glow, origine,
densite ; batch_titans.py).
- Alliés à UNE image (Sentinelle, Léviathan + son drone) : même traitement que les géants (feuilles_xp.geant : corps haute 32 px/tuile,
  normale 16 ; lueurs fondues en UNE couche ; ombre 16 / 8 ; icône 64), un corps par stade (1 à 3 ; « drone » : une image).
- ANIMÉS (Kaiju ; Juggernaut, trois stades, depuis FINITIONS) : par animation (course 8 images, attaque 4) et par couche (main, glow, shadow),
  UN fichier PAR DIRECTION (8), images en lecture continue (`line_length` colonnes, `lines_per_file` lignes), cellule = union des rognages de
  toutes les images et directions ; hr- : densité du rendu (Kaiju 24 px/tuile, Juggernaut 20) divisée par `divs` de la couche (ombre du
  Juggernaut : 2) ; sans préfixe : la moitié. Aucune feuille au-delà de MAX_PX (Kaiju 2 048, Juggernaut 4 096 : 36 tuiles de haut).
  Liseré de contact composé sous le corps (fo_post.compose_main, points isolés retirés comme les souches). La lueur du Kaiju est rendue
  BLANCHE (batch_titans) : le prototype la teinte par ère ; celle du Juggernaut garde ses couleurs.
"""
import argparse
import ast
import glob
import hashlib
import json
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "pieces", "experimentaux"))
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import feuilles_xp as FX  # noqa: E402

LOGS = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs", "2026-11-10_TITANS-FINITIONS")
LOGS2 = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs", "2026-11-10_KAIJUS-MUTANTS")
# plusieurs dossiers de sources (séparés par « ; ») : un titan est pris dans le premier qui a son sous-dossier (KAIJUS-MUTANTS, 10/11)
LOGS3 = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs", "2026-11-10_VISUELS-DISTINCTS")
# VISUELS-DISTINCTS (10/11) : les Écorchés re-rendus (chair, peau, silhouette et collerette par variante) sont pris en PREMIER
LOGS4 = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs", "2026-11-10_TITANS-8DIR")
# TITANS-8DIR (10/11) : Sentinelle et Léviathan animés (8 directions) pris dans leur propre dossier
LOGS5 = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs", "2026-11-11_TITANS-16DIR")
# ART-16DIR (11/11) : Juggernaut, Sentinelle et Ravageur en 16 directions, pris en PREMIER
LOGS6 = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs", "2026-11-11_TITANS2")
# ART-TITANS2 (11/11) : Juggernaut re-modelé d'après les concepts du DC (anneaux flottants, griffes cinétiques, conduits haute densité), pris AVANT tout
SRC_DEFAUT = os.pathsep.join((os.path.join(LOGS6, "rendu"), os.path.join(LOGS5, "rendu"), os.path.join(LOGS4, "rendu"), os.path.join(LOGS3, "rendu"), os.path.join(LOGS, "rendu"), os.path.join(LOGS2, "rendu")))
DEST_DEFAUT = os.path.join(MOD, "graphics", "robots", "titans")
PREFIXE = "__factorio-overhaul__/graphics/robots/titans/"
COMMANDE = "PYTHONUTF8=1 py -3.9 tools/render/pieces/titans/feuilles_titans.py   (depuis la racine du mod ; sources : fo-logs/2026-11-11_TITANS2/rendu, fo-logs/2026-11-11_TITANS-16DIR/rendu, fo-logs/2026-11-10_TITANS-8DIR/rendu, fo-logs/2026-11-10_VISUELS-DISTINCTS/rendu, fo-logs/2026-11-10_TITANS-FINITIONS/rendu et fo-logs/2026-11-10_KAIJUS-MUTANTS/rendu, à GARDER)"
# alliés à une image (traitement des géants) : stades rendus ; le Léviathan a de plus son drone d'escorte (une image, clé « drone »)
ALLIES = (("leviathan", ("drone",)),)   # TITANS-8DIR : Sentinelle et Léviathan sont animés ; seul le drone d'escorte reste une image
# LEVIATHAN-SEG (11/11) : le Léviathan est ARTICULÉ (tête, segments, queue) : ses feuilles sont faites par feuilles_leviathan.py
# (graphics/robots/titans/leviathan/) ; il n'a plus de feuille d'un seul tenant ici, seul son drone d'escorte reste.
# alliés ANIMÉS : (nom, stades, diviseur de densité par couche, feuille la plus large) ; KAIJUS-MUTANTS : Ravageur (allié) et Écorchés
# (ennemis : le « stade » est la VARIANTE, rôdeur / porteur / hurleur)
# ART-16DIR (11/11) : Juggernaut, Ravageur et Sentinelle à 16 directions (SERIE["dirs"] du module) ; lueur à demi-densité (halo diffus),
# ombre au quart : budget de 80 Mpx HR par titan. Lueur au QUART de la densité du rendu (assemblage du 11/11 à demi-densité : Juggernaut
# 83,9, Ravageur 80,2, Sentinelle 80,6 Mpx) : la lueur est le halo additif, les conduits nets restent dans le corps (comparaison à
# l'échelle du jeu : fo-logs/2026-11-11_TITANS-16DIR/essai/lueur-div2-div4.png, sans différence visible)
ANIMES = (("juggernaut", ("1", "2", "3"), {"main": 1, "glow": 4, "shadow": 4}, 4096),
          ("ravageur", ("1", "2", "3"), {"main": 1, "glow": 4, "shadow": 4}, 4096),
          ("sentinelle", ("1", "2", "3"), {"main": 1, "glow": 4, "shadow": 4}, 4096),
          ("ecorche", ("1", "2", "3"), {"main": 1, "glow": 1, "shadow": 1}, 2048))
# ennemis à une série (un prototype par ère : l'échelle vient du jeu) : Kaiju cristallin, Écorcheur
ENNEMIS = ("kaiju", "ecorcheur")
ANIMS = (("course", 8), ("attaque", 4))
DIRS = 8
REDUC = 2
SEUIL = 2
SEUIL_OMBRE = 24
PLUS_PETIT_AMAS = 12
MAX_PX = 2048


def sans_points_isoles(a, seuil, mini=PLUS_PETIT_AMAS):
    m = a > seuil
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n == 0:
        return m
    tailles = ndimage.sum(m, lab, range(1, n + 1))
    garde = np.zeros(n + 1, bool)
    garde[1:] = tailles >= mini
    return garde[lab]


def alpha(x):
    """Canal alpha d'une image RGBA, ou l'image elle-même si elle n'a qu'un canal (ombre)."""
    return x if x.ndim == 2 else x[..., 3]


def boite(a):
    ys, xs = np.where(a > SEUIL)
    if not len(xs):
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def reduit2(img, additif=False):
    """RGBA 8 bits -> moitié (lumière linéaire prémultipliée ; additif : énergie)."""
    f = img.astype(np.float64) / 255.0
    out = P.downsample2_additive(f) if additif else P.downsample2(f)
    return np.round(np.clip(out, 0, 1) * 255).astype(np.uint8)


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def foulee_de(module):
    """FOULEE (tuiles par cycle) lue dans le texte du module (il importe bpy : pas d'import hors Blender)."""
    src = open(os.path.join(HERE, module + ".py"), encoding="utf-8").read()
    m = re.search(r"^FOULEE\s*=\s*([0-9.*+\- ()]+)", src, re.M)
    return round(float(eval(m.group(1), {"__builtins__": {}})), 4)


def directions_de(module):
    """Nombre de directions de la série du module (SERIE["dirs"], 8 par défaut), lu dans son texte (il importe bpy)."""
    src = open(os.path.join(HERE, module + ".py"), encoding="utf-8").read()
    m = re.search(r"^SERIE\s*=\s*(\{.*\})\s*$", src, re.M)
    return int(ast.literal_eval(m.group(1)).get("dirs", DIRS)) if m else DIRS


def dossier(src, sub):
    """Le sous-dossier `sub` dans le premier des dossiers de sources (séparés par os.pathsep) qui le contient."""
    for s in src.split(os.pathsep):
        d = os.path.join(s, sub)
        if os.path.isdir(d):
            return d
    raise SystemExit("MANQUE : " + sub + " dans " + src)


def anime(S, src, poids, sub, base, cle, divs, max_px, ndirs=None):
    """Feuilles d'un titan animé : npz de <src>/<sub>/<base>-<anim>-<image>-<dir>.npz -> hr-<cle>-<anim>-<couche>-<dir>.png (et sans hr-).
    divs : diviseur de densité par couche (hr = densité du rendu / div). Rend { course, attaque, icone }.
    ndirs : directions des feuilles ; à défaut, DIRS du module LU À L'APPEL (feuilles_leviathan.py fixe FT.DIRS = 16 avant d'appeler : une
    valeur par défaut liée à la définition le ramenait à 8, vu à la fusion ART-16DIR + LEVIATHAN-SEG du 11/11)."""
    ndirs = ndirs or DIRS
    d = dossier(src, sub)
    out = {}
    icone = None
    for anim, nb in ANIMS:
        images = {}
        for k in range(ndirs):
            for i in range(nb):
                p = os.path.join(d, "%s-%s-%02d-%02d.npz" % (base, anim, i, k))
                if not os.path.exists(p):
                    raise SystemExit("MANQUE : " + p)
                z = np.load(p)
                fr = P.contact_fringe(z["ao"].astype(np.float64) / 255.0, C.AO_STRENGTH, C.AO_GAMMA, C.AO_COLOR)
                fr[..., 3] *= sans_points_isoles(fr[..., 3], SEUIL / 255.0)
                mn = P.over(z["main"].astype(np.float64) / 255.0, fr)
                mn = np.round(np.clip(mn, 0, 1) * 255).astype(np.uint8)
                om = np.where(sans_points_isoles(z["ombre"], SEUIL_OMBRE), z["ombre"], 0).astype(np.uint8)
                gl = np.round(np.clip(P.additive_layer(z["glow"].astype(np.float64) / 255.0), 0, 1) * 255).astype(np.uint8)
                gl[..., 3] = np.where(sans_points_isoles(gl[..., 3], SEUIL), gl[..., 3], 0)
                images[(k, i)] = (mn, gl, om, z["origine"], float(z["densite"][0]))
        D = images[(0, 0)][4]
        ox, oy = images[(0, 0)][3]
        H0, W0 = images[(0, 0)][0].shape[:2]
        uni = {}
        for c, idx in (("main", 0), ("glow", 1), ("shadow", 2)):
            al = REDUC * divs[c]
            l = [boite(alpha(v[idx])) for v in images.values()]
            l = [x for x in l if x is not None]
            x0, y0 = min(x[0] for x in l), min(x[1] for x in l)
            x1, y1 = max(x[2] for x in l), max(x[3] for x in l)
            x0, y0 = x0 - x0 % al, y0 - y0 % al
            x1, y1 = min(W0, x1 + (-x1) % al), min(H0, y1 + (-y1) % al)
            uni[c] = (x0, y0, x1 - (x1 - x0) % al, y1 - (y1 - y0) % al)
        couches = {}
        for c, idx in (("main", 0), ("glow", 1), ("shadow", 2)):
            x0, y0, x1, y1 = uni[c]
            div = divs[c]
            cw, ch = (x1 - x0) // div, (y1 - y0) // div
            # grille EXACTE (ll × lpf = nb images) : le moteur lit la feuille en continu, ll × lpf images par fichier (F-TITANS : une
            # grille 3 × 3 pour 8 images décalait la direction suivante d'une cellule) ; la plus large qui tient dans max_px
            ll = None
            for cand in range(nb, 0, -1):
                if nb % cand == 0 and cand * cw <= max_px and (nb // cand) * ch <= max_px:
                    ll = cand
                    break
            assert ll is not None, (sub, anim, c, cw, ch, nb)
            lpf = nb // ll
            fichiers_hr, fichiers_lr = [], []
            for k in range(ndirs):
                feuille = np.zeros((ch * div * lpf, cw * div * ll, 4), np.uint8)
                for i in range(nb):
                    t = images[(k, i)][idx][y0:y1, x0:x1]
                    if t.ndim == 2:  # ombre : alpha seul -> RGBA noir
                        tt = np.zeros((ch * div, cw * div, 4), np.uint8)
                        tt[..., 3] = t
                        t = tt
                    lig, col = divmod(i, ll)
                    feuille[lig * ch * div:(lig + 1) * ch * div, col * cw * div:(col + 1) * cw * div] = t
                    bx = boite(t[..., 3])
                    if bx:
                        aire = (bx[2] - bx[0]) * (bx[3] - bx[1]) / 1e6 / (div * div)
                        poids["haute"] += aire
                        poids["normale"] += aire / (REDUC * REDUC)
                hr = feuille
                for _ in range(div.bit_length() - 1):
                    hr = reduit2(hr, additif=(c == "glow"))
                nom_hr = "hr-%s-%s-%s-%d.png" % (cle, anim, c, k)
                nom_lr = "%s-%s-%s-%d.png" % (cle, anim, c, k)
                fichiers_hr.append(S.ecrit(hr, nom_hr))
                fichiers_lr.append(S.ecrit(reduit2(hr, additif=(c == "glow")), nom_lr))
                if c == "main" and k == (3 * ndirs) // 8 and icone is None:   # sud-est
                    icone = images[(k, 0)][0][y0:y1, x0:x1]
            sft = ((x0 + x1) / 2.0 - ox, (y0 + y1) / 2.0 - oy)
            couches[c] = {"hr": fichiers_hr, "lr": fichiers_lr, "w": int(cw), "h": int(ch), "lw": int(cw // REDUC), "lh": int(ch // REDUC),
                          "ll": int(ll), "lpf": int(lpf), "dens": D / div, "sx": round(sft[0] / D, 5), "sy": round(sft[1] / D, 5)}
            poids["images"] += nb * ndirs if c == "main" else 0
        out[anim] = {"images": nb, "densite": D, "couches": couches}
    # icône : direction sud-est, image 0 de la course, tenue dans 60 px
    k = 60.0 / max(icone.shape[0], icone.shape[1])
    ic = FX.lanczos(icone, max(1, int(round(icone.shape[1] * k))), max(1, int(round(icone.shape[0] * k))))
    cadre = np.zeros((64, 64, 4), np.uint8)
    oy_, ox_ = (64 - ic.shape[0]) // 2, (64 - ic.shape[1]) // 2
    cadre[oy_:oy_ + ic.shape[0], ox_:ox_ + ic.shape[1]] = ic
    out["icone"] = {"filename": S.ecrit(cadre, "icone-%s.png" % cle), "size": 64}
    return out


def mesure_variantes(dest, entree, stades):
    """VISUELS-DISTINCTS : couleur moyenne (pondérée par l'alpha) et LUMINANCE (Rec. 709) de la couche principale de la course de chaque
    variante, toutes directions : lue par tests/titans_test.lua §8 (rôdeur clair, hurleur médian, porteur sombre, écarts mesurés)."""
    out = {}
    for st in stades:
        acc, wsum = np.zeros(3), 0.0
        for f in entree[st]["course"]["couches"]["main"]["hr"]:
            a = np.asarray(Image.open(os.path.join(dest, os.path.basename(f))).convert("RGBA")).astype(np.float64) / 255.0
            w = a[..., 3]
            acc += (a[..., :3] * w[..., None]).sum((0, 1))
            wsum += float(w.sum())
        rgb = acc / max(1e-6, wsum)
        out[st] = {"luminance": round(float(0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]), 4), "rgb": [round(float(x), 4) for x in rgb]}
    return out


def _stade(job):
    """Feuilles d'UN stade d'un titan animé (processus fils de seul()) : rend (entrée, poids)."""
    src, dest, nom, st, divs, max_px, nd = job
    FX.PREFIXE = PREFIXE
    p = {"haute": 0.0, "normale": 0.0, "images": 0}
    return anime(FX.Sortie(dest), src, p, "%s-anime-%s" % (nom, st), "%s-%s" % (nom, st), "%s-%s" % (nom, st), divs, max_px, nd), p


def seul(a):
    """ART-TITANS2 (11/11) : ne refait QUE le titan animé `a.seul` : ses PNG (hr-, sans préfixe, icône), son entrée de premier niveau de
    sprites.lua et ses fichiers et son poids dans MANIFEST.json ; les autres entrées (Kaiju, Écorchés, drone du Léviathan...) restent
    octet pour octet (un autre lot peut les refaire en même temps)."""
    nom = a.seul
    ent = [x for x in ANIMES if x[0] == nom]
    if not ent:
        raise SystemExit("--seul : %s n'est pas un titan animé (ANIMES)" % nom)
    _, stades, divs, max_px = ent[0]
    pre = re.compile(r"^(hr-|icone-)?%s-" % re.escape(nom))
    for f in os.listdir(a.dest):
        if f.endswith(".png") and pre.match(f):
            os.remove(os.path.join(a.dest, f))
    FX.PREFIXE = PREFIXE
    S = FX.Sortie(a.dest)
    nd = directions_de(nom)
    e = {"anime": True, "foulee": foulee_de(nom), "reduc": REDUC, "directions": nd}
    pd = {"haute": 0.0, "normale": 0.0, "images": 0}
    # un processus par stade (les stades sont indépendants : fichiers distincts) ; poids sommés après
    import multiprocessing as mp
    with mp.Pool(len(stades)) as pool:
        res = pool.map(_stade, [(a.src, a.dest, nom, st, divs, max_px, nd) for st in stades])
    for st, (ent, p_) in zip(stades, res):
        e[st] = ent
        for k in pd:
            pd[k] += p_[k]
    if nom == "ecorche":
        # s43 3d-ecorches : la mesure de luminance des variantes (tests/titans_test.lua §8) suit les feuilles refaites seules
        e["mesure"] = mesure_variantes(a.dest, e, stades)
    p = os.path.join(a.dest, "sprites.lua")
    with open(p, encoding="utf-8") as f:
        lignes = f.read().split("\n")
    i = lignes.index("  %s = {" % nom)
    j = lignes.index("  },", i)
    lignes[i:j + 1] = ("  %s = %s," % (nom, FX.lua(e, "  "))).split("\n")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lignes))
    pm = os.path.join(a.dest, "MANIFEST.json")
    with open(pm, encoding="utf-8") as f:
        man = json.load(f)
    fichiers = {k: v for k, v in man["fichiers"].items() if not pre.match(k)}
    for f in sorted(os.listdir(a.dest)):
        if f.endswith(".png") and pre.match(f):
            pp = os.path.join(a.dest, f)
            im = Image.open(pp)
            fichiers[f] = {"largeur": im.size[0], "hauteur": im.size[1], "taille": os.path.getsize(pp), "sha256": sha(pp)}
    man["fichiers"] = fichiers
    man["commande"] = COMMANDE
    man["poids_mpx"][nom] = {kk: round(vv, 2) for kk, vv in pd.items()}
    with open(pm, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-TITANS] --seul %s : %d PNG ; haute %.1f Mpx ; normale %.2f Mpx" % (
        nom, sum(1 for f in fichiers if pre.match(f)), pd["haute"], pd["normale"]), flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--sans-kaiju", action="store_true")
    ap.add_argument("--sans-allies", action="store_true")
    ap.add_argument("--sans-animes", action="store_true")
    ap.add_argument("--seul", default="", help="ART-TITANS2 : ne refait que ce titan animé (ses PNG, son entrée de sprites.lua et de MANIFEST.json)")
    a = ap.parse_args()
    if a.seul:
        return seul(a)
    os.makedirs(a.dest, exist_ok=True)
    for f in glob.glob(os.path.join(a.dest, "*.png")):
        os.remove(f)
    FX.PREFIXE = PREFIXE
    S = FX.Sortie(a.dest)
    spr = {}
    poids = {}
    for nom in ENNEMIS:
        spr[nom] = {}
        poids[nom] = {"haute": 0.0, "normale": 0.0, "images": 0}
    for nom, stades in ALLIES:
        spr[nom] = {}
        poids[nom] = {"haute": 0.0, "normale": 0.0, "images": 0}
        if a.sans_allies:
            continue
        for st in stades:
            e = FX.geant(S, dossier(a.src, "%s-%s" % (nom, st)).rsplit(os.sep, 1)[0], "%s-%s" % (nom, st), "%s-%s" % (nom, st))
            spr[nom][st] = e
            for c in [e["main"], e["ombre"]] + e["lueurs"]:
                poids[nom]["haute"] += c["hr"]["width"] * c["hr"]["height"] / 1e6
                poids[nom]["normale"] += c["lr"]["width"] * c["lr"]["height"] / 1e6
            poids[nom]["images"] += 1
    for nom, stades, divs, max_px in ANIMES:
        # le Léviathan garde son drone (ALLIES) : on complète l'entrée au lieu de la remplacer
        nd = directions_de(nom)
        spr.setdefault(nom, {}).update({"anime": True, "foulee": foulee_de(nom), "reduc": REDUC, "directions": nd})
        poids.setdefault(nom, {"haute": 0.0, "normale": 0.0, "images": 0})
        if a.sans_animes:
            continue
        for st in stades:
            spr[nom][st] = anime(S, a.src, poids[nom], "%s-anime-%s" % (nom, st), "%s-%s" % (nom, st), "%s-%s" % (nom, st), divs, max_px, nd)
        if nom == "ecorche":
            spr[nom]["mesure"] = mesure_variantes(a.dest, spr[nom], stades)
    if not a.sans_kaiju:
        for nom in ENNEMIS:
            spr[nom] = {"K": 1.0, "foulee": foulee_de(nom), "reduc": REDUC, "directions": DIRS}
            spr[nom].update(anime(S, a.src, poids[nom], nom, nom, nom, {"main": 1, "glow": 1, "shadow": 1}, MAX_PX))
    p = os.path.join(a.dest, "sprites.lua")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/render/pieces/titans/feuilles_titans.py (lot TITANS) : ne pas modifier à la main.\n")
        f.write("-- Images hors de git (D-6) : MANIFEST.json, « commande ». shift : centre de l'image depuis la position au sol, en tuiles.\n")
        f.write("return " + FX.lua(spr) + "\n")
    fichiers = {}
    total = 0
    for f in sorted(os.listdir(a.dest)):
        if f.endswith(".png"):
            pp = os.path.join(a.dest, f)
            im = Image.open(pp)
            fichiers[f] = {"largeur": im.size[0], "hauteur": im.size[1], "taille": os.path.getsize(pp), "sha256": sha(pp)}
            total += os.path.getsize(pp)
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"commande": COMMANDE, "arguments": [], "poids_mpx": {k: {kk: round(vv, 2) for kk, vv in v.items()} for k, v in poids.items()},
                   "fichiers": fichiers}, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-TITANS] %d fichiers PNG, %.2f Mo" % (len(fichiers), total / 1e6), flush=True)
    for k, v in poids.items():
        print("  %s : %d images ; haute %.1f Mpx ; normale %.2f Mpx" % (k, v["images"], v["haute"], v["normale"]))


if __name__ == "__main__":
    main()
