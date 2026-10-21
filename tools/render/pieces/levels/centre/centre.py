"""Centre de commandement, 15 niveaux (= 15 époques) : pièce source du pipeline V0 (lot V3-a, phase 1).

Variantes : « nEE » (EE = époque 01 à 15), avec suffixes facultatifs :
  -jour : émissifs éteints (époques 1 et 2 : la lumière n'existe que la nuit) ;
  -nuit : émissifs allumés (passes lueur et halo des époques 1 et 2) ;
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
        bpy.context.view_layer.update()
        rows = []
        for o in sorted(S.piece_objects(), key=lambda o: o.name):
            if o.type != "MESH":
                continue
            xs, ys, zs = [], [], []
            for c in o.bound_box:
                w = o.matrix_world @ __import__("mathutils").Vector(c)
                xs.append(w.x)
                ys.append(-w.y / C.TILE_DEPTH_UNITS)
                zs.append(w.z)
            rows.append({"name": o.name, "role": o.get("fo_role", "mass"),
                         "x": [round(min(xs), 3), round(max(xs), 3)], "ty": [round(min(ys), 3), round(max(ys), 3)],
                         "z": [round(min(zs), 3), round(max(zs), 3)]})
        with open(dump, "w", encoding="utf-8") as f:
            json.dump({"variant": variant, "objects": rows}, f, indent=0)
