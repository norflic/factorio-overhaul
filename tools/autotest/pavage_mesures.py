"""Lot PAVAGE-PREUVE : lecture des lignes [FO-PAVAGE-PREUVE] (scenarios/pavage_common.lua) d'un journal de banc.

    py -3.9 -B tools/autotest/pavage_mesures.py <journal> [--minute M] [--min-tuiles N] [--touches]

<journal> : benchmark.log(.gz) d'une archive de banc, ou fo-shots/factorio.log d'une session avec images, ou le dossier
de l'archive (on y cherche benchmark.log.gz, puis fo-shots/factorio.log). Sortie : tableau Markdown par équipe et
gisement à la minute M (défaut : la dernière mesurée), puis une ligne de synthèse par équipe. --touches : seulement les
gisements où l'équipe a au moins une foreuse. Aucune dépendance hors bibliothèque standard.
Lot CULS-DE-SAC : colonnes « tronçons morts » (tapis qui reçoivent du minerai sans aucun consommateur, voir pavage_common.lua),
« souterrains seuls » (sans paire) et « fantômes » ; une journalisation d'avant le lot les affiche « - ». Produits de la fonte
par équipe (champ produits= des lignes « equipe ») : total à la minute M et débit par minute depuis la mesure précédente.
Lot DEBIT-FER : --fer [M1,M2,...] lit les lignes [FO-DEBIT-FER] (bilan du fer par équipe et par minute) : débits, états, pertes
par étage et étage limitant (voir fer_losses).
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


def prods(t):
    out = {}
    for kv in t.get("produits", "-").split(","):
        k, _, v = kv.partition(":")
        if v.isdigit():
            out[k] = int(v)
    return out


def dead(r):
    if "troncons_morts" not in r:
        return "-"
    return f'{r["troncons_morts"]} ({r.get("foreuses_mortes", "0")} ; {r.get("morts", "-")})'


# Lot DEBIT-FER : lignes [FO-DEBIT-FER] (bilan du fer par équipe et par minute, pavage_common.lua).
FER_TAG = "[FO-DEBIT-FER] "


def parse_fer(path):
    f, real = open_log(path)
    out = []
    with f:
        for line in f:
            i = line.find(FER_TAG)
            if i < 0 or "ERREUR" in line[i:i + 40]:
                continue
            d = dict(re.findall(r"(\w+)=(\S+)", line[i + len(FER_TAG):]))
            if "minute" in d and "equipe" in d:
                out.append(d)
    return out, real


def kvmap(s):
    out = {}
    for kv in (s or "-").split(","):
        k, _, v = kv.partition(":")
        try:
            out[k] = float(v)
        except ValueError:
            pass
    return out


# Pertes par étage, en minerai ou plaques par minute au débit nominal (fer : une plaque par minerai) :
#   courant     foreuses de fer no_power, et la part non extraite du débit nominal des low_power (extraction freinée par le réseau) ;
#   epuise      foreuses de fer no_minable_resources ;
#   aval        foreuses de fer waiting_for_space_in_destination (le tapis ou le four ne prend plus le minerai), moins la part
#               expliquée par les fours de fer sortie pleine ;
#   minerai     fours de fer no_ingredients (four qui attend le minerai : extraction ou transport du minerai) ;
#   combustible fours de fer no_fuel ;
#   sortie      fours de fer full_output (bras, tapis ou coffre de sortie saturé) ;
#   coffres     plaques qui s'accumulent dans les coffres de sortie (débit vers le QG insuffisant), par minute.
# Étage limitant = la plus grande perte. Ce n'est pas un modèle exact : c'est un ordre de grandeur pour chiffrer où le fer s'arrête.
STAGES = ("courant", "epuise", "aval", "minerai", "combustible", "sortie", "coffres")


def fer_losses(r, prev):
    dc, fc = kvmap(r.get("foreuses_cap")), kvmap(r.get("fours_cap"))
    L = dict.fromkeys(STAGES, 0.0)
    # low_power : la foreuse tourne au ralenti ; sa perte est la part de son débit nominal que le minerai extrait sur la minute
    # (au-delà des foreuses au travail) ne couvre pas
    got = 0.0
    if prev and int(r["minute"]) > int(prev["minute"]):
        got = (num(r, "minerai_extrait") - num(prev, "minerai_extrait")) / (int(r["minute"]) - int(prev["minute"]))
    low = dc.get("low_power", 0)
    L["courant"] = dc.get("no_power", 0) + max(0.0, low - max(0.0, got - dc.get("working", 0)))
    L["epuise"] = dc.get("no_minable_resources", 0)
    L["sortie"] = fc.get("full_output", 0)
    L["aval"] = max(0.0, dc.get("waiting_for_space_in_destination", 0) - L["sortie"])
    L["minerai"] = fc.get("no_ingredients", 0)
    L["combustible"] = fc.get("no_fuel", 0)
    if prev:
        dt = int(r["minute"]) - int(prev["minute"])
        if dt > 0:
            L["coffres"] = max(0.0, (num(r, "plaques_coffres_sortie") - num(prev, "plaques_coffres_sortie")) / dt)
    return L, dc, fc


def fer_report(path, minutes):
    rows, real = parse_fer(path)
    if not rows:
        sys.exit("aucune ligne [FO-DEBIT-FER] dans " + real)
    by = {}
    for r in rows:
        by.setdefault(r["equipe"], {})[int(r["minute"])] = r
    print(f"Journal : {real} ; bilan du fer (lot DEBIT-FER), débits sur la minute écoulée\n")
    print("| équipe | min | minerai/min | plaques/min | consommées/min | cap. foreuses (dont au travail) | cap. fours (dont au travail) "
          "| foreuses de fer | fours de fer | coffres de sortie | QG | tapis (plaques ; minerai) | pertes /min (courant, épuisé, aval, minerai, "
          "combustible, sortie, coffres) | étage limitant |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    sums = {}
    for team in sorted(by):
        ms = by[team]
        for m in minutes:
            r, p = ms.get(m), ms.get(m - 1)
            if not r:
                continue
            L, dc, fc = fer_losses(r, p)
            rate = lambda k: (num(r, k) - num(p, k)) if p else 0
            stage = max(STAGES, key=lambda k: L[k]) if max(L.values()) > 0 else "-"
            s = sums.setdefault(m, {"ore": 0, "pl": 0, "L": dict.fromkeys(STAGES, 0.0)})
            s["ore"] += rate("minerai_extrait")
            s["pl"] += rate("plaques_produites")
            for k in STAGES:
                s["L"][k] += L[k]
            print(f'| {team} | {m} | {rate("minerai_extrait")} | {rate("plaques_produites")} | {rate("plaques_consommees")} | '
                  f'{sum(dc.values()):.0f} ({dc.get("working", 0):.0f}) | {sum(fc.values()):.0f} ({fc.get("working", 0):.0f}) | '
                  f'{r.get("foreuses", "-")} | {r.get("fours", "-")} | {r.get("plaques_coffres_sortie", "-")} ({r.get("coffres_sortie", "-")}) | '
                  f'{r.get("plaques_qg", "-")} | {r.get("plaques_tapis", "-")} ; {r.get("minerai_tapis", "-")} | '
                  + ", ".join(f"{L[k]:.0f}" for k in STAGES) + f" | {stage} |")
    print()
    for m in sorted(sums):
        s = sums[m]
        st = max(STAGES, key=lambda k: s["L"][k])
        print(f'- minute {m}, toutes équipes : minerai {s["ore"]}/min, plaques {s["pl"]}/min ; pertes '
              + ", ".join(f"{k} {s['L'][k]:.0f}" for k in STAGES) + f" ; étage limitant : {st}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("journal")
    ap.add_argument("--minute", type=int)
    ap.add_argument("--min-tuiles", type=int, default=0)
    ap.add_argument("--touches", action="store_true")
    ap.add_argument("--phase", default="T", help="T (mesure au tick T, défaut) ou capture (re-mesure au tick de chaque capture)")
    ap.add_argument("--fer", nargs="?", const="20,40,60", help="lot DEBIT-FER : bilan du fer aux minutes données (défaut 20,40,60)")
    a = ap.parse_args()
    if a.fer:
        return fer_report(a.journal, [int(x) for x in a.fer.split(",")])
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
    cum = {}
    for t in [t for t in teams if int(t["minute"]) == minute]:  # équipes : relevé du tick T
        now = prods(t)
        prev = [u for u in teams if u["equipe"] == t["equipe"] and int(u["minute"]) < minute]
        prev = max(prev, key=lambda u: int(u["minute"])) if prev else None
        dt = minute - int(prev["minute"]) if prev else 0
        before = prods(prev) if prev else {}
        txt = []
        for k in sorted(now):
            rate = (now[k] - before.get(k, 0)) / dt if dt else 0
            txt.append(f"{k} {now[k]} ({rate:.0f}/min)")
            c = cum.setdefault(k, [0, 0.0])
            c[0] += now[k]
            c[1] += rate
        if txt:
            print(f'- {t["equipe"]} : produits ' + ", ".join(txt))
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
    if cum:
        print("- toutes équipes : produits " + ", ".join(f"{k} {v[0]} ({v[1]:.0f}/min)" for k, v in sorted(cum.items())))
    tot = [r for r in alls]
    print(f'\nTotal : tronçons morts {sum(num(r, "troncons_morts") for r in tot)} ({sum(num(r, "foreuses_mortes") for r in tot)} foreuses), '
          f'souterrains seuls {sum(num(r, "souterrains_seuls") for r in tot)}, fantômes {sum(num(r, "fantomes") for r in tot)}, '
          f'foreuses en attente de place {sum(waiting(r) for r in tot)}, entités interdites sur minerai {sum(int(r["interdites"]) for r in tot)}')


if __name__ == "__main__":
    main()
