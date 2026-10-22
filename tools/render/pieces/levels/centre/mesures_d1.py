"""Mesures D1 et D2 du centre de commandement, 15 niveaux (lot V3-a, phase 1). Python système (numpy + Pillow).

    python -P tools/render/pieces/levels/centre/mesures_d1.py [--out <json>] [--md]

Lit les aperçus de tools/render/out/levels/centre/nNN/ (render_centre.py) :
  mask-sil.npz  : masque D1-3 amendé (alpha brut du rendu principal >= 0,5, SANS couches plates au sol :
                  plate-forme, dalle, aire, émetteur ; sans liseré de contact) ;
  mask-mass.npz : idem, sans les tiges fines (mâts, antennes, drapeaux, garde-corps) : mesure de O et L ;
  mask-full.npz : alpha >= 0,5 de la couche principale livrée (toutes couches, liseré compris) ;
  hr-centre-nNN-main.png / -glow.png / -light.png : photométrie, lueur de jour, lumière de nuit.
Repère : tuiles de jeu, origine = position de l'entité, y vers le bas (bible §1.4). 64 px par tuile.

Indicateurs (bible §1.4 à §1.6, OBJECTIFS D1 et D2 ; le centre n'a pas de niveau pair) :
  - O, O_tige, L, aire, couverture de l'emprise, IoU avec le niveau précédent (<= 0,85), vide V ;
  - D1-3 : IoU(1, 15) (< 0,50, cible <= 0,45) ; IoU normalisée en échelle autour de l'origine, puis ANCRÉE AU
    SOL (bas-centre de la silhouette du niveau 1), et variante sévère échelle + translation (proposition
    <= 0,75) ; agrandissement suréchantillonné 2 × 2 (même protocole que la vérification adverse du 22/10) ;
  - ères (bible §1.2, Q10) : matrice d'IoU des silhouettes et des CORPS (bande y de -2 à 2,2), plus proche
    voisin de chaque époque (dans sa propre ère ?) et IoU de corps maximale entre ères différentes (<= 0,80) ;
  - événements de silhouette (§1.2) : indicateur v2 (profil du haut du masque OUVERT, fils < 5 px retirés,
    pics de proéminence >= 0,20 tuile, plus pics secondaires des profils latéraux), confronté à une
    annotation à la main (EVENTS_ANNOT ; non indépendante : écrite par le producteur) ;
  - photométrie du corps (§1.5) : L5, L50, L95, saturation, écart-type de L, Laplacien moyen |4-voisins| (même
    définition que la vérification adverse ; roboport vanilla 31,2), HORS surfaces lumineuses (éteintes, sous la
    lueur) ;
  - lueur de jour (D2-1, §1.6) sur le COMPOSITE réel (couche principale, émissifs éteints, + lueur additive) :
    luminance médiane et écart avec la médiane du corps (>= +80), pixels saturés (un canal >= 250) et blancs
    (min >= 240), teinte du cœur (alpha >= 0,6) contre la couleur émissive de la bible (±10°), bloc 8 × 8 ;
  - lumière de nuit (D2-3) : énergie de la couche light du sprite et halo par script (I, S de la bible).
Aucune écriture hors du fichier --out (par défaut : mesures_d1.json à côté de ce script).
"""
import argparse
import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(RENDER, "out", "levels", "centre")
sys.path.insert(0, HERE)
import centre_params as PR  # noqa: E402

PPT = 64
# toile commune en tuiles : x [-6, 8), y [-9, 4)
X0, X1, Y0, Y1 = -6, 8, -9, 4
W, H = (X1 - X0) * PPT, (Y1 - Y0) * PPT
LUMA = np.array([0.2126, 0.7152, 0.0722])
BODY_BAND = (-2.0, 2.2)

# Annotation à la main des « événements » de silhouette (dépassements lisibles sur la vignette), faite par le
# PRODUCTEUR sur les planches du 22/10 : elle ne remplace pas le test à l'aveugle (D1-2, non fait).
EVENTS_ANNOT = {
    1: 2,   # mât à drapeau ; tuyau de poêle
    2: 2,   # mât en treillis ; cheminée de forge (les échauguettes restent dans le bloc)
    3: 3,   # 2 cheminées ; mât (chaudière et réservoir : dépassements latéraux bas)
    4: 3,   # torchère ; cuve haute ; escalier et fûts (latéral)
    5: 3,   # 2 pointes de basalte ; mât à bannière
    6: 3,   # tore de Tesla et paratonnerre ; 2 piles d'isolateurs
    7: 4,   # grand cristal ; 2 éclats arrière ; grappes avant
    8: 4,   # col du grand ballon et antenne ; ballon moyen ; petit ballon ; conduit
    9: 4,   # 2 tours de refroidissement ; dôme ; balise
    10: 4,  # radôme ; antenne fouet ; parabole ; pieds
    11: 5,  # tour et flèche ; 4 ailerons (2 de chaque côté à l'écran)
    12: 5,  # noyau et antenne ; 3 anneaux ; pylônes
    13: 5,  # sphère et flèche ; tore (2 côtés) ; trépied ; bunker
    14: 6,  # tour et mât ; 2 ailes ; parabole ; 2 réservoirs
    15: 6,  # 5 flèches de la couronne ; soucoupe
}
ERA_EVENTS = {1: (1, 2), 2: (2, 3), 3: (3, 4), 4: (4, 5), 5: (5, 6)}


def load_mask(path):
    z = np.load(path)
    h, w = (int(v) for v in z["shape"])
    m = np.unpackbits(z["mask"], axis=1)[:, :w].astype(bool)
    ox, oy = (float(v) for v in z["origin"])
    canvas = np.zeros((H, W), bool)
    x0 = int(round(-X0 * PPT - ox))
    y0 = int(round(-Y0 * PPT - oy))
    canvas[y0:y0 + h, x0:x0 + w] = m
    return canvas


def iou(a, b):
    u = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / u) if u else 0.0


# centres des pixels de la toile en tuiles
_XS = (np.arange(W) + 0.5) / PPT + X0
_YS = (np.arange(H) + 0.5) / PPT + Y0


def scaled(mask, k, ax=0.0, ay=0.0):
    """Agrandit un masque d'un facteur k autour du point (ax, ay) (tuiles ; l'origine de l'entité par défaut,
    comme scale + shift × k d'un sprite) ; suréchantillonnage 2 × 2, seuil 0,5."""
    acc = np.zeros((H, W))
    for dx in (-0.25, 0.25):
        for dy in (-0.25, 0.25):
            sx = ((_XS + dx / PPT) - ax) / k + ax
            sy = ((_YS + dy / PPT) - ay) / k + ay
            xi = np.floor((sx - X0) * PPT).astype(int)
            yi = np.floor((sy - Y0) * PPT).astype(int)
            okx = (xi >= 0) & (xi < W)
            oky = (yi >= 0) & (yi < H)
            sub = mask[np.clip(yi, 0, H - 1)][:, np.clip(xi, 0, W - 1)].astype(float)
            sub[~oky, :] = 0
            sub[:, ~okx] = 0
            acc += sub
    return acc / 4 >= 0.5


def iou_scale(a1, an, ks, ax=0.0, ay=0.0):
    best = (0.0, 1.0)
    for k in ks:
        v = iou(scaled(a1, k, ax, ay), an)
        if v > best[0]:
            best = (v, float(k))
    return best


def iou_scale_shift(a1, an, ks):
    """Variante sévère : max sur l'échelle k ET sur toute translation entière (corrélation par FFT)."""
    fb = np.fft.rfft2(an.astype(np.float64), s=(2 * H, 2 * W))
    nb = an.sum()
    best = (0.0, 1.0, (0, 0))
    for k in ks:
        s = scaled(a1, k)
        na = s.sum()
        if na == 0:
            continue
        fa = np.fft.rfft2(s.astype(np.float64)[::-1, ::-1], s=(2 * H, 2 * W))
        inter = np.fft.irfft2(fa * fb, s=(2 * H, 2 * W))
        i = np.unravel_index(np.argmax(inter), inter.shape)
        I = inter[i]
        v = float(I / (na + nb - I))
        if v > best[0]:
            dy, dx = i[0] - (H - 1), i[1] - (W - 1)
            best = (v, float(k), (round(float(dx) / PPT, 3), round(float(dy) / PPT, 3)))
    return best


def extent(mask):
    ys, xs = np.nonzero(mask)
    return (xs.min() / PPT + X0, (xs.max() + 1) / PPT + X0, ys.min() / PPT + Y0, (ys.max() + 1) / PPT + Y0)


def band(mask, y0, y1):
    r0, r1 = int((y0 - Y0) * PPT), int((y1 - Y0) * PPT)
    o = np.zeros_like(mask)
    o[r0:r1] = mask[r0:r1]
    return o


# ---------------------------------------------------------------------------------------------- événements
def _boxsum(m, k):
    c = np.pad(m.astype(np.int32), ((k // 2 + 1, k // 2), (k // 2 + 1, k // 2))).cumsum(0).cumsum(1)
    return c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]


def opening(m, k=5):
    er = _boxsum(m, k) == k * k
    return _boxsum(er, k) > 0


def _peaks(prof, prom_min):
    p = prof.copy()
    fl = np.nanmin(p)
    p = np.nan_to_num(p, nan=fl - 1)
    keep = np.r_[True, p[1:] != p[:-1]]
    xs = np.where(keep)[0]
    hv = p[xs]
    out = []
    for i in range(len(hv)):
        lft = hv[i - 1] if i > 0 else -1e9
        rgt = hv[i + 1] if i < len(hv) - 1 else -1e9
        if not (hv[i] > lft and hv[i] > rgt):
            continue
        j, lo_l = i - 1, hv[i]
        while j >= 0 and hv[j] <= hv[i]:
            lo_l = min(lo_l, hv[j])
            j -= 1
        if j < 0:
            lo_l = min(lo_l, fl - 1)
        j, lo_r = i + 1, hv[i]
        while j < len(hv) and hv[j] <= hv[i]:
            lo_r = min(lo_r, hv[j])
            j += 1
        if j >= len(hv):
            lo_r = min(lo_r, fl - 1)
        pr = hv[i] - max(lo_l, lo_r)
        if pr >= prom_min:
            out.append((int(xs[i]), float(hv[i]), float(pr)))
    return out


def events(mask, prom=0.20):
    """Indicateur v2 : pics du profil du haut (masque complet et masque ouvert : fils < 5 px retirés), plus pics
    SECONDAIRES des profils gauche et droit du masque ouvert (le bord du corps lui-même ne compte pas)."""
    mo = opening(mask, 5)

    def top(m):
        prof = np.full(W, np.nan)
        for c in np.where(m.any(0))[0]:
            prof[c] = -(np.argmax(m[:, c]) / PPT + Y0)
        return prof

    def sides(m):
        Lp, Rp = np.full(H, np.nan), np.full(H, np.nan)
        for r in np.where(m.any(1))[0]:
            xs = np.nonzero(m[r])[0]
            Lp[r] = -(xs.min() / PPT + X0)
            Rp[r] = xs.max() / PPT + X0
        return Lp, Rp
    t_all = _peaks(top(mask), prom)
    t_open = _peaks(top(mo), prom)
    Lp, Rp = sides(mo)
    nl = max(0, len(_peaks(Lp, prom)) - 1)
    nr = max(0, len(_peaks(Rp, prom)) - 1)
    tops = t_all if len(t_all) >= len(t_open) else t_open
    peaks = [(round(c / PPT + X0, 2), round(h - 2.0, 2), round(p, 2)) for c, h, p in tops]
    return {"total": max(len(t_all), len(t_open)) + nl + nr, "top": len(t_all), "top_open": len(t_open),
            "left": nl, "right": nr, "peaks": peaks}


# ---------------------------------------------------------------------------------------------- photométrie
def _lap(lum, a):
    inner = a[1:-1, 1:-1] & a[:-2, 1:-1] & a[2:, 1:-1] & a[1:-1, :-2] & a[1:-1, 2:]
    lap = np.abs(4 * lum[1:-1, 1:-1] - lum[:-2, 1:-1] - lum[2:, 1:-1] - lum[1:-1, :-2] - lum[1:-1, 2:])
    return float(lap[inner].mean())


def _has_block(m, k):
    """Vrai si le masque contient un carré plein de k × k pixels (somme glissante)."""
    if m.shape[0] < k or m.shape[1] < k:
        return False
    c = np.cumsum(np.cumsum(np.pad(m.astype(np.int32), ((1, 0), (1, 0))), 0), 1)
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return bool((s == k * k).any())


def _corner(s):
    return (int(round(s["shift"][0] * 64 - s["width"] / 2.0)), int(round(s["shift"][1] * 64 - s["height"] / 2.0)))


def _hue_dev(h, h0):
    d = abs(h - h0) % 360.0
    return min(d, 360.0 - d)


def photometry(e, d, spec):
    """Corps = couche principale, alpha >= 0,5, HORS des surfaces lumineuses (rendues éteintes, presque noires,
    sous la lueur : ce ne sont pas des matières du corps ; vanilla : ses lueurs sont aussi des couches à part)."""
    mp = os.path.join(d, spec["main"]["hr"]["filename"])
    im = np.asarray(Image.open(mp).convert("RGBA")).astype(np.float64) / 255.0
    a = im[..., 3] >= 0.5
    if "glow" in spec:
        g0 = np.asarray(Image.open(os.path.join(d, spec["glow"]["hr"]["filename"])).convert("RGBA")).astype(np.float64) / 255.0
        gx0, gy0 = _corner(spec["glow"]["hr"])
        mx0, my0 = _corner(spec["main"]["hr"])
        ys, xs = np.nonzero(g0[..., 3] >= 0.25)
        yy, xx = ys + gy0 - my0, xs + gx0 - mx0
        ok = (yy >= 0) & (yy < im.shape[0]) & (xx >= 0) & (xx < im.shape[1])
        a[yy[ok], xx[ok]] = False
    lum_img = im[..., :3] @ LUMA * 255.0
    rgb = im[..., :3][a]
    lum = lum_img[a]
    mx, mn = rgb.max(1), rgb.min(1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    out = {"L5": round(float(np.percentile(lum, 5)), 1), "L50": round(float(np.median(lum)), 1),
           "L95": round(float(np.percentile(lum, 95)), 1), "sat": round(float(sat.mean()), 3),
           "L_std": round(float(lum.std()), 1), "laplacien": round(_lap(lum_img, a), 2), "body_px": int(a.sum()),
           "L50_target": PR.LUM_TARGET[e]}
    if "glow" not in spec:
        return out
    g = np.asarray(Image.open(os.path.join(d, spec["glow"]["hr"]["filename"])).convert("RGBA")).astype(np.float64) / 255.0
    gm = g[..., 3] >= 0.25
    out["glow_px"] = int(gm.sum())
    out["glow_share"] = round(out["glow_px"] / max(1, out["body_px"]), 4)
    out["glow_8x8"] = bool(_has_block(gm, 8))
    mx0, my0 = _corner(spec["main"]["hr"])
    gx0, gy0 = _corner(spec["glow"]["hr"])
    dx, dy = gx0 - mx0, gy0 - my0

    def comp_at(sel):
        ys, xs = np.nonzero(sel)
        my, mxs = ys + dy, xs + dx
        ok = (my >= 0) & (my < im.shape[0]) & (mxs >= 0) & (mxs < im.shape[1])
        base = np.zeros((len(ys), 3))
        base[ok] = im[my[ok], mxs[ok], :3] * im[my[ok], mxs[ok], 3:4]
        add = g[ys, xs, :3] * g[ys, xs, 3:4]
        return np.clip(base + add, 0, 1) * 255.0
    comp = comp_at(gm)
    gl = comp @ LUMA
    out["glow_L50"] = round(float(np.median(gl)), 1)
    out["glow_contrast"] = round(out["glow_L50"] - out["L50"], 1)
    out["glow_saturated_pct"] = round(100.0 * float((comp.max(1) >= 250).mean()), 2)
    out["glow_white_px"] = int((comp.min(1) >= 240).sum())
    # teinte du cœur (alpha >= 0,6) : chaque pixel est rattaché à la couleur émissive de la bible la plus proche
    core = comp_at(g[..., 3] >= 0.6)
    if len(core):
        sub = core[:: max(1, len(core) // 4000)]
        hues = np.array([colorsys.rgb_to_hsv(*(v / 255.0))[0] * 360.0 for v in sub])
        cols = PR.EMISSIVE[e]
        h0 = [PR.hue_deg(PR._hex(c)) for c in cols]
        res = {}
        for c, hh in zip(cols, h0):
            sel = np.array([min(range(len(h0)), key=lambda j: _hue_dev(x, h0[j])) == h0.index(hh) for x in hues])
            if sel.sum() == 0:
                continue
            hs = hues[sel]
            # moyenne circulaire
            ang = np.radians(hs)
            hm = (np.degrees(np.arctan2(np.sin(ang).mean(), np.cos(ang).mean())) + 360.0) % 360.0
            res[c] = {"hue_bible": round(hh, 1), "hue_comp": round(float(hm), 1),
                      "ecart_deg": round(_hue_dev(hm, hh), 1), "part": round(float(sel.mean()), 3)}
        out["glow_hue"] = res
        out["glow_hue_max_dev"] = max(v["ecart_deg"] for v in res.values()) if res else None
    return out


def light_energy(d, spec):
    if "light" not in spec:
        return None
    im = np.asarray(Image.open(os.path.join(d, spec["light"]["hr"]["filename"])).convert("RGBA")).astype(np.float64) / 255.0
    return round(float(((im[..., :3] * im[..., 3:4]) @ LUMA).sum() / PPT ** 2), 3)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "mesures_d1.json"))
    ap.add_argument("--md", action="store_true", help="imprime le tableau Markdown")
    a = ap.parse_args()
    levels = [e for e in range(1, 16) if os.path.exists(os.path.join(OUT, "n%02d" % e, "mask-sil.npz"))]
    sil, mass, full = {}, {}, {}
    rows = []
    for e in levels:
        d = os.path.join(OUT, "n%02d" % e)
        sil[e] = load_mask(os.path.join(d, "mask-sil.npz"))
        mass[e] = load_mask(os.path.join(d, "mask-mass.npz"))
        fp = os.path.join(d, "mask-full.npz")
        full[e] = load_mask(fp) if os.path.exists(fp) else sil[e]
    fpm = np.zeros((H, W), bool)
    fpm[(-2 - Y0) * PPT:(2 - Y0) * PPT, (-2 - X0) * PPT:(2 - X0) * PPT] = True
    a1 = sil.get(1)
    bodies = {e: band(sil[e], *BODY_BAND) for e in levels}
    for e in levels:
        ex_m = extent(mass[e])
        ex_s = extent(sil[e])
        O = -ex_m[2] - 2.0
        O_t = -ex_s[2] - 2.0
        Lw = ex_m[1] - ex_m[0]
        area = sil[e].sum() / PPT ** 2
        r = {"level": e, "name": PR.NAMES[e], "era": PR.ERA[e],
             "O": round(O, 2), "O_target": PR.ENVELOPE[e][0], "O_tige": round(O_t, 2),
             "L": round(Lw, 2), "L_max": PR.ENVELOPE[e][1],
             "x": [round(ex_s[0], 2), round(ex_s[1], 2)], "y": [round(ex_s[2], 2), round(ex_s[3], 2)],
             "area_t2": round(float(area), 2),
             "footprint_cover": round(float(np.logical_and(sil[e], fpm).sum() / fpm.sum()), 3),
             "footprint_cover_full": round(float(np.logical_and(full[e], fpm).sum() / fpm.sum()), 3)}
        if e - 1 in sil:
            p = sil[e - 1]
            r["iou_prev"] = round(iou(p, sil[e]), 3)
            r["added_t2"] = round(float(np.logical_and(sil[e], ~p).sum() / PPT ** 2), 2)
            r["removed_t2"] = round(float(np.logical_and(p, ~sil[e]).sum() / PPT ** 2), 2)
        if a1 is not None:
            r["V_pct"] = round(100.0 * float(np.logical_and(a1, ~sil[e]).sum() / a1.sum()), 1)
            r["V_min_pct"] = PR.ENVELOPE[e][2]
            r["iou_lvl1"] = round(iou(a1, sil[e]), 3)
        ev = events(sil[e])
        r["events"] = ev["total"]
        r["events_detail"] = ev
        r["events_annot"] = EVENTS_ANNOT[e]
        r["events_era_range"] = list(ERA_EVENTS[PR.ERA[e]])
        d = os.path.join(OUT, "n%02d" % e)
        rj = os.path.join(d, "render.json")
        if os.path.exists(rj):
            with open(rj, encoding="utf-8") as f:
                rec = json.load(f)
            spec = rec.get("spec")
            if spec and "main" in spec:
                r["photo"] = photometry(e, d, spec)
                r["light_energy_t2"] = light_energy(d, spec)
            r["render_lock"] = bool(rec.get("render_lock"))
            r["main_sans_emission"] = bool(rec.get("main_sans_emission"))
        r["halo_script"] = PR.halo_script(e)
        r["body_top_tiles"] = round(-ex_m[2], 2)
        rows.append(r)
    res = {"levels": rows, "notes": "masques alpha >= 0,5 à 64 px/tuile ; O et L sur mask-mass ; IoU sur mask-sil ; "
                                    "corps = bande y de -2 à 2,2 ; composite de jour = main (émissifs éteints) + glow"}
    res["events_summary"] = {
        "indicateur_dans_fourchette_ere": sum(1 for r in rows if r["events_era_range"][0] <= r["events"] <= r["events_era_range"][1]),
        "annotation_dans_fourchette_ere": sum(1 for r in rows if r["events_era_range"][0] <= r["events_annot"] <= r["events_era_range"][1]),
        "accord_indicateur_annotation_a_1_pres": sum(1 for r in rows if abs(r["events"] - r["events_annot"]) <= 1),
        "statut": "NON ÉTALONNÉ : annotation du producteur, non indépendante ; test de tri à l'aveugle (D1-2) non fait"}
    O_seq = [r["O"] for r in rows]
    res["O_monotone"] = all(b >= a - 1e-9 for a, b in zip(O_seq, O_seq[1:]))
    res["O_max_vs_ceiling"] = [max(O_seq) if O_seq else None, PR.O_CEILING]
    # --- matrices d'IoU (silhouette entière et corps) et plus proches voisins ---
    mat_s, mat_b = {}, {}
    for i in levels:
        for j in levels:
            if j > i:
                mat_s[(i, j)] = iou(sil[i], sil[j])
                mat_b[(i, j)] = iou(bodies[i], bodies[j])

    def get(m, i, j):
        return m[(min(i, j), max(i, j))]
    nn = {}
    for i in levels:
        others = [j for j in levels if j != i]
        if not others:
            continue
        j = max(others, key=lambda j: get(mat_s, i, j))
        jb = max(others, key=lambda j: get(mat_b, i, j))
        nn[i] = {"sil": j, "sil_iou": round(get(mat_s, i, j), 3), "same_era": PR.ERA[j] == PR.ERA[i],
                 "body": jb, "body_iou": round(get(mat_b, i, jb), 3), "body_same_era": PR.ERA[jb] == PR.ERA[i]}
    cross = [(get(mat_b, i, j), i, j) for i in levels for j in levels if j > i and PR.ERA[i] != PR.ERA[j]]
    res["eras"] = {
        "matrix_sil": {"%d-%d" % k: round(v, 3) for k, v in sorted(mat_s.items())},
        "matrix_body": {"%d-%d" % k: round(v, 3) for k, v in sorted(mat_b.items())},
        "nearest": {str(k): v for k, v in nn.items()},
        "nearest_same_era_count": sum(1 for v in nn.values() if v["same_era"]),
        "body_cross_era_max": [round(max(cross)[0], 3), max(cross)[1], max(cross)[2]] if cross else None,
        "body_cross_era_over_080": sorted([("%d-%d" % (i, j), round(v, 3)) for v, i, j in cross if v > 0.80],
                                          key=lambda t: -t[1]),
    }
    if 1 in sil and 15 in sil:
        ks = np.round(np.arange(0.50, 3.001, 0.01), 3)
        v, k = iou_scale(sil[1], sil[15], ks)
        ex1 = extent(sil[1])
        ax, ay = (ex1[0] + ex1[1]) / 2.0, ex1[3]
        vg, kg = iou_scale(sil[1], sil[15], ks, ax, ay)
        vf, kf = iou_scale(full[1], full[15], ks)
        res["d1_3"] = {"iou_1_15": round(iou(sil[1], sil[15]), 3),
                       "iou_1_15_full": round(iou(full[1], full[15]), 3),
                       "iou_norm_scale": round(v, 3), "k_best": k,
                       "iou_norm_scale_sol": round(vg, 3), "k_sol": kg, "ancre_sol": [round(ax, 3), round(ay, 3)],
                       "iou_norm_scale_full": round(vf, 3), "k_full": kf}
        ks2 = np.round(np.arange(0.50, 3.001, 0.02), 3)
        v2, k2, sh = iou_scale_shift(sil[1], sil[15], ks2)
        res["d1_3"].update({"iou_norm_scale_shift": round(v2, 3), "k2_best": k2, "shift2_tiles": sh})
    # échelle seule entre époques consécutives (aucun « simple agrandissement » d'une époque à la suivante)
    ks3 = np.round(np.arange(0.70, 1.601, 0.02), 3)
    res["consecutive_scale_max"] = {"%d-%d" % (e, e + 1): round(iou_scale(sil[e], sil[e + 1], ks3)[0], 3)
                                    for e in levels if e + 1 in sil}
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1, ensure_ascii=False)
    if a.md:
        print(table_md(res))
    else:
        print(json.dumps(res.get("d1_3", {}), ensure_ascii=False))
        print("O monotone :", res["O_monotone"], "; O max / plafond :", res["O_max_vs_ceiling"])


def table_md(res):
    lines = ["| Niv. | Nom | O (cible) | O tige | L (env.) | Aire t² | Emprise % | IoU préc. | IoU niv. 1 | V % (min) | "
             "Événements (annot. ; ère) | L50 (cible) | p95 | écart-type L | Laplacien | émissif % | lueur − L50 | saturés % | "
             "écart de teinte | lumière nuit t² |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in res["levels"]:
        ph = r.get("photo", {})
        lines.append("| %d | %s | %.2f (%.2f) | %.2f | %.2f (%.2f) | %.2f | %.0f | %s | %s | %s | %d (%d ; %d-%d) | %s | %s | %s | %s | "
                     "%s | %s | %s | %s | %s |" % (
                         r["level"], r["name"], r["O"], r["O_target"], r["O_tige"], r["L"], r["L_max"], r["area_t2"],
                         100 * r["footprint_cover"], r.get("iou_prev", "—"), r.get("iou_lvl1", "—"),
                         ("%.1f (%d)" % (r["V_pct"], r["V_min_pct"])) if "V_pct" in r else "—",
                         r["events"], r["events_annot"], r["events_era_range"][0], r["events_era_range"][1],
                         ("%.0f (%d)" % (ph["L50"], ph["L50_target"])) if ph else "—", ph.get("L95", "—"),
                         ph.get("L_std", "—"), ph.get("laplacien", "—"),
                         ("%.1f" % (100 * ph["glow_share"])) if "glow_share" in ph else "0",
                         ("%+.0f%s" % (ph["glow_contrast"], "" if r["level"] > 2 else " (nuit)")) if "glow_contrast" in ph else "—",
                         ph.get("glow_saturated_pct", "—"),
                         ("%.1f°" % ph["glow_hue_max_dev"]) if ph.get("glow_hue_max_dev") is not None else "—",
                         r.get("light_energy_t2", "—")))
    d = res.get("d1_3")
    if d:
        lines.append("")
        lines.append("D1-3 : IoU(1, 15) sans couches plates = %.3f (seuil < 0,50, cible <= 0,45) ; avec tout = %.3f ; "
                     "IoU normalisée en échelle = %.3f autour de l'origine (k = %.2f), %.3f ancrée au sol (k = %.2f), "
                     "%.3f sur le masque complet ; variante sévère échelle + translation = %.3f (k = %.2f, décalage %s "
                     "tuile) ; proposition <= 0,75." % (
                         d["iou_1_15"], d["iou_1_15_full"], d["iou_norm_scale"], d["k_best"], d["iou_norm_scale_sol"],
                         d["k_sol"], d["iou_norm_scale_full"], d["iou_norm_scale_shift"], d["k2_best"], d["shift2_tiles"]))
    er = res.get("eras")
    if er:
        lines.append("Ères : plus proche voisin dans sa propre ère pour %d époques sur 15 ; IoU de corps maximale entre "
                     "ères différentes = %s ; paires > 0,80 : %s." % (
                         er["nearest_same_era_count"], er["body_cross_era_max"], er["body_cross_era_over_080"] or "aucune"))
    ev = res.get("events_summary")
    if ev:
        lines.append("Événements : indicateur dans la fourchette de l'ère pour %d époques sur 15, annotation pour %d ; accord "
                     "indicateur / annotation à 1 près : %d sur 15 (%s)." % (
                         ev["indicateur_dans_fourchette_ere"], ev["annotation_dans_fourchette_ere"],
                         ev["accord_indicateur_annotation_a_1_pres"], ev["statut"]))
    lines.append("O jamais décroissant : %s ; O max %.2f pour un plafond de %.2f." % (
        res["O_monotone"], res["O_max_vs_ceiling"][0], res["O_max_vs_ceiling"][1]))
    return "\n".join(lines)


if __name__ == "__main__":
    main()
