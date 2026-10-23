"""Preuve d'identité du dégel D-9 (lot A1) : têtes tournées dKK contre les poses validées (tete-N, tete-E). Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/identite.py --new DOSSIER --ref 2-12=DOSSIER --ref 13-15=DOSSIER
        [--paires e02-tete-d00=e02-tete-N,…]   (défaut : d00=N et d16=E pour chaque âge présent dans --new)

Pour chaque paire et chaque couche (main, shadow, glow, light), en hr ET en normale : largeur, hauteur, shift,
sha256 du PNG écrit (octet à octet), et si les octets diffèrent, l'écart au pixel (RGBA 0..255 : maximum, nombre de
pixels différents). Code de sortie 0 seulement si tout est identique octet à octet.
"""
import argparse
import hashlib
import json
import os
import re
import sys

import numpy as np
from PIL import Image


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def refs(specs):
    res = {}
    for s in specs:
        plage, d = s.split("=", 1)
        a, b = plage.split("-") if "-" in plage else (plage, plage)
        for e in range(int(a), int(b) + 1):
            res[e] = d
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--new", required=True)
    ap.add_argument("--ref", action="append", required=True)
    ap.add_argument("--paires", default="")
    a = ap.parse_args()
    R = refs(a.ref)
    if a.paires:
        paires = [p.split("=") for p in a.paires.split(",") if p]
    else:
        paires = []
        for n in sorted(os.listdir(a.new)):
            m = re.match(r"^e(\d\d)-tete-(d00|d16)$", n)
            if m:
                paires.append((n, "e%s-tete-%s" % (m.group(1), "N" if m.group(2) == "d00" else "E")))
    tout = True
    lignes = []
    for nv, rf in paires:
        e = int(nv[1:3])
        dn, dr = os.path.join(a.new, nv), os.path.join(R[e], rf)
        sn = json.load(open(os.path.join(dn, "spec.json"), encoding="utf-8"))
        sr = json.load(open(os.path.join(dr, "spec.json"), encoding="utf-8"))
        if sorted(sn["layers"]) != sorted(sr["layers"]):
            tout = False
            lignes.append("%s / %s : couches différentes %s / %s" % (nv, rf, sorted(sn["layers"]), sorted(sr["layers"])))
            continue
        for lay in sorted(sn["layers"]):
            for res in ("hr", "lr"):
                ln = sn["layers"][lay] if res == "hr" else sn["layers"][lay]["lr"]
                lr_ = sr["layers"][lay] if res == "hr" else sr["layers"][lay]["lr"]
                pn, pr = os.path.join(dn, ln["file"]), os.path.join(dr, lr_["file"])
                hn, hr_ = sha(pn), sha(pr)
                geo = (ln["width"], ln["height"], tuple(ln["shift"])) == (lr_["width"], lr_["height"], tuple(lr_["shift"]))
                ok = hn == hr_ and geo and hn == ln["sha256"] and hr_ == lr_["sha256"]
                detail = ""
                if not ok:
                    tout = False
                    if geo:
                        A = np.asarray(Image.open(pn).convert("RGBA")).astype(int)
                        B = np.asarray(Image.open(pr).convert("RGBA")).astype(int)
                        dif = np.abs(A - B)
                        detail = " ; écart au pixel max %d, %d pixels différents" % (dif.max(), int((dif.max(-1) > 0).sum()))
                    else:
                        detail = " ; géométrie %s contre %s" % ((ln["width"], ln["height"], ln["shift"]),
                                                              (lr_["width"], lr_["height"], lr_["shift"]))
                lignes.append("%-14s = %-11s %-6s %s %4dx%-4d shift %-22s sha256 %s %s%s" % (
                    nv, rf, lay, res, ln["width"], ln["height"], ln["shift"], hn[:16],
                    "IDENTIQUE" if ok else "DIFFERENT", detail))
    print("\n".join(lignes))
    print("BILAN : %d paires, %s" % (len(paires), "TOUT IDENTIQUE OCTET A OCTET" if tout else "ECART"))
    return 0 if tout else 1


if __name__ == "__main__":
    sys.exit(main())
