#!/usr/bin/env python
"""Lot ENERGIE (2/11) : mesures de la centrale d'une partie, lues dans le journal d'une archive de banc (benchmark.log ou .gz).

Usage :  PYTHONUTF8=1 py -3.9 -B tools/autotest/energie_mesures.py <archive> [<archive> ...] [--json]

Pour chaque équipe (votre équipe et les factions) :
  - 1er courant (minutes) : ligne [FO-PLANDIR] « 1er courant » ;
  - minutes SANS COURANT : lignes [FO-RESEAU] « centrale: production nulle, source(s) a sec » (une toutes les 0,3 min de jeu tant que la
    panne dure) x 0,3 ; la plus longue panne continue (lignes de suite a moins de 1 min l'une de l'autre) ;
  - marge de production : bilans [FO-ENERGIE] « bilan a X min » dont la charge atteint 90 % (centrale saturee), sur tous les bilans ;
  - dernier bilan : production, capacite, centrales finies ; chaudieres vivantes au dernier [FO-RESEAU] « synthese » (sources) ;
  - lot ENERGIE seulement : amorces a la main, modules retenus par la porte, centrales de plus demandees avant la saturation.
Le journal n'est pas filtre par graine : une archive = une partie. Erreurs de script : lignes « Error » / « error while running ».
"""
import gzip
import json
import os
import re
import sys

BILAN = re.compile(r"\[FO-ENERGIE\] (\S+) : bilan a ([\d.]+) min : production (\d+) kW, capacite (\d+) kW, charge (\d+) % .*?, (\d+) centrale\(s\) finie\(s\), (\d+) en projet")
SECHE = re.compile(r"\[FO-RESEAU\] (\S+) : centrale: production nulle, source\(s\) a sec .* a ([\d.]+) min")
SYNTH = re.compile(r"\[FO-RESEAU\] (\S+) : synthese : centrale (\S+), production (\d+) kW, sources (\d+)/(\d+) a sec (\d+)")
SATURE = re.compile(r"\[FO-ENERGIE\] (\S+) : centrale saturee a ([\d.]+) min")
COURANT = re.compile(r"\[FO-PLANDIR\] (\S+) : centrale, 1er courant a ([\d.]+) min")
AMORCE = re.compile(r"\[FO-SANTE-CENTRALE\] (\S+) : centrale \S+ a ([\d.]+) min : amorce a la main")
RETENU = re.compile(r"\[FO-SANTE-CENTRALE\] (\S+) : projet \S+ retenu a ([\d.]+) min")
AVANCE = re.compile(r"\[FO-SANTE-CENTRALE\] (\S+) : centrale de plus demandee a ([\d.]+) min AVANT la saturation")
BLOQUEE = re.compile(r"\[FO-SANTE-CENTRALE\] (\S+) : reconstruction de la centrale")
CHAMP = re.compile(r"\[FO-CHAMP-VAPEUR\] (\S+) : (champ de|centrale perdue)")
MORT = re.compile(r"\[FO-CENTRALE-MORT\] minute ([\d.]+) \| force fo-(\S+) \|")
ERR = re.compile(r"(Error while running event|\bError\b.*(script|lua)|attempt to (index|call|compare|perform))", re.I)
GAP_MAX = 1.0  # minutes : deux lignes « a sec » plus proches font la meme panne


def lire(chemin):
    for nom in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(chemin, nom)
        if os.path.exists(p):
            op = gzip.open if p.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as f:
                return f.read().splitlines()
    return []


def mesurer(chemin):
    lignes = lire(chemin)
    eq = {}

    def e(k):
        return eq.setdefault(k, {"sec": [], "bilans": [], "synth": None, "courant": None, "amorces": 0, "retenus": 0, "avance": 0,
                                 "bloquee": 0, "champs": 0, "morts": 0, "saturee": []})

    erreurs = []
    for ln in lignes:
        m = BILAN.search(ln)
        if m:
            e(m.group(1))["bilans"].append((float(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)), int(m.group(6)), int(m.group(7))))
            continue
        m = SECHE.search(ln)
        if m:
            e(m.group(1))["sec"].append(float(m.group(2)))
            continue
        m = SYNTH.search(ln)
        if m:
            e(m.group(1))["synth"] = (m.group(2), int(m.group(3)), int(m.group(4)), int(m.group(5)), int(m.group(6)))
            continue
        m = COURANT.search(ln)
        if m:
            e(m.group(1))["courant"] = float(m.group(2))
            continue
        m = SATURE.search(ln)
        if m:
            e(m.group(1))["saturee"].append(float(m.group(2)))
            continue
        for rx, cle in ((AMORCE, "amorces"), (RETENU, "retenus"), (AVANCE, "avance"), (BLOQUEE, "bloquee"), (CHAMP, "champs")):
            m = rx.search(ln)
            if m:
                e(m.group(1))[cle] += 1
                break
        else:
            m = MORT.search(ln)
            if m:
                e(m.group(2))["morts"] += 1
            elif ERR.search(ln) and "FO-" not in ln[:60] and len(erreurs) < 5:
                erreurs.append(ln.strip()[:200])
    out = {}
    for k, d in sorted(eq.items()):
        sec = sorted(set(d["sec"]))
        longest, cur, start, prev = 0.0, 0.0, None, None
        for t in sec:
            if prev is None or t - prev > GAP_MAX:
                start = t
            cur = t - start + 0.3
            longest = max(longest, cur)
            prev = t
        b = d["bilans"]
        sat = sum(1 for x in b if x[3] >= 90)
        out[k] = {
            "1er_courant_min": d["courant"],
            "min_sans_courant": round(len(sec) * 0.3, 1),
            "plus_longue_panne_min": round(longest, 1),
            "bilans": len(b),
            "bilans_satures": sat,
            "evenements_saturee": len(d["saturee"]),
            "part_saturee": round(sat / len(b), 2) if b else None,
            "dernier_bilan": {"min": b[-1][0], "production_kw": b[-1][1], "capacite_kw": b[-1][2], "charge_pct": b[-1][3], "centrales_finies": b[-1][4], "en_projet": b[-1][5]} if b else None,
            "chaudieres_vivantes": d["synth"][3] if d["synth"] else None,
            "chaudieres_a_sec": d["synth"][4] if d["synth"] else None,
            "amorces": d["amorces"], "retenus": d["retenus"], "centrales_avant_saturation": d["avance"], "reconstructions_bloquees": d["bloquee"],
            "champs_ou_pertes": d["champs"], "pieces_de_centrale_mortes": d["morts"],
        }
    return {"archive": chemin, "lignes": len(lignes), "equipes": out, "erreurs": erreurs}


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 2
    res = [mesurer(a) for a in args]
    if "--json" in argv:
        print(json.dumps(res, indent=1, ensure_ascii=False))
        return 0
    for r in res:
        print("== %s (%d lignes)" % (r["archive"], r["lignes"]))
        for k, d in r["equipes"].items():
            print("  %-9s courant %-5s | sans courant %5.1f min (plus longue %4.1f) | saturee (evenements) %d, bilans >= 90 %% %s/%s | dernier %s | chaudieres %s (a sec %s) | amorces %d retenus %d avance %d bloquees %d champs %d morts %d"
                  % (k, d["1er_courant_min"], d["min_sans_courant"], d["plus_longue_panne_min"], d["evenements_saturee"], d["bilans_satures"], d["bilans"],
                     ("%d/%d kW %d%% %d centrale(s)" % (d["dernier_bilan"]["production_kw"], d["dernier_bilan"]["capacite_kw"], d["dernier_bilan"]["charge_pct"], d["dernier_bilan"]["centrales_finies"])) if d["dernier_bilan"] else "-",
                     d["chaudieres_vivantes"], d["chaudieres_a_sec"], d["amorces"], d["retenus"], d["centrales_avant_saturation"],
                     d["reconstructions_bloquees"], d["champs_ou_pertes"], d["pieces_de_centrale_mortes"]))
        if r["erreurs"]:
            print("  ERREURS : " + " | ".join(r["erreurs"]))
        else:
            print("  aucune erreur de script")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
