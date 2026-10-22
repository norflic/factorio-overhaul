"""OUTIL COMMUN : progression de puissance époque par époque, VANILLA EN TÊTE (charte §5, catalogue §A.5). GELÉ.

    py -3.9 tools/render/pieces/levels/gun_e/dominance.py --mesures mesures.json [--prog prog.json]

Lit le JSON de mesures.py. Suite comparée, pour chaque pose E et N : mitrailleuse VANILLA (niveau 1,
docs/da/mesures_vanilla.json, « gun-turret ») puis les niveaux impairs des époques 2 à 15. Règle de
tools/da/progression.py : une époque DOMINE la précédente si emprise, masse, petites pièces et foyers sont tous >=, et
au moins 2 strictement > ; la densité de détail (D3) ne baisse pas de plus de 5 %. Contrôle impair -> pair de chaque
époque : masse, pièces et foyers tous >=, au moins un >.
Écrit aussi --prog (format d'entrée de tools/da/progression.py, famille « mitrailleuse », vanilla en époque 1) et
lance tools/da/progression.py dessus (sortie recopiée). Code de sortie 1 si une paire ne domine pas.
"""
import argparse
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import epoques as E  # noqa: E402

MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
VANILLA = os.path.join(MOD, "docs", "da", "mesures_vanilla.json")
PROGRESSION = os.path.join(MOD, "tools", "da", "progression.py")


def vanilla_n1():
    V = json.load(open(VANILLA, encoding="utf-8"))
    g = dict([v for v in V if v["nom"] == "gun-turret"][0])
    g.update({"epoque": 1, "niveau": 1, "pose": "*", "pair": False, "famille": "mitrailleuse"})
    return g


def emprise(r):
    w, h = [float(x) for x in r["cote_emprise"].split("x")]
    return w * h


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mesures", required=True)
    ap.add_argument("--prog", default="")
    a = ap.parse_args()
    data = json.load(open(a.mesures, encoding="utf-8"))
    rows = [r for r in data["charte"] if r.get("temoin") is None]
    van = vanilla_n1()
    nko = 0
    for pose in ("E", "N"):
        seq = [van] + sorted([r for r in rows if r["pose"] == pose and not r["pair"] and r["epoque"] >= 2],
                             key=lambda r: r["epoque"])
        nd = 0
        for x, y in zip(seq, seq[1:]):
            q = [(emprise(y), emprise(x)), (y["masse_tuiles2"], x["masse_tuiles2"]),
                 (y["petites_pieces"], x["petites_pieces"]), (y["foyers_lumineux"], x["foyers_lumineux"])]
            ge = all(u >= v for u, v in q)
            gt = sum(1 for u, v in q if u > v)
            ok = ge and gt >= 2
            dd = y["petites_pieces_par_tuile2"] / x["petites_pieces_par_tuile2"] - 1
            nd += ok
            nko += not ok
            print("  %s %-7s -> ép.%2d : masse %6.2f -> %6.2f, pièces %5d -> %5d, foyers %3d -> %3d, D3 %5.1f -> %5.1f "
                  "(%+5.1f %%) : %s%s" % (
                      pose, "vanilla" if x is van else "ép.%2d" % x["epoque"], y["epoque"], x["masse_tuiles2"],
                      y["masse_tuiles2"], x["petites_pieces"], y["petites_pieces"], x["foyers_lumineux"],
                      y["foyers_lumineux"], x["petites_pieces_par_tuile2"], y["petites_pieces_par_tuile2"], 100 * dd,
                      "domine" if ok else "NE DOMINE PAS", "" if dd >= -0.05 else " ; DENSITÉ -%.0f %%" % (-100 * dd)))
        print("  %s : %d/%d paires dominent (vanilla en tête)" % (pose, nd, len(seq) - 1))
    for pose in ("E", "N"):
        n = tot = 0
        for e in range(2, 16):
            x = [r for r in rows if r["epoque"] == e and r["pose"] == pose and not r["pair"]]
            y = [r for r in rows if r["epoque"] == e and r["pose"] == pose and r["pair"]]
            if not x or not y:
                continue
            x, y = x[0], y[0]
            q = [(y["masse_tuiles2"], x["masse_tuiles2"]), (y["petites_pieces"], x["petites_pieces"]),
                 (y["foyers_lumineux"], x["foyers_lumineux"])]
            ok = all(u >= v for u, v in q) and sum(1 for u, v in q if u > v) >= 1
            n += ok
            tot += 1
            nko += not ok
            if not ok:
                print("  %s impair -> pair ép.%d NE DOMINE PAS : masse %.2f -> %.2f, pièces %d -> %d, foyers %d -> %d" % (
                    pose, e, x["masse_tuiles2"], y["masse_tuiles2"], x["petites_pieces"], y["petites_pieces"],
                    x["foyers_lumineux"], y["foyers_lumineux"]))
        print("  %s impair -> pair : %d/%d" % (pose, n, tot))
    if a.prog:
        out = [dict(van, famille="mitrailleuse")]
        for r in rows:
            if r["pose"] == "E" and r["epoque"] >= 2:
                out.append(dict(r, famille="mitrailleuse"))
        json.dump(out, open(a.prog, "w", encoding="utf-8"), indent=1, ensure_ascii=False, default=float)
        print("--- tools/da/progression.py (pose E, vanilla en époque 1) ---")
        res = subprocess.run([sys.executable, PROGRESSION, a.prog], capture_output=True, text=True, encoding="utf-8")
        print("\n".join(l for l in res.stdout.splitlines() if l.startswith("mitrailleuse") or l.startswith("   ")
                        or l.startswith("     ")))
    print("[FO-DOMINANCE] %d défaut(s)" % nko)
    sys.exit(1 if nko else 0)


if __name__ == "__main__":
    main()
