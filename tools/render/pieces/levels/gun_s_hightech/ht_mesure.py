"""Mesure des niveaux de l'explorateur « haute technologie » contre la charte DA_FACTORIO (lot V3-S), avec le MÊME
code que la charte (fo-logs/2026-10-22_V3S/charte/outils/da_lib.py et seuils.py, lus tels quels).

Composition (charte §2.1) : socle (main, glow, light) + tête de la pose (main, glow), 64 px/tuile, corps seul.
    python ht_mesure.py [--poses E,N] [--out <dossier>]
Sorties : mesures_hightech.json et .txt (verdict par plancher, cibles §6.2, dominance §6.1).
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ht_gun as H  # noqa: E402
import ht_post  # noqa: E402

CHARTE = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3S\charte\outils"
sys.path.insert(0, CHARTE)
import da_lib as D  # noqa: E402
import seuils as SE  # noqa: E402

# charte §6.2 (époque -> emprise, masse min, pièces min, O max, zone lumineuse de jour, systèmes, animations)
CIBLES = {11: {"side": 3, "masse": 8.1, "pieces": 251, "O": 1.2, "L1": (0.04, 0.06), "sys": 6, "anim": 3},
          21: {"side": 5, "masse": 20.5, "pieces": 536, "O": 2.0, "L1": (0.07, 0.10), "sys": 10, "anim": 4},
          29: {"side": 6, "masse": 32.4, "pieces": 849, "O": 2.4, "L1": (0.10, 0.12), "sys": 13, "anim": 6},
          30: {"side": 6, "masse": 32.4, "pieces": 849, "O": 2.4, "L1": (0.10, 0.12), "sys": 13, "anim": 6}}
# animations prévues par la fiche (comptées à la main, non rendues ici : rendu d'images fixes seulement)
ANIMS = {11: ["tir", "rotation des canons", "arc de l'éclateur"],
         21: ["tir", "rotation des canons", "chenillard des lignes", "ventilateur du générateur",
              "tourelle secondaire"],
         29: ["tir", "rotation des canons", "pulsation des cellules", "ventilateur du générateur",
              "tourelles secondaires", "lueur du cœur", "chenillard des lignes"],
         30: ["tir", "rotation des canons", "pulsation des cellules", "ventilateur du générateur",
              "tourelles secondaires", "lueur du cœur", "chenillard des lignes", "lancement des missiles"]}


def layers_of(variant, out_root):
    d = os.path.join(out_root, variant)
    with open(os.path.join(d, "spec.json"), encoding="utf-8") as f:
        spec = json.load(f)
    lay = []
    for k in ("main", "glow", "light"):
        if k in spec["layers"]:
            s = spec["layers"][k]
            lay.append({"img": D.load_rgba(os.path.join(d, s["file"])).copy(), "shift": tuple(s["shift"]), "kind": k,
                        "file": s["file"]})
    return lay, spec


def compose_level(level, pose, out_root):
    hl = 29 if level == 30 else level
    ls, ss = layers_of("n%02d-socle" % level, out_root)
    lh, sh = layers_of("n%02d-tete-%s" % (hl, pose), out_root)
    return D.compose(ls + lh), (ss, sh)


def verdict(r):
    out = []
    for sid, k, op, ps, pg, cible in SE.SEUILS:
        p = pg if SE.big(r) else ps
        v = r[k]
        ok = v >= p if op == ">=" else v <= p
        out.append((sid, k, v, op, p, cible, ok))
    return out


def dominance(a, b):
    """§6.1 : b (époque supérieure) domine a ?"""
    ind = [("emprise", a["emprise"], b["emprise"]), ("masse", a["masse_tuiles2"], b["masse_tuiles2"]),
           ("pièces", a["petites_pieces"], b["petites_pieces"]), ("systèmes", a["systemes"], b["systemes"]),
           ("énergie (t²)", a["zone_lumineuse_tuiles2"], b["zone_lumineuse_tuiles2"]),
           ("animations", a["animations"], b["animations"])]
    no_drop = all(y >= x for _, x, y in ind)
    ups = [n for n, x, y in ind if y > x]
    key_up = ("masse" in ups) or ("pièces" in ups)
    dens = b["petites_pieces_par_tuile2"] >= 0.95 * a["petites_pieces_par_tuile2"] and b["petites_pieces_par_tuile2"] >= 26
    ok = no_drop and len(ups) >= 2 and key_up and dens
    return ok, ind, ups, dens


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--poses", default="E,N")
    ap.add_argument("--levels", default="11,21,29,30")
    ap.add_argument("--out", default=os.path.join(HERE, "mesures"))
    ap.add_argument("--renders", default=ht_post.OUT)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    res = []
    lines = []
    for pose in a.poses.split(","):
        for lv in [int(x) for x in a.levels.split(",")]:
            try:
                comp, (ss, sh) = compose_level(lv, pose, a.renders)
            except FileNotFoundError as e:
                lines.append("n%02d %s : rendu absent (%s)" % (lv, pose, e))
                continue
            side = H.LEVELS[lv]["side"]
            r = D.measure(comp, side, "ht-n%02d-%s" % (lv, pose))
            r["niveau"], r["pose"], r["epoque"] = lv, pose, H.LEVELS[lv]["epoch"]
            r["emprise"] = side * side
            r["systemes_liste"] = H.systems(lv)
            r["systemes"] = len(r["systemes_liste"])
            r["animations_liste"] = ANIMS[lv]
            r["animations"] = len(ANIMS[lv])
            r["samples"] = ss["render"]["samples"]
            r["verdict"] = [(sid, k, v, op, p, c, ok) for sid, k, v, op, p, c, ok in verdict(r)]
            r["echecs"] = [x[0] for x in r["verdict"] if not x[6]]
            c = CIBLES[lv]
            r["cibles"] = {
                "masse": (r["masse_tuiles2"], ">=", c["masse"], r["masse_tuiles2"] >= c["masse"]),
                "pieces": (r["petites_pieces"], ">=", c["pieces"], r["petites_pieces"] >= c["pieces"]),
                "densite_26": (r["petites_pieces_par_tuile2"], ">=", 26, r["petites_pieces_par_tuile2"] >= 26),
                "O": (r["O_depassement_haut"], "<=", c["O"], r["O_depassement_haut"] <= c["O"]),
                "L1": (r["zone_lumineuse_part"], "dans", c["L1"], c["L1"][0] <= r["zone_lumineuse_part"] <= 0.15),
                "systemes": (r["systemes"], ">=", c["sys"], r["systemes"] >= c["sys"]),
                "animations": (r["animations"], ">=", c["anim"], r["animations"] >= c["anim"]),
            }
            res.append(r)
    # texte
    for r in res:
        lines.append("=" * 100)
        lines.append("%s (époque %d, emprise %dx%d, pose %s, %d échantillons) : %d plancher(s) en échec sur %d : %s"
                     % (r["nom"], r["epoque"], H.LEVELS[r["niveau"]]["side"], H.LEVELS[r["niveau"]]["side"], r["pose"],
                        r["samples"], len(r["echecs"]), len(r["verdict"]), ", ".join(r["echecs"]) or "aucun"))
        for sid, k, v, op, p, c, ok in r["verdict"]:
            lines.append("  %-4s %-42s %9.3f  %s %-6s (cible %s)  %s" % (sid, k, v, op, p, c, "ok" if ok else "ÉCHEC"))
        lines.append("  cibles §6.2 :")
        for k, (v, op, t, ok) in r["cibles"].items():
            lines.append("    %-11s %s %s %s : %s" % (k, ("%.3f" % v) if isinstance(v, float) else v, op, t,
                                                     "ok" if ok else "NON"))
        lines.append("  pièces totales %d ; masse %.2f t² ; O %.2f (O/côté %.2f) ; zone lumineuse %.3f t² ; foyers %d ; "
                     "halo de nuit %.2f t² (indicatif)" % (r["petites_pieces"], r["masse_tuiles2"], r["O_depassement_haut"],
                                                           r["O_depassement_haut"] / H.LEVELS[r["niveau"]]["side"],
                                                           r["zone_lumineuse_tuiles2"], r["foyers_lumineux"],
                                                           r["halo_nuit_tuiles2"]))
        lines.append("  systèmes (%d) : %s" % (r["systemes"], ", ".join(r["systemes_liste"])))
        lines.append("  animations prévues (%d, non rendues) : %s" % (r["animations"], ", ".join(r["animations_liste"])))
    lines.append("=" * 100)
    lines.append("Dominance §6.1 (substitut automatique du test du regard naïf) :")
    for pose in a.poses.split(","):
        rows = {r["niveau"]: r for r in res if r["pose"] == pose}
        for x, y in ((11, 21), (21, 29), (11, 29), (29, 30)):
            if x in rows and y in rows:
                ok, ind, ups, dens = dominance(rows[x], rows[y])
                lines.append("  pose %s : n%02d -> n%02d : %s ; %s ; en hausse : %s ; densité tenue : %s" % (
                    pose, x, y, "DOMINE" if ok else "ne domine pas",
                    ", ".join("%s %s -> %s" % (n, ("%.2f" % u) if isinstance(u, float) else u,
                                                ("%.2f" % w) if isinstance(w, float) else w) for n, u, w in ind),
                    ", ".join(ups), "oui" if dens else "non"))
    txt = "\n".join(lines)
    print(txt)
    with open(os.path.join(a.out, "mesures_hightech.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(txt + "\n")
    with open(os.path.join(a.out, "mesures_hightech.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1, ensure_ascii=False, default=float)
    # entrée de progression.py (charte) : mitrailleuse vanilla (niveau 1, époque 1, mesures_vanilla.json de la
    # charte, pose E) puis nos niveaux, au format des aperçus V3p1 (famille, niveau, époque)
    van = json.load(open(os.path.join(os.path.dirname(CHARTE), "mesures_vanilla.json"), encoding="utf-8"))
    g = dict([r for r in van if r["nom"] == "gun-turret"][0])
    for pose in a.poses.split(","):
        rows = [dict(g, famille="mitrailleuse", niveau=1, epoque=1, pose=pose)]
        for r in res:
            if r["pose"] == pose:
                q = {k: v for k, v in r.items() if k not in ("verdict", "cibles")}
                q["famille"] = "mitrailleuse"
                rows.append(q)
        with open(os.path.join(a.out, "progression_entree_%s.json" % pose), "w", encoding="utf-8",
                  newline="\n") as f:
            json.dump(rows, f, indent=1, ensure_ascii=False, default=float)


if __name__ == "__main__":
    main()
