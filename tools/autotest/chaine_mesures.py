#!/usr/bin/env python
"""Lot MAINS-CHAINE : lecture des releves [FO-FONCTION] chaine d'archives de banc et jugement des criteres C1 a C5 (CRITERES.md).

Usage :
  python -B tools/autotest/chaine_mesures.py ARCHIVE [ARCHIVE ...]                 -> tableau par archive (equipe du joueur)
  python -B tools/autotest/chaine_mesures.py --temoin "<dir>/t-{seed}" --lot "<dir>/l-{seed}" [--coupure]
        -> criteres sur les 4 graines (20261020 123456789 271828182 1618033988), `{seed}` remplace par la graine.
Aucune lecture n'entre dans un BILAN du jeu ; ce fichier ne juge que des archives.
"""
import gzip
import os
import re
import sys

SEEDS = ["20261020", "123456789", "271828182", "1618033988"]
RE_LINE = re.compile(r"\[FO-FONCTION\] (\w+) minute (\d+) \| ([^|]+?) \| (.*)$")
RE_KV = re.compile(r"(\w+)=(\S+)")
RE_ECHEC = re.compile(r"\[FO-ETAPE1-GUIDE\] BILAN : (\d+) OK, (\d+) ECHEC")


def read_log(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            opener = gzip.open if name.endswith(".gz") else open
            with opener(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


def num(v):
    try:
        return int(v)
    except ValueError:
        try:
            return float(v)
        except ValueError:
            return v


def parse(lines, key="player"):
    """-> ({ minute: { genre: {k: v} } }, ECHEC du BILAN ETAPE1 ou None) pour la cle donnee."""
    out = {}
    echec = None
    for ln in lines:
        m = RE_LINE.search(ln)
        if m:
            kind, minute, k, body = m.group(1), int(m.group(2)), m.group(3).strip(), m.group(4)
            if k != key or kind in ("parite", "statut"):
                continue
            out.setdefault(minute, {})[kind] = {a: num(b) for a, b in RE_KV.findall(body)}
            continue
        b = RE_ECHEC.search(ln)
        if b:
            echec = int(b.group(2))
    return out, echec


def window(data, lo, hi, kind, field, default=0):
    return [data[m][kind].get(field, default) for m in sorted(data) if lo <= m <= hi and kind in data[m]]


def mean(xs):
    return sum(xs) / len(xs) if xs else None


def summary(arch, key="player", lo=10, hi=60):
    data, echec = parse(read_log(arch), key)
    s = {"arch": arch, "echec": echec, "data": data}
    s["ore50_moy"] = mean(window(data, lo, hi, "chaine", "porte_ore50_pct"))
    s["dur_max_s"] = max(window(data, lo, hi, "chaine", "porte_dur_max_s") or [0])
    s["haut_max"] = max(window(data, lo, hi, "chaine", "porte_haut_max") or [0])
    s["ore_max"] = max(window(data, lo, hi, "chaine", "porte_ore_max") or [0])
    for f in ("fonte_vide", "tournees", "mine_zero", "depot_refuse", "mine_ore", "fondu"):
        s[f] = sum(window(data, lo, hi, "chaine", f))
    s["coffre_ore_m60"] = (data.get(60, {}).get("chaine") or {}).get("coffre_ore")
    s["plaques_moy"] = mean(window(data, lo, hi, "prod", "plaques_min"))
    s["inactifs_moy"] = mean(window(data, lo, hi, "corps", "inactifs_mod_pct"))
    s["pnj_m60"] = (data.get(60, {}).get("corps") or {}).get("corps")
    s["morts"] = sum(window(data, lo, hi, "prod", "morte"))
    return s


def fmt(v):
    if v is None:
        return "-"
    if isinstance(v, float):
        return "%.1f" % v
    return str(v)


COLS = ["ore50_moy", "dur_max_s", "haut_max", "ore_max", "fonte_vide", "tournees", "mine_zero", "depot_refuse", "mine_ore",
        "fondu", "coffre_ore_m60", "plaques_moy", "inactifs_moy", "pnj_m60", "echec"]


def table(sums):
    print("%-30s %s" % ("archive", " ".join("%12s" % c for c in COLS)))
    for s in sums:
        name = os.path.basename(s["arch"].rstrip("/\\"))[:30]
        print("%-30s %s" % (name, " ".join("%12s" % fmt(s[c]) for c in COLS)))


def judge(temoin, lot):
    """Criteres C1, C3, C4, C5 (partie mesuree) sur les 4 graines ; rend (liste de (nom, ok, detail), ok_global)."""
    res = []

    def add(name, ok, detail):
        res.append((name, bool(ok), detail))

    t_ore = sum(s["ore50_moy"] or 0 for s in temoin)
    l_ore = sum(s["ore50_moy"] or 0 for s in lot)
    add("C1 somme porte_ore50_pct lot <= temoin", l_ore <= t_ore + 1e-9, "lot %.1f temoin %.1f" % (l_ore, t_ore))
    t_dur = max(s["dur_max_s"] for s in temoin)
    l_dur = max(s["dur_max_s"] for s in lot)
    add("C1 duree max (pire graine) lot <= max(temoin, 300 s)", l_dur <= max(t_dur, 300), "lot %s temoin %s" % (l_dur, t_dur))
    t_fv = sum(s["fonte_vide"] for s in temoin)
    l_fv = sum(s["fonte_vide"] for s in lot)
    lim = 0.25 * t_fv if t_fv > 8 else t_fv
    add("C3 fonte_vide lot <= 25 % temoin", l_fv <= lim, "lot %d temoin %d (limite %.1f)" % (l_fv, t_fv, lim))
    t_mz = sum(s["mine_zero"] for s in temoin)
    l_mz = sum(s["mine_zero"] for s in lot)
    add("C3 mine_zero lot <= temoin", l_mz <= t_mz, "lot %d temoin %d" % (l_mz, t_mz))
    t_pl = sum(s["plaques_moy"] or 0 for s in temoin)
    l_pl = sum(s["plaques_moy"] or 0 for s in lot)
    add("C4 plaques/min (somme des moyennes) lot >= 95 pct temoin", l_pl >= 0.95 * t_pl, "lot %.1f temoin %.1f" % (l_pl, t_pl))
    t_ia = (mean([s["inactifs_moy"] or 0 for s in temoin]) or 0)
    l_ia = (mean([s["inactifs_moy"] or 0 for s in lot]) or 0)
    add("C5 inactifs_mod_pct moyen lot <= temoin + 3", l_ia <= t_ia + 3, "lot %.1f temoin %.1f" % (l_ia, t_ia))
    t_m = sum(s["morts"] for s in temoin)
    l_m = sum(s["morts"] for s in lot)
    add("C5 equipes mortes lot <= temoin", l_m <= t_m, "lot %d temoin %d" % (l_m, t_m))
    add("C5 aucun ECHEC nouveau au BILAN ETAPE1",
        all((s["echec"] or 0) <= (t["echec"] or 0) for s, t in zip(lot, temoin)),
        "lot %s temoin %s" % ([s["echec"] for s in lot], [t["echec"] for t in temoin]))
    return res, all(ok for _, ok, _ in res)


def judge_coupure(lot):
    """C2 : fenetres m40 et m50 (apres la coupure de m30), par graine."""
    res = []
    for s in lot:
        d = s["data"]
        for m in (40, 50):
            label = "C2 %s m%d" % (os.path.basename(s["arch"].rstrip("/\\")), m)
            c = (d.get(m) or {}).get("chaine")
            if not c:
                res.append((label, False, "pas de ligne chaine"))
                continue
            porte = c.get("porte_ore_med", 0) + c.get("porte_plaques_med", 0)
            ok_p = porte <= 50 and c.get("porte_haut_max", 0) < 3
            mined, fondu = c.get("mine_ore", 0), c.get("fondu", 0)
            ok_f = mined <= 100 or fondu >= 0.8 * mined
            res.append((label, ok_p and ok_f, "porte_med %.1f haut_max %s mine_ore %s fondu %s"
                        % (porte, c.get("porte_haut_max"), mined, fondu)))
    return res, all(ok for _, ok, _ in res)


def main(argv):
    coupure = "--coupure" in argv
    argv = [a for a in argv if a != "--coupure"]
    if "--temoin" in argv and "--lot" in argv:
        tp = argv[argv.index("--temoin") + 1]
        lp = argv[argv.index("--lot") + 1]
        temoin = [summary(tp.format(seed=sd)) for sd in SEEDS]
        lot = [summary(lp.format(seed=sd)) for sd in SEEDS]
        print("TEMOIN")
        table(temoin)
        print("LOT")
        table(lot)
        res, ok = judge(temoin, lot)
        if coupure:
            r2, ok2 = judge_coupure(lot)
            res += r2
            ok = ok and ok2
        for name, o, d in res:
            print("%s : %s (%s)" % ("OK   " if o else "ECHEC", name, d))
        print("VERDICT : %s" % ("TOUS LES CRITERES MESURES TENUS" if ok else "CRITERES NON TENUS"))
        return 0 if ok else 1
    table([summary(a) for a in argv])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
