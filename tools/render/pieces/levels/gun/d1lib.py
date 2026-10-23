"""Composition des niveaux de la famille gun sur une toile commune et mesures D1 (Python système).

Toile : 64 px par tuile (couches hr, scale 0,5), origine (position de l'entité) au pixel (OX, OY) ;
x de -5 à +5 tuiles, y de -7 à +3 tuiles. Masque D1 = alpha ≥ 0,5 des couches principales (socle + tête),
sans ombre, lueur ni halo (bible §1.4). Aucune couche plate posée au sol dans cette famille : le socle
d'une tourelle est un volume (vanilla : 0,4 de haut), il reste dans le masque (amendement Q13 (a) sans
objet ici ; voir mesures « tête seule » à titre d'information).

Sources :
  - niveau 1 : sprites vanilla 1.1.91 (socle hr-gun-turret-base, tête hr-gun-turret-shooting-*, image 0
    = « prepared », directions 0/16/32/48 = N/E/S/O, ombre hr-gun-turret-shooting-shadow-*) ;
  - niveaux 2 à 30 : « dry » (silhouettes de dryrun.py) ou « final » (aperçus de render_gun.py).
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
OUT_DIR = os.path.join(MOD_ROOT, "tools", "render", "out", "levels", "gun")
DRY_DIR = os.path.join(OUT_DIR, "_dry")
DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
GT = os.path.join(DATA, "base", "graphics", "entity", "gun-turret")

PPT = 64
X0, X1, Y0, Y1 = -5, 5, -7, 3
W, H = (X1 - X0) * PPT, (Y1 - Y0) * PPT
OX, OY = -X0 * PPT, -Y0 * PPT
POSES = ("N", "E", "S", "O")
VAN_DIR = {"N": 0, "E": 16, "S": 32, "O": 48}


def load_rgba(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


# ------------------------------------------------------------------------------------------------
# Couches
# ------------------------------------------------------------------------------------------------
def layer(img, topleft, kind, module):
    return {"img": img, "tl": (int(topleft[0]), int(topleft[1])), "kind": kind, "module": module}


def tl_from_shift(shift, w, h):
    x = OX + shift[0] * PPT - w / 2.0
    y = OY + shift[1] * PPT - h / 2.0
    assert abs(x - round(x)) < 1e-6 and abs(y - round(y)) < 1e-6, (shift, w, h)
    return int(round(x)), int(round(y))


def vanilla_layers(pose):
    d = VAN_DIR[pose]
    f, row = d // 16 + 1, d % 16
    head = load_rgba(os.path.join(GT, "hr-gun-turret-shooting-%d.png" % f))[row * 130:(row + 1) * 130, 0:132]
    sh = load_rgba(os.path.join(GT, "hr-gun-turret-shooting-shadow-%d.png" % f))[row * 124:(row + 1) * 124, 0:250]
    base = load_rgba(os.path.join(GT, "hr-gun-turret-base.png"))
    return [layer(sh, tl_from_shift((0.6875, 0.078125), 250, 124), "shadow", "tete"),
            layer(base, tl_from_shift((0.015625, -0.03125), 150, 118), "main", "socle"),
            layer(head, tl_from_shift((0.0, -0.859375), 132, 130), "main", "tete")]


def vanilla_head_sweep():
    """Union des alphas de la tête vanilla « prepared » (image 0) sur ses 64 directions."""
    c = np.zeros((H, W))
    for d in range(64):
        f, row = d // 16 + 1, d % 16
        head = load_rgba(os.path.join(GT, "hr-gun-turret-shooting-%d.png" % f))[row * 130:(row + 1) * 130, 0:132]
        paste_max(c, head[..., 3], tl_from_shift((0.0, -0.859375), 132, 130))
    return c


def head_sweep(epoch):
    """Union des silhouettes de la tête de l'époque sur 64 directions (alpha, toile commune) : geo.py --sweep."""
    if epoch == 1:
        return vanilla_head_sweep()
    a = np.asarray(Image.open(os.path.join(DRY_DIR, "e%02d-balayage-alpha.png" % epoch)).convert("RGBA"))
    return a[..., 3].astype(np.float64) / 255.0


def vanilla_base_alpha_canvas():
    c = np.zeros((H, W))
    base = load_rgba(os.path.join(GT, "hr-gun-turret-base.png"))
    paste_max(c, base[..., 3], tl_from_shift((0.015625, -0.03125), 150, 118))
    return c


def paste_max(canvas, a, tl):
    x, y = tl
    h, w = a.shape[:2]
    xs, ys = max(0, -x), max(0, -y)
    xd, yd = max(0, x), max(0, y)
    ww, hh = min(w - xs, W - xd), min(h - ys, H - yd)
    if ww > 0 and hh > 0:
        canvas[yd:yd + hh, xd:xd + ww] = np.maximum(canvas[yd:yd + hh, xd:xd + ww], a[ys:ys + hh, xs:xs + ww])


def to_canvas(img, tl):
    """Image (h, w, 4) -> toile (H, W, 4) (transparent ailleurs)."""
    out = np.zeros((H, W, img.shape[2]))
    x, y = tl
    h, w = img.shape[:2]
    xs, ys = max(0, -x), max(0, -y)
    xd, yd = max(0, x), max(0, y)
    ww, hh = min(w - xs, W - xd), min(h - ys, H - yd)
    if ww > 0 and hh > 0:
        out[yd:yd + hh, xd:xd + ww] = img[ys:ys + hh, xs:xs + ww]
    return out


# --- niveaux 2..30 ---------------------------------------------------------------------------------
def _dry_info():
    with open(os.path.join(DRY_DIR, "dryrun.json"), encoding="utf-8") as f:
        return json.load(f)


_DRY = {}


def dry_layer(name, module):
    if not _DRY:
        _DRY.update(_dry_info())
    inf = _DRY[name]
    a = np.asarray(Image.open(os.path.join(DRY_DIR, "%s-alpha.png" % name)).convert("RGBA")).astype(np.float64) / 255.0
    ox, oy = inf["origin_px"]
    img = np.zeros(a.shape[:2] + (4,))
    img[..., 3] = a[..., 3]
    return layer(img, (OX - ox, OY - oy), "main", module)


def final_layers(name, module, kinds=("shadow", "main", "glow", "light")):
    d = os.path.join(OUT_DIR, name)
    with open(os.path.join(d, "spec.json"), encoding="utf-8") as f:
        spec = json.load(f)
    out = []
    for kind in kinds:
        if kind in spec["layers"]:
            s = spec["layers"][kind]
            img = load_rgba(os.path.join(d, s["file"]))
            out.append(layer(img, tl_from_shift(s["shift"], s["width"], s["height"]), kind, module))
    return out


def level_layers(level, pose, source="final"):
    """Couches d'un niveau dans l'ordre de dessin du moteur : ombres, socle (lower-object), tête (object)."""
    import gun as G   # noqa: E402  (métadonnées seulement)
    if level == 1:
        return vanilla_layers(pose)
    van = vanilla_layers(pose)
    lv = G.level_variants(level)
    socle, tete = [], []
    if level == 2:
        socle.append(van[1])
        for name in lv["socle"]:
            if source == "dry":
                lay = dry_layer(name, "socle")
                if "flancs" in name:   # masque au pixel par l'alpha du socle vanilla (comme V0 « four »)
                    vb = vanilla_base_alpha_canvas()
                    c = to_canvas(lay["img"], lay["tl"])
                    c[..., 3] *= (1 - vb)
                    lay = layer(c, (0, 0), "main", "socle")
                socle.append(lay)
            else:
                socle += final_layers(name, "socle")
        tete = [van[0], van[2]]
    else:
        for name in lv["socle"]:
            socle += [dry_layer(name, "socle")] if source == "dry" else final_layers(name, "socle")
        name = lv["tete"][pose]
        tete = [dry_layer(name, "tete")] if source == "dry" else final_layers(name, "tete")
    shadows = [l for l in socle + tete if l["kind"] == "shadow"]
    rest_s = [l for l in socle if l["kind"] != "shadow"]
    rest_t = [l for l in tete if l["kind"] != "shadow"]
    return shadows + rest_s + rest_t


def main_alpha(layers, modules=("socle", "tete")):
    a = np.zeros((H, W))
    for l in layers:
        if l["kind"] != "main" or l["module"] not in modules:
            continue
        c = to_canvas(l["img"], l["tl"])[..., 3]
        a = c + a * (1 - c)
    return a


def compose_rgb(layers, bg=None):
    """Couleur de jour (sur fond transparent) des couches principales + lueurs : (H, W, 4) droit."""
    rgb = np.zeros((H, W, 3))
    a = np.zeros((H, W))
    for l in layers:
        if l["kind"] not in ("main",):
            continue
        c = to_canvas(l["img"], l["tl"])
        ca = c[..., 3:4]
        rgb = c[..., :3] * ca + rgb * (1 - ca)
        a = c[..., 3] + a * (1 - c[..., 3])
    return rgb, a


# ------------------------------------------------------------------------------------------------
# Mesures
# ------------------------------------------------------------------------------------------------
def opening_h(mask, width=10):
    """Ouverture horizontale : supprime les structures de moins de `width` px de large (tiges fines)."""
    m = mask.astype(np.int32)
    Hm, Wm = m.shape
    cs = np.concatenate([np.zeros((Hm, 1), np.int32), np.cumsum(m, 1)], 1)
    full = ((cs[:, width:] - cs[:, :-width]) == width).astype(np.int32)   # fenêtre [j, j+width) pleine
    fc = np.concatenate([np.zeros((Hm, 1), np.int32), np.cumsum(full, 1)], 1)
    x = np.arange(Wm)
    lo = np.maximum(0, x - width + 1)
    hi = np.minimum(x, Wm - width)
    ok = hi >= lo
    out = np.zeros_like(mask)
    out[:, ok] = (fc[:, hi[ok] + 1] - fc[:, lo[ok]]) > 0
    return out & mask


def metrics(mask):
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    op = opening_h(mask)
    yo = np.nonzero(op.any(1))[0]
    top_masses = (yo.min() - OY) / PPT if len(yo) else None
    return {
        "top": (ys.min() - OY) / PPT, "top_masses": top_masses,
        "O": -top_masses - 1.0 if top_masses is not None else None,
        "O_brut": -(ys.min() - OY) / PPT - 1.0,
        "bottom": (ys.max() + 1 - OY) / PPT,
        "left": (xs.min() - OX) / PPT, "right": (xs.max() + 1 - OX) / PPT,
        "L": (xs.max() + 1 - xs.min()) / PPT,
        "area": len(xs) / PPT ** 2,
    }


def iou(a, b):
    u = (a | b).sum()
    return float((a & b).sum() / u) if u else 0.0


def scale_mask(mask, k):
    """Homothétie de centre l'origine de l'entité (comme measure.py de V1 : scale et shift × k)."""
    yy, xx = np.mgrid[0:H, 0:W]
    sx = np.floor(OX + (xx + 0.5 - OX) / k).astype(int)
    sy = np.floor(OY + (yy + 0.5 - OY) / k).astype(int)
    ok = (sx >= 0) & (sx < W) & (sy >= 0) & (sy < H)
    out = np.zeros_like(mask)
    out[ok] = mask[sy[ok], sx[ok]]
    return out


def iou_scale_norm(m1, m30, ks=None):
    """max sur k ∈ [0,60 ; 2,60] de IoU(m1 agrandi de k, m30) : pas de 0,05 puis affinage au pas de 0,01."""
    if ks is not None:
        cand = list(ks)
    else:
        coarse = np.arange(0.60, 2.601, 0.05)
        vals = [iou(scale_mask(m1, k), m30) for k in coarse]
        order = np.argsort(vals)[::-1][:3]
        cand = sorted({round(float(k), 2) for i in order for k in np.arange(coarse[i] - 0.05, coarse[i] + 0.051, 0.01)})
    best, bk = -1.0, None
    for k in cand:
        v = iou(scale_mask(m1, k), m30)
        if v > best:
            best, bk = v, float(k)
    return best, bk


def luminance(rgb):
    return rgb @ np.array([0.2126, 0.7152, 0.0722])
