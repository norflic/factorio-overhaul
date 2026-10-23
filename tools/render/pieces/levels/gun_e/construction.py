"""CONTRÔLE DE CONSTRUCTION (passe 5, deuxième temps du kit) : construit des variantes de la mitrailleuse dans Blender
SANS RENDU et écrit leur EMPREINTE (pièces par type, sommets, objets, et une somme SHA-1 de la géométrie de chaque objet :
matière, style, sommets arrondis au 1/100 000, faces). Deux empreintes égales = même géométrie, mêmes matières aux
mêmes endroits. Sert à prouver qu'un changement du kit ne change RIEN quand ses clés valent None. FICHIER DU KIT.

TOUJOURS par le verrou de rendu (interdit n° 6) :
    python tools/render/with_render_lock.py -- blender -b --factory-startup -noaudio --python-exit-code 1
        -P tools/render/pieces/levels/gun_e/construction.py -- --out empreinte.json [--names a,b | --tout]
        [--habillage pionnier|fusion|legende]
--tout : les 72 variantes (e01-piece, eNN-socle|piece|tete-N|tete-E pour N = 2 à 15, kS-socle|tete-N|tete-E).
"""
import argparse
import hashlib
import json
import os
import struct
import sys
import time

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402
import importlib.util  # noqa: E402


def empreinte(objs):
    out = []
    for o in sorted(objs, key=lambda o: o.name):
        if o.type != "MESH":
            continue
        me = o.data
        h = hashlib.sha1()
        h.update(o.name.encode("utf-8"))
        h.update(",".join(m.name for m in me.materials if m).encode("utf-8"))
        for v in me.vertices:
            h.update(struct.pack("<3q", *(int(round(c * 100000)) for c in v.co)))
        for p in me.polygons:
            h.update(struct.pack("<%di" % len(p.vertices), *p.vertices))
        out.append({"objet": o.name, "sommets": len(me.vertices), "faces": len(me.polygons), "sha1": h.hexdigest()})
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", default="")
    ap.add_argument("--tout", action="store_true")
    ap.add_argument("--out", required=True)
    ap.add_argument("--habillage", default="")
    a = ap.parse_args(argv)
    if a.habillage:
        os.environ["FO_HABILLAGE_ESSAI"] = a.habillage
    spec = importlib.util.spec_from_file_location("gune_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    names = sorted(piece.PIECE["variants"]) if a.tout else [n for n in a.names.split(",") if n]
    res = {}
    t0 = time.time()
    for name in names:
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        info = piece.build(S, C, name)
        bpy.context.view_layer.update()
        objs = S.piece_objects()
        emp = empreinte(objs)
        h = hashlib.sha1("".join(e["sha1"] for e in emp).encode("ascii")).hexdigest()
        res[name] = {"pieces": info["count"], "nb_pieces": sum(info["count"].values()), "halos": info["halos"],
                     "sommets": sum(e["sommets"] for e in emp), "objets": len(emp), "sha1": h, "detail": emp}
        print("[FO-CONSTRUCTION] %s %d pièces %d sommets %d objets %s" % (
            name, res[name]["nb_pieces"], res[name]["sommets"], len(emp), h[:12]), flush=True)
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump({"dossier": HERE, "habillage": a.habillage or None, "secondes": round(time.time() - t0, 1),
                   "variantes": res}, f, indent=1, sort_keys=True)
    print("[FO-CONSTRUCTION] %d variantes en %.0f s -> %s" % (len(names), time.time() - t0, a.out), flush=True)


main()
