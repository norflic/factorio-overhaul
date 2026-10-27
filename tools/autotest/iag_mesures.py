# Lot IA-G (27/10) : lecture des bancs du cerveau général (scénarios iag-partie, iag-jetable ; archives de banc.py).
# Par faction : décisions [FO-CERVEAU] (minute, technologie, valeur, coût, score), recherches terminées, paliers,
# ressources clés et besoins bruts de la première décision, projets d'extraction ouverts (minute), soldats et PNJ sans
# tâche (relevés par minute d'IA3-DIAG : part « inactif » des PNJ-minutes, de 0 à 10 min et de 10 à la fin).
# Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/iag_mesures.py <archive> [<archive> ...]
import gzip
import os
import re
import sys

RE_DEC = re.compile(r"\[FO-CERVEAU\] (\w+) : but '([^']+)' valeur (\d+) cout (\d+) score (\d+)(.*) a ([0-9.]+) min$")
RE_KEY = re.compile(r"ressources cles : plus demandee (\S+), combustible (\S+), ordre (\S+), sans besoin \[([^\]]*)\], besoins bruts \{([^}]*)\}")
RE_NONE = re.compile(r"\[FO-CERVEAU\] (\w+) : aucune technologie payable")
RE_DONE = re.compile(r"\[FO-IA3C\] (\w+) : recherche '([^']+)' terminee a ([0-9.]+) min")
RE_PAL = re.compile(r"\[FO-IA3C\] (\w+) : palier (\d) atteint a ([0-9.]+) min")
RE_PROJ = re.compile(r"\[FO-IA3C\] (\w+) : projet ouvert '(extraction:\w+)'.* a ([0-9.]+) min")
RE_MIN = re.compile(r"\] minute (\d+) \| (\w+) tech (\d+) soldats (\d+) pnj (\d+)/(\d+) \| taches \{([^}]*)\}")
RE_CAT = re.compile(r"\[FO-CERVEAU\] catalogue lu dans les prototypes : (.*)$")
RE_BILAN = re.compile(r"\[FO-IAG-\w+\] (BILAN.*|ECHEC.*)$")


def opener(d):
    for n in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(d, n)
        if os.path.exists(p):
            if n.endswith(".gz"):
                return gzip.open(p, "rt", encoding="utf-8", errors="replace")
            return open(p, encoding="utf-8", errors="replace")
    raise OSError("benchmark.log absent : " + d)


def kv(s):
    out = {}
    for part in s.split():
        if ":" in part:
            k, v = part.rsplit(":", 1)
            try:
                out[k] = float(v)
            except ValueError:
                pass
    return out


def lire(d):
    fac = {}
    cat = None
    bilan = []

    def F(k):
        return fac.setdefault(k, {"dec": [], "done": [], "pal": {}, "key": None, "proj": [], "none": 0,
                                  "idle": [0.0, 0.0, 0.0, 0.0], "soldats": None, "pnj": None})
    with opener(d) as f:
        for line in f:
            line = line.rstrip("\n")
            m = RE_DEC.search(line)
            if m:
                k = F(m.group(1))
                k["dec"].append((float(m.group(7)), m.group(2), int(m.group(3)), int(m.group(4)), int(m.group(5))))
                mk = RE_KEY.search(line)
                if mk and k["key"] is None:
                    k["key"] = mk.groups()
                continue
            m = RE_NONE.search(line)
            if m:
                F(m.group(1))["none"] += 1
                continue
            m = RE_DONE.search(line)
            if m:
                F(m.group(1))["done"].append((float(m.group(3)), m.group(2)))
                continue
            m = RE_PAL.search(line)
            if m:
                F(m.group(1))["pal"][int(m.group(2))] = float(m.group(3))
                continue
            m = RE_PROJ.search(line)
            if m:
                F(m.group(1))["proj"].append((float(m.group(3)), m.group(2)))
                continue
            m = RE_MIN.search(line)
            if m and m.group(2) != "player":
                k = F(m.group(2))
                minute = int(m.group(1))
                t = kv(m.group(7))
                n = int(m.group(5))
                idle = t.get("inactif", 0.0)
                i = 0 if minute <= 10 else 2
                k["idle"][i] += idle
                k["idle"][i + 1] += n
                k["soldats"], k["pnj"] = int(m.group(4)), n
                continue
            m = RE_CAT.search(line)
            if m:
                cat = m.group(1)
                continue
            m = RE_BILAN.search(line)
            if m:
                bilan.append(m.group(1))
    return cat, fac, bilan


def main():
    for d in sys.argv[1:]:
        cat, fac, bilan = lire(d)
        print("=" * 100)
        print(os.path.basename(os.path.normpath(d)))
        print("  catalogue : %s" % cat)
        for b in bilan:
            print("  " + b)
        for key in sorted(fac):
            k = fac[key]
            if not k["dec"] and not k["done"]:
                continue
            pal = " ".join("p%d %.1f" % (i, k["pal"][i]) for i in sorted(k["pal"]))
            i1 = 100.0 * k["idle"][0] / k["idle"][1] if k["idle"][1] else 0.0
            i2 = 100.0 * k["idle"][2] / k["idle"][3] if k["idle"][3] else 0.0
            print("  %s : %d decisions, %d terminees, paliers [%s], soldats fin %s, pnj fin %s, sans tache 0-10 min %.1f %%, 10-fin %.1f %%"
                  % (key, len(k["dec"]), len(k["done"]), pal, k["soldats"], k["pnj"], i1, i2))
            if k["key"]:
                print("    ressources cles (1re decision) : plus demandee %s, combustible %s, ordre %s, sans besoin [%s], besoins {%s}" % k["key"])
            print("    choix : " + " > ".join("%s (%.1f)" % (d_[1], d_[0]) for d_ in k["dec"][:12]))
            print("    extraction ouverte : " + ", ".join("%s %.1f" % (p[1].split(":")[1], p[0]) for p in k["proj"][:8]))
            if k["none"]:
                print("    pensees sans technologie payable : %d" % k["none"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
