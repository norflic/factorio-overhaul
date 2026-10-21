"""Zone animée de la machine d'assemblage 2 selon le seuil de variation, et part de la surface en mouvement."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png import decode

G = "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/data/base/graphics/entity/"
w, h, px = decode(G + "assembling-machine-2/hr-assembling-machine-2.png")
fw, fh = 214, 218
amp = {}
opaque = 0
for y in range(fh):
    for x in range(fw):
        base = ((0 * fh + y) * w + x) * 4
        if px[base + 3] >= 128:
            opaque += 1
        m = 0
        for f in range(1, 32):
            col, row = f % 8, f // 8
            p = ((row * fh + y) * w + col * fw + x) * 4
            for c in range(4):
                d = abs(px[p + c] - px[base + c])
                if d > m:
                    m = d
        amp[(x, y)] = m
tx = lambda x: (x - fw / 2) / 64 + 0
ty = lambda y: (y - fh / 2) / 64 + 4 / 32
for thr in (8, 32, 96):
    pts = [k for k, v in amp.items() if v > thr]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    print(f"seuil {thr:3d} : {len(pts)} pixels ({len(pts) / opaque * 100:.0f} % des opaques)  x [{tx(min(xs)):+.2f} ; {tx(max(xs) + 1):+.2f}]  y [{ty(min(ys)):+.2f} ; {ty(max(ys) + 1):+.2f}]")
# carte grossière (1 caractère = 8x16 px) des pixels qui changent de plus de 32
for y0 in range(0, fh, 16):
    row = ""
    for x0 in range(0, fw, 8):
        n = c = 0
        for y in range(y0, min(fh, y0 + 16)):
            for x in range(x0, min(fw, x0 + 8)):
                n += 1
                if amp[(x, y)] > 32:
                    c += 1
        f = c / n
        row += "#" if f > 0.5 else ("+" if f > 0.15 else ".")
    print("   " + row)
