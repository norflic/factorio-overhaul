"""Tests hors Blender du kit du MUR (lot F6, 29/10) : contrat des 14 fichiers d'âge (lus par ast, sans les exécuter : ils
importent Blender), table des formes de raccord, plan de la planche, règles de recouvrement poteau / bras.

    PYTHONUTF8=1 py -3.9 tools/render/pieces/levels/mur_e/tests/test_mur.py [--sprites DIR]
--sprites DIR : contrôle en plus les spec.json rendus (14 âges × 8 formes : fichiers, tailles, ombre présente).
"""
import ast
import json
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
MUR = os.path.dirname(ICI)
sys.path.insert(0, MUR)
sys.path.insert(0, os.path.join(os.path.dirname(MUR), "commun"))
import importlib.util as _iu  # noqa: E402
_sp = _iu.spec_from_file_location("mur_epoques", os.path.join(MUR, "epoques.py"))
E = _iu.module_from_spec(_sp)
_sp.loader.exec_module(E)

OK = 0
KO = 0


def ctl(cond, msg):
    global OK, KO
    if cond:
        OK += 1
    else:
        KO += 1
        print("ECHEC : " + msg)


def lire(e):
    src = open(os.path.join(MUR, "ep%02d.py" % e), encoding="utf-8").read()
    tree = ast.parse(src)
    fonctions = {n.name: n for n in tree.body if isinstance(n, ast.FunctionDef)}
    consts = {}
    for n in tree.body:
        if isinstance(n, ast.Assign):
            try:
                v = ast.literal_eval(n.value)
            except Exception:
                v = None
            for t in n.targets:
                if isinstance(t, ast.Tuple) and isinstance(v, tuple):
                    for tt, vv in zip(t.elts, v):
                        consts[tt.id] = vv
                elif isinstance(t, ast.Name):
                    consts[t.id] = v
    return src, fonctions, consts


def main():
    sprites = ""
    if "--sprites" in sys.argv:
        sprites = sys.argv[sys.argv.index("--sprites") + 1]
    # formes de raccord : 8, bras E, O, S seulement (le nord est dessiné par le voisin)
    ctl(len(E.TYPES) == 8 and sorted(E.TYPES) == sorted(E.ORDRE_TYPES), "8 formes")
    ctl(all(set(v) <= {"E", "O", "S"} for v in E.TYPES.values()), "aucun bras nord")
    ctl(len(set(E.TYPES.values())) == 8, "chaque forme a un jeu de bras distinct")
    ctl(set(E.BRAS) == {"E", "O", "S"}, "bras E, O, S")
    ctl(abs(E.BRAS["S"][1] - 2 ** 0.5) < 1e-9, "le bras sud va au centre de la case voisine (1,414)")
    ctl(E.AGES == tuple(range(2, 16)), "âges 2 à 15 (l'âge 1 est le mur vanilla)")
    ctl(sorted(E.TRIPLETS) == list(E.AGES), "un triplet par âge")
    triplets = []
    for e in E.AGES:
        src, fn, c = lire(e)
        ctl("poteau" in fn and "bras" in fn and "matieres" in fn, "âge %d : poteau, bras, matieres" % e)
        ctl(c.get("EPOQUE") == e, "âge %d : EPOQUE" % e)
        ctl(tuple(c.get("TRIPLET") or ()) == E.TRIPLETS[e], "âge %d : TRIPLET = epoques.TRIPLETS" % e)
        triplets.append(E.TRIPLETS[e])
        hp, hb, lp, lb = (c.get(k) for k in ("HAUT_POTEAU", "HAUT_BRAS", "LARG_POTEAU", "LARG_BRAS"))
        ctl(None not in (hp, hb, lp, lb), "âge %d : hauteurs et largeurs déclarées" % e)
        if None not in (hp, hb, lp, lb):
            ctl(hp >= hb + 0.1, "âge %d : poteau plus haut que le bras (%.2f / %.2f)" % (e, hp, hb))
            ctl(lp >= lb + 0.02, "âge %d : poteau plus large que le bras, il recouvre le bout du bras sud" % e)
        ctl("ages.matieres(%d, metal, M)" % e in src, "âge %d : matières de l'âge (ages.matieres)" % e)
        ctl("ages.FOYER[%d]" % e in src, "âge %d : FOYER" % e)
    ctl(len(set(triplets)) == 14, "triplets tous différents")
    # vingt-quatre mots de matière : aucun âge ne réutilise la matière d'un autre âge (clés propres)
    import ages
    for e in E.AGES:
        src, _, _ = lire(e)
        autres = set()
        for o in E.AGES:
            if o != e:
                autres |= set(ages.CLES_MATIERES.get(o, ())) - set(ages.CLES_MATIERES.get(e, ()))
        # clés « M["x"] » utilisées par l'âge
        import re
        for k in set(re.findall(r'M\["([a-z_0-9]+)"\]', src)):
            ctl(k not in autres or k in ("jacket", "ring", "trim", "pipe", "cable_a", "cable_b", "spec"),
                "âge %d : la matière %s est celle d'un autre âge, hors de la palette de l'âge" % (e, k))
    # plan de la planche
    import planche
    ctl(set(planche.formes_du_plan(planche.PLAN)) == set(E.ORDRE_TYPES), "le plan de la planche contient les 8 formes")
    if sprites:
        for e in E.AGES:
            for t in E.ORDRE_TYPES:
                p = os.path.join(sprites, "e%02d-%s" % (e, t), "spec.json")
                ctl(os.path.exists(p), "sprite manquant e%02d-%s" % (e, t))
                if os.path.exists(p):
                    s = json.load(open(p, encoding="utf-8"))
                    ctl("main" in s["layers"] and "shadow" in s["layers"], "e%02d-%s : couches main et shadow" % (e, t))
                    ctl(s["checks"]["holes_ok"], "e%02d-%s : trou enfermé" % (e, t))
    print("[F6-MUR] %d OK, %d ECHEC(S)" % (OK, KO))
    sys.exit(1 if KO else 0)


if __name__ == "__main__":
    main()
