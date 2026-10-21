"""Mesures D1 de la machine d'assemblage 2 (lot V3, phase 1), sur les rendus d'aperçu. Python système (numpy, Pillow).

    python -P tools/render/pieces/levels/assembler/mesures_d1.py [--source complet|masque] [--sortie <fichier.txt>]

Reprend le protocole de docs/epoques/mesures/measure.py (bible §1.4, RD_LOG E27), en numpy :
- toile commune à 64 px par tuile, origine = position de l'entité ; masque = alpha ≥ 0,5 de la couche PRINCIPALE
  (sans ombre, lueur ni halo). Aucun niveau de cette famille n'a de couche plate au sol (socle, dalle) : le masque
  amendé (Q13 a) est donc le masque entier. Le liseré de contact fait partie de la couche principale, comme en vanilla ;
- niveau 1 = sprite vanilla hr, image 0 ; niveau 2 = union du sprite vanilla et de la pièce masquée ;
- O (masses) : dépassement au-dessus de l'emprise après ouverture morphologique par un carré de 0,15 tuile (10 px),
  qui retire les tiges fines (mâts, antennes, câbles : bible §1.4) ; O total : sur le masque brut ;
- D1-1 : aire ajoutée par la pièce paire hors du masque impair (≥ 0,10 t² visé) ; aire où la luminance change d'au
  moins 20/255 (≥ 0,15 t², autre voie du critère) ; IoU impair / pair précédent (≤ 0,85) ;
- D1-2 : IoU entre époques consécutives (niveaux impairs, ≤ 0,85) ; O jamais décroissant ;
- D1-3 amendé (Q13) : IoU(niveau 1, niveau 30) < 0,50 (cible ≤ 0,45) ET IoU normalisée en échelle = max sur k de
  IoU(niveau 1 agrandi de k autour de l'origine, niveau 30), k de 0,70 à 2,50 par pas de 0,01 (seuil proposé 0,75) ;
- vide V : part du masque du niveau 1 laissée transparente par le niveau ; emprise couverte ; L (largeur des masses).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, HERE)
import params  # noqa: E402

DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
OUT = os.path.join(RENDER, "out", "levels", params.FAMILLE)
PPT = 64
X0, X1, Y0, Y1 = -4.0, 7.0, -5.5, 3.0          # étendue de la toile (tuiles)
W, H = int((X1 - X0) * PPT), int((Y1 - Y0) * PPT)
OX, OY = -X0 * PPT, -Y0 * PPT                   # pixel de l'origine (bord de pixel)
LUMA = np.array([0.2126, 0.7152, 0.0722])


def load_rgba(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


def put(img, shift_tiles):
    """Image hr (64 px/tuile) posée sur la toile : centre = origine + shift."""
    out = np.zeros((H, W, img.shape[2]))
    h, w = img.shape[:2]
    x0 = OX + shift_tiles[0] * PPT - w / 2.0
    y0 = OY + shift_tiles[1] * PPT - h / 2.0
    xi, yi = int(round(x0)), int(round(y0))
    assert abs(x0 - xi) < 1e-6 and abs(y0 - yi) < 1e-6, (x0, y0)
    out[yi:yi + h, xi:xi + w] = img
    return out


def over(top, bottom):
    a_t, a_b = top[..., 3:4], bottom[..., 3:4]
    a = a_t + a_b * (1 - a_t)
    rgb = np.where(a > 1e-8, (top[..., :3] * a_t + bottom[..., :3] * a_b * (1 - a_t)) / np.maximum(a, 1e-8), 0)
    return np.concatenate([rgb, a], -1)


def vanilla():
    v = params.VANILLA["main"]
    im = load_rgba(os.path.join(DATA, "base", "graphics", "entity", v["file"]))
    w, h = v["frame"]
    return put(im[:h, :w], v["shift"])


def level_rgba(n, source):
    """Couche principale du niveau n sur la toile (RGBA)."""
    if n == 1:
        return vanilla()
    if source == "masque":
        a = np.asarray(Image.open(os.path.join(OUT, "masques", "masque-n%02d.png" % n))).astype(np.float64) / 255.0
        with open(os.path.join(OUT, "masques", "masque-n%02d.json" % n), encoding="utf-8") as f:
            ox, oy = json.load(f)["origin_px"]
        img = np.zeros(a.shape + (4,))
        img[..., 3] = a
        h, w = a.shape
        shift = ((w / 2.0 - ox) / PPT, (h / 2.0 - oy) / PPT)
        lay = put(img, shift)
    else:
        with open(os.path.join(OUT, "n%02d" % n, "n%02d.json" % n), encoding="utf-8") as f:
            rec = json.load(f)
        sd = rec["spec"]["main"]["hr"]
        lay = put(load_rgba(os.path.join(OUT, "n%02d" % n, sd["filename"])), sd["shift"])
    if n == 2:
        return over(lay, vanilla())
    return lay


def opening(m, k=10):
    """Ouverture morphologique par un carré k × k (images d'intégrales)."""
    m = m.astype(np.int32)
    I = np.zeros((m.shape[0] + 1, m.shape[1] + 1), np.int32)
    I[1:, 1:] = m.cumsum(0).cumsum(1)
    full = np.zeros_like(m)
    s = I[k:, k:] - I[:-k, k:] - I[k:, :-k] + I[:-k, :-k]
    full[:s.shape[0], :s.shape[1]] = (s == k * k)
    J = np.zeros((m.shape[0] + k, m.shape[1] + k), np.int32)
    J[k:, k:] = full.cumsum(0).cumsum(1)
    # pixel (y, x) couvert si une fenêtre pleine a son coin en (y', x'), y-k < y' ≤ y, x-k < x' ≤ x
    yy, xx = np.arange(m.shape[0]), np.arange(m.shape[1])
    A = J[np.ix_(yy + k, xx + k)] - J[np.ix_(yy, xx + k)] - J[np.ix_(yy + k, xx)] + J[np.ix_(yy, xx)]
    return A > 0


def box(m):
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None
    return dict(left=xs.min() / PPT + X0, right=(xs.max() + 1) / PPT + X0, top=ys.min() / PPT + Y0,
                bottom=(ys.max() + 1) / PPT + Y0)


def iou(a, b):
    u = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / u) if u else 0.0


def scaled(mask, k):
    """Masque agrandi d'un facteur k autour de l'origine (plus proche voisin)."""
    yy, xx = np.mgrid[0:H, 0:W]
    sx = ((xx + 0.5 - OX) / k + OX - 0.5).round().astype(int)
    sy = ((yy + 0.5 - OY) / k + OY - 0.5).round().astype(int)
    ok = (sx >= 0) & (sx < W) & (sy >= 0) & (sy < H)
    out = np.zeros_like(mask)
    out[ok] = mask[sy[ok], sx[ok]]
    return out


def iou_norm(m1, mN):
    best, kb = 0.0, 1.0
    for k in np.arange(0.70, 2.501, 0.01):
        v = iou(scaled(m1, k), mN)
        if v > best:
            best, kb = v, float(k)
    return best, kb


def lum255(rgba):
    return (rgba[..., :3] @ LUMA) * 255.0


def photometry(rgba, m):
    L = lum255(rgba)[m]
    rgb = rgba[..., :3][m]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return dict(p05=float(np.percentile(L, 5)), p50=float(np.percentile(L, 50)), p95=float(np.percentile(L, 95)),
                sat=float(sat.mean()), rgb=[float(x) * 255 for x in rgb.mean(0)])


def glow_area(n):
    p = os.path.join(OUT, "n%02d" % n, "n%02d.json" % n)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        rec = json.load(f)
    g = rec["spec"].get("glow")
    if not g:
        return 0.0
    im = load_rgba(os.path.join(OUT, "n%02d" % n, g["hr"]["filename"]))
    return float((im[..., 3] >= 0.35).sum()) / PPT ** 2


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default="complet", choices=("complet", "masque"))
    ap.add_argument("--sortie", default="")
    ap.add_argument("--json", default=os.path.join(OUT, "mesures-d1.json"))
    a = ap.parse_args()
    rgba, mask, masses = {}, {}, {}
    for n in range(1, 31):
        try:
            rgba[n] = level_rgba(n, a.source)
        except FileNotFoundError:
            continue
        mask[n] = rgba[n][..., 3] >= 0.5
        masses[n] = opening(mask[n])
    half = params.EMPRISE / 2.0
    fp = np.zeros((H, W), bool)
    fp[int(OY - half * PPT):int(OY + half * PPT), int(OX - half * PPT):int(OX + half * PPT)] = True
    A1 = mask[1]
    rows, res = [], {"source": a.source, "levels": {}}
    lines = []
    P_ = lines.append
    P_("Mesures D1 · machine d'assemblage 2 · source : rendus d'aperçu « %s » (64 px/tuile, masque alpha ≥ 0,5)" % a.source)
    P_("Colonnes : O masses / O total (tuiles au-dessus de l'emprise) ; L masses ; aire (t²) ; emprise couverte ; V = part"
       " du masque du niveau 1 laissée vide ; IoU avec le niveau précédent ; ajout = aire de la pièce paire hors du masque"
       " impair (t²) ; ΔL = aire où la luminance change de ≥ 20/255 (t²) ; IoU(1, n).")
    P_("")
    hdr = "niv ép  O_mas  O_tot  L_mas  aire   empr   V%    IoU_prec  ajout  dL     IoU_1n  plafondO  envO   envL   envV"
    P_(hdr)
    prevO = None
    for n in range(1, 31):
        if n not in mask:
            continue
        m, mm = mask[n], masses[n]
        b, bm = box(m), box(mm)
        e = params.epoque(n)
        O_tot = -b["top"] - half
        O_mas = -bm["top"] - half if bm else float("nan")
        L_mas = (bm["right"] - bm["left"]) if bm else float("nan")
        area = m.sum() / PPT ** 2
        cover = (m & fp).sum() / fp.sum()
        V = (A1 & ~m).sum() / A1.sum() * 100
        r = {"epoch": e, "O_masses": O_mas, "O_total": O_tot, "L_masses": L_mas, "area": area, "footprint_cover": cover,
             "V_pct": V, "box": b, "iou_1": iou(A1, m)}
        if n > 1 and (n - 1) in mask:
            r["iou_prev"] = iou(mask[n - 1], m)
        if n % 2 == 0 and (n - 1) in mask:
            add = (m & ~mask[n - 1]).sum() / PPT ** 2
            both = m & mask[n - 1]
            dl = (np.abs(lum255(rgba[n]) - lum255(rgba[n - 1])) >= 20) & both
            r["piece_added"] = add
            r["lum_changed"] = dl.sum() / PPT ** 2 if a.source == "complet" else None
        if a.source == "complet" and n > 1:
            r["photo"] = photometry(rgba[n], m)
            r["glow_area"] = glow_area(n)
        env = params.ENVELOPPE[e]
        res["levels"][n] = r
        P_("%3d %3d  %5.2f  %5.2f  %5.2f  %5.2f  %4.0f%%  %4.0f   %s  %s  %s  %5.3f   %s    %4.2f   %4.2f   %3d" % (
            n, e, O_mas, O_tot, L_mas, area, cover * 100, V,
            ("%6.3f" % r["iou_prev"]) if "iou_prev" in r else "   -  ",
            ("%5.2f" % r["piece_added"]) if "piece_added" in r else "  -  ",
            ("%5.2f" % r["lum_changed"]) if r.get("lum_changed") is not None else "  -  ",
            r["iou_1"], "ok " if O_mas <= params.PLAFOND_O + 1e-9 else "DEP", env[0], env[1], env[2]))
    P_("")
    P_("D1-2 · époques consécutives (niveaux impairs) : IoU (≤ 0,85) et O des masses (jamais décroissant)")
    odd = [n for n in range(1, 31, 2) if n in mask]
    res["consecutive"] = {}
    for i in range(len(odd) - 1):
        p, q = odd[i], odd[i + 1]
        v = iou(mask[p], mask[q])
        dO = res["levels"][q]["O_masses"] - res["levels"][p]["O_masses"]
        res["consecutive"]["%d-%d" % (p, q)] = {"iou": v, "dO": dO}
        P_("  niveaux %2d -> %2d (époques %2d -> %2d) : IoU %.3f %s ; ΔO masses %+.2f %s" % (
            p, q, params.epoque(p), params.epoque(q), v, "ok" if v <= 0.85 else "ÉCHEC", dO, "ok" if dO >= -1e-9 else "DÉCROÎT"))
    P_("")
    P_("D1-1 · niveaux pairs : aire ajoutée par la pièce (≥ 0,10 t²) ; niveaux impairs : IoU avec le pair précédent (≤ 0,85)")
    for n in range(2, 31):
        if n not in mask:
            continue
        r = res["levels"][n]
        if n % 2 == 0 and "piece_added" in r:
            ok = r["piece_added"] >= 0.10 or (r.get("lum_changed") or 0) >= 0.15
            P_("  niveau %2d : pièce +%.3f t² hors du masque impair%s -> %s" % (
                n, r["piece_added"], (" ; luminance changée sur %.3f t²" % r["lum_changed"]) if r.get("lum_changed")
                is not None else "", "ok" if ok else "ÉCHEC"))
        elif n % 2 == 1 and "iou_prev" in r:
            P_("  niveau %2d : IoU avec le niveau %d = %.3f -> %s" % (n, n - 1, r["iou_prev"],
                                                                      "ok" if r["iou_prev"] <= 0.85 else "ÉCHEC"))
    P_("")
    if 30 in mask:
        P_("D1-3 amendé (Q13) · niveau 1 contre dernier niveau, masque sans couche plate au sol")
        for n in (29, 30):
            if n not in mask:
                continue
            v = iou(A1, mask[n])
            vn, kb = iou_norm(A1, mask[n])
            res["D1_3_%d" % n] = {"iou": v, "iou_norm": vn, "k_best": kb}
            P_("  niveau 1 / niveau %d : IoU %.3f (< 0,50 ; cible ≤ 0,45 : %s) ; IoU normalisée en échelle %.3f "
               "(k = %.2f ; seuil proposé 0,75 : %s)" % (n, v, "ok" if v <= 0.45 else ("< 0,50" if v < 0.5 else "ÉCHEC"),
                                                          vn, kb, "ok" if vn <= 0.75 else "AU-DESSUS"))
    if a.source == "complet":
        P_("")
        P_("Photométrie de la couche principale (pixels opaques ; luminance sRGB sur 255 ; bible §1.5 : p50 cible de "
           "l'époque ±10, p95 ≤ 240, saturation ≤ 0,45) et lueur de jour (aire alpha ≥ 0,35, t² ; part du masque)")
        cibles = {1: 50, 2: 52, 3: 58, 4: 60, 5: 42, 6: 64, 7: 55, 8: 60, 9: 56, 10: 82, 11: 100, 12: 60, 13: 92, 14: 88,
                  15: 108}
        for n in range(2, 31):
            r = res["levels"].get(n)
            if not r or "photo" not in r:
                continue
            ph = r["photo"]
            e = r["epoch"]
            ga = r.get("glow_area") or 0.0
            P_("  niveau %2d (ép. %2d) : p05 %5.1f  p50 %5.1f (cible %3d %s)  p95 %5.1f %s  sat %.2f %s  lueur %.3f t² "
               "(%.1f %%)" % (n, e, ph["p05"], ph["p50"], cibles[e], "ok" if abs(ph["p50"] - cibles[e]) <= 10 else "hors",
                              ph["p95"], "ok" if ph["p95"] <= 240 else "HORS", ph["sat"],
                              "ok" if ph["sat"] <= 0.45 else "HORS", ga, ga / r["area"] * 100))
    txt = "\n".join(lines)
    print(txt)
    if a.sortie:
        os.makedirs(os.path.dirname(os.path.abspath(a.sortie)), exist_ok=True)
        with open(a.sortie, "w", encoding="utf-8", newline="\n") as f:
            f.write(txt + "\n")
    os.makedirs(os.path.dirname(a.json), exist_ok=True)
    with open(a.json, "w", encoding="utf-8") as f:
        json.dump(res, f, indent=1, default=float)


if __name__ == "__main__":
    main()
