# -*- coding: utf-8 -*-
"""Lot MODULES-ORDRE : lecture des archives de banc (benchmark.log[.gz]) pour la partie du guide a 120 min.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/modules_ordre_lecture.py <archive> [<archive> ...] [--equipes scarlet,azure,player] [--minutes 60,90,120]

Par equipe et par minute releve (lignes brutes du journal) :
  - circuits/min et engrenages/min FAITS PAR LES MACHINES : [FO-FONCTION] prod ... circuits_min=, engrenages_min= (statistiques de production de
    la force ; la fabrication a la main des PNJ, simulee par script, n'y figure pas) ;
  - circuits/min et engrenages/min A LA MAIN : [FO-IA3E] <equipe> minute M ... « charge PNJ/debit { objet:charge/debit } » (debit = objets par minute
    faits a la main sur la fenetre de 10 min, charge = PNJ occupes) ;
  - part faite en machine = machine / (machine + main) ;
  - packs/min : [FO-FONCTION] tech ... packs_fab (packs fabriques sur la fenetre de 10 min, divise par 10) ;
  - relais : nombre de lignes [FO-PORTES] relais (ordres qui ont passe la porte du transport fermee) et de retenues « transport sature ».
Aucune decision n'en depend.
"""
import gzip
import os
import re
import sys


def lines_of(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            op = gzip.open if name.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


def num(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def read(arch, teams, minutes):
    prod, tech, hand = {}, {}, {}
    relais = {}
    sature = {}
    for ln in lines_of(arch):
        m = re.search(r"\[FO-FONCTION\] prod minute (\d+) \| (\S+) \|.* engrenages_min=([\d.]+) circuits_min=([\d.]+) packs_fab=(\d+)", ln)
        if m:
            prod[(int(m.group(1)), m.group(2))] = (num(m.group(3)), num(m.group(4)))
            continue
        m = re.search(r"\[FO-FONCTION\] tech minute (\d+) \| (\S+) \|.* packs_fab=(\d+)", ln)
        if m:
            tech[(int(m.group(1)), m.group(2))] = int(m.group(3))
            continue
        m = re.search(r"\[FO-IA3E\] (\S+) minute (\d+) \| fenetre \d+ min \| charge PNJ/debit \{(.*?)\} \|", ln)
        if m:
            d = {}
            for it, ch, db in re.findall(r"([a-z0-9-]+):([\d.]+)/(\d+)", m.group(3)):
                d[it] = (num(ch), num(db))
            hand[(int(m.group(2)), m.group(1))] = d
            continue
        m = re.search(r"\[FO-PORTES\] (\S+) minute \d+ : relais :", ln)
        if m:
            relais[m.group(1)] = relais.get(m.group(1), 0) + 1
            continue
        m = re.search(r"executant refuse \[(.*?)\]( \||$)", ln)
        mm = re.search(r"\[FO-CAPI\] (\S+) minute", ln)
        if m and mm:
            sature[mm.group(1)] = sature.get(mm.group(1), 0) + m.group(1).count("transport sature")
    print("archive : " + arch)
    print("equipe  | min | circuits/min machine | circuits/min main (PNJ) | part machine | engrenages machine | engrenages main (PNJ) | part machine | packs/min | ")
    for t in teams:
        for mn in minutes:
            eg, ci = prod.get((mn, t), (None, None))
            h = hand.get((mn, t), {})
            hc, hg = h.get("electronic-circuit", (0.0, 0.0)), h.get("iron-gear-wheel", (0.0, 0.0))

            def part(machine, hand_rate):
                if machine is None:
                    return "-"
                tot = machine + (hand_rate or 0.0)
                return "%.0f %%" % (100.0 * machine / tot) if tot > 0 else "-"

            pk = tech.get((mn, t))
            print("%-7s | %3d | %20s | %12s (%.2f PNJ) | %12s | %18s | %12s (%.2f PNJ) | %12s | %9s |" % (
                t, mn, ci, hc[1], hc[0] or 0, part(ci, hc[1]), eg, hg[1], hg[0] or 0, part(eg, hg[1]),
                ("%.1f" % (pk / 10.0)) if pk is not None else "-"))
    print("relais (lignes [FO-PORTES] relais) : " + (", ".join("%s %d" % (k, relais[k]) for k in sorted(relais)) or "aucune"))
    print("retenues par la porte du transport (decisions de l'executant) : " + (", ".join("%s %d" % (k, sature[k]) for k in sorted(sature)) or "aucune"))


def main(argv):
    teams, minutes, archs = ["scarlet", "azure", "player"], [60, 90, 120], []
    i = 0
    while i < len(argv):
        if argv[i] == "--equipes":
            i += 1
            teams = argv[i].split(",")
        elif argv[i] == "--minutes":
            i += 1
            minutes = [int(x) for x in argv[i].split(",")]
        else:
            archs.append(argv[i])
        i += 1
    if not archs:
        print(__doc__)
        return 2
    for a in archs:
        read(a, teams, minutes)
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
