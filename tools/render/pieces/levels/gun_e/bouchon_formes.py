"""Lot A3 (24/10), décision D-10 : essais de FORMES du bouchon arrière sur masques rapides. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/bouchon_formes.py --dest DIR --forme NOM=xf0,xf1,yf0,yf1,zf0,zf1 [...]
        [--ages 4-7] [--samples 16]

Pour chaque forme (sous-boîte de la boîte d'A2, corps.bouchon_forme), rend les masques des âges donnés dans les 64
directions (masques.py rendre, variable FO_BOUCHON_FORME, par le verrou de rendu), puis résume : secteur (trou sans
bouchon > 8 px), plus grand trou AVEC la forme dans le secteur, pixels visibles de la forme aux bords et dans le
secteur. La forme « A2 » (vide) est le bouchon d'A2 tel quel. Sortie : DIR/<nom>/ (masques) et DIR/formes.txt.
"""
import argparse
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import masques as MQ  # noqa: E402


def resume(dossier, ages):
    lignes = []
    for e in ages:
        rows = []
        for k in range(64):
            z = MQ.charge(dossier, e, "d%02d" % k)
            ts = MQ.plus_grand_trou(z["alpha_sans"] / 255.0)[2]
            ta = MQ.plus_grand_trou(z["alpha"] / 255.0)[2]
            vis = int((z["bouchon"] >= 128).sum())
            rows.append((ts, ta, vis))
        sect = [k for k in range(64) if rows[k][0] > MQ.SEUIL_TROU]
        if not sect:
            lignes.append("  âge %d : aucun trou > 8 px" % e)
            continue
        # bande = suite CONTIGUË des directions à trou > 8 px qui contient d32 (les trous isolés ailleurs, d10, d13,
        # d14…, ne sont pas ceux que le bouchon ferme : ils sont listés à part)
        k0 = k1 = 32
        while k0 - 1 >= 0 and rows[k0 - 1][0] > MQ.SEUIL_TROU:
            k0 -= 1
        while k1 + 1 < 64 and rows[k1 + 1][0] > MQ.SEUIL_TROU:
            k1 += 1
        band = list(range(k0, k1 + 1))
        pire = max(rows[k][1] for k in band)
        vis_b = [rows[k][2] for k in band]
        lignes.append("  âge %d : secteur d%02d-d%02d (%d dir. > 8 px%s) ; trou max AVEC dans la bande %d px (%s) ; "
                      "visible : entrée d%02d %d px, sortie d%02d %d px, bande min %d max %d ; hors bande max %d" % (
                          e, k0, k1, len(sect), "" if sect == band else ", isolées " + ",".join(
                              "d%02d" % k for k in sect if k not in band),
                          pire, "OK" if pire <= MQ.SEUIL_TROU else "ECHEC", k0, rows[k0][2], k1, rows[k1][2],
                          min(vis_b), max(vis_b), max(rows[k][2] for k in range(64) if k not in band)))
        lignes.append("     trou sans : " + " ".join("%d" % r[0] for r in rows))
        lignes.append("     trou avec : " + " ".join("%d" % r[1] for r in rows))
        lignes.append("     visible   : " + " ".join("%d" % r[2] for r in rows))
    return lignes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--forme", action="append", required=True)
    ap.add_argument("--ages", default="4-7")
    ap.add_argument("--samples", type=int, default=16)
    a = ap.parse_args()
    ages = MQ.plage(a.ages)
    out = []
    for f in a.forme:
        nom, val = f.split("=", 1)
        d = os.path.join(a.dest, nom)
        if not all(os.path.exists(os.path.join(d, "e%02d" % e, "masques.json")) for e in ages):
            env = dict(os.environ, FO_BOUCHON_FORME=val)
            rc = subprocess.call([sys.executable, os.path.join(HERE, "masques.py"), "rendre", "--out", d, "--ages",
                                  a.ages, "--samples", str(a.samples)], env=env)
            if rc:
                print("forme %s : rendu en échec (%d)" % (nom, rc))
                return rc
        out.append("forme %s = %s" % (nom, val or "bouchon d'A2"))
        out += resume(d, ages)
    txt = "\n".join(out)
    print(txt)
    with open(os.path.join(a.dest, "formes.txt"), "a", encoding="utf-8") as fo:
        fo.write(txt + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
