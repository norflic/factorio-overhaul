"""Planches de la foreuse électrique (lot V3, phase 1) : composition hors moteur des aperçus rendus.

    python -P tools/render/pieces/levels/drill/planches.py [--quick] [--dest docs/epoques/planches/drill]
           [--data "<racine>/data"]

Planches (PNG compacts, versionnés) :
  a-jour-zoom1.png        les 30 niveaux, pose N, au zoom 1 (32 px/tuile) sur la tuile de sol vanilla
                          hr-dirt-4, avec leurs ombres, de jour ; ligne du haut = niveaux impairs
                          (nouvelle silhouette, niveau 1 = vanilla), ligne du bas = niveaux pairs (+ pièce)
  b-nuit-zoom1.png        la même de nuit (LUT lut-night.png, carte des lumières = halos + lueurs, comme
                          tools/render/calib/maquette.py)
  c-gris-zoom1.png        la même en niveaux de gris (test du gris D1-1)
  d-vignettes.png         les 15 niveaux impairs en masques noirs, à la même échelle, le plus grand dans
                          64 px (test de la vignette D1-2), dans l'ordre ; d-vignettes-melangees.png : le
                          même jeu mélangé (lettres), la clé est dans d-vignettes-cle.txt
  e-gros-plans-zoom2-eNN.png  les 15 époques au zoom 2 (64 px/tuile, sprites hr 1:1) : vanilla
                          (niveau 1), niveau impair, niveau pair ; lignes : jour N, nuit N, jour S, nuit S
                          (pose S : goulotte devant) ; correction V3 du 22/10 (D3-2 : gros plan de chaque
                          époque, 4 époques sur 15 auparavant)
  f-directions-zoom1.png  les 30 niveaux dans les 4 directions (N, E, S, O), de jour, zoom 1
  g-courbe-hauteurs.png   hauteur O (pose N, masses) des 30 niveaux, impairs et pairs, contre la cible
                          linéaire de la bible §4 et le plafond 1,60 (question des « dents de scie » au
                          Directeur Créatif ; lit tools/render/out/levels/drill/mesures_d1.json)
Composition (comme maquette.py, CALIBRATION §6) : ombres au maximum des alphas puis sol × (1 − 0,5 a) ;
corps par-dessus (sRGB codé, comme le tampon du moteur) ; lueur additive (jour) et dans la carte des
lumières ; halo de nuit du niveau = LightDefinition (levels_io.halo_map : I(N) = 0,05 + 0,02·N, rayon
S(N) = 1,5 × (1 + 0,05·N), texture light-medium du moteur) ajoutée à la carte des lumières ;
nuit = mix(LUT_nuit(jour), jour, lumière bornée). lightMul et lightAdd du moteur : inconnus
(pris à 1 et 0) ; les lumières propres de la foreuse vanilla (DEL d'état, lumière de travail) ne sont
pas composées (foreuse à l'arrêt). NON PROUVÉ en moteur.
"""
import argparse
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "calib"))
import fo_post as P  # noqa: E402
import levels_io as IO  # noqa: E402
from maquette import lut_apply  # noqa: E402  (lecture seule du pipeline partagé)

DEFAULT_DATA = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data"
LUMA = np.array([0.2126, 0.7152, 0.0722])
# cadre d'une cellule (tuiles, autour de la position de l'entité) : sommet du niveau 30 compris
CX0, CX1, CY0, CY1 = -2.0, 2.75, -4.5, 2.0


def _font(size=12):
    """Police TrueType du système (accents) ; police par défaut de Pillow sinon (sans accents)."""
    for f in ("arial.ttf", "segoeui.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            continue
    return ImageFont.load_default()


FONT = _font(12)


def ground(data, h, w):
    g = np.asarray(Image.open(os.path.join(data, "base", "graphics", "terrain", "hr-dirt-4.png")).convert("RGB"))
    g = g[320:576].astype(np.float64) / 255.0
    reps = (h // g.shape[0] + 1, w // g.shape[1] + 1, 1)
    return np.tile(g, reps)[:h, :w].copy()


def cell(lay, data, light_extra=True):
    """Compose un niveau sur le sol : renvoie (jour, nuit) RGB du cadre de cellule (64 px/tuile)."""
    ox, oy = IO.ORIGIN
    x0, x1 = int(ox + CX0 * 64), int(ox + CX1 * 64)
    y0, y1 = int(oy + CY0 * 64), int(oy + CY1 * 64)
    h, w = y1 - y0, x1 - x0
    day = ground(data, h, w)
    sh = lay["shadow"][y0:y1, x0:x1] if lay["shadow"] is not None else np.zeros((h, w))
    day = day * (1 - 0.5 * sh)[..., None]
    m = lay["main"][y0:y1, x0:x1]
    a = m[..., 3:4]
    day = m[..., :3] * a + day * (1 - a)
    light = np.zeros((h, w, 3))
    if lay.get("glow") is not None:
        g = lay["glow"][y0:y1, x0:x1]
        pm = g[..., :3] * g[..., 3:4]
        day = np.clip(day + pm, 0, 1)
        light += pm
    if lay.get("light") is not None:
        li = lay["light"][y0:y1, x0:x1]
        light += li[..., :3] * li[..., 3:4]
    if lay.get("halo") is not None:
        light += lay["halo"][y0:y1, x0:x1]
    light = np.clip(light, 0, 1)
    night = lut_apply(day, os.path.join(data, "core", "graphics", "color_luts", "lut-night.png"))
    night = night * (1 - light) + day * light
    return day, night


def down2(rgb):
    h, w = rgb.shape[:2]
    lin = P.srgb_to_lin(rgb[:h // 2 * 2, :w // 2 * 2])
    lin = lin.reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3))
    return P.lin_to_srgb(lin)


def to_img(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def grid(cells, cols, labels, pad=6, bg=(24, 24, 24), lab_h=14, fg=None, title=None):
    """Assemble des images RGB (listes de lignes) avec une étiquette au-dessus de chaque cellule ; `title` :
    lignes de texte en tête de planche."""
    ch = max(c.shape[0] for row in cells for c in row if c is not None)
    cw = max(c.shape[1] for row in cells for c in row if c is not None)
    rows = len(cells)
    top = 0 if not title else 14 * len(title) + 4
    W = cols * (cw + pad) + pad
    H = rows * (ch + pad + lab_h) + pad + top
    out = Image.new("RGB", (W, H), bg)
    dr = ImageDraw.Draw(out)
    fgc = fg or ((20, 20, 20) if sum(bg) > 384 else (230, 230, 230))
    for k, line in enumerate(title or []):
        dr.text((pad + 2, 4 + 14 * k), line, fill=fgc, font=FONT)
    for r, row in enumerate(cells):
        for c, im in enumerate(row):
            if im is None:
                continue
            x = pad + c * (cw + pad)
            y = top + pad + r * (ch + pad + lab_h)
            dr.text((x + 2, y), labels[r][c], fill=fg or ((20, 20, 20) if sum(bg) > 384 else (230, 230, 230)), font=FONT)
            out.paste(to_img(im), (x, y + lab_h))
    return out


def height_chart(mes, path):
    """Courbe O (pose N) des 30 niveaux : impairs (silhouette) et pairs (+ pièce), cible et plafond."""
    import measure_d1 as M
    W, H, L, R, T, B = 1200, 560, 80, 220, 70, 70
    im = Image.new("RGB", (W, H), (252, 252, 250))
    dr = ImageDraw.Draw(im)
    ink, muted, grid_c = (30, 30, 28), (110, 110, 104), (226, 226, 220)
    c_odd, c_even = (0x2A, 0x78, 0xD6), (0xEB, 0x68, 0x34)
    y0v, y1v = 0.2, 1.8

    def X(n):
        return L + (n - 1) * (W - L - R) / 29.0

    def Y(v):
        return T + (y1v - v) * (H - T - B) / (y1v - y0v)
    dr.text((L, 18), "Foreuse électrique : hauteur O au-dessus de l'emprise (pose N, masses), niveaux 1 à 30", fill=ink, font=FONT)
    dr.text((L, 36), "bleu : niveaux impairs (nouvelle silhouette) ; orange : niveaux pairs (+ pièce) ; gris : cible "
            "linéaire de la bible §4 ; tirets : plafond 1,60 (Q9)", fill=muted, font=FONT)
    for v in (0.4, 0.6, 0.8, 1.0, 1.2, 1.4, 1.6):
        dr.line([(L, Y(v)), (W - R, Y(v))], fill=grid_c, width=1)
        dr.text((L - 40, Y(v) - 6), ("%.1f" % v).replace(".", ","), fill=muted, font=FONT)
    for n in range(1, 31):
        if n % 2 == 1 or n == 30:
            dr.text((X(n) - 6, H - B + 8), str(n), fill=muted, font=FONT)
    dr.text(((W - R) / 2 - 20, H - B + 26), "niveau", fill=muted, font=FONT)
    dr.text((8, T - 24), "O (tuiles)", fill=muted, font=FONT)
    dr.line([(L, T), (L, H - B), (W - R, H - B)], fill=muted, width=1)
    # cible par rang (impairs) et plafond
    tgt = [(X(2 * e - 1), Y(M.O_RANK[e - 1])) for e in range(1, 16)]
    dr.line(tgt, fill=(150, 150, 144), width=2)
    for xx in range(L, W - R, 12):
        dr.line([(xx, Y(1.60)), (xx + 6, Y(1.60))], fill=(150, 150, 144), width=1)
    pts = {}
    for n in range(1, 31):
        r = mes["levels"].get("L%02d" % n, {}).get("N")
        if r is not None:
            pts[n] = r["O"]
    for par, col in ((1, c_odd), (0, c_even)):
        seq = [(X(n), Y(pts[n])) for n in sorted(pts) if n % 2 == par]
        if len(seq) > 1:
            dr.line(seq, fill=col, width=2)
        for (xx, yy) in seq:
            dr.ellipse([xx - 5, yy - 5, xx + 5, yy + 5], fill=col, outline=(252, 252, 250), width=2)
    # liens impair -> pair de la même époque (pièce) et dents de scie (pair -> impair suivant plus bas)
    saw = 0
    for n in range(2, 30, 2):
        if n in pts and n + 1 in pts and pts[n + 1] < pts[n] - 1e-9:
            saw += 1
    # étiquettes directes à droite
    if 29 in pts:
        dr.text((W - R + 12, Y(pts[29]) - 6), "impairs (L29 : %s)" % ("%.2f" % pts[29]).replace(".", ","), fill=ink, font=FONT)
    if 30 in pts:
        dr.text((W - R + 12, Y(pts[30]) + 8), "pairs (L30 : %s)" % ("%.2f" % pts[30]).replace(".", ","), fill=ink, font=FONT)
    dr.text((W - R + 12, Y(1.60) - 20), "plafond 1,60", fill=muted, font=FONT)
    dr.text((L, H - 22), "Passages pair -> impair suivant où la foreuse RAPETISSE : %d sur 14 (le pair porte une pièce "
            "haute, la bible fixe la hauteur des pièces à +0,25 à +0,50, pas d'époque 0,087)" % saw, fill=ink, font=FONT)
    return save(im, path)


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--dest", default=os.path.join(MOD_ROOT, "docs", "epoques", "planches", "drill"))
    ap.add_argument("--data", default=os.environ.get("FO_DATA", DEFAULT_DATA))
    a = ap.parse_args()
    spec = IO.load_spec()
    dest = a.dest
    if a.quick:
        dest = os.path.join(IO.OUT, "planches-quick")
    lays = {}
    for lvl in range(1, 31):
        for d in IO.DIRS:
            lay = IO.level_layers(spec, lvl, d, quick=a.quick)
            if lay is not None and lay["main"] is not None:
                lays[(lvl, d)] = lay
    cache = {}

    def comp(lvl, d):
        if (lvl, d) not in cache:
            cache[(lvl, d)] = cell(lays[(lvl, d)], a.data)
        return cache[(lvl, d)]

    written = []
    # (a) (b) (c) : pose N, 2 lignes × 15 époques, zoom 1
    for tag, idx, gray in (("a-jour-zoom1", 0, False), ("b-nuit-zoom1", 1, False), ("c-gris-zoom1", 0, True)):
        rows, labels = [[], []], [[], []]
        for e in range(1, 16):
            for r, lvl in enumerate((2 * e - 1, 2 * e)):
                if (lvl, "N") in lays:
                    im = down2(comp(lvl, "N")[idx])
                    if gray:
                        g = P.lin_to_srgb(P.srgb_to_lin(im) @ LUMA)
                        im = np.repeat(g[..., None], 3, -1)
                    rows[r].append(im)
                else:
                    rows[r].append(None)
                labels[r].append("niv %d (e%d)" % (lvl, e))
        written.append(save(grid(rows, 15, labels), os.path.join(dest, tag + ".png")))
    # (d) vignettes : 15 niveaux impairs, pose N, masques noirs à la même échelle (le plus grand : 64 px)
    masks = []
    for e in range(1, 16):
        lvl = 2 * e - 1
        if (lvl, "N") in lays:
            masks.append((e, lays[(lvl, "N")]["main"][..., 3] >= 0.5))
    if masks:
        ys0, ys1, xs0, xs1 = 10 ** 9, -1, 10 ** 9, -1
        for _, m in masks:
            ys, xs = np.nonzero(m)
            ys0, ys1, xs0, xs1 = min(ys0, ys.min()), max(ys1, ys.max()), min(xs0, xs.min()), max(xs1, xs.max())
        side = max(ys1 - ys0 + 1, xs1 - xs0 + 1)
        f = 64.0 / side
        th = []
        for e, m in masks:
            crop = m[ys0:ys0 + side, xs0:xs0 + side].astype(np.float64)
            im = Image.fromarray((crop * 255).astype(np.uint8), "L").resize((64, 64), Image.BOX)
            v = 1.0 - np.asarray(im).astype(np.float64) / 255.0
            th.append((e, np.repeat(v[..., None], 3, -1)))
        written.append(save(grid([[t for _, t in th]], 15, [["e%d" % e for e, _ in th]], bg=(255, 255, 255)),
                            os.path.join(dest, "d-vignettes.png")))
        rnd = random.Random(20261021)
        order = list(range(len(th)))
        rnd.shuffle(order)
        letters = "ABCDEFGHIJKLMNO"
        written.append(save(grid([[th[i][1] for i in order]], 15, [[letters[k] for k in range(len(order))]],
                                 bg=(255, 255, 255)), os.path.join(dest, "d-vignettes-melangees.png")))
        with open(os.path.join(dest, "d-vignettes-cle.txt"), "w", encoding="utf-8", newline="\n") as fk:
            fk.write("Vignettes mélangées (graine 20261021) : lettre -> époque\n")
            for k, i in enumerate(order):
                fk.write("%s -> époque %d (niveau %d)\n" % (letters[k], th[i][0], 2 * th[i][0] - 1))
            fk.write("Échelle commune : %.2f px par tuile (le plus grand cadre : %d px hr)\n" % (f * 64, side))
    # (e) gros plans zoom 2 : les 15 époques ; jour et nuit, poses N et S (goulotte devant en S)
    rinfo = spec["levels"].get("L03", {}).get("N", {}).get("render", {})
    note = ("APERÇU de phase 1 : Cycles %s échantillons%s, passes ao / ombre / lueur à %s ; pas le rendu final"
            % (rinfo.get("samples", "?"), ", débruité (OIDN)" if rinfo.get("denoise") else ", NON débruité (bruité)",
               rinfo.get("samples_aux", "?")))
    for e in range(1, 16):
        lv = [1, 2 * e - 1, 2 * e] if e > 1 else [1, 2]
        lv = [x for x in lv if (x, "N") in lays and (x, "S") in lays]
        rows, labels = [], []
        for d in ("N", "S"):
            for idx, tag in ((0, "jour"), (1, "nuit")):
                rows.append([comp(x, d)[idx] for x in lv])
                labels.append(["%s niv %d %s%s" % (tag, x, d, " (vanilla)" if x == 1 else "") for x in lv])
        title = ["Foreuse électrique, époque %d : vanilla, niveau impair, niveau pair ; zoom 2 (sprites hr 1:1)" % e,
                 note]
        written.append(save(grid(rows, len(lv), labels, title=title),
                            os.path.join(dest, "e-gros-plans-zoom2-e%02d.png" % e)))
    # (f) 4 directions, zoom 1, de jour : 15 colonnes (époques) × 8 lignes (impair N E S O, pair N E S O)
    rows, labels = [], []
    for r, (par, d) in enumerate([(0, d) for d in IO.DIRS] + [(1, d) for d in IO.DIRS]):
        row, lab = [], []
        for e in range(1, 16):
            lvl = 2 * e - 1 + par
            row.append(down2(comp(lvl, d)[0]) if (lvl, d) in lays else None)
            lab.append("niv %d %s" % (lvl, d))
        rows.append(row)
        labels.append(lab)
    written.append(save(grid(rows, 15, labels), os.path.join(dest, "f-directions-zoom1.png")))
    mpath = os.path.join(IO.OUT, "mesures_d1%s.json" % ("_quick" if a.quick else ""))
    if os.path.exists(mpath):
        import json
        with open(mpath, encoding="utf-8") as fm:
            written.append(height_chart(json.load(fm), os.path.join(dest, "g-courbe-hauteurs.png")))
    for w in written:
        print(os.path.abspath(w))


if __name__ == "__main__":
    main()
