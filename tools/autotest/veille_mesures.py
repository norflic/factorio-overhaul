# -*- coding: utf-8 -*-
"""Lot VEILLE (essai 2) : lecture des archives de bancs etape1-guide / veille-temoin (216 300 ticks) du lot contre le temoin (meme source,
veille eteinte) et la base commune, avec les verdicts des criteres ecrits AVANT (docs/CRITERES_VEILLE.md).

Usage :
  PYTHONUTF8=1 py -3.9 -B tools/autotest/veille_mesures.py --base <dossier> [--pref-base temoin-] --lot <dossier> [--pref-lot lot-] \
      [--graines 20261020 123456789 271828182 1618033988]
  Une archive est un dossier de banc.py : benchmark.log ou benchmark.log.gz. Exemple (lot contre temoin) :
  --base fo-logs/<jour>_RECON6 --pref-base temoin- --lot fo-logs/<jour>_RECON6 --pref-lot lot-

Sortie, par graine : soldats / tourelles par faction a 12, 40, 60 min (base/lot), departs de veille par faction (et par 10 min), arrives,
fuites, perdus, minutes d'ouvrier absent, cout en fer par depart (pertes x 50 plaques / departs), secteurs reconnus a 20, 40, 60 min,
attaques vers le joueur, PNJ de l'equipe, morts de soldats. Verdict par critere ; code de sortie 1 si la defense n'est pas tenue.
"""
import argparse
import gzip
import os
import re
import sys

TAGS = r"(?:ETAPE1-GUIDE|RECON-GUIDE|VEILLE-TEMOIN)"
SOLD = re.compile(TAGS + r"\] minute (\d+) \| vivantes \d+ \| (.*?) \| ouvriers du joueur (\d+)")
TOUR = re.compile(TAGS + r"\] mesure minute (\d+) \| (\w+) \|.* tourelles=(\d+)")
ATT = re.compile(r"\[FO-STRAT\] attaque tick (\d+) (\w+) -> (\w+) : (\d+) soldats")
DEP = re.compile(r"\[FO-VEILLE\] depart tick (\d+) (\w+) :")
FIN = re.compile(r"\[FO-VEILLE\] fin tick (\d+) (\w+) : (\w+) apres ([\d.]+) min")
BILAN = re.compile(r"\[FO-VEILLE\] bilan tick (\d+) (\w+) minute (\d+) : partis (\d+), arrives (\d+), fuites (\d+), perdus (\d+), "
                   r"chemins (\d+), autres (\d+), ouvrier absent ([\d.]+) min, rayon (\d+), secteurs reconnus (\w+), veille \w+, refus \{([^}]*)\}")
MORT = re.compile(r"\[FO-VEILLE\] soldat mort tick (\d+) (\w+) : par (\S+) \((\w+)\) en \((-?\d+), (-?\d+)\), a (\d+) tuiles du QG")
PLATES_PAR_OUVRIER = 50


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
    d = {"sold": {}, "tour": {}, "att": [], "dep": {}, "fin": {}, "mort": [], "sect": {}, "joueur": {}, "bilan": {}}
    for ln in lines_of(folder):
        m = SOLD.search(ln)
        if m:
            mi = int(m.group(1))
            for f in re.finditer(r"(\w+) soldats (\d+)", m.group(2)):
                d["sold"][(mi, f.group(1))] = int(f.group(2))
            d["joueur"][mi] = int(m.group(3))
            continue
        m = TOUR.search(ln)
        if m:
            d["tour"][(int(m.group(1)), m.group(2))] = int(m.group(3))
            continue
        m = ATT.search(ln)
        if m:
            d["att"].append((int(m.group(1)), m.group(2), m.group(3), int(m.group(4))))
            continue
        m = DEP.search(ln)
        if m:
            d["dep"].setdefault(m.group(2), []).append(int(m.group(1)) / 3600.0)
            continue
        m = FIN.search(ln)
        if m:
            d["fin"].setdefault(m.group(2), []).append((int(m.group(1)) / 3600.0, m.group(3), float(m.group(4))))
            continue
        m = MORT.search(ln)
        if m:
            d["mort"].append(m.groups())
            continue
        m = BILAN.search(ln)
        if m:
            f, mi = m.group(2), int(m.group(3))
            d["bilan"][(f, mi)] = {"partis": int(m.group(4)), "arrives": int(m.group(5)), "fuites": int(m.group(6)),
                                   "perdus": int(m.group(7)), "absent": float(m.group(10)), "refus": m.group(13)}
            if m.group(12).isdigit():
                d["sect"].setdefault(f, []).append((float(mi), int(m.group(12))))
    return d


def sect_at(series, minute):
    best = None
    for t, n in sorted(series or []):
        if t <= minute:
            best = n
    return best


def run(base_dir, lot_dir, pref_base, pref_lot, seeds):
    bad_def = 0
    cases_ok = 0
    cases = 0
    tot = {"dep": 0, "perdu": 0, "fuite": 0, "arr": 0, "absent": 0.0, "sect_ok": 0, "sect_up": 0, "sect_n": 0, "seed_sect_ok": 0,
           "seed_sect_up": 0}
    for g in seeds:
        b = parse(os.path.join(base_dir, pref_base + g))
        l = parse(os.path.join(lot_dir, pref_lot + g))
        facs = sorted({f for (_, f) in b["sold"]} | {f for (_, f) in l["sold"]})
        print("##### graine", g)
        s60 = [0, 0]
        for f in facs:
            cells = []
            ok_case = True
            for mi in (12, 40, 60):
                sb, sl = b["sold"].get((mi, f)), l["sold"].get((mi, f))
                tb, tl = b["tour"].get((mi, f)), l["tour"].get((mi, f))
                cells.append("min %d : soldats %s/%s tourelles %s/%s" % (mi, sb, sl, tb, tl))
                if None not in (sb, sl) and sl < sb - 2:
                    print("    ECART DEFENSE : %s min %d soldats %d -> %d" % (f, mi, sb, sl))
                    ok_case = False
                if None not in (tb, tl) and tl < tb - 1:
                    print("    ECART DEFENSE : %s min %d tourelles %d -> %d" % (f, mi, tb, tl))
                    ok_case = False
            cases += 1
            cases_ok += 1 if ok_case else 0
            dep = l["dep"].get(f, [])
            fin = l["fin"].get(f, [])
            why = {}
            for _, w, _ in fin:
                why[w] = why.get(w, 0) + 1
            absent = sum(x[2] for x in fin)
            tot["dep"] += len(dep)
            tot["perdu"] += why.get("perdu", 0)
            tot["fuite"] += why.get("fuite", 0)
            tot["arr"] += why.get("fini", 0)
            tot["absent"] += absent
            sectors = []
            for mi in (20, 40, 60):
                sb, sl = sect_at(b["sect"].get(f), mi), sect_at(l["sect"].get(f), mi)
                sectors.append("%s/%s" % (sb, sl))
                if sb is not None and sl is not None:
                    tot["sect_n"] += 1
                    tot["sect_ok"] += 1 if sl >= sb else 0
                    tot["sect_up"] += 1 if sl > sb else 0
            sb60, sl60 = sect_at(b["sect"].get(f), 60), sect_at(l["sect"].get(f), 60)
            s60[0] += sb60 or 0
            s60[1] += sl60 or 0
            print("  %-8s base/lot  %s" % (f, " | ".join(cells)))
            print("  %-8s veille : departs %d (%.2f par 10 min), issues %s, ouvrier absent %.1f min ; secteurs 20/40/60 base/lot : %s" % (
                "", len(dep), len(dep) / 6.0, why or "-", absent, " ; ".join(sectors)))
        # Tolerances declarees avant la lecture des parties (docs/CRITERES_VEILLE.md) : >= 95 % du temoin, en hausse au-dela de 110 %.
        if s60[1] >= 0.95 * s60[0]:
            tot["seed_sect_ok"] += 1
        if s60[1] > 1.10 * s60[0]:
            tot["seed_sect_up"] += 1
        print("  secteurs reconnus a 60 min, somme des factions : base %d lot %d" % (s60[0], s60[1]))
        pb = [a for a in b["att"] if a[2] == "player"]
        pl = [a for a in l["att"] if a[2] == "player"]
        fb = [a for a in b["att"] if a[2] != "player"]
        fl = [a for a in l["att"] if a[2] != "player"]
        print("  attaques vers le joueur : base %d | lot %d ; entre factions : base %d | lot %d" % (len(pb), len(pl), len(fb), len(fl)))
        if len(pl) > len(pb):
            print("    ECART DEFENSE : %d attaque(s) de plus vers le joueur" % (len(pl) - len(pb)))
            bad_def += 1
        jb = [b["joueur"].get(m) for m in (12, 40, 60)]
        jl = [l["joueur"].get(m) for m in (12, 40, 60)]
        print("  PNJ de votre equipe 12/40/60 : base %s | lot %s" % (jb, jl))
        for x, y, m in zip(jb, jl, (12, 40, 60)):
            if None not in (x, y) and y < x:
                print("    ECART DEFENSE : PNJ de votre equipe min %d : %d -> %d" % (m, x, y))
                bad_def += 1
        if l["mort"]:
            zones = {}
            for m in l["mort"]:
                key = (m[1], m[2], int(m[6]) // 100 * 100)
                zones[key] = zones.get(key, 0) + 1
            print("  morts de soldats (lot) : %d ; plus frequents : %s" % (len(l["mort"]), sorted(zones.items(), key=lambda kv: -kv[1])[:3]))
    print("=== criteres (docs/CRITERES_VEILLE.md)")
    n_f = max(1, len(seeds) * 2)
    per10 = tot["dep"] / 6.0 / n_f
    print("1. departs : %d en tout, %.2f par faction et par 10 min -> %s" % (tot["dep"], per10, "tenu" if per10 >= 0.5 else "NON TENU"))
    pct = 100.0 * tot["perdu"] / tot["dep"] if tot["dep"] else 0.0
    print("2. pertes : %d perdus sur %d departs (%.0f %%) ; fuites %d ; arrives %d -> %s" % (tot["perdu"], tot["dep"], pct, tot["fuite"],
          tot["arr"], "tenu" if pct <= 30 else "NON TENU"))
    ok3 = tot["seed_sect_ok"] >= 3 and tot["seed_sect_up"] >= 2
    print("3. secteurs a 60 min >= base sur %d graine(s) sur %d, en hausse sur %d -> %s (points >= base : %d sur %d)" % (
        tot["seed_sect_ok"], len(seeds), tot["seed_sect_up"], "tenu" if ok3 else "NON TENU", tot["sect_ok"], tot["sect_n"]))
    need = max(0, cases * 7 // 8 if cases % 8 == 0 else (cases * 7 + 7) // 8)
    ok4 = cases_ok >= need and bad_def == 0
    print("4. defense : %d cas faction x graine sur %d dans la tolerance (exige %d), autres ecarts %d -> %s" % (
        cases_ok, cases, need, bad_def, "tenu" if ok4 else "NON TENU"))
    cost = PLATES_PAR_OUVRIER * tot["perdu"] / tot["dep"] if tot["dep"] else 0.0
    print("5. cout en fer : %.1f plaque(s) par depart (%d x %d / %d) -> %s" % (cost, tot["perdu"], PLATES_PAR_OUVRIER, tot["dep"],
          "tenu" if cost <= 5 else "NON TENU"))
    per_fac = tot["absent"] / n_f
    print("6. cout en travail : %.1f min d'ouvrier absent en tout, %.1f par faction et par heure (tolerance 15) -> %s" % (
        tot["absent"], per_fac, "tenu" if per_fac <= 15 else "NON TENU (bloquant seulement avec une defense en baisse)"))
    if tot["dep"]:
        print("   issues des missions de veille : fini %d (%.0f %%), fuite %d (%.0f %%), perdu %d, autres %d" % (
            tot["arr"], 100.0 * tot["arr"] / tot["dep"], tot["fuite"], 100.0 * tot["fuite"] / tot["dep"], tot["perdu"],
            tot["dep"] - tot["arr"] - tot["fuite"] - tot["perdu"]))
    return 0 if ok4 else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--lot", required=True)
    ap.add_argument("--pref-base", default="temoin-")
    ap.add_argument("--pref-lot", default="lot-")
    ap.add_argument("--graines", nargs="*", default=["20261020", "123456789", "271828182", "1618033988"])
    a = ap.parse_args()
    return run(a.base, a.lot, a.pref_base, a.pref_lot, a.graines)


if __name__ == "__main__":
    sys.exit(main())
