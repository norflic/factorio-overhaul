#!/usr/bin/env python3
"""Métriques « ce n'est pas un pattern » des factions (lot IA2-0), lues dans les journaux d'un banc.

Conception : fo-logs/2026-10-24_ANALYSE/IA_ADAPTATIVE.md §B10 (M1 forme des bases, M2 diversité, M3 capitalisation).
Lignes lues (create.log puis benchmark.log de chaque dossier de banc ; graine dans seed.txt) :
  [FO-STRAT] fondation / attaque / site et [FO-SHAPE]  (script/faction/journal.lua, lot IA2-0)
  [FO-TEAM] objectif atteint, recherche payée           (script/team/team.lua)
  rapports par minute « ===== minute N » : ligne « equipe : » de chaque faction (stock, livré)

Usage :
  python -B tools/autotest/ia2_mesures.py <dossier de banc> [...]                 un groupe
  python -B tools/autotest/ia2_mesures.py --avant <d1> <d2> --apres <d3> <d4>     deux groupes comparés
  options : --json <fichier> (tout écrire), --detail (tableaux par faction)

Définitions (chiffres « proxy » dits comme tels) :
  M1 radialité   Spearman ρ entre le numéro d'ordre de construction d'un avant-poste et sa distance au QG (≥ 3
                 avant-postes connus, toutes lignes [FO-SHAPE] réunies) ;
     rondeur     √(λ1/λ2) de la covariance des positions des bâtiments (dernière ligne [FO-SHAPE]) ;
     plus proche part des sites puisés au rang 1 (le plus proche du QG parmi la réserve de la même ressource).
  M2 caractère   personnalité et traits par faction et par graine ([FO-STRAT] fondation) ;
     cadence     coefficient de variation des intervalles entre deux attaques d'une faction (≥ 3 attaques) ;
     tailles     CV des effectifs envoyés (≥ 2 attaques) ; côtés : entropie (bits) des octants d'arrivée des
                 attaques contre une même cible (≥ 2 attaques) ; 1re attaque (min) ; factions qui attaquent en
                 60 et 120 min ;
     distances   distance d'édition normalisée des 20 premières décisions (objectifs atteints, recherches,
                 attaques par cible, sites par ressource) : même faction entre graines, et factions d'une graine.
  M3 dormant     part du stock (fer, cuivre, charbon, pierre, acier ; en objets) restée au stock pendant 10 min :
                 Σ min(q sur 10 min) / Σ q, médiane de 30 à 120 min et valeur à la dernière minute ;
     croissance  livraisons (fer, cuivre, charbon, minerai) des 10 dernières minutes ÷ celles de 20 à 30 min ;
     r (proxy)   capital installé (bâtiments × coût en plaques, table COST) gagné en 10 min ÷ objets livrés
                 dans ces 10 min, médiane des fenêtres.
"""
import argparse
import json
import math
import os
import re
import statistics
import sys

KEYS = ["scarlet", "azure", "emerald", "amber"]
STOCK_ITEMS = ["iron", "copper", "coal", "stone", "steel"]
# Coût d'un bâtiment en plaques et briques équivalentes (recettes vanilla 1.1) ; inconnu : 10.
COST = {
    "burner-mining-drill": 14, "electric-mining-drill": 34, "stone-furnace": 5, "steel-furnace": 36,
    "gun-turret": 50, "iron-chest": 8, "wooden-chest": 2, "fo-faction-hq": 0, "small-electric-pole": 2,
    "assembling-machine-1": 22, "lab": 36, "transport-belt": 2, "inserter": 4, "burner-inserter": 2,
}

RX = {
    "found": re.compile(r"\[FO-STRAT\] fondation tick (\d+) (\w+) : personnalite (\w+), origine (\w+), flux (\S+), traits (.*)$"),
    # Lot IA2-a : champs ajoutés en fin de ligne (rassemblement avancé, règle, raid) ; seuil sans la virgule qui suit.
    "attack": re.compile(r"\[FO-STRAT\] attaque tick (\d+) (\w+) -> (\w+) : (\d+) soldats, depart \((-?\d+), (-?\d+)\), vise \((-?\d+), (-?\d+)\), (\d+) tuiles, octant (-?\d+), seuil ([^,\s]+)"
                        r"(?:, rassemblement (?:\((-?\d+), (-?\d+)\)|-), regle ([\w-]+)(, raid)?)?"),
    "posture": re.compile(r"\[FO-STRAT\] posture tick (\d+) (\w+) : dominante (\w+) \((-?\d+), \d+ %\).*?, raison (\S+), menace (\d+), mult (\d+), cible (\S+), raid (\S+?)(, changement)?\s*$"),
    "issue": re.compile(r"\[FO-STRAT\] issue tick (\d+) (\w+) -> (\w+) : (\w+), (\d+) envoyes, (\d+) survivants, octant (-?\d+|-)(, raid)?"),
    "site": re.compile(r"\[FO-STRAT\] site tick (\d+) (\w+) (\S+) : \((-?\d+), (-?\d+)\), (\d+) tuiles du QG, rang (\d+) sur (\d+)"),
    "shape": re.compile(r"\[FO-SHAPE\] tick (\d+) (\w+) : hq \((-?\d+), (-?\d+)\) \| batiments (\d+) \| chunks (\d+) \| centre \((-?[\d.]+), (-?[\d.]+)\) \| cov (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) \| rayon (\d+) \| avant-postes (\S+) \| noms (\S+)"),
    "goal": re.compile(r"\[FO-TEAM\] (\w+) : objectif atteint '([^']+)' a ([\d.]+) min"),
    "research": re.compile(r"\[FO-TEAM\] (\w+) : recherche niveau (\d+) payee en packs a ([\d.]+) min"),
    "minute": re.compile(r"===== minute (\d+) \(tick (\d+)\)"),
    "facline": re.compile(r"remote\.lua:\d+:\s+\S.*? \[(conqueror|technocrat|builder|balanced)\]( ANEANTIE \|)? tech \d+"),
    "team": re.compile(r"equipe : objectif .*\| stock (.*?) \| taches .*\| livre fer (\d+) cuivre (\d+) charbon (\d+) minerai (\d+)"),
}


# ---------------------------------------------------------------------------------------------------
# Outils numériques (purs, testés par tools/autotest/tests/test_ia2_mesures.py)
# ---------------------------------------------------------------------------------------------------
def ranks(values):
    order = sorted(range(len(values)), key=lambda i: values[i])
    r = [0.0] * len(values)
    i = 0
    while i < len(order):
        j = i
        while j + 1 < len(order) and values[order[j + 1]] == values[order[i]]:
            j += 1
        avg = (i + j) / 2 + 1
        for k in range(i, j + 1):
            r[order[k]] = avg
        i = j + 1
    return r


def spearman(xs, ys):
    if len(xs) < 3:
        return None
    rx, ry = ranks(xs), ranks(ys)
    mx, my = sum(rx) / len(rx), sum(ry) / len(ry)
    num = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    den = math.sqrt(sum((a - mx) ** 2 for a in rx) * sum((b - my) ** 2 for b in ry))
    return num / den if den > 0 else None


def roundness(cxx, cyy, cxy):
    """√(λ1/λ2) d'une covariance 2 × 2 (1 = rond ; grand = allongé). None si dégénérée."""
    half = (cxx + cyy) / 2
    disc = math.sqrt(max(0.0, half * half - (cxx * cyy - cxy * cxy)))
    l1, l2 = half + disc, half - disc
    if l2 <= 1e-9:
        return None
    return math.sqrt(l1 / l2)


def cv(values):
    if len(values) < 2:
        return None
    m = statistics.mean(values)
    if m == 0:
        return None
    return statistics.pstdev(values) / m


def entropy(labels):
    if not labels:
        return None
    n = len(labels)
    counts = {}
    for x in labels:
        counts[x] = counts.get(x, 0) + 1
    return abs(-sum(c / n * math.log2(c / n) for c in counts.values()))


def edit_distance(a, b):
    """Distance de Levenshtein normalisée par la plus longue des deux suites (0 = identiques)."""
    if not a and not b:
        return 0.0
    prev = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        cur = [i] + [0] * len(b)
        for j, y in enumerate(b, 1):
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (0 if x == y else 1))
        prev = cur
    return prev[len(b)] / max(len(a), len(b))


def dormant_share(series, window=10):
    """series = [(minute, {objet: quantité})] ; renvoie [(minute, part dormante)] dès la minute `window`."""
    out = []
    for i, (m, q) in enumerate(series):
        past = [s for s in series[: i + 1] if s[0] >= m - window]
        if not past or past[0][0] > m - window:
            continue
        total = sum(q.values())
        if total <= 0:
            continue
        still = sum(min(s[1].get(k, 0) for s in past) for k in q)
        out.append((m, still / total))
    return out


def median(values):
    v = [x for x in values if x is not None]
    return statistics.median(v) if v else None


# ---------------------------------------------------------------------------------------------------
# Lecture d'un banc
# ---------------------------------------------------------------------------------------------------
def parse_stock(text):
    out = {}
    for part in text.split():
        if "=" in part:
            k, v = part.split("=", 1)
            if k in STOCK_ITEMS:
                out[k] = int(v)
    return out


def read_run(folder):
    seed = None
    p = os.path.join(folder, "seed.txt")
    if os.path.exists(p):
        seed = open(p, encoding="utf-8", errors="replace").read().strip()
    run = {"folder": folder, "seed": seed or os.path.basename(folder), "factions": {k: new_faction() for k in KEYS},
           "minutes": 0}
    for name in ("create.log", "benchmark.log"):
        path = os.path.join(folder, name)
        if os.path.exists(path):
            parse_log(open(path, encoding="utf-8", errors="replace"), run, name)
    return run


def new_faction():
    return {"personality": None, "origin": None, "traits": {}, "attacks": [], "sites": [], "shapes": [], "events": [],
            "stock": [], "delivered": [], "postures": [], "issues": []}


def parse_log(lines, run, name):
    F = run["factions"]
    minute, idx = None, 0
    seen_found = set()
    for line in lines:
        m = RX["minute"].search(line)
        if m:
            minute, idx = int(m.group(1)), 0
            run["minutes"] = max(run["minutes"], minute)
            continue
        # Rapport par minute : ligne de faction (dans l'ordre des numéros), puis sa ligne « equipe : » (absente pour
        # une faction anéantie : on rattache chaque ligne d'équipe à la DERNIÈRE ligne de faction lue).
        m = RX["facline"].search(line)
        if m and minute is not None:
            idx += 1
            if m.group(2) and idx <= len(KEYS):
                f = F[KEYS[idx - 1]]
                if f.get("eliminated_min") is None:
                    f["eliminated_min"] = minute
            continue
        m = RX["team"].search(line)
        if m and minute is not None:
            if 1 <= idx <= len(KEYS):
                f = F[KEYS[idx - 1]]
                if not f["stock"] or f["stock"][-1][0] != minute:
                    f["stock"].append((minute, parse_stock(m.group(1))))
                    f["delivered"].append((minute, sum(int(m.group(i)) for i in range(2, 6))))
            continue
        m = RX["found"].search(line)
        if m:
            key = m.group(2)
            if key in F and key not in seen_found:
                seen_found.add(key)
                f = F[key]
                f["personality"], f["origin"] = m.group(3), m.group(4)
                f["traits"] = {kv.split("=")[0]: int(kv.split("=")[1]) for kv in m.group(6).split() if "=" in kv}
            continue
        m = RX["attack"].search(line)
        if m and m.group(2) in F:
            a = {"tick": int(m.group(1)), "target": m.group(3), "n": int(m.group(4)), "octant": int(m.group(10)),
                 "dist": int(m.group(9)), "jitter": m.group(11), "approach": m.group(12) is not None,
                 "rule": m.group(14), "raid": m.group(15) is not None}
            F[m.group(2)]["attacks"].append(a)
            F[m.group(2)]["events"].append((a["tick"], "att:" + a["target"]))
            continue
        m = RX["posture"].search(line)
        if m and m.group(2) in F:
            F[m.group(2)]["postures"].append({"tick": int(m.group(1)), "dominant": m.group(3), "score": int(m.group(4)),
                                             "reason": m.group(5), "threat": int(m.group(6)), "mult": int(m.group(7)),
                                             "target": m.group(8), "raid": m.group(9)})
            continue
        m = RX["issue"].search(line)
        if m and m.group(2) in F:
            F[m.group(2)]["issues"].append({"tick": int(m.group(1)), "target": m.group(3), "outcome": m.group(4),
                                           "n": int(m.group(5)), "survivors": int(m.group(6)),
                                           "octant": None if m.group(7) == "-" else int(m.group(7)), "raid": m.group(8) is not None})
            continue
        m = RX["site"].search(line)
        if m and m.group(2) in F:
            s = {"tick": int(m.group(1)), "resource": m.group(3), "dist": int(m.group(6)), "rank": int(m.group(7)),
                 "of": int(m.group(8))}
            F[m.group(2)]["sites"].append(s)
            F[m.group(2)]["events"].append((s["tick"], "site:" + s["resource"]))
            continue
        m = RX["shape"].search(line)
        if m and m.group(2) in F:
            ops = []
            if m.group(13) != "-":
                for o in m.group(13).split(","):
                    oid, kind, dx, dy = o.split(":")
                    ops.append((int(oid), kind, int(dx), int(dy)))
            names = {}
            if m.group(14) != "-":
                for kv in m.group(14).split(","):
                    k, v = kv.split("=")
                    names[k] = int(v)
            F[m.group(2)]["shapes"].append({
                "tick": int(m.group(1)), "n": int(m.group(5)), "chunks": int(m.group(6)),
                "cov": (float(m.group(9)), float(m.group(10)), float(m.group(11))), "radius": int(m.group(12)),
                "outposts": ops, "names": names})
            continue
        m = RX["goal"].search(line)
        if m and m.group(1) in F:
            F[m.group(1)]["events"].append((int(round(float(m.group(3)) * 3600)), "obj:" + m.group(2)))
            continue
        m = RX["research"].search(line)
        if m and m.group(1) in F:
            F[m.group(1)]["events"].append((int(round(float(m.group(3)) * 3600)), "tech:" + m.group(2)))


# ---------------------------------------------------------------------------------------------------
# Métriques
# ---------------------------------------------------------------------------------------------------
def capital(names):
    return sum(COST.get(k, 10) * v for k, v in names.items())


def faction_metrics(f):
    out = {"personality": f["personality"], "origin": f["origin"], "traits": f["traits"],
           "eliminated_min": f.get("eliminated_min")}
    # M1
    known = {}
    for s in f["shapes"]:
        for oid, kind, dx, dy in s["outposts"]:
            known[oid] = (kind, dx, dy)
    oids = sorted(known)
    out["outposts"] = len(oids)
    out["rho"] = spearman(oids, [math.hypot(known[o][1], known[o][2]) for o in oids])
    last = f["shapes"][-1] if f["shapes"] else None
    out["roundness"] = roundness(*last["cov"]) if last else None
    out["chunks"] = last["chunks"] if last else None
    out["buildings"] = last["n"] if last else None
    out["radius"] = last["radius"] if last else None
    sites = f["sites"]
    out["sites"] = len(sites)
    out["nearest_first"] = (sum(1 for s in sites if s["rank"] == 1) / len(sites)) if sites else None
    # M2
    att = f["attacks"]
    ticks = [a["tick"] for a in att]
    out["attacks"] = len(att)
    out["attacks60"] = sum(1 for t in ticks if t <= 216000)
    out["first_attack_min"] = ticks[0] / 3600 if ticks else None
    gaps = [b - a for a, b in zip(ticks, ticks[1:])]
    out["cadence_cv"] = cv(gaps) if len(gaps) >= 2 else None
    out["size_cv"] = cv([a["n"] for a in att])
    by_target = {}
    for a in att:
        by_target.setdefault(a["target"], []).append(a["octant"])
    ents = [entropy(v) for v in by_target.values() if len(v) >= 2]
    out["sides_entropy"] = max(ents) if ents else None
    ev = sorted(f["events"])
    out["decisions"] = [e[1] for e in ev[:20]]
    # Lot IA2-a : chef (postures minute par minute), raids, règle des attaques, apprentissage (M4).
    post = f["postures"]
    doms = [p["dominant"] for p in post]
    out["thinks"] = len(post)
    out["posture_entropy"] = entropy(doms) if doms else None
    runs = []
    for d in doms:
        if runs and runs[-1][0] == d:
            runs[-1][1] += 1
        else:
            runs.append([d, 1])
    out["posture_changes"] = max(0, len(runs) - 1)
    out["changes_per_hour"] = (out["posture_changes"] / (len(doms) / 60)) if len(doms) >= 30 else None
    # Durée médiane d'une dominante : séquences complètes seulement (ni la première ni la dernière, coupées).
    inner = [r[1] for r in runs[1:-1]]
    out["dominant_minutes_med"] = median(inner) if inner else None
    out["postures_seen"] = sorted(set(doms))
    out["raids"] = sum(1 for x in att if x.get("raid"))
    out["rule_varied"] = sum(1 for x in att if x.get("rule") == "variee")
    out["rule_ia0"] = sum(1 for x in att if x.get("rule") == "ia0")
    out["with_approach"] = sum(1 for x in att if x.get("approach"))
    out["issues"] = {}
    for i in f["issues"]:
        out["issues"][i["outcome"]] = out["issues"].get(i["outcome"], 0) + 1
    # M4 apprentissage : après une attaque repoussée ou anéantie, l'attaque SUIVANTE de la faction vise une autre
    # cible, OU arrive par un autre octant, OU est au moins 1,3 × plus grosse.
    learned, cases = 0, 0
    for i in f["issues"]:
        if i["outcome"] not in ("repoussee", "aneantie"):
            continue
        nxt = next((x for x in att if x["tick"] > i["tick"] and x["target"] != "player"), None)
        if nxt is None:
            continue
        cases += 1
        if nxt["target"] != i["target"] or (i["octant"] is not None and nxt["octant"] != i["octant"]) or nxt["n"] >= 1.3 * i["n"]:
            learned += 1
    out["learn_cases"], out["learned"] = cases, learned
    # M3
    d = dormant_share(f["stock"])
    out["dormant_med"] = median([x for m, x in d if 30 <= m])
    out["dormant_last"] = d[-1][1] if d else None
    dl = dict(f["delivered"])
    mins = sorted(dl)
    if mins:
        last_m = mins[-1]
        def rate(a, b):
            return (dl[b] - dl[a]) / (b - a) if a in dl and b in dl and b > a else None
        early = rate(20, 30)
        late = rate(last_m - 10, last_m)
        out["rate_early"], out["rate_late"] = early, late
        out["growth"] = (late / early) if early and late is not None and early > 0 else None
    else:
        out["rate_early"] = out["rate_late"] = out["growth"] = None
    rs = []
    shapes = f["shapes"]
    for s0, s1 in zip(shapes, shapes[1:]):
        m0, m1 = s0["tick"] // 3600, s1["tick"] // 3600
        if m0 in dl and m1 in dl and dl[m1] > dl[m0]:
            rs.append((capital(s1["names"]) - capital(s0["names"])) / (dl[m1] - dl[m0]))
    out["reinvest_med"] = median(rs)
    out["capital_last"] = capital(shapes[-1]["names"]) if shapes else None
    return out


def group_metrics(runs):
    per = {}
    for r in runs:
        per[r["seed"]] = {k: faction_metrics(r["factions"][k]) for k in KEYS}
    seeds = list(per)
    bases = [per[s][k] for s in seeds for k in KEYS]
    summ = {}
    summ["rho_med"] = median([b["rho"] for b in bases])
    rnd = [b["roundness"] for b in bases if b["roundness"] is not None]
    summ["roundness_med"] = median(rnd)
    summ["roundness_cv"] = cv(rnd)
    summ["nearest_first"] = median([b["nearest_first"] for b in bases])
    summ["cadence_cv_med"] = median([b["cadence_cv"] for b in bases])
    summ["size_cv_med"] = median([b["size_cv"] for b in bases])
    summ["sides_entropy_med"] = median([b["sides_entropy"] for b in bases])
    summ["fighting60"] = [sum(1 for k in KEYS if per[s][k]["attacks60"] > 0) for s in seeds]
    summ["fighting120"] = [sum(1 for k in KEYS if per[s][k]["attacks"] > 0) for s in seeds]
    summ["attacks_total"] = [sum(per[s][k]["attacks"] for k in KEYS) for s in seeds]
    firsts = []
    for s in seeds:
        fs = [per[s][k]["first_attack_min"] for k in KEYS if per[s][k]["first_attack_min"] is not None]
        firsts.append(min(fs) if fs else None)
    summ["first_attack_by_seed"] = firsts
    fv = [x for x in firsts if x is not None]
    summ["first_attack_sd"] = statistics.pstdev(fv) if len(fv) >= 2 else None
    # Distances de décision
    between_seeds = []
    for k in KEYS:
        for i in range(len(seeds)):
            for j in range(i + 1, len(seeds)):
                between_seeds.append(edit_distance(per[seeds[i]][k]["decisions"], per[seeds[j]][k]["decisions"]))
    between_fac = []
    for s in seeds:
        for i in range(len(KEYS)):
            for j in range(i + 1, len(KEYS)):
                between_fac.append(edit_distance(per[s][KEYS[i]]["decisions"], per[s][KEYS[j]]["decisions"]))
    summ["dist_seeds_med"] = median(between_seeds)
    summ["dist_factions_med"] = median(between_fac)
    # Caractère
    pers = {k: [per[s][k]["personality"] for s in seeds] for k in KEYS}
    summ["personalities"] = pers
    summ["distinct_personalities"] = {k: len(set(v)) for k, v in pers.items()}
    aggr = [per[s][k]["traits"].get("agressivite") for s in seeds for k in KEYS]
    aggr = [a for a in aggr if a is not None]
    summ["aggr_cv"] = cv(aggr) if aggr else None
    # Lot IA2-a : chef
    summ["posture_entropy_med"] = median([b["posture_entropy"] for b in bases])
    summ["changes_per_hour_med"] = median([b["changes_per_hour"] for b in bases])
    summ["dominant_minutes_med"] = median([b["dominant_minutes_med"] for b in bases])
    summ["raids_total"] = [sum(per[s][k]["raids"] for k in KEYS) for s in seeds]
    summ["rule_varied_ia0"] = [f"{sum(per[s][k]['rule_varied'] for k in KEYS)}/{sum(per[s][k]['rule_ia0'] for k in KEYS)}" for s in seeds]
    lc = sum(b["learn_cases"] for b in bases)
    summ["learn_share"] = (sum(b["learned"] for b in bases) / lc) if lc else None
    summ["learn_cases"] = lc
    summ["dormant_med"] = median([b["dormant_med"] for b in bases])
    summ["growth"] = [b["growth"] for b in bases]
    summ["growth_ge3"] = sum(1 for g in summ["growth"] if g is not None and g >= 3)
    summ["growth_med"] = median(summ["growth"])
    summ["reinvest_med"] = median([b["reinvest_med"] for b in bases])
    summ["minutes"] = [r["minutes"] for r in runs]
    summ["eliminated"] = [", ".join(f"{k} {per[s][k]['eliminated_min']} min" for k in KEYS if per[s][k]["eliminated_min"] is not None) or "aucune"
                          for s in seeds]
    return per, summ


def fmt(x, nd=2):
    if x is None:
        return "-"
    if isinstance(x, float):
        return f"{x:.{nd}f}"
    return str(x)


def print_detail(label, per):
    print(f"\n### {label} : par graine et par faction")
    print("| graine | faction | personnalité | agr. | pru. | avant-postes | ρ | rondeur | chunks | plus proche | attaques (60 min) | 1re (min) | cadence CV | tailles CV | côtés (bits) | dormant | croissance | r |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for s, fac in per.items():
        for k in KEYS:
            b = fac[k]
            t = b["traits"]
            print(f"| {s} | {k} | {b['personality']} | {fmt(t.get('agressivite'))} | {fmt(t.get('prudence'))} | {b['outposts']} | {fmt(b['rho'])} | "
                  f"{fmt(b['roundness'])} | {fmt(b['chunks'])} | {fmt(b['nearest_first'])} | {b['attacks']} ({b['attacks60']}) | "
                  f"{fmt(b['first_attack_min'], 1)} | {fmt(b['cadence_cv'])} | {fmt(b['size_cv'])} | {fmt(b['sides_entropy'])} | "
                  f"{fmt(b['dormant_med'])} | {fmt(b['growth'])} | {fmt(b['reinvest_med'], 3)} |")


ROWS = [
    ("M1 radialité ρ (médiane ; seuil proposé ≤ 0,5)", "rho_med"),
    ("M1 rondeur √(λ1/λ2) (médiane ; ≥ 1,6)", "roundness_med"),
    ("M1 rondeur, CV entre bases (≥ 0,25)", "roundness_cv"),
    ("M1 plus proche d'abord (médiane ; ≤ 0,4)", "nearest_first"),
    ("M2 personnalités distinctes par couleur sur les graines", "distinct_personalities"),
    ("M2 agressivité tirée, CV entre factions et graines", "aggr_cv"),
    ("M2 distance des 20 décisions, même faction entre graines (≥ 0,4)", "dist_seeds_med"),
    ("M2 distance des 20 décisions, entre factions d'une graine (≥ 0,4)", "dist_factions_med"),
    ("M2 cadence, CV des intervalles (médiane ; ≥ 0,5)", "cadence_cv_med"),
    ("M2 tailles, CV (médiane ; ≥ 0,3)", "size_cv_med"),
    ("M2 côtés, entropie des octants (médiane ; ≥ 1 bit)", "sides_entropy_med"),
    ("M2 entropie des postures dominantes, par faction (médiane ; ≥ 1,5 bit)", "posture_entropy_med"),
    ("M4 changements de dominante par heure (médiane ; ≤ 6)", "changes_per_hour_med"),
    ("M4 durée d'une dominante, min (médiane ; ≥ 5)", "dominant_minutes_med"),
    ("M4 apprentissage : attaque suivante autre cible, autre côté ou ≥ 1,3 × (≥ 90 %)", "learn_share"),
    ("M4 apprentissage : cas (attaques repoussées suivies d'une attaque)", "learn_cases"),
    ("raids, par graine", "raids_total"),
    ("attaques entre factions : règle variée / règle d'IA0, par graine", "rule_varied_ia0"),
    ("M2 factions qui attaquent en 60 min, par graine (4 sur 4)", "fighting60"),
    ("M2 factions qui attaquent en 120 min, par graine", "fighting120"),
    ("M2 attaques en 120 min, par graine", "attacks_total"),
    ("M2 1re attaque de la partie (min), par graine", "first_attack_by_seed"),
    ("M2 1re attaque, écart-type entre graines (min)", "first_attack_sd"),
    ("factions anéanties (minute du constat), par graine", "eliminated"),
    ("M3 stock dormant > 10 min (médiane de 30 à 120 min ; ≤ 0,25)", "dormant_med"),
    ("M3 croissance des livraisons, 110-120 ÷ 20-30 min (médiane)", "growth_med"),
    ("M3 bases à croissance ≥ 3", "growth_ge3"),
    ("M3 r proxy, capital gagné ÷ objets livrés (médiane)", "reinvest_med"),
]


def show(v):
    if isinstance(v, list):
        return ", ".join(fmt(x, 1) for x in v)
    if isinstance(v, dict):
        return ", ".join(f"{k} {v[k]}" for k in KEYS if k in v)
    return fmt(v)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("runs", nargs="*")
    ap.add_argument("--avant", nargs="*", default=[])
    ap.add_argument("--apres", nargs="*", default=[])
    ap.add_argument("--json")
    ap.add_argument("--detail", action="store_true")
    a = ap.parse_args(argv)
    groups = []
    if a.runs:
        groups.append(("bancs", a.runs))
    if a.avant:
        groups.append(("avant", a.avant))
    if a.apres:
        groups.append(("apres", a.apres))
    if not groups:
        ap.error("aucun dossier de banc")
    results = {}
    for label, dirs in groups:
        runs = [read_run(d) for d in dirs]
        per, summ = group_metrics(runs)
        results[label] = {"per": per, "summary": summ}
        if a.detail:
            print_detail(label, per)
    labels = [g[0] for g in groups]
    print("\n### Résumé (" + " / ".join(f"{l} : graines {', '.join(results[l]['per'].keys())}" for l in labels) + ")")
    print("| métrique | " + " | ".join(labels) + " |")
    print("|---|" + "---|" * len(labels))
    for title, key in ROWS:
        print(f"| {title} | " + " | ".join(show(results[l]["summary"].get(key)) for l in labels) + " |")
    if a.json:
        with open(a.json, "w", encoding="utf-8") as fh:
            json.dump(results, fh, ensure_ascii=False, indent=1, default=str)
    return 0


if __name__ == "__main__":
    sys.exit(main())
