"""Lot ADOPTE : compare VOTRE EQUIPE entre la base commune (lot MESURES) et le lot, graine par graine, sur les lignes
[FO-FONCTION] (jamais dans un BILAN). Usage :
  PYTHONUTF8=1 py -3.9 -B tools/autotest/adopte_compare.py <dossier base> <dossier lot> [graine ...]
où <dossier base> contient base-<graine>/ et <dossier lot> contient lot-<graine>/ (benchmark.log.gz). Critères écrits avant la
mesure (ordre du DC, 28/10) : foreuses au coffre, foreuses électriques ET à combustion EN MARCHE à 40 et 60 min (statut),
fer livré par tranche de 10 min (fer_min x 10), plus la recherche et la défense (pas de baisse). Distribution par graine."""
import gzip
import re
import statistics
import sys

MINUTES = (20, 40, 60)


def load(path):
    return gzip.open(path + "/benchmark.log.gz", "rt", encoding="utf-8", errors="replace").read().split("\n")


def kv(s):
    return {m.group(1): m.group(2) for m in re.finditer(r"(\w+)=(\S+)", s)}


def player(path):
    out = {m: {} for m in range(10, 61, 10)}
    for l in load(path):
        m = re.search(r"\[FO-FONCTION\] (\w+) minute (\d+) \| player \| (.*)", l)
        if not m:
            continue
        g, minute, rest = m.group(1), int(m.group(2)), m.group(3)
        if minute not in out:
            continue
        d = out[minute]
        if g == "statut":
            k = kv(rest)
            cl = k.get("classe")
            n = int(k.get("samples", 0))
            d["w_" + cl] = (100.0 * int(k.get("working", 0)) / n) if n else None
            d["n_" + cl] = int(k.get("n", 0))
        else:
            for a, b in kv(rest).items():
                d[g + "." + a] = b
    return out


def num(d, key):
    try:
        return float(d.get(key))
    except (TypeError, ValueError):
        return None


def row(label, vals, fmt="%.0f"):
    return "    %-46s" % label + "".join(("%10s" % (fmt % v if v is not None else "-")) for v in vals)


def main():
    base_dir, lot_dir = sys.argv[1], sys.argv[2]
    seeds = sys.argv[3:] or ["20261020", "123456789", "271828182", "1618033988"]
    agg = {}
    for s in seeds:
        b = player("%s/base-%s" % (base_dir, s))
        l = player("%s/lot-%s" % (lot_dir, s))
        print("=" * 100)
        print("graine %s : colonnes = minutes %s (base | lot)" % (s, ",".join(map(str, MINUTES))))
        spec = [
            ("foreuses au coffre (coffre+corps)", lambda d: (num(d, "dormants.stock_coffre_foreuses") or 0) + (num(d, "dormants.stock_corps_foreuses") or 0)),
            ("fours au coffre (coffre+corps)", lambda d: (num(d, "dormants.stock_coffre_fours") or 0) + (num(d, "dormants.stock_corps_fours") or 0)),
            ("foreuses electriques posees", lambda d: num(d, "n_foreuse_elec")),
            ("foreuses electriques en marche %", lambda d: d.get("w_foreuse_elec")),
            ("foreuses a combustion posees", lambda d: num(d, "n_foreuse_comb")),
            ("foreuses a combustion en marche %", lambda d: d.get("w_foreuse_comb")),
            ("fer livre (plaques de fer / 10 min)", lambda d: (num(d, "prod.fer_min") or 0) * 10 if num(d, "prod.fer_min") is not None else None),
            ("plaques / min (fer+cuivre+brique)", lambda d: num(d, "prod.plaques_min")),
            ("minerai de fer / min", lambda d: num(d, "prod.ore_fer_min")),
            ("technologies terminees", lambda d: num(d, "tech.researched")),
            ("tourelles posees", lambda d: num(d, "tourelles.n")),
            ("tourelles armees", lambda d: num(d, "tourelles.armees")),
            ("PNJ vivants", lambda d: num(d, "prod.pnj")),
            ("labo en marche %", lambda d: d.get("w_labo")),
        ]
        for name, f in spec:
            bv = [f(b[m]) for m in MINUTES]
            lv = [f(l[m]) for m in MINUTES]
            print(row(name + " | base", bv))
            print(row(name + " | lot", lv))
            agg.setdefault(name, {"b": {m: [] for m in MINUTES}, "l": {m: [] for m in MINUTES}})
            for m, x, y in zip(MINUTES, bv, lv):
                if x is not None:
                    agg[name]["b"][m].append(x)
                if y is not None:
                    agg[name]["l"][m].append(y)
        fer_b = [num(b[m], "prod.fer_min") for m in range(10, 61, 10)]
        fer_l = [num(l[m], "prod.fer_min") for m in range(10, 61, 10)]
        print("    fer livre par tranche de 10 min (fer/min x 10), minutes 10..60 :")
        print("      base : " + " ".join("%6.0f" % (x * 10) if x is not None else "     -" for x in fer_b))
        print("      lot  : " + " ".join("%6.0f" % (x * 10) if x is not None else "     -" for x in fer_l))
    print("=" * 100)
    print("DISTRIBUTION sur %d graines (mediane [min..max]) ; base puis lot" % len(seeds))
    for name, d in agg.items():
        line = "  %-44s" % name
        for m in MINUTES:
            for tag in ("b", "l"):
                v = d[tag][m]
                line += " %s%d:%s" % (tag, m, ("%.0f[%.0f..%.0f]" % (statistics.median(v), min(v), max(v))) if v else "-")
        print(line)


main()
