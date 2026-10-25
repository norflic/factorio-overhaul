# Lot IA3-DIAG : lit les journaux des bancs ia3d-* (benchmark.log.gz archivés par ia3d_run.py) et publie, par équipe :
#  - la chronologie des recherches et des objectifs (lignes [FO-TEAM] du mod) ;
#  - le temps des PNJ par activité (relevés [FO-IA3D-*] : PNJ-minutes), par fenêtre de temps ;
#  - les minutes où des PNJ attendent au QG alors que des tâches restent libres (lignes d'état du mod) ;
#  - la recherche « possible » : minute où le travail des PNJ restés immobiles au QG aurait suffi à fabriquer à la
#    main les packs des recherches 1 à 3 (temps de fabrication vanilla), les plaques étant au coffre.
# Usage : py -3.9 ia3d_analyse.py <dossier bancs> [noms...] ; écrit aussi <dossier bancs>/<nom>/chrono.csv
import csv
import gzip
import os
import re
import sys

# Travail de fabrication À LA MAIN des packs (secondes, recettes vanilla, intermédiaires compris) :
# rouge 5 + engrenage 0,5 ; vert 6 + bras 2,25 + tapis 0,5 ; militaire (10 + perforant 3 + chargeur 1 + grenade 8 + 2 murs 1) / 2
PACK_S = {"automation-science-pack": 5.5, "logistic-science-pack": 8.75, "military-science-pack": 11.5}
RESEARCH = {
    1: {"automation-science-pack": 30},
    2: {"automation-science-pack": 50, "logistic-science-pack": 40},
    3: {"automation-science-pack": 80, "logistic-science-pack": 60, "military-science-pack": 30},
}
# Fer et cuivre consommés par les packs (plaques, acier compté en fer)
PACK_FE = {"automation-science-pack": 2, "logistic-science-pack": 5.5, "military-science-pack": 7}
PACK_CU = {"automation-science-pack": 1, "logistic-science-pack": 1.5, "military-science-pack": 2.5}

NAMES = {"Scarlet": "scarlet", "Azure": "azure", "Emerald": "emerald", "Amber": "amber"}
WINDOWS = [(0, 10), (10, 30), (30, 60), (60, 120)]

RE_MIN = re.compile(r"\[FO-IA3D-[A-Z]+\] minute (\d+) \| (\w+) tech (\d+) soldats (\d+) pnj (\d+)/(\d+) \| taches \{([^}]*)\} \| activite \{([^}]*)\} \| fab \{([^}]*)\} \| stock ([^|]*)\| produit ([^|]*)\| livre ([^|]*)\| vitesse_fab \+([0-9.]+)")
RE_RES = re.compile(r"\[FO-TEAM\] (\w+) : recherche niveau (\d) payee en packs a ([0-9.]+) min")
RE_GOAL = re.compile(r"\[FO-TEAM\] (\w+) : objectif atteint '(\w+)' a ([0-9.]+) min")
RE_DEFER = re.compile(r"\[FO-TEAM\] (\w+) : objectif '(\w+)' mis de cote")
RE_WARMIN = re.compile(r"\[FO-WAR\] ([0-9.]+) min \|")
RE_FACT = re.compile(r"remote\.lua:\d+:   (\w+) \w+ \[")
RE_EQ = re.compile(r"equipe : objectif (\S+) \| manque \[([^\]]*)\] \| stock .*? \| taches (\d+) libres (\d+) prises \| ouvriers \{([^}]*)\}")


def kv(s, num=float):
    out = {}
    for part in s.split():
        if ":" in part:
            k, v = part.rsplit(":", 1)
        elif "=" in part:
            k, v = part.split("=", 1)
        else:
            continue
        try:
            out[k] = num(v)
        except ValueError:
            pass
    return out


def parse(path):
    rows, research, goals, defers, status = [], {}, {}, {}, {}
    cur_min, cur_fac = None, None
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = RE_MIN.search(line)
            if m:
                r = {"min": int(m.group(1)), "team": m.group(2), "tech": int(m.group(3)), "soldats": int(m.group(4)),
                     "pnj": int(m.group(5)), "max": int(m.group(6)), "taches": kv(m.group(7)), "act": kv(m.group(8)),
                     "fab": kv(m.group(9)), "stock": kv(m.group(10), int), "prod": kv(m.group(11), int),
                     "livre": kv(m.group(12), int), "vfab": float(m.group(13))}
                rows.append(r)
                continue
            m = RE_RES.search(line)
            if m:
                research.setdefault(m.group(1), {})[int(m.group(2))] = float(m.group(3))
                continue
            m = RE_GOAL.search(line)
            if m:
                goals.setdefault(m.group(1), []).append((float(m.group(3)), m.group(2)))
                continue
            m = RE_DEFER.search(line)
            if m:
                defers.setdefault(m.group(1), []).append(m.group(2))
                continue
            m = RE_WARMIN.search(line)
            if m:
                cur_min = int(round(float(m.group(1))))
                cur_fac = None
                continue
            m = RE_FACT.search(line)
            if m and m.group(1) in NAMES:
                cur_fac = NAMES[m.group(1)]
                continue
            m = RE_EQ.search(line)
            if m and cur_min is not None:
                team = "player" if "equipe du joueur" in line else cur_fac
                if team:
                    status[(team, cur_min)] = {"goal": m.group(1), "manque": m.group(2), "libres": int(m.group(3)),
                                               "prises": int(m.group(4)), "ouvriers": kv(m.group(5), int)}
    return rows, research, goals, defers, status


def possible(rows_t):
    """Minute où l'attente au QG cumulée couvre le travail des packs (recherches 1 à 3, à la main, à vitesse 1 + bonus)."""
    need, cum_need, out = 0.0, [], {}
    for lvl in (1, 2, 3):
        need += sum(n * PACK_S[p] for p, n in RESEARCH[lvl].items()) / 60.0
        cum_need.append((lvl, need))
    acc = 0.0
    fe_need = 0
    for r in rows_t:
        acc += r["act"].get("arret-qg", 0.0) * (1 + r["vfab"])
        for lvl, w in cum_need:
            if lvl in out:
                continue
            fe = sum(n * PACK_FE[p] for l in range(1, lvl + 1) for p, n in RESEARCH[l].items())
            if acc >= w and r["stock"].get("fer", 0) + 0 >= 0 and r["prod"].get("fer", 0) >= fe:
                out[lvl] = r["min"]
    return out, cum_need


def window_avg(rows_t, a, b, key, sub=None):
    sel = [r for r in rows_t if a < r["min"] <= b]
    if not sel:
        return None
    if sub is None:
        return sum(r[key] for r in sel) / len(sel)
    return sum(r[key].get(sub, 0.0) for r in sel) / len(sel)


def report(name, path, out_dir):
    rows, research, goals, defers, status = parse(path)
    teams = []
    for r in rows:
        if r["team"] not in teams:
            teams.append(r["team"])
    print(f"### {name}")
    with open(os.path.join(out_dir, "chrono.csv"), "w", newline="", encoding="utf-8") as fo:
        w = csv.writer(fo, delimiter=";")
        w.writerow(["minute", "equipe", "tech", "pnj", "inactif", "service", "craft", "smelt", "mine", "extend", "build",
                    "fond", "fab", "fab_recherche", "marche", "arret_qg", "arret_loin", "mine_main", "fer_stock", "cuivre_stock",
                    "rouge", "vert", "mil", "fer_produit", "objectif", "manque", "libres", "prises"])
        for r in rows:
            st = status.get((r["team"], r["min"]), {})
            t = r["taches"]
            fond = sum(v for k, v in t.items() if "(fond)" in k)
            w.writerow([r["min"], r["team"], r["tech"], r["pnj"], round(t.get("inactif", 0), 2), round(t.get("service", 0), 2),
                        round(t.get("craft", 0), 2), round(t.get("smelt", 0), 2), round(t.get("mine", 0), 2),
                        round(t.get("extend", 0), 2), round(t.get("build", 0), 2), round(fond, 2),
                        round(r["act"].get("fab", 0), 2), round(r["fab"].get("recherche", 0), 2),
                        round(r["act"].get("marche", 0) + r["act"].get("marche-qg", 0), 2), round(r["act"].get("arret-qg", 0), 2),
                        round(r["act"].get("arret-loin", 0), 2), round(r["act"].get("mine", 0), 2),
                        r["stock"].get("fer", 0), r["stock"].get("cuivre", 0), r["stock"].get("rouge", 0), r["stock"].get("vert", 0),
                        r["stock"].get("mil", 0), r["prod"].get("fer", 0), st.get("goal", ""), st.get("manque", ""),
                        st.get("libres", ""), st.get("prises", "")])
    for team in teams:
        rt = [r for r in rows if r["team"] == team]
        res = research.get(team, {})
        pos, cum = possible(rt)
        last = rt[-1]
        print(f"- {team} : pnj fin {last['pnj']}/{last['max']}, tech fin {last['tech']}, soldats fin {last['soldats']}")
        print("    recherches mesurees : " + ", ".join(f"R{k} {v:.1f} min" for k, v in sorted(res.items())) +
              " | possibles (attente au QG employee aux packs) : " + ", ".join(f"R{k} {v} min" for k, v in sorted(pos.items())))
        g = goals.get(team, [])
        print("    objectifs : " + ", ".join(f"{k} {t:.1f}" for t, k in sorted(g)))
        if defers.get(team):
            print("    mis de cote : " + ", ".join(defers[team]))
        for a, b in WINDOWS:
            n = window_avg(rt, a, b, "pnj")
            if n is None:
                continue
            def av(key, sub):
                v = window_avg(rt, a, b, key, sub)
                return v or 0.0
            fab = av("act", "fab")
            fab_r = av("fab", "recherche")
            line = (f"    {a:>3}-{b:<3} min : pnj {n:4.1f} | taches : inactif {av('taches', 'inactif'):4.2f} service {av('taches', 'service'):4.2f} "
                    f"craft {av('taches', 'craft'):4.2f} smelt {av('taches', 'smelt'):4.2f} mine {av('taches', 'mine'):4.2f} "
                    f"extend {av('taches', 'extend'):4.2f} build {av('taches', 'build'):4.2f} | corps : fab {fab:4.2f} (recherche {fab_r:4.2f}) "
                    f"marche {av('act', 'marche') + av('act', 'marche-qg'):4.2f} arret-qg {av('act', 'arret-qg'):4.2f} "
                    f"arret-loin {av('act', 'arret-loin'):4.2f} mine {av('act', 'mine'):4.2f}")
            print(line)
            cats = {}
            for r in rt:
                if a < r["min"] <= b:
                    for k, v in r["fab"].items():
                        cats[k] = cats.get(k, 0.0) + v
            nmin = max(1, len([r for r in rt if a < r["min"] <= b]))
            tk = {}
            for r in rt:
                if a < r["min"] <= b:
                    for k, v in r["taches"].items():
                        tk[k] = tk.get(k, 0.0) + v
            print("              fab par objet final (PNJ) : " + " ".join(f"{k} {v / nmin:.2f}" for k, v in sorted(cats.items(), key=lambda x: -x[1])[:7])
                  + " | taches (PNJ) : " + " ".join(f"{k} {v / nmin:.2f}" for k, v in sorted(tk.items(), key=lambda x: -x[1])[:9]))
        # minutes avec PNJ immobiles au QG ET tâches libres au tableau
        both = 0
        free_sum = 0
        for r in rt:
            st = status.get((team, r["min"]))
            if st and st["libres"] > 0 and r["act"].get("arret-qg", 0) >= 0.5:
                both += 1
                free_sum += st["libres"]
        print(f"    minutes avec >= 0,5 PNJ immobile au QG ET des taches libres : {both} sur {len(rt)}"
              + (f" (taches libres en moyenne {free_sum / both:.1f})" if both else ""))
        # débit de fer (plaques produites par la force) par fenêtre
        prods = {r["min"]: r["prod"].get("fer", 0) for r in rt}
        parts = []
        for a, b in WINDOWS:
            if a in prods or a == 0:
                pa = prods.get(a, 0)
                if b in prods:
                    parts.append(f"{a}-{b} {(prods[b] - pa) / (b - a):.0f}/min")
        print("    fer produit : " + ", ".join(parts) + f" | stock fer fin {last['stock'].get('fer', 0)}, cuivre {last['stock'].get('cuivre', 0)}")
    print()


def main():
    base = sys.argv[1]
    names = sys.argv[2:] or sorted(d for d in os.listdir(base) if os.path.isdir(os.path.join(base, d)))
    for n in names:
        p = os.path.join(base, n, "benchmark.log.gz")
        if os.path.exists(p):
            report(n, p, os.path.join(base, n))


if __name__ == "__main__":
    main()
