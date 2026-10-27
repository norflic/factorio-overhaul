"""Lot SCALE : résumé d'un banc verif-guide / scale-guide30 (BILAN, ouvriers des factions, attaques contre le joueur,
fer de votre équipe, PNJ sans tâche des factions). Usage : py -3.9 -B tools/autotest/scale_guide.py <archive> [<archive> ...]"""
import gzip, os, re, sys
RE_B = re.compile(r"\[FO-(VERIF-GUIDE|SCALE-GUIDE30)\] BILAN : (\d+) OK, (\d+) ECHEC")
RE_E = re.compile(r"\[FO-(?:VERIF-GUIDE|SCALE-GUIDE30)\] ECHEC\s+(.*)$")
RE_M = re.compile(r"\] minute (\d+) \| vivantes (-?\d+) \| (.*) \| ouvriers du joueur (\d+) \|")
RE_F = re.compile(r"(\w+) soldats (\d+) ouvriers (\d+) attaques-joueur (\d+) (\w+)")
RE_MM = re.compile(r"mesure minute (\d+) \| (.+?) \| n=(\d+) recrues=(\d+) perdus=(-?\d+) .*? fer=(-?\d+) ap=(\d+) .*? inactifs=(\d+)%")
RE_EFF = re.compile(r"\[FO-EFFECTIF\] (\w+) minute (\d+) \| effectif (\d+)/(\d+) \(depart (\d+)\) \| croissance (\d+) \(recrues (\d+)\) \| raisons \{([^}]*)\}")
def lines(d):
    for n in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(d, n)
        if os.path.exists(p):
            f = gzip.open(p, "rt", encoding="utf-8", errors="replace") if n.endswith(".gz") else open(p, encoding="utf-8", errors="replace")
            with f:
                yield from f
            return
for d in sys.argv[1:]:
    bilan, echecs, last, mm, eff = None, [], None, {}, {}
    for l in lines(d):
        m = RE_B.search(l)
        if m: bilan = "%s OK, %s ECHEC" % (m.group(2), m.group(3))
        m = RE_E.search(l)
        if m: echecs.append(m.group(1)[:140])
        m = RE_M.search(l)
        if m: last = (int(m.group(1)), m.group(2), m.group(3), m.group(4))
        m = RE_MM.search(l)
        if m: mm.setdefault(m.group(2), []).append((int(m.group(1)), int(m.group(3)), int(m.group(4)), int(m.group(5)), int(m.group(6)), int(m.group(7)), int(m.group(8))))
        m = RE_EFF.search(l)
        if m: eff[m.group(1)] = (int(m.group(3)), int(m.group(6)), m.group(8))
    print("==", os.path.basename(d.rstrip("/\\")), "|", bilan, "|", "; ".join(echecs))
    if last:
        fs = RE_F.findall(last[2])
        print("   minute %d : vivantes %s ; %s ; ouvriers du joueur %s" % (last[0], last[1], ", ".join("%s %s sold. %s ouv. %s att." % (a, b, c, e) for a, b, c, e, _ in fs), last[3]))
    for k in sorted(mm):
        r = mm[k]
        tail = [x for x in r if x[0] >= 30]
        idle = sum(x[6] for x in tail) / len(tail) if tail else float("nan")
        nmax = max(x[1] for x in r)
        fin = r[-1]
        print("   %-13s n max %d fin %d, recrues %d, perdus %d, fer fin %d, ap %d, sans tache 30-fin %.1f %%" % (k, nmax, fin[1], fin[2], fin[3], fin[4], fin[5], idle))
    for k in sorted(eff):
        print("   effectif %-8s %d, croissance %d, raisons (derniere minute) {%s}" % (k, eff[k][0], eff[k][1], eff[k][2]))
