"""Aperçu RAPIDE hors Blender (aucun verrou de rendu) : projection de la géométrie de ht_gun.py, algorithme du
peintre, ombrage plat (soleil d'ouest 48° + appoint zénithal + ambiance), 64 px/tuile, même projection que le
pipeline (fo_calib). Sert à régler la composition, l'emprise, la masse, O, la part massive et la zone lumineuse
AVANT de prendre une place de rendu. Les indicateurs de détail et de patine (D, P) n'ont AUCUN sens ici : ils ne
se mesurent que sur le rendu Cycles.

    python ht_apercu.py [--levels 11,21,29,30] [--out <dossier>] [--pose E]
"""
import argparse
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ht_geo as G  # noqa: E402
import ht_gun as H  # noqa: E402

CHARTE = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3S\charte\outils"
sys.path.insert(0, CHARTE)
import da_lib as D  # noqa: E402

PPT = 64.0
C45 = math.cos(math.radians(45))
SUN = np.array([-math.cos(math.radians(48)), 0.0, math.sin(math.radians(48))])
CAM = np.array([0.0, -C45, C45])


def lin2srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def triangles(b, angle):
    """Tous les triangles (monde) avec matériau ; la tête est tournée de `angle` autour de Z."""
    R = G.Rz(angle)
    tris, mats = [], []
    for (mat, bev), g in b.groups.items():
        V = np.concatenate(g["v"]) @ R.T
        for f in g["f"]:
            for k in range(1, len(f) - 1):
                tris.append((V[f[0]], V[f[k]], V[f[k + 1]]))
                mats.append(mat)
    return np.array(tris), mats


def raster(parts, pal_by_part, pad=1.2):
    """parts : liste de (triangles, mats) dessinés dans l'ordre (socle puis tête : couches du moteur).
    Renvoie corps RGBA (float, alpha droit), carte d'émission, origine (px)."""
    allv = np.concatenate([t.reshape(-1, 3) for t, _ in parts])
    u = allv[:, 0] * PPT
    v = -(allv[:, 1] * C45 + allv[:, 2] * C45) * PPT
    x0, x1 = int(u.min() - pad * PPT), int(u.max() + pad * PPT)
    y0, y1 = int(v.min() - pad * PPT), int(v.max() + pad * PPT)
    W, Hh = x1 - x0, y1 - y0
    ox, oy = -x0, -y0
    img = Image.new("RGBA", (W, Hh), (0, 0, 0, 0))
    emi = Image.new("L", (W, Hh), 0)
    dr = ImageDraw.Draw(img)
    de = ImageDraw.Draw(emi)
    for (T, mats), pal in zip(parts, pal_by_part):
        if len(T) == 0:
            continue
        n = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
        nn = np.linalg.norm(n, axis=1)
        keep = nn > 1e-12
        n[keep] /= nn[keep, None]
        flip = (n @ CAM) < 0
        n[flip] *= -1
        sun = np.clip(n @ SUN, 0, None)
        fill = np.clip(n[:, 2], 0, None)
        shade = 0.95 * sun + 0.55 * fill + 0.12
        cen = T.mean(1)
        depth = cen[:, 1] * C45 - cen[:, 2] * C45
        order = np.argsort(-depth, kind="stable")
        U = T[:, :, 0] * PPT + ox
        Vv = -(T[:, :, 1] * C45 + T[:, :, 2] * C45) * PPT + oy
        for i in order:
            if not keep[i]:
                continue
            spec = pal[mats[i]]
            if spec["kind"] == "emit":
                col = np.array(spec["color"])
                e = 255
            else:
                col = np.array(spec["color"]) * shade[i] * 1.6
                e = 0
            c = tuple(int(x) for x in np.round(lin2srgb(col) * 255)) + (255,)
            poly = [(U[i, k], Vv[i, k]) for k in range(3)]
            dr.polygon(poly, fill=c)
            de.polygon(poly, fill=e)
    body = np.asarray(img, np.float32) / 255.0
    em = np.asarray(emi, np.float32) / 255.0
    return body, em, (ox, oy)


def sweep_conflicts(bs, bh):
    """Éléments du socle qui seraient heurtés par la tête en tournant : un sommet du socle à la distance r de l'axe
    est en conflit s'il dépasse la cote la plus basse des parties de la tête situées à r ou plus loin."""
    Vh = np.concatenate([np.concatenate(g["v"]) for g in bh.groups.values()])
    rh = np.hypot(Vh[:, 0], Vh[:, 1])
    order = np.argsort(-rh)
    zmin_from = np.minimum.accumulate(Vh[order, 2])       # min z des sommets de rayon >= rh[order[i]]
    r_sorted = rh[order]
    out = []
    for (mat, bev), g in bs.groups.items():
        V = np.concatenate(g["v"])
        r = np.hypot(V[:, 0], V[:, 1])
        idx = np.searchsorted(-r_sorted, -r, side="right") - 1
        ok = idx >= 0
        zlim = np.full(len(r), np.inf)
        zlim[ok] = zmin_from[idx[ok]]
        bad = V[:, 2] > zlim + 0.02
        if bad.any():
            k = int(np.argmax(V[:, 2] - zlim))
            out.append((mat, int(bad.sum()), tuple(np.round(V[k], 2)), float(np.round(zlim[k], 2))))
    return out


def comp_from(body, em, origin):
    z = np.zeros(body.shape[:2], np.float32)
    return {"body": body, "emis": em, "halo": z, "team": z, "origin": origin}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="11,21,29,30")
    ap.add_argument("--pose", default="E")
    ap.add_argument("--out", default=os.path.join(HERE, "..", "..", "..", "out", "levels", "gun_s_hightech", "apercu"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for lv in [int(x) for x in a.levels.split(",")]:
        info = H.LEVELS[lv]
        pal = H.palette(info["epoch"])
        bs, _ = H.build("n%02d-socle" % lv)
        hl = 29 if lv == 30 else lv
        bh, ang = H.build("n%02d-tete-%s" % (hl, a.pose))
        parts = [triangles(bs, 0.0), triangles(bh, ang)]
        body, em, origin = raster(parts, [pal, pal])
        comp = comp_from(body, em, origin)
        r = D.measure(comp, info["side"], "n%02d" % lv)
        ntri = sum(len(p[0]) for p in parts)
        print("n%02d %s : primitives %d+%d, triangles %d ; masse %.2f t² ; remplissage %.2f ; masse/emprise %.2f ; "
              "massive %.3f ; O %.2f (O/côté %.2f) ; largeur %.2f ; L1 %.3f ; L2 %.3f t² ; systèmes %d"
              % (lv, a.pose, bs.nprim, bh.nprim, ntri, r["masse_tuiles2"], r["remplissage_emprise"],
                 r["masse_par_tuile_emprise"], r["part_massive"], r["O_depassement_haut"],
                 r["O_depassement_haut"] / info["side"], r["largeur_tuiles"], r["zone_lumineuse_part"],
                 r["plus_grand_foyer_lumineux_tuiles2"], len(H.systems(lv))), flush=True)
        im = Image.fromarray((np.clip(body, 0, 1) * 255).astype(np.uint8), "RGBA")
        bg = Image.new("RGBA", im.size, (40, 40, 40, 255))
        bg.alpha_composite(im)
        # repère d'emprise
        d = ImageDraw.Draw(bg)
        s = info["side"] / 2 * PPT
        d.rectangle([origin[0] - s, origin[1] - s, origin[0] + s, origin[1] + s], outline=(255, 60, 60, 255))
        bg.convert("RGB").save(os.path.join(a.out, "apercu-n%02d-%s.png" % (lv, a.pose)))
        bn, _ = H.build("n%02d-tete-N" % hl)
        sc = sweep_conflicts(bs, bn)
        print("   balayage de la tête : %s" % ("aucun conflit" if not sc else sc), flush=True)


if __name__ == "__main__":
    main()
