"""Lot X10-CHEMINS (7/11) : lecture du RELEVÉ des demandes de chemin (scénario x10-chemins-releve, lignes [FO-CHEMINS-J]).

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/chemins_releve.py <archive> [<archive> ...]

Rend, par archive (fo-logs/2026-11-07_X10/CHEMINS_CRITERES.md §2.2) :
  1. demandes émises, refusées (L5), finies par issue et par client ; latence des réussites et des échecs ;
  2. RÉPÉTITIONS : part des demandes dont la même clé (client, marge, rayon, résolution, case du départ, case du but) a déjà été
     demandée dans les T ticks d'avant, avec une issue « ok » (cache POSITIF possible) ou « no_path » (cache NÉGATIF possible),
     pour plusieurs tailles de case et plusieurs T ;
  3. distances départ-but (part des trajets de moins de 40 tuiles : sans variation C1) ;
  4. pathFinder du moteur par tick (--benchmark-verbose) mis en face des recherches EN COURS par issue : moindres carrés
     pathFinder(t) = a + Σ b_issue × en_cours_issue(t). Estimation GROSSIÈRE (banc sans --seul, autres clients du pathfinder :
     soldats, biters) : elle oriente, elle ne mesure pas.
Format d'une ligne (script/core/path_service.lua, jlog) :
  [FO-CHEMINS-J] tick ev ticket client owner sx sy gx gy radius pad res a b c
  ev : R (refusée, a = motif), E (émise, a = « nu » si sans marge), F (finie : a = issue, b = points, c = latence).
"""
import collections
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import perf3  # noqa: E402

RE_J = re.compile(r"\[FO-CHEMINS-J\] (.*)$")


def lire(arch):
    reqs = {}
    with perf3.opn(arch, "benchmark.log") as f:
        for line in f:
            m = RE_J.search(line)
            if not m:
                continue
            c = m.group(1).split()
            if len(c) < 15:
                continue
            tick, ev, ticket = int(c[0]), c[1], int(c[2])
            r = reqs.setdefault(ticket, {"ticket": ticket})
            if ev in ("R", "E"):
                if "t0" in r and ev == "E":
                    r["relances"] = r.get("relances", 0) + 1
                    continue
                r.update(t0=tick, ev=ev, h=c[3], owner=c[4], sx=float(c[5]), sy=float(c[6]), gx=float(c[7]), gy=float(c[8]),
                         radius=c[9], pad=c[10], res=c[11], nu=(c[12] == "nu"))
                if ev == "R":
                    r.update(issue="refus:" + c[12], t1=tick, lat=0)
            elif ev == "F":
                if c[12] == "retry":
                    continue
                r.update(t1=tick, issue=c[12], pts=int(c[13]), lat=int(c[14]))
    return [r for r in sorted(reqs.values(), key=lambda r: (r.get("t0", 0), r["ticket"])) if "t0" in r]


def cle(r, sc, gc):
    def cell(v, s):
        return math.floor(v / s)
    return (r["h"], r["pad"], r["radius"], r["res"], cell(r["sx"], sc), cell(r["sy"], sc), cell(r["gx"], gc), cell(r["gy"], gc))


def repetitions(reqs, sc, gc, T):
    """(part positive, part négative) : demandes dont la clé a été demandée dans les T ticks d'avant avec issue ok / no_path."""
    last = {}
    pos = neg = n = 0
    for r in reqs:
        if r["h"] != "fo-nav":
            continue
        n += 1
        k = cle(r, sc, gc)
        prev = last.get(k)
        if prev and r["t0"] - prev[0] <= T:
            if prev[1] == "ok":
                pos += 1
            elif prev[1].startswith("no_path") or prev[1].startswith("refus"):
                neg += 1
        if "issue" in r:
            last[k] = (r.get("t1", r["t0"]), r["issue"])
    return (pos / n if n else 0.0), (neg / n if n else 0.0), n


def neg_suites(reqs, sc, gc):
    """Échecs (no_path ou refus) de PNJ suivis d'un nouvel échec de même clé : écarts en ticks."""
    last = {}
    ecarts = []
    for r in reqs:
        if r["h"] != "fo-nav" or "issue" not in r:
            continue
        k = cle(r, sc, gc)
        bad = r["issue"].startswith("no_path") or r["issue"].startswith("refus")
        if bad and k in last:
            ecarts.append(r["t0"] - last[k])
        if bad:
            last[k] = r.get("t1", r["t0"])
        else:
            last.pop(k, None)
    return ecarts


def moindres_carres(X, y):
    """Résout (XᵀX) b = Xᵀy par élimination de Gauss (petites dimensions)."""
    n = len(X[0])
    A = [[0.0] * (n + 1) for _ in range(n)]
    for row, v in zip(X, y):
        for i in range(n):
            A[i][n] += row[i] * v
            for j in range(n):
                A[i][j] += row[i] * row[j]
    for i in range(n):
        p = max(range(i, n), key=lambda k: abs(A[k][i]))
        A[i], A[p] = A[p], A[i]
        if abs(A[i][i]) < 1e-12:
            return None
        for k in range(n):
            if k != i:
                f = A[k][i] / A[i][i]
                for j in range(i, n + 1):
                    A[k][j] -= f * A[i][j]
    return [A[i][n] / A[i][i] for i in range(n)]


def cout_pathfinder(arch, reqs):
    try:
        with perf3.opn(arch, "benchmark-stdout.txt") as f:
            rows = perf3.aligner(perf3.parse_verbose(f), arch)
    except (OSError, SystemExit):  # perf3.opn lève SystemExit sur un fichier absent
        return None
    if not rows:
        return None
    col = "pathFinder" if "pathFinder" in next(iter(rows.values())) else None
    if not col:
        return None
    classes = ["ok", "eau", "autre", "depart", "busy"]

    def classe(r):
        i = r.get("issue", "")
        if i == "ok":
            return "ok"
        if "water" in i:
            return "eau"
        if "start" in i:
            return "depart"
        if i.startswith("no_path"):
            return "autre"
        return "busy" if i in ("busy", "timeout") else None
    actifs = collections.defaultdict(lambda: [0] * len(classes))
    for r in reqs:
        c = classe(r)
        if c is None or r["ev"] != "E" or "t1" not in r:
            continue
        for t in range(r["t0"], r["t1"] + 1):
            actifs[t][classes.index(c)] += 1
    ticks = sorted(rows)
    ticks = ticks[60:]
    # Classes sans aucun tick actif : retirées (sinon le système est singulier).
    keep = [i for i in range(len(classes)) if any(actifs[t][i] for t in ticks)]
    X = [[1.0] + [float(actifs[t][i]) for i in keep] for t in ticks]
    y = [rows[t][col] / 1e6 for t in ticks]
    b = moindres_carres(X, y)
    moy = sum(y) / len(y) if y else 0.0
    # Ticks avec au moins une recherche de PNJ en cours, contre les autres : moyenne du pathFinder.
    with_r = [rows[t][col] / 1e6 for t in ticks if any(actifs[t])]
    without = [rows[t][col] / 1e6 for t in ticks if not any(actifs[t])]
    extra = (sum(with_r) / len(with_r) if with_r else 0, len(with_r), sum(without) / len(without) if without else 0, len(without))
    return [classes[i] for i in keep], b, moy, len(ticks), extra


RE_P = re.compile(r"\[FO-CHEMINS-P\] (.*)$")


def lire_plans(arch):
    """Itinéraires de M.plan (script/ai3/comportement.lua) : tick équipe agent var same scx scy gcx gcy B graine empreinte n
    astar|via développements bloque|- points."""
    out = []
    with perf3.opn(arch, "benchmark.log") as f:
        for line in f:
            m = RE_P.search(line)
            if not m:
                continue
            c = m.group(1).split()
            if len(c) < 17:
                continue
            out.append({"t": int(c[0]), "team": c[1], "agent": c[2], "var": c[3] == "var", "same": c[4] == "same",
                        "sc": (int(c[5]), int(c[6])), "gc": (int(c[7]), int(c[8])), "B": c[9], "seed": c[10], "h": c[11],
                        "n": c[12], "astar": c[13] == "astar", "exp": int(c[14]), "bloque": c[15] == "bloque", "pts": int(c[16])})
    return out


def plans_rapport(plans):
    if not plans:
        print("  itinéraires : aucun au journal")
        return
    n = len(plans)
    nv = sum(1 for p in plans if p["var"])
    na = sum(1 for p in plans if p["astar"])
    exp = sum(p["exp"] for p in plans)
    print("  itinéraires (M.plan) : %d, dont %d avec variation (aller), %d « same » ; A* %d (%.0f %%), développements %d en tout" % (
        n, nv, sum(1 for p in plans if p["same"]), na, 100.0 * na / n, exp))
    # Mémo exact de l'A* : même équipe, cases, seuil, graine et empreinte du champ, déjà calculé avant.
    seen = set()
    hit = hit_exp = 0
    for p in plans:
        if not p["astar"]:
            continue
        k = (p["team"], p["sc"], p["gc"], p["B"], p["seed"], p["h"], p["n"])
        if k in seen:
            hit += 1
            hit_exp += p["exp"]
        seen.add(k)
    print("  mémo EXACT de l'A* (clé déjà vue dans la fenêtre) : %d A* sur %d (%.1f %%), %.1f %% des développements" % (
        hit, na, 100.0 * hit / na if na else 0, 100.0 * hit_exp / exp if exp else 0))
    # Aller qui suit une porte pour le même trajet (même agent, mêmes cases), et champ inchangé.
    last_gate = {}
    follow = same_field = 0
    for p in plans:
        key = (p["team"], p["agent"])
        if not p["var"] and not p["same"]:
            last_gate[key] = p
        elif p["var"]:
            g = last_gate.get(key)
            if g and g["sc"] == p["sc"] and g["gc"] == p["gc"] and p["t"] - g["t"] <= 180:
                follow += 1
                if g["h"] == p["h"] and g["n"] == p["n"]:
                    same_field += 1
    print("  allers qui suivent une porte du même trajet à 180 ticks au plus : %d sur %d (champ inchangé : %d)" % (follow, nv, same_field))


def troncons(plans, reqs):
    """Demandes de chemin d'un PNJ entre deux itinéraires (M.plan) du même PNJ : tronçons par itinéraire, longueur et latence."""
    by_agent = collections.defaultdict(list)
    for p in plans:
        if p["var"]:  # allers seulement : la porte précède son aller de 60 ticks, sans demande entre les deux
            by_agent[p["agent"]].append(p["t"])
    nav = collections.defaultdict(list)
    for r in reqs:
        if r["h"] == "fo-nav":
            nav[r["owner"]].append(r)
    counts, sans_plan = [], 0
    for agent, ts in by_agent.items():
        ts.sort()
        rs = nav.get(agent, [])
        for i, t in enumerate(ts):
            t_next = ts[i + 1] if i + 1 < len(ts) else None
            n = sum(1 for r in rs if r["t0"] >= t and (t_next is None or r["t0"] < t_next))
            if t_next is not None:  # le dernier itinéraire de la fenêtre peut être coupé par la fin du relevé
                counts.append(n)
    for agent, rs in nav.items():
        if agent not in by_agent:
            sans_plan += len(rs)
    if counts:
        counts.sort()
        print("  tronçons par aller (demandes de chemin du PNJ d'un aller au suivant) : moyenne %.2f, médiane %d, p90 %d, pire %d (%d itinéraires) ; demandes de PNJ sans itinéraire dans la fenêtre : %d" % (
            sum(counts) / len(counts), counts[len(counts) // 2], counts[int(len(counts) * 0.9)], counts[-1], len(counts), sans_plan))
    by_len = collections.defaultdict(list)
    for r in reqs:
        if r["h"] != "fo-nav" or r.get("ev") != "E" or r.get("issue") != "ok":
            continue
        d = math.hypot(r["gx"] - r["sx"], r["gy"] - r["sy"])
        b = "< 20" if d < 20 else ("20-40" if d < 40 else ("40-80" if d < 80 else ">= 80"))
        by_len[b].append(r)
    for b in ("< 20", "20-40", "40-80", ">= 80"):
        v = by_len.get(b, [])
        if v:
            print("    réussites %-6s tuiles : %4d demandes, %5.1f points en moyenne, latence %.2f tick" % (
                b, len(v), sum(r["pts"] for r in v) / len(v), sum(r["lat"] for r in v) / len(v)))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    for arch in sys.argv[1:]:
        reqs = lire(arch)
        print("== %s : %d demande(s) au journal" % (arch, len(reqs)))
        if not reqs:
            continue
        t0, t1 = min(r["t0"] for r in reqs), max(r.get("t1", r["t0"]) for r in reqs)
        par = collections.Counter((r["h"], r.get("issue", "?").split(":")[0] + (":" + r["issue"].split(":")[1] if ":" in r.get("issue", "") else "")) for r in reqs)
        print("  fenêtre : ticks %d à %d (%d ticks)" % (t0, t1, t1 - t0))
        for (h, i), n in sorted(par.items(), key=lambda kv: (-kv[1], kv[0])):
            print("  %-16s %-22s %5d" % (h, i, n))
        nu = sum(1 for r in reqs if r.get("nu"))
        print("  émises sans marge (L5, départ bloqué) : %d ; relances (try_again_later) : %d" % (nu, sum(r.get("relances", 0) for r in reqs)))
        lat_ok = [r["lat"] for r in reqs if r.get("issue") == "ok"]
        lat_ko = [r["lat"] for r in reqs if str(r.get("issue", "")).startswith("no_path")]
        for nom, v in (("réussites", lat_ok), ("échecs", lat_ko)):
            if v:
                v.sort()
                print("  latence des %s : moyenne %.2f tick, médiane %d, p90 %d, pire %d (%d)" % (
                    nom, sum(v) / len(v), v[len(v) // 2], v[int(len(v) * 0.9)], v[-1], len(v)))
        d = sorted(math.hypot(r["gx"] - r["sx"], r["gy"] - r["sy"]) for r in reqs if r["h"] == "fo-nav")
        if d:
            print("  PNJ : distance départ-but médiane %.0f tuiles, p90 %.0f ; moins de 40 tuiles : %.0f %%" % (
                d[len(d) // 2], d[int(len(d) * 0.9)], 100.0 * sum(1 for x in d if x < 40) / len(d)))
        print("  répétitions des demandes des PNJ (même clé déjà demandée dans les T ticks d'avant) :")
        print("    case départ  case but      T   positif   négatif   (demandes)")
        for sc in (1, 4, 8):
            for gc in (1, 4):
                for T in (600, 1800, 100000):
                    p, ng, n = repetitions(reqs, sc, gc, T)
                    print("    %10d %9d %6s %8.1f %% %8.1f %%   %d" % (sc, gc, "tout" if T == 100000 else T, 100 * p, 100 * ng, n))
        ec = neg_suites(reqs, 8, 1)
        if ec:
            ec.sort()
            print("  échecs de PNJ refaits (clé case 8 / tuile) : %d ; écart médian %d ticks, p90 %d" % (len(ec), ec[len(ec) // 2], ec[int(len(ec) * 0.9)]))
        else:
            print("  échecs de PNJ refaits (clé case 8 / tuile) : 0")
        plans = lire_plans(arch)
        plans_rapport(plans)
        troncons(plans, reqs)
        cp = cout_pathfinder(arch, reqs)
        if cp:
            classes, b, moy, n, extra = cp
            print("  pathFinder : %.4f ms/tick quand une recherche de PNJ est en cours (%d ticks), %.4f sinon (%d ticks)" % extra)
            if b:
                print("  pathFinder moyen %.4f ms/tick sur %d ticks ; moindres carrés (ms par tick et par recherche EN COURS) : constante %.4f ; %s" % (
                    moy, n, b[0], ", ".join("%s %.4f" % (c, v) for c, v in zip(classes, b[1:]))))
            else:
                print("  pathFinder : système singulier (trop peu de recherches d'une classe)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
