"""Lot PAVAGE-PREUVE : lecture des lignes [FO-PAVAGE-PREUVE] (scenarios/pavage_common.lua) d'un journal de banc.

    py -3.9 -B tools/autotest/pavage_mesures.py <journal> [--minute M] [--min-tuiles N] [--touches]

<journal> : benchmark.log(.gz) d'une archive de banc, ou fo-shots/factorio.log d'une session avec images, ou le dossier
de l'archive (on y cherche benchmark.log.gz, puis fo-shots/factorio.log). Sortie : tableau Markdown par équipe et
gisement à la minute M (défaut : la dernière mesurée), puis une ligne de synthèse par équipe. --touches : seulement les
gisements où l'équipe a au moins une foreuse. Aucune dépendance hors bibliothèque standard.
Lot CULS-DE-SAC : colonnes « tronçons morts » (tapis qui reçoivent du minerai sans aucun consommateur, voir pavage_common.lua),
« souterrains seuls » (sans paire) et « fantômes » ; une journalisation d'avant le lot les affiche « - ».
"""
import argparse
import gzip
import os
import re
import sys

TAG = "[FO-PAVAGE-PREUVE] "


def open_log(path):
    if os.path.isdir(path):
        for c in ("benchmark.log.gz", "benchmark.log", os.path.join("fo-shots", "factorio.log")):
            p = os.path.join(path, c)
            if os.path.exists(p):
                path = p
                break
        else:
            sys.exit("aucun journal dans " + path)
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="replace"), path
    return open(path, encoding="utf-8", errors="replace"), path


def parse(path):
    f, real = open_log(path)
    rows, teams = [], []
    with f:
        for line in f:
            i = line.find(TAG)
            if i < 0:
                continue
            body = line[i + len(TAG):].strip()
            kind, _, rest = body.partition(" ")
            if kind not in ("gisement", "equipe"):
                continue
            d = dict(re.findall(r"(\w+)=(\S+)", rest))
            d["_kind"] = kind
            (rows if kind == "gisement" else teams).append(d)
    return rows, teams, real


def num(r, k):
    v = r.get(k, "0")
    return int(v) if v.lstrip("-").isdigit() else 0


def waiting(r):
    for kv in r.get("etats", "-").split(","):
        k, _, v = kv.partition(":")
        if k == "waiting_for_space_in_destination" and v.isdigit():
            return int(v)
    return 0


def dead(r):
    if "troncons_morts" not in r:
        return "-"
    return f'{r["troncons_morts"]} ({r.get("foreuses_mortes", "0")} ; {r.get("morts", "-")})'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("journal")
    ap.add_argument("--minute", type=int)
    ap.add_argument("--min-tuiles", type=int, default=0)
    ap.add_argument("--touches", action="store_true")
    ap.add_argument("--phase", default="T", help="T (mesure au tick T, défaut) ou capture (re-mesure au tick de chaque capture)")
    a = ap.parse_args()
    rows, teams, real = parse(a.journal)
    rows = [r for r in rows if r.get("phase", "T") == a.phase]
    if not rows:
        sys.exit("aucune ligne gisement dans " + real)
    minute = a.minute if a.minute is not None else max(int(r["minute"]) for r in rows)
    alls = [r for r in rows if int(r["minute"]) == minute and int(r["tuiles"]) >= a.min_tuiles]
    sel = alls
    if a.touches:
        sel = [r for r in sel if int(r["foreuses_elec"]) + int(r["foreuses_comb"]) > 0]
    print(f"Journal : {real} ; minute {minute} ; {len(sel)} gisement(s)\n")
    print("| équipe | ressource | n | tuiles | dist. QG | foreuses élec | foreuses brûleur | couverture % | interdites sur minerai | sortie par tapis | tronçons morts (foreuses ; bouts) | souterrains seuls | fantômes | états des foreuses | capture |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in sel:
        inter = r["interdites"] if r["interdites"] == "0" else f'{r["interdites"]} ({r["interdits"]})'
        print(f'| {r["equipe"]} | {r["ressource"]} | {r["n"]} | {r["tuiles"]} | {r["distance_qg"]} | {r["foreuses_elec"]} | '
              f'{r["foreuses_comb"]} | {r["couverture"].rstrip("%")} | {inter} | {r["sortie_tapis"]} | {dead(r)} | '
              f'{r.get("souterrains_seuls", "-")} | {r.get("fantomes", "-")} | {r["etats"]} | {r["capture"]} |')
    print()
    for t in [t for t in teams if int(t["minute"]) == minute]:  # équipes : relevé du tick T
        mine = [r for r in alls if r["equipe"] == t["equipe"]]
        tiles = sum(int(r["tuiles"]) for r in mine)
        cov = sum(int(r["couvertes"]) for r in mine)
        touched = [r for r in mine if int(r["foreuses_elec"]) + int(r["foreuses_comb"]) > 0]
        tt = sum(int(r["tuiles"]) for r in touched)
        tc = sum(int(r["couvertes"]) for r in touched)
        bad = sum(int(r["interdites"]) for r in mine)
        out = sum(1 for r in touched if r["sortie_tapis"] == "oui")
        morts = sum(num(r, "troncons_morts") for r in mine)
        fmortes = sum(num(r, "foreuses_mortes") for r in mine)
        seuls = sum(num(r, "souterrains_seuls") for r in mine)
        attente = sum(waiting(r) for r in mine)
        print(f'- {t["equipe"]} : {t["foreuses_equipe"]} foreuses en tout ; {len(mine)} gisements, {tiles} tuiles, couverture '
              f'{100 * cov / max(1, tiles):.1f} % ; gisements exploités {len(touched)} ({tt} tuiles, couverture '
              f'{100 * tc / max(1, tt):.1f} %), sortie par tapis {out}/{len(touched)} ; entités interdites sur minerai {bad} ; '
              f'tronçons morts {morts} ({fmortes} foreuses), souterrains seuls {seuls}, foreuses en attente de place {attente}')
    tot = [r for r in alls]
    print(f'\nTotal : tronçons morts {sum(num(r, "troncons_morts") for r in tot)} ({sum(num(r, "foreuses_mortes") for r in tot)} foreuses), '
          f'souterrains seuls {sum(num(r, "souterrains_seuls") for r in tot)}, fantômes {sum(num(r, "fantomes") for r in tot)}, '
          f'foreuses en attente de place {sum(waiting(r) for r in tot)}, entités interdites sur minerai {sum(int(r["interdites"]) for r in tot)}')


if __name__ == "__main__":
    main()
