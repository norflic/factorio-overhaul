# Lot REGARD : ce que le DC voit, lu dans les archives de banc.py (lignes [FO-REGARD] de scenarios/dc_evolution_common.lua).
# Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/regard.py [--heure] [--pas N] [--stock-min N] <archive> [<archive> ...]
# Par archive et par force : un tableau (une ligne par releve de 5 min ; --heure : un releve par heure + le dernier ;
# --pas N : un releve sur N minutes), puis un verdict par critere du DC (retour du 2/11, fo-logs/2026-11-02_RETOUR/RETOUR_DC.md) :
#   1 electrique dominant sur chaque gisement     6 tourelles reparties (pas toutes autour du QG)
#   2 aucun minerai fige sur les tapis            7 courant sans coupure
#   3 fonderie >= extraction                      8 PNJ non coinces
#   4 cuivre/fer proche du rapport des gisements  9 age qui progresse
#   5 0 minage a la main avec un stock suffisant
# Les seuils sont PROVISOIRES (constantes ci-dessous) ; chaque verdict ecrit le chiffre qui le fonde.
# Un tapis n'expose pas la position de ses objets (API 1.1) : « minerai fige » est un MAJORANT (voir le scenario).
import argparse
import gzip
import math
import os
import re
import sys

LINE = re.compile(r"\[FO-REGARD\] (\S+) (.*)$")
BRACE = re.compile(r"(\w+) \{([^}]*)\}")
KV = re.compile(r"([A-Za-z_][\w]*)=(\S+)")
KVH = re.compile(r"([\w-]+)=(\S+)")
MINAGE = re.compile(r"\[FO-MINAGE\] (\w+) min=([\d.]+) (\S+) got=(-?\d+)/(\d+) dt=([\d.]+) (\S+) sol=(\d+) cle=(\S+) coffre=(\d+)")
PLATE_OF = {"iron-ore": "iron-plate", "copper-ore": "copper-plate", "stone": "stone-brick"}

# Seuils provisoires
FIGE_MAX = 200          # minerai « fige 10 min » toleré sur les tapis d'une force (objets)
FIGE_DEPUIS = 15        # minute a partir de laquelle on juge le fige (les tapis se remplissent avant)
FONDERIE_MIN = 0.90     # plaques produites / minerai extrait (fer + cuivre), depuis la minute 10
RAPPORT_ECART = 1.5     # cuivre/fer des plaques contre cuivre/fer des gisements : facteur toléré
TOUR_QG_MAX = 0.5       # part des tourelles a moins de 15 tuiles du QG
TOUR_MIN = 8            # en dessous, pas de verdict
COUPE_MAX = 0.05        # part des consommateurs sans courant
STOCK_MIN = 300         # stock (coffres + plaques qui dorment) a partir duquel miner a la main est injustifie


def lire(arch):
    for nom in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, nom)
        if os.path.exists(p):
            f = gzip.open(p, "rt", encoding="utf8", errors="replace") if nom.endswith(".gz") else open(p, encoding="utf8", errors="replace")
            with f:
                return f.read().splitlines()
    return []


def nombre(v):
    try:
        return float(v)
    except ValueError:
        return v


def analyser(lignes):
    """-> (rel, minages, couts) ; rel[force][minute] = {R, F, C, T, G: [..]}."""
    rel, minages, couts = {}, [], []
    for ln in lignes:
        m = MINAGE.search(ln)
        if m:
            minages.append({"cle": m.group(1), "min": float(m.group(2)), "item": m.group(3), "got": int(m.group(4)), "count": int(m.group(5)),
                            "coffre": int(m.group(10))})
            continue
        m = LINE.search(ln)
        if not m:
            continue
        genre, reste = m.group(1), m.group(2)
        if genre in ("TACHE", "COUT"):
            couts.append((genre, reste.strip()))
        if genre not in ("R", "F", "C", "T", "G"):
            continue
        sous = {}
        for nom, corps in BRACE.findall(reste):
            sous[nom] = {k: nombre(v) for k, v in KVH.findall(corps)}
        reste = BRACE.sub("", reste)
        d = {k: nombre(v) for k, v in KV.findall(reste)}
        d.update(sous)
        if "min" not in d or "force" not in d:
            continue
        r = rel.setdefault(d["force"], {}).setdefault(int(d["min"]), {"G": []})
        if genre == "G":
            if "tuiles" in d:
                r["G"].append(d)
        else:
            r[genre] = d
    return rel, minages, couts


def g(d, k, defaut=0.0):
    v = (d or {}).get(k, defaut)
    return v if isinstance(v, (int, float)) else defaut


def somme_g(r, k):
    return sum(g(x, k) for x in r["G"])


def pct(a, b):
    return "%3.0f" % (100.0 * a / b) if b else "  -"


def lignes_tableau(rel_f, minutes):
    ent = ("min", "age", "tech", "PNJ", "fer/m", "cu/m", "cu/fe", "oreFe/m", "fours", "dort", "elec", "therm", "couv%", "tuiles",
           "bouche", "fige10", "tour", "qg", "cut%", "coinc", "main")
    out = [ent]
    for mn in minutes:
        r = rel_f[mn]
        R, F, C, T = r.get("R"), r.get("F"), r.get("C"), r.get("T")
        fl = (R or {}).get("flux_min", {})
        fe, cu = g(fl, "iron-plate"), g(fl, "copper-plate")
        tuiles = somme_g(r, "tuiles")
        cons = g(C, "consommateurs")
        out.append((
            str(mn), str(int(g(R, "age", -1))), str(int(g(R, "tech"))), str(int(g(R, "n"))), "%.0f" % fe, "%.0f" % cu,
            "%.2f" % (cu / fe) if fe > 0 else "-", "%.0f" % g(fl, "iron-ore"),
            "%d/%d" % (g(F, "marche"), g(F, "fours")), "%d" % (g(F, "fer_dort") + g(F, "cuivre_dort")),
            "%d" % somme_g(r, "de"), "%d" % somme_g(r, "dt"), pct(somme_g(r, "couv"), tuiles), "%d" % tuiles,
            "%d" % g(T, "minerai_bouche"), "%d" % g(T, "minerai_fige10"), "%d" % g(R, "tourelles"), "%d" % g(R, "tourelles_qg"),
            pct(g(C, "sans_courant"), cons), "%d/%d" % (g(R, "coinces"), g(R, "immobiles")), "%d" % g(R, "mine_main")))
    larg = [max(len(l[i]) for l in out) for i in range(len(ent))]
    return ["  " + " ".join(c.rjust(larg[i]) for i, c in enumerate(l)) for l in out]


def choisir(minutes, args):
    if args.heure:
        pas = 60
    else:
        pas = args.pas
    if pas <= 5:
        return minutes
    sel = [m for m in minutes if m % pas == 0]
    if minutes and minutes[-1] not in sel:
        sel.append(minutes[-1])
    return sel


# ---------------------------------------------------------------------------------------------------------- verdicts
def v_electrique(rel_f, minutes):
    r = rel_f[minutes[-1]]
    mauvais = [x for x in r["G"] if g(x, "dt") > g(x, "de") or g(x, "couv_t") > g(x, "couv_e")]
    total = len(r["G"])
    if not total:
        return None, "aucun gisement exploite au dernier releve"
    de, dt = somme_g(r, "de"), somme_g(r, "dt")
    det = "min %d : %d gisement(s), electriques %d / thermiques %d" % (minutes[-1], total, de, dt)
    if mauvais:
        det += " ; thermique dominant sur " + ", ".join("%s@%s (e%d/t%d, couv e%d t%d)" % (
            x["res"], x["c"], g(x, "de"), g(x, "dt"), g(x, "couv_e"), g(x, "couv_t")) for x in mauvais[:6])
    return not mauvais, det


def v_fige(rel_f, minutes):
    pics = [(g(rel_f[m].get("T"), "minerai_fige10"), m) for m in minutes if m >= FIGE_DEPUIS and "T" in rel_f[m]]
    if not pics:
        return None, "pas de releve apres la minute %d" % FIGE_DEPUIS
    pic, mn = max(pics)
    T = rel_f[mn].get("T")
    return pic <= FIGE_MAX, "pic %d objets figes depuis 10 min (min %d, minerai sur tapis %d, bouche %d) ; seuil %d" % (
        pic, mn, g(T, "minerai_sur_tapis"), g(T, "minerai_bouche"), FIGE_MAX)


def v_fonderie(rel_f, minutes):
    ore = plaques = 0.0
    fours = []
    for m in minutes:
        if m < 10:
            continue
        fl = (rel_f[m].get("R") or {}).get("flux_min", {})
        ore += 5 * (g(fl, "iron-ore") + g(fl, "copper-ore"))
        plaques += 5 * (g(fl, "iron-plate") + g(fl, "copper-plate"))
        F = rel_f[m].get("F")
        if F and g(F, "fours"):
            fours.append(g(F, "marche") / g(F, "fours"))
    if ore <= 0:
        return None, "aucun minerai extrait mesure"
    rap = plaques / ore
    det = "plaques %d pour %d minerai extrait (fer+cuivre, min 10 a %d) = %.2f ; seuil %.2f" % (plaques, ore, minutes[-1], rap, FONDERIE_MIN)
    if fours:
        det += " ; fours en marche %.0f %% en moyenne" % (100 * sum(fours) / len(fours))
    return rap >= FONDERIE_MIN, det


def v_rapport(rel_f, minutes):
    fe = cu = 0.0
    for m in minutes:
        if m < 10:
            continue
        fl = (rel_f[m].get("R") or {}).get("flux_min", {})
        fe += g(fl, "iron-plate")
        cu += g(fl, "copper-plate")
    r = rel_f[minutes[-1]]
    tfe = sum(g(x, "tuiles") for x in r["G"] if x["res"] == "iron-ore")
    tcu = sum(g(x, "tuiles") for x in r["G"] if x["res"] == "copper-ore")
    afe = sum(g(x, "reste") for x in r["G"] if x["res"] == "iron-ore")
    acu = sum(g(x, "reste") for x in r["G"] if x["res"] == "copper-ore")
    if fe <= 0 or tfe <= 0 or tcu <= 0:
        return None, "fer %d plaques, gisements exploites fer %d / cuivre %d tuiles : pas de rapport" % (fe * 5, tfe, tcu)
    rp, rg_ = cu / fe, tcu / tfe
    ok = rg_ / RAPPORT_ECART <= rp <= rg_ * RAPPORT_ECART
    return ok, "cuivre/fer des plaques %.2f contre %.2f des gisements exploites (tuiles %d/%d ; minerai restant %d/%d = %.2f) ; facteur toleré %.1f" % (
        rp, rg_, tcu, tfe, acu, afe, acu / afe if afe else 0, RAPPORT_ECART)


def v_main(rel_f, minutes, minages, cle, stock_min):
    mines = [x for x in minages if x["cle"] == cle]
    if not minutes:
        return None, "?"
    par_item = {}
    for x in mines:
        par_item[x["item"]] = par_item.get(x["item"], 0) + 1
    mauvais = []
    for x in mines:
        if x["item"] not in ("iron-ore", "copper-ore", "coal", "stone"):
            continue
        avant = [m for m in minutes if m <= x["min"]] or [minutes[0]]
        r = rel_f[avant[-1]]
        stock = (r.get("R") or {}).get("stock", {})
        equiv = PLATE_OF.get(x["item"])
        fours = g(r.get("F"), {"iron-plate": "fer_dort", "copper-plate": "cuivre_dort"}.get(equiv, "_"))
        total = max(x["coffre"], g(stock, x["item"])) + (g(stock, equiv) + fours if equiv else 0)
        if total >= stock_min:
            mauvais.append((x["min"], x["item"], total))
    det = "%d minage(s) a la main (%s)" % (len(mines), ", ".join("%s %d" % kv for kv in sorted(par_item.items())) or "aucun")
    if mauvais:
        det += " ; %d avec un stock >= %d : %s" % (len(mauvais), stock_min, ", ".join("min %.0f %s (stock %d)" % x for x in mauvais[:6]))
    return not mauvais, det


def v_tourelles(rel_f, minutes):
    pics = []
    for m in minutes[-3:]:
        R = rel_f[m].get("R")
        if R and g(R, "tourelles") >= TOUR_MIN:
            pics.append((g(R, "tourelles_qg") / g(R, "tourelles"), m, g(R, "tourelles_qg"), g(R, "tourelles")))
    if not pics:
        R = rel_f[minutes[-1]].get("R")
        return None, "%d tourelle(s) au dernier releve (< %d : pas de verdict)" % (g(R, "tourelles"), TOUR_MIN)
    p = max(pics)
    return p[0] <= TOUR_QG_MAX, "a moins de 15 tuiles du QG : %d sur %d (%.0f %%, min %d) ; seuil %.0f %%" % (p[2], p[3], 100 * p[0], p[1], 100 * TOUR_QG_MAX)


def v_courant(rel_f, minutes):
    pic, mn, cons = 0.0, None, 0
    sans_comb = 0.0
    for m in minutes:
        C = rel_f[m].get("C")
        if not C or g(C, "consommateurs") < 10:
            continue
        p = g(C, "sans_courant") / g(C, "consommateurs")
        if p >= pic:
            pic, mn, cons = p, m, g(C, "consommateurs")
        if g(C, "chaudieres"):
            sans_comb = max(sans_comb, g(C, "chaudieres_sans_combustible") / g(C, "chaudieres"))
    if mn is None:
        return None, "moins de 10 consommateurs electriques"
    return pic < COUPE_MAX, "pic de consommateurs sans courant %.1f %% (min %d, sur %d) ; chaudieres sans combustible au pire %.0f %% ; seuil %.0f %%" % (
        100 * pic, mn, cons, 100 * sans_comb, 100 * COUPE_MAX)


def v_pnj(rel_f, minutes):
    serie = [(g(rel_f[m].get("R"), "coinces"), m) for m in minutes if "R" in rel_f[m]]
    imm = max([(g(rel_f[m].get("R"), "immobiles"), m) for m in minutes if "R" in rel_f[m]] or [(0, 0)])
    de_suite = best = 0
    for c, _ in serie:
        de_suite = de_suite + 1 if c > 0 else 0
        best = max(best, de_suite)
    pos = [(m, rel_f[m]["R"].get("coinces_pos")) for c, m in serie if c > 0 and isinstance(rel_f[m]["R"].get("coinces_pos"), str)]
    det = "coinces (immobiles 2 min et entoures de batiments) : jusqu'a %d de suite ; immobiles 2 min au pire %d (min %d)" % (best, imm[0], imm[1])
    if pos:
        det += " ; ex. min %d en %s" % pos[-1]
    return best < 2, det


def v_age(rel_f, minutes):
    ages = [(g(rel_f[m].get("R"), "age", -1), g(rel_f[m].get("R"), "tech"), m) for m in minutes if "R" in rel_f[m]]
    if not ages:
        return None, "?"
    a0, a1 = ages[0], ages[-1]
    avant = ages[max(0, len(ages) - 7)]
    monte = a1[0] > a0[0] or a1[1] > avant[1]
    return monte, "age %d -> %d, tech %d -> %d (min %d a %d) ; tech il y a 30 min : %d" % (a0[0], a1[0], a0[1], a1[1], a0[2], a1[2], avant[1])


CRITERES = [
    ("1 electrique dominant", v_electrique), ("2 aucun minerai fige", v_fige), ("3 fonderie >= extraction", v_fonderie),
    ("4 cuivre/fer ~ gisements", v_rapport), ("5 0 minage main avec stock", None), ("6 tourelles reparties", v_tourelles),
    ("7 courant sans coupure", v_courant), ("8 PNJ non coinces", v_pnj), ("9 age progresse", v_age),
]


def marque(ok):
    return "n/a " if ok is None else ("OK  " if ok else "FAUX")


def traiter(arch, args):
    rel, minages, couts = analyser(lire(arch))
    seed = ""
    sp = os.path.join(arch, "seed.txt")
    if os.path.exists(sp):
        seed = open(sp).read().strip()
    print("== %s (graine %s)" % (os.path.basename(os.path.normpath(arch)), seed or "?"))
    if not rel:
        print("  aucune ligne [FO-REGARD] (banc sans le scenario dc-evolution/dc-croissance ?)")
        return {}
    bilan = {}
    for force in sorted(rel):
        rel_f = rel[force]
        minutes = sorted(rel_f)
        cle = (rel_f[minutes[-1]].get("R") or {}).get("cle", force.replace("fo-", ""))
        print("\n-- %s (%s), releves minutes %d a %d" % (force, cle, minutes[0], minutes[-1]))
        for l in lignes_tableau(rel_f, choisir(minutes, args)):
            print(l)
        bilan[force] = {}
        for nom, fn in CRITERES:
            if fn is None:
                ok, det = v_main(rel_f, minutes, minages, cle, args.stock_min)
            else:
                ok, det = fn(rel_f, minutes)
            bilan[force][nom] = ok
            print("  [%s] %s : %s" % (marque(ok), nom, det))
    cout = [c for c in couts if c[0] == "COUT"]
    if cout:
        print("\n-- cout du releve (profileur du moteur, par force et par releve) : %d ligne(s), p. ex. %s" % (len(cout), cout[-1][1]))
    taches = [c[1] for c in couts if c[0] == "TACHE"]
    if taches:
        print("   plus longue tache du premier releve : " + max(taches, key=lambda s: duree_ms(s)))
    return bilan


def duree_ms(texte):
    m = re.search(r"([\d.]+)\s*(ms|s|us|µs)", texte)
    if not m:
        return 0.0
    v = float(m.group(1))
    return v * {"s": 1000.0, "ms": 1.0, "us": 0.001, "µs": 0.001}[m.group(2)]


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("archives", nargs="+")
    ap.add_argument("--heure", action="store_true", help="un releve par heure")
    ap.add_argument("--pas", type=int, default=5, help="un releve sur N minutes")
    ap.add_argument("--stock-min", type=int, default=STOCK_MIN)
    args = ap.parse_args(argv)
    tout = {}
    for a in args.archives:
        tout[os.path.basename(os.path.normpath(a))] = traiter(a, args)
        print()
    if True:
        print("== SYNTHESE (OK / FAUX / n/a par critere ; une colonne par force de chaque archive)")
        for nom, _ in CRITERES:
            cases = []
            for arch, forces in tout.items():
                for f in sorted(forces):
                    cases.append(marque(forces[f].get(nom)).strip())
            ok, faux = cases.count("OK"), cases.count("FAUX")
            print("  %-30s OK %2d  FAUX %2d  n/a %2d" % (nom, ok, faux, len(cases) - ok - faux))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
