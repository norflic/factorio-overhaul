"""OUTIL COMMUN : mesures de la charte (tools/da, inchangé) sur les niveaux composés. FICHIER GELÉ. Python 3.9.

    py -3.9 tools/render/pieces/levels/commun/mesures.py --out DIR --json mesures.json [--famille gun_e]
        [--epochs 1,…,15] [--kit 2,5]

Lot K0 : outil commun ; poses, compositions, sprites comptés, pièce paire, cibles, repère des points blancs et nom
de la famille : profil de la famille (profil.compositions, profil.sprites, profil.est_piece_paire, profil.CIBLE,
profil.LUCIOLES_MAX, profil.PIECE_MIN, profil.FAMILLE_PROG) ; familles de couleur : commun/ages.py.

Pour chaque époque, poses E et N, niveau impair et niveau pair (époque 1 : niveau 2 seulement, le niveau 1 est la
mesure vanilla de docs/da/mesures_vanilla.json) :
  1. CHARTE : da_lib.measure sur le corps composé (main + glow + light, sans ombre ; 64 px/tuile) ; planchers de
     tools/da/seuils.py + D1max 41, D3max 45, D3 >= 26, P1max 7,6 (protocole des juges de la passe 3) ; cibles du
     catalogue §A.4 (masse, pièces, O, zone lumineuse de jour) ;
  2. FOYERS : couleur moyenne pondérée de la couche glow (socle + tête) et sa FAMILLE (commun/ages.FAMILLES, règle d'or
     3) : « dans la famille » ou « HORS FAMILLE » ; plus grand foyer de la couche glow seule (<= 0,45 t²) ;
  3. POINTS BLANCS : pixels opaques de luminance >= 200 qui dépassent la médiane 3×3 de plus de 70, par t², sur
     chaque sprite principal HR ; repère vanilla 13,2 (feuille HR de la mitrailleuse) : au-delà, ÉCHEC ;
  4. PIÈCE PAIRE : masque nouveau (alpha >= 0,5) du niveau pair hors du niveau impair, catalogue >= 0,10 t².
Le fichier JSON sert à dominance.py. Code de sortie 1 si un contrôle bloquant échoue (points blancs, famille de
foyers, pièce paire, plancher de la charte).
"""
import argparse
import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ages as E  # noqa: E402  (lot K0 : familles de couleur communes, commun/ages.py)
import compo as K  # noqa: E402

D = K.D
sys.path.insert(0, K.OUTILS)
import seuils  # noqa: E402

# lot K0 : cibles, repère des points blancs et seuil de la pièce paire viennent du profil de la famille (main) ;
# valeurs de la mitrailleuse : gun_e/profil.py (inchangées)
CIBLE = {}
LUCIOLES_MAX = None
PIECE_MIN = None
PR = None


def _profil(nom):
    global CIBLE, LUCIOLES_MAX, PIECE_MIN, PR
    PR = K.utiliser(nom)
    CIBLE, LUCIOLES_MAX, PIECE_MIN = PR.CIBLE, PR.LUCIOLES_MAX, PR.PIECE_MIN
    return PR


def side_of(e):
    return int(e[1:]) if isinstance(e, str) else K.SIDE[e]


def floors(r):
    F = [(sid, ok, v, "%s %s" % (op, p)) for sid, k, v, op, p, ok in seuils.verdict(r)]
    F.append(("D1max", r["laplacien_moyen"] <= 41, r["laplacien_moyen"], "<= 41"))
    F.append(("D3max", r["petites_pieces_par_tuile2"] <= 45, r["petites_pieces_par_tuile2"], "<= 45"))
    F.append(("D3lot", r["petites_pieces_par_tuile2"] >= 26, r["petites_pieces_par_tuile2"], ">= 26"))
    F.append(("P1max", r["grain_surfaces"] <= 7.6, r["grain_surfaces"], "<= 7.6"))
    return F


def lucioles(path):
    a = np.asarray(Image.open(path).convert("RGBA"), np.float32)
    L = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    m = a[..., 3] >= 250
    P = np.pad(L, 1, mode="edge")
    st = np.stack([P[i:i + L.shape[0], j:j + L.shape[1]] for i in range(3) for j in range(3)], 0)
    med = np.median(st, 0)
    ff = (L >= 200) & (L - med > 70) & m
    return float(ff.sum() / max(1, m.sum()) * 4096), int(ff.sum())


def glow_stats(out, e, pose):
    lays = [l for l in K.level_layers(out, e, pose, False, kinds=("glow",))]
    if not lays:
        return None
    comp = D.compose([dict(l, kind="main") for l in lays])
    b = comp["body"]
    w = b[..., 3] * b[..., :3].max(axis=2)
    m = w > 0.25
    if not m.any():
        return None
    rgb = (b[..., :3][m] * w[m][:, None]).sum(0) / w[m].sum()
    h, s, v = colorsys.rgb_to_hsv(*[float(x) for x in rgb / max(1e-6, rgb.max())])
    sizes, _ = D.components(m, conn8=True)
    return {"hex": "%02X%02X%02X" % tuple(int(255 * min(1, x / rgb.max())) for x in rgb), "teinte": h * 360,
            "saturation": s, "plus_grand_glow_t2": max(sizes.values()) / 4096.0,
            "n_glow": sum(1 for x in sizes.values() if x >= 16)}


def piece_nouvelle(out, e, pose):
    """Masque nouveau du niveau pair hors du niveau impair (même canevas : la pièce est mise à zéro pour l'impair)."""
    ev = K.level_layers(out, e, pose, True, kinds=("main",))
    od = [dict(l, img=np.zeros_like(l["img"])) if PR.est_piece_paire(e, l.get("file", "")) else l for l in ev]
    if not ev:
        return None
    ca = D.compose(ev)["body"][..., 3] >= 0.5
    cb = D.compose(od)["body"][..., 3] >= 0.5
    return float((ca & ~cb).sum()) / 4096.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--json", required=True)
    ap.add_argument("--epochs", default="1,2,3,4,5,6,7,8,9,10,11,12,13,14,15")
    ap.add_argument("--kit", default="")
    K.option_famille(ap)
    a = ap.parse_args()
    _profil(a.famille or None)
    eps = [int(x) for x in a.epochs.split(",") if x] + ["k%s" % s for s in a.kit.split(",") if s]
    rows, echecs = [], []
    print("=" * 110)
    print("1. CHARTE (corps : main + glow + light, sans ombre ; 64 px/tuile)")
    for e in eps:
        side = side_of(e)
        for pose, even in PR.compositions(e):
            lays = K.level_layers(a.out, e, pose, even, kinds=("main", "glow", "light"))
            if not lays:
                continue
            comp = D.compose(lays)
            lvl = (2 * e - 1 + int(even)) if not isinstance(e, str) else 0
            r = D.measure(comp, side, "n%02d-%s" % (lvl, pose))
            if r is None:
                continue
            r.update({"epoque": e if not isinstance(e, str) else 0, "temoin": e if isinstance(e, str) else None,
                      "niveau": lvl, "pose": pose, "pair": even, "famille": PR.FAMILLE_PROG})
            F = floors(r)
            r["echecs"] = [f[0] for f in F if not f[1]]
            if not isinstance(e, str) and e in CIBLE:
                m, p, O, lum = CIBLE[e]
                r["cible_ok"] = {"masse": r["masse_tuiles2"] >= m, "pieces": r["petites_pieces"] >= p,
                                 "O": r["O_depassement_haut"] <= O,
                                 "lum_bande": lum[0] - 1e-9 <= r["zone_lumineuse_part"] <= lum[1] + 1e-9}
            rows.append(r)
            print("%s %-4s %s %dx%d%s : %d échec(s) %s" % (
                r["nom"], e, pose, side, side, " (pair)" if even else "", len(r["echecs"]), ",".join(r["echecs"])))
            print("    D1 %.1f D3 %.1f (%d pièces) P1 %.2f P2 %.1f | C1 %.0f C2 %.0f C3 %.2f C7 %.3f C8 %.3f | L1 %.3f "
                  "L2 %.3f foyers %d | M1 %.2f M3 %.3f masse %.2f O %.2f" % (
                      r["laplacien_moyen"], r["petites_pieces_par_tuile2"], r["petites_pieces"], r["grain_surfaces"],
                      r["variance_basse_freq"], r["lum_p50"], r["lum_p95"], r["part_teinte_chaude_corps"],
                      r["part_peinte_froide_hors_lumineux"], r["part_quasi_blanc"], r["zone_lumineuse_part"],
                      r["plus_grand_foyer_lumineux_tuiles2"], r["foyers_lumineux"], r["remplissage_emprise"],
                      r["part_massive"], r["masse_tuiles2"], r["O_depassement_haut"]))
    print("=" * 110)
    print("2. FOYERS : couleur mesurée (couche glow, moyenne pondérée) contre la FAMILLE de l'âge (commun/ages.FAMILLES)")
    foyers = []
    for e in eps:
        if isinstance(e, str) or e == 1:
            continue
        for pose in PR.POSES:
            gs = glow_stats(a.out, e, pose)
            if gs is None:
                print("  ép.%2d %s : pas de couche glow" % (e, pose))
                continue
            ok = E.dans_famille(e, gs["teinte"], gs["saturation"])
            fam = E.FAMILLES[e]
            gs.update({"epoque": e, "pose": pose, "famille": fam["nom"], "dans_famille": ok})
            foyers.append(gs)
            if not ok:
                echecs.append("foyers ép.%d %s hors famille" % (e, pose))
            print("  ép.%2d %s : #%s teinte %3.0f° sat %.2f ; famille « %s » (%s°, sat %s) : %s ; plus grand glow %.3f t²%s" % (
                e, pose, gs["hex"], gs["teinte"], gs["saturation"], fam["nom"], fam["teinte"], fam["sat"],
                "dans la famille" if ok else "HORS FAMILLE", gs["plus_grand_glow_t2"],
                "" if gs["plus_grand_glow_t2"] <= 0.45 else " <-- > 0,45"))
    print("=" * 110)
    print("3. POINTS BLANCS (luminance >= 200, > médiane 3×3 + 70 ; par t² ; repère vanilla %.1f)" % LUCIOLES_MAX)
    luc = []
    for e in eps:
        for var in PR.sprites(e):
            s = K.spec_of(a.out, var)
            if not s:
                continue
            p = os.path.join(K._dir(a.out, var), s["layers"]["main"]["file"])
            rate, n = lucioles(p)
            ok = rate <= LUCIOLES_MAX
            luc.append({"variante": var, "points_t2": rate, "points": n, "ok": ok})
            if not ok:
                echecs.append("points blancs %s" % var)
            print("  %-14s %6.1f points/t² (%d) %s" % (var, rate, n, "" if ok else "<-- ECHEC"))
    print("=" * 110)
    print("4. PIÈCE PAIRE : masque nouveau (catalogue >= %.2f t²)" % PIECE_MIN)
    pieces = []
    for e in eps:
        if isinstance(e, str):
            continue
        for pose in PR.POSES:
            t2 = piece_nouvelle(a.out, e, pose)
            if t2 is None:
                continue
            ok = t2 >= PIECE_MIN
            pieces.append({"epoque": e, "pose": pose, "t2": t2, "ok": ok})
            if not ok:
                echecs.append("pièce paire ép.%d %s" % (e, pose))
            print("  ép.%2d %s : %.3f t² %s" % (e, pose, t2, "ok" if ok else "TROP PETIT"))
    for r in rows:
        if r["echecs"]:
            echecs.append("charte %s ép.%s %s : %s" % (r["nom"], r["epoque"], r["pose"], ",".join(r["echecs"])))
    json.dump({"charte": rows, "foyers": foyers, "lucioles": luc, "pieces": pieces, "echecs": echecs},
              open(a.json, "w", encoding="utf-8"), indent=1, ensure_ascii=False, default=float)
    print("[FO-MESURES] %d mesures ; %d échec(s) bloquant(s)" % (len(rows), len(echecs)))
    sys.exit(1 if echecs else 0)


if __name__ == "__main__":
    main()
