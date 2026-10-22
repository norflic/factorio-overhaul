"""Aperçu HORS BLENDER (Python système : numpy + Pillow) de la géométrie de design.py : projection exacte du
pipeline (fo_calib.blender_to_screen_px), peintre (tri en profondeur), Lambert sous le soleil d'ouest du
pipeline. Sert à régler la composition, la masse, le remplissage et le dépassement AVANT de prendre le verrou de
rendu (les indicateurs de détail et de patine, eux, ne se mesurent que sur le rendu Cycles).

    python apercu.py <dossier de sortie> [niveaux 11,21,29,30] [poses N,E]

Écrit <sortie>/apercu-nNN-<pose>.png (64 px/tuile) et apercu.txt : masse, remplissage, part massive, O, et le
dépassement du socle seul (information : depuis la reprise du 22/10 après midi, le socle est prévu en calque « object »).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
import fo_calib as C  # noqa: E402
import design as Dz  # noqa: E402

PPT = 64.0
SS = 2   # suréchantillonnage


def srgb(c):
    return [(12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055) for x in c]


def project(g, angle):
    """Faces projetées : liste (profondeur, polygone écran, couleur RGB 0-255)."""
    ca, sa = math.cos(angle), math.sin(angle)
    ct, st = C.COS_T, C.SIN_T
    sun = C.sun_vector()
    view = (0.0, -st, ct)
    out = []
    for mat, md in g.meshes.items():
        spec = Dz_specs[mat]
        kind, par = spec
        base = par["color"]
        V = np.array(md.v, dtype=np.float64)
        if angle:
            x, y = V[:, 0].copy(), V[:, 1].copy()
            V[:, 0] = ca * x - sa * y
            V[:, 1] = sa * x + ca * y
        U = V[:, 0] * PPT
        W = -(V[:, 1] * ct + V[:, 2] * st) * PPT
        D = -V[:, 1] * st + V[:, 2] * ct
        for f in md.f:
            pts = V[list(f)]
            n = np.zeros(3)
            for i in range(len(f)):
                a, b = pts[i], pts[(i + 1) % len(f)]
                n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
            ln = np.linalg.norm(n)
            if ln < 1e-12:
                continue
            n /= ln
            if n[1] * view[1] + n[2] * view[2] <= 0:
                continue
            if kind == "emit":
                col = srgb([min(1.0, c) for c in base])
            else:
                lam = max(0.0, n[0] * sun[0] + n[1] * sun[1] + n[2] * sun[2])
                k = 0.18 + 1.25 * lam + 0.55 * max(0.0, n[2])
                col = srgb([min(1.0, c * k) for c in base])
            poly = [(float(U[j]) * SS, float(W[j]) * SS) for j in f]
            out.append((float(D[list(f)].mean()), poly, tuple(int(255 * max(0, min(1, c))) for c in col)))
    return out


def raster(faces_list, box):
    """faces_list : listes de faces (socle puis tête : la tête est peinte PAR-DESSUS, comme en jeu)."""
    x0, y0, x1, y1 = box
    W, H = int((x1 - x0) * SS), int((y1 - y0) * SS)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for faces in faces_list:
        for depth, poly, col in sorted(faces, key=lambda t: t[0]):
            pp = [(p[0] - x0 * SS, p[1] - y0 * SS) for p in poly]
            d.polygon(pp, fill=col + (255,))
    return img.resize((W // SS, H // SS), Image.LANCZOS)


def stats(alpha, side, origin):
    """Masse (t²), remplissage, part massive (ouverture 17 px), O : mêmes définitions que la charte (da_lib)."""
    sys.path.insert(0, CHARTE)
    import da_lib as DL
    M = alpha >= 0.5
    ox, oy = origin
    n = M.sum() / PPT ** 2
    ys, xs = np.nonzero(M)
    top = (ys.min() - oy) / PPT
    fx0, fx1 = int(round(ox - side / 2 * 64)), int(round(ox + side / 2 * 64))
    fy0, fy1 = int(round(oy - side / 2 * 64)), int(round(oy + side / 2 * 64))
    fp = np.zeros_like(M)
    fp[fy0:fy1, fx0:fx1] = True
    k = 17
    op = DL.dilate(DL.erode(M, k), k) & M
    return {"masse": n, "remplissage": (M & fp).sum() / ((fy1 - fy0) * (fx1 - fx0)), "massive": op.sum() / M.sum(),
            "O": -top - side / 2, "masse_par_tuile": n / side ** 2}


CHARTE = os.environ.get("FO_CHARTE", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3S\charte\outils")
Dz_specs = {}


def main():
    out = sys.argv[1]
    levels = [int(x) for x in (sys.argv[2] if len(sys.argv) > 2 else "11,21,29,30").split(",")]
    poses = (sys.argv[3] if len(sys.argv) > 3 else "N,E").split(",")
    os.makedirs(out, exist_ok=True)
    rep = []
    for lv in levels:
        side = Dz.LEVELS[lv]["side"]
        gs, specs, _ = Dz.build("n%02d-socle" % lv)
        Dz_specs.clear()
        Dz_specs.update(specs)
        fs = project(gs, 0.0)
        # règle du bord nord : point le plus haut du socle à l'écran
        top_socle = min(min(p[1] for p in poly) for _, poly, _ in fs) / SS / PPT
        o_socle = -top_socle - side / 2
        head_lv = 29 if lv == 30 else lv
        for pose in poses:
            gh, specs_h, ang = Dz.build("n%02d-tete-%s" % (head_lv, pose))
            Dz_specs.update(specs_h)
            fh = project(gh, ang)
            allp = [p for _, poly, _ in fs + fh for p in poly]
            xs = [p[0] / SS for p in allp]
            ys = [p[1] / SS for p in allp]
            box = (math.floor(min(xs)) - 8, math.floor(min(ys)) - 8, math.ceil(max(xs)) + 8, math.ceil(max(ys)) + 8)
            img = raster([fs, fh], box)
            a = np.asarray(img).astype(np.float64)[..., 3] / 255.0
            origin = (-box[0], -box[1])
            st = stats(a, side, origin)
            bg = Image.new("RGBA", img.size, (40, 40, 40, 255))
            bg.alpha_composite(img)
            p = os.path.join(out, "apercu-n%02d-%s.png" % (lv, pose))
            bg.convert("RGB").save(p)
            nverts = sum(len(m.v) for m in gs.meshes.values()) + sum(len(m.v) for m in gh.meshes.values())
            line = ("n%02d %s : masse %.1f t² (%.2f/tuile), remplissage %.2f, massive %.2f, O %.2f (max %.1f), "
                    "O du socle %.2f (info : socle en calque object), sommets %d, pièces posées socle %d tête %d" % (
                        lv, pose, st["masse"], st["masse_par_tuile"], st["remplissage"], st["massive"], st["O"],
                        0.4 * side, o_socle, nverts, sum(gs.counts.values()), sum(gh.counts.values())))
            print(line, flush=True)
            rep.append(line)
    with open(os.path.join(out, "apercu.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(rep) + "\n")


if __name__ == "__main__":
    main()
