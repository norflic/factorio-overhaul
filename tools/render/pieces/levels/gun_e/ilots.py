"""OUTIL COMMUN, BLOQUANT : îlots détachés et trous enfermés (règle d'or 6). FICHIER GELÉ. Python 3.9 (numpy).

    py -3.9 tools/render/pieces/levels/gun_e/ilots.py --out DIR [--epochs 2,…,15] [--kit 2,5] [--diag DIR]
        [--json fichier.json]

Définitions (celles des juges de la passe 3, juge_e.py et juge_ilots.py ; 64 px/tuile, couche main HR) :
  - TROU ENFERMÉ : composante de pixels transparents (alpha < 0,5, connexité 4) qui ne touche pas le bord de l'image ;
    seuil bloquant : 8 px hr pour le plus grand ;
  - ÎLOT DÉTACHÉ (pièce qui flotte, pièce posée hors du socle) : composante opaque (alpha >= 0,5, connexité 8) autre
    que la plus grande, de plus de 8 px hr.
Contrôlés : chaque sprite de socle et de tête seul, puis chaque COMPOSITION de niveau (socle + tête, et socle + pièce
paire + tête), poses E et N, niveaux impairs et pairs. La pièce paire seule n'est pas contrôlée isolément (ses deux
moitiés, aux coins avant, ne se rejoignent qu'à travers le socle). Époque 1 : vanilla + pièce du niveau 2.
Trous VOULUS (sol visible par une arche, un anneau…) : à déclarer par l'intégrateur dans epoques.TROUS_VOULUS
{(époque, partie): [(x, y, rayon) en tuiles depuis le centre de l'entité]} ; un trou dont le centre y tombe est ignoré.
Code de sortie 1 s'il reste un échec : les rendus de production ne se livrent pas.
Avec --diag, un gros plan (×4, fond magenta) de chaque îlot ou trou fautif est écrit pour le regarder.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402
import epoques as E  # noqa: E402

D = K.D
SEUIL = 8


def analyse(alpha_bool):
    """(plus grand trou, total des trous, groupes de trous, [(taille, centre_px)] des trous, [îlots (taille, centre_px,
    boîte)])."""
    a = alpha_bool
    holes = ~a
    sizes, lab = D.components(holes, conn8=False)
    border = set(lab[0, :].tolist()) | set(lab[-1, :].tolist()) | set(lab[:, 0].tolist()) | set(lab[:, -1].tolist())
    trous = []
    for k, n in sizes.items():
        if k in border:
            continue
        ys, xs = np.nonzero(lab == k)
        trous.append((int(n), (float(xs.mean()), float(ys.mean()))))
    sz, lab8 = D.components(a, conn8=True)
    if not sz:
        return trous, []
    main = max(sz, key=sz.get)
    ilots = []
    for k, n in sz.items():
        if k == main or n <= SEUIL:
            continue
        ys, xs = np.nonzero(lab8 == k)
        ilots.append((int(n), (float(xs.mean()), float(ys.mean())), (int(xs.min()), int(ys.min()), int(xs.max()),
                                                                       int(ys.max()))))
    return trous, ilots


def voulus(e, partie):
    return getattr(E, "TROUS_VOULUS", {}).get((e, partie), [])


def filtre_trous(trous, origin, e, partie):
    """Retire les trous déclarés voulus ; origin = position du centre de l'entité en px dans l'image."""
    vv = voulus(e, partie)
    out = []
    for n, (cx, cy) in trous:
        xt, yt = (cx - origin[0]) / 64.0, (cy - origin[1]) / 64.0
        if any((xt - x) ** 2 + (yt - y) ** 2 <= r * r for x, y, r in vv):
            continue
        out.append((n, (cx, cy)))
    return out


def gros_plan(img_rgba, box, dest):
    x0, y0, x1, y1 = box
    H, W = img_rgba.shape[:2]
    x0, y0 = max(0, x0 - 40), max(0, y0 - 40)
    x1, y1 = min(W, x1 + 40), min(H, y1 + 40)
    crop = (np.clip(img_rgba[y0:y1, x0:x1], 0, 1) * 255).astype(np.uint8)
    c = Image.new("RGBA", (x1 - x0, y1 - y0), (255, 0, 255, 255))
    c.alpha_composite(Image.fromarray(crop, "RGBA"))
    c = c.resize((c.width * 4, c.height * 4), Image.NEAREST)
    c.convert("RGB").save(dest)


def controle(nom, lays, e, partie, diag):
    comp = D.compose([dict(l, kind="main") for l in lays if l["kind"] == "main"])
    body = comp["body"]
    a = body[..., 3] >= 0.5
    trous, ilots = analyse(a)
    trous = filtre_trous(trous, comp["origin"], e, partie)
    big = max([n for n, _ in trous], default=0)
    ok = big <= SEUIL and not ilots
    if not ok and diag:
        os.makedirs(diag, exist_ok=True)
        for n, c_, box in ilots:
            gros_plan(body, box, os.path.join(diag, "ilot-%s-%d.png" % (nom, n)))
        for n, (cx, cy) in trous:
            if n > SEUIL:
                gros_plan(body, (int(cx) - 6, int(cy) - 6, int(cx) + 6, int(cy) + 6),
                          os.path.join(diag, "trou-%s-%d.png" % (nom, n)))
    o = comp["origin"]
    return {"objet": nom, "plus_grand_trou": big, "trous_total": int(sum(n for n, _ in trous)),
            "ilots": [{"px": n, "centre_t": [round((c_[0] - o[0]) / 64.0, 2), round((c_[1] - o[1]) / 64.0, 2)]}
                      for n, c_, _ in ilots], "ok": bool(ok)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--epochs", default="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15")
    ap.add_argument("--kit", default="")
    ap.add_argument("--diag", default="")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    rows = []
    eps = [int(x) for x in a.epochs.split(",") if x] + ["k%s" % s for s in a.kit.split(",") if s]
    for e in eps:
        pre = e if isinstance(e, str) else "e%02d" % e
        if e != 1:
            for partie in (["socle"] + ["tete-E", "tete-N"]):
                lays = K.own(a.out, "%s-%s" % (pre, partie), kinds=("main",))
                if lays:
                    rows.append(controle("%s-%s" % (pre, partie), lays, e, partie.split("-")[0], a.diag))
        for pose in ("E", "N"):
            for even in ((False, True) if not isinstance(e, str) else (False,)):
                if e == 1 and not even:
                    continue
                lays = K.level_layers(a.out, e, pose, even, kinds=("main",))
                if not lays:
                    continue
                nom = "%s-niv%s-%s" % (pre, "pair" if even else "impair", pose)
                rows.append(controle(nom, lays, e, "compo", a.diag))
    nb = 0
    for r in rows:
        nb += not r["ok"]
        print("%-22s plus grand trou %4d px (total %4d) ; îlots > %d px : %s  %s" % (
            r["objet"], r["plus_grand_trou"], r["trous_total"], SEUIL,
            ", ".join("%d px en (%.2f, %.2f) t" % (i["px"], i["centre_t"][0], i["centre_t"][1]) for i in r["ilots"])
            or "aucun", "OK" if r["ok"] else "<-- ECHEC"))
    print("[FO-ILOTS] %d contrôles, %d échec(s)" % (len(rows), nb))
    if a.json:
        json.dump(rows, open(a.json, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    sys.exit(1 if nb else 0)


if __name__ == "__main__":
    main()
