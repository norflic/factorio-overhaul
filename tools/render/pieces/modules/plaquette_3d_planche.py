"""Planche de l'ESSAI 3D de la direction D (lot DESIGN-MODULES, 7/11) : PROPOSITION, rien n'est remplacé.

Prend les rendus de plaquette_3d_blender.py (<dossier>/3d-<type>-<palier>.png, 512 px, fond transparent), les cale sur la
silhouette de D en 2D (même boîte englobante de l'objet), pose la plaque du chiffre romain (vecteur à 64 px, au pixel à 32 px,
comme icones.icone_objet), puis compare vanilla, D en 2D et D en 3D (cases de la planche, et une maquette d'inventaire).
Usage : py -3.9 tools/render/pieces/modules/plaquette_3d_planche.py --dossier <dossier des rendus> --out <dossier>
        [--cas speed:5,productivity:5,effectivity:5,speed:1,speed:10]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import icones as I  # noqa: E402
import icones_directions as Dn  # noqa: E402
import icones_plaquette as P  # noqa: E402

NOMS = {"speed": "Vitesse", "productivity": "Productivité", "effectivity": "Efficacité"}


def boite(a, seuil):
    ys, xs = np.nonzero(a > seuil)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def calee(chemin, t):
    """Rendu 3D (sRGB, alpha droit) -> linéaire prémultiplié 512 px, calé sur la boîte de l'objet de D en 2D."""
    im = Image.open(chemin).convert("RGBA")
    if im.size != (I.N, I.N):
        im = im.resize((I.N, I.N), Image.LANCZOS)
    px = np.asarray(im).astype(np.float64) / 255.0
    a = px[..., 3]
    rgb = I.srgb_vers_lin(px[..., :3]) * a[..., None]
    x0, y0, x1, y1 = boite(a, 0.9)
    u0, v0, u1, v1 = boite(P.geometrie(t)["a_obj"], 0.5)
    s = (u1 - u0) / float(x1 - x0)          # même largeur que l'objet 2D ; hauteur libre (vraie perspective)
    # sortie (v, u) -> entrée (y, x) : y = y0 + (v - v0) / s ; x = x0 + (u - u0) / s
    mat = np.array([[1.0 / s, 0.0], [0.0, 1.0 / s]])
    off = np.array([y0 - v0 / s, x0 - u0 / s])
    out_a = ndimage.affine_transform(a, mat, offset=off, order=1, mode="constant", cval=0.0)
    out_rgb = np.stack([ndimage.affine_transform(rgb[..., c], mat, offset=off, order=1, mode="constant", cval=0.0) for c in range(3)], axis=-1)
    return out_rgb, np.clip(out_a, 0.0, 1.0)


def bande(rgb, a, t, k):
    rgb_p, a_p = P.plaque_vecteur(rgb, a, t, k)
    R = I.roles_type(t, k)
    im64 = I.en_image(*I.reduire(rgb_p, a_p, 64))
    im32 = I.poser_plaque_pixel(I.en_image(*I.reduire(rgb, a, 32)), k, 1, R)
    im16 = I.reduire_image(im32, 16)
    im8 = I.reduire_image(im16, 8)
    b = Image.new("RGBA", (120, 64), (0, 0, 0, 0))
    x = 0
    for im in (im64, im32, im16, im8):
        b.paste(im, (x, 0))
        x += im.size[0]
    return b


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dossier", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--cas", default="speed:5,productivity:5,effectivity:5,speed:1,speed:10")
    a = ap.parse_args(argv)
    cas = [(c.split(":")[0], int(c.split(":")[1])) for c in a.cas.split(",")]
    fond = (49, 48, 49)
    f_b, f_t = Dn.police(16, True), Dn.police(22, True)
    col = 220
    lignes = ("Vanilla", "D en 2D", "D en 3D (essai Blender)")
    im = Image.new("RGB", (230 + col * len(cas), 90 + 150 * len(lignes)), fond)
    d = ImageDraw.Draw(im)
    d.text((14, 12), "Direction D : la 2D et l'essai 3D (proposition, rien n'est remplacé)", fill=(235, 235, 235), font=f_t)
    bandes = {}
    for j, (t, k) in enumerate(cas):
        d.text((230 + j * col + 6, 62), "%s %s" % (NOMS[t], I.ROMAIN[k]), fill=(235, 235, 235), font=f_b)
        rgb, al = calee(os.path.join(a.dossier, "3d-%s-%d.png" % (t, k)), t)
        bandes[(t, k)] = (Dn.vanilla(t, min(k, 3)), P.icone_objet(t, k)[0], bande(rgb, al, t, k))
    for i, titre in enumerate(lignes):
        y = 90 + i * 150
        d.text((14, y + 56), titre, fill=(235, 235, 235), font=f_b)
        for j, c in enumerate(cas):
            b = bandes[c][i]
            im.paste(Dn.tuile(b, fond).convert("RGB"), (230 + j * col, y))
    os.makedirs(a.out, exist_ok=True)
    im.save(os.path.join(a.out, "essai-3d.png"))
    # maquette d'inventaire à 32 px (cases de 40 px), agrandie 2 fois
    case = 40
    fz = Dn.police(13, True)
    inv = Image.new("RGB", (16 + 220 + case * len(cas) + 16, 16 + 3 * (case + 8) + 8), (36, 35, 36))
    di = ImageDraw.Draw(inv)
    for i, titre in enumerate(lignes):
        y = 16 + i * (case + 8)
        di.text((16, y + 12), titre, fill=(225, 225, 225), font=Dn.police(14, True))
        for j, c in enumerate(cas):
            x = 236 + j * case
            di.rectangle((x, y, x + case - 2, y + case - 2), fill=(62, 60, 62), outline=(28, 27, 28))
            b32 = bandes[c][i].crop((64, 0, 96, 32))
            inv.paste(b32, (x + 3, y + 3), b32)
            n = "50"
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                di.text((x + case - 4 - di.textlength(n, font=fz) + ox, y + case - 17 + oy), n, fill=(0, 0, 0), font=fz)
            di.text((x + case - 4 - di.textlength(n, font=fz), y + case - 17), n, fill=(255, 255, 255), font=fz)
    inv.resize((inv.size[0] * 2, inv.size[1] * 2), Image.NEAREST).save(os.path.join(a.out, "essai-3d-inventaire-x2.png"))
    print("[FO-MODULES-3D] planches dans %s" % a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
