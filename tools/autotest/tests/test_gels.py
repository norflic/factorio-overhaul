# Lot OUTILLAGE : règles pures de tools/autotest/gels.py (pics, rythme, alignement), avec mutants. Hors jeu, moins de 5 s.
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/tests/test_gels.py   -> BILAN : n OK
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
AUTOTEST = os.path.dirname(ICI)
sys.path.insert(0, AUTOTEST)
import gels  # noqa: E402

ok = ko = 0


def verifie(cond, quoi):
    global ok, ko
    if cond:
        ok += 1
        print("OK   " + quoi)
    else:
        ko += 1
        print("ECHEC " + quoi)


def jeu(regles):
    # Série de 3000 ticks à 0,05 ms, avec une pensée de 9 ms aux ticks 0 et 1 de chaque période de 300, un pic isolé à 1234.
    ticks = list(range(3000))
    ms = [0.05] * 3000
    for t in ticks:
        if t % 300 in (0, 1):
            ms[t] = 9.0
    ms[1234] = 5.0
    p = regles.pics(ticks, ms)
    return ticks, ms, p


t, ms, p = jeu(gels)
verifie(len(p) == 21 and (1234, 5.0) in p and (0, 9.0) in p and (301, 9.0) in p, "pics : 20 pensées + 1 pic isolé, rien d'autre (%d)" % len(p))
verifie(gels.pics([0, 1, 2], [0.05, 2.0, 0.05]) == [], "pics : un tick de 2 ms n'est pas un pic (seuil 3 ms)")
verifie(gels.pics([0, 1], [10.0, 40.0], facteur=4, min_ms=3) == [(1, 40.0)] or gels.pics([0, 1], [10.0, 40.0]) == [],
        "pics : tout est relatif à la médiane")
e, n, part = gels.rythme([a for a, _ in p if a != 1234])
verifie(e == 1 and n == 10, "rythme : l'écart le plus fréquent est 1 tick (les paires 0, 1) : %d x%d" % (e, n))
al = gels.alignement([a for a, _ in p if a != 1234])
verifie(len(al) == 1 and al[0][0] == 300 and al[0][1] == 0 and al[0][2] == 1.0, "alignement : la vraie période 300 (fenêtre de 4 ticks), pas ses diviseurs : %s" % (al[:3],))
verifie(gels.alignement([a for a, _ in p])[0][:2] == (300, 0), "alignement : le pic isolé ne cache pas la période (part >= 60 %)")
verifie(gels.alignement([1, 2, 3]) == [], "alignement : moins de 6 pics, rien")
verifie(gels.rythme([]) == (0, 0, 0.0), "rythme : aucun pic")
verifie(gels.pics(list(range(5)), [2.0, 2.0, 2.0, 5.0, 2.0]) == [], "pics : 5 ms sur une médiane de 2 ms (4 x 2 = 8) n'est pas un pic")
irreg, _v = [], 12345
for _ in range(60):  # suite congruentielle fixe : 60 ticks sans rythme
    _v = (_v * 1103515245 + 12345) % 2147483648
    irreg.append(_v % 200000)
irreg.sort()
verifie(gels.alignement(irreg) == [], "alignement : des pics irréguliers ne donnent aucune période")

# Mutants
src = open(os.path.join(AUTOTEST, "gels.py"), encoding="utf-8").read()


def mut(nom, a, b, controle):
    assert src.count(a) == 1, nom
    ns = {"__name__": "gels_mutant", "__file__": os.path.join(AUTOTEST, "gels.py")}
    exec(compile(src.replace(a, b), "mutant-" + nom, "exec"), ns)

    class M:
        pics = staticmethod(ns["pics"])
        rythme = staticmethod(ns["rythme"])
        alignement = staticmethod(ns["alignement"])
    verifie(not controle(M), "mutant %s refusé" % nom)


def controle(M):
    tt, mm, pp = jeu(M)
    return (len(pp) == 21 and M.rythme([a for a, _ in pp if a != 1234])[:2] == (1, 10)
            and M.alignement([a for a, _ in pp]) != [] and M.alignement(irreg) == [] and M.pics([0, 1, 2], [0.05, 2.0, 0.05]) == []
            and M.pics(list(range(5)), [2.0, 2.0, 2.0, 5.0, 2.0]) == [] and M.alignement([1, 2, 3, 4, 5]) == [])


verifie(controle(gels), "contrôle témoin vrai sur le vrai module")
mut("seuil-absent", "seuil = max(facteur * med, min_ms)", "seuil = facteur * med", controle)
mut("facteur-1", "seuil = max(facteur * med, min_ms)", "seuil = max(med, min_ms)", controle)
mut("part-0", "if part >= 0.6:", "if part >= 0.0:", controle)
mut("ecart-signe", "ecarts = [b - a for a, b in zip(ticks_pics, ticks_pics[1:]) if 0 < b - a <= max_ecart]",
    "ecarts = [b - a for a, b in zip(ticks_pics, ticks_pics[1:])]", lambda M: controle(M) and M.rythme([0, 5000, 5001])[:2] == (0, 0))
mut("moins-de-6", "if n < 6:", "if n < 1:", controle)

print("BILAN : %d OK, %d ECHEC(S)" % (ok, ko))
sys.exit(1 if ko else 0)
