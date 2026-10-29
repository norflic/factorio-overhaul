# -*- coding: utf-8 -*-
"""Lot CAPI-ANNULATION : tableau temoin / lot des series etape1-guide (criteres : fo-logs/2026-10-29_NUIT/CAPIA/CRITERES.md).

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/capia_tableau.py <dossier des archives> [--juges 20261020,123456789,271828182,1618033988]
            [--regl 314159265] [--json <fichier>]
Le dossier contient temoin-<graine>/ et lot-<graine>/ (benchmark.log.gz, seed.txt) rendus par banc.py.

Mesures par graine et par faction (M-1 a M-4) puis decisions K0 a K7 sur les graines de JUGEMENT ; la graine de reglage est
rapportee a part (K5). Aucune valeur de seuil n'est choisie ici apres lecture : elles sont dans CRITERES.md.
"""
import gzip
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fonction_mesures as FM  # noqa: E402

PREFIX = re.compile(r"^\s*[\d.]+ Script @[^:]+:\d+: ")
RE_ANNULE = re.compile(r"\[FO-IA1D\] (\w+) : projet (\d+) annule \(CAPI : (.*)\)")
RE_FINI = re.compile(r"\[FO-IA1D\] (\w+) : projet (\d+) fini \(.*\) a ([\d.]+) min")
RE_REFUSE = re.compile(r"\[FO-IA1D\] (\w+) : projet (\d+) refuse")
RE_MIN = re.compile(r"\[FO-IA3E\] (\w+) minute (\d+) \|.*?\| modules \{(.*?)\} \| verdicts")
RE_MOD = re.compile(r"(\S+?)#(\d+):(\w+)\((\d+)/(\d+)\)(?:=\d+/min)?(?:\[[^\]]*\])?(?:<([^>]*)>)?")
RE_CAPI_ORDRE = re.compile(r"\[FO-CAPI\] (\w+) : ordre (\S+) (FINI|ECHOUE) \((\w+)(?:, (.*?))?\) apres ([\d.]+) min a ([\d.]+) min")
RE_GARDE = re.compile(r"\[FO-CAPI\] (\w+) : ordre (\S+) GARDE : manque (-?\d+).*apres ([\d.]+) min a ([\d.]+) min")
RE_BILAN = re.compile(r"\[FO-ETAPE1-GUIDE\] BILAN : (\d+) OK, (\d+) ECHEC")
DETERMINISTES = ("FO-CAPI", "FO-IA1D", "FO-IA3E", "FO-IA3C", "FO-CERVEAU", "FO-TEAM", "FO-STRAT", "FO-ETAPE1-GUIDE",
                 "FO-FONCTION", "FO-CAPITAL", "FO-EFFECTIF", "FO-SITES")
ELEC = ("foreuse_elec", "bras_elec", "assembleur", "labo")
FACTIONS = ("scarlet", "azure")


def lines_of(arch):
    return FM.read_log(arch)


def normal(ln):
    return PREFIX.sub("", ln).rstrip()


def tag_of(txt):
    m = re.match(r"\[(FO-[A-Z0-9-]+)\]", txt)
    return m.group(1) if m else None


def minute_missing(txt):
    """Ligne minute IA3E -> (faction, minute, { id: (etat, total des objets affiches ou None) })"""
    m = RE_MIN.search(txt)
    if not m:
        return None
    out = {}
    for mm in RE_MOD.finditer(m.group(3)):
        mid, state, miss = int(mm.group(2)), mm.group(3), mm.group(6)
        tot = None
        if state == "reserve" and miss:
            tot = 0
            for part in miss.split(","):
                try:
                    tot += int(part.rsplit("x", 1)[1])
                except (IndexError, ValueError):
                    pass
        out[mid] = (state, tot)
    return m.group(1), int(m.group(2)), out


def analyse(arch):
    lines = lines_of(arch)
    res = {"ttl": [], "plafond": [], "fini": {}, "annule": {}, "garde": [], "ordres_ttl": [], "bilan": None, "erreurs": 0,
           "capi_ordres": {}}
    hist = {}      # (faction, id) -> [(minute, total)]
    last_min = {}  # faction -> derniere minute vue
    for ln in lines:
        txt = normal(ln)
        if "Error" in txt and ("stack traceback" in txt or "Error while running" in txt or "attempt to" in txt):
            res["erreurs"] += 1
        m = RE_BILAN.search(txt)
        if m:
            res["bilan"] = (int(m.group(1)), int(m.group(2)))
        mm = minute_missing(txt)
        if mm:
            fac, minute, mods = mm
            last_min[fac] = minute
            for mid, (state, tot) in mods.items():
                hist.setdefault((fac, mid), []).append((minute, tot))
            continue
        m = RE_FINI.search(txt)
        if m:
            res["fini"].setdefault(m.group(1), []).append((int(m.group(2)), float(m.group(3))))
            continue
        m = RE_ANNULE.search(txt)
        if m:
            fac, pid, why = m.group(1), int(m.group(2)), m.group(3)
            res["annule"].setdefault(fac, []).append((pid, why))
            if "aucun progres" in why or "plafond" in why:
                mc = last_min.get(fac, -1)
                vals = [(mi, t) for (mi, t) in hist.get((fac, pid), []) if t is not None and mc - 30 <= mi <= mc]
                baisse = any(vals[i + 1][1] < vals[i][1] for i in range(len(vals) - 1))
                rec = {"faction": fac, "projet": pid, "minute": mc, "baisse_30min": baisse,
                       "manque_affiche": vals[-1][1] if vals else None, "serie": vals[-6:]}
                res["plafond" if "plafond" in why else "ttl"].append(rec)
            continue
        m = RE_GARDE.search(txt)
        if m:
            res["garde"].append({"faction": m.group(1), "ordre": m.group(2), "manque": int(m.group(3)),
                                 "age": float(m.group(4)), "minute": float(m.group(5))})
            continue
        m = RE_CAPI_ORDRE.search(txt)
        if m:
            d = res["capi_ordres"].setdefault(m.group(1), {"FINI": 0, "ECHOUE": 0})
            d[m.group(3)] += 1
            why = m.group(5) or ""
            if m.group(3) == "ECHOUE" and m.group(4) == "module" and ("aucun progres" in why or "plafond" in why):
                # M-1 lu sur les lignes CAPI (le journal du plan directeur n'ecrit pas toujours « annule »)
                res["ordres_ttl"].append({"faction": m.group(1), "ordre": m.group(2), "age": float(m.group(6)),
                                          "minute": float(m.group(7)), "cause": "plafond" if "plafond" in why else "ttl"})
    # indicateurs fonctionnels
    data = FM.parse_lines(lines)
    fonc = {}
    for (key, minute), slot in data.items():
        f = fonc.setdefault(key, {})
        alim = 0.0
        for cls in ELEC:
            st = slot.get("statut", {}).get(cls)
            if st:
                n, s = FM.get(st, "n"), FM.get(st, "samples")
                if s:
                    alim += n * (1.0 - FM.get(st, "no_power") / s)
        pr = slot.get("prod", {})
        tu = slot.get("tourelles", {})
        f[minute] = {"alim": alim, "pnj": FM.get(pr, "pnj"), "plaques": FM.get(pr, "plaques_min", 0.0),
                     "tour_armees": FM.get(tu, "armees"), "tourelles": FM.get(tu, "n")}
    res["fonc"] = fonc
    res["norm"] = [normal(ln) for ln in lines]
    return res


def first_divergence(a, b):
    """Premier indice ou deux suites de lignes normalisees (balises deterministes, sans GARDE) different."""
    def keep(ls):
        return [x for x in ls if tag_of(x) in DETERMINISTES and " GARDE : " not in x]
    ka, kb = keep(a), keep(b)
    for i in range(min(len(ka), len(kb))):
        if ka[i] != kb[i]:
            return i, ka[i], kb[i], len(ka), len(kb)
    if len(ka) != len(kb):
        return min(len(ka), len(kb)), None, None, len(ka), len(kb)
    return None, None, None, len(ka), len(kb)


def first_ttl_index(norm):
    ks = [x for x in norm if tag_of(x) in DETERMINISTES and " GARDE : " not in x]
    for i, x in enumerate(ks):
        if "ECHOUE (module, aucun progres" in x or "ECHOUE (module, plafond" in x:
            return i
    return None


def total(res, fac_list, minute, k):
    s = 0.0
    for fac in fac_list:
        s += res["fonc"].get(fac, {}).get(minute, {}).get(k, 0) or 0
    return s


def ratio(a, b):
    return None if not b else a / b


def fmt(v, nd=2):
    return "-" if v is None else (f"{v:.{nd}f}" if isinstance(v, float) else str(v))


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    base = argv[1]
    juges = ["20261020", "123456789", "271828182", "1618033988"]
    regl = ["314159265"]
    out_json = None
    for i, a in enumerate(argv):
        if a == "--juges":
            juges = argv[i + 1].split(",")
        if a == "--regl":
            regl = argv[i + 1].split(",")
        if a == "--json":
            out_json = argv[i + 1]
    R = {}
    for g in juges + regl:
        for v in ("temoin", "lot"):
            p = os.path.join(base, f"{v}-{g}")
            if os.path.isdir(p):
                R[(v, g)] = analyse(p)
    summary = {}
    for g in juges + regl:
        t, l = R.get(("temoin", g)), R.get(("lot", g))
        if not (t and l):
            print(f"== graine {g} : archives manquantes (temoin {bool(t)}, lot {bool(l)})")
            continue
        tag = "REGLAGE" if g in regl else "jugement"
        print(f"== graine {g} ({tag})")
        i_div, lt, ll, nt, nl = first_divergence(t["norm"], l["norm"])
        i_ttl = first_ttl_index(t["norm"])
        k0 = (i_div is None) or (i_ttl is not None and i_div >= i_ttl)
        print(f"  K0 : lignes deterministes temoin {nt}, lot {nl} ; 1er ecart a l'indice {i_div} ; 1re annulation TTL du temoin a l'indice {i_ttl} -> {'TENU' if k0 else 'ECHEC'}")
        if not k0:
            print(f"     temoin : {lt[:260] if lt else None}\n     lot    : {ll[:260] if ll else None}")
        for v, r in (("temoin", t), ("lot", l)):
            nb = sum(1 for x in r["ttl"] if x["baisse_30min"])
            print(f"  {v:6s} M-1b (lignes CAPI ECHOUE aucun progres/plafond) : {len(r['ordres_ttl'])} " +
                  "; ".join(f"{x['faction']} {x['ordre']} a {x['minute']} min (age {x['age']}, {x['cause']})" for x in r["ordres_ttl"]))
            print(f"  {v:6s} M-1 : annulations TTL {len(r['ttl'])} dont avec manque en baisse {nb} ; plafond {len(r['plafond'])} ; GARDE {len(r['garde'])} ; BILAN {r['bilan']} ; erreurs Lua {r['erreurs']}")
            for x in r["ttl"] + r["plafond"]:
                print(f"           {x['faction']} projet {x['projet']} a {x['minute']} min : baisse={x['baisse_30min']} manque_affiche={x['manque_affiche']} serie={x['serie']}")
            for x in r["garde"]:
                print(f"           GARDE {x['faction']} {x['ordre']} a {x['minute']} min (age {x['age']}) manque {x['manque']}")
            for fac in FACTIONS + ("player",):  # votre equipe : pour memoire, hors decisions
                fin = [p for p in r["fini"].get(fac, []) if p[1] <= 60.2]
                ann = r["annule"].get(fac, [])
                print(f"           {fac:7s} M-2 projets finis<=60 min {len(fin)} (ids {sorted(p[0] for p in fin)}) annules {len(ann)} ; M-3 alim m40 {fmt(total(r,[fac],40,'alim'),1)} m60 {fmt(total(r,[fac],60,'alim'),1)} ; PNJ m60 {fmt(total(r,[fac],60,'pnj'),0)} ; tourelles armees m60 {fmt(total(r,[fac],60,'tour_armees'),0)} ; plaques/min m60 {fmt(total(r,[fac],60,'plaques'),1)}")
        summary[g] = (t, l, k0)
    # decisions sur les graines de jugement
    js = [g for g in juges if g in summary]
    if js:
        print("\n== DECISIONS (graines de jugement, factions scarlet+azure, sommes)")
        def tot_fini(r):
            return sum(len([p for p in r["fini"].get(f, []) if p[1] <= 60.2]) for f in FACTIONS)
        Tf = sum(tot_fini(summary[g][0]) for g in js)
        Lf = sum(tot_fini(summary[g][1]) for g in js)
        k3 = Lf >= Tf and all(tot_fini(summary[g][1]) >= 0.5 * tot_fini(summary[g][0]) for g in js)
        print(f"  K3 projets finis a 60 min : temoin {Tf}, lot {Lf} ; par graine " +
              ", ".join(f"{g}:{tot_fini(summary[g][0])}/{tot_fini(summary[g][1])}" for g in js) + f" -> {'TENU' if k3 else 'ECHEC'}")
        def sum_all(k, minutes, which):
            return sum(total(summary[g][which], FACTIONS, m, k) for g in js for m in minutes)
        res4 = {}
        for name, k, mins in (("M-3 alimentes m40+m60", "alim", (40, 60)), ("PNJ vivants m60", "pnj", (60,)),
                              ("tourelles armees m60", "tour_armees", (60,)), ("plaques/min m60", "plaques", (60,))):
            a, b = sum_all(k, mins, 0), sum_all(k, mins, 1)
            res4[name] = ratio(b, a)
            print(f"  K4 {name} : temoin {a:.1f}, lot {b:.1f}, rapport {fmt(res4[name])} (>= 0,90 attendu)")
        bas = []
        for g in js:
            a = sum(total(summary[g][0], FACTIONS, m, "alim") for m in (40, 60))
            b = sum(total(summary[g][1], FACTIONS, m, "alim") for m in (40, 60))
            rr = ratio(b, a)
            print(f"      graine {g} : alimentes lot/temoin {fmt(rr)}")
            if rr is not None and rr < 0.75:
                bas.append(g)
        k4 = all((v is None or v >= 0.90) for v in res4.values()) and len(bas) <= 1
        print(f"  K4 -> {'TENU' if k4 else 'ECHEC'} (graines sous 0,75 : {bas})")
        nb_t = sum(1 for g in js + [x for x in regl if x in summary] for x in summary[g][0]["ttl"] if x["baisse_30min"])
        nb_l = sum(1 for g in js + [x for x in regl if x in summary] for x in summary[g][1]["ttl"] if x["baisse_30min"])
        print(f"  K1 annulations TTL avec manque en baisse (toutes graines) : temoin {nb_t}, lot {nb_l} -> {'TENU' if nb_l == 0 and nb_t > 0 else ('NON REPRODUIT (temoin 0)' if nb_t == 0 else 'ECHEC')}")
        nl2 = sum(1 for g in summary for x in summary[g][1]["ttl"] if not x["baisse_30min"])
        print(f"  K2 annulations TTL du lot sans baisse du manque (le vrai blocage encore retire) : {nl2} " + ("" if nl2 else "-> non eprouve en moteur"))
        for g in summary:
            for x in summary[g][1]["plafond"]:
                print(f"  K7 plafond : graine {g} {x['faction']} projet {x['projet']} a {x['minute']} min, manque affiche {x['manque_affiche']}")
    if out_json:
        with open(out_json, "w", encoding="utf-8") as fh:
            json.dump({f"{v}-{g}": {k: x for k, x in r.items() if k not in ("norm",)} for (v, g), r in R.items()}, fh, indent=1,
                      default=str)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
