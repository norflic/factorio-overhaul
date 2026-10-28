# -*- coding: utf-8 -*-
"""Lot RECON : lecture des archives de bancs `recon-guide` (ou etape1-guide) pour le tableau avant / apres.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/recon_mesures.py <archive> [<archive> ...]
Pour chaque archive (dossier de banc.py : benchmark.log ou benchmark.log.gz) :
  - soldats et tourelles par faction aux minutes 12 et 60 (lignes [FO-RECON-GUIDE]) ;
  - attaques entre factions (lignes [FO-STRAT] attaque ... -> <faction>), la premiere ;
  - attaques sans savoir : une attaque contre une faction dont la ligne ne porte pas ', savoir <age> min' avec age <= 20,
    ou qui n'a pas de ligne [FO-RECON] vu anterieure non « inconnue » (le mod du lot ecrit ces lignes ; le temoin 0.6.5 ne
    les ecrit pas : la colonne reste « - ») ;
  - eclaireurs de reconnaissance partis / perdus / refus.
"""
import gzip
import os
import re
import sys

FRESH_MIN = 20.0


def lines_of(folder):
    for name in ("benchmark.log", "benchmark.log.gz", "benchmark-stdout.txt", "benchmark-stdout.txt.gz"):
        p = os.path.join(folder, name)
        if os.path.exists(p):
            op = gzip.open if p.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as fh:
                for ln in fh:
                    yield ln.rstrip("\n")
            return


RE_ARMY = re.compile(r"\[FO-RECON-GUIDE\] minute (\d+) \| (.*)$")
RE_FAC = re.compile(r"(\w+) soldats=(\d+) tourelles=(\d+) ouvriers=(\d+)")
RE_ATT = re.compile(r"\[FO-STRAT\] attaque tick (\d+) (\w+) -> (\w+) : (\d+) soldats.*?(?:, savoir ([\d.]+) min)?$")
RE_VU = re.compile(r"\[FO-RECON\] vu tick (\d+) (\w+) -> (\w+) : (\w+)")
RE_SC = re.compile(r"\[FO-RECON\] eclaireur tick (\d+) (\w+) : (part vers|PERDU|arrive|arrete|sans itineraire)")
RE_REF = re.compile(r"\[FO-RECON\] refus tick (\d+) (\w+) -> (\w+)")


def analyse(folder):
    army = {}
    attacks = []
    vu = {}
    seen_once = set()
    sc = {"part": 0, "perdu": 0, "arrive": 0, "refus": 0}
    unk = []
    has_lot = False
    for ln in lines_of(folder):
        m = RE_ARMY.search(ln)
        if m:
            minute = int(m.group(1))
            for f in RE_FAC.finditer(m.group(2)):
                army[(minute, f.group(1))] = (int(f.group(2)), int(f.group(3)), int(f.group(4)))
            continue
        m = RE_VU.search(ln)
        if m:
            has_lot = True
            t, f, r, st = int(m.group(1)), m.group(2), m.group(3), m.group(4)
            vu[(f, r)] = st
            if st != "inconnue":
                seen_once.add((f, r))
            continue
        m = RE_SC.search(ln)
        if m:
            has_lot = True
            k = m.group(3)
            if k == "part vers":
                sc["part"] += 1
            elif k == "PERDU":
                sc["perdu"] += 1
            elif k == "arrive":
                sc["arrive"] += 1
            continue
        if RE_REF.search(ln):
            has_lot = True
            sc["refus"] += 1
            continue
        m = RE_ATT.search(ln)
        if m:
            t, f, r = int(m.group(1)), m.group(2), m.group(3)
            if r == "player":
                continue
            age = re.search(r", savoir ([\d.]+) min", ln)
            attacks.append((t, f, r, float(age.group(1)) if age else None))
            if has_lot:
                if age is None or float(age.group(1)) > FRESH_MIN or (f, r) not in seen_once:
                    unk.append((t, f, r, age.group(1) if age else None))
    return army, attacks, sc, unk, has_lot


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    bad = 0
    for folder in argv[1:]:
        army, attacks, sc, unk, has_lot = analyse(folder)
        name = os.path.basename(os.path.normpath(folder))
        row = []
        for minute in (12, 60):
            sold = sum(v[0] for (mi, f), v in army.items() if mi == minute)
            tour = sum(v[1] for (mi, f), v in army.items() if mi == minute)
            work = sum(v[2] for (mi, f), v in army.items() if mi == minute)
            row.append("min %d : soldats %d tourelles %d ouvriers %d" % (minute, sold, tour, work))
        first = min((a[0] for a in attacks), default=None)
        print("%-34s | %s | attaques entre factions %d (1re %s)%s" % (
            name, " | ".join(row), len(attacks),
            ("min %.1f" % (first / 3600.0)) if first is not None else "-",
            (" | sans savoir %d" % len(unk)) if has_lot else " | (temoin : sans ligne de savoir)"))
        if has_lot:
            print("%-34s   eclaireurs partis %d, arrives %d, perdus %d, refus %d" % ("", sc["part"], sc["arrive"], sc["perdu"], sc["refus"]))
            for u in unk:
                print("    ATTAQUE SANS SAVOIR : tick %d %s -> %s (age %s)" % u)
                bad += 1
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
