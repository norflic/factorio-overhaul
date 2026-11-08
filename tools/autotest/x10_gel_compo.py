"""Lot X10-GEL, C20' (b) : composition de la scène x10-gel-echelle tirée du RECENSEMENT de la partie du DC.

Lit les lignes [FO-X10-RECENS] du journal d'un banc x10-gel-recensement (benchmark.log ou benchmark.log.gz) et écrit
tools/autotest/fo-autotest/scenarios/x10_gel_echelle_compo.lua (une faction de la partie = un groupe de la scène, posé 10 fois par
le scénario). Ce qui n'est pas dans le recensement est dit ici, tel quel :
  - les îlots d'une faction sont rattachés à l'avant-poste de distance la plus proche (le recensement ne donne pas la direction) ;
  - les refus des fours du QG = fours connus de la faction - fours du QG relevés, pris dans l'ordre RAISONS_QG ; les autres refus
    sont des foreuses, réparties sur les avant-postes selon leurs foreuses non relevées ;
  - noms et rôles des soldats sont appariés dans l'ordre trié (le recensement les compte à part).
Usage :
  py -3.9 -B tools/autotest/x10_gel_compo.py <archive du recensement> [--out <fichier .lua>]
  py -3.9 -B tools/autotest/x10_gel_compo.py --selftest
"""
import gzip
import os
import re
import sys

RAISONS_QG = ["recette", "bras", "combustible", "electrique", "foreuse", "a demonter", "invalide"]
SORTIE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fo-autotest", "scenarios", "x10_gel_echelle_compo.lua")

RE_FACTION = re.compile(
    r"\[FO-X10-RECENS\] faction (\S+) \((.*?)\) qg (-?\d+),(-?\d+) ; candidats (\d+) lus (\d+) ; refus \[(.*?)\] ; fours_qg (\d+) ; "
    r"soldats (\d+) \[(.*?)\] noms \[(.*?)\] dist \[(.*?)\] postes (\d+) \[(.*?)\] ; tourelles (\d+) \[(.*?)\] amas \[(.*?)\] ; "
    r"avant-postes \[(.*?)\]")
RE_ILOT = re.compile(
    r"\[FO-X10-RECENS\] ilot (\S+) (\S+) foreuses (\d+) machines (\d+) dist (-?\d+) minerai (\S+) gisement (-?\d+) charbon (\d+)-(\d+) "
    r"fige (\S+) etats ?(.*)$")


def kv(text):
    """« a=1 b=2 » -> {a: 1, b: 2} (ordre gardé)."""
    out = {}
    for part in text.split():
        k, _, v = part.rpartition("=")
        if k:
            out[k] = int(v)
    return out


def pairs_at(text):
    """« 12@80 3@40 » -> [(12, 80), (3, 40)]."""
    out = []
    for part in text.split():
        a, _, b = part.partition("@")
        out.append((int(a), int(b)))
    return out


def lire(chemin):
    if os.path.isdir(chemin):
        for nom in ("benchmark.log", "benchmark.log.gz"):
            if os.path.exists(os.path.join(chemin, nom)):
                chemin = os.path.join(chemin, nom)
                break
    ouvrir = gzip.open if chemin.endswith(".gz") else open
    with ouvrir(chemin, "rt", encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def composer(lignes):
    factions, ilots = [], []
    for ligne in lignes:
        m = RE_FACTION.search(ligne)
        if m:
            g = m.groups()
            factions.append({
                "fid": g[0], "key": g[1], "candidats": int(g[4]), "lus": int(g[5]), "refus": kv(g[6]), "fours_qg": int(g[7]),
                "roles": kv(g[9]), "noms": kv(g[10]), "postes": [int(x) for x in g[13].split()], "noms_tourelles": kv(g[15]),
                "amas": pairs_at(g[16]), "avant_postes": pairs_at(g[17])})
            continue
        m = RE_ILOT.search(ligne)
        if m:
            g = m.groups()
            ilots.append({"fid": g[0], "s": g[1], "f": int(g[2]), "d": int(g[4]), "m": g[5], "g": int(g[6]), "c0": int(g[7]),
                          "c1": int(g[8]), "e": g[10].strip()})
    if not factions:
        raise SystemExit("aucune ligne [FO-X10-RECENS] faction : est-ce le journal d'un banc x10-gel-recensement ?")
    out = []
    for F in factions:
        mes = [I for I in ilots if I["fid"] == F["fid"]]
        qg = [I for I in mes if I["s"] == "qg"]
        reste = dict(F["refus"])
        refus_qg = []
        manque = max(0, F["fours_qg"] - len(qg))
        for r in RAISONS_QG:
            while manque > 0 and reste.get(r, 0) > 0:
                refus_qg.append(r)
                reste[r] -= 1
                manque -= 1
        refus_foreuses = []
        for r in sorted(reste):
            refus_foreuses += [r] * reste[r]
        aps = [{"n": n, "d": d, "ilots": [], "refus": []} for (n, d) in F["avant_postes"]]
        for I in mes:
            if I["s"] == "qg":
                continue
            if not aps:
                aps.append({"n": I["f"], "d": I["d"], "ilots": [], "refus": []})
            best = min(range(len(aps)), key=lambda k: (abs(aps[k]["d"] - I["d"]), k))
            aps[best]["ilots"].append(I)
        libres = [max(0, A["n"] - sum(I["f"] for I in A["ilots"])) for A in aps]
        k = 0
        for r in refus_foreuses:
            if not aps:
                break
            essais = 0
            while libres[k % len(aps)] <= 0 and essais < len(aps):
                k += 1
                essais += 1
            j = k % len(aps)
            aps[j]["refus"].append(r)
            libres[j] -= 1
            if essais >= len(aps):
                k += 1
        noms = []
        for n in sorted(F["noms"]):
            noms += [n] * F["noms"][n]
        roles = []
        for r in sorted(F["roles"]):
            roles += [r] * F["roles"][r]
        tourelles = []
        for n in sorted(F["noms_tourelles"]):
            tourelles += [n] * F["noms_tourelles"][n]
        out.append({"key": F["key"], "qg": qg, "refus_qg": refus_qg, "outposts": [A for A in aps if A["ilots"] or A["refus"]],
                    "amas": [{"t": t, "d": d} for (t, d) in F["amas"] if t > 0], "turret_names": tourelles or ["gun-turret"],
                    "postes": F["postes"], "soldats": [{"name": n, "role": r} for n, r in zip(noms, roles)],
                    "lus": F["lus"], "candidats": F["candidats"]})
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_ilot(I):
    return "{ s = %s, f = %d, d = %d, m = %s, g = %d, c0 = %d, c1 = %d, e = %s }" % (
        lua_str(I["s"]), I["f"], I["d"], lua_str(I["m"]), I["g"], I["c0"], I["c1"], lua_str(I["e"]))


def ecrire(compo, source):
    L = ["-- Généré par tools/autotest/x10_gel_compo.py depuis le recensement de la partie du DC. Ne pas éditer.",
         "return {", "  source = %s," % lua_str(source), "  factions = {"]
    for F in compo:
        L.append("    { key = %s, -- candidats %d, lus %d" % (lua_str(F["key"]), F["candidats"], F["lus"]))
        L.append("      ilots = {")
        for I in F["qg"]:
            L.append("        " + lua_ilot(I) + ",")
        L.append("      },")
        L.append("      refus_qg = { %s }," % ", ".join(lua_str(r) for r in F["refus_qg"]))
        L.append("      outposts = {")
        for A in F["outposts"]:
            L.append("        { d = %d, refus = { %s }, ilots = {" % (A["d"], ", ".join(lua_str(r) for r in A["refus"])))
            for I in A["ilots"]:
                L.append("          " + lua_ilot(I) + ",")
            L.append("        } },")
        L.append("      },")
        L.append("      amas = { %s }," % ", ".join("{ t = %d, d = %d }" % (a["t"], a["d"]) for a in F["amas"]))
        L.append("      turret_names = { %s }," % ", ".join(lua_str(n) for n in F["turret_names"]))
        L.append("      postes = { %s }," % ", ".join(str(d) for d in F["postes"]))
        L.append("      soldats = { %s }," % ", ".join("{ name = %s, role = %s }" % (lua_str(s["name"]), lua_str(s["role"])) for s in F["soldats"]))
        L.append("    },")
    L += ["  },", "}", ""]
    return "\n".join(L)


def resume(compo):
    for F in compo:
        n_il = len(F["qg"]) + sum(len(A["ilots"]) for A in F["outposts"])
        n_ref = len(F["refus_qg"]) + sum(len(A["refus"]) for A in F["outposts"])
        print("%s : %d ilot(s) (dont %d du QG), %d refus, %d avant-poste(s), %d soldat(s), %d poste(s), %d amas" % (
            F["key"], n_il, len(F["qg"]), n_ref, len(F["outposts"]), len(F["soldats"]), len(F["postes"]), len(F["amas"])))


def selftest():
    lignes = [
        "x [FO-X10-RECENS] faction 1 (a) qg 0,0 ; candidats 9 lus 9 ; refus [bras=2 bus=1 electrique=1] ; fours_qg 3 ; soldats 3 "
        "[guard=1 qg=2] noms [fo-s1=2 fo-s2=1] dist [5 6 80] postes 1 [80] ; tourelles 4 [gun-turret=4] amas [3@60 1@200] ; "
        "avant-postes [4@100 3@300]",
        "x [FO-X10-RECENS] ilot 1 coffre foreuses 1 machines 1 dist 98 minerai iron-ore gisement 4000 charbon 5-5 fige true etats working=1",
        "x [FO-X10-RECENS] ilot 1 four foreuses 2 machines 3 dist 290 minerai copper-ore gisement 9000 charbon 3-9 fige false etats working=2 no_fuel=1",
        "x [FO-X10-RECENS] ilot 1 qg foreuses 0 machines 1 dist 12 minerai iron-ore gisement 0 charbon 4-4 fige true etats working=1",
        "x [FO-X10-RECENS] ilot 1 qg foreuses 0 machines 1 dist 14 minerai iron-ore gisement 0 charbon 2-2 fige true etats ",
    ]
    c = composer(lignes)
    F = c[0]
    ok = []
    ok.append(len(F["qg"]) == 2 and F["refus_qg"] == ["bras"])
    ok.append([len(A["ilots"]) for A in F["outposts"]] == [1, 1])
    ok.append(sorted(r for A in F["outposts"] for r in A["refus"]) == ["bras", "bus", "electrique"])
    ok.append(F["outposts"][0]["refus"] == ["bras", "bus", "electrique"])  # 3 foreuses libres au premier, 1 au second (déjà prise)
    ok.append(F["soldats"] == [{"name": "fo-s1", "role": "guard"}, {"name": "fo-s1", "role": "qg"}, {"name": "fo-s2", "role": "qg"}])
    ok.append(F["amas"] == [{"t": 3, "d": 60}, {"t": 1, "d": 200}] and F["postes"] == [80])
    texte = ecrire(c, "selftest")
    ok.append('e = "working=2 no_fuel=1"' in texte and 'e = ""' in texte)
    n = sum(1 for x in ok if x)
    print("[X10-GEL-COMPO] BILAN : %d OK, %d ECHEC(S)" % (n, len(ok) - n))
    return 0 if n == len(ok) else 1


def main(argv):
    if "--selftest" in argv:
        return selftest()
    if not argv:
        print(__doc__)
        return 2
    sortie = SORTIE
    if "--out" in argv:
        sortie = argv[argv.index("--out") + 1]
    source = argv[0]
    compo = composer(lire(source))
    resume(compo)
    with open(sortie, "wb") as f:
        f.write(ecrire(compo, os.path.abspath(source).replace("\\", "/")).encode("utf-8"))
    print("ecrit : " + sortie)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
