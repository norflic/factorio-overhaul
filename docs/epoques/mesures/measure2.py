"""Mesures complémentaires : enveloppe balayée par les têtes de tourelles (64 directions), zone du socle
toujours visible, zone animée de la machine d'assemblage 2, course de la tige de la foreuse, couleurs des
couches lumineuses vanilla."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure as M
from png import decode

G = M.G


def union(masks):
    out = [0.0] * (M.CW * M.CH)
    for m in masks:
        for i, a in enumerate(m):
            if a > out[i]:
                out[i] = a
    return out


def head_layers(kind, d):
    if kind == "gun":
        f = d // 16 + 1
        row = d % 16
        return [M.L(f"gun-turret/hr-gun-turret-shooting-{f}.png", 132, 130, 0, row, shift=M.bp(0, -27.5))]
    else:
        return [M.L("laser-turret/hr-laser-turret-shooting.png", 126, 120, d % 8, d // 8, shift=M.bp(0, -35))]


for kind, base in (("gun", [M.gun_base]), ("laser", [M.las_base[0]])):
    heads = []
    tops = []
    for d in range(64):
        a, _, _ = M.compose(head_layers(kind, d))
        heads.append(a)
        st = M.stats(a)
        tops.append((st["top"], st["left"], st["right"], st["bottom"]))
    u = union(heads)
    su = M.stats(u)
    ab, _, _ = M.compose(base)
    sb = M.stats(ab)
    always = [a if (a >= 0.5 and h < 0.5) else 0.0 for a, h in zip(ab, u)]
    sa = M.stats(always)
    n_base = sum(1 for a in ab if a >= 0.5)
    n_always = sum(1 for a in always if a >= 0.5)
    print(f"== {kind} : tête sur 64 directions")
    print(f"   enveloppe balayée x [{su['left']:+.2f} ; {su['right']:+.2f}] y [{su['top']:+.2f} ; {su['bottom']:+.2f}]  aire {su['area']:.2f} t²")
    print(f"   sommet de la tête : min {min(t[0] for t in tops):+.2f}  max {max(t[0] for t in tops):+.2f} ; bas de la tête max {max(t[3] for t in tops):+.2f}")
    print(f"   socle x [{sb['left']:+.2f} ; {sb['right']:+.2f}] y [{sb['top']:+.2f} ; {sb['bottom']:+.2f}]  aire {sb['area']:.2f} t²")
    if sa:
        print(f"   socle TOUJOURS visible (hors enveloppe de la tête) : {n_always / max(1, n_base) * 100:.0f} % du socle, y [{sa['top']:+.2f} ; {sa['bottom']:+.2f}] x [{sa['left']:+.2f} ; {sa['right']:+.2f}]")
    if os.environ.get("ASCII"):
        print("   enveloppe tête (#) :")
        print(M.ascii_mask(u, 2))
        print("   socle toujours visible (#) :")
        print(M.ascii_mask(always, 2))

# --- Machine d'assemblage 2 : zone animée (pixels qui changent entre les 32 images)
w, h, px = decode(G + "assembling-machine-2/hr-assembling-machine-2.png")
fw, fh = 214, 218
minx = miny = 10 ** 9
maxx = maxy = -1
changed = 0
opaque = 0
for y in range(fh):
    for x in range(fw):
        vals = []
        for f in range(32):
            col, row = f % 8, f // 8
            p = ((row * fh + y) * w + col * fw + x) * 4
            vals.append(tuple(px[p:p + 4]))
        if vals[0][3] >= 128:
            opaque += 1
        if any(abs(v[c] - vals[0][c]) > 8 for v in vals[1:] for c in range(4)):
            changed += 1
            minx, maxx, miny, maxy = min(minx, x), max(maxx, x), min(miny, y), max(maxy, y)
sh = M.bp(0, 4)
tx = lambda x: (x - fw / 2) / 64 + sh[0]
ty = lambda y: (y - fh / 2) / 64 + sh[1]
print("== assembleur 2 : zone animée (32 images)")
print(f"   pixels qui changent : {changed} ({changed / opaque * 100:.0f} % des pixels opaques)  boîte x [{tx(minx):+.2f} ; {tx(maxx + 1):+.2f}] y [{ty(miny):+.2f} ; {ty(maxy + 1):+.2f}]")

# --- Foreuse : course de la tige (30 images de l'animation verticale)
w, h, px = decode(G + "electric-mining-drill/hr-electric-mining-drill.png")
fw, fh = 162, 156
tops = []
bots = []
for f in range(30):
    col, row = f % 6, f // 6
    top = bot = None
    for y in range(fh):
        for x in range(fw):
            p = ((row * fh + y) * w + col * fw + x) * 4
            if px[p + 3] >= 128:
                if top is None:
                    top = y
                bot = y
                break
    tops.append(top)
    bots.append(bot)
sh = M.bp(1, -11)
print("== foreuse : animation verticale (tige)")
print(f"   sommet opaque par image (tuiles) : min {min(tops) / 64 - fh / 128 + sh[1]:+.2f}  max {max(tops) / 64 - fh / 128 + sh[1]:+.2f}")
print("   décalage animé (shift_animation_waypoints nord) : de -0.5 à +0.6 tuile (mining-drill.lua:753)")

# --- Couleurs des couches lumineuses vanilla (moyenne pondérée par l'alpha et luminance max)
LIGHTS = [
    ("steel-furnace/hr-steel-furnace-working.png", "four : working (draw_as_light, additive)"),
    ("steel-furnace/hr-steel-furnace-fire.png", "four : feu 48 images (draw_as_light)"),
    ("steel-furnace/steel-furnace-glow.png", "four : glow (basse résolution seulement)"),
    ("steel-furnace/hr-steel-furnace-ground-light.png", "four : lumière au sol"),
    ("laser-turret/hr-laser-turret-shooting-light.png", "laser : energy_glow_animation"),
    ("electric-mining-drill/hr-electric-mining-drill-N-light.png", "foreuse : DEL nord (teinte d'état)"),
    ("wall/hr-wall-diode-green.png", "mur : diode verte (draw_as_glow)"),
    ("beacon/hr-beacon-light.png", "balise : lumière"),
]
print("== couches lumineuses vanilla")
for path, label in LIGHTS:
    w, h, px = decode(G + path)
    sr = sg = sb = sa = 0.0
    n = 0
    mx = 0
    for i in range(w * h):
        a = px[i * 4 + 3] / 255.0
        if a > 0.02:
            r, g, b = px[i * 4], px[i * 4 + 1], px[i * 4 + 2]
            sr += r * a; sg += g * a; sb += b * a; sa += a
            n += 1
            mx = max(mx, 0.2126 * r + 0.7152 * g + 0.0722 * b)
    print(f"   {label:45s} {w}x{h}  RGB moyen pondéré ({sr / sa:.0f}, {sg / sa:.0f}, {sb / sa:.0f})  alpha moyen {sa / (w * h):.3f}  luminance max {mx:.0f}")
