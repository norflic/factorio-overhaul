"""Mesures des silhouettes vanilla (niveau 1 des 7 familles) pour la bible des époques (lot V1).

Composition des couches hr (64 px par tuile, échelle 0,5) sur une toile en coordonnées de tuiles centrée
sur l'entité. Masque = alpha >= 128. Les couches d'ombre sont composées à part.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png import decode

G = "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/data/base/graphics/entity/"
PPT = 64  # pixels de toile par tuile
X0, X1, Y0, Y1 = -5, 5, -7, 5  # étendue de la toile en tuiles
CW, CH = (X1 - X0) * PPT, (Y1 - Y0) * PPT

_cache = {}


def img(path):
    if path not in _cache:
        _cache[path] = decode(G + path)
    return _cache[path]


def bp(x, y):
    return (x / 32.0, y / 32.0)


def L(path, fw, fh, col=0, row=0, scale=0.5, shift=(0, 0), kind="body"):
    return dict(path=path, fw=fw, fh=fh, col=col, row=row, scale=scale, shift=shift, kind=kind)


def homothety(layers, f):
    out = []
    for l in layers:
        m = dict(l)
        m["scale"] = l["scale"] * f
        m["shift"] = (l["shift"][0] * f, l["shift"][1] * f)
        out.append(m)
    return out


def compose(layers):
    """Renvoie (alpha_body, rgb_body, alpha_shadow) : listes de taille CW*CH."""
    a_body = [0.0] * (CW * CH)
    rgb = [[0.0, 0.0, 0.0] for _ in range(CW * CH)]
    a_sh = [0.0] * (CW * CH)
    for l in layers:
        w, h, px = img(l["path"])
        k = 2.0 * l["scale"]  # pixels de toile par pixel source
        dw, dh = l["fw"] * k, l["fh"] * k
        cx = (l["shift"][0] - X0) * PPT
        cy = (l["shift"][1] - Y0) * PPT
        left, top = cx - dw / 2.0, cy - dh / 2.0
        sx0, sy0 = l["col"] * l["fw"], l["row"] * l["fh"]
        for ty in range(max(0, int(math.floor(top))), min(CH, int(math.ceil(top + dh)))):
            sy = int((ty + 0.5 - top) / k)
            if sy < 0 or sy >= l["fh"]:
                continue
            for tx in range(max(0, int(math.floor(left))), min(CW, int(math.ceil(left + dw)))):
                sx = int((tx + 0.5 - left) / k)
                if sx < 0 or sx >= l["fw"]:
                    continue
                p = ((sy0 + sy) * w + (sx0 + sx)) * 4
                a = px[p + 3] / 255.0
                if a <= 0:
                    continue
                i = ty * CW + tx
                if l["kind"] == "shadow":
                    a_sh[i] = a + a_sh[i] * (1 - a)
                else:
                    c = rgb[i]
                    for j in range(3):
                        c[j] = px[p + j] / 255.0 * a + c[j] * (1 - a)
                    a_body[i] = a + a_body[i] * (1 - a)
    return a_body, rgb, a_sh


def stats(mask_a, thr=0.5):
    xs, ys, n = [], [], 0
    minx = miny = 10 ** 9
    maxx = maxy = -1
    sx = sy = 0
    for i, a in enumerate(mask_a):
        if a >= thr:
            x, y = i % CW, i // CW
            n += 1
            sx += x
            sy += y
            if x < minx: minx = x
            if x > maxx: maxx = x
            if y < miny: miny = y
            if y > maxy: maxy = y
    if n == 0:
        return None
    t = lambda v, o: v / PPT + o
    return dict(left=t(minx, X0), right=t(maxx + 1, X0), top=t(miny, Y0), bottom=t(maxy + 1, Y0),
                area=n / PPT ** 2, cx=t(sx / n + 0.5, X0), cy=t(sy / n + 0.5, Y0))


def iou(a1, a2, thr=0.5):
    inter = uni = 0
    for p, q in zip(a1, a2):
        m1, m2 = p >= thr, q >= thr
        if m1 and m2: inter += 1
        if m1 or m2: uni += 1
    return inter / uni if uni else 0.0


def color_stats(a_body, rgb, thr=0.5):
    lum = []
    sr = sg = sb = sw = 0.0
    sat = 0.0
    for a, c in zip(a_body, rgb):
        if a >= thr:
            r, g, b = (c[0] / a, c[1] / a, c[2] / a)  # couleur non prémultipliée
            sr += r; sg += g; sb += b; sw += 1
            lum.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
            mx, mn = max(r, g, b), min(r, g, b)
            sat += (mx - mn) / mx if mx > 0 else 0
    lum.sort()
    q = lambda f: lum[min(len(lum) - 1, int(f * len(lum)))]
    return dict(r=sr / sw * 255, g=sg / sw * 255, b=sb / sw * 255, l5=q(0.05) * 255, l50=q(0.5) * 255,
                l95=q(0.95) * 255, sat=sat / sw)


def footprint_cover(a_body, size, thr=0.5):
    half = size / 2.0
    inside = tot = 0
    x0, x1 = int((-half - X0) * PPT), int((half - X0) * PPT)
    y0, y1 = int((-half - Y0) * PPT), int((half - Y0) * PPT)
    for y in range(y0, y1):
        for x in range(x0, x1):
            tot += 1
            if a_body[y * CW + x] >= thr: inside += 1
    n_all = sum(1 for a in a_body if a >= thr)
    return inside / tot, (n_all - inside) / PPT ** 2


def ascii_mask(a_body, size, thr=0.5, cx=8, cy=16):
    st = stats(a_body, thr)
    if not st: return ""
    lines = []
    half = size / 2.0
    x_from = min(st["left"], -half) - 0.25
    x_to = max(st["right"], half) + 0.25
    y_from = min(st["top"], -half) - 0.25
    y_to = max(st["bottom"], half) + 0.25
    y = y_from
    while y < y_to:
        row = ""
        x = x_from
        while x < x_to:
            # cellule : fraction couverte
            px0, py0 = int((x - X0) * PPT), int((y - Y0) * PPT)
            n = c = 0
            for yy in range(py0, min(CH, py0 + cy)):
                for xx in range(px0, min(CW, px0 + cx)):
                    n += 1
                    if a_body[yy * CW + xx] >= thr: c += 1
            on_edge = abs(abs(x + cx / PPT / 2) - half) < cx / PPT / 2 and abs(y + cy / PPT / 2) <= half or \
                      abs(abs(y + cy / PPT / 2) - half) < cy / PPT / 2 and abs(x + cx / PPT / 2) <= half
            f = c / n if n else 0
            ch = "#" if f > 0.6 else ("+" if f > 0.2 else ("." if on_edge else " "))
            row += ch
            x += cx / PPT
        lines.append(row.rstrip())
        y += cy / PPT
    return "\n".join(lines)


FAM = {}
# --- Mitrailleuse (turrets.lua:744-819 socle, 112-319 tête ; tête « prepared » direction 0 = nord)
gun_base = L("gun-turret/hr-gun-turret-base.png", 150, 118, shift=bp(0.5, -1))
FAM["gun-N"] = (2, [gun_base, L("gun-turret/hr-gun-turret-shooting-1.png", 132, 130, 0, 0, shift=bp(0, -27.5)),
                    L("gun-turret/hr-gun-turret-shooting-shadow-1.png", 250, 124, 0, 0, shift=bp(22, 2.5), kind="shadow")])
FAM["gun-E"] = (2, [gun_base, L("gun-turret/hr-gun-turret-shooting-2.png", 132, 130, 0, 0, shift=bp(0, -27.5)),
                    L("gun-turret/hr-gun-turret-shooting-shadow-2.png", 250, 124, 0, 0, shift=bp(22, 2.5), kind="shadow")])
FAM["gun-folded"] = (2, [gun_base, L("gun-turret/hr-gun-turret-raising.png", 130, 126, 0, 0, shift=bp(0, -26.5)),
                         L("gun-turret/hr-gun-turret-raising-shadow.png", 250, 124, 0, 0, shift=bp(19, 2.5), kind="shadow")])
# --- Laser (turrets.lua:948-995 socle, 413-515 tête ; 64 directions, 8 colonnes)
las_base = [L("laser-turret/hr-laser-turret-base.png", 138, 104, shift=bp(-0.5, 2)),
            L("laser-turret/hr-laser-turret-base-shadow.png", 132, 82, shift=bp(6, 3), kind="shadow")]
FAM["laser-N"] = (2, las_base + [L("laser-turret/hr-laser-turret-shooting.png", 126, 120, 0, 0, shift=bp(0, -35)),
                                 L("laser-turret/hr-laser-turret-shooting-shadow.png", 170, 92, 0, 0, shift=bp(50.5, 2.5), kind="shadow")])
FAM["laser-E"] = (2, las_base + [L("laser-turret/hr-laser-turret-shooting.png", 126, 120, 0, 2, shift=bp(0, -35)),
                                 L("laser-turret/hr-laser-turret-shooting-shadow.png", 170, 92, 0, 2, shift=bp(50.5, 2.5), kind="shadow")])
FAM["laser-folded"] = (2, las_base + [L("laser-turret/hr-laser-turret-raising.png", 130, 126, 0, 0, shift=bp(0, -32.5)),
                                      L("laser-turret/hr-laser-turret-raising-shadow.png", 182, 96, 0, 0, shift=bp(47, 2.5), kind="shadow")])
# --- Mur (entities.lua:4990-5380)
FAM["wall-single"] = (1, [L("wall/hr-wall-single.png", 64, 86, shift=bp(0, -5)),
                          L("wall/hr-wall-single-shadow.png", 98, 60, shift=bp(10, 17), kind="shadow")])
FAM["wall-horizontal"] = (1, [L("wall/hr-wall-horizontal.png", 64, 92, shift=bp(0, -2)),
                              L("wall/hr-wall-horizontal-shadow.png", 124, 68, shift=bp(14, 15), kind="shadow")])
FAM["wall-vertical"] = (1, [L("wall/hr-wall-vertical.png", 64, 134, shift=bp(0, 8)),
                            L("wall/hr-wall-vertical-shadow.png", 98, 110, shift=bp(10, 29), kind="shadow")])
FAM["wall-t_up"] = (1, [L("wall/hr-wall-t.png", 64, 134, shift=bp(0, 7))])
FAM["wall-corner_right_down"] = (1, [L("wall/hr-wall-corner-right.png", 64, 128, shift=bp(0, 7))])
FAM["wall-corner_left_down"] = (1, [L("wall/hr-wall-corner-left.png", 64, 134, shift=bp(0, 7))])
FAM["wall-ending_right"] = (1, [L("wall/hr-wall-ending-right.png", 64, 92, shift=bp(0, -3))])
FAM["wall-ending_left"] = (1, [L("wall/hr-wall-ending-left.png", 64, 92, shift=bp(0, -3))])
FAM["wall-filling"] = (1, [L("wall/hr-wall-filling.png", 48, 56, shift=bp(0, -1))])
# --- Foreuse électrique (mining-drill.lua:441-747 corps, 820-1085 visualisations, 2471-2581 intégration)
FAM["drill-N"] = (3, [L("electric-mining-drill/hr-electric-mining-drill-N.png", 190, 208, shift=bp(0, -4)),
                      L("electric-mining-drill/hr-electric-mining-drill.png", 162, 156, 0, 0, shift=bp(1, -11)),
                      L("electric-mining-drill/hr-electric-mining-drill-N-output.png", 60, 66, 0, 0, shift=bp(-3, -44)),
                      L("electric-mining-drill/hr-electric-mining-drill-N-shadow.png", 212, 204, shift=bp(6, -3), kind="shadow")])
FAM["drill-E"] = (3, [L("electric-mining-drill/hr-electric-mining-drill-E.png", 192, 188, shift=bp(0, -4)),
                      L("electric-mining-drill/hr-electric-mining-drill-horizontal.png", 80, 160, 0, 0, shift=bp(2, -12)),
                      L("electric-mining-drill/hr-electric-mining-drill-E-output.png", 50, 74, 0, 0, shift=bp(30, -8)),
                      L("electric-mining-drill/hr-electric-mining-drill-horizontal-front.png", 66, 154, 0, 0, shift=bp(-3, 3)),
                      L("electric-mining-drill/hr-electric-mining-drill-E-front.png", 136, 148, shift=bp(21, 10)),
                      L("electric-mining-drill/hr-electric-mining-drill-E-shadow.png", 222, 182, shift=bp(10, 2), kind="shadow")])
FAM["drill-S"] = (3, [L("electric-mining-drill/hr-electric-mining-drill-S.png", 184, 192, shift=bp(0, -1)),
                      L("electric-mining-drill/hr-electric-mining-drill.png", 162, 156, 0, 0, shift=bp(1, -11)),
                      L("electric-mining-drill/hr-electric-mining-drill-S-output.png", 84, 56, 0, 0, shift=bp(-1, 34)),
                      L("electric-mining-drill/hr-electric-mining-drill-S-front.png", 190, 104, shift=bp(0, 27)),
                      L("electric-mining-drill/hr-electric-mining-drill-S-shadow.png", 212, 204, shift=bp(6, 2), kind="shadow")])
FAM["drill-W"] = (3, [L("electric-mining-drill/hr-electric-mining-drill-W.png", 192, 188, shift=bp(0, -4)),
                      L("electric-mining-drill/hr-electric-mining-drill-horizontal.png", 80, 160, 0, 0, shift=bp(2, -12)),
                      L("electric-mining-drill/hr-electric-mining-drill-W-output.png", 50, 60, 0, 0, shift=bp(-31, -13)),
                      L("electric-mining-drill/hr-electric-mining-drill-horizontal-front.png", 66, 154, 0, 0, shift=bp(-3, 3)),
                      L("electric-mining-drill/hr-electric-mining-drill-W-front.png", 134, 140, shift=bp(-22, 12)),
                      L("electric-mining-drill/hr-electric-mining-drill-W-shadow.png", 200, 182, shift=bp(-5, 2), kind="shadow")])
FAM["drill-N-integration"] = (3, [L("electric-mining-drill/hr-electric-mining-drill-N-integration.png", 216, 218, shift=bp(-1, 1))])
# --- Four en acier (entities.lua:7274-7317)
FAM["furnace"] = (2, [L("steel-furnace/hr-steel-furnace.png", 171, 174, shift=bp(-1.25, 2)),
                      L("steel-furnace/hr-steel-furnace-shadow.png", 277, 85, shift=bp(39.25, 11.25), kind="shadow")])
# --- Machine d'assemblage 2 (entities.lua:4748-4795), image 0
FAM["assembler"] = (3, [L("assembling-machine-2/hr-assembling-machine-2.png", 214, 218, 0, 0, shift=bp(0, 4)),
                        L("assembling-machine-2/hr-assembling-machine-2-shadow.png", 196, 163, 0, 0, shift=bp(12, 4.75), kind="shadow")])


# --- Centre de commandement (prototypes/levels.lua:252-266), niveaux 1, 4 et 7
def moved(l, dx, dy, s):
    m = dict(l)
    m["shift"] = (l["shift"][0] * s + dx, l["shift"][1] * s + dy)
    m["scale"] = l["scale"] * s
    return m


radar = L("radar/hr-radar.png", 196, 254, 0, 0, shift=bp(1, -16))
beacon_top = L("beacon/hr-beacon-top.png", 96, 140, 0, 0, shift=bp(3, -19))


def cc(n):
    layers = [L("roboport/hr-roboport-base.png", 228, 277, shift=bp(2, 7.75)),
              L("roboport/hr-roboport-shadow.png", 294, 201, shift=bp(28.5, 19.25), kind="shadow"),
              L("roboport/hr-roboport-base-patch.png", 138, 100, shift=bp(1.5, 5)),
              L("roboport/hr-roboport-door-up.png", 97, 38, 0, 0, shift=bp(-0.25, -29.5)),
              L("roboport/hr-roboport-door-down.png", 97, 41, 0, 0, shift=bp(-0.25, -9.75))]
    rs = 0.58 if n >= 7 else 0.46
    layers.append(moved(radar, -1.05, -1.45 - (0.1 if n >= 7 else 0), rs))
    if n >= 4: layers.append(moved(beacon_top, 1.15, -1.25, 0.75))
    if n >= 7: layers.append(moved(beacon_top, 1.45, 0.35, 0.65))
    s = 1 + 0.012 * (n - 1)
    return homothety(layers, s) if n > 1 else layers


FAM["command-1"] = (4, cc(1))

only = sys.argv[1:]
results = {}
for name, (size, layers) in (FAM.items() if __name__ == "__main__" else []):
    if only and name not in only:
        continue
    a, rgb, sh = compose(layers)
    st = stats(a)
    shs = stats(sh)
    cs = color_stats(a, rgb)
    cov, out_area = footprint_cover(a, size)
    results[name] = (size, a)
    half = size / 2.0
    print(f"== {name} (emprise {size}x{size})")
    print(f"   boîte visuelle (tuiles, centre = 0) : x [{st['left']:+.2f} ; {st['right']:+.2f}]  y [{st['top']:+.2f} ; {st['bottom']:+.2f}]")
    print(f"   largeur {st['right'] - st['left']:.2f}  hauteur {st['bottom'] - st['top']:.2f}  dépassement au-dessus de l'emprise {-(st['top'] + half):.2f}"
          f"  sous l'emprise {st['bottom'] - half:+.2f}  côtés {-(st['left'] + half):+.2f}/{st['right'] - half:+.2f}")
    print(f"   aire du masque {st['area']:.2f} t²  couverture de l'emprise {cov * 100:.0f} %  aire hors emprise {out_area:.2f} t²  centroïde ({st['cx']:+.2f}, {st['cy']:+.2f})")
    print(f"   couleur moyenne RGB ({cs['r']:.0f}, {cs['g']:.0f}, {cs['b']:.0f})  luminance p5/p50/p95 {cs['l5']:.0f}/{cs['l50']:.0f}/{cs['l95']:.0f}  saturation {cs['sat']:.2f}")
    if shs:
        print(f"   ombre : x [{shs['left']:+.2f} ; {shs['right']:+.2f}] y [{shs['top']:+.2f} ; {shs['bottom']:+.2f}]  centroïde ({shs['cx']:+.2f}, {shs['cy']:+.2f})"
              f"  décalage ombre - corps ({shs['cx'] - st['cx']:+.2f}, {shs['cy'] - st['cy']:+.2f})")
    if os.environ.get("ASCII"):
        print(ascii_mask(a, size))
    # Recouvrement avec l'homothétie ×1,108 du design rejeté (niveau 10 : +1,2 %/niveau)
    if name in ("gun-N", "laser-N", "drill-N", "furnace", "assembler", "command-1"):
        if name == "command-1":
            a10, _, _ = compose(cc(10))
        else:
            a10, _, _ = compose(homothety(layers, 1 + 0.012 * 9))
        print(f"   IoU(niveau 1, niveau 10 du design rejeté E25) = {iou(a, a10):.2f}")
