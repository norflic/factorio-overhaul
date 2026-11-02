# Lot FLUX : critères F1 à F4 de fo-logs/2026-11-02_FLUX/CRITERES.md, lus dans les archives de banc.py (lignes [FO-REGARD] et [FO-FLUX]).
# Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/flux_mesures.py <archive> [<archive> ...]
# Une archive = une colonne de comparaison par force. Réutilise regard.py (analyse des lignes, minages, seuils).
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import regard  # noqa: E402

FLUX = re.compile(r"\[FO-FLUX\] (\w+) a ([\d.]+) min : sorties comptees (\d+) .*?receptacles pleins (\d+) ; tournees libres (\d+) \(plus vieille (\d+) s, prio (\d+)\) ; "
                  r"bruleurs vitaux (\d+) dont (\d+) a sec(?:, remplissage a (\d+) charbons)? ; pendant menace : (\d+) pensee\(s\), ([\d.]+) %")


def g(d, k):
    v = (d or {}).get(k, 0)
    return v if isinstance(v, (int, float)) else 0


def mesure(arch):
    lignes = regard.lire(arch)
    rel, minages, _ = regard.analyser(lignes)
    out = {}
    for force in sorted(rel):
        r = rel[force]
        mins = sorted(r)
        if not mins:
            continue
        # F1 : minages après MAIN_DEPUIS dont le stock (coffre + plaques + plaques des fours) atteint les seuils (même calcul que regard.v_main)
        cle = None
        for x in minages:
            pass
        out[force] = {"minutes": mins}
    # minages par force (la clé du MINAGE est le nom court ; les forces de regard sont « fo-<nom> » ou « player »)
    par = {}
    for ln in lignes:
        m = regard.MINAGE.search(ln)
        if not m:
            continue
        par.setdefault(m.group(1), []).append({"min": float(m.group(2)), "item": m.group(3), "got": int(m.group(4)), "count": int(m.group(5)),
                                               "coffre": int(m.group(10))})
    res = {}
    for force, d in out.items():
        short = force[3:] if force.startswith("fo-") else force
        r = rel[force]
        mins = d["minutes"]
        mauvais = bas = 0
        for x in par.get(short, []):
            if x["min"] < regard.MAIN_DEPUIS or x["item"] not in ("iron-ore", "copper-ore", "coal", "stone"):
                continue
            avant = [m for m in mins if m <= x["min"]] or [mins[0]]
            rr = r[avant[-1]]
            stock = (rr.get("R") or {}).get("stock", {})
            eq = regard.PLATE_OF.get(x["item"])
            fours = g(rr.get("F"), {"iron-plate": "fer_dort", "copper-plate": "cuivre_dort"}.get(eq, "_"))
            total = max(x["coffre"], g(stock, x["item"])) + (g(stock, eq) + fours if eq else 0)
            if total >= regard.STOCK_INFO:
                bas += 1
            if total >= regard.STOCK_MIN:
                mauvais += 1
        dort = {m: g(r[m].get("F"), "fer_dort") + g(r[m].get("F"), "cuivre_dort") for m in mins if r[m].get("F")}
        pleine = {m: g(r[m].get("F"), "sortie_pleine") for m in mins if r[m].get("F")}
        # F3 : relevés dont l'intervalle contient une perte de PNJ ; sans_combustible à ces relevés
        att = []
        prev = None
        for m in mins:
            R = r[m].get("R") or {}
            perdus = g(R, "perdus")
            if prev is not None and perdus > prev and r[m].get("F"):
                att.append(g(r[m]["F"], "sans_combustible"))
            prev = perdus
        flux = 0.0
        for m in mins:
            R = r[m].get("R") or {}
            flux += g(R.get("flux_min", {}), "iron-plate") * 5 + g(R.get("flux_min", {}), "copper-plate") * 5
        last = r[mins[-1]].get("R") or {}
        res[force] = {"mauvais": mauvais, "bas": bas, "dort": dort, "pleine": pleine, "att": att, "plaques": flux,
                      "perdus": g(last, "perdus"), "pnj": g(last, "n"), "min_fin": mins[-1], "stock_fer": g(last, "stock_fer")}
    # [FO-FLUX] : part de brûleurs vitaux à sec (toutes tournées d'une force, moyenne des lignes) et tournée libre la plus ancienne
    fl = {}
    for ln in lignes:
        m = FLUX.search(ln)
        if not m:
            continue
        key = m.group(1)
        t = fl.setdefault(key, {"n": 0, "br": 0, "dry": 0, "old": 0, "thr_p": 0, "thr_pct": 0.0, "fill": 0})
        t["n"] += 1
        t["br"] += int(m.group(8))
        t["dry"] += int(m.group(9))
        t["old"] = max(t["old"], int(m.group(6)))
        t["fill"] = max(t["fill"], int(m.group(10) or 0))
        t["thr_p"] += int(m.group(11))
        t["thr_pct"] = max(t["thr_pct"], float(m.group(12)))
    return res, fl


def main():
    for arch in sys.argv[1:]:
        res, fl = mesure(arch)
        print("== " + os.path.basename(arch.rstrip("/\\")))
        for force in sorted(res):
            x = res[force]
            d = x["dort"]
            ms = sorted(d)
            def at(m):
                c = [k for k in ms if k <= m]
                return d[c[-1]] if c else -1
            att = x["att"]
            moy = sum(d[k] for k in ms if k >= 10) / max(1, len([k for k in ms if k >= 10]))
            print("  %-12s minage>=1000 %2d  >=300 %2d | dort moy %5d (min30 %5d min45 %5d min55 %5d) | sortie_pleine max %3d | sans_combustible en attaque %s | plaques %6d | PNJ %2d perdus %2d | fer coffre %5d"
                  % (force, x["mauvais"], x["bas"], moy, at(30), at(45), at(55), max(x["pleine"].values()) if x["pleine"] else 0,
                     (str(att) if att else "aucune attaque"), x["plaques"], x["pnj"], x["perdus"], x["stock_fer"]))
        for key in sorted(fl):
            t = fl[key]
            part = 100.0 * t["dry"] / t["br"] if t["br"] else 0.0
            print("  [FO-FLUX] %-9s %2d lignes ; bruleurs vitaux a sec %.1f %% en moyenne ; tournee libre la plus vieille %d s ; menace : %d pensees, pic %.1f %% ; remplissage max %d"
                  % (key, t["n"], part, t["old"], t["thr_p"], t["thr_pct"], t["fill"]))


if __name__ == "__main__":
    main()
