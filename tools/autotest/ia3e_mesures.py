# Lot IA3-e (27/10) : résumé d'une ou plusieurs archives du banc ia3e-usine (banc.py) : par faction, paliers de recherche
# (K1), poteau moyen (electric-energy-distribution-1), modules demandés et finis (minute), centrale, critères A4 publiés
# par le scénario (modules sans PNJ, part à la main, tournées), QG détruit, soldats à 60 min.
# Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/ia3e_mesures.py <archive> [<archive> ...]
import gzip
import os
import re
import sys

RE_PAL = re.compile(r"\[FO-IA3C\] (\w+) : palier (\d) atteint a ([0-9.]+) min")
RE_TECH = re.compile(r"\[FO-IA3C\] (\w+) : recherche '([^']+)' terminee a ([0-9.]+) min")
RE_DEM = re.compile(r"\[FO-IA3E\] (\w+) : module '([^']+)' DEMANDE .* a ([0-9.]+) min")
RE_FINI = re.compile(r"\[FO-IA3E\] (\w+) : module '([^']+)' FINI .* a ([0-9.]+) min")
RE_REF = re.compile(r"\[FO-IA3E\] (\w+) : module '([^']+)' REFUSE par le plan directeur : (.*) a ([0-9.]+) min")
RE_PLANT = re.compile(r"\[FO-IA3E\] (\w+) : centrale (FINIE|REFUSEE[^a]*)a ([0-9.]+) min")
RE_CRIT = re.compile(r"CRITERES (\w+) \| modules produisant 5 min sans PNJ a 45 min : (\d+).*\((\d+) % a la main.*tournees a pied 30-90 min : (\d+) %.*minage a la main (\d+) %")
RE_DEAD = re.compile(r"qg detruit tick (\d+) (\w+) par (\w+)")
RE_WAR = re.compile(r"\[FO-IA3E-USINE\] SANS PNJ (\w+) : (\d+) module\(s\) produisent 5 min sur (\d+) finis : (.*)")


def parse(path):
    teams = {}

    def t(k):
        return teams.setdefault(k, {"pal": {}, "eed1": None, "dem": [], "fini": [], "ref": [], "plant": None, "crit": None,
                                    "dead": None, "sanspnj": None})

    with gzip.open(os.path.join(path, "benchmark.log.gz"), "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = RE_PAL.search(line)
            if m:
                t(m.group(1))["pal"].setdefault(int(m.group(2)), float(m.group(3)))
                continue
            m = RE_TECH.search(line)
            if m and m.group(2) == "electric-energy-distribution-1":
                t(m.group(1))["eed1"] = float(m.group(3))
                continue
            m = RE_DEM.search(line)
            if m:
                t(m.group(1))["dem"].append((m.group(2), float(m.group(3))))
                continue
            m = RE_FINI.search(line)
            if m:
                t(m.group(1))["fini"].append((m.group(2), float(m.group(3))))
                continue
            m = RE_REF.search(line)
            if m:
                t(m.group(1))["ref"].append((m.group(2), m.group(3), float(m.group(4))))
                continue
            m = RE_PLANT.search(line)
            if m:
                t(m.group(1))["plant"] = (m.group(2).strip(), float(m.group(3)))
                continue
            m = RE_CRIT.search(line)
            if m:
                t(m.group(1))["crit"] = (int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)))
                continue
            m = RE_DEAD.search(line)
            if m:
                t(m.group(2))["dead"] = (int(m.group(1)) / 3600.0, m.group(3))
                continue
            m = RE_WAR.search(line)
            if m:
                t(m.group(1))["sanspnj"] = (int(m.group(2)), int(m.group(3)), m.group(4).strip())
    return teams


def fmt(x):
    return "-" if x is None else f"{x:.1f}"


def main():
    for path in sys.argv[1:]:
        print(f"== {os.path.basename(path.rstrip('/'))}")
        teams = parse(path)
        for k in sorted(teams):
            d = teams[k]
            pal = " ".join(f"p{i}={fmt(d['pal'].get(i))}" for i in (1, 2, 3))
            dem = ", ".join(f"{p}@{fmt(x)}" for p, x in d["dem"])
            fin = ", ".join(f"{p}@{fmt(x)}" for p, x in d["fini"])
            crit = d["crit"]
            c = f"sansPNJ {crit[0]} | main {crit[1]} % | tournees {crit[2]} % | minage {crit[3]} %" if crit else "criteres -"
            dead = f"QG DETRUIT a {d['dead'][0]:.1f} min ({d['dead'][1]})" if d["dead"] else "vivante"
            plant = f"centrale {d['plant'][0]} a {fmt(d['plant'][1])}" if d["plant"] else "centrale -"
            print(f"  {k:8s} {pal} | poteau moyen {fmt(d['eed1'])} | {plant} | {dead}")
            print(f"           demandes [{dem}] | finis [{fin}] | refus {len(d['ref'])}")
            print(f"           {c}" + (f" | sans PNJ : {d['sanspnj'][2]}" if d["sanspnj"] else ""))


if __name__ == "__main__":
    main()
