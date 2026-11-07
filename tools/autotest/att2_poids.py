"""Lot DESIGN-ATTAQUES (7/11) : contrôle des POIDS du budget par tick des grandes attaques contre le coût MESURÉ (demande du lead).

    py -3.9 -B tools/autotest/att2_poids.py <archive d'un banc att2-perf> [--source <racine du mod>]

Lit les lignes [FO-ATT2-PROFIL] du journal (benchmark.log ; remote fo-att2 « profil », allumé par att2-perf) : par tick d'une grande
attaque, les comptes (coups, tuiles, feux, entités rangées, bandes de recherche, jetons payés) et trois chronomètres du moteur
(LuaProfiler : préparation, pas, coups). En tire le coût mesuré PAR TYPE d'opération, par moindres carrés :
  préparation ~ rang × rangées + bande × bandes
  coups       ~ coup × coups (boucle du plan : Stylet, Ixion, Tournesol)
  pas         ~ tuile × tuiles + feu × feux + fixe (effets du tick)
  poteau      ~ (pas − fixe) / poteaux (ticks du climax du Cairn)
et le compare aux poids de shared/robots/attaques2.lua (A.POIDS, en µs). Verdict par type : OK si le mesuré est entre la moitié et le
double du poids ; sinon RECALER (le poids proposé est le mesuré arrondi). Contrôle global : jetons payés contre temps mesuré, tick par tick.
Code 0 : tous les types mesurés dans [0,5 ; 2] ; 1 : au moins un à recaler ; 2 : aucune ligne de chronomètre.
"""
import gzip
import os
import re
import sys

PROFIL = re.compile(r"\[FO-ATT2-PROFIL\] tick (\d+) (\w+) rt (-?\d+) : coups (\d+), tuiles (\d+), feux (\d+), rangees (\d+), bandes (\d+), "
                    r"poteaux (\d+), jetons (\d+) ; preparation (.*?) ; pas (.*?) ; coups (.*)$", re.M)
DUREE = re.compile(r"([0-9]+(?:\.[0-9]+)?)\s*ms")
POIDS = re.compile(r"^\s*(coup|feu|eclat|poteau|rang|tuile|abattre|bande|vide)\s*=\s*([0-9.]+)", re.M)


def lire(d, nom):
    p = os.path.join(d, nom)
    if os.path.exists(p):
        return open(p, encoding="utf-8", errors="replace").read()
    if os.path.exists(p + ".gz"):
        return gzip.open(p + ".gz", "rt", encoding="utf-8", errors="replace").read()
    return ""


def ms(texte):
    """Durée d'un LuaProfiler écrit au journal (« Duration: 0.1234ms », ou « Elapsed: … ») en ms ; None si illisible."""
    m = DUREE.search(texte)
    return float(m.group(1)) if m else None


def lignes(journal):
    out = []
    for m in PROFIL.finditer(journal):
        tps = [ms(m.group(k)) for k in (11, 12, 13)]
        if None in tps:
            continue
        out.append({"tick": int(m.group(1)), "id": m.group(2), "rt": int(m.group(3)), "coups": int(m.group(4)), "tuiles": int(m.group(5)),
                    "feux": int(m.group(6)), "rangees": int(m.group(7)), "bandes": int(m.group(8)), "poteaux": int(m.group(9)), "jetons": int(m.group(10)),
                    "prep": tps[0] * 1000, "pas": tps[1] * 1000, "cps": tps[2] * 1000})  # en µs
    return out


def moindres_carres(X, y):
    """Solution de X b = y au sens des moindres carrés (équations normales, élimination de Gauss) ; None si singulier."""
    n = len(X[0])
    A = [[sum(r[i] * r[k] for r in X) for k in range(n)] for i in range(n)]
    B = [sum(r[i] * v for r, v in zip(X, y)) for i in range(n)]
    for c in range(n):
        p = max(range(c, n), key=lambda i: abs(A[i][c]))
        if abs(A[p][c]) < 1e-12:
            return None
        A[c], A[p], B[c], B[p] = A[p], A[c], B[p], B[c]
        for i in range(c + 1, n):
            f = A[i][c] / A[c][c]
            for k in range(c, n):
                A[i][k] -= f * A[c][k]
            B[i] -= f * B[c]
    b = [0.0] * n
    for i in range(n - 1, -1, -1):
        b[i] = (B[i] - sum(A[i][k] * b[k] for k in range(i + 1, n))) / A[i][i]
    return b


def estimer(L):
    """Coût mesuré par type (µs) : { type: (valeur, nombre d'observations) }."""
    est = {}
    P = [r for r in L if r["rangees"] + r["bandes"] > 0]
    if P:
        b = moindres_carres([[r["rangees"], r["bandes"]] for r in P], [r["prep"] for r in P])
        if b:
            est["rang"] = (b[0], sum(r["rangees"] for r in P))
            est["bande"] = (b[1], sum(r["bandes"] for r in P))
    C = [r for r in L if r["coups"] > 0 and r["id"] in ("stylet", "ixion", "tournesol") and r["cps"] > 0]
    if C:
        est["coup"] = (sum(r["cps"] for r in C) / sum(r["coups"] for r in C), sum(r["coups"] for r in C))
    S = [r for r in L if r["rt"] >= 0 and r["id"] in ("stylet", "ixion", "tournesol")]
    if len(S) >= 3 and any(r["tuiles"] for r in S) and any(r["feux"] for r in S):
        b = moindres_carres([[r["tuiles"], r["feux"], 1] for r in S], [r["pas"] for r in S])
        if b:
            est["tuile"] = (b[0], sum(r["tuiles"] for r in S))
            est["feu"] = (b[1], sum(r["feux"] for r in S))
            est["fixe"] = (b[2], len(S))
    # Cairn : les ticks du climax (poteaux grillés) ; leur pas, moins les effets fixes estimés ci-dessus, par poteau
    K = [r for r in L if r["id"] == "cairn" and r["poteaux"] > 0]
    if K:
        fixe = est.get("fixe", (0, 0))[0]
        est["poteau"] = (sum(r["pas"] - fixe for r in K) / sum(r["poteaux"] for r in K), sum(r["poteaux"] for r in K))
    return est


def poids_du_mod(source):
    p = os.path.join(source, "shared", "robots", "attaques2.lua")
    s = open(p, encoding="utf-8").read()
    a = s.index("A.POIDS = {")
    return {k: float(v) for k, v in POIDS.findall(s[a:s.index("}", a)])}


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    d = argv[0]
    source = argv[argv.index("--source") + 1] if "--source" in argv else os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    L = lignes(lire(d, "benchmark.log"))
    if not L:
        print("aucune ligne [FO-ATT2-PROFIL] (le banc a-t-il allumé le profil ?)")
        return 2
    W = poids_du_mod(source)
    est = estimer(L)
    print("%-8s %10s %12s %8s %8s  %s" % ("type", "poids µs", "mesuré µs", "ratio", "n", "verdict"))
    code = 0
    for k in ("rang", "bande", "coup", "tuile", "feu", "poteau"):
        if k not in est:
            print("%-8s %10s %12s %8s %8s  non mesuré" % (k, W.get(k, "?"), "-", "-", "-"))
            continue
        v, n = est[k]
        ratio = v / W[k] if W.get(k) else float("inf")
        ok = 0.5 <= ratio <= 2
        if not ok:
            code = 1
        print("%-8s %10.0f %12.1f %8.2f %8d  %s" % (k, W[k], v, ratio, n, "OK" if ok else "RECALER (proposé %d)" % max(1, round(v))))
    if "fixe" in est:
        print("%-8s %10s %12.1f %8s %8d  effets du tick (hors budget)" % ("fixe", "-", est["fixe"][0], "-", est["fixe"][1]))
    # contrôle global : µs mesurés par jeton payé, tick par tick (1,0 = poids justes)
    R = sorted((r["prep"] + r["pas"] + r["cps"]) / r["jetons"] for r in L if r["jetons"] >= 200)
    if R:
        print("µs mesurés par jeton (ticks à 200 jetons ou plus, %d) : médiane %.2f, 90 %% %.2f, max %.2f" % (len(R), R[len(R) // 2],
              R[min(len(R) - 1, int(len(R) * 0.9))], R[-1]))
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
