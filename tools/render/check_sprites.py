"""Contrôle hors moteur des sprites livrés (ce que le chargeur de Factorio refuserait ou afficherait mal).

    python tools/render/check_sprites.py [pièce ...]        (défaut : toutes celles de manifests/)

Pour chaque couche de chaque variante du manifeste :
- le PNG existe, est en RGBA 8 bits, et ses dimensions valent EXACTEMENT width × height déclarés
  (un rectangle plus grand que l'image fait refuser le prototype au chargement) ;
- hr = 2 × lr en largeur et en hauteur, même shift ;
- shift multiple exact de 1/64 de tuile (alignement au pixel HR) et bord gauche/haut sur la grille
  paire (alignement au pixel de la version normale) ;
- la somme SHA-256 du fichier est celle du manifeste (fichier non retouché à la main) ;
- couche non vide ; ombre noire ; icône 120 × 64 (64 + 32 + 16 + 8).
Contrôles V0b (fo_checks.py, refaits sur les PNG HR livrés, couches posées à leur shift) :
- aucun pixel transparent (alpha < 0,5) ENFERMÉ dans la silhouette de la couche principale (le sol se verrait
  au travers : collerette V0), sauf tolérance déclarée par la pièce (PIECE["enclosed_tolerance_px"]) ;
- halo : au plus 3 % de son énergie sur la couche principale (draw_as_light révèle la couleur de jour de ce
  qu'il recouvre, F64) et, pour une variante posée sur un sprite vanilla (masque), au plus 3 % sur ce sprite ;
  aucune poche sombre enfermée dans le halo (« ombre fantôme » d'une partie cachée).
Contrôles du correcteur V0b (couche principale et lueur posées à leur shift, partie visible seulement pour une
variante posée sur un sprite vanilla) :
- règles de palette de la bible (DESIGN_EPOQUES §1.5) quand la pièce déclare PIECE["epoque"] ;
- rapport de luminance médiane pièce / bâtiment vanilla porteur ≤ fo_calib.CARRIER_RATIO_MAX.
Code de sortie 1 au premier écart.
"""
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_ROOT = os.path.dirname(os.path.dirname(HERE))
DEFAULT_DATA = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data"
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_checks  # noqa: E402


def _place(canvas, img, shift, origin):
    """Pose un sprite HR (h, w, 4 ; 0..1) à son shift (tuiles) sur une toile dont l'entité est en origin (px)."""
    h, w = img.shape[:2]
    x0 = int(round(origin[0] + shift[0] * 64 - w / 2.0))
    y0 = int(round(origin[1] + shift[1] * 64 - h / 2.0))
    canvas[y0:y0 + h, x0:x0 + w] = img
    return canvas


def v0b_checks(man, v, d, piece_meta, data_dir):
    """Contrôles V0b d'une variante sur les PNG HR livrés. Renvoie la liste des écarts."""
    errs = []
    spec = v["spec"]
    if "main" not in spec:
        return errs
    load = lambda fn: np.asarray(Image.open(os.path.join(d, fn)).convert("RGBA")).astype(np.float64) / 255.0  # noqa: E731
    main = load(spec["main"]["hr"]["filename"])
    tol = int((piece_meta or {}).get("enclosed_tolerance_px", 0))
    n, am, _ = fo_checks.enclosed_transparent(main[..., 3])
    if n > tol:
        errs.append("%s : %d px transparents enfermés dans la couche principale (tolérance %d)" % (v["name"], n, tol))
    S = 1024
    origin = (S / 2.0, S / 2.0 + 128)
    cm = _place(np.zeros((S, S, 4)), main, spec["main"]["hr"]["shift"], origin)
    vname = v["name"].split("-", 1)[1] if "-" in v["name"] else v["name"]
    mask = ((piece_meta or {}).get("variants", {}).get(vname) or {}).get("mask")
    carrier = None
    if mask:
        carrier = np.asarray(Image.open(os.path.join(data_dir, "base", "graphics", "entity", mask["hr"]["file"]))
                             .convert("RGBA")).astype(np.float64) / 255.0
    # photométrie de la partie visible (correcteur V0b) : règles de la bible, rapport au bâtiment porteur
    vis = cm.copy()
    if carrier is not None:
        vis[..., 3] *= 1 - _place(np.zeros((S, S, 4)), carrier, mask["hr"]["shift"], origin)[..., 3]
    glow = _place(np.zeros((S, S, 4)), load(spec["glow"]["hr"]["filename"]), spec["glow"]["hr"]["shift"], origin)         if "glow" in spec else None
    ph = fo_checks.photometry(vis, glow)
    e = (piece_meta or {}).get("epoque")
    if ph.get("n") and e is not None:
        for f in fo_checks.bible_rules(ph, [int(x) for x in (e if isinstance(e, (list, tuple)) else [e])],
                                       C.BIBLE_MEDIAN, C.BIBLE_TOL):
            errs.append("%s : %s" % (v["name"], f))
    if ph.get("n") and carrier is not None:
        cmed = fo_checks.bible_median(carrier)
        ratio = ph["bible_p05_p50_p95"][1] / cmed
        if ratio > C.CARRIER_RATIO_MAX:
            errs.append("%s : luminance médiane pièce / bâtiment porteur %.2f > %.2f" % (v["name"], ratio,
                                                                                        C.CARRIER_RATIO_MAX))
    if "light" not in spec:
        return errs
    light = load(spec["light"]["hr"]["filename"])
    cl = _place(np.zeros((S, S, 4)), light, spec["light"]["hr"]["shift"], origin)
    fr, _ = fo_checks.light_on(cl, cm[..., 3])
    if fr > 0.03:
        errs.append("%s : %.1f %% de l'énergie du halo sur la couche principale (≤ 3 %%)" % (v["name"], 100 * fr))
    blocked = cm[..., 3] >= 0.5
    if mask:
        cv = _place(np.zeros((S, S, 4)), carrier, mask["hr"]["shift"], origin)
        fb, _ = fo_checks.light_on(cl, cv[..., 3])
        if fb > 0.03:
            errs.append("%s : %.1f %% de l'énergie du halo sur le bâtiment porteur (≤ 3 %%)" % (v["name"], 100 * fb))
        blocked |= cv[..., 3] >= 0.5
    pk = fo_checks.light_pockets(cl, blocked)
    if pk:
        errs.append("%s : poche sombre enfermée de %d px dans le halo" % (v["name"], pk))
    return errs


def piece_meta(man):
    """PIECE du fichier source de la pièce (sans Blender), ou None."""
    src = man.get("piece_source")
    if not src:
        return None
    path = os.path.join(MOD_ROOT, *src.split("/"))
    if not os.path.exists(path):
        return None
    import importlib.util
    spec = importlib.util.spec_from_file_location("fo_piece_meta_chk", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return getattr(mod, "PIECE", None)


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def check(name):
    with open(os.path.join(HERE, "manifests", name + ".json"), encoding="utf-8") as f:
        man = json.load(f)
    errs, n = [], 0
    for v in man["variants"]:
        d = os.path.join(MOD_ROOT, "graphics", *v["dest"].split("/"))
        for layer, sd in sorted(v["spec"].items()):
            for res in ("lr", "hr"):
                s = sd[res]
                p = os.path.join(d, s["filename"])
                n += 1
                if not os.path.exists(p):
                    errs.append("absent : " + p)
                    continue
                im = Image.open(p)
                if im.mode != "RGBA":
                    errs.append("%s : mode %s (RGBA attendu)" % (s["filename"], im.mode))
                if im.size != (s["width"], s["height"]):
                    errs.append("%s : %s déclaré %dx%d" % (s["filename"], im.size, s["width"], s["height"]))
                if sha(p) != v["files"][s["filename"]]:
                    errs.append("%s : somme SHA-256 différente du manifeste" % s["filename"])
                for k in (0, 1):
                    q = s["shift"][k] * 64
                    if abs(q - round(q)) > 1e-9:
                        errs.append("%s : shift %r non multiple de 1/64" % (s["filename"], s["shift"]))
                # bord gauche/haut relatif à la position de l'entité, en px HR : pair
                w_hr, h_hr = sd["hr"]["width"], sd["hr"]["height"]
                left = s["shift"][0] * 64 - w_hr / 2.0
                top = s["shift"][1] * 64 - h_hr / 2.0
                if abs(left - round(left)) > 1e-9 or abs(top - round(top)) > 1e-9 or round(left) % 2 or round(top) % 2:
                    errs.append("%s : bord (%.2f, %.2f) px hors de la grille paire" % (s["filename"], left, top))
                ext = im.getextrema()
                if ext[3][1] == 0:
                    errs.append("%s : couche vide" % s["filename"])
                if layer == "shadow" and max(ext[0][1], ext[1][1], ext[2][1]) > 0:
                    errs.append("%s : ombre non noire" % s["filename"])
            if (sd["hr"]["width"], sd["hr"]["height"]) != (2 * sd["lr"]["width"], 2 * sd["lr"]["height"]):
                errs.append("%s/%s : hr ≠ 2 × lr" % (v["name"], layer))
            if sd["hr"]["shift"] != sd["lr"]["shift"]:
                errs.append("%s/%s : shift hr ≠ lr" % (v["name"], layer))
        if "checks" in v:  # manifeste V0b : contrôles refaits sur les fichiers livrés
            errs.extend(v0b_checks(man, v, d, piece_meta(man), os.environ.get("FO_DATA", DEFAULT_DATA)))
    for icon, h in man["icon"].items():
        p = os.path.join(MOD_ROOT, "graphics", *man["variants"][0]["dest"].split("/"), icon)
        n += 1
        im = Image.open(p)
        if im.size != (120, 64):
            errs.append("%s : %s au lieu de 120x64 (64 px + 3 mipmaps)" % (icon, im.size))
        if sha(p) != h:
            errs.append("%s : somme SHA-256 différente du manifeste" % icon)
    p = os.path.join(MOD_ROOT, "graphics", *man["variants"][0]["dest"].split("/"), "sprites.lua")
    if sha(p) != man["sprites_lua"]:
        errs.append("sprites.lua : somme différente du manifeste")
    return n, errs


def main():
    names = sys.argv[1:] or sorted(f[:-5] for f in os.listdir(os.path.join(HERE, "manifests")) if f.endswith(".json"))
    bad = 0
    for name in names:
        n, errs = check(name)
        for e in errs:
            print("[FO-SPRITES] ECHEC %s : %s" % (name, e))
        print("[FO-SPRITES] %s : %d fichiers contrôlés, %d écart(s)" % (name, n, len(errs)))
        bad += len(errs)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
