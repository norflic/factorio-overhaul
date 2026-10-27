"""Lot SCALE : part de PNJ sans tâche des factions (et de votre équipe) par tranche de minutes, lue dans un banc archivé.

Sources : lignes minute « [FO-IA1-SCALE] minute M | <équipe> n=N/MAX ... inactifs=X% » (ia1-scale, ia1b-scale30/10) et
« [FO-IA3C] <équipe> minute M | ... | inactifs I/N | ... » (cerveau, toutes les parties), et « [FO-EFFECTIF] ».
Usage : py -3.9 -B tools/autotest/scale_inactifs.py <archive> [a b] (tranche de minutes, défaut 30 60).
"""
import gzip, os, re, sys
RE_SC = re.compile(r"\[FO-IA1-SCALE\] minute (\d+) \| (\w+) n=(\d+)/(\d+).* inactifs=(\d+)%")
RE_C = re.compile(r"\[FO-IA3C\] (\w+) minute (\d+) \| actifs (\d+) productifs (\d+) pris (\d+) bloques (\d+) K (\d+) \| inactifs (\d+)/(\d+) \| attente (\d+) pensees, sans tache (\d+), libres (\d+), non prenables (\d+) \| sature \[([^\]]*)\]")
RE_EFF = re.compile(r"\[FO-EFFECTIF\] (\w+) minute (\d+) \| effectif (\d+)/(\d+) \(depart (\d+)\) \| croissance (\d+) \(recrues (\d+)\)")
def lines(d):
    for n in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(d, n)
        if os.path.exists(p):
            f = gzip.open(p, "rt", encoding="utf-8", errors="replace") if n.endswith(".gz") else open(p, encoding="utf-8", errors="replace")
            with f:
                for l in f:
                    yield l
            return
def main():
    d = sys.argv[1]
    a, b = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (30, 60)
    sc, c, eff = {}, {}, {}
    for l in lines(d):
        m = RE_SC.search(l)
        if m:
            sc.setdefault(m.group(2), []).append((int(m.group(1)), int(m.group(3)), int(m.group(5))))
        m = RE_C.search(l)
        if m:
            c.setdefault(m.group(1), []).append((int(m.group(2)), int(m.group(8)), int(m.group(9)), int(m.group(7)), int(m.group(3)), int(m.group(12)), int(m.group(10)), m.group(14)))
        m = RE_EFF.search(l)
        if m:
            eff.setdefault(m.group(1), []).append((int(m.group(2)), int(m.group(3)), int(m.group(6))))
    print("archive", os.path.basename(d.rstrip("/\\")), "tranche", a, "-", b, "min")
    allp = []
    for k in sorted(set(sc) | set(c)):
        r = [x for x in sc.get(k, []) if a <= x[0] < b]
        rc = [x for x in c.get(k, []) if a <= x[0] < b]
        s1 = sum(x[2] for x in r) / len(r) if r else None
        n1 = sum(x[1] for x in r) / len(r) if r else None
        idle = sum(x[1] for x in rc); tot = sum(x[2] for x in rc)
        s2 = 100.0 * idle / tot if tot else None
        act = sum(x[4] for x in rc) / len(rc) if rc else None
        K = sum(x[3] for x in rc) / len(rc) if rc else None
        free = sum(x[5] for x in rc) / max(1, sum(x[6] for x in rc)) if rc else None
        e = eff.get(k, [])
        emax = max((x[1] for x in e), default=None)
        efin = e[-1][1] if e else None
        grown = e[-1][2] if e else None
        if k != "player" and s2 is not None:
            allp.append(s2)
        print("  %-8s effectif moyen %s | sans tache (scale) %s %% | sans tache (cerveau) %s %% | projets actifs %s / K %s | taches libres/pensee %s | effectif max %s fin %s croissance %s" % (
            k, "-" if n1 is None else "%.1f" % n1, "-" if s1 is None else "%.1f" % s1, "-" if s2 is None else "%.1f" % s2,
            "-" if act is None else "%.1f" % act, "-" if K is None else "%.1f" % K, "-" if free is None else "%.2f" % free, emax, efin, grown))
    if allp:
        allp.sort()
        med = allp[len(allp)//2] if len(allp) % 2 else (allp[len(allp)//2-1] + allp[len(allp)//2]) / 2
        print("  factions : mediane sans tache (cerveau) %.1f %%, moyenne %.1f %%" % (med, sum(allp)/len(allp)))
main()
