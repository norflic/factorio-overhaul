#!/usr/bin/env python3
"""
Correction du lot IA1-a (défauts M1 et M2 de la vérification adverse, 24/10) : armée des factions et coffre de
votre équipe, lus dans les RAPPORTS du mod (toutes les minutes), donc sur n'importe quelle version (0.4.11 comprise).

    py -3.9 -B tools/autotest/ia1_armee.py <archive> [<archive> ...] [--minutes 20,30,60] [--csv <fichier>]

Une archive = un dossier fo-autotest (benchmark.log ; seed.txt et source.txt s'ils existent).
Lignes lues : « [FO-WAR] <m> min | factions vivantes n », puis pour chaque faction « <Nom> [perso] tech a+b |
avant-postes n (...) | fonderie n | soldats s (...) | ouvriers w | attaques a | pertes p » et sa ligne « equipe :
... stock iron=... | ... | livre fer f ... » ; « [FO-AUTOTEST] equipe du joueur : equipe : ... » (votre équipe).
Pour chaque minute demandée, le DERNIER rapport à cette minute ou avant (la minute 60 d'un banc de 216 000 ticks
n'a pas de rapport : on lit la 59).
Publie, par archive : soldats, ouvriers, technologie, avant-postes, fer au stock et fer livré par faction ; total
des soldats ; votre équipe : ouvriers (dont inactifs), fer au coffre, ramassé, fer livré, objectif.
Code de sortie : 0 ; 2 si une archive est illisible.
"""
import argparse
import os
import re
import sys

WAR_RE = re.compile(r"\[FO-WAR\] ([0-9.]+) min \| factions vivantes (\d+)")
FAC_RE = re.compile(r"(Scarlet|Azure|Emerald|Amber) [A-Za-z]+ \[\w+\] tech (\d+)\+\d+ \| avant-postes (\d+) .*?"
                    r"\| soldats (\d+) .*?\| ouvriers (\d+) \| attaques (\d+) \| pertes (\d+)")
TEAM_RE = re.compile(r"equipe : objectif (\S+(?: \([^)]*\))?).*?\| stock iron=(\d+)")
OUV_RE = re.compile(r"\| ouvriers \{([^}]*)\}")
LIVRE_RE = re.compile(r"\| ramasse (\d+) \| entraines \d+ \| livre fer (\d+)")
EFF_RE = re.compile(r"\| effectif (\d+)/(\d+) \(recrues (\d+)")
KEYS = ["scarlet", "azure", "emerald", "amber"]


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return None


def workers_of(line):
    m = OUV_RE.search(line)
    if not m:
        return 0, 0
    total, idle = 0, 0
    for part in m.group(1).split():
        if ":" in part:
            k, v = part.rsplit(":", 1)
            if v.isdigit():
                total += int(v)
                if k == "idle":
                    idle += int(v)
    return total, idle


def team_fields(line):
    out = {}
    m = TEAM_RE.search(line)
    if m:
        out["goal"], out["iron"] = m.group(1), int(m.group(2))
    w, idle = workers_of(line)
    out["workers"], out["idle"] = w, idle
    m = LIVRE_RE.search(line)
    if m:
        out["collected"], out["iron_delivered"] = int(m.group(1)), int(m.group(2))
    m = EFF_RE.search(line)
    if m:
        out["n"], out["max"], out["recruited"] = int(m.group(1)), int(m.group(2)), int(m.group(3))
    return out


def parse(log):
    """Rend {minute (float): {"factions": {key: {...}}, "player": {...}}}."""
    snaps, cur, last_fac = {}, None, None
    for line in log.splitlines():
        m = WAR_RE.search(line)
        if m:
            cur = float(m.group(1))
            snaps.setdefault(cur, {"factions": {}, "player": None, "alive": int(m.group(2))})
            last_fac = None
            continue
        if cur is None:
            continue
        if "[FO-AUTOTEST] equipe du joueur :" in line:
            snaps[cur]["player"] = team_fields(line)
            continue
        m = FAC_RE.search(line)
        if m:
            key = m.group(1).lower()
            snaps[cur]["factions"][key] = {
                "tech": int(m.group(2)), "outposts": int(m.group(3)), "soldiers": int(m.group(4)),
                "workers": int(m.group(5)), "attacks": int(m.group(6)), "losses": int(m.group(7)),
            }
            last_fac = key
            continue
        if last_fac and "equipe : objectif" in line and "equipe du joueur" not in line:
            snaps[cur]["factions"][last_fac].update({k: v for k, v in team_fields(line).items() if k != "workers"})
            last_fac = None
    return snaps


def at(snaps, minute):
    keys = [k for k in snaps if k <= minute + 1e-6]
    return (max(keys), snaps[max(keys)]) if keys else (None, None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--minutes", default="20,30,60")
    ap.add_argument("--csv", default=None)
    a = ap.parse_args()
    minutes = [int(x) for x in a.minutes.split(",")]
    rows, bad = [], 0
    for d in a.dirs:
        log = read(os.path.join(d, "benchmark.log"))
        if log is None:
            print(f"ILLISIBLE : {d}")
            bad += 1
            continue
        seed = (read(os.path.join(d, "seed.txt")) or "?").strip()
        src = (read(os.path.join(d, "source.txt")) or "?").strip()
        snaps = parse(log)
        label = os.path.basename(os.path.normpath(d))
        print(f"== {label} | graine {seed} | source {src}")
        for mn in minutes:
            real, s = at(snaps, mn)
            if s is None or real < mn - 1.01:
                print(f"   min {mn} : aucun rapport (dernier : {real})")
                continue
            parts, total = [], 0
            for k in KEYS:
                f = s["factions"].get(k)
                if f is None:
                    parts.append(f"{k} elimine")
                    continue
                total += f["soldiers"]
                parts.append(f"{k} sold {f['soldiers']} ouv {f['workers']} tech {f['tech']} ap {f['outposts']} "
                             f"fer {f.get('iron', '?')} livre {f.get('iron_delivered', '?')}")
                rows.append([label, seed, mn, real, k, f["soldiers"], f["workers"], f["tech"], f["outposts"],
                             f.get("iron", ""), f.get("iron_delivered", ""), f["attacks"], f["losses"]])
            p = s["player"] or {}
            print(f"   min {mn} (rapport {real:g}) : soldats total {total} | " + " ; ".join(parts))
            if p:
                print(f"      votre equipe : ouvriers {p.get('workers')} (inactifs {p.get('idle')}) "
                      f"fer au coffre {p.get('iron')} ramasse {p.get('collected')} fer livre {p.get('iron_delivered')} "
                      f"objectif {p.get('goal')}" + (f" recrues payees {p['recruited']}" if "recruited" in p else ""))
                rows.append([label, seed, mn, real, "player", "", p.get("workers"), "", "", p.get("iron"),
                             p.get("iron_delivered"), "", ""])
    if a.csv:
        with open(a.csv, "w", encoding="utf-8") as f:
            f.write("archive;graine;minute;rapport;equipe;soldats;ouvriers;tech;avant_postes;fer_stock;fer_livre;"
                    "attaques;pertes\n")
            for r in rows:
                f.write(";".join("" if v is None else str(v) for v in r) + "\n")
        print(f"== tableau : {a.csv}")
    return 2 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
