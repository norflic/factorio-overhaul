"""Centre de commandement, 15 niveaux (= 15 époques) : pièce source du pipeline V0 (lot V3-a, phase 1).

Variantes : « nEE » (EE = époque 01 à 15), avec suffixes facultatifs :
  -jour : émissifs éteints (verre sombre de leur teinte) : couches main, ao et shadow de TOUTES les époques
          (correction V3 du 21/10 : la couche principale ne doit pas contenir l'émission que la lueur
          additive apporte déjà) ; sans suffixe : émissifs allumés, couches glow et light ;
  -sil  : sans les couches plates au sol (masque D1-3 amendé, Q13) ;
  -mass : sans couches plates ni tiges fines (mesure de O, bible §1.4).
Le pilote est render_centre.py (même dossier) ; il appelle tools/render/fo_blender.py, inchangé.
"""
import importlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

PIECE = {
    "name": "centre",
    "variants": {"n%02d" % e: {"dest": "levels/centre/e%02d" % e, "anchor_tiles": (0.0, 0.0)} for e in range(1, 16)},
    "margin_px": 40,
}


def parse(variant):
    parts = variant.split("-")
    return int(parts[0][1:]), set(parts[1:])


def build(S, C, variant):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import centre_kit
    import centre_params as PR
    e, flags = parse(variant)
    era = (e - 1) // 3 + 1
    mod = importlib.import_module("centre_ere%d" % era)
    k = centre_kit.Kit(S, C, e, flags, gain=PR.ALBEDO_GAIN[e])
    getattr(mod, "build_e%02d" % e)(k)
    # sources de la passe halo : une seule liste (centre_params.HALO), partagée avec le post-traitement
    if "sil" not in flags and "mass" not in flags:
        for i, (x, ty, z, col, pw, *_r) in enumerate(PR.HALO.get(e, [])):
            k.halo(x, ty, z, col, pw, radius=0.06, name="halo_%d" % i)
    dump = os.environ.get("FO_CENTRE_DUMP")
    if dump:
        import bpy
        from mathutils import Vector
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        rows = []
        for o in sorted(S.piece_objects(), key=lambda o: o.name):
            if o.type != "MESH":
                continue
            xs, ys, zs = [], [], []
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                xs.append(w.x)
                ys.append(-w.y / C.TILE_DEPTH_UNITS)
                zs.append(w.z)
            # enveloppe convexe EXACTE de la projection à l'écran (sommets du maillage évalué, modificateurs
            # compris) : u = x, v = ty - 0,707·z, en tuiles (mesure des dépassements, mesures_d1.events)
            oe = o.evaluated_get(dg)
            me = oe.to_mesh()
            mw = o.matrix_world
            pts = []
            for vtx in me.vertices:
                w = mw @ vtx.co
                pts.append((round(w.x, 4), round(-w.y / C.TILE_DEPTH_UNITS - K45 * w.z, 4)))
            oe.to_mesh_clear()
            rows.append({"name": o.name, "role": o.get("fo_role", "mass"),
                         "x": [round(min(xs), 3), round(max(xs), 3)], "ty": [round(min(ys), 3), round(max(ys), 3)],
                         "z": [round(min(zs), 3), round(max(zs), 3)], "hull": _hull(pts)})
        with open(dump, "w", encoding="utf-8") as f:
            json.dump({"variant": variant, "objects": rows}, f, indent=0)


K45 = 0.5 ** 0.5


def _hull(pts):
    """Enveloppe convexe 2D (chaîne monotone d'Andrew), points arrondis au 1/1000 de tuile."""
    P = sorted(set((round(u, 3), round(v, 3)) for u, v in pts))
    if len(P) <= 2:
        return [list(p) for p in P]

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in P:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(P):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return [list(p) for p in lo[:-1] + up[:-1]]
