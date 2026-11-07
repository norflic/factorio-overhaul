"""Lot DESIGN-ATTAQUES (7/11) : contrôle HORS JEU de tools/autotest/att2_poids.py (poids du budget contre coût mesuré, demande du lead).

    PYTHONUTF8=1 py -3.9 -B tools/autotest/tests/test_att2_poids.py

Un journal SYNTHÉTIQUE de chronomètres ([FO-ATT2-PROFIL]) est fabriqué avec des coûts par type CONNUS (et un bruit déterministe de ± 5 %) ;
l'outil doit les retrouver à 10 % près, rendre le code 0 quand les poids du mod sont justes, et 1 (RECALER) quand un poids est faux d'un
facteur 3 ou plus (mutants). Aucun jeu lancé.
"""
import gzip
import os
import shutil
import sys
import tempfile

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(ICI))
import att2_poids  # noqa: E402

VRAI = {"rang": 7.0, "bande": 280.0, "coup": 450.0, "tuile": 35.0, "feu": 140.0, "poteau": 650.0, "fixe": 120.0}

ok = ko = 0


def check(cond, nom, det=""):
    global ok, ko
    if cond:
        ok += 1
    else:
        ko += 1
    print("%s %s%s" % ("OK   " if cond else "ECHEC", nom, (" : " + det) if det else ""))


def bruit(k):
    """± 5 % déterministe (suite de Weyl)."""
    return 1 + 0.1 * (((k * 0.6180339887) % 1.0) - 0.5)


def journal():
    out, k = [], 0
    def ligne(tick, gid, rt, coups=0, tuiles=0, feux=0, rangees=0, bandes=0, poteaux=0):
        nonlocal k
        k += 1
        prep = (VRAI["rang"] * rangees + VRAI["bande"] * bandes) * bruit(k)
        pas = 0.0
        if rt >= 0:
            pas = (VRAI["tuile"] * tuiles + VRAI["feu"] * feux + VRAI["fixe"] + VRAI["poteau"] * poteaux) * bruit(k + 7)
        cps = VRAI["coup"] * coups * bruit(k + 13) if gid in ("stylet", "ixion", "tournesol") else 0.0
        jetons = int(8 * rangees + 300 * bandes + 400 * coups + 40 * tuiles + 150 * feux + 700 * poteaux)
        out.append("  1.0 Script @x: [FO-ATT2-PROFIL] tick %d %s rt %d : coups %d, tuiles %d, feux %d, rangees %d, bandes %d, poteaux %d, "
                   "jetons %d ; preparation Duration: %.6fms ; pas Duration: %.6fms ; coups Duration: %.6fms"
                   % (tick, gid, rt, coups, tuiles, feux, rangees, bandes, poteaux, jetons, prep / 1000, pas / 1000, cps / 1000))
    t = 1000
    for gid in ("cairn", "stylet", "ixion", "tournesol"):
        for i in range(60):  # charge : recherche et rangement
            ligne(t, gid, i - 60, rangees=(i * 37) % 200 + 20, bandes=(i % 3))
            t += 1
        for i in range(200):
            if gid == "cairn":
                ligne(t, gid, i, poteaux=(2 if 40 <= i < 70 else 0))
            elif gid == "stylet":
                ligne(t, gid, i, coups=(i * 7) % 6, feux=(i * 5) % 4)
            elif gid == "ixion":
                ligne(t, gid, i, coups=(i * 3) % 6, tuiles=(i * 11) % 33, feux=(1 if i % 9 == 0 else 0))
            else:
                ligne(t, gid, i, coups=(i * 5) % 6, tuiles=(i * 13) % 33)
            t += 1
    return "\n".join(out) + "\n"


def mod(poids):
    d = tempfile.mkdtemp(prefix="att2poids-")
    os.makedirs(os.path.join(d, "shared", "robots"))
    with open(os.path.join(d, "shared", "robots", "attaques2.lua"), "w", encoding="utf-8") as f:
        f.write("A.POIDS = {\n" + "".join("  %s = %s,\n" % (k, v) for k, v in poids.items()) + "}\n")
    return d


def main():
    arch = tempfile.mkdtemp(prefix="att2poids-banc-")
    with gzip.open(os.path.join(arch, "benchmark.log.gz"), "wt", encoding="utf-8") as f:
        f.write(journal())
    L = att2_poids.lignes(att2_poids.lire(arch, "benchmark.log"))
    check(len(L) == 4 * 260, "lecture : toutes les lignes de chronomètres", str(len(L)))
    est = att2_poids.estimer(L)
    for k in ("rang", "bande", "coup", "tuile", "feu", "poteau"):
        v = est.get(k, (None, 0))[0]
        check(v is not None and abs(v - VRAI[k]) <= 0.1 * VRAI[k], "estimation de « %s » à 10 %% près" % k,
              "%s pour %.0f" % ("%.1f" % v if v is not None else "rien", VRAI[k]))
    justes = {"coup": 400, "feu": 150, "eclat": 50, "poteau": 700, "rang": 8, "tuile": 40, "abattre": 200, "bande": 300, "vide": 20}
    d = mod(justes)
    try:
        check(att2_poids.main([arch, "--source", d]) == 0, "poids justes (à moins d'un facteur 2) : code 0")
    finally:
        shutil.rmtree(d)
    for k, faux in (("coup", 80), ("bande", 2500), ("tuile", 8), ("poteau", 120)):
        p = dict(justes)
        p[k] = faux
        d = mod(p)
        try:
            check(att2_poids.main([arch, "--source", d]) == 1, "mutant : poids « %s » = %s (faux) : code 1, RECALER" % (k, faux))
        finally:
            shutil.rmtree(d)
    vide = tempfile.mkdtemp(prefix="att2poids-vide-")
    try:
        check(att2_poids.main([vide]) == 2, "journal sans chronomètres : code 2")
    finally:
        shutil.rmtree(vide)
    shutil.rmtree(arch)
    print("[ATT2-POIDS] BILAN : %d OK, %d ECHEC(S)" % (ok, ko))
    return 0 if ko == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
