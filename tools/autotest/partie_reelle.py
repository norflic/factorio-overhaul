# -*- coding: utf-8 -*-
"""Lot PARTIE-REELLE (12/11) : ce qui tourne VRAIMENT dans une partie, lu au journal (banc ou partie du DC).

Usage : py -3.9 -B tools/autotest/partie_reelle.py <factorio-current.log | archive> [--minutes 30,60,90,120] [--csv]
Par équipe et par minute (relevé [FO-CHAMP-ETAT] le plus proche à 5 min près) : foreuses du champ (en marche, figées sortie
pleine, sans courant), fours du champ (en marche, sans entrée, sans combustible), plaques dans les coffres de sortie du champ
(produites mais jamais rendues au QG), entités bâties par les projets finis ([FO-IA1D] « fini », cumul). Somme des équipes en bas.
Aucune projection : seulement des statuts d'entités lus en moteur et des objets comptés dans des coffres.
"""
import io, os, re, sys

ETAT = re.compile(r"\[FO-CHAMP-ETAT\] (\S+) min (\d+) \|.*?foreuses (\d+) \(marche (\d+), figees (\d+), sans courant (\d+)\) \| "
                  r"fours (\d+) \(marche (\d+), sans entree (\d+), sans combustible (\d+), sortie pleine (\d+)\) \| "
                  r"coffres de sortie (\d+) \(plaques (\d+)")
FINI = re.compile(r"\[FO-IA1D\] (\S+) : projet \d+ fini \([^,]*, (\d+) entites.*? a ([\d.]+) min")


def read(path):
    if os.path.isdir(path):
        path = os.path.join(path, "factorio-current.log")
    rows, built = {}, []
    with io.open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = ETAT.search(line)
            if m:
                k, mi = m.group(1), int(m.group(2))
                rows.setdefault(k, []).append((mi, [int(x) for x in m.groups()[2:]]))
                continue
            m = FINI.search(line)
            if m:
                built.append((m.group(1), int(m.group(2)), float(m.group(3))))
    return rows, built


def at(series, minute):
    best = None
    for mi, v in series:
        if abs(mi - minute) <= 5 and (best is None or abs(mi - minute) < abs(best[0] - minute)):
            best = (mi, v)
    return best


def main(argv):
    path = argv[1]
    minutes = [30, 60, 90, 120]
    csv = "--csv" in argv
    if "--minutes" in argv:
        minutes = [int(x) for x in argv[argv.index("--minutes") + 1].split(",")]
    rows, built = read(path)
    hdr = "equipe  min | foreuses marche figees sanscourant %marche | fours marche sansentree sanscomb | plaques_au_champ | entites_baties"
    print(hdr if not csv else "equipe,min,foreuses,marche,figees,sans_courant,pct_marche,fours,fours_marche,sans_entree,sans_comb,plaques_champ,entites_baties")
    for minute in minutes:
        tot = [0] * 11
        tb = 0
        for k in sorted(rows):
            b = at(rows[k], minute)
            nb = sum(n for t, n, m in built if t == k and m <= minute)
            tb += nb
            if not b:
                continue
            v = b[1]
            for i in range(11):
                tot[i] += v[i]
            pct = 100.0 * v[1] / v[0] if v[0] else 0.0
            if csv:
                print("%s,%d,%d,%d,%d,%d,%.1f,%d,%d,%d,%d,%d,%d" % (k, minute, v[0], v[1], v[2], v[3], pct, v[4], v[5], v[6], v[7], v[10], nb))
            else:
                print("%-7s %3d | %8d %6d %6d %11d %6.1f | %5d %6d %10d %8d | %16d | %d" % (k, minute, v[0], v[1], v[2], v[3], pct, v[4], v[5], v[6], v[7], v[10], nb))
        pct = 100.0 * tot[1] / tot[0] if tot[0] else 0.0
        if csv:
            print("TOTAL,%d,%d,%d,%d,%d,%.1f,%d,%d,%d,%d,%d,%d" % (minute, tot[0], tot[1], tot[2], tot[3], pct, tot[4], tot[5], tot[6], tot[7], tot[10], tb))
        else:
            print("%-7s %3d | %8d %6d %6d %11d %6.1f | %5d %6d %10d %8d | %16d | %d" % ("TOTAL", minute, tot[0], tot[1], tot[2], tot[3], pct, tot[4], tot[5], tot[6], tot[7], tot[10], tb))
            print("-" * len(hdr))


if __name__ == "__main__":
    main(sys.argv)
