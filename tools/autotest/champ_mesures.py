# Lot CHAMP : lecture des relevés [FO-CHAMP-MESURE] d'une ou plusieurs archives de banc (scénario champ-croissance) contre
# fo-logs/2026-11-02_CHAMP/CRITERES.md (C1 à C6). Usage :
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/champ_mesures.py <archive> [<archive> ...]
# Une archive = un dossier de banc.py --out (benchmark.log ou benchmark.log.gz). Imprime, par archive : C1 part électrique fer +
# cuivre (factions), C2 couverture électrique du gisement le plus couvert (fer, cuivre) par faction, C3 foreuses figées, C4 fours
# sans entrée, C5 rapport cuivre / fer, C6 bilan du scénario et erreurs Lua.
import gzip
import os
import re
import statistics
import sys

FACTIONS = ("scarlet", "azure", "emerald", "amber")
LINE = re.compile(r"\[FO-CHAMP-MESURE\] minute ([\d.]+) \| (\w+) \| foreuses (.*?) \| gisements \[(.*?)\] \| figees (\d+)/(\d+) electriques"
                  r" \| tapis minerai (\d+) pleins (\d+) \| fours marche (\d+) sans_entree (\d+) sortie_pleine (\d+) sans_combustible (\d+)"
                  r" autre (\d+) \| fer (\S+)/min cuivre (\S+)/min rapport (\S+)")
DRILL = re.compile(r"(\S+) (\d+)/(\d+) \(")
DEP = re.compile(r"(\S+)@(-?\d+),(-?\d+) (\d+) tuiles elec (\d+)% tout (\d+)%")


def read_log(folder):
    for name in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(folder, name)
        if os.path.exists(p):
            op = gzip.open if name.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read()
    return ""


def parse(text):
    rows = []
    for m in LINE.finditer(text):
        drills = {d[0]: (int(d[1]), int(d[2])) for d in DRILL.findall(m.group(3))}
        deps = [(d[0], int(d[3]), int(d[4]), int(d[5])) for d in DEP.findall(m.group(4))]
        rows.append({
            "minute": float(m.group(1)), "team": m.group(2), "drills": drills, "deps": deps,
            "stuck": int(m.group(5)), "elec": int(m.group(6)), "belts": int(m.group(7)), "full": int(m.group(8)),
            "f_work": int(m.group(9)), "f_noin": int(m.group(10)), "f_full": int(m.group(11)), "f_nofuel": int(m.group(12)),
            "iron": None if m.group(14) == "-" else float(m.group(14)),
            "copper": None if m.group(15) == "-" else float(m.group(15)),
        })
    return rows


def summary(folder):
    text = read_log(folder)
    rows = parse(text)
    out = {"folder": folder, "rows": len(rows)}
    if not rows:
        return out
    last_min = max(r["minute"] for r in rows)
    minutes = sorted({r["minute"] for r in rows})
    last4 = set(minutes[-4:])
    e = t = 0
    per = {}
    for r in rows:
        if r["minute"] == last_min and r["team"] in FACTIONS:
            for ore in ("iron-ore", "copper-ore"):
                de, db = r["drills"].get(ore, (0, 0))
                e, t = e + de, t + de + db
                best = max([d[2] for d in r["deps"] if d[0] == ore] or [0])
                per[(r["team"], ore)] = (de, de + db, best)
    out["c1"] = (e, t, 100.0 * e / t if t else 0.0)
    out["c2"] = per
    st = [r for r in rows if r["minute"] in last4 and r["team"] in FACTIONS]
    out["c3"] = (sum(r["stuck"] for r in st) / max(1, len(st)), sum(r["elec"] for r in st) / max(1, len(st)))
    out["c4"] = (sum(r["f_noin"] for r in st) / max(1, len(st)), sum(r["f_work"] + r["f_noin"] + r["f_full"] + r["f_nofuel"] for r in st) / max(1, len(st)))
    out["c4_full"] = sum(r["f_full"] for r in st) / max(1, len(st))
    out["c5"] = {r["team"]: (r["iron"], r["copper"]) for r in rows if r["minute"] == last_min}
    out["bilan"] = re.findall(r"\[FO-CHAMP-CROISSANCE\] BILAN : [^\n]*", text)
    out["errors"] = len(re.findall(r"Error|erreur Lua", text))
    out["champ"] = len(re.findall(r"\[FO-CHAMP\]", text))
    out["bandes"] = len(re.findall(r"bande \S+ du champ demandee", text))
    out["produit"] = len(re.findall(r"la ligne neuve du projet \d+ produit", text))
    return out


def main():
    for folder in sys.argv[1:]:
        s = summary(folder)
        print("== %s (%d releves)" % (s["folder"], s["rows"]))
        if not s["rows"]:
            continue
        e, t, p = s["c1"]
        print("C1 part electrique fer + cuivre (factions) : %d / %d = %.0f %%" % (e, t, p))
        print("C2 couverture electrique du gisement le plus couvert :")
        for (team, ore), (de, n, best) in sorted(s["c2"].items()):
            print("   %-8s %-10s foreuses elec %d / %d, gisement le plus couvert %d %%" % (team, ore, de, n, best))
        st, el = s["c3"]
        print("C3 foreuses figees (moy. 4 derniers releves, par faction) : %.1f / %.1f electriques" % (st, el))
        ni, tot = s["c4"]
        print("C4 fours sans entree (moy.) : %.1f / %.1f ; sortie pleine (FLUX) : %.1f" % (ni, tot, s["c4_full"]))
        print("C5 rapport cuivre / fer (dernier releve) :")
        for team, (ir, cr) in sorted(s["c5"].items()):
            ratio = (cr / ir) if (ir and cr is not None and ir > 0) else None
            print("   %-8s fer %s/min cuivre %s/min rapport %s" % (team, ir, cr, "%.2f" % ratio if ratio is not None else "-"))
        print("C6 %s ; erreurs %d ; lignes [FO-CHAMP] %d, bandes demandees %d, bandes qui produisent %d" % (
            "; ".join(s["bilan"]) or "pas de BILAN", s["errors"], s["champ"], s["bandes"], s["produit"]))


if __name__ == "__main__":
    main()
