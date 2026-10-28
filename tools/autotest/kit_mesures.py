# Lot KIT (28/10) : relevé des critères « kit égal » sur une ou plusieurs archives du banc etape1-guide (banc.py).
# Par faction et par graine : foreuses visant un minerai (fer, cuivre) et au total, centrale (chaudières, machines à vapeur) à
# 30 min, recherches faites à 40 min, effectif, plaques de fer au coffre. Critères du DC (28/10) avec le kit égal : chaque
# faction a au moins 6 foreuses de minerai, une centrale à 30 min, plus de 5 recherches à 40 min.
# Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/kit_mesures.py <archive> [<archive> ...]
import gzip, os, re, sys

BASE = re.compile(r"\[FO-ETAPE1-GUIDE\] base minute (\d+) \| (\w+) \| chaudieres=(\d+) vapeur=(\d+) poteaux=(\d+) foreuses_elec=(\d+) "
                  r"foreuses_comb=(\d+).*?\| tech=(-?\d+) n=(-?\d+) \| coffre_qg (.*)")
MES = re.compile(r"\[FO-ETAPE1-GUIDE\] kit-mesure minute (\d+) \| (\w+) \| foreuses ([^|]*)\| recherches_faites=(\d+)(?: \| bois_coffre=(\d+))?")


def lire(archive):
    for nom in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(archive, nom)
        if os.path.exists(p):
            f = gzip.open(p, "rt", encoding="utf8", errors="replace") if nom.endswith(".gz") else open(p, encoding="utf8", errors="replace")
            with f:
                return f.read().splitlines()
    return []


def iron_of(txt):
    m = re.search(r"iron-plate=(\d+)", txt)
    return int(m.group(1)) if m else 0


def releve(archive):
    base, mes = {}, {}
    for ln in lire(archive):
        m = BASE.search(ln)
        if m:
            mn, key = int(m.group(1)), m.group(2)
            base[(mn, key)] = dict(chaud=int(m.group(3)), vap=int(m.group(4)), pot=int(m.group(5)), elec=int(m.group(6)),
                                   comb=int(m.group(7)), tech=int(m.group(8)), n=int(m.group(9)), fer=iron_of(m.group(10)))
            continue
        m = MES.search(ln)
        if m:
            cibles = {}
            for part in m.group(3).split():
                if ":" in part:
                    k, v = part.rsplit(":", 1)
                    cibles[k] = int(v)
            mes[(int(m.group(1)), m.group(2))] = dict(cibles=cibles, rech=int(m.group(4)), bois=int(m.group(5) or 0))
    return base, mes


def main(argv):
    ok_all = True
    for arch in argv:
        base, mes = releve(arch)
        seed = ""
        sp = os.path.join(arch, "seed.txt")
        if os.path.exists(sp):
            seed = open(sp).read().strip()
        print("== %s (graine %s)" % (os.path.basename(os.path.normpath(arch)), seed))
        cles = sorted({k for (_, k) in base})
        for key in cles:
            lignes = []
            for mn in (10, 20, 30, 40, 60):
                b, m = base.get((mn, key)), mes.get((mn, key))
                if not b:
                    continue
                c = m["cibles"] if m else {}
                minerai = sum(v for k, v in c.items() if k in ("iron-ore", "copper-ore")) if m else b["elec"] + b["comb"]
                total = sum(c.values()) if m else b["elec"] + b["comb"]
                lignes.append("%d min : foreuses minerai=%d total=%d [%s] centrale=%d/%d poteaux=%d recherches=%s bois_qg=%s tech=%d n=%d fer_qg=%d" % (
                    mn, minerai, total, " ".join("%s:%d" % kv for kv in sorted(c.items())), b["chaud"], b["vap"], b["pot"],
                    str(m["rech"]) if m else "?", str(m["bois"]) if m else "?", b["tech"], b["n"], b["fer"]))
            print("  %s" % key)
            for l in lignes:
                print("    " + l)
            b30, b40 = base.get((30, key)), mes.get((40, key))
            m60 = mes.get((60, key)) or mes.get((30, key))
            ok6 = False
            ref = mes.get((60, key)) or mes.get((40, key)) or mes.get((30, key))
            if ref:
                ok6 = sum(v for k, v in ref["cibles"].items() if k in ("iron-ore", "copper-ore")) >= 6
            okc = bool(b30 and b30["chaud"] >= 1 and b30["vap"] >= 1)
            okr = bool(b40 and b40["rech"] > 5)
            print("    criteres : >=6 foreuses de minerai %s | centrale a 30 min %s | >5 recherches a 40 min %s" % (
                "OK" if ok6 else "NON", "OK" if okc else "NON", "OK" if okr else "NON"))
            ok_all = ok_all and ok6 and okc and okr
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
