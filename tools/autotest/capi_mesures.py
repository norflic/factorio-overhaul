# -*- coding: utf-8 -*-
"""Lot CAPIB : mesures du banc capi-partie / capi-temoin (scenarios/capi_common.lua) et du journal [FO-CAPI].

Usage : py -3.9 -B tools/autotest/capi_mesures.py <archive> [<archive> ...] [--csv <fichier>]
Chaque archive est un dossier rendu par banc.py (benchmark.log.gz ou benchmark.log).

Rend, par archive et par faction :
  - la COURBE de capacité toutes les 10 min : foreuses électriques et à combustion, fours, assembleurs, laboratoires,
    minerai extrait et plaques produites dans les 10 min, part des PNJ sans tâche, technologies ;
  - critère (1) : couverture du gisement exploité le plus couvert (tuiles de minerai sous une foreuse ÷ tuiles du
    gisement, relue par le banc) à 30, 60, 90 min ; nombre de gisements exploités (au moins une foreuse) ;
  - critère (2) : fours affamés (part) et foreuses à sortie pleine, par relevé ;
  - critère (3) : gisements exploités au fil du temps (un nouveau après la couverture du premier) ;
  - critère (4) : premier assembleur posé (minute) ; ordres « chaine »/« packs » de la capitalisation ;
  - critère (5) : laboratoires et packs produits par 10 min ;
  - part des PNJ sans tâche de 30 à 90 min.
"""
import gzip
import os
import re
import sys

ORES = ["iron-ore", "copper-ore", "coal", "stone"]
PACKS = ["automation-science-pack", "logistic-science-pack", "military-science-pack"]


def read_log(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            if name.endswith(".gz"):
                with gzip.open(p, "rt", encoding="utf-8", errors="replace") as fh:
                    return fh.read().splitlines()
            with open(p, encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


RE_COURBE = re.compile(r"\[FO-CAPI-(PARTIE|TEMOIN)\] courbe minute (\d+) \| (\S+) \| foreuses_elec=(\d+) foreuses_comb=(\d+) "
                       r"fours=(\d+) assembleurs=(\d+) labos=(\d+) \| n=(\d+) inactifs=([\d.]+)% tech=(-?\d+) \| extrait10 (.*?) \| produit10 (.*)$")
RE_FONTE = re.compile(r"\[FO-CAPI-(?:PARTIE|TEMOIN)\] fonte minute (\d+) \| (\S+) \| fours (\d+) affames (\d+) \| foreuses (\d+) sortie_pleine (\d+)")
RE_GIS = re.compile(r"\[FO-CAPI-(?:PARTIE|TEMOIN)\] gisements minute (\d+) \| (\S+) \| decisions (\d+) ordres (\d+) ouverts (\d+) \[(.*?)\] \| (.*)$")
RE_DEP = re.compile(r"(\S+)\[(\S+)\] tuiles=(\d+)/(\d+) couvertes=(\d+) foreuses=(\d+) \{(.*?)\}")
RE_BILAN = re.compile(r"\[FO-CAPI-(?:PARTIE|TEMOIN)\] BILAN : (.*)$")
RE_CAPI = re.compile(r"\[FO-CAPI\] (\S+) minute (\d+) \| .*?ordres=\[(.*?)\] gisements=")
RE_ORDER_DONE = re.compile(r"\[FO-CAPI\] (\S+) : ordre (\S+) (FINI|ECHOUE) \((.*?)\) apres ([\d.]+) min")
RE_SENT = re.compile(r"\| envoyes \[(.*?)\] \| executant refuse \[(.*?)\]")
RE_TECH_DONE = re.compile(r"\[FO-IA3C\] (\S+) : recherche '(\S+)' terminee a ([\d.]+) min")


def kv(s):
    out = {}
    for part in s.split():
        if "=" in part:
            k, v = part.split("=", 1)
            try:
                out[k] = int(v)
            except ValueError:
                pass
    return out


def analyse(arch):
    lines = read_log(arch)
    res = {"courbe": {}, "fonte": {}, "gis": {}, "bilan": None, "orders": {}, "done": {}, "refused": {}, "tech": {},
           "sent": {}}
    for ln in lines:
        m = RE_COURBE.search(ln)
        if m:
            minute, fk = int(m.group(2)), m.group(3)
            res["courbe"].setdefault(fk, []).append({
                "min": minute, "fe": int(m.group(4)), "fc": int(m.group(5)), "fours": int(m.group(6)),
                "asm": int(m.group(7)), "labos": int(m.group(8)), "n": int(m.group(9)), "idle": float(m.group(10)),
                "tech": int(m.group(11)), "ext": kv(m.group(12)), "prod": kv(m.group(13))})
            continue
        m = RE_FONTE.search(ln)
        if m:
            res["fonte"].setdefault(m.group(2), []).append({"min": int(m.group(1)), "fours": int(m.group(3)),
                                                             "affames": int(m.group(4)), "foreuses": int(m.group(5)),
                                                             "pleines": int(m.group(6))})
            continue
        m = RE_GIS.search(ln)
        if m:
            deps = []
            for d in RE_DEP.finditer(m.group(7)):
                deps.append({"id": d.group(1), "res": d.group(2), "tiles": int(d.group(3)), "tiles_census": int(d.group(4)),
                             "cov": int(d.group(5)), "drills": int(d.group(6)), "kinds": d.group(7)})
            res["gis"].setdefault(m.group(2), []).append({"min": int(m.group(1)), "decisions": int(m.group(3)),
                                                           "orders": int(m.group(4)), "open": int(m.group(5)),
                                                           "stats": m.group(6), "deps": deps})
            continue
        m = RE_BILAN.search(ln)
        if m:
            res["bilan"] = m.group(1)
            continue
        m = RE_ORDER_DONE.search(ln)
        if m:
            fk = m.group(1)
            res["done"].setdefault(fk, []).append((m.group(2), m.group(3), m.group(4), float(m.group(5))))
            continue
        m = RE_CAPI.search(ln)
        if m:
            fk, minute = m.group(1), int(m.group(2))
            s = RE_SENT.search(ln)
            if s and s.group(1):
                for item in s.group(1).split(", "):
                    res["sent"].setdefault(fk, []).append((minute, item))
            if s and s.group(2):
                for item in s.group(2).split(", "):
                    res["refused"].setdefault(fk, []).append((minute, item))
            continue
        m = RE_TECH_DONE.search(ln)
        if m:
            res["tech"].setdefault(m.group(1), []).append((m.group(2), float(m.group(3))))
    return res


def best_cov(entry):
    """Gisement exploité (au moins une foreuse) le plus couvert : (kappa ‰, id, couvertes, tuiles, ressource)."""
    best = None
    exploited = 0
    for d in entry["deps"]:
        if d["drills"] > 0 and d["tiles"] > 0:
            exploited += 1
            k = 1000 * d["cov"] // d["tiles"]
            if best is None or k > best[0]:
                best = (k, d["id"], d["cov"], d["tiles"], d["res"])
    return best, exploited


def report(arch, out_csv=None):
    r = analyse(arch)
    name = os.path.basename(os.path.normpath(arch))
    print("=" * 100)
    print("ARCHIVE %s | BILAN %s" % (name, r["bilan"]))
    rows_csv = []
    for fk in sorted(r["courbe"]):
        print("-" * 100)
        print("FACTION %s" % fk)
        print("  min | f.elec f.comb fours asm labos |  n idle%% tech | minerai(fer,cu,charbon,pierre)/10min | plaques fer cu | packs r/v/m | kappa gisement exploite (nb exploites)")
        gis = {e["min"]: e for e in r["gis"].get(fk, [])}
        fon = {e["min"]: e for e in r["fonte"].get(fk, [])}
        for c in r["courbe"][fk]:
            ext = c["ext"]
            pr = c["prod"]
            g = gis.get(c["min"])
            bc, ex = (best_cov(g) if g else (None, 0))
            kap = ("%d%% %s %d/%d" % (bc[0] // 10, bc[4], bc[2], bc[3])) if bc else "-"
            print("  %3d | %6d %6d %5d %3d %5d | %2d %5.1f %4d | %5d %5d %5d %5d | %5d %5d | %d/%d/%d | %s (%d)" % (
                c["min"], c["fe"], c["fc"], c["fours"], c["asm"], c["labos"], c["n"], c["idle"], c["tech"],
                ext.get("iron-ore", 0), ext.get("copper-ore", 0), ext.get("coal", 0), ext.get("stone", 0),
                pr.get("iron-plate", 0), pr.get("copper-plate", 0), pr.get(PACKS[0], 0), pr.get(PACKS[1], 0),
                pr.get(PACKS[2], 0), kap, ex))
            f = fon.get(c["min"])
            rows_csv.append([name, fk, c["min"], c["fe"], c["fc"], c["fours"], c["asm"], c["labos"], c["n"], c["idle"],
                             c["tech"], ext.get("iron-ore", 0), ext.get("copper-ore", 0), ext.get("coal", 0),
                             ext.get("stone", 0), pr.get("iron-plate", 0), pr.get("copper-plate", 0),
                             pr.get(PACKS[0], 0), pr.get(PACKS[1], 0), bc[0] if bc else 0, ex,
                             f["affames"] if f else "", f["fours"] if f else "", f["pleines"] if f else "",
                             f["foreuses"] if f else ""])
        # critère (2)
        ff = r["fonte"].get(fk, [])
        if ff:
            parts = ["%d:%d/%d aff,%d/%d pleines" % (e["min"], e["affames"], e["fours"], e["pleines"], e["foreuses"]) for e in ff]
            print("  (2) fonte : " + " ; ".join(parts))
        # critère (1) et (3) : couverture au fil du temps
        for e in r["gis"].get(fk, []):
            if e["min"] in (30, 60, 90):
                ds = ["%s %s %d/%d foreuses %d {%s}" % (d["id"], d["res"], d["cov"], d["tiles"], d["drills"], d["kinds"])
                      for d in e["deps"] if d["drills"] > 0]
                print("  (1)(3) minute %d : %s" % (e["min"], " ; ".join(ds) if ds else "aucun gisement exploite recense"))
        idle = [c["idle"] for c in r["courbe"][fk] if 30 < c["min"] <= 90]
        if idle:
            print("  inactifs 30-90 min : moyenne %.1f %%" % (sum(idle) / len(idle)))
        first_asm = next((c["min"] for c in r["courbe"][fk] if c["asm"] > 0), None)
        print("  (4) premier assembleur (releve a 10 min pres) : %s min" % first_asm)
        sent = r["sent"].get(fk, [])
        kinds = {}
        for _, s in sent:
            k = s.split(":", 1)[0]
            kinds[k] = kinds.get(k, 0) + 1
        print("  ordres envoyes par sorte : %s" % (", ".join("%s=%d" % (k, kinds[k]) for k in sorted(kinds)) or "aucun"))
        done = r["done"].get(fk, [])
        ok = sum(1 for d in done if d[1] == "FINI")
        print("  ordres finis %d, echoues %d" % (ok, len(done) - ok))
        for d in done[:12]:
            print("     %s %s (%s) %.1f min" % d)
        ref = r["refused"].get(fk, [])
        if ref:
            print("  refus de l'executant (%d), premiers : %s" % (len(ref), " | ".join("%d:%s" % x for x in ref[:6])))
        techs = r["tech"].get(fk, [])
        print("  technologies (%d) : %s" % (len(techs), ", ".join("%s@%.0f" % t for t in techs[:30])))
    if out_csv:
        import csv
        new = not os.path.exists(out_csv)
        with open(out_csv, "a", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            if new:
                w.writerow(["archive", "faction", "minute", "foreuses_elec", "foreuses_comb", "fours", "assembleurs", "labos",
                            "n", "inactifs_pct", "tech", "fer_minerai_10", "cuivre_minerai_10", "charbon_10", "pierre_10",
                            "plaques_fer_10", "plaques_cuivre_10", "packs_rouges_10", "packs_verts_10", "kappa_pm",
                            "gisements_exploites", "fours_affames", "fours", "foreuses_pleines", "foreuses"])
            for row in rows_csv:
                w.writerow(row)
    return r


def main(argv):
    out_csv = None
    archs = []
    i = 0
    while i < len(argv):
        if argv[i] == "--csv":
            out_csv = argv[i + 1]
            i += 2
            continue
        archs.append(argv[i])
        i += 1
    if not archs:
        print(__doc__)
        return 2
    for a in archs:
        report(a, out_csv)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
