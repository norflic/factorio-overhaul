"""APERÇU HORS BLENDER d'un état du kit vaisseau_o (refonte QG, 30/10) : construit la géométrie avec un faux « bpy »,
la projette avec la caméra du jeu (fo_calib.blender_to_screen_px) et la peint face par face (algorithme du peintre,
ombrage plat : soleil d'ouest à 48°), une couleur par matière. Sert à juger la COMPOSITION (masses, silhouette, sens
du nez, collisions) en quelques secondes, sans prendre de place au verrou de rendu. Ce n'est PAS un rendu.

    py -3.9 tools/render/pieces/levels/vaisseau_o/apercu.py --nom qg08 --dest apercu.png [--zoom 1] [--emprise 12x6]
"""
import argparse
import importlib
import math
import os
import sys
import types

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)


class _Mat:
    def __init__(self, name, col=(0.3, 0.3, 0.3), emis=False):
        self.name, self.col, self.emis = name, col, emis

    def get(self, k, d=None):
        return d

    def __setitem__(self, k, v):
        pass


def _faux_bpy():
    bpy = types.ModuleType("bpy")
    sys.modules["bpy"] = bpy
    import mat as MT

    def surface(name, col, **kw):
        if kw.get("bandes"):
            col = tuple(0.5 * (a + b) for a, b in zip(col, kw["bandes"][1]))
        return _Mat(name, col)
    MT.surface = surface
    MT.verre = lambda name, col=(0.02, 0.045, 0.05), reflet=(0.16, 0.24, 0.26): _Mat(name, tuple(0.5 * (a + b) for a, b in zip(col, reflet)))
    MT.lumiere = lambda S, name, col, force=6.0, main=0.35: _Mat(name, col, True)
    return MT


class _S:
    def mat_emissive(self, name, color, strength=8.0, base=(0, 0, 0), main_scale=1.0, crust=None):
        return _Mat(name, color, True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nom", default="qg08")
    ap.add_argument("--dest", required=True)
    ap.add_argument("--zoom", type=int, default=1)
    ap.add_argument("--emprise", default="12x6")
    a = ap.parse_args()
    _faux_bpy()
    import fo_calib as FC
    import geo as G
    mod = importlib.import_module(a.nom)
    if hasattr(mod, "verre_vert"):
        mod.verre_vert = lambda name: _Mat(name, (0.2, 0.42, 0.06))
    lot = G.Lot(None, "ap")
    mod.build(_S(), lot)
    from PIL import Image, ImageDraw
    k = 32.0 * a.zoom / 64.0
    sun = FC.sun_vector()
    tris = []
    for key, (m, verts, faces, uvs) in lot.parts.items():
        col = m.col
        for f in faces:
            P = [verts[i] for i in f]
            if len(P) < 3:
                continue
            n = G.cross(G.sub(P[1], P[0]), G.sub(P[2], P[0]))
            if G.length(n) < 1e-12 and len(P) > 3:
                n = G.cross(G.sub(P[2], P[0]), G.sub(P[3], P[0]))
            n = G.norm(n)
            cam = (0.0, -math.cos(math.radians(FC.THETA_DEG)), math.sin(math.radians(FC.THETA_DEG)))
            if G.dot(n, cam) < 0:
                n = G.mul(n, -1.0)
            lam = max(0.0, G.dot(n, sun)) * 0.85 + 0.18
            if m.emis:
                c = tuple(min(255, int(255 * (0.3 + 0.7 * x))) for x in col)
            else:
                c = tuple(min(255, int(255 * (x * lam * 1.9) ** (1 / 2.2))) for x in col)
            d = sum(p[1] * math.cos(math.radians(FC.THETA_DEG)) - p[2] * math.sin(math.radians(FC.THETA_DEG)) for p in P) / len(P)
            scr = [FC.blender_to_screen_px(*p) for p in P]
            tris.append((d, [(u * k, v * k) for (u, v) in scr], c))
    tris.sort(key=lambda t: -t[0])
    ew, eh = [float(x) for x in a.emprise.split("x")]
    ppt = 32 * a.zoom
    W, H = int((ew + 4) * ppt), int((eh + 7) * ppt)
    ox, oy = W / 2.0, H / 2.0 + 1.5 * ppt
    im = Image.new("RGB", (W, H), (96, 70, 44))
    dr = ImageDraw.Draw(im)
    dr.rectangle([ox - ew / 2 * ppt, oy - eh / 2 * ppt, ox + ew / 2 * ppt, oy + eh / 2 * ppt], outline=(150, 120, 80))
    for d, pts, c in tris:
        dr.polygon([(ox + u, oy + v) for (u, v) in pts], fill=c)
    dr.text((6, 4), "APERCU (pas un rendu) %s : nez attendu a DROITE ; %d faces" % (a.nom, len(tris)), fill=(255, 230, 160))
    im.save(a.dest)
    print(a.dest, im.size, len(tris), "faces")


if __name__ == "__main__":
    main()
