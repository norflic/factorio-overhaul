# Lot CHAMP : critères du lot exprimés avec les relevés [FO-REGARD] (lot REGARD, scenarios/dc_evolution_common.lua), lisibles sur le
# témoin (dc-croissance sur main) comme sur le lot (champ-longue). Usage :
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/champ_regard.py [--minutes 60,120,150] <archive> [<archive> ...]
# Par archive, force et minute : part électrique des foreuses de fer et de cuivre (de / (de + dt), lignes G), plus grand gisement exploité
# de fer et de cuivre (tuiles, couverture électrique couv_e), minerai extrait contre plaques produites (flux_min de la ligne R),
# rapport cuivre / fer des plaques contre celui des gisements exploités (tuiles), fours en marche, plaques qui dorment dans les fours.
import argparse
import gzip
import os
import re

LINE = re.compile(r"\[FO-REGARD\] (\w) min=(\d+) force=(\S+) (.*)$")
KV = re.compile(r"([\w-]+)=(-?[\d.]+)")
BRACE = re.compile(r"(\w+) \{([^}]*)\}")
FACTIONS = ("fo-scarlet", "fo-azure", "fo-emerald", "fo-amber")


def read(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            op = gzip.open if name.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


def parse(lines):
    rel = {}
    for ln in lines:
        m = LINE.search(ln)
        if not m:
            continue
        kind, minute, force, rest = m.group(1), int(m.group(2)), m.group(3), m.group(4)
        d = {k: float(v) for k, v in KV.findall(rest)}
        for name, body in BRACE.findall(rest):
            d[name] = {k: float(v) for k, v in KV.findall(body)}
        res = re.search(r"res=(\S+)", rest)
        if res:
            d["res"] = res.group(1)
        r = rel.setdefault(force, {}).setdefault(minute, {"G": []})
        if kind == "G":
            r["G"].append(d)
        else:
            r[kind] = d
    return rel


def at(rel_force, minute):
    keys = sorted(k for k in rel_force if k <= minute)
    return (keys[-1], rel_force[keys[-1]]) if keys else (None, None)


def row(r):
    G = [g for g in r["G"] if g.get("res") in ("iron-ore", "copper-ore")]
    de = sum(g.get("de", 0) for g in G)
    dt = sum(g.get("dt", 0) for g in G)
    out = {"share": 100.0 * de / (de + dt) if de + dt else None, "de": de, "dt": dt}
    for ore in ("iron-ore", "copper-ore"):
        ex = [g for g in G if g.get("res") == ore and g.get("de", 0) + g.get("dt", 0) > 0]
        big = max(ex, key=lambda g: g.get("tuiles", 0)) if ex else None
        out[ore] = (int(big["tuiles"]), 100.0 * big.get("couv_e", 0) / big["tuiles"]) if big and big.get("tuiles") else None
        out[ore + "_tiles"] = sum(g.get("tuiles", 0) for g in ex)
    flux = (r.get("R") or {}).get("flux_min", {})
    out["ore_fe"], out["pl_fe"] = flux.get("iron-ore"), flux.get("iron-plate")
    out["ore_cu"], out["pl_cu"] = flux.get("copper-ore"), flux.get("copper-plate")
    F = r.get("F") or {}
    out["fours"] = (int(F.get("marche", 0)), int(F.get("fours", 0)))
    out["dort"] = int(F.get("fer_dort", 0) + F.get("cuivre_dort", 0))
    return out


def fmt(v, f="%.0f"):
    return "-" if v is None else f % v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--minutes", default="60,120,150")
    ap.add_argument("arch", nargs="+")
    a = ap.parse_args()
    mins = [int(x) for x in a.minutes.split(",")]
    for arch in a.arch:
        rel = parse(read(arch))
        print("== %s" % arch)
        print("  force       min  elec%  e/t      fer:tuiles couv_e%  cuivre:tuiles couv_e%  minFe>plFe   minCu>plCu   cu/fe plaques  cu/fe gisements  fours  dort")
        for force in sorted(rel):
            if force not in FACTIONS:
                continue
            for mn in mins:
                m, r = at(rel[force], mn)
                if r is None or m < mn - 5:
                    continue
                o = row(r)
                cf = (o["pl_cu"] / o["pl_fe"]) if o["pl_fe"] else None
                cg = (o["copper-ore_tiles"] / o["iron-ore_tiles"]) if o["iron-ore_tiles"] else None
                fe = o["iron-ore"] or (0, 0)
                cu = o["copper-ore"] or (0, 0)
                print("  %-11s %3d  %5s  %3d/%-4d %6d %5.0f       %6d %5.0f       %5s>%-5s  %5s>%-5s  %6s         %6s           %d/%d  %d" % (
                    force[3:], m, fmt(o["share"]), o["de"], o["dt"], fe[0], fe[1], cu[0], cu[1], fmt(o["ore_fe"]), fmt(o["pl_fe"]),
                    fmt(o["ore_cu"]), fmt(o["pl_cu"]), fmt(cf, "%.2f"), fmt(cg, "%.2f"), o["fours"][0], o["fours"][1], o["dort"]))


if __name__ == "__main__":
    main()
