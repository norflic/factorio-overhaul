"""PLANCHES DES TITANS (lot TITANS, 9/11) pour le DC (au téléphone) : rendu principal + lueur, et une bande de la run_animation.

    PYTHONUTF8=1 py -3.9 tools/render/pieces/titans/planches_titans.py [--dest fo-logs/2026-11-10_TITANS-FINITIONS]

- planche-juggernaut.png, planche-sentinelle.png, planche-leviathan.png : les trois stades côte à côte à l'échelle du jeu (zoom 1, 32 px/tuile)
  sur le sol vanilla, à côté du vrai silo (9 × 9) et d'un vrai béhémoth (scene.py des géants), de jour puis de nuit (lueur seule) ; stade 3
  en gros plan ; le Léviathan avec ses drones d'escorte posés comme en jeu (orbite de la règle). Juggernaut ANIMÉ (FINITIONS 10/11) : image 0 de la
  course, direction sud-est, puis une bande des 8 images de course (direction est) et des 4 images de salve (direction sud) du stade 3.
- planche-kaiju.png : le Kaiju (feuilles de jeu, direction sud-est) de jour avec sa lueur teintée par ère (5 ères), une bande des 8 images
  de course (direction est) et des 4 images d'attaque, à côté du béhémoth.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, os.path.join(RENDER, "pieces", "experimentaux"))
import scene as SC  # noqa: E402

LOGS = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91", "fo-logs", "2026-11-10_TITANS-FINITIONS")
SPRITES = os.path.join(MOD, "graphics", "robots", "titans")


LUA_JSON = r"""
local t = dofile(os.getenv("FO_SPRITES"))
package.path = os.getenv("FO_MOD") .. "/?.lua;" .. package.path
local T = require("shared.robots.titans")
t.__eres = {}
for e = 1, T.ERAS do local k = T.kaiju(e); t.__eres[e] = { tint = { k.tint.r, k.tint.g, k.tint.b }, glow = k.glow, scale = k.scale } end
t.__eres_ecorcheur = {}
for e = T.ECORCHEUR.era_min, T.ERAS do local k = T.kaiju(e, T.ECORCHEUR); t.__eres_ecorcheur[e] = { tint = { k.tint.r, k.tint.g, k.tint.b }, glow = k.glow, scale = k.scale } end
t.__ecorches = {}
for i, v in ipairs(T.ECORCHE.variants) do
  local l = { id = v.id, eres = {} }
  for e = T.ECORCHE.era_min, T.ERAS do local m = T.ecorche(v, e); l.eres[e] = { tint = { m.tint.r, m.tint.g, m.tint.b }, glow = m.glow, scale = m.scale } end
  t.__ecorches[i] = l
end
t.__drones = {}
for st = 1, T.STAGES do
  local n = 0
  for p = 1, T.PALIERS do if T.stage(p) == st then n = math.max(n, T.drones(p)) end end
  t.__drones[tostring(st)] = n
end
t.__orbit = T.LEVIATHAN.drones.orbit
local function esc(s) return '"' .. s:gsub('[%c"]', function(c) return string.format("%su%04x", string.char(92), c:byte()) end) .. '"' end
local function w(v)
  if type(v) == "table" then
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    if n == #v and n > 0 then
      local p = {}
      for i = 1, n do p[i] = w(v[i]) end
      return "[" .. table.concat(p, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local p = {}
    for _, k in ipairs(keys) do p[#p + 1] = esc(k) .. ":" .. w(v[k] == nil and v[tonumber(k)] or v[k]) end
    return "{" .. table.concat(p, ",") .. "}"
  elseif type(v) == "string" then return esc(v)
  elseif type(v) == "boolean" then return v and "true" or "false"
  elseif v == nil then return "null"
  else return tostring(v) end
end
io.write(w(t))
"""


def lua_table(path):
    """Lit sprites.lua (table Lua pure) par lua5.2 (sérialisation JSON minimale, clés triées)."""
    import subprocess
    lua = os.environ.get("FO_LUA", os.path.join("C:" + os.sep, "Users", "evan2", "bin", "lua5.2.exe"))  # lua5.2 : alias de Git Bash (CLAUDE.md §3)
    r = subprocess.run([lua, "-e", LUA_JSON], capture_output=True, text=True, encoding="utf-8", env=dict(os.environ, FO_SPRITES=path, FO_MOD=MOD))
    if r.returncode:
        raise SystemExit("lua5.2 : " + r.stderr)
    return json.loads(r.stdout)


def rgba(path):
    return np.asarray(Image.open(path).convert("RGBA"), np.float32) / 255.0


def couche(entry, kind, ppt=32):
    """Couche d'un géant depuis sprites.lua (hr à 32 px/tuile) en format scene.py."""
    f = entry["hr"]["filename"].replace("__factorio-overhaul__/graphics/robots/titans/", "")
    im = rgba(os.path.join(SPRITES, f))
    k = ppt / (32.0 / entry["hr"]["scale"])
    return {"img": SC._reduit(Image.fromarray(np.round(im * 255).astype(np.uint8), "RGBA"), k) if abs(k - 1) > 1e-6 else im,
            "shift": tuple(entry["shift"]), "kind": kind}


def telephone(im, path, largeur=1600):
    """Copie réduite (au plus `largeur` px de large) pour le DC au téléphone."""
    k = min(1.0, largeur / float(im.width))
    r = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS) if k < 1 else im
    r.save(path, optimize=True)


def couches_anime(e, anim, direction, image, ppt):
    """Couches (format scene.py) d'une image d'un stade ANIMÉ : main, glow_0, shadow, chacune réduite de sa densité à `ppt`."""
    cells, K = images_de(e[anim], direction)
    cell = cells[image]
    out = {}
    for c, cle, kind in (("main", "main", "main"), ("glow", "glow_0", "glow"), ("shadow", "shadow", "shadow")):
        cc = K["couches"][c]
        k = ppt / cc.get("dens", K["densite"])
        a = cell[c]
        im = SC._reduit(Image.fromarray(np.round(np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA"), k) if abs(k - 1) > 1e-6 else a
        out[cle] = {"img": im, "shift": (cc["sx"], cc["sy"]), "kind": kind}
    return out


def allie_anime_fin(spr, dest, nom, jour, nuit, f2):
    """Fin de la planche d'un allié ANIMÉ : gros plan du stade 3 (image 0 de la course, sud-est, densité du rendu), bande des images de course
    (direction est) et de salve (direction sud) du stade 3, à 20 px/tuile."""
    e = spr[nom]["3"]
    cells, K = images_de(e["course"], 3)
    D = K["densite"]
    gp = SC.to_im(compose(cells[0], K, D, (1.0, 1.0, 1.0), 1.0, fond_val=0.30))
    ImageDraw.Draw(gp).text((12, 8), "stade 3, feuille HR %d px/tuile (corps + lueur), direction sud-est" % D, fill=(255, 225, 150), font=f2)
    bandes = []
    for anim, direction, titre in (("course", 2, "marche : %d images, direction est" % e["course"]["images"]), ("attaque", 4, "salve : %d images, direction sud" % e["attaque"]["images"])):
        cells, K = images_de(e[anim], direction)
        ims = [SC.to_im(compose(c, K, 20, (1.0, 1.0, 1.0), 1.0, fond_val=0.38)) for c in cells]
        W = sum(i.width for i in ims) + 6 * (len(ims) - 1)
        H = max(i.height for i in ims)
        b = Image.new("RGB", (W, H + 30), (20, 20, 24))
        ImageDraw.Draw(b).text((8, 4), titre, fill=(255, 225, 150), font=f2)
        x = 0
        for i in ims:
            b.paste(i, (x, 30))
            x += i.width + 6
        bandes.append(b)
    Wt = max([jour.width + gp.width + 10] + [b.width for b in bandes])
    Ht = max(jour.height + nuit.height + 10, gp.height) + sum(b.height + 8 for b in bandes)
    out = Image.new("RGB", (Wt, Ht), (20, 20, 24))
    out.paste(jour, (0, 0))
    out.paste(nuit, (0, jour.height + 10))
    out.paste(gp, (jour.width + 10, 0))
    y = max(jour.height + nuit.height + 10, gp.height)
    for b in bandes:
        out.paste(b, (0, y + 8))
        y += b.height + 8
    p = os.path.join(dest, "planche-%s.png" % nom)
    out.save(p, optimize=True)
    telephone(out, os.path.join(dest, "planche-%s-telephone.png" % nom))
    return p, out.size


ALLIES = {
    "juggernaut": ("JUGGERNAUT, titan allié bipède ANIMÉ (âges 10 à 15)", 34, 150),
    "ravageur": ("RAVAGEUR, méga-robot d'assaut allié ANIMÉ (âges 13 à 15)", 30, 140),
    "sentinelle": ("SENTINELLE, titan allié hexapode flottant (âges 11 à 15)", 38, 162),
    "leviathan": ("LÉVIATHAN, titan allié serpentin flottant (âges 12 à 15)", 44, 180),
}
# orbite des drones du Léviathan telle que le script la pose (script/robots/titans.lua : CERCLE, DRONE_HAUT, règle T.LEVIATHAN.drones)
CERCLE = [(1.0, 0.0), (0.866, 0.5), (0.5, 0.866), (0.0, 1.0), (-0.5, 0.866), (-0.866, 0.5), (-1.0, 0.0), (-0.866, -0.5), (-0.5, -0.866),
          (0.0, -1.0), (0.5, -0.866), (0.866, -0.5)]


def allie(spr, dest, nom):
    titre, pas, W_t = ALLIES[nom]
    ppt = 32
    H_t = 64
    sc = SC.Scene(W_t, H_t, ppt, seed=11)
    sol_y = 52
    ents = [{"pos": (9, sol_y), "layers": SC.vanilla("silo", ppt)}, {"pos": (22, sol_y + 1), "layers": SC.behemoth(ppt)}]
    geants = []
    anime = spr[nom].get("anime") is True
    for i, st in enumerate(("1", "2", "3")):
        e = spr[nom][st]
        if anime:
            layers = couches_anime(e, "course", 3, 0, ppt)
            ordre = ("main", "glow_0")
        else:
            layers = {"main": couche(e["main"], "main"), "shadow": couche(e["ombre"], "shadow")}
            for k, g in enumerate(e["lueurs"]):
                layers["glow_%d" % k] = couche(g, "glow")
            ordre = ("main",) + tuple("glow_%d" % k for k in range(len(e["lueurs"])))
        pos = (44 + pas * i, sol_y)
        geants.append({"pos": pos, "layers": layers, "ordre": ordre})
        if nom == "leviathan" and "drone" in spr[nom]:
            d = spr[nom]["drone"]
            n = spr["__drones"][st]
            orbit = spr["__orbit"]
            for k in range(n):
                c = CERCLE[(3 * i + 12 * k // n) % 12]
                off = (c[0] * orbit, c[1] * orbit * 0.6 - 6.0)
                dl = {"main": couche(d["main"], "main")}
                for q, g in enumerate(d["lueurs"]):
                    dl["glow_%d" % q] = couche(g, "glow")
                geants.append({"pos": (pos[0] + off[0], pos[1] + off[1]), "layers": dl, "ordre": ("main",) + tuple("glow_%d" % q for q in range(len(d["lueurs"])))})
    jour = SC.to_im(sc.rendu(ents, geants))
    # nuit : sol assombri, lueur seule par-dessus (approximation de la carte des lumières)
    nuit_img = sc.rendu(ents, geants) * 0.22
    for g in geants:
        for k in list(g["layers"]):
            if k.startswith("glow"):
                src, d = sc._place(g["layers"][k], g["pos"])
                if src is not None:
                    a = src[..., 3:4]
                    nuit_img[d] = np.clip(nuit_img[d] + src[..., :3] * a, 0, 1)
    nuit = SC.to_im(nuit_img)
    f = SC.police(26)
    f2 = SC.police(17)
    for im, moment in ((jour, "JOUR"), (nuit, "NUIT (lueur seule)")):
        d = ImageDraw.Draw(im)
        d.text((16, 12), titre + " · zoom 1 du jeu (32 px/tuile) · " + moment, fill=(255, 225, 150), font=f)
        y = int((sol_y + 5) * ppt)
        d.text((int(3 * ppt), y), "Vanilla : rocket-silo 9×9", fill=(245, 245, 245), font=f2)
        d.text((int(18 * ppt), y), "Vanilla : behemoth-biter", fill=(245, 245, 245), font=f2)
        for i in range(3):
            d.text((int((36 + pas * i) * ppt), y), "stade %d (paliers %s)" % (i + 1, ("1-2", "3-4", "5-6")[i]), fill=(170, 240, 255), font=f2)
    if anime:
        return allie_anime_fin(spr, dest, nom, jour, nuit, f2)
    # gros plan du stade 3 (feuille HR telle quelle)
    e = spr[nom]["3"]
    gros = couche(e["main"], "main")["img"]
    lu = couche(e["lueurs"][0], "glow")["img"]
    H, W = gros.shape[:2]
    fond = np.full((H + 40, W + 40, 3), 0.30, np.float32)
    fond[20:20 + H, 20:20 + W] = gros[..., :3] * gros[..., 3:4] + fond[20:20 + H, 20:20 + W] * (1 - gros[..., 3:4])
    sh = couche(e["lueurs"][0], "glow")["shift"]
    ms = couche(e["main"], "main")["shift"]
    ox = int(round(20 + W / 2 + (sh[0] - ms[0]) * 32 - lu.shape[1] / 2))
    oy = int(round(20 + H / 2 + (sh[1] - ms[1]) * 32 - lu.shape[0] / 2))
    h2, w2 = lu.shape[:2]
    y0, x0 = max(0, oy), max(0, ox)
    y1, x1 = min(fond.shape[0], oy + h2), min(fond.shape[1], ox + w2)
    if y1 > y0 and x1 > x0:
        src = lu[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
        fond[y0:y1, x0:x1] = np.clip(fond[y0:y1, x0:x1] + src[..., :3] * src[..., 3:4] * 0.7, 0, 1)
    gp = SC.to_im(fond)
    ImageDraw.Draw(gp).text((12, 8), "stade 3, feuille HR 32 px/tuile (corps + lueur)", fill=(255, 225, 150), font=f2)
    # assemblage vertical : jour, nuit ; gros plan à droite
    Wt = jour.width + gp.width + 10
    Ht = max(jour.height + nuit.height + 10, gp.height)
    out = Image.new("RGB", (Wt, Ht), (20, 20, 24))
    out.paste(jour, (0, 0))
    out.paste(nuit, (0, jour.height + 10))
    out.paste(gp, (jour.width + 10, 0))
    p = os.path.join(dest, "planche-%s.png" % nom)
    out.save(p, optimize=True)
    telephone(out, os.path.join(dest, "planche-%s-telephone.png" % nom))
    return p, out.size


def images_de(K, direction, seizieme=None):
    """Images (main, glow, shadow) d'une direction d'une animation `K` (entrée `course` ou `attaque` de sprites.lua) : liste de cellules
    {main, glow, shadow} en float RGBA (chaque couche à sa densité `dens`). `direction` en HUITIÈMES de tour (0 = nord, 2 = est, 3 = sud-est,
    4 = sud) quel que soit le nombre de directions des feuilles (ART-16DIR : 8 ou 16) ; `seizieme` : direction exacte en seizièmes."""
    out = []
    files = {}
    n = len(K["couches"]["main"]["hr"])
    k = (seizieme * n // 16) if seizieme is not None else (direction * n // 8)
    for c in ("main", "glow", "shadow"):
        cc = K["couches"][c]
        f = cc["hr"][k].replace("__factorio-overhaul__/graphics/robots/titans/", "")
        files[c] = (rgba(os.path.join(SPRITES, f)), cc)
    for i in range(K["images"]):
        cell = {}
        for c, (img, cc) in files.items():
            lig, col = divmod(i, cc["ll"])
            cell[c] = img[lig * cc["h"]:(lig + 1) * cc["h"], col * cc["w"]:(col + 1) * cc["w"]]
        out.append(cell)
    return out, K


def compose(cell, K, ppt, tint, glow_a, fond_val=0.42, scale=1.0):
    """Une image du Kaiju composée sur un fond : ombre à 50 %, corps, lueur additive teintée."""
    def red(a, c, additif=False):
        k = ppt / K["couches"][c].get("dens", K["densite"]) * scale
        im = Image.fromarray(np.round(np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")
        return SC._reduit(im, k) if abs(k - 1) > 1e-6 else a
    m, g, s = red(cell["main"], "main"), red(cell["glow"], "glow"), red(cell["shadow"], "shadow")
    W = int(max(m.shape[1], s.shape[1]) * 1.12)
    H = int(max(m.shape[0], s.shape[0]) * 1.08)
    img = np.full((H, W, 3), fond_val, np.float32)
    def place(a, cc):
        cx = W / 2 + cc["sx"] * ppt * scale
        cy = H * 0.70 + cc["sy"] * ppt * scale
        x0, y0 = int(round(cx - a.shape[1] / 2)), int(round(cy - a.shape[0] / 2))
        xs0, ys0 = max(0, -x0), max(0, -y0)
        xd0, yd0 = max(0, x0), max(0, y0)
        ww, hh = min(a.shape[1] - xs0, W - xd0), min(a.shape[0] - ys0, H - yd0)
        if ww <= 0 or hh <= 0:
            return None, None
        return a[ys0:ys0 + hh, xs0:xs0 + ww], (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))
    src, d = place(s, K["couches"]["shadow"])
    if src is not None:
        img[d] *= (1 - 0.5 * src[..., 3:4])
    src, d = place(m, K["couches"]["main"])
    if src is not None:
        img[d] = src[..., :3] * src[..., 3:4] + img[d] * (1 - src[..., 3:4])
    src, d = place(g, K["couches"]["glow"])
    if src is not None:
        t = np.asarray(tint, np.float32)
        img[d] = np.clip(img[d] + src[..., :3] * src[..., 3:4] * t * glow_a, 0, 1)
    return np.clip(img, 0, 1)


ENNEMIS = {
    "kaiju": ("KAIJU CRISTALLIN, titan ennemi", "__eres", "kaiju"),
    "ecorcheur": ("ÉCORCHEUR, second titan ennemi (bras-canon, ponte des Écorchés dès l'ère III)", "__eres_ecorcheur", "ecorcheur"),
}


def kaiju(spr, dest, nom="kaiju"):
    titre, cle_eres, fichier = ENNEMIS[nom]
    f = SC.police(26)
    f2 = SC.police(17)
    # 1. les ères ouvertes (direction sud-est, image 0 de la course), échelle de l'ère, lueur teintée ; béhémoth à côté
    cells, K = images_de(spr[nom]["course"], 3)
    rang = []
    eres = spr[cle_eres]
    cles = sorted(int(k) for k in eres) if isinstance(eres, dict) else list(range(1, len(eres) + 1))
    for era in cles:
        e = eres[str(era)] if isinstance(eres, dict) else eres[era - 1]
        a = compose(cells[0], K, 32, tuple(e["tint"]), e["glow"], scale=e["scale"])
        im = SC.to_im(a)
        ImageDraw.Draw(im).text((8, 8), "ère %d : lueur %.2f, échelle %.2f" % (era, e["glow"], e["scale"]), fill=(170, 240, 255), font=f2)
        rang.append(im)
    beh = SC.behemoth(32)
    sc = SC.Scene(8, 8, 32, seed=5)
    bim = SC.to_im(sc.rendu([{"pos": (4, 6), "layers": beh}]))
    ImageDraw.Draw(bim).text((6, 6), "behemoth", fill=(245, 245, 245), font=f2)
    rang.append(bim)
    W1 = sum(i.width for i in rang) + 10 * (len(rang) - 1)
    H1 = max(i.height for i in rang)
    ligne1 = Image.new("RGB", (W1, H1 + 44), (20, 20, 24))
    ImageDraw.Draw(ligne1).text((12, 8), titre + " · zoom 1 du jeu (32 px/tuile) · une ère par âge de la partie (lueur = couleur de l'ère)", fill=(255, 225, 150), font=f)
    x = 0
    for i in rang:
        ligne1.paste(i, (x, 44 + H1 - i.height))
        x += i.width + 10
    # 2. bande de course (direction est = 2) et bande d'attaque (direction sud = 4), 24 px/tuile pour tenir en largeur
    bandes = []
    for anim, direction, titre in (("course", 2, "run_animation : 8 images, direction est"), ("attaque", 4, "attaque : 4 images, direction sud")):
        cells, K = images_de(spr[nom][anim], direction)
        ims = [SC.to_im(compose(c, K, 20, (0.1, 0.92, 1.0), 0.6, fond_val=0.38)) for c in cells]
        W = sum(i.width for i in ims) + 6 * (len(ims) - 1)
        H = max(i.height for i in ims)
        b = Image.new("RGB", (W, H + 30), (20, 20, 24))
        ImageDraw.Draw(b).text((8, 4), titre, fill=(255, 225, 150), font=f2)
        x = 0
        for i in ims:
            b.paste(i, (x, 30))
            x += i.width + 6
        bandes.append(b)
    Wt = max([ligne1.width] + [b.width for b in bandes])
    Ht = ligne1.height + sum(b.height + 8 for b in bandes)
    out = Image.new("RGB", (Wt, Ht), (20, 20, 24))
    out.paste(ligne1, (0, 0))
    y = ligne1.height
    for b in bandes:
        out.paste(b, (0, y + 8))
        y += b.height + 8
    p = os.path.join(dest, "planche-%s.png" % fichier)
    out.save(p, optimize=True)
    telephone(out, os.path.join(dest, "planche-%s-telephone.png" % fichier))
    return p, out.size


def mutants(spr, dest):
    """Planche des Écorchés : une ligne par variante (rôdeur, porteur, hurleur) : les ères ouvertes à l'échelle du jeu (zoom 2 : 64 px/tuile,
    ils sont petits) avec la lueur de l'ère, puis la bande de course (direction est) de la première variante."""
    f = SC.police(26)
    f2 = SC.police(17)
    lignes = []
    for i, v in enumerate(spr["__ecorches"]):
        cells, K = images_de(spr["ecorche"][str(i + 1)]["course"], 3)
        rang = []
        for era in sorted(int(k) for k in v["eres"]):
            e = v["eres"][str(era)]
            im = SC.to_im(compose(cells[0], K, 64, tuple(e["tint"]), e["glow"], scale=e["scale"]))
            ImageDraw.Draw(im).text((6, 6), "ère %d" % era, fill=(170, 240, 255), font=f2)
            rang.append(im)
        beh = SC.behemoth(64)
        sc = SC.Scene(6, 6, 64, seed=5)
        bim = SC.to_im(sc.rendu([{"pos": (3, 4.5), "layers": beh}]))
        ImageDraw.Draw(bim).text((6, 6), "behemoth", fill=(245, 245, 245), font=f2)
        rang.append(bim)
        W = sum(x.width for x in rang) + 8 * (len(rang) - 1)
        H = max(x.height for x in rang)
        l = Image.new("RGB", (W, H + 36), (20, 20, 24))
        ImageDraw.Draw(l).text((10, 6), "Écorché %s (zoom 2 du jeu, 64 px/tuile)" % v["id"], fill=(255, 225, 150), font=f2)
        x = 0
        for im in rang:
            l.paste(im, (x, 36 + H - im.height))
            x += im.width + 8
        lignes.append(l)
    cells, K = images_de(spr["ecorche"]["1"]["course"], 2)
    ims = [SC.to_im(compose(c, K, 48, (0.1, 0.92, 1.0), 0.6, fond_val=0.38)) for c in cells]
    W = sum(i.width for i in ims) + 6 * (len(ims) - 1)
    H = max(i.height for i in ims)
    b = Image.new("RGB", (W, H + 30), (20, 20, 24))
    ImageDraw.Draw(b).text((8, 4), "run_animation du rôdeur : 8 images, direction est (48 px/tuile)", fill=(255, 225, 150), font=f2)
    x = 0
    for i in ims:
        b.paste(i, (x, 30))
        x += i.width + 6
    lignes.append(b)
    Wt = max(l.width for l in lignes)
    Ht = 44 + sum(l.height + 8 for l in lignes)
    out = Image.new("RGB", (Wt, Ht), (20, 20, 24))
    ImageDraw.Draw(out).text((12, 8), "ÉCORCHÉS, mordeurs mutants pondus par l'Écorcheur · trois variantes · une ère par âge (lueur = couleur de l'ère)", fill=(255, 225, 150), font=f)
    y = 44
    for l in lignes:
        out.paste(l, (0, y))
        y += l.height + 8
    p = os.path.join(dest, "planche-mutants.png")
    out.save(p, optimize=True)
    telephone(out, os.path.join(dest, "planche-mutants-telephone.png"))
    return p, out.size


def rose(spr, dest, nom, stade="3"):
    """ART-16DIR (11/11) : les 16 directions (ou 8) d'un allié animé, image 0 de la marche du stade `stade`, à 20 px/tuile, en grille 4 × 4
    dans l'ordre du moteur (0 = nord, sens horaire), avec la direction de chaque vue. planche-<nom>-directions.png (et -telephone)."""
    from PIL import ImageFont
    try:
        f2 = ImageFont.truetype("arial.ttf", 18)
    except OSError:
        f2 = ImageFont.load_default()
    e = spr[nom][stade]
    n = len(e["course"]["couches"]["main"]["hr"])
    noms = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
    ims = []
    for k in range(n):
        cells, K = images_de(e["course"], None, seizieme=k * 16 // n)
        im = SC.to_im(compose(cells[0], K, 20, (1.0, 1.0, 1.0), 1.0, fond_val=0.38))
        ImageDraw.Draw(im).text((8, 6), "%d / %d : %s" % (k, n, noms[k * 16 // n]), fill=(255, 225, 150), font=f2)
        ims.append(im)
    cw, ch = max(i.width for i in ims), max(i.height for i in ims)
    col = 4
    lig = (n + col - 1) // col
    out = Image.new("RGB", (cw * col, ch * lig + 40), (20, 20, 24))
    ImageDraw.Draw(out).text((10, 8), "%s, stade %s : %d directions de marche (image 0), ordre du moteur" % (nom.upper(), stade, n),
                             fill=(255, 225, 150), font=f2)
    for k, im in enumerate(ims):
        out.paste(im, ((k % col) * cw + (cw - im.width) // 2, 40 + (k // col) * ch + (ch - im.height) // 2))
    p = os.path.join(dest, "planche-%s-directions.png" % nom)
    out.save(p, optimize=True)
    telephone(out, os.path.join(dest, "planche-%s-directions-telephone.png" % nom))
    return p, out.size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=LOGS)
    ap.add_argument("--sans-kaiju", action="store_true")
    ap.add_argument("--sans-allies", action="store_true")
    ap.add_argument("--allies", default="juggernaut,sentinelle,leviathan,ravageur")
    ap.add_argument("--ennemis", default="kaiju,ecorcheur,mutants")
    ap.add_argument("--rose", default="", help="ART-16DIR : planche des directions de ces alliés (ex. juggernaut,sentinelle,ravageur)")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    spr = lua_table(os.path.join(SPRITES, "sprites.lua"))
    for nom in [x for x in a.rose.split(",") if x]:
        print(*rose(spr, a.dest, nom), flush=True)
    if not a.sans_allies:
        for nom in [x for x in a.allies.split(",") if x]:
            print(*allie(spr, a.dest, nom), flush=True)
    if not a.sans_kaiju:
        for nom in [x for x in a.ennemis.split(",") if x]:
            print(*(mutants(spr, a.dest) if nom == "mutants" else kaiju(spr, a.dest, nom)), flush=True)


if __name__ == "__main__":
    main()
