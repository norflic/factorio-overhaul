"""Mesures D1 automatiques du four (lot V3, famille « furnace », phase 1). Python système (numpy, Pillow).

    python -P tools/render/pieces/levels/furnace/measure_d1.py              # rendus d'aperçu (out/levels/furnace)
    python -P tools/render/pieces/levels/furnace/measure_d1.py --src quick  # silhouettes rapides (out/.../quick)

Protocole (bible docs/DESIGN_EPOQUES.md §1.4, OBJECTIFS D1, amendement Q13) — ce sont des INDICATEURS, ils
aident le verdict du Directeur Créatif sans le remplacer :
- toile commune : 64 px par tuile, origine = position de l'entité, x vers l'est, y vers le bas (écran) ;
- masque d'un niveau = alpha ≥ 0,5 de la couche principale SANS liseré de contact (couche « objmask » :
  alpha de la passe principale avant composition du liseré, qui est une couche plate au sol), sans ombre,
  lueur ni halo. Niveau 1 : alpha du sprite vanilla hr-steel-furnace.png (son liseré est cuit dedans :
  environ 3 px sous le bord bas au seuil 0,5, défaut de mesure connu et minime). Niveau 2 : vanilla ∪ pièce ;
- O = -(haut de la boîte des masses) - 1 (emprise 2×2) ; les tiges fines (< 0,15 tuile = 10 px de large)
  sont retirées par une ouverture morphologique horizontale de 10 px (« masses ») ; O brut donné aussi ;
- L = largeur de la boîte des masses ; couverture de l'emprise = part du carré [-1 ; 1]² couverte (F45) ;
- D1-1 : aire ajoutée par la pièce paire = |M(2e) \\ M(2e-1)| (≥ 0,10 tuile² visée) ; IoU avec le niveau
  précédent (impair : ≤ 0,85) ;
- D1-2 : IoU entre niveaux impairs consécutifs (≤ 0,85) ; O jamais décroissant (vérifié sur les 30 niveaux) ;
  nombre de dépassements (pics du profil haut des masses, proéminence ≥ 0,10 tuile : indicatif) ;
- D1-3 amendé : IoU(niveau 1, dernier niveau) < 0,50 (cible ≤ 0,45) ET IoU normalisée en échelle =
  max sur k ∈ [0,50 ; 3,00] (pas 0,01) de IoU(niveau 1 agrandi de k autour de l'origine, dernier niveau)
  (homothétie de docs/epoques/mesures/measure.py) ; seuil proposé 0,75 ; une seule pose pour le four ;
- vide V = |M1 \\ M(n)| / |M1| (bible §4 : ≥ 5 % à l'époque 10 … ≥ 30 % à l'époque 15) ;
- photométrie du corps (sRGB, comme la bible §1.5) : luminance p05/p50/p95 (sur 255), saturation moyenne ;
- lumière de jour (D2-1) : zones où la lueur (draw_as_glow, additive) porte la luminance du jour à au moins
  la médiane du corps + 80/255 ; part émissive du corps ; présence d'un carré plein de 8 × 8 px HR ;
- halo de nuit (D2-3) : maximum et étendue de la couche halo.
Sorties : docs/epoques/planches/furnace/mesures_d1.json et mesures_d1.txt (tableau).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compose as CP  # noqa: E402
import params as PRM  # noqa: E402

MOD_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
DST = os.path.join(MOD_ROOT, "docs", "epoques", "planches", "furnace")
PPT = 64
X0, X1, Y0, Y1 = -3.0, 3.0, -4.5, 2.0
W, H = int((X1 - X0) * PPT), int((Y1 - Y0) * PPT)
OX, OY = int(-X0 * PPT), int(-Y0 * PPT)
TILE2 = float(PPT * PPT)
LUMA = np.array([0.2126, 0.7152, 0.0722])


def paste(img, shift, canvas=None):
    """Pose une image (H, W, C) centrée sur origine + shift, sur la toile commune."""
    h, w = img.shape[:2]
    c = img.shape[2] if img.ndim == 3 else 1
    out = np.zeros((H, W, c)) if canvas is None else canvas
    x0 = OX + shift[0] * PPT - w / 2.0
    y0 = OY + shift[1] * PPT - h / 2.0
    xi, yi = int(round(x0)), int(round(y0))
    assert abs(x0 - xi) < 1e-6 and abs(y0 - yi) < 1e-6, ("hors grille", shift, w, h)
    xs0, ys0 = max(0, -xi), max(0, -yi)
    xd0, yd0 = max(0, xi), max(0, yi)
    ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
    src = img[ys0:ys0 + hh, xs0:xs0 + ww]
    out[yd0:yd0 + hh, xd0:xd0 + ww] = src.reshape(hh, ww, c)
    return out


def load_png(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


class Level:
    def __init__(self, n, src):
        self.n = n
        self.layers = {}
        if n in (1, 2):
            v = CP.vanilla_layers(False)[1]
            self.vanilla = paste(v["img"], v["shift"])
        if n >= 2:
            d = os.path.join(src, "n%02d" % n)
            with open(os.path.join(d, "spec.json"), encoding="utf-8") as f:
                self.spec = json.load(f)
            for k, s in self.spec["layers"].items():
                self.layers[k] = paste(load_png(os.path.join(d, s["filename"])), s["shift"])
        if n == 1:
            self.mask = self.vanilla[..., 3] >= 0.5
            self.body = self.mask
            self.rgb = self.vanilla[..., :3]
        else:
            own = self.layers["objmask"][..., 3] >= 0.5
            if n == 2:
                self.mask = (self.vanilla[..., 3] >= 0.5) | own
                self.body = own
                self.rgb = self.layers["main"][..., :3]
            else:
                self.mask = own
                self.body = own
                self.rgb = self.layers["main"][..., :3]


def h_open(m, w=10):
    """Ouverture morphologique horizontale : retire ce qui fait moins de w pixels de large."""
    Hh, Ww = m.shape
    c = np.concatenate([np.zeros((Hh, 1), np.int32), np.cumsum(m, 1, dtype=np.int32)], 1)
    er = np.zeros_like(m)
    er[:, :Ww - w + 1] = (c[:, w:] - c[:, :Ww - w + 1]) == w
    c2 = np.concatenate([np.zeros((Hh, 1), np.int32), np.cumsum(er, 1, dtype=np.int32)], 1)
    idx = np.arange(Ww)
    lo = np.maximum(idx - w + 1, 0)
    return (c2[:, idx + 1] - c2[:, lo]) > 0


def bbox(m):
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None
    return {"left": (xs.min() - OX) / PPT, "right": (xs.max() + 1 - OX) / PPT, "top": (ys.min() - OY) / PPT,
            "bottom": (ys.max() + 1 - OY) / PPT}


def iou(a, b):
    u = (a | b).sum()
    return float((a & b).sum() / u) if u else 0.0


def scaled_iou(m1, mn, ks=np.arange(0.50, 3.0001, 0.01)):
    """max sur k de IoU(m1 agrandi de k autour de l'origine, mn) ; renvoie (iou, k)."""
    yy, xx = np.mgrid[0:H, 0:W]
    u = (xx + 0.5 - OX)
    v = (yy + 0.5 - OY)
    best = (0.0, 1.0)
    for k in ks:
        sx = np.floor(OX + u / k).astype(np.int64)
        sy = np.floor(OY + v / k).astype(np.int64)
        ok = (sx >= 0) & (sx < W) & (sy >= 0) & (sy < H)
        sc = np.zeros((H, W), bool)
        sc[ok] = m1[sy[ok], sx[ok]]
        val = iou(sc, mn)
        if val > best[0]:
            best = (val, float(k))
    return best


def peaks(m_mass, prom=0.10, min_sep_px=10):
    """Dépassements : pics du profil haut des masses (proéminence topographique ≥ prom tuile)."""
    has = m_mass.any(0)
    top = np.where(has, np.argmax(m_mass, 0), H)
    h = -(top - OY) / PPT          # hauteur à l'écran au-dessus de l'origine (tuiles)
    h = np.where(has, h, -1.5)
    # lissage léger
    hs = np.convolve(np.pad(h, 2, mode="edge"), np.ones(5) / 5, mode="valid")
    n = len(hs)
    cands = [x for x in range(1, n - 1) if has[x] and hs[x] >= hs[max(0, x - 6):x + 7].max() - 1e-9]
    out = []
    for x in cands:
        # proéminence : descente minimale nécessaire pour atteindre un point plus haut
        left = hs[:x][::-1]
        right = hs[x + 1:]
        def col(seq):
            mn = hs[x]
            for v in seq:
                mn = min(mn, v)
                if v > hs[x] + 1e-9:
                    return mn
            return mn  # bord : on descend jusqu'au minimum du côté
        p = hs[x] - max(col(left), col(right))
        if p >= prom and all(abs(x - y) >= min_sep_px for y in out):
            out.append(x)
    return len(out), [round((x - OX) / PPT, 2) for x in out]


def photometry(rgb, body):
    if not body.any():
        return {}
    c = rgb[body]
    Lm = c @ LUMA * 255
    mx, mn = c.max(-1), c.min(-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return {"L_p05": round(float(np.percentile(Lm, 5)), 1), "L_p50": round(float(np.percentile(Lm, 50)), 1),
            "L_p95": round(float(np.percentile(Lm, 95)), 1), "sat": round(float(sat.mean()), 3)}


def square_inside(z, s=8):
    if z.sum() < s * s:
        return False
    c = np.zeros((z.shape[0] + 1, z.shape[1] + 1), np.int32)
    c[1:, 1:] = np.cumsum(np.cumsum(z, 0, dtype=np.int32), 1, dtype=np.int32)
    win = c[s:, s:] - c[:-s, s:] - c[s:, :-s] + c[:-s, :-s]
    return bool((win == s * s).any())


def emissive(lv, ph):
    g = lv.layers.get("glow")
    if g is None or not ph:
        return {"zone_px": 0, "part": 0.0, "carre_8px": False}
    main = lv.layers["main"]
    pm = main[..., :3] * main[..., 3:4]                # composé sur noir
    day = np.clip(pm + g[..., :3] * g[..., 3:4], 0, 1)
    L = day @ LUMA * 255
    zone = (g[..., 3] >= 0.10) & (L >= ph["L_p50"] + 80) & (main[..., 3] >= 0.5)
    n_body = lv.body.sum()
    return {"zone_px": int(zone.sum()), "part": round(float(zone.sum() / max(1, n_body)), 4),
            "carre_8px": square_inside(zone, 8)}


def halo(lv):
    li = lv.layers.get("light")
    if li is None:
        return None
    s = lv.spec["layers"]["light"]
    return {"max": round(float(li[..., 3].max()), 3), "largeur_t": round(s["width"] / PPT, 2),
            "hauteur_t": round(s["height"] / PPT, 2)}


def measure(src, levels):
    lv = {n: Level(n, src) for n in levels}
    m1 = lv[1].mask
    rows = {}
    for n in levels:
        L_ = lv[n]
        mass = h_open(L_.mask, 10)
        bb, bbr = bbox(mass), bbox(L_.mask)
        fp = L_.mask[OY - PPT:OY + PPT, OX - PPT:OX + PPT]
        ph = photometry(L_.rgb, L_.body)
        r = {"n": n, "epoque": PRM.epoch_of(n), "pair": n % 2 == 0,
             "aire_t2": round(L_.mask.sum() / TILE2, 3),
             "O": round(-bb["top"] - 1.0, 3), "O_brut": round(-bbr["top"] - 1.0, 3), "O_cible": round(PRM.o_target(n), 3),
             "L": round(bb["right"] - bb["left"], 3), "boite": {k: round(v, 3) for k, v in bb.items()},
             "emprise_couverte": round(float(fp.mean()), 3),
             "iou_n1": round(iou(m1, L_.mask), 3),
             "vide_V": round(float((m1 & ~L_.mask).sum() / m1.sum()), 3),
             "photometrie": ph, "palette_cible_L50": PRM.PALETTE[PRM.epoch_of(n)]["L50"]}
        r["depassements"], r["pics_x"] = peaks(mass)
        if n >= 2:
            prev = lv[n - 1].mask
            r["iou_prec"] = round(iou(prev, L_.mask), 3)
            if n % 2 == 0:
                r["aire_ajoutee_t2"] = round(float((L_.mask & ~prev).sum() / TILE2), 3)
            if n % 2 == 1 and n >= 3:
                r["iou_impair_prec"] = round(iou(lv[n - 2].mask, L_.mask), 3)
            r["lumiere_jour"] = emissive(L_, ph)
            r["halo"] = halo(L_)
        rows[n] = r
    last = max(levels)
    res = {"lignes": [rows[n] for n in levels]}
    if last >= 29:
        d13 = {}
        for n in sorted({29, last}):
            si, k = scaled_iou(m1, lv[n].mask)
            d13["n%02d" % n] = {"iou": rows[n]["iou_n1"], "iou_normalisee": round(si, 3), "k": round(k, 2)}
        res["D1_3"] = d13
    # monotonie de O sur les 30 niveaux
    Os = [rows[n]["O"] for n in levels]
    res["O_monotone"] = all(b >= a - 0.005 for a, b in zip(Os, Os[1:]))
    res["O_decroissances"] = [(levels[i], levels[i + 1], Os[i], Os[i + 1]) for i in range(len(Os) - 1) if Os[i + 1] < Os[i] - 0.005]
    return res


def table(res):
    out = ["| n | ép. | O (masses) | O brut | O cible | L | emprise | aire t² | +pièce t² | IoU préc. | IoU impair préc. | IoU n1 | V | dépass. | L p50 (cible) | p95 | sat | lueur jour (part, 8×8) | halo max |",
           "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in res["lignes"]:
        ph = r["photometrie"]
        lj = r.get("lumiere_jour") or {}
        ha = r.get("halo") or {}
        out.append("| %d | %d | %.2f | %.2f | %.2f | %.2f | %.0f %% | %.2f | %s | %s | %s | %.2f | %.0f %% | %d | %s (%d) | %s | %s | %s | %s |" % (
            r["n"], r["epoque"], r["O"], r["O_brut"], r["O_cible"], r["L"], 100 * r["emprise_couverte"], r["aire_t2"],
            "%.2f" % r["aire_ajoutee_t2"] if "aire_ajoutee_t2" in r else "—",
            "%.2f" % r["iou_prec"] if "iou_prec" in r else "—",
            "%.2f" % r["iou_impair_prec"] if "iou_impair_prec" in r else "—",
            r["iou_n1"], 100 * r["vide_V"], r["depassements"], ph.get("L_p50", "—"), r["palette_cible_L50"],
            ph.get("L_p95", "—"), ph.get("sat", "—"),
            ("%.1f %%, %s" % (100 * lj["part"], "oui" if lj["carre_8px"] else "non")) if lj else "—",
            ha.get("max", "—") if ha else "—"))
    if "D1_3" in res:
        for k, v in sorted(res["D1_3"].items()):
            out.append("")
            out.append("D1-3 (%s contre n01) : IoU = %.3f (seuil < 0,50, cible ≤ 0,45) ; IoU normalisée en échelle = %.3f "
                       "(k = %.2f ; seuil proposé ≤ 0,75)" % (k, v["iou"], v["iou_normalisee"], v["k"]))
    out.append("")
    out.append("O non décroissant sur les 30 niveaux : %s %s" % ("oui" if res["O_monotone"] else "NON", res["O_decroissances"] or ""))
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="", help="'' (aperçus) ou 'quick'")
    ap.add_argument("--levels", default="1-30")
    ap.add_argument("--no-write", action="store_true")
    a = ap.parse_args()
    src = os.path.join(CP.OUT, a.src) if a.src else CP.OUT
    lo, hi = (int(x) for x in a.levels.split("-"))
    levels = list(range(lo, hi + 1))
    if 1 not in levels:
        levels = [1] + levels
    res = measure(src, levels)
    res["source"] = os.path.relpath(src, MOD_ROOT).replace("\\", "/")
    txt = table(res)
    print(txt)
    if not a.no_write:
        os.makedirs(DST, exist_ok=True)
        with open(os.path.join(DST, "mesures_d1.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(res, f, indent=1, ensure_ascii=False, sort_keys=True)
        with open(os.path.join(DST, "mesures_d1.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.write("Mesures D1 du four (indicateurs automatiques ; protocole : tools/render/pieces/levels/furnace/measure_d1.py)\n")
            f.write("Source : %s\n\n" % res["source"])
            f.write(txt + "\n")


if __name__ == "__main__":
    main()
