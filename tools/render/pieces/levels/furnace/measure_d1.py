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
  nombre de dépassements (pics du profil haut, ouverture de 4 px seulement pour garder flèches et
  pointes, proéminence ≥ 0,10 tuile : indicatif) ;
- D1-3 amendé : IoU(niveau 1, dernier niveau) < 0,50 (cible ≤ 0,45) ET IoU normalisée en échelle =
  max sur k ∈ [0,50 ; 3,00] (pas 0,01) de IoU(niveau 1 agrandi de k autour de l'origine, dernier niveau)
  (homothétie de docs/epoques/mesures/measure.py) ; seuil proposé 0,75 ; une seule pose pour le four ;
- vide V = |M1 \\ M(n)| / |M1| (bible §4 : ≥ 5 % à l'époque 10 … ≥ 30 % à l'époque 15) ;
- photométrie du corps (sRGB, comme la bible §1.5) hors zones émissives (lueur ≥ 0,10) : luminance
  p05/p50/p95 (sur 255), saturation moyenne ;
- lumière de jour (D2-1) : zones où la lueur (draw_as_glow, additive) porte la luminance du jour à au moins
  la médiane du corps + 80/255 ; part émissive du corps ; présence d'un carré plein de 8 × 8 px HR ;
- halo de nuit (D2-3) : maximum et étendue de la couche halo.
Ajouts de la correction V3 (vérification adverse) :
- dépassements : un plateau ne compte qu'une fois (défaut corrigé, voir peaks) ; fourchette de l'ère (§1.2)
  vérifiée et écrite au bilan, échec compris ;
- lueur en deux couches (glow : feu de marche ; glowdeco : décor) ; couleur émissive COMPOSÉE (couche
  principale + lueurs) : teinte médiane par classe et écart à la cible (feu : couleur de bouche de l'époque ;
  décor : couleur d'époque de la bible §1.5), part de pixels saturés à 255 sur deux canaux ;
- part émissive comparée à la courbe proposée par la bible §1.6 (1 % ép. 3 … 12-15 % ép. 15) ;
- halo : étendue (alpha > 0,05, tuile²) et monotonie sur les niveaux 3 à 30 (D2-3) ;
- ancrage : bas du masque, bords ouest et est, couverture de la bande y ∈ [0,5 ; 1] de l'emprise ;
- D1-3 : trois variantes de l'IoU normalisée (homothétie centrée sur l'origine ; centrée sur le pied
  (0 ; +1) ; avec en plus une translation libre jusqu'à ±1 tuile), pour l'étalonnage du seuil de Q13.
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
import importlib.util as _ilu  # noqa: E402
_spec = _ilu.spec_from_file_location("furnace_meta", os.path.join(HERE, "furnace_levels.py"))
furnace_meta = _ilu.module_from_spec(_spec)
_spec.loader.exec_module(furnace_meta)

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
        self.src = src
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
        # proéminence : descente minimale nécessaire pour atteindre un point plus haut. Correction V3 : un
        # PLATEAU ne compte qu'une fois (à droite, un point de même hauteur vaut « plus haut ») ; l'ancien
        # calcul comptait un pic tous les 10 px d'un sommet plat (n3 : 3 « pics » sur le seul couronnement
        # de la cheminée ; même défaut dans le compte du vérificateur, identique au mien)
        left = hs[:x][::-1]
        right = hs[x + 1:]
        def col(seq, ties):
            mn = hs[x]
            for v in seq:
                mn = min(mn, v)
                if v > hs[x] + 1e-9 or (ties and v >= hs[x] - 1e-9):
                    return mn
            return mn  # bord : on descend jusqu'au minimum du côté
        p = hs[x] - max(col(left, False), col(right, True))
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


def glow_sum(lv):
    """Lueurs additives (feu de marche + décor), prémultipliées, et alpha maximal."""
    gs = [lv.layers[k] for k in ("glow", "glowdeco") if k in lv.layers]
    if not gs:
        return None, None
    add = sum(g[..., :3] * g[..., 3:4] for g in gs)
    amax = np.max(np.stack([g[..., 3] for g in gs]), 0)
    return add, amax


def hue_deg(rgb):
    r, g, b = [float(x) for x in rgb]
    mx, mn = max(r, g, b), min(r, g, b)
    if mx - mn < 1e-6:
        return 0.0
    if mx == r:
        h = 60 * (((g - b) / (mx - mn)) % 6)
    elif mx == g:
        h = 60 * ((b - r) / (mx - mn) + 2)
    else:
        h = 60 * ((r - g) / (mx - mn) + 4)
    return h % 360


def hue_gap(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


# part émissive proposée par la bible §1.6 (❔) : 1 % (ép. 3), 3 % (5), 5 % (7), 7 % (10), 10 % (13), 12-15 % (15)
PART_BIBLE = {3: 0.01, 5: 0.03, 7: 0.05, 10: 0.07, 13: 0.10, 15: 0.135}


def part_bible(e):
    ks = sorted(PART_BIBLE)
    if e < ks[0]:
        return 0.0
    for a, b in zip(ks, ks[1:]):
        if a <= e <= b:
            return PART_BIBLE[a] + (PART_BIBLE[b] - PART_BIBLE[a]) * (e - a) / (b - a)
    return PART_BIBLE[ks[-1]]


def emissive(lv, ph):
    add, amax = glow_sum(lv)
    if add is None or not ph:
        return {"zone_px": 0, "part": 0.0, "carre_8px": False}
    main = lv.layers["main"]
    pm = main[..., :3] * main[..., 3:4]                # composé sur noir
    day = np.clip(pm + add, 0, 1)
    L = day @ LUMA * 255
    zone = (amax >= 0.10) & (L >= ph["L_p50"] + 80) & (main[..., 3] >= 0.5)
    n_body = lv.body.sum()
    e = PRM.epoch_of(lv.n)
    out = {"zone_px": int(zone.sum()), "part": round(float(zone.sum() / max(1, n_body)), 4),
           "carre_8px": square_inside(zone, 8), "part_bible": round(part_bible(e), 4)}
    # couleur composée (jour, en marche) : couche principale (émetteurs éteints) + lueurs ; chaque pixel lumineux
    # (alpha de sa couche ≥ 0,5) est rapporté à la cible de teinte la plus proche parmi les couleurs émissives
    # déclarées de l'époque (furnace_levels.EMIT_TARGETS) ; par cible : RGB médian, écart de teinte, part de pixels
    # saturés à 255 sur deux canaux
    tg = furnace_meta.EMIT_TARGETS.get(e, [])
    th = np.array([hue_deg(PRM.hex_rgb(t)) for t in tg]) if tg else None
    for key in ("glow", "glowdeco"):
        g = lv.layers.get(key)
        if g is None or th is None:
            continue
        z = (g[..., 3] >= 0.5) & (main[..., 3] >= 0.5)
        if z.sum() < 16:
            continue
        c = day[z] * 255
        mx, mn = c.max(1), c.min(1)
        d = np.maximum(mx - mn, 1e-6)
        r_, g_, b_ = c[:, 0], c[:, 1], c[:, 2]
        h = np.where(mx == r_, 60 * (((g_ - b_) / d) % 6), np.where(mx == g_, 60 * ((b_ - r_) / d + 2), 60 * ((r_ - g_) / d + 4))) % 360
        gap = np.abs(h[:, None] - th[None, :]) % 360
        gap = np.minimum(gap, 360 - gap)
        near = gap.argmin(1)
        res = []
        for i, t in enumerate(tg):
            sel = near == i
            if sel.sum() < 30:
                continue
            med = np.median(c[sel], 0)
            hm = hue_deg(med)
            res.append({"cible": t, "px": int(sel.sum()), "rgb_median": [int(round(x)) for x in med], "teinte": round(hm, 1),
                        "ecart_deg": round(hue_gap(hm, th[i]), 1),
                        "part_2canaux_255": round(float(((c[sel] >= 250).sum(1) >= 2).mean()), 3)})
        out["couleur_" + key] = res
    return out


def halo(lv):
    li = lv.layers.get("light")
    if li is None:
        return None
    s = lv.spec["layers"]["light"]
    # étendue sur l'image ENTIÈRE de la couche (la toile commune peut la couper)
    full = load_png(os.path.join(lv.src, "n%02d" % lv.n, s["filename"]))
    return {"max": round(float(li[..., 3].max()), 3), "largeur_t": round(s["width"] / PPT, 2),
            "hauteur_t": round(s["height"] / PPT, 2), "etendue_t2": round(float((full[..., 3] > 0.05).sum() / TILE2), 2),
            "S_N": round(PRM.halo_intensity(lv.n)[1], 2)}


def scaled_iou_variants(m1, mn):
    """IoU normalisée en échelle, trois variantes (étalonnage du seuil de Q13) :
    origine : homothétie de centre l'origine (définition de la bible) ;
    pied : homothétie de centre le milieu du bord sud de l'emprise (0 ; +1) ;
    translation : homothétie de centre le pied, plus une translation libre jusqu'à ±1 tuile (pas de 1 px),
    calculée par corrélation (FFT)."""
    out = {}
    si, k = scaled_iou(m1, mn)
    out["origine"] = {"iou": round(si, 3), "k": round(k, 2)}
    yy, xx = np.mgrid[0:H, 0:W]
    fy = OY + PPT
    best, bk = 0.0, 1.0
    scs = {}
    for k in np.arange(0.50, 2.0001, 0.01):
        sx = np.floor(OX + (xx + 0.5 - OX) / k).astype(np.int64)
        sy = np.floor(fy + (yy + 0.5 - fy) / k).astype(np.int64)
        ok = (sx >= 0) & (sx < W) & (sy >= 0) & (sy < H)
        sc = np.zeros((H, W), bool)
        sc[ok] = m1[sy[ok], sx[ok]]
        v = iou(sc, mn)
        scs[round(float(k), 2)] = sc
        if v > best:
            best, bk = v, float(k)
    out["pied"] = {"iou": round(best, 3), "k": round(bk, 2)}
    P = PPT
    Fm = np.fft.rfft2(np.pad(mn.astype(np.float64), P))
    nn = float(mn.sum())
    bt = (0.0, 1.0, 0, 0)
    for k, sc in scs.items():
        ns = float(sc.sum())
        if ns == 0:
            continue
        Fs = np.fft.rfft2(np.pad(sc.astype(np.float64), P))
        corr = np.fft.irfft2(Fm * np.conj(Fs), s=(H + 2 * P, W + 2 * P))
        # corr[dy, dx] = somme mn(y + dy, x + dx) · sc(y, x) ; translations |dx|, |dy| ≤ 64 px
        sub = np.concatenate([corr[-P:, :], corr[:P + 1, :]], 0)
        sub = np.concatenate([sub[:, -P:], sub[:, :P + 1]], 1)
        inter = np.round(sub)
        val = inter / np.maximum(1.0, ns + nn - inter)
        j = np.unravel_index(np.argmax(val), val.shape)
        if val[j] > bt[0]:
            bt = (float(val[j]), k, int(j[1]) - P, int(j[0]) - P)
    out["translation"] = {"iou": round(bt[0], 3), "k": round(bt[1], 2), "dx_px": bt[2], "dy_px": bt[3]}
    return out


RANGE_ERE = {"I": (1, 2), "II": (2, 3), "III": (3, 4), "IV": (4, 5), "V": (5, 6)}


def measure(src, levels):
    lv = {n: Level(n, src) for n in levels}
    m1 = lv[1].mask
    rows = {}
    for n in levels:
        L_ = lv[n]
        mass = h_open(L_.mask, 10)
        bb, bbr = bbox(mass), bbox(L_.mask)
        fp = L_.mask[OY - PPT:OY + PPT, OX - PPT:OX + PPT]
        _a, amax = glow_sum(L_)
        emis = (amax >= 0.10) if amax is not None else np.zeros_like(L_.body)
        ph = photometry(L_.rgb, L_.body & ~emis)
        r = {"n": n, "epoque": PRM.epoch_of(n), "pair": n % 2 == 0,
             "aire_t2": round(L_.mask.sum() / TILE2, 3),
             "O": round(-bb["top"] - 1.0, 3), "O_brut": round(-bbr["top"] - 1.0, 3), "O_cible": round(PRM.o_target(n), 3),
             "L": round(bb["right"] - bb["left"], 3), "boite": {k: round(v, 3) for k, v in bb.items()},
             "emprise_couverte": round(float(fp.mean()), 3),
             "iou_n1": round(iou(m1, L_.mask), 3),
             "vide_V": round(float((m1 & ~L_.mask).sum() / m1.sum()), 3),
             "photometrie": ph, "palette_cible_L50": PRM.PALETTE[PRM.epoch_of(n)]["L50"]}
        r["depassements"], r["pics_x"] = peaks(h_open(L_.mask, 4))
        rg = RANGE_ERE[PRM.EPOCHS[PRM.epoch_of(n)]["ere"]]
        r["fourchette_ere"] = list(rg)
        r["depassements_ok"] = rg[0] <= r["depassements"] <= rg[1]
        r["bas_masque"] = round(bbr["bottom"], 3)
        r["bord_ouest"], r["bord_est"] = round(bbr["left"], 3), round(bbr["right"], 3)
        band = L_.mask[OY + PPT // 2:OY + PPT, OX - PPT:OX + PPT]
        r["bande_sud_couverte"] = round(float(band.mean()), 3)
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
            var = scaled_iou_variants(m1, lv[n].mask)
            d13["n%02d" % n] = {"iou": rows[n]["iou_n1"], "iou_normalisee": var["origine"]["iou"], "k": var["origine"]["k"],
                                "variantes": var}
        res["D1_3"] = d13
    # halo : étendue monotone (D2-3)
    hx = [(n, rows[n]["halo"]["etendue_t2"]) for n in levels if rows[n].get("halo")]
    res["halo_etendue_monotone"] = all(b[1] >= a[1] - 0.01 for a, b in zip(hx, hx[1:]))
    res["halo_etendue_baisses"] = [(a[0], b[0], a[1], b[1]) for a, b in zip(hx, hx[1:]) if b[1] < a[1] - 0.01]
    # monotonie de O sur les 30 niveaux
    Os = [rows[n]["O"] for n in levels]
    res["O_monotone"] = all(b >= a - 0.005 for a, b in zip(Os, Os[1:]))
    res["O_decroissances"] = [(levels[i], levels[i + 1], Os[i], Os[i + 1]) for i in range(len(Os) - 1) if Os[i + 1] < Os[i] - 0.005]
    return res


def table(res):
    out = ["| n | ép. | O (masses) | O brut | O cible | L | emprise | aire t² | +pièce t² | IoU préc. | IoU impair préc. | IoU n1 | V | dépass. (ère) | bas | ouest / est | L p50 (cible) | p95 | sat | lueur jour (part, bible, 8×8) | couleur composée du feu (cible : RGB écart) | couleur composée du décor | halo max, étendue t² |",
           "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]

    def col(lj, key):
        cs = lj.get("couleur_" + key)
        if not cs:
            return "—"
        return " ; ".join("%s : (%d,%d,%d) %s°%s" % (c["cible"], c["rgb_median"][0], c["rgb_median"][1], c["rgb_median"][2],
                                                     c["ecart_deg"], ", 2 canaux à 255 : %.0f %%" % (100 * c["part_2canaux_255"])
                                                     if c["part_2canaux_255"] > 0.05 else "") for c in cs)
    for r in res["lignes"]:
        ph = r["photometrie"]
        lj = r.get("lumiere_jour") or {}
        ha = r.get("halo") or {}
        out.append("| %d | %d | %.2f | %.2f | %.2f | %.2f | %.0f %% | %.2f | %s | %s | %s | %.2f | %.0f %% | %d %s(%d-%d) | %+.2f | %+.2f / %+.2f | %s (%d) | %s | %s | %s | %s | %s | %s |" % (
            r["n"], r["epoque"], r["O"], r["O_brut"], r["O_cible"], r["L"], 100 * r["emprise_couverte"], r["aire_t2"],
            "%.2f" % r["aire_ajoutee_t2"] if "aire_ajoutee_t2" in r else "—",
            "%.2f" % r["iou_prec"] if "iou_prec" in r else "—",
            "%.2f" % r["iou_impair_prec"] if "iou_impair_prec" in r else "—",
            r["iou_n1"], 100 * r["vide_V"], r["depassements"], "" if r["depassements_ok"] or r["pair"] else "HORS ",
            r["fourchette_ere"][0], r["fourchette_ere"][1], r["bas_masque"], r["bord_ouest"], r["bord_est"],
            ph.get("L_p50", "—"), r["palette_cible_L50"], ph.get("L_p95", "—"), ph.get("sat", "—"),
            ("%.1f %%, %.1f %%, %s" % (100 * lj["part"], 100 * lj.get("part_bible", 0), "oui" if lj["carre_8px"] else "non"))
            if lj else "—", col(lj, "glow"), col(lj, "glowdeco"),
            ("%s, %s" % (ha.get("max"), ha.get("etendue_t2"))) if ha else "—"))
    out.append("")
    out.append("Bilan des indicateurs (aucun n'est un verdict : seul le Directeur Créatif valide un design)")
    odd = [r for r in res["lignes"] if not r["pair"]]
    hors = ["n%d (%d, fourchette %d-%d)" % (r["n"], r["depassements"], r["fourchette_ere"][0], r["fourchette_ere"][1])
            for r in odd if not r["depassements_ok"]]
    out.append("- D1-2, dépassements des niveaux impairs dans la fourchette de l'ère : %s" %
               ("oui, 15 sur 15" if not hors else "NON, hors fourchette : " + ", ".join(hors)))
    ious = [r.get("iou_impair_prec") for r in odd if r.get("iou_impair_prec") is not None]
    out.append("- D1-2, IoU entre époques consécutives : max %.2f (seuil 0,85) ; O non décroissant sur les 30 niveaux : %s %s" % (
        max(ious), "oui" if res["O_monotone"] else "NON", res["O_decroissances"] or ""))
    steps = [(odd[i + 1]["n"], round(odd[i + 1]["O"] - odd[i]["O"], 3)) for i in range(len(odd) - 1)]
    small = [x for x in steps if x[1] < 0.03 - 1e-9]
    out.append("- pas de O entre époques (≥ 0,03 visé) : %s" % ("oui (min %.2f)" % min(x[1] for x in steps) if not small
                                                            else "NON : " + ", ".join("n%d +%.2f" % x for x in small)))
    ev = [r for r in res["lignes"] if r["pair"] and r["n"] >= 2]
    low = [r["n"] for r in ev if r.get("aire_ajoutee_t2", 0) < 0.10]
    out.append("- D1-1, pièce paire ≥ 0,10 t² hors du masque impair : %s (min %.2f t²)" % (
        "oui" if not low else "NON : " + str(low), min(r.get("aire_ajoutee_t2", 0) for r in ev)))
    west = [(r["n"], r["bord_ouest"]) for r in res["lignes"] if r["n"] >= 2 and r["bord_ouest"] < -1.10 - 1e-9]
    east = [(r["n"], r["bord_est"]) for r in res["lignes"] if r["n"] >= 2 and r["bord_est"] > 1.10 + 1e-9]
    out.append("- débord latéral ≤ 1,10 de chaque côté : %s" % ("oui" if not west and not east else "NON : %s %s" % (west, east)))
    bas = [(r["n"], r["bas_masque"]) for r in res["lignes"] if r["n"] >= 3 and r["bas_masque"] < 0.75]
    out.append("- ancrage, bas du masque ≥ +0,75 (vanilla +1,02) : %s" % ("oui" if not bas else "NON : %s" % bas))
    hues = []
    for r in res["lignes"]:
        lj = r.get("lumiere_jour") or {}
        for key in ("glow", "glowdeco"):
            for c in lj.get("couleur_" + key) or []:
                if c["ecart_deg"] > 15 or c["part_2canaux_255"] > 0.05:
                    hues.append("n%d %s %s %s° (2 canaux à 255 : %.0f %%)" % (r["n"], "feu" if key == "glow" else "décor",
                                                                            c["cible"], c["ecart_deg"], 100 * c["part_2canaux_255"]))
    out.append("- couleur émissive composée à moins de 15° de sa cible, sans saturation de deux canaux : %s" % (
        "oui" if not hues else "NON : " + " ; ".join(hues)))
    parts = [(r["n"], r["lumiere_jour"]["part"], r["lumiere_jour"].get("part_bible", 0)) for r in res["lignes"]
             if r.get("lumiere_jour") and r["n"] >= 5]
    far = ["n%d %.0f %% (bible %.0f %%)" % (n, 100 * a, 100 * b) for n, a, b in parts if b > 0 and (a > 2 * b or a < 0.5 * b)]
    out.append("- part émissive dans un facteur 2 de la courbe proposée par la bible §1.6 (❔) : %s" % (
        "oui" if not far else "ÉCART : " + ", ".join(far)))
    out.append("- D2-3, étendue du halo (alpha > 0,05) non décroissante, niveaux 3 à 30 : %s %s" % (
        "oui" if res.get("halo_etendue_monotone") else "NON", res.get("halo_etendue_baisses") or ""))
    if "D1_3" in res:
        for k, v in sorted(res["D1_3"].items()):
            var = v.get("variantes", {})
            out.append("- D1-3 (%s contre n01) : IoU = %.3f (seuil < 0,50, cible ≤ 0,45) ; IoU normalisée en échelle = %.3f "
                       "(k = %.2f, centre l'origine ; seuil proposé ≤ 0,75) ; variantes pour l'étalonnage : centre au pied %.3f "
                       "(k %.2f), pied + translation libre ±1 tuile %.3f (k %.2f, dx %d px, dy %d px)" % (
                           k, v["iou"], v["iou_normalisee"], v["k"], var["pied"]["iou"], var["pied"]["k"],
                           var["translation"]["iou"], var["translation"]["k"], var["translation"]["dx_px"],
                           var["translation"]["dy_px"]))
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
