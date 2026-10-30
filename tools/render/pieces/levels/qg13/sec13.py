"""ESSAI À SEC du QG âge 13 (sans Blender) : construit la géométrie avec des matières factices, compte les sommets par
matière, mesure l'enveloppe à l'écran (tuiles, 32 px/tuile) et le dépassement O au-dessus de l'emprise 16×8.

    py -3.9 tools/render/pieces/levels/qg13/sec13.py
"""
import os
import sys
import types

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.modules["bpy"] = types.ModuleType("bpy")
import mat as MT  # noqa: E402


class _M:
    def __init__(self, name):
        self.name = name


MT.surface = lambda name, *a, **k: _M(name)
MT.verre = lambda name, *a, **k: _M(name)
MT.lumiere = lambda S, name, *a, **k: _M(name)

import geo as G  # noqa: E402
import age13  # noqa: E402

lot = G.Lot(None, "sec")
age13.build(None, lot)
tot = 0
us, vs = [], []
for k in sorted(lot.parts):
    v = lot.parts[k][1]
    tot += len(v)
    print("%-16s %8d sommets" % (k, len(v)))
    for x, y, z in v:
        us.append(x)
        vs.append(-(y + z) * 0.7071)     # écran : tuiles vers le bas
print("total %d sommets, %d pièces posées" % (tot, lot.n))
print("écran x %.2f .. %.2f ; y %.2f .. %.2f (tuiles, origine au centre)" % (min(us), max(us), min(vs), max(vs)))
print("O (sommet au-dessus du bord nord de l'emprise 16x8) = %.2f tuiles" % (-min(vs) - 4.0))
zs = [p[2] for k in lot.parts for p in lot.parts[k][1]]
ys = [p[1] / 1.4142 for k in lot.parts for p in lot.parts[k][1]]
xs = [p[0] for k in lot.parts for p in lot.parts[k][1]]
print("monde x %.2f..%.2f ; y (tuiles) %.2f..%.2f ; z %.2f..%.2f" % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
