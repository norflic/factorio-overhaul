# Lot GEANT-D-ABORD (9/11) : relevé des critères écrits AVANT les parties à 600 % (banc.py --carte-max, etape1-carte).
# Par équipe, à 60 et 120 minutes : le plus grand gisement suivi par la capitalisation (tuiles couvertes sur tuiles, foreuses posées dessus), le fer par minute
# (fer_min, plaques_min, ore_fer_min de [FO-FONCTION] prod), les morts de la fenêtre (morte=) ; puis le nombre de foreuses posées autour de chaque QG
# ([FO-CARTE-MAX] champ). Lit benchmark.log(.gz) d'une ou plusieurs archives.
# Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/geant_mesure.py <archive> [<archive> ...]
import gzip, os, re, sys

COUV = re.compile(r"\[FO-CAPI-COUV\] (\w+) minute (\d+) \| gisement (\S+) (\S+) \| couverture (\d+)/(\d+) \((\d+) pour mille\) \| places libres (\d+) \| foreuses posees (\d+)")
PROD = re.compile(r"\[FO-FONCTION\] prod minute (\d+) \| (\w+) \| fenetre=([\d.]+) pnj=(\d+) morte=(\d+) plaques_min=([\d.]+) fer_min=([\d.]+).*?ore_fer_min=([\d.]+)")
CHAMP = re.compile(r"\[FO-CARTE-MAX\] champ minute (\d+) \| (\w+) \| (\d+) foreuses autour de")


def lire(archive):
    for nom in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(archive, nom)
        if os.path.exists(p):
            f = gzip.open(p, "rt", encoding="utf8", errors="replace") if nom.endswith(".gz") else open(p, encoding="utf8", errors="replace")
            with f:
                return f.read().splitlines()
    return []


def proche(d, cible, marge=8):
    """Entrée de d (clé : minute) la plus proche de `cible`, à `marge` minutes au plus."""
    best = None
    for m in d:
        if abs(m - cible) <= marge and (best is None or abs(m - cible) < abs(best - cible)):
            best = m
    return best


def releve(archive):
    couv, prod, champ = {}, {}, {}
    for ln in lire(archive):
        m = COUV.search(ln)
        if m:
            team, minute, dep, res, cov, tiles, pm, free, drills = m.groups()
            couv.setdefault(team, {}).setdefault(int(minute), {})[dep] = (int(cov), int(tiles), int(drills), res)
            continue
        m = PROD.search(ln)
        if m:
            minute, team, fen, pnj, mort, plaques, fer, ore = m.groups()
            prod.setdefault(team, {})[int(minute)] = (float(fer), float(plaques), float(ore), int(mort), int(pnj))
            continue
        m = CHAMP.search(ln)
        if m:
            champ.setdefault(m.group(2), {})[int(m.group(1))] = int(m.group(3))
    out = ["== " + os.path.basename(os.path.normpath(archive))]
    for team in sorted(set(couv) | set(prod)):
        for cible in (60, 120):
            ligne = "  %-8s %3d min :" % (team, cible)
            mc = proche(couv.get(team, {}), cible)
            if mc is not None:
                deps = couv[team][mc]
                big = sorted(deps.items(), key=lambda kv: (-kv[1][1], kv[0]))[:2]
                ligne += " plus grands gisements (minute %d) %s" % (mc, " ; ".join("%s %d/%d tuiles, %d foreuses" % (k, v[0], v[1], v[2]) for k, v in big))
            else:
                ligne += " (aucun relevé de gisement)"
            mp = proche(prod.get(team, {}), cible, 12)
            if mp is not None:
                fer, plaques, ore, mort, pnj = prod[team][mp]
                ligne += " | minute %d : fer %.0f/min, plaques %.0f/min, minerai de fer %.0f/min, morts %d, pnj %d" % (mp, fer, plaques, ore, mort, pnj)
            out.append(ligne)
    for team in sorted(champ):
        last = max(champ[team])
        out.append("  champ %-8s foreuses autour du QG : %s" % (team, ", ".join("min %d : %d" % (m, champ[team][m]) for m in sorted(champ[team])[-3:])))
    return "\n".join(out)


if __name__ == "__main__":
    for a in sys.argv[1:]:
        print(releve(a))
