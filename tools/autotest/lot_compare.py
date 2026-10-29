# -*- coding: utf-8 -*-
"""Lot MESURES : comparaison d'un lot à la base commune, graine par graine (règle de docs/PORTES_LAYOUT_OUTILLAGE.md).

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/lot_compare.py --base <préfixe> --lot <préfixe> --seeds s1,s2,...
            [--aa <dossier de l'essai A/A>] [--minutes 60,40,20] [--gels]
  Les archives sont <préfixe>-<graine> (par exemple .../base et .../layout). --aa : dossier de l'essai A/A (graine lue
  dans seed.txt, comparée à la base de cette graine : donne le bruit d'un changement sans effet).
Pour chaque indicateur et chaque minute : par graine, base, lot, écart lot - base (et écart A/A de la graine), puis le
verdict RÉGRESSION / GAIN / INDISTINCT (au moins 3 graines sur 4 de même signe ET médiane de même signe), et les
ALERTES de mort (force vivante dans la base, morte dans le lot). Groupes : « joueur » (sa valeur) et « factions »
(médiane des factions vivantes). Aucun seuil absolu.
--gels : pour chaque partie, maximum, 99e centile et pics de scriptUpdate après le tick 3600, surcoût moyen des pics,
poste faction:think du profileur ; verdict « plus court » si le lot est plus petit sur au moins 3 graines sur 4 ET en médiane.
"""
import argparse
import gzip
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fonction_mesures as FM  # noqa: E402

RE_SOLD = re.compile(r"\[FO-[\w-]+\] minute (\d+) \| vivantes (\d+) \| (.*?) \| ouvriers du joueur")
RE_PART = re.compile(r"^(\S+) soldats (\d+) ouvriers (\d+)")

# (nom, libellé, groupes, source) : verdict pour LAYOUT et OUTILLAGE (docs/PORTES_LAYOUT_OUTILLAGE.md)
VERDICT_IND = [
    ("soldats", "soldats vivants", ("factions",)),
    ("tourelles_armees_n", "tourelles armées", ("joueur", "factions")),
    ("fe_working_n", "foreuses électriques en marche", ("joueur", "factions")),
    ("foreuses_working_n", "foreuses en marche (électriques + combustion)", ("joueur", "factions")),
    ("fours_a50_n", "fours productifs (>= 50 % de la cadence nominale)", ("joueur", "factions")),
    ("fours_prod_n", "fours ayant produit", ("joueur", "factions")),
]
INFO_IND = [
    ("plaques_min", "plaques/min (statistiques de force)", ("joueur", "factions")),
    ("fours_part_alimentee", "fours alimentés structurellement %", ("joueur", "factions")),
    ("tapis_part_utile", "tapis utiles %", ("joueur", "factions")),
    ("techs", "technologies terminées", ("joueur", "factions")),
]


def soldiers(arch):
    """{ minute: { clé: soldats } } (lignes « minute N | vivantes k | <clé> soldats S ouvriers W … ; … | ouvriers du joueur »)."""
    out = {}
    for ln in FM.read_log(arch):
        m = RE_SOLD.search(ln)
        if not m:
            continue
        row = {}
        for part in m.group(3).split(" ; "):
            mm = RE_PART.match(part.strip())
            if mm:
                row[mm.group(1)] = int(mm.group(2))
        out[int(m.group(1))] = row
    return out


def load(path):
    rec = FM.load(path)
    rec["soldats"] = soldiers(path)
    return rec


def median(xs):
    return FM.median(xs)


def value(rec, group, name, minute):
    """Valeur d'un indicateur pour le groupe à la minute : (valeur ou None, vivantes, total) ; mortes exclues."""
    vals, alive, total = [], 0, 0
    if name == "soldats":
        mm = FM.nearest(rec["soldats"].keys(), minute)
        if mm is None or group != "factions":
            return None, 0, 0
        for key, v in rec["soldats"][mm].items():
            fm = rec["forces"].get(key, {})
            fmm = FM.nearest(fm.keys(), minute)
            dead = fmm is not None and fm[fmm]["morte"]
            total += 1
            if not dead:
                alive += 1
                vals.append(v)
        return median(vals), alive, total
    for key, fm in rec["forces"].items():
        if (key == "player") != (group == "joueur"):
            continue
        mm = FM.nearest(fm.keys(), minute)
        if mm is None:
            continue
        total += 1
        if fm[mm]["morte"]:
            continue
        alive += 1
        v = fm[mm]["ind"].get(name)
        if v is not None:
            vals.append(v)
    return median(vals), alive, total


def deaths(rec_base, rec_lot, minute):
    """Forces vivantes dans la base à la minute et mortes (ou absentes) dans le lot : liste de clés."""
    out = []
    for key, fm in rec_base["forces"].items():
        mm = FM.nearest(fm.keys(), minute)
        if mm is None or fm[mm]["morte"]:
            continue
        fl = rec_lot["forces"].get(key)
        ml = FM.nearest(fl.keys(), minute) if fl else None
        if ml is None or fl[ml]["morte"]:
            out.append(key)
    return sorted(out)


def verdict(diffs, lower_is_better=False):
    """diffs : écarts appariés (lot - base) ; renvoie ('REGRESSION' | 'GAIN' | 'INDISTINCT', nb négatifs, nb positifs, médiane)."""
    d = [x for x in diffs if x is not None]
    if not d:
        return "SANS DONNEE", 0, 0, None
    neg = sum(1 for x in d if x < 0)
    pos = sum(1 for x in d if x > 0)
    med = median(d)
    need = max(3, (3 * len(d) + 3) // 4)  # 3 sur 4 ; avec n graines, au moins 3/4 arrondi au-dessus
    bad, good = (pos, neg) if lower_is_better else (neg, pos)
    if bad >= need and ((med > 0) if lower_is_better else (med < 0)):
        return "REGRESSION", neg, pos, med
    if good >= need and ((med < 0) if lower_is_better else (med > 0)):
        return "GAIN", neg, pos, med
    return "INDISTINCT", neg, pos, med


def f(v):
    return "-" if v is None else ("%.1f" % v if isinstance(v, float) else str(v))


def compare(base, lot, aa, seeds, minute, out, names):
    """base, lot : { graine: rec } ; aa : (graine, rec) ou None. Renvoie { (nom, groupe): verdict }."""
    res = {}
    for name, label, groups in names:
        for g in groups:
            diffs, rows = [], []
            for s in seeds:
                if s not in base or s not in lot:
                    continue
                vb, ab, tb = value(base[s], g, name, minute)
                vl, al, tl = value(lot[s], g, name, minute)
                d = (vl - vb) if (vb is not None and vl is not None) else None
                diffs.append(d)
                da = None
                if aa and aa[0] == s:
                    va, _, _ = value(aa[1], g, name, minute)
                    da = (va - vb) if (va is not None and vb is not None) else None
                rows.append((s, vb, vl, d, da, "%d/%d" % (ab, tb), "%d/%d" % (al, tl)))
            v = verdict(diffs)
            res[(name, g)] = v
            out.write("  %-52s %-9s m%d : %s (négatifs %d, positifs %d, médiane écart %s)\n" % (
                label, g, minute, v[0], v[1], v[2], f(v[3])))
            for s, vb, vl, d, da, sb, sl in rows:
                out.write("      graine %-11s base %8s  lot %8s  écart %8s%s   vivantes base %s lot %s\n" % (
                    s, f(vb), f(vl), f(d), ("   [A/A %s%s]" % (f(da), "" if (da is None or d is None) else (" ; hors A/A" if abs(d) > abs(da) else " ; dans A/A"))) if da is not None else "", sb, sl))
    return res


# ------------------------------------------------------------------ gels (OUTILLAGE)
RE_FENETRE = re.compile(r"Profiler \(fenetre (\d+) ticks\)")
RE_POSTE = re.compile(r"^\s*([^\s|]+) \| total Duration: ([0-9.]+)ms \| moyenne/tick Duration: ([0-9.]+)ms")


def gel_stats(arch, depuis=3600, periode_rapports=0):
    """{ max, p99, pics, surcout_tick, think_tick, ticks } ou None. Pics : > max(4 x médiane, 3 ms) après `depuis`."""
    import analyze
    texte = None
    for nm in ("benchmark-stdout.txt.gz", "benchmark-stdout.txt"):
        p = os.path.join(arch, nm)
        if os.path.exists(p):
            opener = gzip.open if nm.endswith(".gz") else open
            with opener(p, "rt", encoding="utf-8", errors="replace") as fh:
                texte = fh.read()
            break
    if texte is None:
        return None
    header, rows = analyze.parse_verbose(texte)
    if not header or "scriptUpdate" not in header:
        return None
    i = header.index("scriptUpdate") - 1
    # periode_rapports : écarte les ticks des rapports du banc lui-même (etape1-guide : tous les 36 000 ticks, 600 ms et plus
    # dans les DEUX bras) ; 0 = rien d'écarté (définition écrite avant les parties de docs/PORTES_LAYOUT_OUTILLAGE.md)
    ms = [vals[i] / 1e6 for tick, vals in rows if tick >= depuis and len(vals) > i
          and not (periode_rapports and tick % periode_rapports == 0)]
    if not ms:
        return None
    srt = sorted(ms)
    med = srt[len(srt) // 2]
    seuil = max(4 * med, 3.0)
    pics = [x for x in ms if x > seuil]
    think = None
    fen = 0
    cur = None
    for ln in FM.read_log(arch):
        m = RE_FENETRE.search(ln)
        if m:
            fen = int(m.group(1))
            continue
        m = RE_POSTE.match(ln.split("remote.lua:60:", 1)[-1])
        if m and m.group(1) == "faction:think" and fen:
            cur = float(m.group(3))
    think = cur
    return {"max": srt[-1], "p99": srt[min(len(srt) - 1, int(0.99 * len(srt)))], "pics": len(pics), "moy": sum(ms) / len(ms),
            "surcout_tick": sum(x - med for x in pics) / len(ms), "think_tick": think, "ticks": len(ms)}


def compare_gels(base, lot, aa, seeds, out):
    for fld, label in (("max", "scriptUpdate maximal (ms)"), ("p99", "scriptUpdate 99e centile (ms)"), ("moy", "scriptUpdate moyen (ms/tick)"),
                       ("surcout_tick", "surcoût moyen des pics (ms/tick)"), ("think_tick", "faction:think (ms/tick)")):
        diffs, rows = [], []
        for s in seeds:
            gb, gl = base.get(s), lot.get(s)
            if not gb or not gl or gb.get(fld) is None or gl.get(fld) is None:
                continue
            diffs.append(gl[fld] - gb[fld])
            rows.append((s, gb[fld], gl[fld], (aa[1].get(fld) - gb[fld]) if aa and aa[0] == s and aa[1] and aa[1].get(fld) is not None else None))
        v = verdict(diffs, lower_is_better=True)
        lab = {"REGRESSION": "PLUS LONG (régression)", "GAIN": "PLUS COURT (gain)", "INDISTINCT": "INDISTINCT"}.get(v[0], v[0])
        out.write("  %-40s : %s (plus courts %d, plus longs %d, médiane écart %s)\n" % (label, lab, v[1], v[2], f(v[3] if v[3] is None else round(v[3], 3))))
        for s, b, l, a in rows:
            out.write("      graine %-11s base %9.3f  lot %9.3f  écart %9.3f%s\n" % (s, b, l, l - b, "" if a is None else "   [A/A %.3f]" % a))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--lot", required=True)
    ap.add_argument("--seeds", required=True)
    ap.add_argument("--aa")
    ap.add_argument("--minutes", default="60,40,20")
    ap.add_argument("--gels", action="store_true")
    ap.add_argument("--sans-rapports", type=int, default=0, metavar="PERIODE",
                    help="avec --gels : refait le tableau en écartant les ticks multiples de PERIODE (rapports du banc, 36000)")
    a = ap.parse_args(argv)
    seeds = a.seeds.split(",")
    minutes = [int(x) for x in a.minutes.split(",")]
    base = {s: load("%s-%s" % (a.base, s)) for s in seeds if os.path.isdir("%s-%s" % (a.base, s))}
    lot = {s: load("%s-%s" % (a.lot, s)) for s in seeds if os.path.isdir("%s-%s" % (a.lot, s))}
    aa = None
    if a.aa and os.path.isdir(a.aa):
        r = load(a.aa)
        aa = (FM.read_seed(a.aa), r)
    out = sys.stdout
    out.write("== base %s ; lot %s ; graines base %s, lot %s ; A/A %s\n" % (a.base, a.lot, ",".join(base), ",".join(lot),
                                                                       aa[0] if aa else "-"))
    for m in minutes:
        out.write("-- indicateurs à verdict, minute %d\n" % m)
        compare(base, lot, aa, seeds, m, out, VERDICT_IND)
        out.write("-- information (pas de verdict), minute %d\n" % m)
        compare(base, lot, aa, seeds, m, out, INFO_IND)
        al = []
        for s in seeds:
            if s in base and s in lot:
                d = deaths(base[s], lot[s], m)
                if d:
                    al.append("%s: %s" % (s, ",".join(d)))
        out.write("-- ALERTES de mort (vivante dans la base, morte dans le lot) minute %d : %s\n" % (m, "; ".join(al) or "aucune"))
    if a.gels:
        gb = {s: gel_stats("%s-%s" % (a.base, s)) for s in seeds}
        gl = {s: gel_stats("%s-%s" % (a.lot, s)) for s in seeds}
        ga = (aa[0], gel_stats(a.aa)) if aa else None
        out.write("-- gels de scriptUpdate (après le tick 3600) : plus court = mieux\n")
        compare_gels(gb, gl, ga, seeds, out)
        if a.sans_rapports:
            P = a.sans_rapports
            gb = {s: gel_stats("%s-%s" % (a.base, s), periode_rapports=P) for s in seeds}
            gl = {s: gel_stats("%s-%s" % (a.lot, s), periode_rapports=P) for s in seeds}
            ga = (aa[0], gel_stats(a.aa, periode_rapports=P)) if aa else None
            out.write("-- MÊMES gels en écartant les ticks multiples de %d (rapports du banc lui-même ; correction de mesure faite APRES lecture, voir la note)\n" % P)
            compare_gels(gb, gl, ga, seeds, out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
