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


ORES = ("iron-ore", "copper-ore")


def crit(rel, minute):
    """Critères C1 à C5 de CRITERES.md lus sur les relevés REGARD (mêmes lignes pour le témoin et le lot), factions vivantes à `minute`.
    C1 part électrique fer + cuivre ; C2 médiane, par faction et minerai qui ont des foreuses électriques, de la couverture électrique du
    gisement le plus couvert ; C3 foreuses électriques fer + cuivre bloquées en sortie / électriques, moyenne des 4 derniers relevés ; C4 fours
    sans entrée, moyenne des 4 derniers relevés (somme des factions) ; C5 plaques cuivre / fer par faction (flux du relevé)."""
    de = dt = 0
    cov, c3n, c3d, c4, c5 = [], [], [], [], {}
    for force in sorted(rel):
        if force not in FACTIONS:
            continue
        keys = sorted(k for k in rel[force] if k <= minute)
        if not keys or keys[-1] < minute - 5:
            continue
        r = rel[force][keys[-1]]
        G = [g for g in r["G"] if g.get("res") in ORES]
        if not G and not r.get("F"):
            continue
        de += sum(g.get("de", 0) for g in G)
        dt += sum(g.get("dt", 0) for g in G)
        for ore in ORES:
            ex = [100.0 * g.get("couv_e", 0) / g["tuiles"] for g in G if g.get("res") == ore and g.get("de", 0) > 0 and g.get("tuiles")]
            if ex:
                cov.append(max(ex))
        for k in keys[-4:]:
            rr = rel[force][k]
            GG = [g for g in rr["G"] if g.get("res") in ORES]
            c3n.append(sum(g.get("de_pleine", 0) for g in GG))
            c3d.append(sum(g.get("de", 0) for g in GG))
        c4.append(sum(rel[force][k].get("F", {}).get("sans_entree", 0) for k in keys[-4:]) / max(1, len(keys[-4:])))
        flux = (r.get("R") or {}).get("flux_min", {})
        fe, cu = flux.get("iron-plate"), flux.get("copper-plate")
        if fe and fe > 0:
            c5[force[3:]] = (cu or 0) / fe
    cov.sort()
    med = (cov[len(cov) // 2] if len(cov) % 2 else (cov[len(cov) // 2 - 1] + cov[len(cov) // 2]) / 2) if cov else None
    return {"c1": (de, de + dt, 100.0 * de / (de + dt) if de + dt else None), "c2": (med, len(cov)),
            "c3": (sum(c3n), sum(c3d), 100.0 * sum(c3n) / sum(c3d) if sum(c3d) else None), "c4": sum(c4), "c5": c5}


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
        for mn in mins:
            c = crit(rel, mn)
            e, t, p = c["c1"]
            print("  criteres min %d : C1 %d/%d = %s %% | C2 mediane %s %% (%d cas) | C3 %d/%d = %s %% figees | C4 fours sans entree %.1f | C5 %s"
                  % (mn, e, t, fmt(p), fmt(c["c2"][0]), c["c2"][1], c["c3"][0], c["c3"][1], fmt(c["c3"][2]), c["c4"],
                     " ".join("%s %.2f" % (k, v) for k, v in sorted(c["c5"].items())) or "-"))


if __name__ == "__main__":
    main()
