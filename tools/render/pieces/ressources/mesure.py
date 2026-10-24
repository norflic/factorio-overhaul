"""Mesures d'une feuille de gisement contre les minerais vanilla (lot M1, 24/10). Python système (py -3.9).

    py -3.9 tools/render/pieces/ressources/mesure.py --data "<racine>/data" --feuille A=<dossier> [--feuille B=...]
        [--json mesures.json] [--planche planche.png] [--sol-vanilla grass-1]

Mesures (couche hr, pixels d'alpha > 0,9 sauf mention) :
  - couverture par stade : part des pixels d'alpha > 0,5 d'une image de 128 px, moyenne des 8 variantes ;
  - luminance (Rec. 709 des valeurs sRGB codées, /255) : médiane, moyenne, p95 ; saturation moyenne (HSV) ;
  - reflets : couleur moyenne des 10 % de pixels les plus clairs, sa teinte et sa saturation ;
  - écart à chaque minerai vanilla : ΔE (CIE76, Lab D65) de la couleur moyenne et des reflets, écart de médiane ;
  - lisibilité (planche hors moteur) : contraste de luminance minerai / sol (médiane du minerai composé sur le sol
    moins médiane du sol nu), au zoom 2 (hr, 64 px/tuile) et au zoom 1 (normale, 32 px/tuile), de jour et de nuit.
    La NUIT est une APPROXIMATION hors moteur (image × 0,2, plus la couche d'effet additive × alpha maximal ×
    multiplicateur d'obscurité, comme l'uranium vanilla) : seules les captures en jeu font foi.
    ATTENTION (correction M1, 24/10) : cette approximation s'est trompée de SIGNE sur le commit a9038a9 (tungstène
    16,1 contre fer 13,5 hors moteur ; 7,5 contre 11,2 sur les captures en moteur). Le critère de nuit est celui de
    lisibilite_moteur.py, sur les captures du scénario m1-minerai ; les chiffres de nuit d'ici ne décident de rien ;
  - couleurs VUES (repartition) : sombres, acier (dont bleutés), chauds, et histogramme de luminance.
La planche montre, pour chaque minerai, un gisement de 9 × 7 tuiles (stade selon la distance au centre, variante au
hasard fixe) sur le sol de cendres volcaniques (nuclear-ground × teinte du biome) et sur le sol vanilla donné.
"""
import argparse
import colorsys
import json
import os
import random

import numpy as np
from PIL import Image, ImageDraw

VANILLA = ("iron-ore", "copper-ore", "coal", "stone", "uranium-ore")
CENDRES_TEINTE = (0.80, 0.92, 1.00)   # shared/content/world.lua, fo-volcanic-ash


def lire(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float64) / 255.0


def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lab(rgb):
    lin = srgb_to_lin(np.asarray(rgb, np.float64))
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = M @ lin / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def repartition(sheet):
    """Répartition des couleurs VUES (correction M1, 24/10, MAJEUR 2 de la vérification) : pixels d'alpha > 0,9 de la
    couche hr, valeurs sRGB codées (0 à 255). Classes (définitions du vérificateur, v_palette.py) :
      - chauds : r − b > 12 et r ≥ g (brun-rouge, rouille, lave) ;
      - sombres : luminance < 40 et non chauds (wolframite noire, basalte) ;
      - acier : luminance ≥ 40 et non chauds ; dont « bleutés » : b − r > 4.
    La répartition des MATIÈRES dans la scène n'est pas celle qu'on voit (le reflet du ciel éclaircit la wolframite) :
    c'est celle-ci qu'on annonce, et le MANIFEST.json de la feuille la porte (check_gisement.py la recalcule)."""
    m = sheet[..., 3] > 0.9
    px = sheet[..., :3][m] * 255.0
    if len(px) == 0:
        return {"sombres": 0.0, "acier": 0.0, "acier_bleutes": 0.0, "chauds": 0.0, "L": [0.0] * 4}
    lum = px @ np.array([0.2126, 0.7152, 0.0722])
    chaud = (px[:, 0] - px[:, 2] > 12) & (px[:, 0] >= px[:, 1])
    bleu = (px[:, 2] - px[:, 0] > 4) & ~chaud
    r = lambda x: round(float(x), 3)  # noqa: E731
    return {"sombres": r(((lum < 40) & ~chaud).mean()), "acier": r(((lum >= 40) & ~chaud).mean()),
            "acier_bleutes": r((bleu & (lum >= 40)).mean()), "chauds": r(chaud.mean()),
            "L": [r(((lum >= s) & (lum < e)).mean()) for s, e in ((0, 40), (40, 80), (80, 120), (120, 256))]}


def stats(sheet):
    a = sheet[..., 3]
    fs = sheet.shape[1] // 8
    couv = []
    for r in range(8):
        couv.append(round(float(np.mean([(a[r * fs:(r + 1) * fs, c * fs:(c + 1) * fs] > 0.5).mean()
                                         for c in range(8)])), 4))
    m = a > 0.9
    rgb = sheet[..., :3][m]
    L = rgb @ np.array([0.2126, 0.7152, 0.0722])
    mx, mn = rgb.max(1), rgb.min(1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    top = L >= np.percentile(L, 90)
    moy = rgb.mean(0)
    refl = rgb[top].mean(0)
    h, s, _ = colorsys.rgb_to_hsv(*refl)
    return {
        "couverture": couv, "couverture_moy": round(float(np.mean(couv)), 4),
        "L_med": round(float(np.median(L) * 255), 1), "L_moy": round(float(L.mean() * 255), 1),
        "L_p95": round(float(np.percentile(L, 95) * 255), 1), "sat": round(float(sat.mean()), 3),
        "couleur": [round(float(x * 255), 1) for x in moy], "reflets": [round(float(x * 255), 1) for x in refl],
        "reflets_teinte": round(h * 360, 1), "reflets_sat": round(s, 3),
        "repartition": repartition(sheet),
        "_lab": lab(moy).tolist(), "_lab_refl": lab(refl).tolist(),
    }


def sol(data, nom, px, teinte=None, taille=None):
    """Texture de sol répétée (premier carré de la texture de matière vanilla), à px pixels par tuile."""
    hr = os.path.join(data, "base", "graphics", "terrain", "hr-%s.png" % nom)
    im4 = lire(hr)
    s = min(512, im4.shape[0])
    # carré le plus opaque (les textures de matière ont des zones transparentes de transition), le reste comblé par
    # la couleur moyenne opaque
    best, bx = -1.0, 0
    for x in range(0, im4.shape[1] - s + 1, s):
        o = im4[:s, x:x + s, 3].mean()
        if o > best:
            best, bx = o, x
    t4 = im4[:s, bx:bx + s]
    op = t4[..., 3:4]
    moy = (t4[..., :3] * op).sum((0, 1)) / max(1e-6, op.sum())
    t = t4[..., :3] * op + moy * (1 - op)
    if teinte is not None:
        t = t * np.array(teinte)
    if px != 64:
        t = np.asarray(Image.fromarray((t * 255).astype(np.uint8)).resize((s * px // 64, s * px // 64),
                                                                        Image.LANCZOS)).astype(np.float64) / 255
    H, W = taille
    reps = (H // t.shape[0] + 1, W // t.shape[1] + 1, 1)
    return np.tile(t, reps)[:H, :W]


def gisement(fond, sheet, effet, px, tw=9, th=7, graine=7):
    """Compose un gisement de tw × th tuiles sur le fond (RGB) ; renvoie (jour, couche d'effet au même cadre)."""
    rng = random.Random(graine)
    fs = sheet.shape[1] // 8
    out = fond.copy()
    eff = np.zeros(fond.shape[:2] + (1,))
    ox, oy = (fond.shape[1] - tw * px) // 2, (fond.shape[0] - th * px) // 2
    for ty in range(th):
        for tx in range(tw):
            dx, dy = (tx - (tw - 1) / 2) / (tw / 2), (ty - (th - 1) / 2) / (th / 2)
            r = (dx * dx + dy * dy) ** 0.5
            if r > 1.05:
                continue
            stade = min(7, int(r * 8))
            v = rng.randrange(8)
            fr = sheet[stade * fs:(stade + 1) * fs, v * fs:(v + 1) * fs]
            cx, cy = ox + tx * px + px // 2, oy + ty * px + px // 2
            x0, y0 = cx - fs // 2, cy - fs // 2
            a = fr[..., 3:4]
            reg = out[y0:y0 + fs, x0:x0 + fs]
            lin = srgb_to_lin(fr[..., :3]) * a + srgb_to_lin(reg) * (1 - a)
            out[y0:y0 + fs, x0:x0 + fs] = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.maximum(lin, 0) ** (1 / 2.4) - 0.055)
            if effet is not None:
                e = effet[stade * fs:(stade + 1) * fs, v * fs:(v + 1) * fs]
                eff[y0:y0 + fs, x0:x0 + fs] += e[..., 3:4]
    return out, np.clip(eff, 0, 1)


def nuit(jour, eff, effet_rgb, alpha_max, mult):
    base = jour * 0.2
    return np.clip(base + eff * np.array(effet_rgb) * alpha_max * min(1.0, mult * 0.25), 0, 1)


def contraste(img, fond):
    Li = img @ np.array([0.2126, 0.7152, 0.0722])
    Lf = fond @ np.array([0.2126, 0.7152, 0.0722])
    d = np.abs(Li - Lf)
    return round(float(d[d > 0.02].mean() * 255) if (d > 0.02).any() else 0.0, 1), round(float((d > 0.06).mean()), 4)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--feuille", action="append", default=[], help="NOM=dossier (hr-<nom>.png dedans)")
    ap.add_argument("--nom", default="tungstene")
    ap.add_argument("--json")
    ap.add_argument("--planche")
    ap.add_argument("--sol-vanilla", default="grass-1")
    a = ap.parse_args()
    ent = os.path.join(a.data, "base", "graphics", "entity")
    jeux = []
    for n in VANILLA:
        eff = os.path.join(ent, n, "hr-%s-glow.png" % n)
        jeux.append((n, os.path.join(ent, n, "hr-%s.png" % n), os.path.join(ent, n, "%s.png" % n),
                     eff if os.path.exists(eff) else None, os.path.join(ent, n, "%s-glow.png" % n)))
    for f in a.feuille:
        k, d = f.split("=", 1)
        eh = os.path.join(d, "hr-%s-effet.png" % a.nom)
        jeux.append((k, os.path.join(d, "hr-%s.png" % a.nom), os.path.join(d, "%s.png" % a.nom),
                     eh if os.path.exists(eh) else None, os.path.join(d, "%s-effet.png" % a.nom)))
    res = {}
    for k, hr, _, _, _ in jeux:
        res[k] = stats(lire(hr))
    for k in res:
        if k in VANILLA:
            continue
        ec = {}
        for v in VANILLA:
            ec[v] = {"dE_couleur": round(float(np.linalg.norm(np.array(res[k]["_lab"]) - res[v]["_lab"])), 1),
                     "dE_reflets": round(float(np.linalg.norm(np.array(res[k]["_lab_refl"]) - res[v]["_lab_refl"])), 1),
                     "dL_med": round(res[k]["L_med"] - res[v]["L_med"], 1)}
        res[k]["ecarts"] = ec
    # planche et lisibilité
    lis = {}
    if a.planche:
        lignes = []
        for px, zoom in ((64, 2), (32, 1)):
            H, W = 7 * px + 2 * px, 9 * px + 2 * px
            sols = {"cendres": sol(a.data, "nuclear-ground", px, CENDRES_TEINTE, (H, W)),
                    a.sol_vanilla: sol(a.data, a.sol_vanilla, px, None, (H, W))}
            for nom_sol in ("cendres", a.sol_vanilla):
                fond = sols[nom_sol]
                rangee_j, rangee_n = [], []
                for k, hr, nr, eh, en in jeux:
                    sheet = lire(hr if px == 64 else nr)
                    effp = (eh if px == 64 else en)
                    effet = lire(effp) if eh and os.path.exists(effp) else None
                    j, e = gisement(fond, sheet, effet, px)
                    if effet is not None:
                        m = effet[..., 3] > 0.05
                        ergb = (effet[..., :3][m].mean(0) if m.any() else np.ones(3))
                    else:
                        ergb = np.zeros(3)
                    amax, mult = (0.3, 3.6) if k == "uranium-ore" else (0.6, 3.6)
                    n = nuit(j, e, ergb, amax, mult)
                    lis.setdefault(k, {})["z%d-%s-jour" % (zoom, nom_sol)] = contraste(j, fond)
                    lis[k]["z%d-%s-nuit" % (zoom, nom_sol)] = contraste(n, fond * 0.2)
                    rangee_j.append(j)
                    rangee_n.append(n)
                for rangee in (rangee_j, rangee_n):
                    ligne = np.concatenate([np.pad(x, ((0, 0), (0, 8), (0, 0))) for x in rangee], 1)
                    if px == 32:
                        ligne = np.repeat(np.repeat(ligne, 2, 0), 2, 1)
                    lignes.append(ligne)
        Wm = max(l.shape[1] for l in lignes)
        img = np.concatenate([np.pad(l, ((0, 8), (0, Wm - l.shape[1]), (0, 0))) for l in lignes], 0)
        pil = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
        dr = ImageDraw.Draw(pil)
        cw = jeux and (9 * 64 + 2 * 64 + 8)
        for i, j in enumerate(jeux):
            dr.text((i * cw + 6, 4), j[0], fill=(255, 255, 0))
        etiquettes = []
        for zoom in (2, 1):
            for nom_sol in ("cendres", a.sol_vanilla):
                for moment in ("jour", "nuit (approx. hors moteur, NON fiable)"):
                    etiquettes.append("zoom %d, %s, %s" % (zoom, nom_sol, moment))
        y = 0
        for l, t in zip(lignes, etiquettes):
            dr.text((6, y + 16), t, fill=(255, 255, 0))
            y += l.shape[0] + 8
        pil.save(a.planche)
        print("[FO-MESURE] planche : %s (%d × %d)" % (a.planche, pil.size[0], pil.size[1]))
    for k in res:
        r = res[k]
        print("[FO-MESURE] %-12s couv %s | L méd %5.1f moy %5.1f p95 %5.1f sat %.2f | reflets %s %5.1f° sat %.2f" % (
            k, r["couverture"], r["L_med"], r["L_moy"], r["L_p95"], r["sat"], r["reflets"], r["reflets_teinte"],
            r["reflets_sat"]))
        rp = r["repartition"]
        print("[FO-MESURE] %-12s   couleurs vues : sombres %.1f %% | acier %.1f %% (bleutés %.1f %%) | chauds %.1f %% | "
              "L < 40 / 40-80 / 80-120 / > 120 : %s %%" % ("", 100 * rp["sombres"], 100 * rp["acier"],
                                                          100 * rp["acier_bleutes"], 100 * rp["chauds"],
                                                          " / ".join("%.1f" % (100 * x) for x in rp["L"])))
        if "ecarts" in r:
            print("[FO-MESURE] %-12s   écarts : %s" % ("", "; ".join(
                "%s ΔE %.0f / reflets %.0f / ΔL %+.0f" % (v, e["dE_couleur"], e["dE_reflets"], e["dL_med"])
                for v, e in r["ecarts"].items())))
        if k in lis:
            print("[FO-MESURE] %-12s   contraste au sol (moyen /255, part > 0,06) : %s" % ("", "; ".join(
                "%s %s" % (c, lis[k][c]) for c in sorted(lis[k]))))
    if a.json:
        for r in res.values():
            r.pop("_lab", None)
            r.pop("_lab_refl", None)
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({"mesures": res, "lisibilite": lis}, f, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
