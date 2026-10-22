"""Dominance époque par époque avec tools/da/progression.py de la charte, SANS le modifier (lot V3-E, époques 1 à 9).

    py -3.9 tools/render/pieces/levels/gun_e_bas/prog_e.py <outils charte> <mesures_vanilla.json> <mesures_e.json>
           <dossier de sortie>

progression.py ne garde que les niveaux impairs de familles fixes : on lui donne, par pose, la mitrailleuse vanilla
(niveau 1, époque 1) puis les niveaux 3, 5, ..., 17 (époques 2 à 9). Le niveau 2 (vanilla + sacs de sable) n'y
entre pas (niveau pair). Les familles absentes font échouer la fin du script après la mitrailleuse : on ne garde que
la sortie de la mitrailleuse (même méthode que la lignée, gun_s_industriel/prog.py).
"""
import copy
import json
import os
import subprocess
import sys


def main():
    outils, van, mes, out = sys.argv[1:5]
    V = json.load(open(van, encoding="utf-8"))
    R = json.load(open(mes, encoding="utf-8"))["niveaux"]
    os.makedirs(out, exist_ok=True)
    txt = []
    for pose in ("E", "N"):
        g = copy.deepcopy([r for r in V if r["nom"] == "gun-turret"][0])
        g.update({"famille": "mitrailleuse", "niveau": 1, "epoque": 1})
        rows = [g]
        for r in sorted((r for r in R if r["pose"] == pose and not r["pair"] and r["epoque"] >= 2),
                        key=lambda r: r["epoque"]):
            r = copy.deepcopy(r)
            r["famille"] = "mitrailleuse"
            rows.append(r)
        p = os.path.join(out, "progression-%s.json" % pose)
        json.dump(rows, open(p, "w", encoding="utf-8"), ensure_ascii=False, default=float)
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        res = subprocess.run([sys.executable, os.path.join(outils, "progression.py"), p], capture_output=True, env=env)
        keep = []
        for ln in res.stdout.decode("utf-8", "replace").splitlines():
            if ln.startswith("laser"):
                break
            keep.append(ln)
        txt.append("== pose %s : vanilla n1 puis n3 à n17 (progression.py)" % pose)
        txt.extend(keep)
    s = "\n".join(txt)
    open(os.path.join(out, "progression.txt"), "w", encoding="utf-8").write(s + "\n")
    print(s)


if __name__ == "__main__":
    main()
