# -*- coding: utf-8 -*-
"""Panel s43 (non-regression) : partie-reelle-60, 4 graines. Usage : py -3.9 -B tools/autotest/panel_s43.py <dossier des archives> [versions a,b,...] [prefixe] (archives <prefixe>-<version>-<graine>, prefixe par defaut s43-pn).
Par archive et par equipe : fer livre (FO-DEBIT-FER minute=60 livrees), bandes finies (dernier FO-CHAMP-ETAT, "fini N"),
QG sans charbon libre (lignes FO-CHARBON-CENTRALE, plafond Cc.LOGS = 40 par equipe ; premiere minute), foreuses du champ sans
courant / foreuses (dernier FO-CHAMP-ETAT), erreurs Lua (traceback, "Error", controle du banc)."""
import gzip, os, re, sys

SP = sys.argv[1]
SEEDS = ["123456789", "1618033988", "271828182", "314159265"]
VERS = sys.argv[2].split(",") if len(sys.argv) > 2 else ["0796", "rel"]
FER = re.compile(r"\[FO-DEBIT-FER\] minute=60 equipe=(\w+) .*?livrees=(\d+)")
ETAT = re.compile(r"\[FO-CHAMP-ETAT\] (\w+) min (\d+) \| bandes \d+ \(([^)]*)\).*?\| foreuses (\d+) \(marche (\d+), figees (\d+), sans courant (\d+)\)")
SANS = re.compile(r"\[FO-CHARBON-CENTRALE\] (\w+) : .*? a ([\d.]+) min : coffre du QG SANS charbon libre")
SONDE = re.compile(r"\[FO-SONDE-CHARBON\] minute=(\d+) equipe=(\S+) source=(\S+) combustible_qg=(-?\d+) charbon_qg=(-?\d+)")
PREFIX = sys.argv[3] if len(sys.argv) > 3 else "s43-pn"
ERR = re.compile(r"stack traceback|Error while running|LuaError|\bERREUR\b|attempt to (index|call|compare|perform)")

def one(arch):
    p = os.path.join(arch, "benchmark.log.gz")
    if not os.path.exists(p):
        return None
    t = {}
    errs = 0
    lua_ok = None
    with gzip.open(p, "rt", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = FER.search(line)
            if m:
                t.setdefault(m.group(1), {})["fer"] = int(m.group(2))
                continue
            m = ETAT.search(line)
            if m:
                d = t.setdefault(m.group(1), {})
                fin = re.search(r"fini (\d+)", m.group(3))
                d["bandes"] = int(fin.group(1)) if fin else 0
                d["for"], d["sc"] = int(m.group(4)), int(m.group(7))
                continue
            m = SONDE.search(line)
            if m:  # sonde sans plafond (scenarios/sonde_charbon.lua) : minutes a zero combustible, moyenne
                d = t.setdefault(m.group(2), {})
                n = int(m.group(4))
                if n >= 0:
                    d["sn"] = d.get("sn", 0) + 1
                    d["s0"] = d.get("s0", 0) + (1 if n == 0 else 0)
                    d["ssum"] = d.get("ssum", 0) + n
                    d["ssrc"] = m.group(3)
                continue
            m = SANS.search(line)
            if m:
                d = t.setdefault(m.group(1), {})
                d["sans"] = d.get("sans", 0) + 1
                d.setdefault("sans1", float(m.group(2)))
                continue
            if "aucune erreur Lua dans la mesure" in line:
                lua_ok = " OK " in line or "] OK" in line
            if ERR.search(line) and "aucune erreur" not in line:
                errs += 1
    return t, errs, lua_ok

tot = {v: {"fer": 0, "bandes": 0, "sans": 0, "for": 0, "sc": 0, "err": 0, "s0": 0, "sn": 0, "ssum": 0} for v in VERS}
print("graine     version equipe   fer_livre bandes_finies qg_sans_charbon(1re min) foreuses_sans_courant | sonde : min_a_zero/min moyenne (source)")
for s in SEEDS:
    for v in VERS:
        r = one(os.path.join(SP, "%s-%s-%s" % (PREFIX, v, s)))
        if r is None:
            print("%-10s %-7s (absent)" % (s, v))
            continue
        t, errs, lua_ok = r
        tot[v]["err"] += errs
        for k in sorted(t):
            d = t[k]
            sonde = ("%d/%d %.0f (%s)" % (d["s0"], d["sn"], d["ssum"] / d["sn"], d["ssrc"])) if d.get("sn") else "-"
            print("%-10s %-7s %-8s %9d %13d %10d (%s) %10s | %s" % (s, v, k, d.get("fer", 0), d.get("bandes", 0), d.get("sans", 0),
                  "%.1f" % d["sans1"] if "sans1" in d else "-", "%d/%d" % (d.get("sc", 0), d.get("for", 0)), sonde))
            for f in ("fer", "bandes", "sans", "for", "sc", "s0", "sn", "ssum"):
                tot[v][f] += d.get(f, 0)
        print("%-10s %-7s erreurs Lua : %d ; controle du banc : %s" % (s, v, errs, lua_ok))
print()
for v in VERS:
    x = tot[v]
    print("SOMME %-5s fer %d | bandes finies %d | lignes QG sans charbon %d | foreuses sans courant %d/%d | erreurs %d | sonde : %d min a zero sur %d, moyenne %s" % (
        v, x["fer"], x["bandes"], x["sans"], x["sc"], x["for"], x["err"], x["s0"], x["sn"], ("%.0f" % (x["ssum"] / x["sn"])) if x["sn"] else "-"))
