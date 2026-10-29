"""AVANT / APRÈS : empile deux planches de même largeur de cellule (lot CENTRE-FUSEE). Python 3.9.

    py -3.9 tools/render/pieces/levels/fusee_e/avant_apres.py --avant A.png --apres B.png --dest C.png
        [--etiquettes "v2" "v3 propre"] [--largeur 2400]
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont


def font(n):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", n)
    except OSError:
        return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--avant", required=True)
    ap.add_argument("--apres", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--etiquettes", nargs=2, default=["AVANT (v2)", "APRÈS (v3 propreté)"])
    ap.add_argument("--largeur", type=int, default=2400)
    a = ap.parse_args()
    A, B = Image.open(a.avant).convert("RGB"), Image.open(a.apres).convert("RGB")
    W = max(A.width, B.width)
    bande = 34
    H = A.height + B.height + 2 * bande
    out = Image.new("RGB", (W, H), (22, 22, 26))
    d = ImageDraw.Draw(out)
    d.text((10, 6), a.etiquettes[0], fill=(255, 150, 120), font=font(22))
    out.paste(A, (0, bande))
    d.text((10, bande + A.height + 6), a.etiquettes[1], fill=(140, 235, 150), font=font(22))
    out.paste(B, (0, 2 * bande + A.height))
    if W > a.largeur:
        k = a.largeur / float(W)
        out = out.resize((a.largeur, int(H * k)), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    out.save(a.dest, optimize=True)
    print(a.dest, out.size, "%.2f Mo" % (os.path.getsize(a.dest) / 1e6))


if __name__ == "__main__":
    main()
