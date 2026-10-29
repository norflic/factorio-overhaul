# Lot KIT : rendement des minages à la main et morts, par force, depuis les lignes [FO-MINAGE] et « PNJ n tue » d'archives banc.py.
# Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/kit_minage.py <archive> [<archive> ...]
# Pour chaque archive et chaque force : minages finis, part à 0/N (got=0), part sous 10 % du compte, rendement moyen ;
# morts de PNJ : minute, distance au QG, tâche, tueur (ennemi réel ou autre). Aucune conclusion : des chiffres.
import gzip, os, re, sys

MIN = re.compile(r"\[FO-MINAGE\] (\w+) min=([\d.]+) (\S+) got=(-?\d+)/(\d+) dt=([\d.]+) (\S+)")
DEAD = re.compile(r"\[FO-TEAM\] (\w+) : PNJ (\d+) tue \(([^)]*)\) a (\d+) tuiles du QG, tache (\S+), ([\d.]+) min")


def lire(arch):
    for nom in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, nom)
        if os.path.exists(p):
            f = gzip.open(p, "rt", encoding="utf8", errors="replace") if nom.endswith(".gz") else open(p, encoding="utf8", errors="replace")
            with f:
                return f.read().splitlines()
    return []


def main(argv):
    for arch in argv:
        seed = ""
        sp = os.path.join(arch, "seed.txt")
        if os.path.exists(sp):
            seed = open(sp).read().strip()
        mines, morts = {}, {}
        for ln in lire(arch):
            m = MIN.search(ln)
            if m:
                mines.setdefault(m.group(1), []).append((float(m.group(2)), int(m.group(4)), int(m.group(5))))
                continue
            m = DEAD.search(ln)
            if m:
                morts.setdefault(m.group(1), []).append((float(m.group(6)), int(m.group(4)), m.group(5), m.group(3)))
        print("== %s (graine %s)" % (os.path.basename(os.path.normpath(arch)), seed))
        for key in sorted(set(mines) | set(morts)):
            L = mines.get(key, [])
            n = len(L)
            z = sum(1 for _, g, c in L if g <= 0)
            low = sum(1 for _, g, c in L if g * 10 < c)
            tot = sum(g for _, g, c in L)
            avg = (100.0 * sum(g / c for _, g, c in L) / n) if n else 0
            print("  %-8s minages=%3d  a_zero=%3d (%.0f %%)  sous10%%=%3d (%.0f %%)  rendement_moyen=%.0f %%  minerai=%d" % (
                key, n, z, 100.0 * z / n if n else 0, low, 100.0 * low / n if n else 0, avg, tot))
            D = morts.get(key, [])
            if D:
                att = sum(1 for d in D if "enemy" in d[3])
                qg = sum(1 for d in D if d[1] <= 10)
                print("           morts=%d (tueur ennemi=%d, a <=10 tuiles du QG=%d) minutes : %s" % (
                    len(D), att, qg, " ".join("%.0f" % d[0] for d in D[:30])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
