"""FEUILLES DE JEU DES 20 MACHINES DU CALCUL (lot MACHINES-CALCUL, 3/11) -> graphics/machines/calcul/ (PNG HORS de git, D-6),
sprites.lua (GÉNÉRÉ, lu par prototypes/calcul_machines.lua), sprites.json et MANIFEST.json (commités).

    py -3.9 tools/render/pieces/calcul/feuilles.py            (depuis la racine du mod, sans argument)
    py -3.9 tools/render/pieces/calcul/feuilles.py --src DIR --dest DIR

Sources à GARDER : fo-logs/2026-11-01_CALCUL-DESIGN/final/<machine>/ (rendus à 64 échantillons du kit calcul_o, lot CALCUL-DESIGN :
couches main, shadow, glow et, pour 12 machines, une bande de 8 images de la pièce mobile ; spec.json : tailles, shift en tuiles,
64 px par tuile). Le kit de rendu lui-même vit dans le worktree calcul-design (tools/render/pieces/machines/calcul_o, non commité ;
copie dans fo-logs/2026-11-03_SAUVEGARDE-DA) : ce script n'en dépend pas et ne lance jamais Blender.

Règles (toutes contrôlées par tools/render/pieces/calcul/tests/test_calcul_feuilles.py) :
- NETTOYAGE : les rendus portent des pixels isolés (1 ou 2 px, alpha jusqu'à 129 aux coins de la tireuse et de l'intégrateur) ;
  dans le corps et l'ombre, toute composante connexe (8 voisins, alpha > 0) de 4 px au plus est effacée ; dans la lueur, seulement si
  son alpha ne dépasse pas 32 (une diode de 1 px reste).
- RECADRAGE au contenu, sur une grille PAIRE alignée sur l'origine de l'entité (coin et taille pairs en pixels hr) : la normale
  (32 px par tuile) est la moyenne exacte 2 × 2 de la hr, en alpha prémultiplié, et tombe au pixel sur la hr et sur les tuiles. Le
  shift est recalculé : aucun décalage (la hr replacée par son shift redonne la source nettoyée au pixel près).
- PIÈCE MOBILE : la bande de la source garde un fond opaque (le corps est rendu à la phase 0) ; chaque image est rognée d'au plus
  1 px par bord pour tomber sur la même grille paire ; la feuille de jeu a une image par colonne (line_length = images).
- 8 192 px au plus par fichier (F144).
"""
import argparse
import hashlib
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
SRC_DEFAUT = os.path.join(LOGS, "2026-11-01_CALCUL-DESIGN", "final")
DEST_DEFAUT = os.path.join(MOD, "graphics", "machines", "calcul")
PREFIXE = "__factorio-overhaul__/graphics/machines/calcul/"
PX = 64  # pixels hr par tuile
COMMANDE = "py -3.9 tools/render/pieces/calcul/feuilles.py   (depuis la racine du mod, sans argument ; sources : " \
           "fo-logs/2026-11-01_CALCUL-DESIGN/final, à GARDER)"
ETIQUETTE = "[FO-FEUILLES-CALCUL]"

# nom de la variante rendue : (prototype, âge, côté de l'emprise en tuiles) ; même table que calcul_o/piece.py
MACHINES = {
    "centre": ("fo-data-center", 10, 4), "grand_centre": ("fo-data-center-2", 12, 6),
    "litho": ("fo-crystal-lithograph", 10, 4), "salle": ("fo-cleanroom", 10, 5),
    "tireuse": ("fo-crystal-puller", 10, 3), "scie": ("fo-wire-saw", 10, 3),
    "graveur": ("fo-plasma-etcher", 10, 3), "testeur": ("fo-die-prober", 10, 3),
    "boitier": ("fo-packaging-line", 10, 3), "cms": ("fo-smt-line", 10, 4),
    "fibre": ("fo-fiber-tower", 10, 3), "integ": ("fo-rack-integrator", 10, 4),
    "froid": ("fo-chiller", 10, 4), "tour": ("fo-cooling-tower", 10, 5),
    "cryo": ("fo-cryogenic-unit", 12, 5), "dilution": ("fo-dilution-fridge", 13, 3),
    "qlab": ("fo-quantum-lab", 13, 5), "impr": ("fo-circuit-printer", 4, 3),
    "fritt": ("fo-sintering-furnace", 5, 3), "arc": ("fo-arc-furnace", 6, 4),
}
COUCHES = ("main", "shadow", "glow")
STRAY_MAX_PX = 4
STRAY_GLOW_ALPHA = 32 / 255.0
MAX_PX_FICHIER = 8192


def charge(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float64) / 255.0


def u8(a):
    u = np.clip(np.floor(a * 255.0 + 0.5), 0, 255).astype(np.uint8)
    u[u[..., 3] == 0, :3] = 0
    return u


def ecrit(a, p):
    Image.fromarray(u8(a), "RGBA").save(p, optimize=True)


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def nettoie(a, couche):
    """Efface les composantes isolées (pixels parasites du rendu) ; rend (image, nombre de pixels effacés)."""
    m = a[..., 3] > 0
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n <= 1:
        return a, 0
    taille = np.bincount(lab.ravel())
    amax = ndimage.maximum(a[..., 3], lab, index=np.arange(1, n + 1))
    efface = np.zeros(n + 1, bool)
    for i in range(1, n + 1):
        if taille[i] <= STRAY_MAX_PX and (couche != "glow" or amax[i - 1] <= STRAY_GLOW_ALPHA):
            efface[i] = True
    masque = efface[lab]
    out = a.copy()
    out[masque] = 0.0
    return out, int(masque.sum())


def moitie(a):
    """Moyenne exacte 2 × 2 en alpha prémultiplié (dimensions paires exigées)."""
    h, w = a.shape[:2]
    assert h % 2 == 0 and w % 2 == 0, "moitie : dimensions impaires %dx%d" % (w, h)
    p = a.copy()
    p[..., :3] *= p[..., 3:4]
    q = p.reshape(h // 2, 2, w // 2, 2, 4).mean((1, 3))
    al = q[..., 3:4]
    q[..., :3] = np.where(al > 1e-9, np.clip(q[..., :3] / np.maximum(al, 1e-9), 0, 1), 0)
    return q


def place(spec_c, c0, nom, couche):
    """Coin haut-gauche (x, y) d'une couche dans le repère du canevas, entier exigé."""
    x = c0[0] + spec_c["shift"][0] * PX - spec_c["width"] / 2.0
    y = c0[1] + spec_c["shift"][1] * PX - spec_c["height"] / 2.0
    if abs(x - round(x)) > 1e-6 or abs(y - round(y)) > 1e-6:
        raise SystemExit("%s %s %s : coin hors de la grille des pixels (%.3f, %.3f)" % (ETIQUETTE, nom, couche, x, y))
    return int(round(x)), int(round(y))


def boite_paire(x0, y0, x1, y1, par):
    """Agrandit [x0, x1) × [y0, y1) pour que coin et bord soient de la parité de l'origine (par)."""
    if (x0 - par[0]) % 2:
        x0 -= 1
    if (y0 - par[1]) % 2:
        y0 -= 1
    if (x1 - par[0]) % 2:
        x1 += 1
    if (y1 - par[1]) % 2:
        y1 += 1
    return x0, y0, x1, y1


def recadre(a, pos, par):
    """Rogne une couche fixe à son contenu sur la grille paire ; rend (image, coin dans le canevas)."""
    ys, xs = np.nonzero(a[..., 3] > 0)
    if len(xs) == 0:
        return None, None
    x0, y0, x1, y1 = boite_paire(pos[0] + xs.min(), pos[1] + ys.min(), pos[0] + xs.max() + 1, pos[1] + ys.max() + 1, par)
    out = np.zeros((y1 - y0, x1 - x0, 4))
    sx0, sy0 = x0 - pos[0], y0 - pos[1]
    # la boîte agrandie peut déborder de 1 px de l'image source : copie de l'intersection
    ix0, iy0 = max(0, sx0), max(0, sy0)
    ix1, iy1 = min(a.shape[1], sx0 + out.shape[1]), min(a.shape[0], sy0 + out.shape[0])
    out[iy0 - sy0:iy1 - sy0, ix0 - sx0:ix1 - sx0] = a[iy0:iy1, ix0:ix1]
    return out, (x0, y0)


def shift_de(coin, w, h, c0):
    return [round((coin[0] + w / 2.0 - c0[0]) / PX, 6), round((coin[1] + h / 2.0 - c0[1]) / PX, 6)]


def icone(main, glow_canevas, dest):
    """Icône 64 px et ses mipmaps 32, 16, 8 à la suite (120 × 64), depuis le corps (lueur ajoutée à 60 %)."""
    im = main.copy()
    if glow_canevas is not None:
        im[..., :3] = np.clip(im[..., :3] + glow_canevas[..., :3] * glow_canevas[..., 3:4] * 0.6, 0, 1)
    ys, xs = np.nonzero(im[..., 3] > 8 / 255.0)
    im = im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    cote = max(im.shape[:2])
    sq = np.zeros((cote, cote, 4))
    oy, ox = (cote - im.shape[0]) // 2, (cote - im.shape[1]) // 2
    sq[oy:oy + im.shape[0], ox:ox + im.shape[1]] = im
    sq[..., :3] *= sq[..., 3:4]
    base = Image.fromarray(np.clip(np.floor(sq * 255 + 0.5), 0, 255).astype(np.uint8), "RGBA")
    feuille = np.zeros((64, 120, 4))
    x = 0
    for t in (64, 32, 16, 8):
        r = np.asarray(base.resize((t, t), Image.LANCZOS)).astype(np.float64) / 255.0
        al = r[..., 3:4]
        r[..., :3] = np.where(al > 1e-4, np.clip(r[..., :3] / np.maximum(al, 1e-4), 0, 1), 0)
        feuille[0:t, x:x + t] = r
        x += t
    ecrit(feuille, dest)


def lua(v, ind=0):
    p = "  " * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        out = []
        for k in sorted(v, key=lambda k: (isinstance(k, str), k)):
            kk = ("[%d]" % k) if isinstance(k, int) else ('["%s"]' % k if "-" in k else k)
            out.append("%s  %s = %s" % (p, kk, lua(v[k], ind + 1)))
        return "{\n" + ",\n".join(out) + "\n" + p + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x, ind) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(round(float(v), 6))
    if isinstance(v, int):
        return str(v)
    return json.dumps(v, ensure_ascii=False)


def une_machine(src, dest, nom, fichiers, journal):
    proto, age, cote = MACHINES[nom]
    d = os.path.join(src, nom)
    p = os.path.join(d, "spec.json")
    if not os.path.isfile(p):
        raise SystemExit("%s %s : source absente %s" % (ETIQUETTE, nom, p))
    spec = json.load(open(p, encoding="utf-8"))
    L = spec["layers"]
    m = L["main"]
    # origine de l'entité dans le repère du canevas (coin haut-gauche de la couche principale = (0, 0))
    c0 = (m["width"] / 2.0 - m["shift"][0] * PX, m["height"] / 2.0 - m["shift"][1] * PX)
    if abs(c0[0] - round(c0[0])) > 1e-6 or abs(c0[1] - round(c0[1])) > 1e-6:
        raise SystemExit("%s %s : origine de l'entité hors de la grille des pixels %s" % (ETIQUETTE, nom, c0))
    c0 = (int(round(c0[0])), int(round(c0[1])))
    par = (c0[0] % 2, c0[1] % 2)
    ent = {"variante": nom, "age": age, "cote": cote, "couches": {}}
    corps_canevas, glow_canevas = None, None
    rects = []
    for couche in COUCHES:
        s = L.get(couche)
        if not s:
            continue
        a = charge(os.path.join(d, s["file"]))
        if a.shape[1] != s["width"] or a.shape[0] != s["height"]:
            raise SystemExit("%s %s %s : %dx%d, spec.json %dx%d" % (ETIQUETTE, nom, couche, a.shape[1], a.shape[0], s["width"], s["height"]))
        if hashlib.sha256(open(os.path.join(d, s["file"]), "rb").read()).hexdigest() != s.get("sha256", ""):
            raise SystemExit("%s %s %s : sha256 différent de spec.json (source changée ?)" % (ETIQUETTE, nom, couche))
        pos = place(s, c0, nom, couche)
        a, n_eff = nettoie(a, couche)
        journal.append("%s %s : %d pixel(s) isolé(s) effacé(s)" % (nom, couche, n_eff))
        out, coin = recadre(a, pos, par)
        if out is None:
            raise SystemExit("%s %s %s : couche vide" % (ETIQUETTE, nom, couche))
        if couche == "main":
            corps_canevas = (a, pos)
        elif couche == "glow":
            glow_canevas = (a, pos)
        h, w = out.shape[:2]
        if max(w, h) > MAX_PX_FICHIER:
            raise SystemExit("%s %s %s : %d px > 8 192 (F144)" % (ETIQUETTE, nom, couche, max(w, h)))
        hr_f, lr_f = "hr-%s-%s.png" % (nom, couche), "%s-%s.png" % (nom, couche)
        ecrit(out, os.path.join(dest, hr_f))
        ecrit(moitie(out), os.path.join(dest, lr_f))
        fichiers.extend([hr_f, lr_f])
        sh = shift_de(coin, w, h, c0)
        ent["couches"][couche] = {"hr": {"filename": PREFIXE + hr_f, "width": w, "height": h, "shift": sh},
                                  "lr": {"filename": PREFIXE + lr_f, "width": w // 2, "height": h // 2, "shift": sh}}
        if couche != "shadow":
            rects.append((coin[0], coin[1], coin[0] + w, coin[1] + h))
    s = L.get("mobile")
    if s:
        n, w, h = s["images"], s["width"], s["height"]
        bande = charge(os.path.join(d, s["file"]))
        if bande.shape[1] != n * w or bande.shape[0] != h:
            raise SystemExit("%s %s mobile : bande %dx%d, attendu %dx%d" % (ETIQUETTE, nom, bande.shape[1], bande.shape[0], n * w, h))
        if hashlib.sha256(open(os.path.join(d, s["file"]), "rb").read()).hexdigest() != s.get("sha256", ""):
            raise SystemExit("%s %s mobile : sha256 différent de spec.json" % (ETIQUETTE, nom))
        pos = place(s, c0, nom, "mobile")
        # rognage vers l'intérieur jusqu'à la grille paire (au plus 1 px par bord)
        gx0 = pos[0] + ((pos[0] - par[0]) % 2)
        gy0 = pos[1] + ((pos[1] - par[1]) % 2)
        gx1 = pos[0] + w - ((pos[0] + w - par[0]) % 2)
        gy1 = pos[1] + h - ((pos[1] + h - par[1]) % 2)
        W2, H2 = gx1 - gx0, gy1 - gy0
        cases = [bande[gy0 - pos[1]:gy1 - pos[1], k * w + gx0 - pos[0]:k * w + gx1 - pos[0]] for k in range(n)]
        f = np.concatenate(cases, 1)
        if f.shape[1] > MAX_PX_FICHIER:
            raise SystemExit("%s %s mobile : %d px > 8 192 (F144)" % (ETIQUETTE, nom, f.shape[1]))
        hr_f, lr_f = "hr-%s-mobile.png" % nom, "%s-mobile.png" % nom
        ecrit(f, os.path.join(dest, hr_f))
        ecrit(moitie(f), os.path.join(dest, lr_f))
        fichiers.extend([hr_f, lr_f])
        sh = shift_de((gx0, gy0), W2, H2, c0)
        ent["couches"]["mobile"] = {"images": n,
                                    "hr": {"filename": PREFIXE + hr_f, "width": W2, "height": H2, "shift": sh},
                                    "lr": {"filename": PREFIXE + lr_f, "width": W2 // 2, "height": H2 // 2, "shift": sh}}
        rects.append((gx0, gy0, gx1, gy1))
    # icône (corps + lueur replacée dans le repère du corps)
    a, pos = corps_canevas
    gl = None
    if glow_canevas is not None:
        g, gpos = glow_canevas
        gl = np.zeros_like(a)
        ox, oy = gpos[0] - pos[0], gpos[1] - pos[1]
        y0, x0 = max(0, oy), max(0, ox)
        y1, x1 = min(a.shape[0], oy + g.shape[0]), min(a.shape[1], ox + g.shape[1])
        gl[y0:y1, x0:x1] = g[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    ic = "icone-%s.png" % nom
    icone(a, gl, os.path.join(dest, ic))
    fichiers.append(ic)
    ent["icone"] = {"icon": PREFIXE + ic, "icon_size": 64, "icon_mipmaps": 4}
    al = a[..., 3:4]
    ent["map_color"] = [round(float(x), 3) for x in ((a[..., :3] * al).sum((0, 1)) / max(1e-6, al.sum()))]
    # boîte de dessin : toutes les couches sauf l'ombre, et l'emprise (valeurs en 1/64 de tuile, exactes)
    demi_px = cote * PX // 2
    rects.append((c0[0] - demi_px, c0[1] - demi_px, c0[0] + demi_px, c0[1] + demi_px))
    bx0 = min(r[0] for r in rects)
    by0 = min(r[1] for r in rects)
    bx1 = max(r[2] for r in rects)
    by1 = max(r[3] for r in rects)
    ent["boite"] = [[round((bx0 - c0[0]) / PX, 6), round((by0 - c0[1]) / PX, 6)],
                    [round((bx1 - c0[0]) / PX, 6), round((by1 - c0[1]) / PX, 6)]]
    # calage du corps opaque (alpha >= 200) contre l'emprise, en pixels hr : retrait (+) ou débord (-) à l'ouest, à l'est, au sud
    ys, xs = np.nonzero(a[..., 3] >= 200 / 255.0)
    demi = cote * PX // 2
    ent["calage_px"] = {"ouest": int(pos[0] + xs.min() - (c0[0] - demi)), "est": int((c0[0] + demi) - (pos[0] + xs.max() + 1)),
                        "sud": int((c0[1] + demi) - (pos[1] + ys.max() + 1))}
    return proto, ent


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=SRC_DEFAUT)
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for f in os.listdir(a.dest):
        if f.endswith(".png"):
            os.remove(os.path.join(a.dest, f))
    fichiers, journal, tab = [], [], {}
    for nom in sorted(MACHINES):
        proto, ent = une_machine(a.src, a.dest, nom, fichiers, journal)
        tab[proto] = ent
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/calcul/feuilles.py (lot MACHINES-CALCUL) : ne pas modifier à la main.\n"
              "-- Tailles en pixels, shift et boîtes en tuiles ; hr = 64 px par tuile (scale 0,5), normale = 32 (moyenne 2 x 2 exacte).\n"
              "-- Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + lua(tab) + "\n")
    with open(os.path.join(a.dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(tab, f, indent=1, sort_keys=True, ensure_ascii=False)
    man = {"commande": COMMANDE, "arguments": [], "sources": "fo-logs/2026-11-01_CALCUL-DESIGN/final", "machines": len(tab),
           "fichiers": {}}
    total, mpx_hr, mpx_lr = 0, 0.0, 0.0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        w, h = Image.open(p).size
        n = os.path.getsize(p)
        total += n
        if fn.startswith("hr-"):
            mpx_hr += w * h / 1e6
        elif not fn.startswith("icone-"):
            mpx_lr += w * h / 1e6
        man["fichiers"][fn] = {"sha256": sha(p), "taille": n, "largeur": w, "hauteur": h}
    man["mpx_hr"], man["mpx_normale"] = round(mpx_hr, 3), round(mpx_lr, 3)
    man["nettoyage"] = journal
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("%s %d machines, %d fichiers PNG, %.2f Mo, %.2f Mpx hr, %.2f Mpx normale ; sources %s"
          % (ETIQUETTE, len(tab), len(fichiers), total / 1e6, mpx_hr, mpx_lr, a.src))


if __name__ == "__main__":
    main()
