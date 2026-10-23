"""Compare deux dossiers de feuilles de la mitrailleuse (lot A3-jeu, 24/10). Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/compare_feuilles.py AVANT APRES [--ages 2,3]

Dit, fichier par fichier, ce qui est identique (sha256) ou différent ; compare les DONNÉES de sprites.lua (le
`return {...}`, sans l'en-tête de commentaires) et celles de sprites.json (sans les sous-tables « outils » ajoutées par
le lot A3-jeu) ; avec --ages, ne regarde que les fichiers et les données de ces âges (plus l'âge 1 et les tables
communes). Sert à prouver le REPLI : à 4 directions, feuilles.py rend les mêmes octets qu'au lot A2.
Code 0 si tout ce qui est regardé est identique.
"""
import argparse
import hashlib
import json
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def corps_lua(p):
    t = open(p, encoding="utf-8").read()
    return t[t.index("return "):]


def sans_outils(j):
    j = json.loads(json.dumps(j))
    for A in j["ages"].values():
        A.pop("outils", None)
    return j


def age_du_fichier(f):
    m = re.search(r"-e(\d\d)-", f)
    return int(m.group(1)) if m else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("avant")
    ap.add_argument("apres")
    ap.add_argument("--ages", default="")
    a = ap.parse_args()
    ages = set(int(x) for x in a.ages.split(",") if x) or None
    diff = []
    same = 0
    pa = sorted(f for f in os.listdir(a.avant) if f.endswith(".png"))
    pb = sorted(f for f in os.listdir(a.apres) if f.endswith(".png"))
    for f in sorted(set(pa) | set(pb)):
        e = age_du_fichier(f)
        if ages is not None and e is not None and e not in ages:
            continue
        if f not in pa or f not in pb:
            diff.append("PNG présent d'un seul côté : %s" % f)
        elif sha(os.path.join(a.avant, f)) != sha(os.path.join(a.apres, f)):
            diff.append("PNG différent : %s" % f)
        else:
            same += 1
    la, lb = corps_lua(os.path.join(a.avant, "sprites.lua")), corps_lua(os.path.join(a.apres, "sprites.lua"))
    ja = sans_outils(json.load(open(os.path.join(a.avant, "sprites.json"), encoding="utf-8")))
    jb = sans_outils(json.load(open(os.path.join(a.apres, "sprites.json"), encoding="utf-8")))
    if ages is None:
        if la != lb:
            diff.append("sprites.lua : données différentes")
        if ja != jb:
            diff.append("sprites.json : données différentes (hors « outils »)")
    else:
        for k in sorted(set(ja["ages"]) | set(jb["ages"]), key=int):
            if int(k) in ages or int(k) == 1:
                if ja["ages"].get(k) != jb["ages"].get(k):
                    diff.append("sprites.json : âge %s différent" % k)
        for k in ("directions", "eclat", "vanille"):
            if ja.get(k) != jb.get(k):
                diff.append("sprites.json : table %s différente" % k)
    for d in diff:
        print("[FO-COMPARE] DIFFERENT " + d)
    print("[FO-COMPARE] %d PNG identiques ; %d différence(s) ; sprites.lua (données) %s ; sprites.json (hors outils) %s"
          % (same, len(diff), "identique" if la == lb else "différent", "identique" if ja == jb else "différent"))
    return 0 if not diff else 1


if __name__ == "__main__":
    sys.exit(main())
