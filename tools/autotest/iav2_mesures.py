# Lot IA-V2 (27/10) : critères de la section IA3 (docs/IA3_CERVEAU.md §6.1) AVANT / APRÈS, lus dans les journaux des
# parties de mesure (scénarios ia3d-* sur main, ia3c-* sur la branche ; benchmark.log.gz archivé par banc.py).
# Réunit les lectures d'ia3c_compare.py (paliers, fer II, soldats, inactifs, projets) et d'ia3b_mesures.py (échecs
# « stock », immobiles au QG, morts), et ajoute :
#   K3b (APPROCHÉ) : part des PNJ-minutes sur des tâches du CERVEAU (ni inactif, ni fond) de 30 à 90 min ; part du fond
#        (« investissements par défaut », visé ≤ 20 %). La conception demande « produit consommé dans les 15 min » : le
#        journal ne le dit pas ; l'approximation est écrite telle quelle dans le rapport ;
#   K6 : PNJ-minutes de fabrication de packs (catégorie « recherche » des relevés « fab ») pendant les minutes où le
#        projet de recherche du cerveau est BLOQUÉ (impayable) ; avant (ancien cerveau) : packs fabriqués après le
#        dernier niveau payé (même lecture qu'ia3a_compare.py, en PNJ-minutes de fabrication) ;
#   K9 : faction anéantie (dernière minute relevée) avant 60 min ;
#   K12 : « fer II » (médiane) et factions à 0 soldat à 60 min.
# Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/iav2_mesures.py --avant <archives> --apres <archives>
import gzip
import os
import re
import statistics
import sys

RE_PAL = re.compile(r"\[FO-IA3C\] (\w+) : palier (\d) atteint a ([0-9.]+) min")
RE_IRON2 = re.compile(r"\[FO-TEAM\] (\w+) : objectif atteint 'iron2' a ([0-9.]+) min")
RE_RES = re.compile(r"\[FO-TEAM\] (\w+) : recherche niveau (\d) payee en packs a ([0-9.]+) min")
RE_TECH = re.compile(r"\[FO-IA3C\] (\w+) : recherche '([^']+)' terminee a ([0-9.]+) min")
RE_MIN = re.compile(r"\[FO-IA(?:3[A-Z]|G)-[A-Z]+\] minute (\d+) \| (\w+) tech (\d+) soldats (\d+) pnj (\d+)/(\d+) \| "
                    r"taches \{([^}]*)\} \| activite \{([^}]*)\} \| fab \{([^}]*)\}")
RE_PROJ = re.compile(r"\[FO-IA3C\] (\w+) minute (\d+) \| actifs (\d+) productifs (\d+) pris (\d+) bloques (\d+) K (\d+)"
                     r".*\| projets \{([^}]*)\}")
RE_WARMIN = re.compile(r"\[FO-WAR\] ([0-9.]+) min \|")
RE_FACT = re.compile(r"remote\.lua:\d+:   (\w+) \w+ \[")
RE_EQ = re.compile(r"equipe : objectif (\S+) \| manque \[[^\]]*\] \| stock .*? \| taches (\d+) libres (\d+) prises \|.*?"
                   r"\| echecs \{([^}]*)\}")
RE_DEAD = re.compile(r"\[FO-TEAM\] (\w+) : PNJ \d+ tue \(([^)]*)\)")
NAMES = {"Scarlet": "scarlet", "Azure": "azure", "Emerald": "emerald", "Amber": "amber"}


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


def parse(path):
    teams = {}
    status = {}
    cur_min, cur_fac = None, None

    def t(name):
        return teams.setdefault(name, {"pal": {}, "res": {}, "iron2": None, "rows": [], "proj": {}, "dead": [],
                                       "techs": []})

    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = RE_MIN.search(line)
            if m:
                t(m.group(2))["rows"].append({"min": int(m.group(1)), "soldats": int(m.group(4)), "pnj": int(m.group(5)),
                                              "taches": kv(m.group(7)), "act": kv(m.group(8)), "fab": kv(m.group(9))})
                continue
            m = RE_PROJ.search(line)
            if m:
                t(m.group(1))["proj"][int(m.group(2))] = {"actifs": int(m.group(3)), "productifs": int(m.group(4)),
                                                          "pris": int(m.group(5)), "projets": m.group(8)}
                continue
            m = RE_PAL.search(line)
            if m:
                t(m.group(1))["pal"].setdefault(int(m.group(2)), float(m.group(3)))
                continue
            m = RE_TECH.search(line)
            if m:
                t(m.group(1))["techs"].append((float(m.group(3)), m.group(2)))
                continue
            m = RE_IRON2.search(line)
            if m:
                d = t(m.group(1))
                if d["iron2"] is None:
                    d["iron2"] = float(m.group(2))
                continue
            m = RE_RES.search(line)
            if m:
                t(m.group(1))["res"].setdefault(int(m.group(2)), float(m.group(3)))
                continue
            m = RE_DEAD.search(line)
            if m:
                t(m.group(1))["dead"].append(m.group(2))
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
                    fails = {}
                    for part in m.group(4).split():
                        if ":" in part:
                            k, v = part.rsplit(":", 1)
                            fails[k] = int(v)
                    status[(team, cur_min)] = {"libres": int(m.group(2)), "prises": int(m.group(3)), "echecs": fails}
    return teams, status


def share(rows, a, b, pred):
    num = tot = 0.0
    for r in rows:
        if a <= r["min"] < b:
            for k, v in r["taches"].items():
                tot += v
                if pred(k):
                    num += v
    return None if tot == 0 else 100.0 * num / tot


def team_stats(name, d, status, last_min):
    rows = d["rows"]
    end = max([r["min"] for r in rows] or [0])
    sold60 = None
    for r in rows:
        if r["min"] <= 60:
            sold60 = r["soldats"]
    k5 = k5t = 0
    for r in rows:
        st = status.get((name, r["min"]))
        if st and st["libres"] > 0 and r["act"].get("arret-qg", 0) >= 0.5:
            k5 += 1
        # K5 « par les tâches » (lecture d'IA3-b) : au moins 0,5 PNJ SANS tâche pendant que des tâches restent libres ;
        # K5 « corps » compte aussi les gardes du coffre et les PNJ qui y prennent ou déposent.
        if st and st["libres"] > 0 and r["taches"].get("inactif", 0) >= 0.5:
            k5t += 1
    last = None
    for (tm, mn), st in sorted(status.items(), key=lambda x: x[0][1]):
        if tm == name:
            last = st
    fails = last["echecs"] if last else {}
    # K6 après : fabrication de packs pendant que la recherche est bloquée (impayable).
    waste = 0.0
    blocked_min = 0
    for r in rows:
        p = d["proj"].get(r["min"])
        if p and "recherche:bloque" in p["projets"]:
            blocked_min += 1
            waste += r["fab"].get("recherche", 0.0)
    # K6 avant (ancien cerveau) : fabrication de packs après le dernier niveau payé, si un niveau suivant n'est jamais payé.
    waste_old = None
    if d["res"] and not d["proj"]:
        last_res = max(d["res"].values())
        waste_old = sum(r["fab"].get("recherche", 0.0) for r in rows if r["min"] > last_res + 1)
    par3 = None
    if d["proj"]:
        par3 = 100.0 * sum(1 for p in d["proj"].values() if p["productifs"] >= 3) / len(d["proj"])
    return {
        "team": name, "p1": d["pal"].get(1), "p2": d["pal"].get(2), "p3": d["pal"].get(3),
        "r1": d["res"].get(1), "r2": d["res"].get(2), "r3": d["res"].get(3), "iron2": d["iron2"], "sold60": sold60,
        "k3a": share(rows, 0, 10, lambda k: k == "inactif"), "k3b": share(rows, 30, 90, lambda k: k == "inactif"),
        "util": share(rows, 30, 90, lambda k: k != "inactif" and not k.endswith("(fond)")),
        "fond": share(rows, 30, 90, lambda k: k.endswith("(fond)")),
        "k4": fails.get("stock", 0), "k5": k5, "k5t": k5t, "k5n": len(rows),
        "k6": waste if d["proj"] else waste_old, "k6b": blocked_min, "par3": par3,
        "dead": end if end < last_min - 1 else None, "morts": len(d["dead"]), "techs": len(d["techs"]),
    }


def stats_of(path):
    teams, status = parse(path)
    last_min = max([r["min"] for d in teams.values() for r in d["rows"]] or [0])
    out = []
    for name in sorted(teams):
        d = teams[name]
        if not d["rows"]:
            continue
        out.append(team_stats(name, d, status, last_min))
    return out


def med(values):
    v = [x for x in values if x is not None]
    return statistics.median(v) if v else None


def fmt(x):
    if x is None:
        return "—"
    return f"{x:.1f}" if isinstance(x, float) else str(x)


COLS = ["p1", "p2", "p3", "r1", "r2", "r3", "iron2", "sold60", "k3a", "k3b", "util", "fond", "k4", "k5", "k5t", "k6", "par3",
        "morts", "techs", "dead"]


def group(label, archives):
    rows = []
    for a in archives:
        p = os.path.join(a, "benchmark.log.gz")
        if not os.path.exists(p):
            print(f"  {a} : benchmark.log.gz absent")
            continue
        for r in stats_of(p):
            r["bench"] = os.path.basename(a.rstrip("/\\"))
            rows.append(r)
    print(f"== {label} ({len(archives)} banc(s), {len(rows)} équipe(s))")
    print("  " + "banc".ljust(30) + "équipe".ljust(9) + "".join(c.rjust(8) for c in COLS))
    for r in rows:
        print("  " + r["bench"][:29].ljust(30) + r["team"].ljust(9) + "".join(fmt(r[c]).rjust(8) for c in COLS))
    fac = [r for r in rows if r["team"] != "player"]
    pl = [r for r in rows if r["team"] == "player"]
    never = {k: sum(1 for r in fac if r[k] is None) for k in ("p1", "p2", "p3", "r1", "r2", "r3")}
    print("  FACTIONS médianes : " + "  ".join(f"{c} {fmt(med([r[c] for r in fac]))}" for c in COLS if c not in ("dead",)))
    print(f"  jamais (sur {len(fac)}) : p1 {never['p1']} p2 {never['p2']} p3 {never['p3']} | r1 {never['r1']} r2 {never['r2']}"
          f" r3 {never['r3']} | anéanties avant 60 min : {sum(1 for r in fac if r['dead'] is not None and r['dead'] < 60)}"
          f" ; en tout : {sum(1 for r in fac if r['dead'] is not None)} | à 0 soldat à 60 min : "
          f"{sum(1 for r in fac if r['sold60'] == 0)} | K4 > 0 : {sum(1 for r in rows if (r['k4'] or 0) > 0)}"
          f" | K5 max {max([r['k5'] for r in rows] or [0])} min (par les tâches {max([r['k5t'] for r in rows] or [0])})")
    if pl:
        print("  VOTRE ÉQUIPE médianes : " + "  ".join(f"{c} {fmt(med([r[c] for r in pl]))}" for c in
                                                       ("k3a", "k3b", "util", "fond", "k4", "k5", "k5t", "morts")))
    return rows


def main():
    args = sys.argv[1:]
    groups, cur = {"avant": [], "apres": []}, None
    for a in args:
        if a in ("--avant", "--apres"):
            cur = a[2:]
        elif cur:
            groups[cur].append(a)
    print("Colonnes : p1-p3 paliers (vraies technologies, min) ; r1-r3 niveaux de l'ancien cerveau (min) ; iron2 (min) ;"
          " sold60 soldats à 60 min ; k3a / k3b PNJ inactifs (%) 0-10 et 30-90 min ; util = part des tâches du cerveau"
          " (ni inactif ni fond) 30-90 min (K3b APPROCHÉ) ; fond = part du fond 30-90 min ; k4 échecs « stock » ;"
          " k5 minutes à 0,5 PNJ ou plus immobiles au QG (corps) pendant que des tâches attendent ; k5t idem, PNJ SANS"
          " tâche ; k6 PNJ-minutes de packs jetés ; par3 = % des"
          " minutes à 3 projets productifs ou plus ; morts PNJ tués ; techs technologies finies (laboratoire du QG) ;"
          " dead = minute de l'anéantissement.")
    for k in ("avant", "apres"):
        if groups[k]:
            group(k.upper(), groups[k])


if __name__ == "__main__":
    main()
