# -*- coding: utf-8 -*-
"""
Mesure de la cheminée V0 validée et des aperçus REJETÉS de V3 phase 1 (mitrailleuse, centre, laser,
assembleur), avec les mêmes fonctions que le vanilla (da_lib.measure).

    python mesure_apercus.py <racine du mod> <dossier cheminée V0 (git show 4599023)> <sortie.json> [aperçus]

Sources (lecture seule) :
  mitrailleuse : .claude/worktrees/wf_1f9884be-7b6-2/tools/render/out/levels/gun/eNN-{socle,socle-piece,tete-E}
                 (niveau impair 2e-1 = socle + tête E ; niveau pair 2e = socle-piece + tête E)
  laser        : .claude/worktrees/wf_1f9884be-7b6-3/tools/render/out/levels/laser/LNN/{base,E}-*.png (canevas)
  assembleur   : .claude/worktrees/wf_1f9884be-7b6-7/tools/render/out/levels/assembler/nNN/hr-assembler-nNN-*.png
  centre       : .claude/worktrees/wf_1f9884be-7b6-1/tools/render/out/levels/centre/nNN/hr-centre-nNN-*.png
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import da_lib as D  # noqa: E402

MOD, V0DIR, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
PREV = sys.argv[4] if len(sys.argv) > 4 else None
WT = os.path.join(MOD, ".claude", "worktrees")
G = os.path.join(WT, "wf_1f9884be-7b6-2", "tools", "render", "out", "levels", "gun")
LZ = os.path.join(WT, "wf_1f9884be-7b6-3", "tools", "render", "out", "levels", "laser")
AS = os.path.join(WT, "wf_1f9884be-7b6-7", "tools", "render", "out", "levels", "assembler")
CE = os.path.join(WT, "wf_1f9884be-7b6-1", "tools", "render", "out", "levels", "centre")
CH = os.path.join(MOD, "graphics", "vitrine", "cheminee")
DATA = os.path.join(os.path.dirname(os.path.dirname(MOD)), "data")

KIND = {"main": "main", "glow": "glow", "light": "light"}


def spec_layers(dirpath, spec):
    """spec : {couche: {file|filename, shift}} -> couches à 64 px/tuile."""
    out = []
    for k in ("main", "glow", "light"):
        if k not in spec:
            continue
        s = spec[k].get("hr", spec[k])
        fn = s.get("file") or s.get("filename")
        p = os.path.join(dirpath, fn)
        if not os.path.exists(p):
            continue
        out.append({"img": D.load_rgba(p).copy(), "shift": tuple(s["shift"]), "kind": KIND[k], "file": fn})
    return out


def save_preview(comp, path):
    b = comp["body"]
    im = Image.fromarray((np.clip(b, 0, 1) * 255).astype(np.uint8), "RGBA")
    bg = Image.new("RGBA", im.size, (40, 40, 40, 255))
    bg.alpha_composite(im)
    bg.convert("RGB").save(path)


results = []


def run(fam, level, epoch, layers, side, extra=None):
    if not layers:
        return
    comp = D.compose(layers)
    r = D.measure(comp, side, "%s-n%02d" % (fam, level))
    if r is None:
        return
    r.update({"famille": fam, "niveau": level, "epoque": epoch, "couches": [(l["file"], l["kind"]) for l in layers]})
    if extra:
        r.update(extra)
    results.append(r)
    if PREV:
        save_preview(comp, os.path.join(PREV, "%s-n%02d.png" % (fam, level)))


# ---------------- cheminée V0 (validée, 21/10) et V0b finale (dépôt) ----------------
def lua_shifts(path):
    import re
    s = open(path, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'filename = "[^"]*/(hr-[^"]+)",\s*height = (\d+),\s*shift = \{ ([-\d.]+), ([-\d.]+) \},\s*width = (\d+)', s):
        out[m.group(1)] = (float(m.group(3)), float(m.group(4)))
    return out


for tag, d in (("cheminee-V0", V0DIR), ("cheminee-V0b", CH)):
    sh = lua_shifts(os.path.join(d, "sprites.lua"))
    lay = []
    for k in ("main", "glow", "light"):
        fn = "hr-cheminee-seule-%s.png" % k
        lay.append({"img": D.load_rgba(os.path.join(d, fn)).copy(), "shift": sh[fn], "kind": k, "file": fn})
    run(tag, 0, 3, lay, 1)
    # four en pierre vanilla + cheminée (la composition validée de la vitrine)
    dump = D.parse_dump(open(os.path.join(os.environ["FO_DUMPS"], "furnace_stone-furnace.txt"),
                             encoding="utf-8", errors="replace").read())
    wvs = dump["working_visualisations"]
    van = D.vanilla_layers([(dump["animation"], 0, None), (wvs[0]["animation"], 0, "glow")], DATA)
    lay2 = []
    for k in ("main", "glow", "light"):
        fn = "hr-cheminee-four-%s.png" % k
        lay2.append({"img": D.load_rgba(os.path.join(d, fn)).copy(), "shift": sh[fn], "kind": k, "file": fn})
    run(tag + "-sur-four", 0, 3, van + lay2, 2)

# ---------------- mitrailleuse (pose E) ----------------
for e in range(2, 16):
    for lvl, socle in ((2 * e - 1, "e%02d-socle" % e), (2 * e, "e%02d-socle-piece" % e)):
        lay = []
        for part in (socle, "e%02d-tete-E" % e):
            p = os.path.join(G, part, "spec.json")
            if os.path.exists(p):
                lay += spec_layers(os.path.join(G, part), json.load(open(p, encoding="utf-8"))["layers"])
        run("mitrailleuse", lvl, e, lay, 2)

# ---------------- laser (pose E) ----------------
for n in range(2, 31):
    d = os.path.join(LZ, "L%02d" % n)
    if not os.path.isdir(d):
        continue
    lay = []
    # niveau pair : socle du niveau + tête du niveau impair précédent (la tête ne change pas)
    head_dir = d if n % 2 == 1 else os.path.join(LZ, "L%02d" % (n - 1))
    if not os.path.exists(os.path.join(head_dir, "E.json")):
        continue
    for part, pd in (("base", d), ("E", head_dir)):
        js = json.load(open(os.path.join(pd, part + ".json"), encoding="utf-8"))
        for k in ("main", "glow", "light"):
            if k in js["layers"]:
                spec = [("%s-%s.png" % (part, k), js["layers"][k]["origin_px"], k)]
                lay += D.from_canvas_files(spec, pd)
    run("laser", n, (n + 1) // 2, lay, 2)

# ---------------- assembleur ----------------
for n in range(2, 31):
    d = os.path.join(AS, "n%02d" % n)
    p = os.path.join(d, "n%02d.json" % n)
    if not os.path.exists(p):
        continue
    js = json.load(open(p, encoding="utf-8"))
    run("assembleur", n, (n + 1) // 2, spec_layers(d, js["spec"]), 3)

# ---------------- centre (niveau = époque) ----------------
for n in range(1, 16):
    d = os.path.join(CE, "n%02d" % n)
    p = os.path.join(d, "render.json")
    if not os.path.exists(p):
        continue
    js = json.load(open(p, encoding="utf-8"))
    run("centre", n, n, spec_layers(d, js["spec"]), 4)

json.dump(results, open(OUT, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
for r in results:
    print("%-20s ep=%2d lap=%5.1f cont=%.3f pc/t2=%5.1f cl7=%5.1f S=%.2f sat=%.3f satHL=%.3f froid=%.3f plage=%.3f O=%.2f fill=%.2f mass=%.2f massive=%.2f grain=%.2f creux=%.3f p50=%.0f p95=%.0f"
          % (r["nom"], r["epoque"], r["laplacien_moyen"], r["part_contours"], r["petites_pieces_par_tuile2"],
             r["contraste_local_7px"], r["saturation_moyenne"], r["part_saturee"], r["part_saturee_hors_lumineux"],
             r["part_saturee_froide_hors_lumineux"], r["plus_grande_plage_saturee_part"],
             r["O_depassement_haut"], r["remplissage_emprise"], r["masse_par_tuile_emprise"], r["part_massive"],
             r["grain_surfaces"], r["part_creux_sombres"], r["lum_p50"], r["lum_p95"]))
