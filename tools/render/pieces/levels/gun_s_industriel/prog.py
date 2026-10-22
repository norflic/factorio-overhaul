"""Dominance 1 -> 11 -> 21 -> 29 -> 30 avec outils/progression.py de la charte, SANS le modifier.

    python tools/render/pieces/levels/gun_s_industriel/prog.py <outils charte> <mesures_vanilla.json> <mesures.json>
           <dossier de sortie>

progression.py lit des familles fixes (« mitrailleuse », « laser », « assembleur », « centre ») et ne garde que les
niveaux impairs. On lui donne donc deux fichiers : (a) mitrailleuse vanilla (niveau 1, époque 1) puis les niveaux
11, 21, 29 ; (b) niveau 29 puis niveau 30, présenté comme « niveau 31, époque 16 » pour passer son filtre des
niveaux impairs (les chiffres sont ceux du niveau 30). Les familles absentes font échouer la fin du script après
l'impression de la mitrailleuse : on ne garde que la sortie de la mitrailleuse.
"""
import copy
import json
import os
import subprocess
import sys


def main():
    outils, van, mes, out = sys.argv[1:5]
    V = json.load(open(van, encoding="utf-8"))
    R = {r["niveau"]: r for r in json.load(open(mes, encoding="utf-8"))}
    g = copy.deepcopy([r for r in V if r["nom"] == "gun-turret"][0])
    g.update({"famille": "mitrailleuse", "niveau": 1, "epoque": 1})
    rows_a = [g]
    for n in (11, 21, 29):
        r = copy.deepcopy(R[n])
        r["famille"] = "mitrailleuse"
        rows_a.append(r)
    r29 = copy.deepcopy(R[29])
    r29["famille"] = "mitrailleuse"
    r30 = copy.deepcopy(R[30])
    r30.update({"famille": "mitrailleuse", "niveau": 31, "epoque": 16})
    os.makedirs(out, exist_ok=True)
    txt = []
    for tag, rows in (("1-11-21-29", rows_a), ("29-30", [r29, r30])):
        p = os.path.join(out, "progression-%s.json" % tag)
        json.dump(rows, open(p, "w", encoding="utf-8"), ensure_ascii=False)
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        res = subprocess.run([sys.executable, os.path.join(outils, "progression.py"), p], capture_output=True,
                             env=env)
        lines = res.stdout.decode("utf-8", "replace").splitlines()
        keep = []
        for ln in lines:
            if ln.startswith("laser"):
                break
            keep.append(ln)
        txt.append("== %s (progression.py)" % tag)
        txt.extend(keep)
    s = "\n".join(txt)
    open(os.path.join(out, "progression.txt"), "w", encoding="utf-8").write(s + "\n")
    print(s)


if __name__ == "__main__":
    main()
