# -*- coding: utf-8 -*-
"""Lot GISEMENTS-GEANTS : lecture des lignes [FO-GEANTS] (scenarios/geants_common.lua) d'une ou plusieurs archives du banc.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/geants_lecture.py <archive> [<archive> ...]
            [--minutes 5,10,15,20,25,30,35,40] [--detail] [--avec-temoin] [--json <fichier>]
Chaque archive est un dossier rendu par banc.py (benchmark.log.gz ou benchmark.log). Lecture seule, aucun jeu lancé.

Rend, par archive :
  - un tableau PAR ÉQUIPE et par minute demandée : pour-mille des tuiles des gisements géants couvert par des foreuses électriques,
    par des foreuses thermiques (sans source électrique) et en tout (l'union : une tuile sous les deux compte une fois), foreuses
    électriques et thermiques sur les géants, foreuses hors géants, lignes de tapis qui en sortent ;
  - une ligne de SYNTHÈSE par équipe à la dernière minute demandée (40 par défaut) : couverture, foreuses, lignes, gisements touchés
    sur le total, meilleur et pire gisement ;
  - avec --detail : le détail par gisement à cette minute.
Les valeurs sont en pour-mille des tuiles posées (un champ de 4 000 tuiles couvert par 6 foreuses électriques de 25 tuiles : 37,5 pm).
Une minute absente du journal est écrite « - » ; si la minute de synthèse manque, la dernière minute relevée la remplace (dite).
L'équipe TEMOIN (gisement synthétique du micro-banc) est ignorée sauf --avec-temoin.
"""
import gzip
import json
import os
import re
import sys

RE_LINE = re.compile(r"\[FO-GEANTS\] minute (\d+(?:\.\d+)?) \| ([^|]+?) \| (.*)$")
RE_DEP = re.compile(r"^(\S+)#(\d+) \| tuiles=(\d+) \| couvert elec=(\d+) \(\d+ pm\) therm=(\d+) \(\d+ pm\) total=(\d+) \(\d+ pm\)"
                    r" \| foreuses elec=(\d+) therm=(\d+) \| lignes=(\d+) directes=(\d+) sans_sortie=(\d+)")
RE_TOT = re.compile(r"^TOTAL (\d+) gisement\(s\) (\d+) tuiles \| couvert elec=(\d+) therm=(\d+) total=(\d+) \(\d+ pm\)"
                    r" \| foreuses dessus elec=(\d+) therm=(\d+), hors geants (\d+) \(toutes: elec=(\d+) therm=(\d+)\) \| lignes=(\d+)")
MINUTES = (5, 10, 15, 20, 25, 30, 35, 40)


def read_log(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            opener = gzip.open if name.endswith(".gz") else open
            with opener(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


def parse(lines):
    """-> { équipe: { minute (float) : { 'total': {...} | None, 'deps': { 'iron-ore#1': {...}, ... } } } } ; la dernière ligne d'une minute l'emporte."""
    out = {}
    for ln in lines:
        m = RE_LINE.search(ln)
        if not m:
            continue
        minute, team, body = float(m.group(1)), m.group(2).strip(), m.group(3)
        rec = out.setdefault(team, {}).setdefault(minute, {"total": None, "deps": {}})
        t = RE_TOT.match(body)
        if t:
            g = [int(x) for x in t.groups()]
            rec["total"] = dict(n_dep=g[0], tuiles=g[1], cov_e=g[2], cov_t=g[3], cov=g[4], e=g[5], t=g[6], hors=g[7],
                                all_e=g[8], all_t=g[9], lignes=g[10])
            continue
        d = RE_DEP.match(body)
        if d:
            g = d.groups()
            key = "%s#%s" % (g[0], g[1])
            rec["deps"][key] = dict(ore=g[0], rang=int(g[1]), tuiles=int(g[2]), cov_e=int(g[3]), cov_t=int(g[4]), cov=int(g[5]),
                                    e=int(g[6]), t=int(g[7]), lignes=int(g[8]), directes=int(g[9]), sans_sortie=int(g[10]))
    return out


def at(rows, minute):
    """Relevé de la minute `minute` (tolérance 0,05), ou None."""
    for m in sorted(rows):
        if abs(m - minute) < 0.05:
            return rows[m]
    return None


def pm(a, n):
    return 1000.0 * a / n if n else 0.0


def fmt_pm(x):
    return "%.1f" % x


def team_order(teams):
    return sorted(teams, key=lambda t: (t != "player", t))


def table(team, rows, minutes):
    out = ["Equipe %s" % ("VOTRE EQUIPE (player)" if team == "player" else team),
           "  minute | tuiles | pm elec | pm therm | pm total | foreuses elec/therm (sur geants) | hors geants | lignes de tapis"]
    for mn in minutes:
        r = at(rows, mn)
        tot = r and r["total"]
        if not tot:
            out.append("  %6d |      - |       - |        - |        - | -                                | -           | -" % mn)
            continue
        out.append("  %6d | %6d | %7s | %8s | %8s | %14s                   | %11d | %d" % (
            mn, tot["tuiles"], fmt_pm(pm(tot["cov_e"], tot["tuiles"])), fmt_pm(pm(tot["cov_t"], tot["tuiles"])),
            fmt_pm(pm(tot["cov"], tot["tuiles"])), "%d / %d" % (tot["e"], tot["t"]), tot["hors"], tot["lignes"]))
    return out


def synthese(team, rows, minute):
    """Ligne de synthèse de l'équipe à `minute` (ou à sa dernière minute relevée, dite). Rend (texte, dict)."""
    r = at(rows, minute)
    label = "%d min" % minute
    if not (r and r["total"]):
        done = [m for m in sorted(rows) if rows[m]["total"]]
        if not done:
            return "%s : aucun releve [FO-GEANTS]" % team, None
        minute = done[-1]
        r = rows[minute]
        label = "%.1f min (la minute demandee manque : dernier releve)" % minute
    tot, deps = r["total"], r["deps"]
    touched = [k for k in sorted(deps) if deps[k]["cov"] > 0]
    if deps:
        order = sorted(deps, key=lambda k: (pm(deps[k]["cov"], deps[k]["tuiles"]), k))
        worst, best = order[0], order[-1]
        extra = " | meilleur %s %s pm, pire %s %s pm" % (best, fmt_pm(pm(deps[best]["cov"], deps[best]["tuiles"])),
                                                       worst, fmt_pm(pm(deps[worst]["cov"], deps[worst]["tuiles"])))
    else:
        extra = ""
    txt = ("%s a %s : %d gisement(s), %d tuiles | couvert %s pm (elec %s, therm %s) | %d foreuse(s) dessus (%d elec, %d therm), %d hors geants | "
           "%d ligne(s) de tapis | gisements touches %d/%d%s") % (
        team, label, tot["n_dep"], tot["tuiles"], fmt_pm(pm(tot["cov"], tot["tuiles"])), fmt_pm(pm(tot["cov_e"], tot["tuiles"])),
        fmt_pm(pm(tot["cov_t"], tot["tuiles"])), tot["e"] + tot["t"], tot["e"], tot["t"], tot["hors"], tot["lignes"],
        len(touched), len(deps), extra)
    return txt, dict(minute=minute, pm=pm(tot["cov"], tot["tuiles"]), pm_e=pm(tot["cov_e"], tot["tuiles"]),
                     pm_t=pm(tot["cov_t"], tot["tuiles"]), foreuses=tot["e"] + tot["t"], lignes=tot["lignes"],
                     touches=len(touched), gisements=len(deps), tuiles=tot["tuiles"])


def detail(team, rows, minute):
    r = at(rows, minute)
    if not (r and r["deps"]):
        done = [m for m in sorted(rows) if rows[m]["deps"]]
        if not done:
            return []
        r = rows[done[-1]]
    out = ["  detail %s :" % team,
           "    gisement          | tuiles | pm elec | pm therm | pm total | elec/therm | lignes | directes | sans sortie"]
    for k in sorted(r["deps"]):
        d = r["deps"][k]
        out.append("    %-17s | %6d | %7s | %8s | %8s | %4d/%-5d | %6d | %8d | %d" % (
            k, d["tuiles"], fmt_pm(pm(d["cov_e"], d["tuiles"])), fmt_pm(pm(d["cov_t"], d["tuiles"])),
            fmt_pm(pm(d["cov"], d["tuiles"])), d["e"], d["t"], d["lignes"], d["directes"], d["sans_sortie"]))
    return out


def report(arch, minutes, want_detail=False, with_ctl=False):
    """Texte du rapport d'une archive et dictionnaire des synthèses par équipe."""
    data = parse(read_log(arch))
    teams = [t for t in team_order(data) if with_ctl or t != "TEMOIN"]
    out = ["=== %s ===" % arch]
    syn = {}
    if not teams:
        out.append("Aucune ligne [FO-GEANTS] de releve dans cette archive.")
        return "\n".join(out), syn
    for t in teams:
        out.extend(table(t, data[t], minutes))
        out.append("")
    out.append("Synthese (%d min) :" % minutes[-1])
    for t in teams:
        txt, d = synthese(t, data[t], minutes[-1])
        out.append("  " + txt)
        syn[t] = d
    if want_detail:
        out.append("")
        for t in teams:
            out.extend(detail(t, data[t], minutes[-1]))
    return "\n".join(out), syn


def main(argv):
    archs, minutes, want_detail, with_ctl, jpath = [], list(MINUTES), False, False, None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--minutes":
            i += 1
            minutes = sorted(int(x) for x in argv[i].split(",") if x)
        elif a == "--detail":
            want_detail = True
        elif a == "--avec-temoin":
            with_ctl = True
        elif a == "--json":
            i += 1
            jpath = argv[i]
        elif a.startswith("-"):
            print("option inconnue : " + a)
            return 2
        else:
            archs.append(a)
        i += 1
    if not archs or not minutes:
        print(__doc__)
        return 2
    allsyn = {}
    for a in archs:
        txt, syn = report(a, minutes, want_detail, with_ctl)
        print(txt)
        print("")
        allsyn[a] = syn
    if jpath:
        with open(jpath, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(allsyn, fh, indent=1, sort_keys=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
