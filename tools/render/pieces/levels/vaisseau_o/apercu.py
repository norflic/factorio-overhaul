"""APERÇU EN TERRE GLAISE d'un état du kit vaisseau_o, HORS BLENDER (sans le verrou de rendu) : construit l'état avec
le vrai code (geo, forme, l'état), des matières factices (couleur de base seulement), puis rastérise les faces à la
caméra du jeu (u = 64·X, v = −64·(Y cos 45 + Z sin 45)), ombrage plat (soleil d'ouest à 48°), tri du peintre, ombre
portée. Sert à la SILHOUETTE, à la composition et au sens du nez ; jamais aux matières ni à la lumière.
Sorties : <dest>.png (sur sol, emprise tracée) et mesures de forme (remplissage de l'emprise, découpe du contour,
dépassement haut) sur le masque du corps à 64 px/tuile.

    py -3.9 tools/render/pieces/levels/vaisseau_o/apercu.py qg00 <dest.png> [--emprise 8x4] [--zoom 2]
"""
import argparse
import importlib
import math
import os
import sys
import types

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.modules.setdefault("bpy", types.ModuleType("bpy"))


class FakeMat:
    def __init__(self, name, col, emit=False):
        self.name, self.col, self.emit = name, tuple(col), emit


def _patch():
    import mat as MT
    MT.surface = lambda name, col, **kw: FakeMat(name, col)
    MT.verre = lambda name, col=(0.02, 0.045, 0.05), reflet=None: FakeMat(name, (0.05, 0.08, 0.09))
    MT.lumiere = lambda S, name, col, force=6.0, main=0.35: FakeMat(name, col, emit=True)


def srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def construire(nom):
    _patch()
    import geo as G
    mod = importlib.import_module(nom)
    lot = G.Lot(None, "apercu")
    mod.build(types.SimpleNamespace(EXTRA_LIGHTS=[]), lot)
    faces = []
    for key in sorted(lot.parts):
        mat, V, Fs, _ = lot.parts[key]
        for f in Fs:
            faces.append((mat, [V[i] for i in f]))
    return faces, lot.n


def rasteriser(faces, ppt=64):
    ct = st = math.sqrt(0.5)
    el = math.radians(48.0)
    sun = np.array([-math.cos(el), 0.0, math.sin(el)])
    tocam = np.array([0.0, -st, ct])
    us, vs = [], []
    for _, P in faces:
        for p in P:
            us.append(p[0])
            vs.append(-(p[1] * ct + p[2] * st))
    u0, u1 = min(min(us), -4.5) - 0.5, max(max(us), 4.5) + 0.5
    v0, v1 = min(min(vs), -3.0) - 0.5, max(max(vs), 2.5) + 0.8
    W, H = int((u1 - u0) * ppt), int((v1 - v0) * ppt)
    body = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow = Image.new("L", (W, H), 0)
    db, ds = ImageDraw.Draw(body), ImageDraw.Draw(shadow)

    def proj(p):
        return ((p[0] - u0) * ppt, (-(p[1] * ct + p[2] * st) - v0) * ppt)

    for _, P in faces:
        Q = [proj((p[0] - sun[0] * max(0.0, p[2]) / sun[2], p[1], 0.0)) for p in P]
        if len(Q) >= 3:
            ds.polygon(Q, fill=255)
    order = sorted(faces, key=lambda t: -sum(st * p[1] - ct * p[2] for p in t[1]) / len(t[1]))
    for mat, P in order:
        if len(P) < 3:
            continue
        n = np.zeros(3)
        for i in range(len(P)):
            a, b = P[i], P[(i + 1) % len(P)]
            n += ((a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1]))
        ln = np.linalg.norm(n)
        if ln < 1e-12:
            continue
        n /= ln
        if n.dot(tocam) < 0:
            n = -n
        if mat.emit:
            col = tuple(min(1.0, 1.1 * c) for c in mat.col)
        else:
            k = 0.25 + 1.35 * max(0.0, n.dot(sun)) + 0.25 * max(0.0, n[2])
            col = tuple(c * k for c in mat.col)
        db.polygon([proj(p) for p in P], fill=tuple(int(255 * srgb(c)) for c in col) + (255,))
    origin = (-u0 * ppt, -v0 * ppt)
    return body, shadow, origin


def mesures(body, origin, emprise, ppt=64):
    a = np.asarray(body)[..., 3] >= 128
    sw, sh = emprise
    ox, oy = origin
    fx0, fx1 = int(round(ox - sw / 2.0 * ppt)), int(round(ox + sw / 2.0 * ppt))
    fy0, fy1 = int(round(oy - sh / 2.0 * ppt)), int(round(oy + sh / 2.0 * ppt))
    rem = a[fy0:fy1, fx0:fx1].mean()
    ys, xs = np.nonzero(a)
    sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "da")))
    import da_lib as D
    edge = a & ~D.erode(a, 3)
    per = edge.sum() / 3.0
    dec = per * per / (4 * math.pi * max(1, a.sum()))
    return {"remplissage": float(rem), "masse_t2": float(a.sum() / ppt ** 2), "decoupe": float(dec),
            "depassement_haut_t": float((oy - ys.min()) / ppt - sh / 2.0), "gauche_t": float((xs.min() - ox) / ppt),
            "droite_t": float((xs.max() - ox) / ppt), "bas_t": float((ys.max() - oy) / ppt)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("nom")
    ap.add_argument("dest")
    ap.add_argument("--emprise", default="8x4")
    ap.add_argument("--zoom", type=int, default=2)
    a = ap.parse_args()
    emp = tuple(float(x) for x in a.emprise.split("x"))
    faces, n = construire(a.nom)
    body, shadow, origin = rasteriser(faces)
    m = mesures(body, origin, emp)
    W, H = body.size
    sol = Image.new("RGB", (W, H), (120, 82, 46))
    sol.paste((60, 41, 23), (0, 0), shadow.point(lambda v: v // 2))
    sol.paste(body, (0, 0), body)
    dr = ImageDraw.Draw(sol)
    ox, oy = origin
    dr.rectangle([ox - emp[0] * 32, oy - emp[1] * 32, ox + emp[0] * 32, oy + emp[1] * 32], outline=(240, 230, 160))
    dr.text((6, 4), "%s · %d faces · %d pièces · NEZ -> droite (+X) · remplissage %.2f, découpe %.2f, masse %.1f t2" % (
        a.nom, len(faces), n, m["remplissage"], m["decoupe"], m["masse_t2"]), fill=(255, 255, 255))
    if a.zoom == 1:
        sol = sol.resize((W // 2, H // 2), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sol.save(a.dest)
    print(a.dest, sol.size, {k: round(v, 3) for k, v in m.items()})


if __name__ == "__main__":
    main()
