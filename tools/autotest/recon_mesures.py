# -*- coding: utf-8 -*-
"""Lot RECON : lecture des archives de bancs `recon-guide` (ou etape1-guide) pour le tableau temoin / lot.

Usage :
  PYTHONUTF8=1 py -3.9 -B tools/autotest/recon_mesures.py <archive> [<archive> ...]
      resume par archive : soldats / tourelles aux minutes 12, 40 et 60, attaques entre factions (la premiere), attaques sans
      savoir, eclaireurs (partis, balayages, arrives, perdus, sans itineraire par faction), premiere vue de chaque rivale ;
  PYTHONUTF8=1 py -3.9 -B tools/autotest/recon_mesures.py --tableau <temoin> <lot>
      tableau minute par minute (toutes les 5 min, plus la minute 12) : soldats et tourelles de chaque faction, temoin et lot,
      avec les creux (lot < temoin) et le bilan aux minutes 12, 40 et 60.

Une archive est un dossier de banc.py (benchmark.log ou benchmark.log.gz). Code de sortie 1 si une attaque entre factions part
sans savoir frais (', savoir <age> min' absent ou > 20) ou si une faction a plus de 3 eclaireurs « sans itineraire ».
"""
import gzip
import os
import re
import sys

FRESH_MIN = 20.0
NOPATH_MAX = 3
KEY_MINUTES = (12, 40, 60)


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
RE_ATT = re.compile(r"\[FO-STRAT\] attaque tick (\d+) (\w+) -> (\w+) : (\d+) soldats")
RE_VU = re.compile(r"\[FO-RECON\] vu tick (\d+) (\w+) -> (\w+) : (\w+)")
RE_SC = re.compile(r"\[FO-RECON\] eclaireur tick (\d+) (\w+) : (part vers|PERDU|arrive|arrete|sans itineraire)")
RE_SWEEP = re.compile(r"\[FO-RECON\] eclaireur tick (\d+) (\w+) : part vers .*, balayer ")
RE_REF = re.compile(r"\[FO-RECON\] refus tick (\d+) (\w+) -> (\w+)")


def analyse(folder):
    army = {}
    attacks = []
    first_seen = {}
    seen_once = set()
    sc = {}
    refus = 0
    unk = []
    has_lot = False

    def row(f):
        return sc.setdefault(f, {"part": 0, "balayage": 0, "perdu": 0, "arrive": 0, "nopath": 0})

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
            if st != "inconnue":
                seen_once.add((f, r))
                first_seen.setdefault((f, r), t)
            continue
        m = RE_SC.search(ln)
        if m:
            has_lot = True
            k, f = m.group(3), m.group(2)
            r = row(f)
            if k == "part vers":
                r["part"] += 1
                if RE_SWEEP.search(ln):
                    r["balayage"] += 1
            elif k == "PERDU":
                r["perdu"] += 1
            elif k == "arrive":
                r["arrive"] += 1
            elif k == "sans itineraire":
                r["nopath"] += 1
            continue
        if RE_REF.search(ln):
            has_lot = True
            refus += 1
            continue
        m = RE_ATT.search(ln)
        if m:
            t, f, r = int(m.group(1)), m.group(2), m.group(3)
            if r == "player":
                attacks.append((t, f, r, None))
                continue
            age = re.search(r", savoir ([\d.]+) min", ln)
            attacks.append((t, f, r, float(age.group(1)) if age else None))
            if has_lot:
                if age is None or float(age.group(1)) > FRESH_MIN or (f, r) not in seen_once:
                    unk.append((t, f, r, age.group(1) if age else None))
    return {"army": army, "attacks": attacks, "sc": sc, "refus": refus, "unk": unk, "has_lot": has_lot, "first_seen": first_seen}


def summary(folder):
    a = analyse(folder)
    name = os.path.basename(os.path.normpath(folder))
    bad = 0
    row = []
    for minute in KEY_MINUTES:
        sold = sum(v[0] for (mi, f), v in a["army"].items() if mi == minute)
        tour = sum(v[1] for (mi, f), v in a["army"].items() if mi == minute)
        row.append("min %d : soldats %d tourelles %d" % (minute, sold, tour))
    fac = [x for x in a["attacks"] if x[2] != "player"]
    pla = [x for x in a["attacks"] if x[2] == "player"]
    first = min((x[0] for x in fac), default=None)
    print("%-30s | %s | attaques entre factions %d (1re %s) vers le joueur %d%s" % (
        name, " | ".join(row), len(fac), ("min %.1f" % (first / 3600.0)) if first is not None else "-", len(pla),
        (" | sans savoir %d" % len(a["unk"])) if a["has_lot"] else " | (temoin : sans ligne de savoir)"))
    if a["has_lot"]:
        for f in sorted(a["sc"]):
            r = a["sc"][f]
            print("%-30s   %s : eclaireurs partis %d (dont balayages %d), arrives %d, perdus %d, sans itineraire %d" % (
                "", f, r["part"], r["balayage"], r["arrive"], r["perdu"], r["nopath"]))
            if r["nopath"] > NOPATH_MAX:
                print("    TROP DE BUTS SANS ITINERAIRE : %s %d > %d" % (f, r["nopath"], NOPATH_MAX))
                bad += 1
        fs = ", ".join("%s->%s min %.1f" % (k[0], k[1], v / 3600.0) for k, v in sorted(a["first_seen"].items()))
        print("%-30s   premieres vues : %s ; refus %d" % ("", fs or "aucune", a["refus"]))
        for u in a["unk"]:
            print("    ATTAQUE SANS SAVOIR : tick %d %s -> %s (age %s)" % u)
            bad += 1
    return bad


def tableau(temoin, lot):
    t, l = analyse(temoin), analyse(lot)
    minutes = sorted({mi for (mi, f) in list(t["army"]) + list(l["army"])})
    facs = sorted({f for (mi, f) in list(t["army"]) + list(l["army"])})
    print("minute | " + " | ".join("%s soldats t/l, tourelles t/l" % f for f in facs))
    worse = {k: [] for k in KEY_MINUTES}
    for mi in minutes:
        cells = []
        for f in facs:
            a, b = t["army"].get((mi, f)), l["army"].get((mi, f))
            if not a or not b:
                cells.append("-")
                continue
            hole = "  <" if b[0] < a[0] or b[1] < a[1] else ""
            cells.append("%2d/%2d, %2d/%2d%s" % (a[0], b[0], a[1], b[1], hole))
            if mi in worse and (b[0] < a[0] or b[1] < a[1]):
                worse[mi].append(f)
        print("%5d | %s" % (mi, " | ".join(cells)))
    for mi in KEY_MINUTES:
        print("minute %d : lot sous le temoin pour %s" % (mi, ", ".join(worse[mi]) if worse[mi] else "aucune faction"))
    ts = sum(v[0] for v in t["army"].values())
    ls = sum(v[0] for v in l["army"].values())
    tt = sum(v[1] for v in t["army"].values())
    lt = sum(v[1] for v in l["army"].values())
    print("somme des releves (soldats-releves / tourelles-releves) : temoin %d / %d, lot %d / %d" % (ts, tt, ls, lt))


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    if argv[1] == "--tableau":
        if len(argv) != 4:
            print(__doc__)
            return 2
        tableau(argv[2], argv[3])
        return 0
    bad = 0
    for folder in argv[1:]:
        bad += summary(folder)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
