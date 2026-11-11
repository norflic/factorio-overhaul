"""FEUILLES PROCÉDURALES DES EFFETS (lot POLISSAGE-FX, 10/11) : VORTEX (spirale lumineuse qui tourne, 8 images) et ONDE (anneau de
choc qui s'élargit et s'éteint, 8 images). Blanches, en alpha : la TEINTE du prototype (couleur de l'arme, lue dans ses données)
leur donne leur couleur ; dessinées en « additive » / draw_as_glow par le jeu.

    py -3.9 tools/render/pieces/effets/vortex.py [--dest graphics/effets]      (depuis la racine du mod ; numpy + Pillow, pas de Blender)

Sorties (hors git, D-6) : hr-vortex.png (8 × 256 px), vortex.png (8 × 128 px), hr-onde.png, onde.png ; lot ART-IMPACTS (11/11) :
choc (onde au sol, 16 images), singularite + singularite-ombre (distorsion, 16), faisceau (corps de faisceau dense, 8),
eclat (bouts du faisceau, 8), en grilles d'au plus 1 024 px de côté ; sprites.lua (lu par
prototypes/effets_armes.lua : tailles, images, échelles), MANIFEST.json (SHA-256). DÉTERMINISTE : pur calcul, aucun aléa ;
la trigonométrie reste ici (outil de rendu), jamais dans la simulation (shared/content/effets_armes.lua, script).
"""
import argparse
import hashlib
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
DEST_DEFAUT = os.path.join(MOD, "graphics", "effets")
PREFIXE_JEU = "__factorio-overhaul__/graphics/effets/"
IMAGES = 8
PX = 128          # résolution normale ; hr = 2 ×
COMMANDE = "py -3.9 tools/render/pieces/effets/vortex.py   (depuis la racine du mod)"


def grille(n):
    """Coordonnées polaires normalisées d'une image n × n : r (0 au centre, 1 au bord inscrit), theta (radians)."""
    u = (np.arange(n) + 0.5) / n * 2.0 - 1.0
    x, y = np.meshgrid(u, u)
    return np.sqrt(x * x + y * y), np.arctan2(y, x)


def vortex(n, k):
    """Image k du vortex : trois bras en spirale logarithmique qui tournent d'un huitième de tour par image, cœur brillant,
    bord qui s'éteint en douceur ; luminance L (0-1) et alpha."""
    r, th = grille(n)
    phase = 2.0 * np.pi * k / IMAGES
    tors = 5.5 * np.log(np.maximum(r, 0.02))           # spirale : l'angle du bras dépend du rayon
    bras = 0.5 + 0.5 * np.cos(3.0 * th + tors - phase)  # 3 bras
    bras = bras ** 3.0
    rayon = np.clip(1.0 - r, 0.0, 1.0) ** 1.4           # s'éteint vers le bord
    coeur = np.exp(-(r / 0.16) ** 2)
    anneau = np.exp(-((r - 0.55) / 0.12) ** 2) * 0.35
    L = np.clip(bras * rayon * 0.9 + coeur * 1.2 + anneau, 0.0, 1.0)
    L = np.where(r > 1.0, 0.0, L)
    a = np.clip(L * 1.15, 0.0, 1.0)
    return L, a


def onde(n, k):
    """Image k de l'onde : anneau qui part du centre (rayon 0,12) et atteint le bord (0,95) à la dernière image, de plus en plus
    fin et transparent ; léger voile derrière le front."""
    r, _ = grille(n)
    t = k / (IMAGES - 1.0)
    r0 = 0.12 + 0.83 * t
    w = 0.16 * (1.0 - 0.55 * t)
    front = np.exp(-((r - r0) / w) ** 2)
    voile = np.clip((r0 - r) / max(r0, 1e-6), 0.0, 1.0) * 0.18 * (1.0 - t)
    L = np.clip(front + voile, 0.0, 1.0) * (1.0 - 0.75 * t)
    L = np.where(r > 1.0, 0.0, L)
    return L, np.clip(L * 1.3, 0.0, 1.0)


def feuille(fn, n):
    """Rangée de IMAGES images n × n ; blanc en RGB, luminance dans l'alpha (une teinte multiplie RGB : la couleur de l'arme)."""
    sheet = np.zeros((n, n * IMAGES, 4), dtype=np.float64)
    for k in range(IMAGES):
        L, a = fn(n, k)
        cell = sheet[:, k * n:(k + 1) * n]
        cell[..., 0] = cell[..., 1] = cell[..., 2] = np.clip(0.55 + 0.45 * L, 0.0, 1.0)
        cell[..., 3] = a
    return Image.fromarray((sheet * 255.0).round().astype(np.uint8), "RGBA")


# ---------------------------------------------------------------------------------------------------------------------
# IMPACTS (lot ART-IMPACTS, 11/11, mandat de nuit du DC : « faisceaux denses, ondes de choc au sol, distorsions de
# singularité ») : feuilles en GRILLE (line_length colonnes) pour rester sous 2 048 px de côté ; mêmes conventions :
# blanc + luminance dans l'alpha (la teinte de l'arme colore), sauf l'OMBRE de la singularité (noire, mélange normal).
# ---------------------------------------------------------------------------------------------------------------------
N_CHOC = 16
N_SING = 16
N_FAISCEAU = 8
N_ECLAT = 8


def _vie(k, n):
    return k / (n - 1.0)


def choc(n, k):
    """Onde de choc AU SOL : front épais qui part vite puis ralentit (sortie en douceur), stries radiales (poussière
    soulevée), voile de poussière derrière le front, éclair au centre au début ; tout s'éteint à la fin."""
    r, th = grille(n)
    t = _vie(k, N_CHOC)
    te = 1.0 - (1.0 - t) ** 2.2                                  # sortie en douceur : le front ralentit
    r0 = 0.08 + 0.86 * te
    w = 0.05 + 0.09 * (1.0 - t)
    front = np.exp(-((r - r0) / w) ** 2)
    stries = 0.62 + 0.38 * (0.5 + 0.5 * np.cos(23.0 * th + 2.6 * np.sin(7.0 * th))) ** 2
    echo = 0.45 * np.exp(-((r - 0.72 * r0) / (0.7 * w)) ** 2)    # second anneau, plus faible
    poussiere = np.clip((r0 - r) / max(r0, 1e-6), 0.0, 1.0) ** 0.6 * (0.30 + 0.12 * np.cos(11.0 * th + 9.0 * r))
    eclair = np.exp(-(r / 0.14) ** 2) * (1.0 - t) ** 3 * 1.4
    L = (front * stries + echo * stries + poussiere * (1.0 - t)) * (1.0 - t) ** 0.9 + eclair
    L = np.where(r > 1.0, 0.0, np.clip(L, 0.0, 1.0))
    return L, np.clip(L * 1.25, 0.0, 1.0)


def _taille_sing(t):
    """Rayon relatif de la singularité au cours de sa vie : s'ouvre vite, tient, s'effondre (0,15 au plus petit)."""
    return max(0.15, min(1.0, 3.0 * t) * min(1.0, 3.0 * (1.0 - t)) ** 0.5)


def singularite(n, k):
    """Distorsion de singularité (couche LUMINEUSE, additive) : anneau de photons fin, disque d'accrétion qui tourne en
    bras spiralés aspirés vers le centre, halo de lentille ; le centre reste vide (l'ombre le noircit)."""
    r0, th = grille(n)
    t = _vie(k, N_SING)
    s = _taille_sing(t)
    r = r0 / s
    phase = 2.0 * np.pi * k / N_SING * 1.5
    photon = np.exp(-((r - 0.30) / 0.025) ** 2) * 1.2
    bras = (0.5 + 0.5 * np.cos(2.0 * th + 7.0 * np.log(np.maximum(r, 0.05)) - phase)) ** 4
    disque = np.exp(-((r - 0.44) / 0.12) ** 2) * (0.35 + 0.65 * bras)
    halo = np.exp(-((r - 0.62) / 0.16) ** 2) * 0.28 * (0.6 + 0.4 * np.cos(4.0 * th - 0.5 * phase))
    L = (photon + disque + halo) * np.where(r < 0.26, 0.0, 1.0)
    fond = min(1.0, 4.0 * (1.0 - t))
    L = np.where(r0 > 1.0, 0.0, np.clip(L * fond, 0.0, 1.0))
    return L, np.clip(L * 1.2, 0.0, 1.0)


def singularite_ombre(n, k):
    """Distorsion de singularité (couche OMBRE, mélange normal) : disque NOIR au bord adouci, de la taille du centre."""
    r0, _ = grille(n)
    t = _vie(k, N_SING)
    s = _taille_sing(t)
    r = r0 / s
    a = np.clip(1.0 - ((r - 0.20) / 0.10), 0.0, 1.0) ** 1.5 * 0.92
    fond = min(1.0, 4.0 * (1.0 - t))
    a = np.where(r0 > 1.0, 0.0, a * fond)
    return np.zeros_like(a), a


JOINT = 0.07   # part de l'image, à chaque bout, en fondu : le moteur pose les maillons d'un faisceau à ~0,93 tuile l'un de
               # l'autre (mesuré sur capture, 11/11) ; une image d'UNE tuile les fait se chevaucher de ~0,07 : fondus
               # complémentaires, ni trou (image plus courte : jointures sombres) ni carré brillant (chevauchement additif).


def faisceau(w, h, k):
    """Corps de FAISCEAU DENSE, raccordable le long du trait (fréquences entières le long de u) : cœur blanc épais,
    gaine lumineuse large, filaments d'énergie qui défilent d'un huitième de période par image ; fondu aux deux bouts."""
    u = (np.arange(w) + 0.5) / w                     # le long du faisceau, 0..1 (raccord à 1)
    v = (np.arange(h) + 0.5) / h * 2.0 - 1.0         # en travers, -1..1
    U, V = np.meshgrid(u, v)
    ph = 2.0 * np.pi * k / N_FAISCEAU
    coeur = np.exp(-(V / 0.24) ** 2) * 1.5
    gaine = np.exp(-(V / 0.62) ** 2) * 0.80
    fil = 0.5 + 0.5 * np.cos(2.0 * np.pi * 2.0 * U - ph + 5.0 * V)
    fil2 = 0.5 + 0.5 * np.cos(2.0 * np.pi * 3.0 * U + ph - 4.0 * V)
    L = coeur + gaine * (0.45 + 0.35 * fil + 0.20 * fil2)
    L = L * np.clip(1.0 - np.abs(V) ** 6, 0.0, 1.0)
    fondu = np.clip(np.minimum(U, 1.0 - U) / JOINT, 0.0, 1.0)
    L = np.clip(L, 0.0, 1.0) * (0.5 + 0.5 * fondu)
    return L, np.clip(L * 1.15, 0.0, 1.0)


def eclat(n, k):
    """Éclat (bouts du faisceau) : cœur brillant, six rayons qui tournent et vacillent, anneau léger."""
    r, th = grille(n)
    ph = 2.0 * np.pi * k / N_ECLAT
    vac = 0.8 + 0.2 * np.cos(3.0 * ph)
    coeur = np.exp(-(r / 0.16) ** 2) * 1.3
    rayons = (0.5 + 0.5 * np.cos(6.0 * th + ph)) ** 8 * np.exp(-r / 0.42) * 0.9
    anneau = np.exp(-((r - 0.45) / 0.08) ** 2) * 0.25
    L = np.where(r > 1.0, 0.0, np.clip((coeur + rayons + anneau) * vac, 0.0, 1.0))
    return L, np.clip(L * 1.2, 0.0, 1.0)


def grille_feuille(fn, w, h, n_images, cols, noir=False):
    """Grille de n_images images w × h, cols colonnes ; blanc (ou noir pour l'ombre) en RGB, luminance dans l'alpha."""
    rows = (n_images + cols - 1) // cols
    sheet = np.zeros((h * rows, w * cols, 4), dtype=np.float64)
    for k in range(n_images):
        L, a = fn(k)
        y0, x0 = (k // cols) * h, (k % cols) * w
        cell = sheet[y0:y0 + h, x0:x0 + w]
        if not noir:
            cell[..., 0] = cell[..., 1] = cell[..., 2] = np.clip(0.55 + 0.45 * L, 0.0, 1.0)
        cell[..., 3] = a
    return Image.fromarray((sheet * 255.0).round().astype(np.uint8), "RGBA")


# nom -> (fonction(w, h, k) -> (L, a), images, colonnes, largeur lr, hauteur lr, noire)
IMPACTS = (
    ("choc", lambda w, h, k: choc(w, k), N_CHOC, 4, 128, 128, False),
    ("singularite", lambda w, h, k: singularite(w, k), N_SING, 4, 128, 128, False),
    ("singularite-ombre", lambda w, h, k: singularite_ombre(w, k), N_SING, 4, 128, 128, True),
    ("faisceau", lambda w, h, k: faisceau(w, h, k), N_FAISCEAU, N_FAISCEAU, 32, 24, False),
    ("eclat", lambda w, h, k: eclat(w, k), N_ECLAT, N_ECLAT, 64, 64, False),
)


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def lua(v, ind=0):
    pad = "  " * ind
    if isinstance(v, dict):
        rows = []
        for k in sorted(v):
            key = k if k.isidentifier() else '["%s"]' % k
            rows.append("%s  %s = %s" % (pad, key, lua(v[k], ind + 1)))
        return "{\n" + ",\n".join(rows) + "\n" + pad + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x, ind + 1) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v
    return repr(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=DEST_DEFAUT)
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    tab, fichiers = {}, []
    for nom, fn in (("vortex", vortex), ("onde", onde)):
        ent = {"images": IMAGES, "lr": {}, "hr": {}}
        for cle, n in (("lr", PX), ("hr", 2 * PX)):
            f = ("hr-%s.png" if cle == "hr" else "%s.png") % nom
            im = feuille(fn, n)
            im.save(os.path.join(a.dest, f), optimize=True)
            fichiers.append(f)
            ent[cle] = {"filename": PREFIXE_JEU + f, "width": n, "height": n, "scale": 1.0 if cle == "lr" else 0.5}
        tab[nom] = ent
    for nom, fn, n_img, cols, wl, hl, noir in IMPACTS:
        ent = {"images": n_img, "line_length": cols, "lr": {}, "hr": {}}
        for cle, f_px in (("lr", 1), ("hr", 2)):
            w, h = wl * f_px, hl * f_px
            f = ("hr-%s.png" if cle == "hr" else "%s.png") % nom
            im = grille_feuille(lambda k, w=w, h=h, fn=fn: fn(w, h, k), w, h, n_img, cols, noir)
            im.save(os.path.join(a.dest, f), optimize=True)
            fichiers.append(f)
            ent[cle] = {"filename": PREFIXE_JEU + f, "width": w, "height": h, "scale": 1.0 if cle == "lr" else 0.5}
        tab[nom] = ent
    entete = ("-- FICHIER GÉNÉRÉ par tools/render/pieces/effets/vortex.py (lot POLISSAGE-FX) : ne pas modifier à la main.\n"
              "-- Rangées de « images » images carrées ; lr = 32 px par tuile pour 1 tuile = 128 px (scale 1), hr = scale 0,5.\n"
              "-- « line_length » présent : grille de line_length colonnes (lot ART-IMPACTS ; le faisceau a des images non carrées).\n"
              "-- Images hors de git (D-6) : MANIFEST.json, « commande ».\n")
    with open(os.path.join(a.dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(entete + "return " + lua(tab) + "\n")
    man = {"commande": COMMANDE, "fichiers": {}}
    total = 0
    for fn in sorted(fichiers):
        p = os.path.join(a.dest, fn)
        w, h = Image.open(p).size
        s = os.path.getsize(p)
        total += s
        man["fichiers"][fn] = {"sha256": sha(p), "taille": s, "largeur": w, "hauteur": h}
    with open(os.path.join(a.dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FEUILLES-EFFETS] %d PNG, %.2f Mo -> %s" % (len(fichiers), total / 1e6, a.dest))


if __name__ == "__main__":
    main()
