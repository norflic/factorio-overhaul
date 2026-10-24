"""Socle émissif animé (lot A4) : le moteur anime-t-il base_picture ? Mesure sur les captures de nuit du scénario
a4-socle. Python 3.9.

    py -3.9 tools/autotest/a4_socle_images.py "<fo-shots de fo-captures.bat a4-socle>" [--planche SORTIE.png]

Par niveau : 8 captures de nuit à 30 ticks d'écart, même cadrage. Zone = pixels du socle éclairés (somme RGB > 60 sur
au moins une capture). Différence moyenne entre instants successifs (somme RGB) dans la zone, et énergie lumineuse de
chaque instant rapportée à la moyenne (min, max), pixels qui changent de plus de 3 (sur 255) d'un instant à l'autre.
Témoin (socle FIXE, niveau 9) : identique au pixel ; socle animé (niveaux 11 et 12) : plus de 100 pixels qui changent à
chaque pas. Code 0 si le témoin est fixe et les socles animés bougent.
"""
import argparse
import csv
import glob
import os
import sys

import numpy as np
from PIL import Image

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ANIMES = (11, 12)
TEMOIN = 9


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shots")
    ap.add_argument("--planche", default=None)
    a = ap.parse_args()
    rows = list(csv.DictReader(open(os.path.join(a.shots, "a4-socle-sites.tsv"), encoding="utf-8"), delimiter="\t"))
    par = {}
    for r in rows:
        if r["nuit"] == "1":
            f = glob.glob(os.path.join(a.shots, "[0-9][0-9][0-9]-%s.png" % r["capture"]))[0]
            par.setdefault(int(r["niveau"]), []).append(np.asarray(Image.open(f).convert("RGB")).astype(np.int32))
    ko = 0
    res = {}
    for n, ims in sorted(par.items()):
        st = np.stack(ims)
        zone = st.sum(-1).max(0) > 60
        diffs = [float(np.abs(st[i + 1] - st[i]).sum(-1)[zone].mean()) for i in range(len(ims) - 1)]
        bouge = [int((np.abs(st[i + 1] - st[i]).max(-1) > 3).sum()) for i in range(len(ims) - 1)]
        dmax = int(np.abs(st - st.mean(0)).max())
        en = st.sum(-1)[:, zone].sum(1).astype(np.float64)
        e_rel = en / en.mean()
        res[n] = (max(diffs), e_rel)
        # premier passage (24/10) : le motif « tourne » de l'âge 6 garde l'énergie totale (± 0,3 %) ; le critère est
        # donc le nombre de pixels qui changent d'un instant à l'autre, le témoin devant rester identique au pixel
        if n == TEMOIN:
            ok = max(diffs) == 0.0 and max(bouge) == 0
        else:
            ok = min(bouge) > 100
        ko += not ok
        print("[FO-A4-SOCLE-IMG] %s niveau %d (%s) : %d px de zone ; différence entre instants successifs (somme RGB "
              "moyenne) %s ; pixels qui changent de plus de 3 %s ; écart max à la moyenne %d ; énergie relative %s" % (
                  "OK    " if ok else "ECHEC ", n, "témoin, socle fixe" if n == TEMOIN else "socle animé",
                  int(zone.sum()), [round(x, 2) for x in diffs], bouge, dmax, [round(float(x), 3) for x in e_rel]))
    if a.planche:
        lignes = []
        for n, ims in sorted(par.items()):
            lignes.append(np.concatenate(ims, axis=1))
        Image.fromarray(np.clip(np.concatenate(lignes, axis=0), 0, 255).astype(np.uint8)).save(a.planche)
        print("[FO-A4-SOCLE-IMG] planche : %s" % a.planche)
    print("[FO-A4-SOCLE-IMG] BILAN : %d ECHEC(S)" % ko)
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
