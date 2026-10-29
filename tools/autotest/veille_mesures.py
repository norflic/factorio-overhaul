# -*- coding: utf-8 -*-
"""Lot VEILLE : lecture des archives de bancs etape1-guide (216 300 ticks) du lot contre la base commune, avec les verdicts des
criteres ecrits AVANT (docs/CRITERES_VEILLE.md).

Usage :
  PYTHONUTF8=1 py -3.9 -B tools/autotest/veille_mesures.py --base <dossier des base-<graine>> --lot <dossier des lot-<graine>> \
      [--graines 20261020 123456789 271828182 1618033988]
  (une archive est un dossier de banc.py : benchmark.log ou benchmark.log.gz ; noms <dossier>/base-<graine> et <dossier>/lot-<graine>,
   ou deux dossiers distincts passes par --base et --lot, avec les prefixes --pref-base et --pref-lot)

Sortie, par graine : soldats / tourelles par faction a 12, 40, 60 min (base/lot), eclaireurs partis par faction et par 10 min, perdus,
secteurs reconnus a 20, 40, 60 min (bilans [FO-VEILLE] de 10 min, "secteurs reconnus N" ; le TEMOIN est la MEME source avec la veille
eteinte, scenario veille-temoin : lui aussi publie ces bilans ; la base-<graine> de MESURES n'en a pas), attaques vers le joueur (distribution), attaques entre factions, morts de soldats par cause et zone.
Verdict par critere (tenu / non tenu) ; code de sortie 1 si un critere de defense n'est pas tenu.
"""
import argparse
import gzip
import os
import re
import sys

SOLD = re.compile(r"(?:ETAPE1-GUIDE|RECON-GUIDE|VEILLE-TEMOIN)\] minute (\d+) \| vivantes \d+ \| (.*?) \| ouvriers du joueur")
TOUR = re.compile(r"(?:ETAPE1-GUIDE|RECON-GUIDE|VEILLE-TEMOIN)\] mesure minute (\d+) \| (\w+) \|.* tourelles=(\d+)")
ATT = re.compile(r"\[FO-STRAT\] attaque tick (\d+) (\w+) -> (\w+) : (\d+) soldats")
DEP = re.compile(r"\[FO-VEILLE\] depart tick (\d+) (\w+) :")
PERDU = re.compile(r"\[FO-VEILLE\] perdu tick (\d+) (\w+) :")
ARR = re.compile(r"\[FO-VEILLE\] fin tick (\d+) (\w+) : arrive")
FAB = re.compile(r"\[FO-VEILLE\] vivier tick (\d+) (\w+) :")
BILAN = re.compile(r"\[FO-VEILLE\] bilan tick (\d+) (\w+) minute (\d+) : .*secteurs reconnus (\w+), veille \w+, refus \{([^}]*)\}")
MORT = re.compile(r"\[FO-VEILLE\] soldat mort tick (\d+) (\w+) : par (\S+) \((\w+)\) en \((-?\d+), (-?\d+)\), a (\d+) tuiles du QG")
SECT = re.compile(r"\[FO-IA3F\] (\w+) : .*? a ([\d.]+) min.*?secteurs vus (\d+)")
JOUEUR = re.compile(r"ouvriers du joueur (\d+)")


def lines_of(folder):
    for name in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(folder, name)
        if os.path.exists(p):
            op = gzip.open if p.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as fh:
                for ln in fh:
                    yield ln.rstrip("\n")
            return
    raise SystemExit("aucune archive dans " + folder)


def parse(folder):
    d = {"sold": {}, "tour": {}, "att": [], "dep": {}, "perdu": {}, "arr": {}, "fab": {}, "mort": [], "sect": {}, "joueur": {},
         "refus": {}}
    for ln in lines_of(folder):
        m = SOLD.search(ln)
        if m:
            mi = int(m.group(1))
            for f in re.finditer(r"(\w+) soldats (\d+)", m.group(2)):
                d["sold"][(mi, f.group(1))] = int(f.group(2))
            j = JOUEUR.search(ln)
            if j:
                d["joueur"][mi] = int(j.group(1))
            continue
        m = TOUR.search(ln)
        if m:
            d["tour"][(int(m.group(1)), m.group(2))] = int(m.group(3))
            continue
        m = ATT.search(ln)
        if m:
            d["att"].append((int(m.group(1)), m.group(2), m.group(3), int(m.group(4))))
            continue
        for key, rx in (("dep", DEP), ("perdu", PERDU), ("arr", ARR), ("fab", FAB)):
            m = rx.search(ln)
            if m:
                d[key].setdefault(m.group(2), []).append(int(m.group(1)) / 3600.0)
                break
        else:
            m = MORT.search(ln)
            if m:
                d["mort"].append(m.groups())
                continue
            m = BILAN.search(ln)
            if m:
                d["refus"][(m.group(2), int(m.group(3)))] = m.group(5)
                if m.group(4).isdigit():
                    d["sect"].setdefault(m.group(2), []).append((float(m.group(3)), int(m.group(4))))
    return d


def sect_at(series, minute):
    best = None
    for t, n in sorted(series or []):
        if t <= minute:
            best = n
    return best


def run(base_dir, lot_dir, pref_base, pref_lot, seeds):
    bad_def = 0
    tot = {"dep": 0, "perdu": 0, "slots": 0, "sect_ok": 0, "sect_up": 0, "sect_n": 0}
    for g in seeds:
        b = parse(os.path.join(base_dir, pref_base + g))
        l = parse(os.path.join(lot_dir, pref_lot + g))
        facs = sorted({f for (_, f) in b["sold"]} | {f for (_, f) in l["sold"]})
        print("##### graine", g)
        for f in facs:
            cells = []
            for mi in (12, 40, 60):
                sb, sl = b["sold"].get((mi, f)), l["sold"].get((mi, f))
                tb, tl = b["tour"].get((mi, f)), l["tour"].get((mi, f))
                cells.append("min %d : soldats %s/%s tourelles %s/%s" % (mi, sb, sl, tb, tl))
                if None not in (sb, sl) and sl < sb - 2:
                    print("    DEFENSE NON TENUE : %s min %d soldats %d -> %d" % (f, mi, sb, sl))
                    bad_def += 1
                if None not in (tb, tl) and tl < tb - 1:
                    print("    DEFENSE NON TENUE : %s min %d tourelles %d -> %d" % (f, mi, tb, tl))
                    bad_def += 1
            dep, perdu = l["dep"].get(f, []), l["perdu"].get(f, [])
            tot["dep"] += len(dep)
            tot["perdu"] += len(perdu)
            sectors = []
            for mi in (20, 40, 60):
                sb, sl = sect_at(b["sect"].get(f), mi), sect_at(l["sect"].get(f), mi)
                sectors.append("%s/%s" % (sb, sl))
                if sb is not None and sl is not None:
                    tot["sect_n"] += 1
                    tot["sect_ok"] += 1 if sl >= sb else 0
                    tot["sect_up"] += 1 if sl > sb else 0
            print("  %-8s base/lot  %s" % (f, " | ".join(cells)))
            print("  %-8s eclaireurs : fabriques %d, partis %d (%.2f par 10 min), arrives %d, perdus %d ; secteurs 20/40/60 base/lot : %s" % (
                "", len(l["fab"].get(f, [])), len(dep), len(dep) / 6.0, len(l["arr"].get(f, [])), len(perdu), " ; ".join(sectors)))
            last = max([k[1] for k in l["refus"] if k[0] == f] or [0])
            if last:
                print("  %-8s refus (derniere periode, minute %d) : %s" % ("", last, l["refus"][(f, last)]))
        pb = [a for a in b["att"] if a[2] == "player"]
        pl = [a for a in l["att"] if a[2] == "player"]
        fb = [a for a in b["att"] if a[2] != "player"]
        fl = [a for a in l["att"] if a[2] != "player"]
        print("  attaques vers le joueur : base %d %s | lot %d %s" % (len(pb), [(round(a[0] / 3600.0, 1), a[1], a[3]) for a in pb], len(pl),
              [(round(a[0] / 3600.0, 1), a[1], a[3]) for a in pl]))
        print("  attaques entre factions : base %d | lot %d" % (len(fb), len(fl)))
        if len(pl) > len(pb):
            print("    DEFENSE NON TENUE : %d attaque(s) de plus vers le joueur" % (len(pl) - len(pb)))
            bad_def += 1
        jb = [b["joueur"].get(m) for m in (12, 40, 60)]
        jl = [l["joueur"].get(m) for m in (12, 40, 60)]
        print("  PNJ de votre equipe (ouvriers du joueur) 12/40/60 : base %s | lot %s" % (jb, jl))
        for x, y, m in zip(jb, jl, (12, 40, 60)):
            if None not in (x, y) and y < x:
                print("    DEFENSE NON TENUE : PNJ de votre equipe min %d : %d -> %d" % (m, x, y))
                bad_def += 1
        if l["mort"]:
            zones = {}
            for m in l["mort"]:
                key = (m[1], m[2], int(m[6]) // 100 * 100)
                zones[key] = zones.get(key, 0) + 1
            print("  morts de soldats (lot) : %d ; plus frequents : %s" % (len(l["mort"]), sorted(zones.items(), key=lambda kv: -kv[1])[:4]))
    print("=== criteres (docs/CRITERES_VEILLE.md)")
    pct = 100.0 * tot["perdu"] / tot["dep"] if tot["dep"] else 0.0
    print("2. perdus : %d sur %d partis (%.0f %%) -> %s" % (tot["perdu"], tot["dep"], pct, "tenu" if pct <= 30 else "NON TENU"))
    print("3. secteurs reconnus >= base : %d sur %d points ; en hausse : %d" % (tot["sect_ok"], tot["sect_n"], tot["sect_up"]))
    print("4. defense : %s" % ("tenue" if bad_def == 0 else "NON TENUE (%d ecart(s))" % bad_def))
    print("1. depart : voir les lignes eclaireurs ci-dessus (>= 0,5 par faction et par 10 min quand le vivier existe)")
    return 1 if bad_def else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--lot", required=True)
    ap.add_argument("--pref-base", default="base-")
    ap.add_argument("--pref-lot", default="lot-")
    ap.add_argument("--graines", nargs="*", default=["20261020", "123456789", "271828182", "1618033988"])
    a = ap.parse_args()
    return run(a.base, a.lot, a.pref_base, a.pref_lot, a.graines)


if __name__ == "__main__":
    sys.exit(main())
