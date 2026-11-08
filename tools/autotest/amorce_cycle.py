"""Lot VIDEO-COUVERTURE 5 : lecture APRES COUP du banc `amorce-cycle` (tools/autotest/fo-autotest/scenarios/amorce-cycle.lua).

    PYTHONUTF8=1 py -3.9 -B tools/autotest/amorce_cycle.py <archive du banc> [--seed-min 80]

Un script de scenario ne lit pas le journal du mod : ce programme relit benchmark.log (ou .gz) de l'archive et controle :
  C5.1  une ligne « [FO-AMORCE] <equipe> : graine de cycle <objet> : <n> a fabriquer ; cause : cycle <id> : … » avec
        seed_min <= n <= 400 (Am.CYCLE_HARD), pour l'objet qui ferme le cycle (uranium-235) ;
  C5.2  « machine sans production ne compte pas » : le scenario ecrit « [FO-CONFIRMATION-BANC] <equipe> : posees=N produites=0 » ;
        le DERNIER bilan « [FO-CAPI-CONF] <equipe> : bilan : A engage(s), B confirme(s) » de la meme equipe porte B = 0 et
        A >= N : aucune capacite fantome. Ecrit « [FO-CONFIRMATION] 0 capacite fantome » quand c'est vrai ;
  banc  « [FO-AMORCE-CYCLE] BILAN : n OK, 0 ECHEC(S) ».
Code de sortie 0 : tout est vrai.
"""
import gzip
import os
import re
import sys

RE_SEED = re.compile(r"\[FO-AMORCE\] (\w+) : graine de cycle (\S+) : (\d+) a fabriquer ; cause : (cycle .*)")
# l'enrichissement n'est pas fabricable a la main (categorie centrifuging) : le cycle est ferme par Rg.chain, publie, puis refuse PAR ECRIT
RE_SKIP = re.compile(r"\[FO-AMORCE\] (\w+) : cycle (\S+) non seme \((\d+) voulus\) : aucune recette a la main ; cause : (cycle .*)")
RE_BANC = re.compile(r"\[FO-CONFIRMATION-BANC\] (\w+) : posees=(\d+) produites=(\d+)")
RE_BILAN = re.compile(r"\[FO-CAPI-CONF\] (\w+) : bilan : (\d+) engage\(s\), (\d+) confirme\(s\)")
RE_SCEN = re.compile(r"\[FO-AMORCE-CYCLE\] BILAN : (\d+) OK, (\d+) ECHEC")
HARD = 400


def read_log(path):
    for name in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(path, name)
        if os.path.exists(p):
            op = gzip.open if name.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    raise SystemExit("benchmark.log absent de " + path)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    seed_min = 80
    if "--seed-min" in argv:
        seed_min = int(argv[argv.index("--seed-min") + 1])
    lines = read_log(argv[1])
    fails = 0

    def verdict(ok, msg):
        nonlocal fails
        print(("OK     " if ok else "ECHEC  ") + msg)
        if not ok:
            fails += 1

    scen = [m for m in (RE_SCEN.search(l) for l in lines) if m]
    verdict(bool(scen) and scen[-1].group(2) == "0", "banc : %s" % (scen[-1].group(0) if scen else "aucun BILAN du scenario"))
    seeds = [m for m in (RE_SEED.search(l) for l in lines) if m]
    skips = [m for m in (RE_SKIP.search(l) for l in lines) if m]
    good = [m for m in seeds if m.group(2) == "uranium-235" and seed_min <= int(m.group(3)) <= HARD]
    good += [m for m in skips if m.group(2) == "uranium-235" and seed_min <= int(m.group(3)) <= HARD]
    verdict(bool(good), "C5.1 : cycle uranium-235 ferme, publie, avec sa cause (graine bornee [%d, %d] ou refus ecrit faute de recette a la main) : %s" % (
        seed_min, HARD, "; ".join("%s=%s (%s)" % (m.group(2), m.group(3), m.group(4)[:60]) for m in seeds + skips) or "aucune ligne"))
    over = [m for m in seeds if int(m.group(3)) > HARD]
    verdict(not over, "C5.1 : aucune graine au-dela de %d" % HARD)
    banc = [m for m in (RE_BANC.search(l) for l in lines) if m]
    verdict(bool(banc), "C5.2 : ligne [FO-CONFIRMATION-BANC] du scenario presente")
    if banc:
        key, posees, produites = banc[-1].group(1), int(banc[-1].group(2)), int(banc[-1].group(3))
        bilans = [m for m in (RE_BILAN.search(l) for l in lines) if m and m.group(1) == key]
        verdict(bool(bilans), "C5.2 : bilans [FO-CAPI-CONF] de %s relus (%d)" % (key, len(bilans)))
        if bilans:
            a, b = int(bilans[-1].group(2)), int(bilans[-1].group(3))
            ok = produites == 0 and b == 0 and a >= posees
            verdict(ok, "C5.2 : %s : %d posee(s), %d produite(s) ; dernier bilan : %d engage(s), %d confirme(s)" % (key, posees, produites, a, b))
            if ok:
                print("[FO-CONFIRMATION] 0 capacite fantome (%s : %d machine(s) posee(s) sans production, 0 confirmee)" % (key, posees))
    print("BILAN : %d ECHEC(S)" % fails)
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
