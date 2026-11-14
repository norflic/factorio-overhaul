"""PLANCHE DU CORRODER (s43, 14/11) : la famille toxique avant / après, à l'échelle du jeu (zoom 1, 32 px/tuile), direction sud-est,
image 0 de la course, sur un sol brun. AVANT : le déchiqueteur vanilla recoloré (masques teintés tint1/tint2 de la famille) ;
APRÈS : le Corroder (feuilles de graphics/robots/titans/sprites.lua), corps teinté et lueur additive de la variante (E.teinte_variante,
alpha Evo.tier_alpha(palier, 0,45, 0,05)), déchiqueteurs puis cracheurs. Les tailles et teintes sont lues dans les données (lua5.2).

    PYTHONUTF8=1 py -3.9 tools/render/pieces/titans/planche_corroder.py --dest DIR [--data <racine>/data]
"""
import argparse
import json
import os
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
RACINE = os.environ.get("FO_RACINE", r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91")   # données vanilla (le mod peut être un worktree)
PALIERS = (1, 3, 5, 8, 12)
VANILLA = {"small": 0.5, "medium": 0.7, "big": 1.0, "behemoth": 1.2}   # échelles vanilla des déchiqueteurs et cracheurs (1.1)

LUA = r"""
package.path = os.getenv("FO_MOD") .. "/?.lua;" .. package.path
local E = require("shared.content.enemies")
local spr = dofile(os.getenv("FO_MOD") .. "/graphics/robots/titans/sprites.lua")
local function js(v)
  if type(v) == "table" then
    local n = #v
    local parts = {}
    if n > 0 then for i = 1, n do parts[#parts + 1] = js(v[i]) end return "[" .. table.concat(parts, ",") .. "]" end
    local ks = {}
    for k in pairs(v) do ks[#ks + 1] = tostring(k) end
    table.sort(ks)
    for _, k in ipairs(ks) do parts[#parts + 1] = string.format("%q", k) .. ":" .. js(v[k] ~= nil and v[k] or v[tonumber(k)]) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif type(v) == "string" then return string.format("%q", v)
  elseif type(v) == "boolean" then return v and "true" or "false"
  else return tostring(v) end
end
local f = E.families.toxic
local out = { spr = spr.corroder, spr_c = spr.corroder_cracheur, echelle = f.corps3d_echelle or 1, tint1 = f.tint1, tint2 = f.tint2, size = f.size, paliers = {} }
for t = 1, E.TIERS do
  local base = E.tier_names[math.min(t, E.VANILLA_TIERS)]
  local nt = E.new_tiers[t]
  local lb, cb = E.teinte_variante("toxic", "biter", t)
  local ls, cs = E.teinte_variante("toxic", "spitter", t)
  out.paliers[t] = { base = base, nt = nt and nt.scale or 0, lb = lb, cb = cb, ls = ls, cs = cs }
end
print(js(out))
"""


def donnees():
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf-8") as f:
        f.write(LUA)
        p = f.name
    try:
        r = subprocess.run([os.environ.get("FO_LUA", "lua5.2.exe"), p], capture_output=True, text=True, env=dict(os.environ, FO_MOD=MOD), check=True)
    finally:
        os.remove(p)
    return json.loads(r.stdout)


def rgba(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


def fichier(nom):
    return os.path.join(MOD, nom.replace("__factorio-overhaul__/", "").replace("/", os.sep))


def cellule(c, k_dir, image=0):
    """Image `image` de la direction k_dir d'une couche hr d'une animation (grille ll × lpf par fichier)."""
    im = rgba(fichier(c["hr"][k_dir]))
    lig, col = divmod(image, c["ll"])
    return im[lig * c["h"]:(lig + 1) * c["h"], col * c["w"]:(col + 1) * c["w"]]


def redim(a, k):
    h, w = a.shape[:2]
    W, H = max(1, int(round(w * k))), max(1, int(round(h * k)))
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)).astype(np.float64) / 255.0


def poser(fond, a, cx, cy, mode="over"):
    h, w = a.shape[:2]
    x0, y0 = int(cx - w / 2), int(cy - h / 2)
    H, W = fond.shape[:2]
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
    if xa >= xb or ya >= yb:
        return
    s = a[ya - y0:yb - y0, xa - x0:xb - x0]
    d = fond[ya:yb, xa:xb]
    if mode == "add":
        d[..., :3] = np.clip(d[..., :3] + s[..., :3] * s[..., 3:4], 0, 1)
    elif mode == "ombre":
        d[..., :3] = d[..., :3] * (1 - 0.5 * s[..., 3:4])
    else:
        d[..., :3] = s[..., :3] * s[..., 3:4] + d[..., :3] * (1 - s[..., 3:4])


def avant(D, t, fond, cx, cy):
    """Déchiqueteur vanilla recoloré : direction 6 sur 16 (sud-est), image 0 ; corps, masques teintés, ombre."""
    p = D["paliers"][t - 1]
    g = VANILLA[p["base"]] * (p["nt"] / 1.2 if p["nt"] else 1.0) * D["size"]
    base = os.path.join(RACINE, "data", "base", "graphics", "entity", "biter")
    d = 6
    f_, r0 = divmod(d, 4)
    lig = r0 * 2

    def cel(nom, W, H):
        im = rgba(os.path.join(base, nom % (f_ + 1)))
        return im[lig * H:(lig + 1) * H, 0:W]
    k = 0.5 * g        # hr : 64 px par tuile, échelle 0,5 × g ; ici 32 px par tuile
    # (fichier, largeur, hauteur, décalage en px vanilla, teinte) : ombre, corps, masques teintés (biter-animations.lua)
    couches = (("hr-biter-run-shadow-%02d.png", 432, 292, (8, -1), None), ("hr-biter-run-%02d.png", 398, 310, (-1, -5), "corps"),
               ("hr-biter-run-mask1-%02d.png", 238, 182, (-1, -37), D["tint1"]), ("hr-biter-run-mask2-%02d.png", 232, 184, (0, -38), D["tint2"]))
    for nom, W, H, (sx, sy), tt in couches:
        im = cel(nom, W, H).copy()
        if isinstance(tt, dict):
            im[..., :3] *= np.array([tt["r"], tt["g"], tt["b"]])
        poser(fond, redim(im, k), cx + sx * g, cy + sy * g, "ombre" if tt is None else "over")
    return g


def apres(D, t, sorte, fond, cx, cy, cadavre=False):
    """Corroder : direction 3 sur 8 (sud-est), image 0 de la course (ou le cadavre) ; corps teinté, lueur additive de la variante, ombre."""
    A = D["spr_c"] if (sorte == "spitter" and D.get("spr_c")) else D["spr"]
    a = A["cadavre"]["mort"] if cadavre else A["course"]
    p = D["paliers"][t - 1]
    g = VANILLA[p["base"]] * (p["nt"] / 1.2 if p["nt"] else 1.0) * D["size"] * D["echelle"]
    lueur, teinte = (p["lb"], p["cb"]) if sorte == "biter" else (p["ls"], p["cs"])
    alpha = min(1.0, 0.45 + 0.05 * t) * (0.25 if cadavre else 1.0)
    cc = a["couches"]
    for nom, mode in (("shadow", "ombre"), ("main", "over"), ("glow", "add")):
        c = cc[nom]
        im = cellule(c, 3, a["images"] - 1 if cadavre else 0).copy()   # cadavre : dernière image de la chute (la carcasse)
        if nom == "main":
            im[..., :3] *= np.array([teinte["r"], teinte["g"], teinte["b"]])
        if nom == "glow":
            im[..., :3] *= np.array([lueur["r"], lueur["g"], lueur["b"]]) * alpha
        k = g * 32.0 / c["dens"]
        poser(fond, redim(im, k), cx + c["sx"] * g * 32, cy + c["sy"] * g * 32, mode)
    return g


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    a = ap.parse_args()
    D = donnees()
    # colonnes et lignes à la taille du plus gros palier (échelle g : un Corroder fait environ 2,6 g tuiles de long)
    gs = []
    for t in PALIERS:
        p = D["paliers"][t - 1]
        gs.append(VANILLA[p["base"]] * (p["nt"] / 1.2 if p["nt"] else 1.0) * D["size"] * D["echelle"])
    cws = [max(150, int(100 * g)) for g in gs]
    xs = [170 + sum(cws[:i]) + cws[i] // 2 for i in range(len(cws))]
    ch = max(170, int(80 * max(gs)))
    W, H = 170 + sum(cws) + 20, ch * 5 + 50
    fond = np.ones((H, W, 4)) * np.array([0.33, 0.27, 0.19, 1.0])
    img_lignes = (("AVANT : dechiqueteur vanilla recolore", "avant"), ("APRES : Corroder, dechiqueteurs", "biter"),
                  ("APRES : Corroder, cracheurs", "spitter"), ("APRES : cadavres (dechiqueteurs)", "cadavre"),
                  ("APRES : cadavres (cracheurs)", "cadavre_c"))
    for li, (_, sorte) in enumerate(img_lignes):
        for ci, t in enumerate(PALIERS):
            cx, cy = xs[ci], 40 + li * ch + ch // 2
            if sorte == "avant":
                avant(D, t, fond, cx, cy)
            elif sorte == "cadavre":
                apres(D, t, "biter", fond, cx, cy, cadavre=True)
            elif sorte == "cadavre_c":
                apres(D, t, "spitter", fond, cx, cy, cadavre=True)
            else:
                apres(D, t, sorte, fond, cx, cy)
    im = Image.fromarray((np.clip(fond, 0, 1) * 255).astype(np.uint8)).convert("RGB")
    dr = ImageDraw.Draw(im)
    try:
        from PIL import ImageFont
        fnt = ImageFont.truetype("arial.ttf", 16)
    except OSError:
        fnt = None
    dr.text((6, 6), "FAMILLE TOXIQUE (Corroder) - zoom 1 du jeu (32 px/tuile), sud-est ; colonnes = paliers " + ", ".join(map(str, PALIERS)), fill=(255, 230, 140), font=fnt)
    for li, (titre, _) in enumerate(img_lignes):
        dr.text((6, 40 + li * ch + 10), titre, fill=(255, 255, 255), font=fnt)
    for ci, t in enumerate(PALIERS):
        dr.text((xs[ci] - 30, 26), "palier %d" % t, fill=(220, 220, 220), font=fnt)
    os.makedirs(a.dest, exist_ok=True)
    p = os.path.join(a.dest, "planche-corroder.png")
    im.save(p)
    im.resize((im.size[0] * 2, im.size[1] * 2), Image.NEAREST).save(os.path.join(a.dest, "planche-corroder-x2.png"))
    print(p, im.size)


if __name__ == "__main__":
    main()
