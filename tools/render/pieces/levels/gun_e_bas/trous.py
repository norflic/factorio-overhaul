"""Contrôle BLOQUANT des trous enfermés (lot V3-E, catalogue §A.6) : pixels d'alpha < 0,5 non reliés au bord, dans
chaque couche principale hr ET dans la composition socle (+ pièce) + tête de chaque niveau et pose. Seuil : aucun
groupe de plus de 8 px hr. Image de diagnostic facultative (trous en rouge, ×3).

    py -3.9 trous.py <dossier out> [--diag <dossier>] [--json <sortie.json>]
Code de sortie 1 si un groupe dépasse 8 px.
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402
import fo_checks as FC  # noqa: E402

LIMIT = 8


def holes_of(alpha):
    n, _, holes = FC.enclosed_transparent(alpha)
    if not n:
        return 0, 0, 0, holes
    sizes, _ = K.D.components(holes, conn8=False)
    return n, len(sizes), max(sizes.values()), holes


def diag(img, holes, path):
    rgb = np.zeros(img.shape[:2] + (3,))
    a = img[..., 3:4]
    rgb[:] = img[..., :3] * a + np.array([0.45, 0.35, 0.25]) * (1 - a)
    rgb[holes] = (1, 0, 0)
    im = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    im.resize((im.size[0] * 3, im.size[1] * 3), Image.NEAREST).save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--diag", default="")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    rows = []
    bad = 0
    for p in sorted(glob.glob(os.path.join(a.out, "*", "hr-*-main.png"))):
        img = np.asarray(Image.open(p).convert("RGBA")).astype(np.float64) / 255
        n, ng, big, holes = holes_of(img[..., 3])
        ok = big <= LIMIT
        bad += not ok
        name = os.path.basename(os.path.dirname(p))
        rows.append({"sprite": name, "px": n, "groupes": ng, "plus_grand": big, "ok": ok})
        print("%-16s sprite : %4d px en %3d groupes, plus grand %4d px  %s" % (name, n, ng, big, "OK" if ok else "ECHEC"))
        if a.diag and not ok:
            os.makedirs(a.diag, exist_ok=True)
            diag(img, holes, os.path.join(a.diag, "trous-%s.png" % name))
    # compositions socle (+ pièce) + tête
    for e in range(2, 10):
        for pose in ("E", "N"):
            for even in (False, True):
                lays = K.level_layers(a.out, e, pose, even, kinds=("main",))
                if len(lays) < 2:
                    continue
                comp = K.D.compose([dict(l) for l in lays])
                alpha = comp["body"][..., 3]
                n, ng, big, holes = holes_of(alpha)
                ok = big <= LIMIT
                bad += not ok
                tag = "n%02d-%s" % (2 * e - 1 + even, pose)
                rows.append({"composition": tag, "epoque": e, "pose": pose, "pair": even, "px": n, "groupes": ng,
                             "plus_grand": big, "ok": ok})
                print("%-16s compo  : %4d px en %3d groupes, plus grand %4d px  %s" % (tag, n, ng, big,
                                                                                    "OK" if ok else "ECHEC"))
                if a.diag and not ok:
                    os.makedirs(a.diag, exist_ok=True)
                    diag(comp["body"], holes, os.path.join(a.diag, "trous-%s.png" % tag))
    # époque 1 : vanilla + pièce du niveau 2
    for pose in ("E", "N"):
        lays = K.level_layers(a.out, 1, pose, True, kinds=("main",))
        lays = [l for l in lays if l["kind"] == "main"]
        if len(lays) >= 2:
            comp = K.D.compose([dict(l) for l in lays])
            n, ng, big, holes = holes_of(comp["body"][..., 3])
            ok = big <= LIMIT
            bad += not ok
            rows.append({"composition": "n02-%s" % pose, "epoque": 1, "pose": pose, "pair": True, "px": n,
                         "groupes": ng, "plus_grand": big, "ok": ok})
            print("%-16s compo  : %4d px en %3d groupes, plus grand %4d px  %s (vanilla + pièce)" % (
                "n02-" + pose, n, ng, big, "OK" if ok else "ECHEC"))
    print("BILAN trous enfermés : %d échec(s) sur %d contrôles (seuil : aucun groupe > %d px hr)" % (bad, len(rows),
                                                                                                  LIMIT))
    if a.json:
        json.dump(rows, open(a.json, "w", encoding="utf-8"), indent=1)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
