# Lot IA3-b « personne n'attend, personne n'arrache » : critères K3, K4, K5 (docs/IA3_CERVEAU.md §6.1) et morts par heure
# (F239), par équipe, lus dans les journaux des bancs ia3d-* (avant, réglage éteint) et ia3b-* (après), archivés par
# tools/autotest/ia3d_run.py (benchmark.log.gz).
#   K3 : PNJ sans tâche (relevés de l'interface « fo-ia1 », lignes minute du scénario) : part de 0 à 10 min et de 30 à
#        90 min (visé : <= 20 % et <= 15 %) ;
#   K4 : échecs « stock » de la dernière ligne d'état de l'équipe (« echecs {…} » ; visé : 0), plus « preempte » ;
#   K5 : minutes où au moins 0,5 PNJ est immobile au QG (corps) ET des tâches restent libres au tableau (ligne d'état
#        du mod de la même minute ; visé : <= 5 sur 119) ;
#   morts : lignes « PNJ <id> tue » du mod, par heure de jeu ; lignes [FO-IA3B] (préemptions, réservations perdues).
# Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/ia3b_mesures.py <dossier bancs> [noms...]
import gzip
import os
import re
import sys

RE_MIN = re.compile(r"\[FO-IA3[A-Z]-[A-Z]+\] minute (\d+) \| (\w+) tech (\d+) soldats (\d+) pnj (\d+)/(\d+) \| taches \{([^}]*)\} \| activite \{([^}]*)\}")
RE_WARMIN = re.compile(r"\[FO-WAR\] ([0-9.]+) min \|")
RE_FACT = re.compile(r"remote\.lua:\d+:   (\w+) \w+ \[")
RE_EQ = re.compile(r"equipe : objectif (\S+) \| manque \[[^\]]*\] \| stock .*? \| taches (\d+) libres (\d+) prises \|.*?\| echecs \{([^}]*)\}")
RE_DEAD = re.compile(r"\[FO-TEAM\] (\w+) : PNJ \d+ tue \(([^)]*)\)")
RE_IA3B = re.compile(r"\[FO-IA3B\] (\w+) : (.*)")
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
    rows, status, dead, ia3b = [], {}, {}, {}
    cur_min, cur_fac = None, None
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = RE_MIN.search(line)
            if m:
                rows.append({"min": int(m.group(1)), "team": m.group(2), "pnj": int(m.group(5)),
                             "taches": kv(m.group(7)), "act": kv(m.group(8))})
                continue
            m = RE_DEAD.search(line)
            if m:
                dead.setdefault(m.group(1), []).append(m.group(2))
                continue
            m = RE_IA3B.search(line)
            if m:
                kind = "preemption" if "preemption" in m.group(2) else ("disparu" if "disparu" in m.group(2) else "autre")
                d = ia3b.setdefault(m.group(1), {})
                d[kind] = d.get(kind, 0) + 1
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
    return rows, status, dead, ia3b


def share(rows, a, b):
    sel = [r for r in rows if a < r["min"] <= b and r["pnj"] > 0]
    if not sel:
        return None
    idle = sum(r["taches"].get("inactif", 0.0) for r in sel)
    n = sum(r["pnj"] for r in sel)
    return 100.0 * idle / n if n else None


def report(name, path):
    rows, status, dead, ia3b = parse(path)
    teams = []
    for r in rows:
        if r["team"] not in teams:
            teams.append(r["team"])
    print(f"### {name}")
    for team in teams:
        rt = [r for r in rows if r["team"] == team]
        k3a, k3b = share(rt, 0, 10), share(rt, 30, 90)
        # K5 (corps, mesure d'IA3-DIAG) : compte aussi les gardes du coffre et les PNJ qui prennent ou déposent au coffre ;
        # K5t (tâches) : au moins 0,5 PNJ SANS tâche (relevés « fo-ia1 » de la minute) ET des tâches libres.
        k5, k5t = 0, 0
        for r in rt:
            st = status.get((team, r["min"]))
            if st and st["libres"] > 0 and r["act"].get("arret-qg", 0) >= 0.5:
                k5 += 1
            if st and st["libres"] > 0 and r["taches"].get("inactif", 0) >= 0.5:
                k5t += 1
        last = None
        for (t, mn), st in sorted(status.items(), key=lambda x: x[0][1]):
            if t == team:
                last = st
        fails = last["echecs"] if last else {}
        hours = max(1e-9, (rt[-1]["min"] if rt else 0) / 60.0)
        d = dead.get(team, [])
        enemy = sum(1 for c in d if "/enemy:" in c)
        x = ia3b.get(team, {})
        print(f"- {team} : K3 inactifs 0-10 {k3a if k3a is None else round(k3a, 1)} %, 30-90 {k3b if k3b is None else round(k3b, 1)} % | "
              f"K4 echecs stock {fails.get('stock', 0)} (preempte {fails.get('preempte', 0)} ; tous {fails}) | "
              f"K5 {k5} min sur {len(rt)} (corps ; par les taches {k5t}) | morts {len(d)} ({enemy} par les ennemis), {len(d) / hours:.1f} par heure | "
              f"[FO-IA3B] preemptions {x.get('preemption', 0)}, reservations perdues {x.get('disparu', 0)} | pnj fin {rt[-1]['pnj'] if rt else '?'}")
    print()


def main():
    base = sys.argv[1]
    names = sys.argv[2:] or sorted(d for d in os.listdir(base) if os.path.isdir(os.path.join(base, d)))
    for n in names:
        p = os.path.join(base, n, "benchmark.log.gz")
        if os.path.exists(p):
            report(n, p)


if __name__ == "__main__":
    main()
