"""Mesures D1, D2 et palette des niveaux de la foreuse électrique (lot V3, phase 1), hors moteur.

    python -P tools/render/pieces/levels/drill/measure_d1.py [--quick] [--out <fichier .json>]

Protocole (bible §1.4, OBJECTIFS D1, amendement Q13), poses de référence N, E, S, O, image 0 :
- masque = alpha >= 0,5 de la couche PRINCIPALE seule (ni ombre, ni lueur, ni halo, ni integration_patch :
  aucune couche plate au sol) ; 64 px par tuile, même origine (position de l'entité) ;
- masses = masque après ouverture morphologique par un carré de 10 px (0,156 tuile) : les tiges fines
  (< 0,15 tuile : mâts, antennes, haubans, garde-corps) ne comptent ni dans O ni dans L ;
- O = dépassement du sommet des masses au-dessus du bord haut de l'emprise (y = -1,5) ; O_tige = idem
  avec le masque complet ; L = largeur des masses (bornes x0, x1 publiées) ; aire = aire du masque ;
- niveau pair : aire ajoutée = |M(pair) \\ M(impair)| (cible >= 0,10 t²) ; IoU(pair, impair) ;
- niveau impair : IoU avec le niveau pair précédent (<= 0,85) et avec l'impair précédent (époques
  consécutives, <= 0,85) ; V = part du masque du niveau 1 laissée vide (bible §4) ;
- D1-2 (indicateur ajouté le 22/10, vérification adverse) : « événements de silhouette » = pics du profil
  haut des masses (pose N) de proéminence >= 0,15 tuile, comparés à la fourchette de l'ère (bible §1.2) ;
- D1-3 : IoU(niveau 1, niveau 30) < 0,50 (cible <= 0,45), et IoU normalisée en échelle = max sur k
  (0,50 à 3,00, pas 0,01) de IoU(niveau 1 agrandi de k autour de la position de l'entité, niveau 30)
  (proposition <= 0,75) ; maximum sur les 4 poses ; publiée aussi en version adverse (échelle ET
  translation libres, protocole de la vérification adverse du 22/10), à titre d'indicateur ;
- enveloppe (bible §4, contrôlée depuis le 22/10) : L (pose N, masses) = cible du rang ± 0,05 ; aire du
  masque (pose N) >= aire du niveau 1 (4,99 t² : jamais plus léger que le vanilla), cible indicative
  A1 × (1 + 0,25·(e-1)/14) ;
- photométrie de la couche principale (pixels d'alpha >= 0,99 hors émissifs, sRGB), DANS LES 4 POSES :
  luminance médiane (cible de l'époque ± 10, dans [40, 110]), p95 (<= 240), saturation moyenne (<= 0,45) ;
- D2-1 (lueur de jour, époques 3+), DANS LES 4 POSES, sur la composition additive corps + lueur (sol
  (150, 100, 60)) : « zone chaude » = lueur d'alpha >= 0,5 ET luminance composée >= médiane du corps + 80 ;
  il faut un carré de 8 × 8 px hr entièrement chaud (ouverture 8 × 8 non vide) ; plus grande zone
  connexe (8-voisinage) publiée ;
- goulotte en pose S (zone |x| <= 0,30, y >= 0,90 tuile, corps hors émissifs) : p95 <= 240 ;
- ombre (F58, correction du 22/10) : part de l'INTÉRIEUR de l'ombre (alpha >= 0,25 érodé de 3 px, hors
  du corps) dont l'alpha est < 0,9 : <= 2 % dans chaque pose (vanilla : 1 %) ;
- halo de nuit (D2-3) : énergie de la LightDefinition du niveau (levels_io.level_halo), strictement
  croissante de L01 à L30 ; énergie des lueurs (Σ luminance × alpha des couches glow et light) publiée.
Sortie : tableaux texte et JSON (par défaut tools/render/out/levels/drill/mesures_d1.json).
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import levels_io as IO  # noqa: E402

LUMA = np.array([0.2126, 0.7152, 0.0722])
GROUND = np.array([150, 100, 60]) / 255.0
# bible §4 (foreuse) : O / L / V par rang d'époque ; §1.5 : luminance médiane cible du corps
O_RANK = [0.38, 0.47, 0.55, 0.64, 0.73, 0.82, 0.90, 0.99, 1.08, 1.16, 1.25, 1.34, 1.43, 1.51, 1.60]
L_RANK = [2.94, 2.96, 2.98, 3.00, 3.01, 3.03, 3.05, 3.07, 3.09, 3.11, 3.13, 3.14, 3.16, 3.18, 3.20]
V_RANK = [0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 7, 10, 13, 17, 20]
LUM_TARGET = [50, 52, 58, 60, 42, 64, 55, 60, 56, 82, 100, 60, 92, 88, 108]
# bible §1.2 : événements de silhouette par ère (époques 1-3, 4-6, 7-9, 10-12, 13-15)
EVENTS_ERA = [(1, 2), (2, 3), (3, 4), (4, 5), (5, 6)]
O_CEIL = 1.60
L_TOL = 0.05
OPEN_PX = 10
SHADOW_LOW_MAX = 0.02


def box_all(a, kx, ky=None):
    """Vrai au coin haut-gauche (y, x) si tout le rectangle ky × kx est dans a."""
    ky = ky or kx
    c = np.pad(a.astype(np.int32), ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    h, w = a.shape
    s = c[ky:, kx:] - c[:-ky, kx:] - c[ky:, :-kx] + c[:-ky, :-kx]
    out = np.zeros(a.shape, bool)
    out[:h - ky + 1, :w - kx + 1] = s == kx * ky
    return out


def opening(m, k=OPEN_PX):
    """Ouverture binaire par un carré k × k (érosion puis dilatation), par sommes cumulées."""
    er = box_all(m, k)
    c = np.pad(er.astype(np.int32), ((k, 0), (k, 0))).cumsum(0).cumsum(1)
    h, w = m.shape
    s = c[k:k + h, k:k + w] - c[0:h, k:k + w] - c[k:k + h, 0:w] + c[0:h, 0:w]
    return s > 0


def bbox(m):
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None
    ox, oy = IO.ORIGIN
    return ((xs.min() - ox) / 64.0, (xs.max() + 1 - ox) / 64.0, (ys.min() - oy) / 64.0, (ys.max() + 1 - oy) / 64.0)


def iou(a, b):
    u = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / u) if u else 0.0


def scaled(m, k):
    """Masque agrandi de k autour de l'origine (plus proche voisin, échantillonnage inverse)."""
    ox, oy = IO.ORIGIN
    yy, xx = np.mgrid[0:IO.H, 0:IO.W]
    sx = np.floor((xx + 0.5 - ox) / k + ox).astype(int)
    sy = np.floor((yy + 0.5 - oy) / k + oy).astype(int)
    ok = (sx >= 0) & (sx < IO.W) & (sy >= 0) & (sy < IO.H)
    out = np.zeros_like(m)
    out[ok] = m[sy[ok], sx[ok]]
    return out


def norm_iou(m1, m30):
    best, kb = 0.0, 1.0
    for k in np.arange(0.50, 3.0001, 0.01):
        v = iou(scaled(m1, k), m30)
        if v > best:
            best, kb = v, float(k)
    return best, kb


def norm_iou_adv(m1, m30):
    """Version adverse (vérification du 22/10) : échelle ET translation libres, grossier puis fin."""
    def sh(m, dx, dy):
        return np.roll(np.roll(m, dy, 0), dx, 1)
    best = (0.0, 1.0, 0, 0)
    for k in np.arange(0.50, 2.5001, 0.05):
        sm = scaled(m1, k)
        for dx in range(-48, 49, 8):
            for dy in range(-96, 49, 8):
                v = iou(sh(sm, dx, dy), m30)
                if v > best[0]:
                    best = (v, float(k), dx, dy)
    v0, k0, dx0, dy0 = best
    for k in np.arange(k0 - 0.05, k0 + 0.0501, 0.01):
        sm = scaled(m1, k)
        for dx in range(dx0 - 8, dx0 + 9, 2):
            for dy in range(dy0 - 8, dy0 + 9, 2):
                v = iou(sh(sm, dx, dy), m30)
                if v > best[0]:
                    best = (v, float(k), dx, dy)
    return best


def components(m):
    """Tailles des composantes connexes (8-voisinage), sans scipy."""
    seen = np.zeros_like(m)
    sizes = []
    H, W = m.shape
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        if seen[y, x]:
            continue
        stack = [(y, x)]
        seen[y, x] = True
        n = 0
        while stack:
            cy, cx = stack.pop()
            n += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        sizes.append(n)
    return sizes


def lum(rgb):
    return (rgb[..., :3] @ LUMA) * 255


def photometry(main, glow, d):
    a = main[..., 3]
    m = a >= 0.99
    gpm = None
    if glow is not None:
        # corps = hors des zones émissives (bible §1.5 : règles de palette du CORPS ; les émissifs vivent
        # dans leurs couches). Aperçus rapides : pas de couche de lueur, émissifs comptés dans le corps.
        gpm = glow[..., :3] * glow[..., 3:4]
        m = m & (gpm.max(-1) < 0.05)
    rgb = main[..., :3]
    L = lum(rgb)
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    body50 = float(np.median(L[m]))
    out = {"lum_p50": body50, "lum_p95": float(np.percentile(L[m], 95)), "sat": float(sat[m].mean())}
    if d == "S":
        # goulotte devant (pose S) : zone |x| <= 0,30, y >= 0,90 tuile
        ox, oy = IO.ORIGIN
        zone = np.zeros_like(m)
        zone[oy + int(0.90 * 64):, ox - int(0.30 * 64):ox + int(0.30 * 64)] = True
        zm = m & zone
        if zm.sum() >= 20:
            out["chute_p50"] = float(np.median(L[zm]))
            out["chute_p95"] = float(np.percentile(L[zm], 95))
    if gpm is not None:
        gm = (gpm.max(-1) >= 0.25) & (a >= 0.5)
        out["glow_frac"] = float(gm.sum() / max(1, (a >= 0.5).sum()))
        comp = rgb * a[..., None] + GROUND * (1 - a[..., None])
        lc = lum(np.clip(comp + gpm, 0, 1))
        gz = glow[..., 3] >= 0.5
        hot = gz & (lc - body50 >= 80)
        sizes = components(hot) if hot.any() else []
        out["glow_zone_px"] = int(max(sizes)) if sizes else 0
        out["glow_sq8"] = bool(box_all(hot, 8).any()) if hot.any() else False
        out["glow_sq10"] = bool(box_all(hot, 10).any()) if hot.any() else False
        out["glow_contrast"] = float(np.median(lc[gz]) - body50) if gz.any() else None
    return out


def shadow_quality(sh, m):
    """Part de l'intérieur de l'ombre (alpha >= 0,25 érodé de 3 px, hors du corps) à alpha < 0,9."""
    if sh is None:
        return None, 0
    s = sh >= 0.25
    er = s.copy()
    for dy in (-3, 0, 3):
        for dx in (-3, 0, 3):
            er &= np.roll(np.roll(s, dy, 0), dx, 1)
    inn = er & ~m
    if not inn.any():
        return None, 0
    return float((sh[inn] < 0.9).mean()), int(inn.sum())


def light_energy(lay):
    """Σ luminance × alpha (tuiles²) des couches glow et light (alpha droit, couleur codée c / max)."""
    e = 0.0
    for k in ("glow", "light"):
        v = lay.get(k)
        if v is not None:
            e += float(((v[..., :3] @ LUMA) * v[..., 3]).sum() / 4096.0)
    return e


def events(ms):
    """Pics du profil haut des masses de proéminence >= 0,15 tuile (colonnes vides = creux profond)."""
    cols = ms.any(0)
    if not cols.any():
        return 0, []
    top = np.where(cols, ms.argmax(0), ms.shape[0])
    h = -(top - IO.ORIGIN[1]) / 64.0
    h = np.where(cols, h, h[cols].min() - 1.0)
    # plateaux réduits à un point
    xs, hs = [], []
    for x in range(len(h)):
        if xs and hs[-1] == h[x]:
            continue
        xs.append(x)
        hs.append(h[x])
    hs = np.array(hs)
    peaks = []
    for i in range(len(hs)):
        left = hs[i - 1] if i > 0 else -1e9
        right = hs[i + 1] if i + 1 < len(hs) else -1e9
        if not (hs[i] > left and hs[i] > right):
            continue
        # base gauche : minimum jusqu'au premier point plus haut (ou au bord)
        lm, j = hs[i], i - 1
        while j >= 0 and hs[j] <= hs[i]:
            lm = min(lm, hs[j])
            j -= 1
        lmin = lm if j >= 0 else hs[:i + 1].min()
        rm, j = hs[i], i + 1
        while j < len(hs) and hs[j] <= hs[i]:
            rm = min(rm, hs[j])
            j += 1
        rmin = rm if j < len(hs) else hs[i:].min()
        prom = hs[i] - max(lmin, rmin)
        if prom >= 0.15:
            peaks.append({"x": round((xs[i] - IO.ORIGIN[0]) / 64.0, 3), "h": round(float(hs[i]), 3),
                          "prom": round(float(prom), 3)})
    return len(peaks), peaks


def measure(spec, quick=False, levels=range(1, 31)):
    masks, res = {}, {"levels": {}, "quick": quick}
    for lvl in levels:
        for d in IO.DIRS:
            lay = IO.level_layers(spec, lvl, d, quick=quick)
            if lay is None or lay["main"] is None:
                continue
            m = lay["main"][..., 3] >= 0.5
            masks[(lvl, d)] = m
            ms = opening(m)
            bb, bbm = bbox(m), bbox(ms)
            r = {"area": float(m.sum() / 4096.0), "O": -bbm[2] - 1.5, "O_tige": -bb[2] - 1.5, "L": bbm[1] - bbm[0],
                 "Lx": [bbm[0], bbm[1]], "x": [bb[0], bb[1]], "y": [bb[2], bb[3]],
                 "cover": float(m[IO.ORIGIN[1] - 96:IO.ORIGIN[1] + 96, IO.ORIGIN[0] - 96:IO.ORIGIN[0] + 96].sum() / (192 * 192)),
                 "below": bb[3] - 1.5, "side_l": -1.5 - bb[0], "side_r": bb[1] - 1.5}
            r.update(photometry(lay["main"], lay["glow"], d))
            if not quick:
                low, n_in = shadow_quality(lay["shadow"], m)
                r["shadow_low"] = low
                r["shadow_inner_px"] = n_in
                r["light_energy"] = light_energy(lay)
            if d == "N" and lvl % 2 == 1:
                n, pk = events(ms)
                r["events"] = n
                r["events_peaks"] = pk
            res["levels"].setdefault("L%02d" % lvl, {})[d] = r
        h = IO.level_halo(lvl)
        if "L%02d" % lvl in res["levels"]:
            res["levels"]["L%02d" % lvl]["halo"] = h
    # relations entre niveaux
    for lvl in levels:
        key = "L%02d" % lvl
        if key not in res["levels"]:
            continue
        for d in IO.DIRS:
            if (lvl, d) not in masks:
                continue
            r = res["levels"][key][d]
            m = masks[(lvl, d)]
            if lvl > 1 and (lvl - 1, d) in masks:
                prev = masks[(lvl - 1, d)]
                r["iou_prev"] = iou(m, prev)
                if lvl % 2 == 0:
                    r["added"] = float(np.logical_and(m, ~prev).sum() / 4096.0)
                    r["removed"] = float(np.logical_and(prev, ~m).sum() / 4096.0)
            if lvl % 2 == 1 and lvl > 1 and (lvl - 2, d) in masks:
                r["iou_epoch_prev"] = iou(m, masks[(lvl - 2, d)])
            if lvl % 2 == 1 and (1, d) in masks:
                m1 = masks[(1, d)]
                r["V"] = float(np.logical_and(m1, ~m).sum() / max(1, m1.sum()))
            if (1, d) in masks:
                r["iou_L1"] = iou(m, masks[(1, d)])
    # D1-3
    d13 = {}
    for d in IO.DIRS:
        if (1, d) in masks and (30, d) in masks:
            nb, kb = norm_iou(masks[(1, d)], masks[(30, d)])
            d13[d] = {"iou": iou(masks[(1, d)], masks[(30, d)]), "iou_norm": nb, "k": kb}
            if not quick:
                va, ka, dxa, dya = norm_iou_adv(masks[(1, d)], masks[(30, d)])
                d13[d].update({"iou_norm_adv": va, "k_adv": ka, "dx_adv": dxa, "dy_adv": dya})
    res["d13"] = d13
    # matrice des IoU entre époques (niveaux impairs, max sur les poses)
    odd = [l for l in range(1, 31, 2) if all((l, d) in masks for d in IO.DIRS)]
    res["iou_epochs_max"] = {"L%02d-L%02d" % (a, b): max(iou(masks[(a, d)], masks[(b, d)]) for d in IO.DIRS)
                             for i, a in enumerate(odd) for b in odd[i + 1:]}
    return res


def _f(v, p=2):
    return "—" if v is None else ("%.*f" % (p, v))


def table(res):
    lines = ["GÉOMÉTRIE (pose N, sauf « max » / « min » = sur les 4 poses)", ""]
    hdr = ("Niv", "Ép", "O N", "O cible", "O max", "O tige", "L N", "L cible", "x0..x1 N", "aire N", "ajout min",
           "IoU préc max", "IoU ép. max", "IoU L1 N", "V min", "évén.")
    lines.append(" | ".join(hdr))
    for key in sorted(k for k in res["levels"]):
        lvl = int(key[1:])
        e = (lvl + 1) // 2
        rs = res["levels"][key]
        ds = [d for d in IO.DIRS if d in rs]
        rN = rs.get("N", rs[ds[0]])

        def mx(k, f=max):
            v = [rs[d][k] for d in ds if rs[d].get(k) is not None]
            return f(v) if v else None
        lines.append(" | ".join([
            key, str(e), _f(rN["O"]), _f(O_RANK[e - 1]), _f(mx("O")), _f(mx("O_tige")), _f(rN["L"]),
            _f(L_RANK[e - 1]), "%+.2f..%+.2f" % tuple(rN["Lx"]), _f(rN["area"]), _f(mx("added", min)),
            _f(mx("iou_prev")), _f(mx("iou_epoch_prev")), _f(rN.get("iou_L1")),
            _f(None if mx("V", min) is None else 100 * mx("V", min), 0),
            "—" if rN.get("events") is None else "%d (%d-%d)" % ((rN["events"],) + EVENTS_ERA[(e - 1) // 3])]))
    lines += ["", "PHOTOMÉTRIE ET LUMIÈRE PAR POSE (N / E / S / O)", ""]
    hdr = ("Niv", "lum cible", "lum p50", "p95 max", "sat max", "goul. S p95", "lueur %", "zone chaude px",
           "8×8", "contraste", "ombre <0,9 %", "halo E(N)", "lueurs E")
    lines.append(" | ".join(hdr))
    for key in sorted(k for k in res["levels"]):
        lvl = int(key[1:])
        e = (lvl + 1) // 2
        rs = res["levels"][key]
        ds = [d for d in IO.DIRS if d in rs]

        def per(k, p=0, mul=1.0):
            return "/".join(_f(None if rs[d].get(k) is None else rs[d][k] * mul, p) for d in ds)

        def mx(k, f=max):
            v = [rs[d][k] for d in ds if rs[d].get(k) is not None]
            return f(v) if v else None
        h = rs.get("halo")
        lines.append(" | ".join([
            key, str(LUM_TARGET[e - 1]), per("lum_p50"), _f(mx("lum_p95"), 0), _f(mx("sat")),
            _f(rs.get("S", {}).get("chute_p95"), 0), per("glow_frac", 1, 100), per("glow_zone_px"),
            "/".join(("oui" if rs[d].get("glow_sq8") else "non") if "glow_sq8" in rs[d] else "—" for d in ds),
            per("glow_contrast"), per("shadow_low", 1, 100), _f(h["energy_t2"] if h else 0.0, 3),
            _f(mx("light_energy"), 3)]))
    lines.append("")
    for d, v in sorted(res["d13"].items()):
        adv = ""
        if "iou_norm_adv" in v:
            adv = " ; version adverse (échelle et translation libres) = %.3f (k = %.2f, décalage %+d, %+d px)" % (
                v["iou_norm_adv"], v["k_adv"], v["dx_adv"], v["dy_adv"])
        lines.append("D1-3 %s : IoU(1, 30) = %.3f ; IoU normalisée = %.3f (k = %.2f)%s" % (
            d, v["iou"], v["iou_norm"], v["k"], adv))
    if res["d13"]:
        lines.append("D1-3 max sur les poses : IoU = %.3f ; IoU normalisée = %.3f" % (
            max(v["iou"] for v in res["d13"].values()), max(v["iou_norm"] for v in res["d13"].values())))
    if res.get("iou_epochs_max"):
        k, v = max(res["iou_epochs_max"].items(), key=lambda kv: kv[1])
        lines.append("IoU maximale entre deux époques quelconques (niveaux impairs, max des poses) : %.3f (%s)" % (v, k))
    lines.append("")
    lines += checks(res)
    return "\n".join(lines)


def checks(res):
    """Contrôles automatiques (indicateurs de la bible §1.4 ; ils aident le verdict, ne le remplacent pas)."""
    out = ["Contrôles (dans chacune des 4 poses, sauf mention) :"]
    lv = res["levels"]
    fails, warns = [], []
    quick = res.get("quick")

    def worst(key, k, f):
        v = [lv[key][d][k] for d in IO.DIRS if d in lv.get(key, {}) and lv[key][d].get(k) is not None]
        return f(v) if v else None
    # pièce paire >= 0,10 t² ajoutée, dans chaque pose
    for lvl in range(2, 31, 2):
        a = worst("L%02d" % lvl, "added", min)
        if a is not None and a < 0.10:
            fails.append("L%02d : pièce paire %.3f t² < 0,10" % (lvl, a))
    # niveau impair : IoU avec le pair précédent <= 0,85 ; avec l'impair précédent <= 0,85
    for lvl in range(3, 31, 2):
        for k, lab in (("iou_prev", "IoU avec le niveau pair précédent"), ("iou_epoch_prev", "IoU entre époques")):
            v = worst("L%02d" % lvl, k, max)
            if v is not None and v > 0.85:
                fails.append("L%02d : %s %.3f > 0,85" % (lvl, lab, v))
    # O : niveaux impairs jamais décroissants (pose N) ; tous les niveaux sous le plafond
    prev = None
    for lvl in range(1, 31, 2):
        key = "L%02d" % lvl
        if key not in lv or "N" not in lv[key]:
            continue
        o = lv[key]["N"]["O"]
        if prev is not None and o < prev[1] - 1.0 / 64:
            fails.append("%s : O (pose N) %.2f < %.2f (%s)" % (key, o, prev[1], prev[0]))
        prev = (key, o)
    for key in sorted(lv):
        o = worst(key, "O", max)
        if o is not None and o > O_CEIL + 1.0 / 64:
            fails.append("%s : O %.2f > plafond %.2f" % (key, o, O_CEIL))
    # enveloppe L (pose N, masses) et aire (pose N), niveaux impairs 3 à 29
    a1 = lv.get("L01", {}).get("N", {}).get("area")
    for lvl in range(3, 31, 2):
        r = lv.get("L%02d" % lvl, {}).get("N")
        if r is None:
            continue
        e = (lvl + 1) // 2
        if abs(r["L"] - L_RANK[e - 1]) > L_TOL + 1e-9:
            fails.append("L%02d : L (pose N, masses) %.2f hors de %.2f ± %.2f" % (lvl, r["L"], L_RANK[e - 1], L_TOL))
        if a1 is not None:
            if r["area"] < a1 - 1e-9:
                fails.append("L%02d : aire (pose N) %.2f t² < niveau 1 (%.2f)" % (lvl, r["area"], a1))
            elif r["area"] < a1 * (1 + 0.25 * (e - 1) / 14.0):
                warns.append("L%02d : aire (pose N) %.2f t² sous la cible indicative %.2f" % (
                    lvl, r["area"], a1 * (1 + 0.25 * (e - 1) / 14.0)))
        ev = r.get("events")
        if ev is not None:
            lo, hi = EVENTS_ERA[(e - 1) // 3]
            if not lo <= ev <= hi:
                warns.append("L%02d : %d événements de silhouette, fourchette de l'ère %d à %d (indicateur D1-2 ❔)" % (
                    lvl, ev, lo, hi))
    # emprise : rien ne dépasse de plus de 0,25 tuile sur les côtés (F42 : 0,10 à 0,25 permis) ; au sud,
    # pas plus que le vanilla (0,141 en pose S)
    for key in sorted(lv):
        for d in IO.DIRS:
            r = lv[key].get(d)
            if r is None or key == "L01":
                continue
            if max(r["side_l"], r["side_r"]) > 0.25 + 1.0 / 64:
                fails.append("%s %s : dépasse l'emprise de %.2f tuile sur le côté" % (key, d, max(r["side_l"], r["side_r"])))
            if r["below"] > 0.141 + 1.0 / 64:
                fails.append("%s %s : dépasse au sud de %.2f tuile (vanilla 0,14)" % (key, d, r["below"]))
    # palette (bible §1.5), 4 poses ; L01 et L02 portent le sprite vanilla (hors règle)
    for lvl in range(3, 31):
        e = (lvl + 1) // 2
        t = LUM_TARGET[e - 1]
        for d in IO.DIRS:
            r = lv.get("L%02d" % lvl, {}).get(d)
            if r is None:
                continue
            tag = "L%02d %s" % (lvl, d)
            if abs(r["lum_p50"] - t) > 10 or not 40 <= r["lum_p50"] <= 110:
                fails.append("%s : luminance médiane %.0f (cible %d ± 10, dans [40, 110])" % (tag, r["lum_p50"], t))
            if r["lum_p95"] > 240:
                fails.append("%s : luminance p95 %.0f > 240" % (tag, r["lum_p95"]))
            if r["sat"] > 0.45:
                fails.append("%s : saturation %.2f > 0,45" % (tag, r["sat"]))
            if r.get("chute_p95") is not None and r["chute_p95"] > 240:
                fails.append("%s : goulotte p95 %.0f > 240" % (tag, r["chute_p95"]))
            # D2-1 (rendus complets seulement) : un carré 8 × 8 px hr chaud dès l'époque 3
            if not quick and e >= 3 and not r.get("glow_sq8"):
                fails.append("%s : aucune lueur de jour de 8 × 8 px hr à +80 (zone chaude max %d px, contraste "
                             "médian %s) (D2-1)" % (tag, r.get("glow_zone_px", 0), _f(r.get("glow_contrast"), 0)))
    if not quick:
        # ombre : intérieur plein (F58)
        for key in sorted(lv):
            for d in IO.DIRS:
                r = lv[key].get(d)
                if r is None or r.get("shadow_low") is None:
                    continue
                if r["shadow_low"] > SHADOW_LOW_MAX:
                    fails.append("%s %s : %.1f %% de l'intérieur de l'ombre à alpha < 0,9 (> 2 %%)" % (
                        key, d, 100 * r["shadow_low"]))
        # halo de nuit strictement croissant
        prev = None
        for lvl in range(1, 31):
            key = "L%02d" % lvl
            if key not in lv:
                continue
            h = lv[key].get("halo")
            e_ = h["energy_t2"] if h else 0.0
            if prev is not None and e_ <= prev[1]:
                fails.append("%s : énergie du halo %.3f <= %.3f (%s)" % (key, e_, prev[1], prev[0]))
            prev = (key, e_)
    d13 = res.get("d13", {})
    if d13:
        mi = max(v["iou"] for v in d13.values())
        mn = max(v["iou_norm"] for v in d13.values())
        if mi >= 0.50:
            fails.append("D1-3 : IoU(1, 30) %.3f >= 0,50" % mi)
        elif mi > 0.45:
            warns.append("D1-3 IoU %.3f > cible 0,45" % mi)
        if mn > 0.75:
            fails.append("D1-3 : IoU normalisée %.3f > 0,75 (seuil proposé, à étalonner)" % mn)
        ma = [v["iou_norm_adv"] for v in d13.values() if "iou_norm_adv" in v]
        if ma and max(ma) > 0.75:
            warns.append("D1-3 : IoU normalisée adverse (échelle et translation) %.3f > 0,75" % max(ma))
    out += ["  ÉCHEC " + f for f in fails] if fails else ["  aucun échec"]
    out += ["  avertissement : " + w for w in warns]
    res["checks"] = fails
    res["warnings"] = warns
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--out", default=None)
    ap.add_argument("--levels", default=None, help="ex. 1,3,5 (défaut : 1 à 30)")
    a = ap.parse_args()
    spec = IO.load_spec()
    lv = range(1, 31) if not a.levels else sorted({int(x) for x in a.levels.split(",")} | {1})
    res = measure(spec, quick=a.quick, levels=lv)
    out = a.out or os.path.join(IO.OUT, "mesures_d1%s.json" % ("_quick" if a.quick else ""))
    txt = table(res)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1, sort_keys=True)
    with open(out[:-5] + ".txt", "w", encoding="utf-8", newline="\n") as f:
        f.write(txt + "\n")
    if not a.quick and not a.levels and not a.out:
        # copie versionnée à côté des planches (tools/render/out est ignoré par git)
        dst = os.path.join(os.path.dirname(os.path.dirname(IO.RENDER)), "docs", "epoques", "planches", "drill",
                           "mesures_d1.txt")
        with open(dst, "w", encoding="utf-8", newline="\n") as f:
            f.write(txt + "\n")
    print(txt)


if __name__ == "__main__":
    main()
