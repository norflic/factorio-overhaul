"""Lit les lignes [FO-DORM] d'archives du banc (benchmark.log.gz) et classe les fours / foreuses dormants par cause.
Usage : python dorm_report.py <archive> [<archive> ...]"""
import gzip, re, sys, statistics

ITEMS = {"stone-furnace": "four", "burner-mining-drill": "foreuse"}


def load(path):
    f = path.rstrip("/\\") + "/benchmark.log.gz"
    return gzip.open(f, "rt", encoding="utf-8", errors="replace").read().split("\n")


def causes(fl):
    c = []
    m = re.search(r"plan=(-?\d+)", fl)
    if m and int(m.group(1)) > 0:
        c.append("reserve plan directeur")
    m = re.search(r"reserve marche (\d+)", fl)
    if m and int(m.group(1)) > 0:
        c.append("reserve marche (tache prise)")
    m = re.search(r"registre=(\d+)/16", fl)
    if m and int(m.group(1)) >= 16:
        c.append("plafond registre fours")
    m = re.search(r"sites_viables\{([^}]*)\}", fl)
    sites = sum(int(x.split("=")[1]) for x in m.group(1).split()) if m else -1
    m = re.search(r"avant-postes (\d+)\(agrandissables (\d+), attente (\d+), pleins (\d+), meurtriers (\d+)", fl)
    n, ext, hold, full, leth = (int(x) for x in m.groups()) if m else (0, 0, 0, 0, 0)
    if sites == 0 and ext == 0:
        c.append("aucun site viable ni avant-poste agrandissable")
    if ext == 0 and (hold or leth):
        c.append("danger/attente (%d attente, %d meurtriers)" % (hold, leth))
    m = re.search(r"taches_avec_l_objet\(libres (\d+), prises (\d+)\)", fl)
    if m and int(m.group(1)) > 0:
        c.append("tache ouverte non prise")
    m = re.search(r"PNJ (\d+) inactifs (\d+)", fl)
    if m and int(m.group(1)) > 0 and int(m.group(2)) == 0:
        c.append("tous les PNJ occupes")
    elif m and int(m.group(2)) > 0:
        c.append("%d PNJ inactifs" % int(m.group(2)))
    return c or ["non classe"]


def report(path):
    lines = load(path)
    name = path.rstrip("/\\").split("/")[-1].split("\\")[-1]
    print("=" * 100)
    print(name)
    for item, label in ITEMS.items():
        etat = []
        take = []
        add = []
        for l in lines:
            if "[FO-DORM]" not in l or item not in l:
                continue
            m = re.search(r"\[FO-DORM\] t([\d.]+) ETAT \S+ au_stock=(\d+) age_median=([\d.]+) plus_de_10min=(\d+) \| cohortes \[(.*?)\] \| (.*)", l)
            if m:
                etat.append((float(m.group(1)), int(m.group(2)), float(m.group(3)), int(m.group(4)), m.group(5), m.group(6)))
                continue
            m = re.search(r"\[FO-DORM\] t([\d.]+) TAKE \S+ x(\d+) age=([\d.]+) min origine=(\S+) pris par (.*)", l)
            if m:
                take.append((float(m.group(1)), int(m.group(2)), float(m.group(3)), m.group(4), m.group(5)))
                continue
            m = re.search(r"\[FO-DORM\] t([\d.]+) ADD \S+ x(\d+) origine=(.*)", l)
            if m:
                add.append((float(m.group(1)), int(m.group(2)), m.group(3)))
        if not etat:
            print("  %s : aucune ligne ETAT" % label)
            continue
        old = [e[3] for e in etat if e[0] >= 10]
        stock = [e[1] for e in etat if e[0] >= 10]
        ages = []
        for _, k, a, _, _ in take:
            ages += [a] * k
        for e in etat:
            pass
        print("  %s : ajoutes %d ; consommes %d ; age median a la prise %.1f min ; au stock a 60 min %d ; plus de 10 min : moyenne %.1f, max %d, minutes avec >4 : %d/%d"
              % (label, sum(a[1] for a in add), sum(t[1] for t in take), statistics.median(ages) if ages else 0, etat[-1][1],
                 statistics.mean(old) if old else 0, max(old) if old else 0, sum(1 for o in old if o > 4), len(old)))
        # age median des objets presents (echantillons ETAT), pondere par le nombre
        present = [e[2] for e in etat if e[1] > 0 and e[0] >= 10]
        print("     age median des objets au stock (mediane des minutes non vides) %.1f min" % (statistics.median(present) if present else 0))
        # causes : echantillons ou plus_de_10min > 0
        hist = {}
        for e in etat:
            if e[3] > 0:
                for c in causes(e[5]):
                    hist[c] = hist.get(c, 0) + 1
        tot = sum(1 for e in etat if e[3] > 0)
        print("     minutes avec des %s de plus de 10 min : %d/%d" % (label, tot, len(etat)))
        for c in sorted(hist, key=lambda k: -hist[k]):
            print("       - %s : %d minute(s)" % (c, hist[c]))
        # origines des cohortes vieilles
        org = {}
        for e in etat:
            for part in e[4].split(" ; "):
                m = re.match(r"(\d+)x (\d+)min (.*)", part)
                if m and int(m.group(2)) > 10:
                    k = re.sub(r"\d+", "#", m.group(3))
                    org[k] = org.get(k, 0) + 1
        for k in sorted(org, key=lambda k: -org[k])[:6]:
            print("       origine ancienne : %s (%d echantillons)" % (k, org[k]))
        bad = [e for e in etat if e[3] > 4][:3]
        for e in bad:
            print("       LIGNE t%.0f : stock %d, >10min %d, cohortes [%s] | %s" % (e[0], e[1], e[3], e[4][:200], e[5][:330]))


for p in sys.argv[1:]:
    report(p)
