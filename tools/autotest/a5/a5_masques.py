"""Lot A5-ESSAI (25/10) : feuilles de MASQUE D'ÉQUIPE de la tête (3 âges, essai) et copie JETABLE du mod. Python 3.9.

    py -3.9 tools/autotest/a5/a5_masques.py composer --rendu DIR --dest DIR [--intensites 25,40,60] [--g0 0.85]
        Pour chaque âge rendu (a5_equipe.py rendre), la couverture VISIBLE des pièces choisies (CHOIX ci-dessous) devient
        une feuille de masque de la tête, mêmes cellules que la couche principale (sprites.json : 8 × 8, mêmes
        largeur, hauteur et shift ; chaque pose à sa place « poses »), en haute (hr) et en normale (lr, réduction 2×) :
          gris  = G0 × (0,5 + 0,5 × L / Lm), borné à [0,15 ; 1] : L luminance du pixel de PRODUCTION, Lm sa moyenne
                  sur les pièces choisies de l'âge (le modelé est gardé à moitié, le niveau est le même d'un âge à
                  l'autre : sur une pièce noire, une teinte qui multiplie ne se verrait pas, F36, F38) ;
          alpha = couverture visible (bornée par l'alpha de production) × intensité.
        Une feuille par intensité : hr-gun-eNN-tete-equipe-iXX.png et gun-eNN-tete-equipe-iXX.png. Aucune image de
        base n'est lue autrement qu'en lecture : les feuilles de la tête ne changent pas.
        DEST/equipe.json : pixels, part de la tête, boîtes d'alpha par cellule (hr, lr), accord des silhouettes.
    py -3.9 tools/autotest/a5/a5_masques.py jetable --masques DIR --dest DIR
        Copie JETABLE du mod (sans .git, .claude, tools/render) + feuilles de masque + a5_equipe_proto.lua (copies des
        tourelles des 3 âges, une par intensité, nommées a5-gun-eNN-iXX, avec la couche de masque) branché en fin de
        data-final-fixes.lua. Le mod livré n'est pas touché.
"""
import argparse
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import a5_equipe as AE  # noqa: E402

# pièces retenues par âge (planches de diagnostic, fo-logs/2026-10-25_A5/diag) : un élément compact et un liseré
CHOIX = {3: ["tourelleau", "capot"], 9: ["tourelleau", "liseré"], 15: ["ligne_panneau", "plaque"]}
NIVEAU = {3: 5, 9: 17, 15: 29}      # niveau impair de l'âge (socle + tête), fo-lvl-gun-N


def lum(rgb8):
    a = rgb8.astype(np.float64) / 255.0
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def reduit2(rgba):
    """Réduction 2× d'une image RGBA flottante à alpha droit (moyenne prémultipliée)."""
    h, w = rgba.shape[:2]
    a = rgba[..., 3:4]
    pm = (rgba[..., :3] * a).reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3))
    a2 = a.reshape(h // 2, 2, w // 2, 2, 1).mean((1, 3))
    rgb = np.where(a2 > 1e-8, pm / np.maximum(a2, 1e-8), 0)
    return np.concatenate([rgb, a2], -1)


def u8(x):
    return np.clip(np.rint(x * 255.0), 0, 255).astype(np.uint8)


def boites(alpha, w, h, ll, n):
    """Somme des boîtes d'alpha (> 0) des n cellules (F147 : le moteur range les images rognées)."""
    px = 0
    for k in range(n):
        c = alpha[(k // ll) * h:(k // ll + 1) * h, (k % ll) * w:(k % ll + 1) * w]
        ys, xs = np.nonzero(c > 0)
        if ys.size:
            px += (ys.max() - ys.min() + 1) * (xs.max() - xs.min() + 1)
    return int(px)


def composer(a):
    sp = json.load(open(os.path.join(MOD, "graphics", "levels", "gun", "sprites.json"), encoding="utf-8"))
    intens = [int(x) for x in a.intensites.split(",")]
    os.makedirs(a.dest, exist_ok=True)
    rap = {"g0": a.g0, "intensites": intens, "choix": {str(k): v for k, v in CHOIX.items()}, "ages": {}}
    for e in sorted(CHOIX):
        if a.ages and e not in AE.plage(a.ages):
            continue
        de = os.path.join(a.rendu, "e%02d" % e)
        if not os.path.isdir(de):
            print("[A5-MASQUES] âge %d : pas de rendu, sauté" % e)
            continue
        T = sp["ages"][str(e)]["tete"]["main"]
        W, H, ll, n = T["hr"]["width"], T["hr"]["height"], T["hr"]["line_length"], T["hr"]["direction_count"]
        L0 = int(round(T["hr"]["shift"][0] * 64 - W / 2.0))
        T0 = int(round(T["hr"]["shift"][1] * 64 - H / 2.0))
        rows = n // ll
        poses = []
        s_l, s_c = 0.0, 0.0
        accords = []
        bornes = 0
        for K in range(n):
            d = "d%02d" % K
            im, gx, gy, _ = AE.couche_prod(e, K)
            h, w = im.shape[:2]
            pz = T["poses"][d]
            if (pz["x"], pz["y"]) != (gx - L0, gy - T0):
                raise SystemExit("âge %d %s : place de la pose %s, sprites.json %s" % (e, d, (gx - L0, gy - T0),
                                                                                  (pz["x"], pz["y"])))
            if (gx % 2) or (gy % 2) or (w % 2) or (h % 2):
                raise SystemExit("âge %d %s : boîte impaire" % (e, d))
            z = np.load(os.path.join(de, "e%02d-%s.npz" % (e, d)))
            al = AE.recadre(z, "alpha", gx, gy, w, h)
            accords.append(AE.accord_silhouette(al, im))
            c = np.zeros((h, w))
            for g in CHOIX[e]:
                c += AE.recadre(z, "g_" + g, gx, gy, w, h).astype(np.float64) / 255.0
            pa = im[..., 3].astype(np.float64) / 255.0
            bornes += int((c > pa + 1e-6).sum())
            c = np.minimum(np.minimum(c, 1.0), pa)
            L = lum(im[..., :3])
            s_l += float((L * c).sum())
            s_c += float(c.sum())
            poses.append((K, gx - L0, gy - T0, c, L))
        Lm = s_l / max(s_c, 1e-9)
        A = {"pieces": CHOIX[e], "niveau": NIVEAU[e], "lum_moyenne_pieces": round(Lm, 4),
             "accord_silhouettes_min": round(min(accords), 4), "accord_silhouettes_moyen": round(float(np.mean(accords)), 4),
             "pixels_bornes_par_alpha_prod": bornes, "intensites": {}}
        for it in intens:
            hr = np.zeros((rows * H, ll * W, 4))
            lr = np.zeros((rows * H // 2, ll * W // 2, 4))
            for K, x, y, c, L in poses:
                g = np.clip(a.g0 * (0.5 + 0.5 * L / max(Lm, 1e-6)), 0.15, 1.0)
                m = np.zeros(c.shape + (4,))
                m[..., 0] = m[..., 1] = m[..., 2] = np.where(c > 0, g, 0.0)
                m[..., 3] = c * it / 100.0
                cx, cy = (K % ll) * W + x, (K // ll) * H + y
                hr[cy:cy + c.shape[0], cx:cx + c.shape[1]] = m
                ml = reduit2(m)
                lr[cy // 2:cy // 2 + ml.shape[0], cx // 2:cx // 2 + ml.shape[1]] = ml
            fh = "hr-gun-e%02d-tete-equipe-i%02d.png" % (e, it)
            fl = "gun-e%02d-tete-equipe-i%02d.png" % (e, it)
            h8, l8 = u8(hr), u8(lr)
            for arr, f in ((h8, fh), (l8, fl)):
                arr[arr[..., 3] == 0, :3] = 0
                Image.fromarray(arr, "RGBA").save(os.path.join(a.dest, f), optimize=True, compress_level=9)
            A["intensites"][str(it)] = {
                "hr": {"fichier": fh, "pixels_alpha": int((h8[..., 3] > 0).sum()),
                       "boites_alpha_px": boites(h8[..., 3], W, H, ll, n), "octets": os.path.getsize(os.path.join(a.dest, fh))},
                "lr": {"fichier": fl, "pixels_alpha": int((l8[..., 3] > 0).sum()),
                       "boites_alpha_px": boites(l8[..., 3], W // 2, H // 2, ll, n),
                       "octets": os.path.getsize(os.path.join(a.dest, fl))}}
        # tête de production (couche principale) : mêmes mesures, pour la part
        th = np.asarray(Image.open(os.path.join(MOD, "graphics", "levels", "gun", os.path.basename(T["hr"]["filename"]))))
        tl = np.asarray(Image.open(os.path.join(MOD, "graphics", "levels", "gun", os.path.basename(T["lr"]["filename"]))))
        A["tete"] = {"hr": {"pixels_alpha": int((th[..., 3] > 0).sum()), "boites_alpha_px": boites(th[..., 3], W, H, ll, n)},
                     "lr": {"pixels_alpha": int((tl[..., 3] > 0).sum()),
                            "boites_alpha_px": boites(tl[..., 3], W // 2, H // 2, ll, n)},
                     "def": {"hr": T["hr"], "lr": T["lr"]}}
        # boîtes de CHAQUE pièce seule (coût d'un masque réduit à une pièce : la dispersion fait le coût)
        A["boites_par_piece_hr"] = {}
        for g in CHOIX[e]:
            tot = 0
            for K, x, y, c, L in poses:
                im, gx, gy, _ = AE.couche_prod(e, K)
                z = np.load(os.path.join(de, "e%02d-d%02d.npz" % (e, K)))
                cg = AE.recadre(z, "g_" + g, gx, gy, im.shape[1], im.shape[0])
                ys, xs = np.nonzero(cg > 0)
                if ys.size:
                    tot += (ys.max() - ys.min() + 1) * (xs.max() - xs.min() + 1)
            A["boites_par_piece_hr"][g] = int(tot)
        rap["ages"][str(e)] = A
        i0 = A["intensites"][str(intens[0])]
        print("[A5-MASQUES] âge %d (%s) : pixels hr %d (tête %d, %.1f %%) ; boîtes hr %d px (tête %d, %.1f %%), lr %d ; "
              "silhouettes d'accord %.2f %% au pire ; Lm %.3f" % (
                  e, "+".join(CHOIX[e]), i0["hr"]["pixels_alpha"], A["tete"]["hr"]["pixels_alpha"],
                  100.0 * i0["hr"]["pixels_alpha"] / A["tete"]["hr"]["pixels_alpha"], i0["hr"]["boites_alpha_px"],
                  A["tete"]["hr"]["boites_alpha_px"], 100.0 * i0["hr"]["boites_alpha_px"] / A["tete"]["hr"]["boites_alpha_px"],
                  i0["lr"]["boites_alpha_px"], 100 * A["accord_silhouettes_min"], Lm), flush=True)
    with open(os.path.join(a.dest, "equipe.json"), "w", encoding="utf-8") as f:
        json.dump(rap, f, indent=1, ensure_ascii=False, sort_keys=True)
    return 0


PROTO = r'''-- LOT A5-ESSAI (copie JETABLE, tools/autotest/a5/a5_masques.py) : copies des mitrailleuses des âges essayés, une par
-- intensité du masque d'équipe, avec la couche de masque (flags « mask », apply_runtime_tint, comme le masque vanilla
-- de la mitrailleuse, data/base/prototypes/entity/turrets.lua) au-dessus de la couche principale de la tête, dans les
-- 5 animations. Rien de ceci n'existe dans le mod livré.
local ESSAI = @@ESSAI@@
local TETE = { "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation",
  "folding_animation" }
--- La couche de masque est une COPIE de la couche principale de la tête telle que le mod l'a finie (même cadre, même
--- shift, même échelle), dont seuls le fichier et les drapeaux changent.
local function masque(main, d)
  assert(string.find(main.filename, "tete%-main", 1) and main.width == d.width and main.height == d.height,
    "a5 : couche principale inattendue " .. tostring(main.filename))
  local t = table.deepcopy(main)
  t.hr_version = nil
  t.filename = d.filename
  t.flags = { "mask" }
  t.apply_runtime_tint = true
  t.draw_as_glow, t.draw_as_shadow, t.draw_as_light, t.blend_mode = nil, nil, nil, nil
  return t
end
for _, x in ipairs(ESSAI) do
  local src = data.raw["ammo-turret"][x.source]
  assert(src, "a5 : " .. x.source .. " absent")
  local p = table.deepcopy(src)
  p.name = x.nom
  p.localised_name = { "", "A5 ", tostring(x.age), " ", tostring(x.intensite) }
  p.next_upgrade = nil
  for _, k in ipairs(TETE) do
    local L = p[k].layers
    local c = masque(L[1], x.lr)
    c.hr_version = masque(L[1].hr_version, x.hr)
    table.insert(L, 2, c)
  end
  data:extend({ p })
  log("[FO-A5] " .. x.nom .. " : masque " .. x.hr.filename)
end
'''


def jetable(a):
    rap = json.load(open(os.path.join(a.masques, "equipe.json"), encoding="utf-8"))
    dest = os.path.abspath(a.dest)
    if os.path.exists(dest):
        raise SystemExit("dossier déjà là : %s (un dossier NEUF)" % dest)

    def ign(d, names):
        out = {".git", ".claude"}
        if os.path.normpath(d) == os.path.join(MOD, "tools"):
            out.add("render")
        return [x for x in names if x in out]

    shutil.copytree(MOD, dest, ignore=ign)
    pre = "__factorio-overhaul__/graphics/levels/gun/"
    essai = []
    for e, A in sorted(rap["ages"].items(), key=lambda kv: int(kv[0])):
        T = A["tete"]["def"]
        for it, I in sorted(A["intensites"].items(), key=lambda kv: int(kv[0])):
            for r in ("hr", "lr"):
                shutil.copy2(os.path.join(a.masques, I[r]["fichier"]),
                             os.path.join(dest, "graphics", "levels", "gun", I[r]["fichier"]))
            d = {}
            for r in ("hr", "lr"):
                t = dict(T[r])
                t["filename"] = pre + I[r]["fichier"]
                d[r] = t
            essai.append({"nom": "a5-gun-e%02d-i%02d" % (int(e), int(it)), "source": "fo-lvl-gun-%d" % A["niveau"],
                          "age": int(e), "intensite": int(it), "hr": d["hr"], "lr": d["lr"]})

    def lua(v, ind=""):
        if isinstance(v, dict):
            return "{ " + ", ".join("%s = %s" % (k, lua(x)) for k, x in sorted(v.items())) + " }"
        if isinstance(v, (list, tuple)):
            return "{ " + ", ".join(lua(x) for x in v) + " }"
        if isinstance(v, str):
            return json.dumps(v)
        if isinstance(v, bool):
            return "true" if v else "false"
        return repr(v)

    with open(os.path.join(dest, "a5_equipe_proto.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(PROTO.replace("@@ESSAI@@", "{\n  " + ",\n  ".join(lua(x) for x in essai) + "\n}"))
    p = os.path.join(dest, "data-final-fixes.lua")
    t = open(p, encoding="utf-8", newline="").read()
    t += '\n-- LOT A5-ESSAI (copie jetable) : mitrailleuses d\'essai du masque d\'équipe\nrequire("a5_equipe_proto")\n'
    open(p, "w", encoding="utf-8", newline="").write(t)
    print("[A5-JETABLE] %s : %d prototype(s) d'essai (%s)" % (dest, len(essai), ", ".join(x["nom"] for x in essai)))
    return 0


def apercu(a):
    """Aperçu HORS JEU (contrôle de forme seulement, pas une preuve) : masque composé sur la tête de la feuille, teinte
    simulée par la règle du masque (sortie = base × (1 − α) + α × gris × teinte, couleur de force d'alpha 1)."""
    rap = json.load(open(os.path.join(a.masques, "equipe.json"), encoding="utf-8"))
    teintes = [(1.0, 1.0, 1.0)] + [tuple(float(v) for v in t.split("/")) for t in a.teintes.split(",")]
    lignes = []
    for e, A in sorted(rap["ages"].items(), key=lambda kv: int(kv[0])):
        T = A["tete"]["def"]["hr"]
        W, H, ll = T["width"], T["height"], T["line_length"]
        base = np.asarray(Image.open(os.path.join(MOD, "graphics", "levels", "gun", os.path.basename(T["filename"])))
                          ).astype(np.float64) / 255.0
        for K in AE.plage(a.dirs):
            r0, c0 = (K // ll) * H, (K % ll) * W
            b = base[r0:r0 + H, c0:c0 + W]
            cases = []
            for it, I in [("0", None)] + sorted(A["intensites"].items(), key=lambda kv: int(kv[0])):
                m = None
                if I is not None:
                    m = np.asarray(Image.open(os.path.join(a.masques, I["hr"]["fichier"]))).astype(np.float64)[
                        r0:r0 + H, c0:c0 + W] / 255.0
                for t in (teintes[1:] if I is not None else teintes[:1]):
                    rgb = b[..., :3].copy()
                    if m is not None:
                        al = m[..., 3:4]
                        rgb = rgb * (1 - al) + al * m[..., :3] * np.array(t)
                    img = np.concatenate([rgb, b[..., 3:4]], -1)
                    case = Image.new("RGBA", (W, H), (70, 74, 66, 255))
                    case.alpha_composite(Image.fromarray(u8(img), "RGBA"))
                    cases.append(case)
            ligne = Image.new("RGBA", (len(cases) * W, H), (0, 0, 0, 255))
            for k, c in enumerate(cases):
                ligne.alpha_composite(c, (k * W, 0))
            k = min(1.0, float(a.largeur) / ligne.size[0])
            lignes.append(ligne.resize((int(ligne.size[0] * k), int(ligne.size[1] * k)), Image.LANCZOS) if k < 1 else ligne)
    Wt = max(l.size[0] for l in lignes)
    out = Image.new("RGBA", (Wt, sum(l.size[1] for l in lignes)), (0, 0, 0, 255))
    y = 0
    for l in lignes:
        out.alpha_composite(l, (0, y))
        y += l.size[1]
    out.convert("RGB").save(a.out, optimize=True)
    print("[A5-APERCU] %s : %d × %d" % (a.out, out.size[0], out.size[1]))
    return 0


def cout(a):
    """Coût ESTIMÉ du masque aux 15 âges : boîtes d'alpha de la tête de chaque âge (feuilles actuelles, 64 directions)
    × la part mesurée (boîtes du masque / boîtes de la tête) sur les âges essayés ; rangement F187 (× 1,19 en haute,
    × 1,44 en normale). Une estimation, pas une mesure du moteur."""
    rap = json.load(open(os.path.join(a.masques, "equipe.json"), encoding="utf-8"))
    sp = json.load(open(os.path.join(MOD, "graphics", "levels", "gun", "sprites.json"), encoding="utf-8"))
    tete = {}
    for e in range(2, 16):
        T = sp["ages"][str(e)]["tete"]["main"]
        r = {}
        for q in ("hr", "lr"):
            d = T[q]
            im = np.asarray(Image.open(os.path.join(MOD, "graphics", "levels", "gun", os.path.basename(d["filename"]))))
            r[q] = boites(im[..., 3], d["width"], d["height"], d["line_length"], d["direction_count"])
        tete[e] = r
    th = sum(v["hr"] for v in tete.values())
    tl = sum(v["lr"] for v in tete.values())
    lignes = ["Têtes, couche principale, 15 âges (2 à 15) à 64 directions : boîtes d'alpha hr %.2f Mpx, normale %.2f Mpx"
              % (th / 1e6, tl / 1e6)]
    parts = {}
    for e, A in sorted(rap["ages"].items(), key=lambda kv: int(kv[0])):
        I = list(A["intensites"].values())[0]
        ph = I["hr"]["boites_alpha_px"] / float(A["tete"]["hr"]["boites_alpha_px"])
        pl = I["lr"]["boites_alpha_px"] / float(A["tete"]["lr"]["boites_alpha_px"])
        parts[e] = (ph, pl)
        seul = {g: v / float(A["tete"]["hr"]["boites_alpha_px"]) for g, v in A["boites_par_piece_hr"].items()}
        lignes.append("âge %s (%s) : boîtes du masque / boîtes de la tête : hr %.1f %%, normale %.1f %% ; une pièce seule (hr) : %s"
                      % (e, "+".join(A["pieces"]), 100 * ph, 100 * pl,
                         ", ".join("%s %.1f %%" % (g, 100 * v) for g, v in sorted(seul.items()))))
    for nom, sel in (("bas (part la plus faible mesurée)", min), ("haut (part la plus forte mesurée)", max)):
        ph = sel(p[0] for p in parts.values())
        pl = sel(p[1] for p in parts.values())
        lignes.append("15 âges, %s : hr %.1f à %.1f Mpx (× 1,10 à 1,19), normale %.1f Mpx (× 1,44, F187)"
                      % (nom, th * ph * 1.10 / 1e6, th * ph * 1.19 / 1e6, tl * pl * 1.44 / 1e6))
    txt = "\n".join(lignes)
    print(txt)
    with open(os.path.join(a.masques, "cout-15-ages.txt"), "w", encoding="utf-8") as f:
        f.write(txt + "\n")
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("composer")
    c.add_argument("--rendu", required=True)
    c.add_argument("--dest", required=True)
    c.add_argument("--intensites", default="25,40,60")
    c.add_argument("--g0", type=float, default=0.85)
    c.add_argument("--ages", default="")
    j = sub.add_parser("jetable")
    j.add_argument("--masques", required=True)
    j.add_argument("--dest", required=True)
    p = sub.add_parser("apercu")
    p.add_argument("--masques", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--dirs", default="24")
    p.add_argument("--teintes", default="0.85/0.18/0.16,0.20/0.45/0.95")
    p.add_argument("--largeur", type=int, default=2400)
    k = sub.add_parser("cout")
    k.add_argument("--masques", required=True)
    a = ap.parse_args()
    return {"composer": composer, "jetable": jetable, "apercu": apercu, "cout": cout}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
