"""Vignettes du test à l'aveugle (lot V3-E) : une image par époque, le bâtiment seul (niveau impair de l'époque ;
époque 1 : niveau 2), zoom 1, jour, pose E, sol vanilla, cadre carré 384 × 384 centré sur l'emprise, sans légende ni
chiffre. Nom de fichier ALÉATOIRE (8 caractères hexadécimaux tirés par le système).

    py -3.9 tools/render/pieces/levels/gun_e_bas/vignettes_e.py <dossier out> <dossier vignettes> [--epochs 1-9]

La correspondance (fichier -> époque, niveau) n'est écrite NULLE PART sur le disque : elle n'est imprimée que sur la
sortie standard, pour la valeur de retour de l'agent. Ne pas rediriger cette sortie vers un fichier.
"""
import argparse
import os
import secrets
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("dest")
    ap.add_argument("--epochs", default="1,2,3,4,5,6,7,8,9")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    eps = [int(x) for x in a.epochs.split(",") if x]
    order = list(eps)
    secrets.SystemRandom().shuffle(order)
    for e in order:
        lays = K.level_layers(a.out, e, "E", e == 1)
        T = 12.0  # 12 tuiles à 64 px = 768 px, réduits à 384 (zoom 1)
        day, _ = K.compose([{"pos": (T / 2, T / 2), "layers": lays}], T, T)
        img = K.to_im(K.down2(day))
        assert img.size == (384, 384), img.size
        while True:
            name = secrets.token_hex(4) + ".png"
            p = os.path.join(a.dest, name)
            if not os.path.exists(p):
                break
        img.save(p)
        print("%s\tepoque=%d\tniveau=%d" % (os.path.abspath(p).replace("\\", "/"), e, 2 if e == 1 else 2 * e - 1))


if __name__ == "__main__":
    main()
