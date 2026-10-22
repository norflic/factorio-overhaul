"""Rendu par paquets (lot V3-E, époques 1 à 9) : une session Blender par paquet, post-traitement et purge des passes
brutes après chaque paquet (disque H: presque plein), et le verrou de rendu rendu entre deux paquets (l'autre
constructeur rend aussi).

    py -3.9 tools/render/pieces/levels/gun_e_bas/lots.py --cache DIR --out DIR [--quick] [--samples N]
                                                          [--epochs 1,2,...] [--parts socle,piece,tete-E,tete-N]
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--epochs", default="1,2,3,4,5,6,7,8,9")
    ap.add_argument("--parts", default="piece,socle,tete-E,tete-N")
    ap.add_argument("--per", type=int, default=4, help="variantes par session Blender")
    a = ap.parse_args()
    names = []
    for e in [int(x) for x in a.epochs.split(",") if x]:
        for p in a.parts.split(","):
            if e == 1 and p != "piece":
                continue
            names.append("e%02d-%s" % (e, p))
    rc_all = 0
    for i in range(0, len(names), a.per):
        chunk = names[i:i + a.per]
        cmd = [sys.executable, os.path.join(HERE, "rendre.py"), "--only", ",".join(chunk), "--samples",
               str(a.samples), "--cache", a.cache, "--out", a.out]
        if a.quick:
            cmd.append("--quick")
        print("[FO-LOTS] paquet %d/%d : %s" % (i // a.per + 1, (len(names) + a.per - 1) // a.per, ",".join(chunk)),
              flush=True)
        rc = subprocess.call(cmd)
        rc_all = rc_all or rc
        if rc:
            print("[FO-LOTS] ECHEC du paquet (code %d)" % rc, flush=True)
    sys.exit(rc_all)


if __name__ == "__main__":
    main()
