"""Lot IA1-b2 : mesures de votre équipe dans une partie (verif-guide, ia1b-scale30/10, ia1-poles).

Usage : python -B tools/autotest/ia1b2_guide.py <archive> [<archive> ...]
Chaque archive est une copie de fo-autotest\\ (benchmark.log). Lit :
  - les lignes « mesure minute N | votre equipe | n=.. recrues=.. perdus=.. tues_ennemis=.. fer=.. ap=.. defendus=..
    tourelles=.. » (verif-guide depuis IA1-b2) ou « minute N | player n=a/b recrues=.. ... perdus=.. » (ia1b-scale) ;
  - les lignes « [FO-TEAM] <équipe> : PNJ <id> tue (<cause>) a <d> tuiles du QG, tache <type>[ (fond)], <m> min »
    (morts par tâche et par distance) ;
  - le BILAN du banc.
Imprime, par archive : effectif minute par minute (votre équipe), recrues, perdus, tués par les ennemis, fer, avant-postes,
tourelles, puis les morts de votre équipe par type de tâche. Code 0 si chaque archive a un benchmark.log, 1 sinon.
"""
import os
import re
import sys

RE_GUIDE = re.compile(r"mesure minute (\d+) \| (.+?) \| n=(\d+) recrues=(\d+) perdus=(-?\d+) tues_ennemis=(-?\d+) "
                      r"fer=(-?\d+) ap=(\d+) defendus=(-?\d+) tourelles=(-?\d+)")
RE_SCALE = re.compile(r"\] minute (\d+) \| (\w+) n=(\d+)/\d+ recrues=(\d+) .*? ap=(\d+) .*?perdus=(-?\d+) "
                      r"tues_ennemis=(-?\d+) tourelles=(-?\d+) defendus=(-?\d+)")
RE_DEATH = re.compile(r"\[FO-TEAM\] (\S+) : PNJ (\d+) tue \(([^)]*)\) a (-?\d+) tuiles du QG, tache (\w+)( \(fond\))?, "
                      r"([\d.]+) min")
RE_BILAN = re.compile(r"\[(FO-[A-Z0-9-]+)\] BILAN : (.*)$", re.M)


def load(d):
    p = os.path.join(d, "benchmark.log")
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8", errors="replace") as fh:
        log = fh.read()
    rows = {}
    for m in RE_GUIDE.finditer(log):
        team = "player" if m.group(2) == "votre equipe" else m.group(2)
        rows.setdefault(team, {})[int(m.group(1))] = {
            "n": int(m.group(3)), "rec": int(m.group(4)), "lost": int(m.group(5)), "enemy": int(m.group(6)),
            "iron": int(m.group(7)), "ap": int(m.group(8)), "def": int(m.group(9)), "tur": int(m.group(10))}
    for m in RE_SCALE.finditer(log):
        rows.setdefault(m.group(2), {})[int(m.group(1))] = {
            "n": int(m.group(3)), "rec": int(m.group(4)), "ap": int(m.group(5)), "lost": int(m.group(6)),
            "enemy": int(m.group(7)), "tur": int(m.group(8)), "def": int(m.group(9)), "iron": -1}
    deaths = []
    for m in RE_DEATH.finditer(log):
        deaths.append({"team": m.group(1), "cause": m.group(3), "dist": int(m.group(4)), "kind": m.group(5),
                       "fond": bool(m.group(6)), "min": float(m.group(7))})
    bilans = ["%s %s" % (m.group(1), m.group(2).strip()) for m in RE_BILAN.finditer(log)]
    return rows, deaths, bilans


def team_summary(name, series):
    mins = sorted(series)
    if not mins:
        return
    last = series[mins[-1]]
    nmax = max(series[k]["n"] for k in mins)
    print("  %s : effectif fin %d (max %d), recrues %d, perdus %d dont tues par les ennemis %d, avant-postes %d "
          "(defendus %d), tourelles %d, fer %d" % (name, last["n"], nmax, last["rec"], last["lost"], last["enemy"],
                                                   last["ap"], last["def"], last["tur"], last["iron"]))


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    rc = 0
    for d in argv:
        r = load(d)
        print("== %s" % d)
        if r is None:
            print("  benchmark.log absent")
            rc = 1
            continue
        rows, deaths, bilans = r
        for b in bilans:
            print("  BILAN " + b)
        p = rows.get("player", {})
        if p:
            mins = sorted(p)
            print("  votre equipe, effectif par minute : " + " ".join("%d" % p[k]["n"] for k in mins))
            print("  votre equipe, fer par minute      : " + " ".join("%d" % p[k]["iron"] for k in mins if k % 5 == 0))
        for name in sorted(rows):
            team_summary(name, rows[name])
        by = {}
        for x in deaths:
            key = (x["team"], x["kind"] + (" fond" if x["fond"] else ""))
            by.setdefault(key, []).append(x)
        teams = sorted(set(k[0] for k in by))
        for t in teams:
            parts = []
            tot = 0
            for k in sorted(k for k in by if k[0] == t):
                xs = by[k]
                tot += len(xs)
                dist = sorted(x["dist"] for x in xs)
                parts.append("%s %d (distance mediane %d)" % (k[1], len(xs), dist[len(dist) // 2]))
            enemy = sum(1 for k in by if k[0] == t for x in by[k] if "/enemy:" in x["cause"])
            print("  morts %s : %d (ennemis %d) : %s" % (t, tot, enemy, ", ".join(parts)))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
