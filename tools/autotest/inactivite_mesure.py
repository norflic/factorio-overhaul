"""Lot ZERO-IDLE-3 : lit [FO-INACTIF-CAUSE] et la minute de fin de la centrale au journal d'un banc (lecture seule).

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/inactivite_mesure.py <benchmark.log[.gz]> [<autre journal> ...] [--de 5 --a 40]

Pour chaque equipe et chaque tranche de 10 minutes : PNJ-secondes perdues / PNJ-secondes totales, deux fois :
  - « sans tache » : toute pensee de PNJ sans tache (jetons, sans-tache:*, sans-programme:*, refus-porte:*) ;
  - « vraiment oisif » : sans celles ou le PNJ fabrique en arriere-plan (suffixe +fabrique : il travaille).
Puis la minute de fin de la centrale ([FO-IA3E] <equipe> : centrale FINIE a X min). Une mesure de FONCTION (tache attribuee ou non),
jamais de presence. Une minute sans ligne [FO-INACTIF-CAUSE] n'a aucune pensee de PNJ libre : 0 perdu, fenetre complete au denominateur.
"""
import gzip
import re
import sys
from collections import defaultdict

RX = re.compile(r"\[FO-INACTIF-CAUSE\] (\w+) minute (\d+) \| PNJ (\d+) \| perdu (\d+) PNJ-s sur (\d+) \(([\d.]+) %\) \| (.*)$")
RX_PART = re.compile(r"(.*) (\d+) s \((\d+)\)\s*$")
RX_CENTRALE = re.compile(r"\[FO-IA3E\] (\w+) : centrale FINIE a ([\d.]+) min")


def lire(path):
    op = gzip.open if path.endswith(".gz") else open
    with op(path, "rt", encoding="utf-8", errors="replace") as f:
        for ligne in f:
            yield ligne


def mesurer(path, de, a):
    perdu = defaultdict(float)   # (equipe, tranche) -> PNJ-s
    oisif = defaultdict(float)
    total = defaultdict(float)
    minutes_vues = defaultdict(set)
    pnj = {}
    centrale = {}
    for ligne in lire(path):
        m = RX_CENTRALE.search(ligne)
        if m and m.group(1) not in centrale:
            centrale[m.group(1)] = float(m.group(2))
        m = RX.search(ligne)
        if not m:
            continue
        equipe, minute, n, _pl, _pd, _pct, reste = m.groups()
        minute = int(minute)
        if not de <= minute <= a:
            continue
        n = int(n)
        pnj[equipe] = n
        tranche = (minute // 10) * 10
        minutes_vues[(equipe, tranche)].add(minute)
        # le texte ne garde que les 8 premieres causes : la borne du perdu est la somme des parties lues, le total ecrit sert de reference
        perdu[(equipe, tranche)] += float(_pl)
        for part in reste.split(" ; "):
            mm = RX_PART.match(part.strip())
            if mm and not mm.group(1).endswith("+fabrique"):
                oisif[(equipe, tranche)] += float(mm.group(2))
    equipes = sorted({k[0] for k in perdu})
    return equipes, perdu, oisif, minutes_vues, pnj, centrale


def main(argv):
    de, a = 5, 40
    fichiers = []
    i = 0
    while i < len(argv):
        if argv[i] == "--de":
            de = int(argv[i + 1]); i += 2
        elif argv[i] == "--a":
            a = int(argv[i + 1]); i += 2
        else:
            fichiers.append(argv[i]); i += 1
    if not fichiers:
        print(__doc__)
        return 2
    for path in fichiers:
        equipes, perdu, oisif, vues, pnj, centrale = mesurer(path, de, a)
        print("== %s (minutes %d a %d)" % (path, de, a))
        tranches = sorted({k[1] for k in perdu})
        for e in equipes:
            n = pnj.get(e, 0)
            ligne_p, ligne_o = [], []
            tp = to = tt = 0.0
            for t in tranches:
                lo, hi = max(de, t), min(a, t + 9)
                fen = (hi - lo + 1) * 60.0 * max(1, n)  # PNJ-s de la tranche, toutes les minutes comptees
                p = perdu.get((e, t), 0.0)
                o = oisif.get((e, t), 0.0)
                tp += p; to += o; tt += fen
                ligne_p.append("%2d-%2d min %5.1f %%" % (lo, hi, 100 * p / fen))
                ligne_o.append("%2d-%2d min %5.1f %%" % (lo, hi, 100 * o / fen))
            print("  %-8s PNJ %2d | sans tache %5.1f %% [%s]" % (e, n, 100 * tp / max(1, tt), " ; ".join(ligne_p)))
            print("  %-8s        | vraiment oisif %5.1f %% [%s]" % ("", 100 * to / max(1, tt), " ; ".join(ligne_o)))
        print("  centrale FINIE (min) : %s" % (", ".join("%s %.1f" % (e, centrale[e]) for e in sorted(centrale)) or "aucune"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
