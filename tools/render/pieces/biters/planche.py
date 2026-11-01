"""PLANCHES des biters (lot RB-V0). Python 3.9, hors Blender.
    py -3.9 tools/render/pieces/biters/planche.py apercu --src <dossier de rendus> --dest x.png     (toutes les images du dossier)
    py -3.9 tools/render/pieces/biters/planche.py livre --souche cuirasse --src <dossier final> --dest <dossier>
livre écrit <souche>-z1.png (à l'échelle du jeu : small-biter, la souche, behemoth-biter, gun-turret, jour et nuit, zoom 1 puis zoom 2),
<souche>-gros.png (gros plan à la densité du rendu), <souche>-course.png (les images de course, même échelle, zoom 2).
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "levels", "commun")))
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import compo as K  # noqa: E402

BITER = K.DATA + "/base/graphics/entity/biter/"
GUN = K.DATA + "/base/graphics/entity/gun-turret/"
PPT = 64


def retaille(img, f):
    """Retaille une image RGBA (sRGB, alpha droit) d'un facteur f, en lumière linéaire prémultipliée."""
    if abs(f - 1.0) < 1e-6:
        return img
    h, w = img.shape[:2]
    a = img[..., 3]
    lin = P.srgb_to_lin(img[..., :3]) * a[..., None]
    nw, nh = max(1, int(round(w * f))), max(1, int(round(h * f)))
    filtre = Image.LANCZOS if f < 1 else Image.BICUBIC
    out = np.zeros((nh, nw, 4))
    for i in range(3):
        out[..., i] = np.asarray(Image.fromarray(lin[..., i].astype(np.float32), "F").resize((nw, nh), filtre))
    out[..., 3] = np.clip(np.asarray(Image.fromarray(a.astype(np.float32), "F").resize((nw, nh), filtre)), 0, 1)
    rgb = np.where(out[..., 3:4] > 1e-5, np.clip(out[..., :3], 0, None) / np.maximum(out[..., 3:4], 1e-5), 0)
    return np.concatenate([P.lin_to_srgb(np.clip(rgb, 0, 1)), out[..., 3:4]], -1)


def lire_rendu(d):
    with open(os.path.join(d, "render.json"), encoding="utf-8") as f:
        info = json.load(f)
    nom = os.path.basename(d)
    main = np.load(os.path.join(d, nom + "-main.npy"))
    ao = np.load(os.path.join(d, nom + "-ao.npy"))
    sh = np.load(os.path.join(d, nom + "-shadow.npy"))
    return info, P.compose_main(main, ao, C), P.shadow_layer(sh)


def couches_souche(d, echelle=1.0, ppt=PPT):
    """Couches pour K.compose, à ppt px par tuile, souche × échelle."""
    info, main, sh = lire_rendu(d)
    f = ppt / info["densite"] * echelle
    ox, oy = info["origin_px"]
    W, H = info["canvas"]
    sft = ((W / 2.0 - ox) * f / ppt, (H / 2.0 - oy) * f / ppt)
    return [{"img": retaille(sh, f), "shift": sft, "kind": "shadow"}, {"img": retaille(main, f), "shift": sft, "kind": "main"}]


def _png(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float64) / 255.0


def _cadre(prefixe, w, h, idx):
    """Image idx d'une feuille de course vanilla : 4 fichiers de 8 × 8 images."""
    fic, reste = divmod(idx, 64)
    lig, col = divmod(reste, 8)
    im = _png(BITER + "hr-biter-run-%s%02d.png" % (prefixe, fic + 1))
    return im[lig * h:(lig + 1) * h, col * w:(col + 1) * w]


def couches_biter(scale, t1, t2, direction=10, image=2, ppt=PPT):
    """Vrai biter HR vanilla (data/base/prototypes/entity/biter-animations.lua), masques teints composés."""
    idx = direction * 16 + image
    f = ppt / 64.0 * scale                    # hr : scale = 0,5 × scale, donc 1 px = scale / 64 × 2 / 2... (64 px/tuile à scale 1)
    sh = _cadre("shadow-", 432, 292, idx)
    corps = _cadre("", 398, 310, idx)
    m1 = _cadre("mask1-", 238, 182, idx)
    m2 = _cadre("mask2-", 232, 184, idx)

    def t(img, tint):
        x = img.copy()
        x[..., :3] = x[..., :3] * np.array(tint)
        return x

    def s(px, py):
        return (px / 32.0 * scale, py / 32.0 * scale)

    return [{"img": retaille(sh, f), "shift": s(8, -1), "kind": "shadow"},
            {"img": retaille(corps, f), "shift": s(-1, -5), "kind": "main"},
            {"img": retaille(t(m1, t1), f), "shift": s(-1, -37), "kind": "main"},
            {"img": retaille(t(m2, t2), f), "shift": s(0, -38), "kind": "main"}]


def couches_tourelle(ppt=PPT):
    f = ppt / 64.0
    base = _png(GUN + "hr-gun-turret-base.png")
    tir = _png(GUN + "hr-gun-turret-shooting-1.png")[:130, :132]
    ombre = _png(GUN + "hr-gun-turret-shooting-shadow-1.png")[:124, :250]
    return [{"img": retaille(ombre, f), "shift": (22.5 / 32, 2.5 / 32), "kind": "shadow"},
            {"img": retaille(base, f), "shift": (0.5 / 32, -1 / 32), "kind": "main"},
            {"img": retaille(tir, f), "shift": (0, -27.5 / 32), "kind": "main"}]


SMALL = (0.5, (0.60, 0.58, 0.51), (0.9, 0.83, 0.54))
BEHEMOTH = (1.2, (0.21, 0.19, 0.25), (0.657, 0.95, 0.432))


def texte(sheet, xy, s, taille=14, coul=(235, 230, 215)):
    ImageDraw.Draw(sheet).text(xy, s, fill=coul, font=K.font(taille))


def scene_z(souche, d_pose, d_pose2, largeur, hauteur, base_y, essaim=(), echelle=1.0):
    """Scène côte à côte, en tuiles : small-biter, souche, autre vue de la souche, behemoth-biter, gun-turret."""
    x_small = 1.3
    ents = [{"pos": (x_small, base_y), "layers": couches_biter(*SMALL)}]
    ents.append({"pos": (largeur * 0.37, base_y), "layers": couches_souche(d_pose, echelle)})
    if d_pose2:
        ents.append({"pos": (largeur * 0.60, base_y), "layers": couches_souche(d_pose2, echelle)})
    for (dx, dy, dd) in essaim:
        ents.append({"pos": (largeur * 0.37 + dx, base_y + dy), "layers": couches_souche(dd, echelle)})
    ents.append({"pos": (largeur - 4.2, base_y), "layers": couches_biter(*BEHEMOTH)})
    ents.append({"pos": (largeur - 1.3, base_y), "layers": couches_tourelle()})
    return K.compose(ents, largeur, hauteur)


def dossiers(src, souche):
    return sorted(d for d in glob.glob(os.path.join(src, souche + "-*")) if os.path.isdir(d))


def z1(souche, src, dest, etiquette, largeur, hauteur, base_y, pose, pose2, essaim_de=None, echelle=1.0):
    essaim = []
    if essaim_de:
        ds = dossiers(src, souche)
        ds = [d for d in ds if d.endswith(essaim_de)]
        ps = [(1.15, -0.9), (1.8, 0.1), (1.05, 0.95), (-1.25, -0.8), (-1.5, 0.5), (0.45, 1.6), (2.3, 1.15)]
        for i, (dx, dy) in enumerate(ps):
            essaim.append((dx, dy, ds[i % len(ds)]))
    day, night, _ = scene_z(souche, os.path.join(src, pose), os.path.join(src, pose2) if pose2 else None, largeur, hauteur, base_y, essaim, echelle)
    jour1, nuit1 = K.to_im(K.down2(day)), K.to_im(K.down2(night))
    jour2 = K.to_im(day)
    W = max(jour1.width * 2 + 8, jour2.width) + 16
    H = 30 + jour1.height + 26 + jour2.height + 10
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    texte(sheet, (8, 6), "%s, zoom 1 : jour | nuit. Vanilla : small-biter (gauche), behemoth-biter, gun-turret (droite)" % etiquette, 15)
    sheet.paste(jour1, (8, 30))
    sheet.paste(nuit1, (8 + jour1.width + 8, 30))
    texte(sheet, (8, 34 + jour1.height), "Même scène, zoom 2 (64 px/tuile)", 15)
    sheet.paste(jour2, (8, 30 + jour1.height + 26))
    sheet.save(dest)
    print(dest, sheet.size)


def sol_a(w, h, densite):
    gt = K.ground_tile()
    f = densite / 64.0
    gi = Image.fromarray((gt * 255).astype(np.uint8)).resize((int(gt.shape[1] * f), int(gt.shape[0] * f)), Image.BICUBIC)
    g = np.asarray(gi).astype(np.float64) / 255.0
    return np.tile(g, (h // g.shape[0] + 1, w // g.shape[1] + 1, 1))[:h, :w].copy()


def gros(d, dest, etiquette, cadre=None):
    info, main, sh = lire_rendu(d)
    h, w = main.shape[:2]
    fond = sol_a(w, h, info["densite"])
    fond = fond * (1 - 0.5 * sh[..., 3:4])
    a = main[..., 3:4]
    out = main[..., :3] * a + fond * (1 - a)
    im = K.to_im(out)
    if im.width < 420:
        f = int(np.ceil(420 / im.width))
        im = im.resize((im.width * f, im.height * f), Image.LANCZOS)
    sheet = Image.new("RGB", (im.width + 16, im.height + 34), (22, 22, 26))
    texte(sheet, (8, 6), "%s, gros plan : %.0f px par tuile" % (etiquette, info["densite"]), 15)
    sheet.paste(im, (8, 28))
    sheet.save(dest)
    print(dest, sheet.size)


def course(ds, dest, etiquette, echelle=1.0, cols=None):
    cases = []
    bords = []
    for d in ds:
        lays = couches_souche(d, echelle)
        for l in lays:
            h, w = l["img"].shape[:2]
            bords.append((l["shift"][0] * PPT - w / 2, l["shift"][1] * PPT - h / 2, l["shift"][0] * PPT + w / 2, l["shift"][1] * PPT + h / 2))
        cases.append(lays)
    x0, y0 = min(b[0] for b in bords), min(b[1] for b in bords)
    x1, y1 = max(b[2] for b in bords), max(b[3] for b in bords)
    T_w, T_h = (x1 - x0) / PPT + 0.1, (y1 - y0) / PPT + 0.1
    pos = (-x0 / PPT + 0.05, -y0 / PPT + 0.05)
    ims = [K.to_im(K.compose([{"pos": pos, "layers": l}], T_w, T_h)[0]) for l in cases]
    cols = cols or len(ims)
    rows = (len(ims) + cols - 1) // cols
    cw, ch = ims[0].size
    sheet = Image.new("RGB", (cols * (cw + 4) + 12, rows * (ch + 4) + 34), (22, 22, 26))
    texte(sheet, (8, 6), "%s, course : %d images d'une foulée, zoom 2, même échelle" % (etiquette, len(ims)), 15)
    for i, im in enumerate(ims):
        r, c = divmod(i, cols)
        sheet.paste(im, (6 + c * (cw + 4), 30 + r * (ch + 4)))
    sheet.save(dest)
    print(dest, sheet.size)


def apercu(src, dest, densite_fixe=None):
    """Toutes les images d'un dossier, gros plan sur sol, en grille."""
    ds = sorted(d for d in glob.glob(os.path.join(src, "*")) if os.path.isfile(os.path.join(d, "render.json")))
    ims = []
    for d in ds:
        info, main, sh = lire_rendu(d)
        h, w = main.shape[:2]
        fond = sol_a(w, h, info["densite"]) * (1 - 0.5 * sh[..., 3:4])
        a = main[..., 3:4]
        ims.append((os.path.basename(d), K.to_im(main[..., :3] * a + fond * (1 - a)), info))
    W = sum(i[1].width + 6 for i in ims) + 6
    H = max(i[1].height for i in ims) + 28
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    x = 6
    for nom, im, info in ims:
        texte(sheet, (x, 4), "%s %d sommets %.0fs" % (nom, info["sommets"], info["seconds"]), 12)
        sheet.paste(im, (x, 22))
        x += im.width + 6
    sheet.save(dest)
    print(dest, sheet.size)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("quoi", choices=("apercu", "livre"))
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--souche", default="")
    a = ap.parse_args()
    if a.quoi == "apercu":
        apercu(a.src, a.dest)
        return
    s = a.souche
    if s == "cuirasse":
        z1(s, a.src, os.path.join(a.dest, "cuirasse-z1.png"), "Cuirassé (de face, de profil)", 22.0, 6.0, 3.2, "cuirasse-000-225", "cuirasse-000-090")
        gros(os.path.join(a.src, "cuirasse-000-225"), os.path.join(a.dest, "cuirasse-gros.png"), "Cuirassé")
        course([d for d in dossiers(a.src, s) if d.endswith("-225")], os.path.join(a.dest, "cuirasse-course.png"), "Cuirassé")
    elif s == "moucheron":
        z1(s, a.src, os.path.join(a.dest, "moucheron-z1.png"), "Moucheron (seul au centre, puis en essaim comme en jeu)", 17.0, 5.6, 2.8, "moucheron-000-225", "moucheron-000-090", essaim_de="-225", echelle=1.3)
        gros(os.path.join(a.src, "moucheron-000-225"), os.path.join(a.dest, "moucheron-gros.png"), "Moucheron")
        course([d for d in dossiers(a.src, s) if d.endswith("-225")], os.path.join(a.dest, "moucheron-course.png"), "Moucheron", echelle=2.0)
    elif s == "ecraseur":
        z1(s, a.src, os.path.join(a.dest, "ecraseur-z1.png"), "Écraseur (de face, de profil)", 31.0, 10.0, 6.2, "ecraseur-000-225", "ecraseur-000-090")
        gros(os.path.join(a.src, "ecraseur-000-225"), os.path.join(a.dest, "ecraseur-gros.png"), "Écraseur")
        course([d for d in dossiers(a.src, s) if d.endswith("-225")], os.path.join(a.dest, "ecraseur-course.png"), "Écraseur", cols=3)


if __name__ == "__main__":
    main()
