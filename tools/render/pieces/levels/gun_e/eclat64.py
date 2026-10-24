"""Éclat de tir à 64 directions (lot A3-jeu, 24/10) : bouche dessinée de chaque pose, réglage du moteur, écarts, planche.
Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/eclat64.py --ages 2-15 [--masques DIR] [--a3 DIR] [--planche DOSSIER]
        [--zoom 2] [--json SORTIE]

Pour chaque âge : les 64 poses sont lues dans la production (feuilles.poses_64 : V, A2 et A3 contrôlées) quand
l'âge est complet ; sinon la silhouette vient des MASQUES RAPIDES d'A3 (alpha à 99,87 % identique à la production,
F141 ; bouchon des âges 4 à 7 : masques de la rampe 0,8, comme produire_a3.py) : PRÉVISION, dite comme telle.
Mêmes fonctions que feuilles.py (bouche_u, ajuste_tir_u, marges_u) ; réglage AVANT (lot A2 : d00, d16, d32, d48) et
APRÈS (moindres carrés sur 64) ; écart de chaque direction (le long, en travers), pire direction.
--planche : une image par âge, 64 cases dans l'ordre d00 à d63 (8 × 8), silhouette en gris, bouche dessinée (rouge),
cible (bouche + marge, jaune), éclat visible prévu par le réglage APRÈS (vert) et AVANT (bleu).
--couleur (correction M-1, 24/10) : la pose en COULEUR (couche principale de la production) au lieu de la silhouette,
pour juger à l'œil si l'éclat prévu (vert) naît au bout des canons ; --seules-ecartees : seulement les directions
ÉCARTÉES du réglage (une rangée), à regarder avant d'inscrire une direction dans ECLAT_ECARTEES_OK_DEFAUT de
feuilles.py (sinon l'âge reste à 4 directions). La ligne de chaque âge dit les écartées NON REGARDÉES (hors liste).
Règle du moteur prouvée hors des axes (vérification du lot, V2 : 60 tirs en diagonale, écart ≤ 0,008 tuile) : le
point vert est l'endroit où le moteur fait naître l'éclat (à la hauteur H_ECLAT près).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import feuilles as FE  # noqa: E402

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

MASQUES = os.path.join(FE.LOGS, "2026-10-24_A3", "masques", "m16")
RAMPE = os.path.join(FE.LOGS, "2026-10-24_A3", "bouchon", "rampe80")


def plage(spec):
    res = []
    for x in [x for x in str(spec).split(",") if x]:
        a, b = x.split("-") if "-" in x else (x, x)
        res += list(range(int(a), int(b) + 1))
    return res


def silhouettes(e, a):
    """64 entrées (« dKK », alpha uint8, gauche, haut, origine) : production si l'âge est complet, sinon masques."""
    valides = FE.plages(FE.VALIDES_DEFAUT)
    poses, motif = FE.poses_64(e, valides[e], a.so, a.a3, FE.HORS_REGLE_OK_DEFAUT)  # mêmes têtes que feuilles.py
    out = []
    if poses is not None:
        for dname, nom, d, org in poses:
            s, dd = FE.lire_spec(d, nom)
            L = s["layers"]["main"]
            gx, gy, _, _ = FE.boite_px(L)
            im = FE.rgba(os.path.join(dd, L["file"]))
            silhouettes.couleur[(e, dname)] = im
            out.append((dname, im[..., 3], gx, gy, "production"))
        return out, "production"
    import masques as MQ  # noqa: E402  (scipy, piece : seulement pour la prévision)
    if e in (4, 5, 6, 7):
        MQ.AUTRES[e] = RAMPE
    for k in range(64):
        dn = "d%02d" % k
        z = MQ.charge(a.masques, e, dn)
        al = (MQ.alpha_prod(z, e, dn) * 255).round().astype(np.uint8)
        ox, oy = (int(v) for v in z["origin"])
        out.append((dn, al, -ox, -oy, "masque"))
    return out, "masques (prévision ; %s)" % motif


silhouettes.couleur = {}


def analyse(e, a, marge):
    sil, origine = silhouettes(e, a)
    bouches, unites = {}, {}
    for dn, al, gx, gy, _ in sil:
        unites[dn] = FE.unite_pose(dn)
        bouches[dn] = FE.bouche_u(al, gx, gy, dn)
    card = {c: bouches["d%02d" % k] for c, k in FE.CARDINAUX.items()}
    cy4, d4 = FE.ajuste_tir(card, marge)
    cy4, d4 = round(cy4, 5), round(d4, 5)
    ec4 = FE.ecarts_de(FE.marges_u(bouches, unites, cy4, d4), marge)
    cy, d, _, rejet = FE.ajuste_robuste(bouches, unites, marge)
    cy, d = round(cy, 5), round(d, 5)
    ec_tous = FE.ecarts_de(FE.marges_u(bouches, unites, cy, d), marge)
    ec = {k: v for k, v in ec_tous.items() if k not in rejet}
    pire = lambda E: max(E, key=lambda k: E[k][0] ** 2 + E[k][1] ** 2)  # noqa: E731
    return {"age": e, "origine": origine, "avant": {"tir": [cy4, d4], "max64": round(FE.pire_de(ec4), 4),
                                                     "pire": pire(ec4)},
            "apres": {"tir": [cy, d], "max64": round(FE.pire_de(ec), 4), "pire": pire(ec), "ecarts": ec_tous,
                      "ecartees": rejet, "max_toutes": round(FE.pire_de(ec_tous), 4)},
            "ecarts_avant": ec4, "bouches": bouches, "unites": unites, "sil": sil}


def planche(R, marge, dest, zoom, couleur=False, seules=None):
    sil = R["sil"]
    L0 = min(gx for _, al, gx, gy, _ in sil)
    T0 = min(gy for _, al, gx, gy, _ in sil)
    R0 = max(gx + al.shape[1] for _, al, gx, gy, _ in sil)
    B0 = max(gy + al.shape[0] for _, al, gx, gy, _ in sil)
    # marge pour voir l'éclat : 1,5 tuile autour
    L0, T0, R0, B0 = L0 - 96, T0 - 96, R0 + 96, B0 + 96
    W, H = (R0 - L0), (B0 - T0)
    f = zoom / 2.0       # px hr (64/tuile) -> px de la planche (32 × zoom / tuile)
    cw, ch = int(W * f), int(H * f) + 14
    cases = [x for x in sil if seules is None or x[0] in seules]
    ncol = 8 if seules is None else max(1, min(6, len(cases)))
    nlig = max(1, (len(cases) + ncol - 1) // ncol)
    im = Image.new("RGB", (ncol * cw, nlig * ch), (40, 44, 40))
    dr = ImageDraw.Draw(im)
    cy, d = R["apres"]["tir"]
    cy4, d4 = R["avant"]["tir"]
    for k, (dn, al, gx, gy, _) in enumerate(cases):
        ox, oy = (k % ncol) * cw, (k // ncol) * ch
        taille = (max(1, int(al.shape[1] * f)), max(1, int(al.shape[0] * f)))
        a = Image.fromarray(al).resize(taille, Image.BILINEAR)
        c = silhouettes.couleur.get((R["age"], dn)) if couleur else None
        if c is not None:
            src = Image.fromarray(c[..., :3]).resize(taille, Image.LANCZOS)
        else:
            src = Image.new("RGB", a.size, (150, 150, 150))
        im.paste(src, (ox + int((gx - L0) * f), oy + int((gy - T0) * f)), a)

        def pt(x, y):  # tuiles -> px de la planche
            return ox + (x * 64 - L0) * f, oy + (y * 64 - T0) * f

        def croix(x, y, c, r=3):
            px, py = pt(x, y)
            dr.line([(px - r, py), (px + r, py)], fill=c, width=2)
            dr.line([(px, py - r), (px, py + r)], fill=c, width=2)

        ox0, oy0 = pt(0, 0)
        dr.ellipse([ox0 - 2, oy0 - 2, ox0 + 2, oy0 + 2], outline=(255, 255, 255))
        bx, by = R["bouches"][dn]
        ux, uy = R["unites"][dn]
        croix(bx + marge * ux, by + marge * uy, (255, 220, 0))
        vx, vy = FE.eclat_visible_u(cy4, d4, (ux, uy))
        croix(vx, vy, (80, 140, 255))
        vx, vy = FE.eclat_visible_u(cy, d, (ux, uy))
        croix(vx, vy, (60, 230, 60))
        croix(bx, by, (255, 40, 40), 2)
        e = R["apres"]["ecarts"][dn]
        rej = dn in R["apres"]["ecartees"]
        dr.text((ox + 3, oy + ch - 13), "%s %.2f/%.2f%s" % (dn, e[0], e[1], " ECARTEE" if rej else ""),
                fill=(255, 120, 120) if rej else (230, 230, 230))
    p = os.path.join(dest, "eclat64-e%02d%s%s-z%d.png" % (R["age"], "-ecartees" if seules is not None else "",
                                                         "-couleur" if couleur else "", zoom))
    im.save(p)
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ages", default="2-15")
    ap.add_argument("--masques", default=MASQUES)
    ap.add_argument("--a3", default=FE.A3_DEFAUT)
    ap.add_argument("--so", default=FE.SO_DEFAUT)
    ap.add_argument("--data", default=FE.DATA_DEFAUT)
    ap.add_argument("--planche", default=None)
    ap.add_argument("--zoom", type=int, default=2)
    ap.add_argument("--json", default=None)
    ap.add_argument("--couleur", action="store_true", help="poses en couleur (âges complets seulement)")
    ap.add_argument("--seules-ecartees", action="store_true", help="planche des seules directions écartées")
    a = ap.parse_args()
    ok_par_age = FE.ecartees_ok_de(FE.ECLAT_ECARTEES_OK_DEFAUT)
    vb = FE.bouches_vanille(a.data)
    mv = FE.marges(vb, FE.VANILLE["projectile_center"][1], FE.VANILLE["projectile_creation_distance"])
    marge = sum(mv[d][0] for d in FE.MARGE_DIRS) / len(FE.MARGE_DIRS)
    res = []
    for e in plage(a.ages):
        R = analyse(e, a, marge)
        av, apr = R["avant"], R["apres"]
        nv = [dn for dn in apr["ecartees"] if dn not in ok_par_age.get(e, set())]
        print("[FO-ECLAT64] âge %2d (%s) : AVANT (réglage A2 centre %.5f, distance %.5f) pire %.3f en %s %s ; APRÈS "
              "(centre %.5f, distance %.5f) pire %.3f en %s %s ; %s" % (
                  e, R["origine"], av["tir"][0], av["tir"][1], av["max64"], av["pire"], R["ecarts_avant"][av["pire"]],
                  apr["tir"][0], apr["tir"][1], apr["max64"], apr["pire"], apr["ecarts"][apr["pire"]],
                  ("REFUSÉ (> %.2f)" % FE.SEUIL_ECLAT if apr["max64"] > FE.SEUIL_ECLAT
                   or len(apr["ecartees"]) > (1 - FE.GARDE_MIN) * 64 else "accepté")
                  + " ; écartées (bouche mal mesurée) %d : %s (pire de toutes %.3f)" % (
                      len(apr["ecartees"]), ",".join(apr["ecartees"]), apr["max_toutes"])
                  + " ; NON REGARDÉES (hors ECLAT_ECARTEES_OK_DEFAUT : l'âge resterait à 4) : %s" % (
                      ",".join(nv) if nv else "aucune")))
        R["non_regardees"] = nv
        if a.planche:
            os.makedirs(a.planche, exist_ok=True)
            if a.seules_ecartees and not apr["ecartees"]:
                print("[FO-ECLAT64]   planche : aucune direction écartée, rien à regarder")
            else:
                print("[FO-ECLAT64]   planche : %s" % planche(R, marge, a.planche, a.zoom, a.couleur,
                                                            apr["ecartees"] if a.seules_ecartees else None))
        res.append({k: v for k, v in R.items() if k not in ("sil", "unites")})
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(res, f, indent=1, sort_keys=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
