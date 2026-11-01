"""LIVRABLES D'UN ÂGE DE LA SÉRIE DES QG : <dest>/ageNN-z1.png (zoom 1, à côté de l'épave vanilla et de la raffinerie, sans en-tête)
et <dest>/ageNN-gros.png (zoom 2, sur le sol, sprite centré à marges fixes), au format des états validés. Python 3.9.

    py -3.9 tools/render/pieces/levels/vaisseau_o/images_qg.py --src <sprites> --nom qg07 --age 7 --titre "Âge 7 · Cristal" --dest <images>
"""
import argparse
import json
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
import compo as K  # noqa: E402

ENTETE = 40       # px d'en-tête de planche.py, retirés
HAUT = 11.82      # hauteur de case en tuiles : 414 px une fois l'en-tête retiré
OY = 7.0


def z1(src, nom, titre, dest):
    tmp = dest + ".tmp.png"
    noms = ",".join(("%s|%s|%s" % (nom, src, titre), "van:vaisseau|%s|Vanilla : épave du vaisseau" % src, "van:raffinerie|%s|Vanilla : raffinerie" % src))
    subprocess.check_call([sys.executable, os.path.join(HERE, "planche.py"), "--src", src, "--dest", tmp, "--noms", noms, "--zoom", "1",
                           "--haut", str(HAUT), "--oy", str(OY), "--titre", " "])
    im = Image.open(tmp)
    im.crop((0, ENTETE, im.size[0], im.size[1])).save(dest, optimize=True)
    os.remove(tmp)


def gros(src, nom, dest, mx=24, my=19):
    spec = json.load(open(os.path.join(src, nom, "spec.json"), encoding="utf-8"))
    m = spec["layers"]["main"]
    W, H = m["width"] + 2 * mx, m["height"] + 2 * my
    px = (W / 2.0) / 64.0 - m["shift"][0]
    py = (H / 2.0) / 64.0 - m["shift"][1]
    day, _, _ = K.compose([{"pos": (px, py), "layers": K.own(src, nom, ("shadow", "main", "glow"))}], W / 64.0, H / 64.0)
    K.to_im(day).save(dest, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--nom", required=True)
    ap.add_argument("--age", type=int, required=True)
    ap.add_argument("--titre", required=True)
    ap.add_argument("--dest", required=True)
    a = ap.parse_args()
    z1(a.src, a.nom, a.titre, os.path.join(a.dest, "age%02d-z1.png" % a.age))
    gros(a.src, a.nom, os.path.join(a.dest, "age%02d-gros.png" % a.age))
    print(a.dest, "age%02d" % a.age)


if __name__ == "__main__":
    main()
