# Lot DEFENSE : lecture des archives du scenario dc-defense (tools/autotest/fo-autotest/scenarios/dc-defense.lua) et comparaison
# temoin / essai selon fo-logs/2026-11-02_DEFENSE/CRITERES.md.
# Usage : py -3.9 -B tools/autotest/defense_mesures.py --temoin <dossier> [<dossier>...] --essai <dossier> [<dossier>...]
#   chaque dossier : une archive banc.py (benchmark.log.gz ou benchmark.log). Les grandeurs sont rendues pour les FACTIONS seules, pour VOTRE
#   EQUIPE seule et pour le total (le critere du lot porte sur le total ; les factions et votre equipe n'ont pas le meme comportement).
import argparse
import gzip
import re
import sys
from pathlib import Path

MES = re.compile(r"\[FO-DEF-MESURE\] minute (\d+) \| (\S+) \| tourelles=(\d+) pres_qg15=(\d+) pres_qg40=(\d+) pieces_prod=(\d+)(?: couvertes=(\d+) assembleurs=(\d+) assembleurs_couverts=(\d+))?")
PERTE = re.compile(r"\[FO-DEF-PERTE\] (\S+) \| vagues=(\d+) \| pieces_prod_perdues=(\d+) dont_hors_portee_de_tourelle=(\d+) \| "
                   r"tourelles_perdues=(\d+) \| pire_vague_prod=(\d+) pire_vague_tourelles=(\d+)")
VIVANTES = re.compile(r"\[FO-DEF-PERTE\] TOTAL .* factions_vivantes=(-?\d+)")


def lire(dossier):
    d = Path(dossier)
    for nom in ("benchmark.log.gz", "benchmark.log"):
        p = d / nom
        if p.exists():
            op = gzip.open if nom.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as f:
                return f.read().splitlines()
    sys.exit("aucun benchmark.log dans " + str(d))


def groupe(cle):
    return "equipe" if cle == "player" else "factions"


def resume(dossier):
    """{groupe: {tour, pres, prod_perdu, hors, vagues, tur_perdues}} + vivantes."""
    out = {g: dict(tour=0, pres=0, prod_perdu=0, hors=0, vagues=0, tur_perdues=0, pieces=0, couv=0, asm=0, asm_couv=0) for g in ("factions", "equipe")}
    mes, vivantes = {}, -1
    for l in lire(dossier):
        m = MES.search(l)
        if m:
            mes.setdefault(m.group(2), {})[int(m.group(1))] = tuple(int(m.group(i) or 0) for i in (3, 4, 6, 7, 8, 9))
        m = PERTE.search(l)
        if m and m.group(1) != "TOTAL":
            g = out[groupe(m.group(1))]
            g["vagues"] += int(m.group(2))
            g["prod_perdu"] += int(m.group(3))
            g["hors"] += int(m.group(4))
            g["tur_perdues"] += int(m.group(5))
        m = VIVANTES.search(l)
        if m:
            vivantes = int(m.group(1))
    for cle, par_minute in mes.items():
        tour, pres, pieces, couv, asm, asm_couv = par_minute[max(par_minute)]
        g = out[groupe(cle)]
        g["tour"] += tour
        g["pres"] += pres
        g["pieces"] += pieces
        g["couv"] += couv
        g["asm"] += asm
        g["asm_couv"] += asm_couv
    return out, vivantes


PIECE = re.compile(r"\[FO-DEF-PIECE\] minute ([\d.]+) \| (\S+) \| (\S+) \((\S+)\) en \((-?\d+), (-?\d+)\) a (\d+) tuiles du QG \| "
                   r"tourelle vivante la plus proche : (aucune a 80 tuiles|\d+ tuiles) \| (HORS PORTEE|a portee)")


def pertes(dossiers):
    """Positions des pertes contre positions des tourelles : tranche de distance a la tourelle vivante la plus proche, par groupe et par type.
    Le journal garde les 120 premieres pertes par equipe (cause : echantillon, pas le total)."""
    tranches = [("aucune a 80 tuiles", None), ("40 a 80 tuiles", (40, 81)), ("19 a 39 tuiles", (19, 40)), ("<= 18 tuiles (a portee)", (0, 19))]
    cpt, types, qg = {}, {}, {}
    for d in dossiers:
        for l in lire(d):
            m = PIECE.search(l)
            if not m or m.group(3) == "":
                continue
            g, typ, dqg, near = groupe(m.group(2)), m.group(4), int(m.group(7)), m.group(8)
            if typ in ("ammo-turret", "electric-turret", "fluid-turret"):
                continue
            dist = None if near.startswith("aucune") else int(near.split()[0])
            for nom, rng in tranches:
                if (rng is None and dist is None) or (rng is not None and dist is not None and rng[0] <= dist < rng[1]):
                    cpt[(g, nom)] = cpt.get((g, nom), 0) + 1
                    break
            types[(g, typ)] = types.get((g, typ), 0) + 1
            qg.setdefault(g, []).append(dqg)
    for g in ("factions", "equipe"):
        tot = sum(v for (gg, _), v in cpt.items() if gg == g)
        if not tot:
            continue
        print(f"PERTES {g} (pieces de production, echantillon journal) : {tot}")
        for nom, _ in tranches:
            n = cpt.get((g, nom), 0)
            print(f"   tourelle vivante la plus proche : {nom:26s} {n:4d} ({pct(n, tot):3.0f} %)")
        print("   par type : " + ", ".join(f"{t}={v}" for (gg, t), v in sorted(types.items()) if gg == g))
        ds = sorted(qg[g])
        print(f"   distance au QG : mediane {ds[len(ds) // 2]} tuiles, <= 15 tuiles {pct(sum(1 for x in ds if x <= 15), len(ds)):.0f} %, > 40 tuiles {pct(sum(1 for x in ds if x > 40), len(ds)):.0f} %")


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def add(a, b):
    return {k: a[k] + b[k] for k in a}


def ligne(nom, g):
    return (f"{nom:9s} A {pct(g['pres'], g['tour']):3.0f} % ({g['pres']}/{g['tour']}) | B {pct(g['hors'], g['prod_perdu']):3.0f} % "
            f"({g['hors']}/{g['prod_perdu']}) | C {g['prod_perdu'] / g['vagues'] if g['vagues'] else 0:4.1f} par vague ({g['prod_perdu']}/{g['vagues']}) "
            f"| E tourelles perdues {g['tur_perdues']} | F pieces couvertes {pct(g['couv'], g['pieces']):3.0f} % ({g['couv']}/{g['pieces']}) "
            f"| G assembleurs couverts {pct(g['asm_couv'], g['asm']):3.0f} % ({g['asm_couv']}/{g['asm']})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--temoin", nargs="+", required=True)
    ap.add_argument("--essai", nargs="*", default=[])
    ap.add_argument("--pertes", action="store_true", help="positions des pertes contre positions des tourelles (temoin puis essai)")
    a = ap.parse_args()
    cumul = {}
    for tag, dossiers in (("temoin", a.temoin), ("essai", a.essai)):
        tot = {g: dict(tour=0, pres=0, prod_perdu=0, hors=0, vagues=0, tur_perdues=0, pieces=0, couv=0, asm=0, asm_couv=0) for g in ("factions", "equipe")}
        viv = 0
        for d in dossiers:
            r, v = resume(d)
            print(f"[{tag}] {Path(d).name}  factions vivantes {v}")
            print("   " + ligne("factions", r["factions"]))
            print("   " + ligne("equipe", r["equipe"]))
            tot = {g: add(tot[g], r[g]) for g in tot}
            viv += v
        cumul[tag] = (tot, viv)
    for tag in ("temoin", "essai"):
        if tag not in cumul or not cumul[tag][0]["factions"]["tour"]:
            continue
        tot, viv = cumul[tag]
        print(f"CUMUL {tag} (factions vivantes {viv})")
        print("   " + ligne("factions", tot["factions"]))
        print("   " + ligne("equipe", tot["equipe"]))
        print("   " + ligne("total", add(tot["factions"], tot["equipe"])))
        if a.pertes:
            pertes(a.temoin if tag == "temoin" else a.essai)


if __name__ == "__main__":
    main()
