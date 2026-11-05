# -*- coding: utf-8 -*-
"""Lot DEPENSES2, essai 2 : preuve lot contre témoin (critères C1 à C6 de fo-logs/2026-11-04_DEPENSES2/CRITERES.md).

Usage : py -3.9 -B tools/autotest/depenses2_preuve.py <dossier essai2>   (paires lot-<nom> / temoin-<nom>)
"""
import gzip
import importlib.util
import os
import re
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("dd", os.path.join(HERE, "depenses_diag.py"))
dd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dd)

# Essai 2 : « laboratoires base X cible Y, soldats cible Z » ; essai 3 : « laboratoires base X cible Y | soldats ... ».
RX_DEP = re.compile(r"\[FO-DEPENSES\] (\S+) minute (\d+) \|.*laboratoires base (\S+) cible ([^,\s]+)(?:, soldats cible (\S+)| \| (.*))")
RX_HOLD = re.compile(r"\[FO-DEPENSES\] (\S+) minute \d+ \| CENTRE EN ATTENTE")
RX_RSV = re.compile(r"\[FO-RESERVE\] (\S+) minute (\d+) \| besoin NON couvert")
RX_CC = re.compile(r"\[FO-CAPITAL\] (\S+) : centre monte au niveau (\d+) .* a ([0-9.]+) min")
RX_BILAN = re.compile(r"\[FO-DEPENSES-DIAG(?:-DC)?\] BILAN : (\d+) OK, (\d+) ECHEC")
RX_ERR = re.compile(r"stack traceback|Error while running|script error", re.I)


def scan(path):
    p = os.path.join(path, "benchmark.log.gz")
    out = {"dep": [], "noncouv": {}, "cc": {}, "bilan": None, "err": 0, "hold": {}}
    with gzip.open(p, "rt", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if RX_ERR.search(line):
                out["err"] += 1
            if "[FO-" not in line:
                continue
            m = RX_HOLD.search(line)
            if m:
                out["hold"][m.group(1)] = out["hold"].get(m.group(1), 0) + 1
            m = RX_DEP.search(line)
            if m:
                out["dep"].append((m.group(1), int(m.group(2)), m.group(3), m.group(4), m.group(5) or m.group(6)))
                continue
            m = RX_RSV.search(line)
            if m:
                out["noncouv"][m.group(1)] = out["noncouv"].get(m.group(1), 0) + 1
                continue
            m = RX_CC.search(line)
            if m:
                out["cc"].setdefault(m.group(1), []).append((int(m.group(2)), float(m.group(3))))
                continue
            m = RX_BILAN.search(line)
            if m:
                out["bilan"] = (int(m.group(1)), int(m.group(2)))
    D = dd.parse(path)[0]
    return D, out


def last_min(D, eq, kind):
    ms = [k[1] for k in D if k[0] == eq and k[2] == kind]
    return max(ms) if ms else None


def val(D, eq, kind, key, t=None):
    t = t if t is not None else last_min(D, eq, kind)
    rec = D.get((eq, t, kind)) if t is not None else None
    return dd.g(rec, key) if rec else None


def dist(xs):
    xs = [x for x in xs if x is not None]
    if not xs:
        return "-"
    return "n=%d min %.0f med %.1f max %.0f [%s]" % (len(xs), min(xs), statistics.median(xs), max(xs), " ".join("%.0f" % x for x in xs))


def main(root, troot=None):
    troot = troot or root
    names = sorted(n[4:] for n in os.listdir(root) if n.startswith("lot-") and os.path.isdir(os.path.join(root, n)))
    holds = []
    c1d, c1s = [], [0, 0]
    labs_l, labs_t, c2_bad, c2_over, c2_after = [], [], [], [], []
    sold_l, sold_t, c3_cap = [], [], []
    nc = [0, 0]
    c4 = []
    c5 = []
    errs = []
    dor_l, dor_t, red_l, red_t = [], [], [], []
    rows = []
    for n in names:
        lp, tp = os.path.join(root, "lot-" + n), os.path.join(troot, "temoin-" + n)
        if not (os.path.exists(os.path.join(lp, "benchmark.log.gz")) and os.path.exists(os.path.join(tp, "benchmark.log.gz"))):
            print("(paire incomplete : %s)" % n)
            continue
        DL, OL = scan(lp)
        DT, OT = scan(tp)
        errs.append((n, OL["err"], OT["err"]))
        holds.append((n, sorted(OL["hold"].items())))
        if n.startswith("guide"):
            c5.append((n, OL["bilan"], OT["bilan"]))
        eqs = sorted(set(k[0] for k in DL) | set(k[0] for k in DT))
        for eq in eqs:
            fl, ft = val(DL, eq, "L", "faites"), val(DT, eq, "L", "faites")
            if fl is not None and ft is not None:
                c1d.append(fl - ft)
                c1s[0] += fl
                c1s[1] += ft
            labs_l.append(val(DL, eq, "L", "labos"))
            labs_t.append(val(DT, eq, "L", "labos"))
            # C2 : chaque relevé du lot
            targets = [(m, tg) for (k, m, base, tg, sold) in OL["dep"] if k in (eq, "votre equipe" if eq == "player" else eq)]
            prev_t, prev_labs = None, None
            for t in sorted(k[1] for k in DL if k[0] == eq and k[2] == "L"):
                labs = dd.g(DL[(eq, t, "L")], "labos")
                if labs > 13:
                    c2_over.append((n, eq, t, labs))
                cur = [tg for (m, tg) in targets if m <= t]
                tg = cur[-1] if cur else "-"
                if tg not in ("-", "nil"):
                    try:
                        tgv = int(float(tg))
                        if labs > tgv:
                            c2_bad.append((n, eq, t, labs, tgv))
                        if prev_t == tgv and prev_labs is not None and prev_labs >= tgv and labs > prev_labs:
                            c2_after.append((n, eq, t, prev_labs, labs))
                        prev_t = tgv
                    except ValueError:
                        pass
                prev_labs = labs
            if eq != "player":
                sl, st_ = val(DL, eq, "A", "soldats"), val(DT, eq, "A", "soldats")
                sold_l.append(sl)
                sold_t.append(st_)
                for t in sorted(k[1] for k in DL if k[0] == eq and k[2] == "A"):
                    if dd.g(DL[(eq, t, "A")], "soldats") > 30:
                        c3_cap.append((n, eq, t))
                al, at = val(DL, eq, "A", "age"), val(DT, eq, "A", "age")
                ccl = [m for (lv, m) in OL["cc"].get(eq, [])]
                cct = [m for (lv, m) in OT["cc"].get(eq, [])]
                c4.append((n, eq, al, at, ccl, cct))
            key = "votre equipe" if eq == "player" else eq
            nc[0] += OL["noncouv"].get(eq, 0) + (OL["noncouv"].get(key, 0) if key != eq else 0)
            nc[1] += OT["noncouv"].get(eq, 0) + (OT["noncouv"].get(key, 0) if key != eq else 0)
            tl, tt = last_min(DL, eq, "C"), last_min(DT, eq, "C")
            dl = dd.dormant_fam(DL, eq, tl, "plaques") if tl else None
            dt = dd.dormant_fam(DT, eq, tt, "plaques") if tt else None
            dor_l.append(dl)
            dor_t.append(dt)
            rl = dd.dormant_items(DL, eq, tl).get("automation-science-pack") if tl else None
            rt = dd.dormant_items(DT, eq, tt).get("automation-science-pack") if tt else None
            red_l.append(rl)
            red_t.append(rt)
            rows.append((n, eq, ft, fl, val(DT, eq, "L", "labos"), val(DL, eq, "L", "labos"), val(DT, eq, "A", "soldats"),
                         val(DL, eq, "A", "soldats"), val(DT, eq, "A", "age"), val(DL, eq, "A", "age"), dt, dl))
    print("partie            equipe   | techs T->L | labos T->L | soldats T->L | age T->L | plaques qui dorment T->L")
    for r in rows:
        f = lambda x: "-" if x is None else "%d" % x
        print("%-17s %-8s | %3s -> %3s | %2s -> %2s | %2s -> %2s | %s -> %s | %6s -> %6s" % (r[0], r[1], f(r[2]), f(r[3]), f(r[4]), f(r[5]),
              f(r[6]), f(r[7]), f(r[8]), f(r[9]), f(r[10]), f(r[11])))
    print()
    med = statistics.median(c1d) if c1d else None
    print("C1 recherche : differences lot - temoin %s ; somme lot %d, temoin %d -> %s" % (
        dist(c1d), c1s[0], c1s[1], "TENU" if (med is not None and med >= 0 and c1s[0] >= c1s[1]) else "NON TENU"))
    print("C2 laboratoires : lot %s ; temoin %s ; releves > 13 : %d ; releves > cible : %d %s ; poses apres cible atteinte : %d %s -> %s" % (
        dist(labs_l), dist(labs_t), len(c2_over), len(c2_bad), c2_bad[:4], len(c2_after), c2_after[:4],
        "TENU" if not c2_over and not c2_bad and not c2_after else "NON TENU"))
    print("C3 armee : soldats a 59 min lot %s ; temoin %s ; releves > 30 : %d ; minutes besoin NON couvert lot %d, temoin %d (borne %.0f) -> %s" % (
        dist(sold_l), dist(sold_t), len(c3_cap), nc[0], nc[1], 1.2 * nc[1] + 5,
        "TENU" if not c3_cap and nc[0] <= 1.2 * nc[1] + 5 else "NON TENU"))
    bad4 = [x for x in c4 if x[2] is not None and x[3] is not None and x[2] < x[3]]
    print("C4 ages : %s -> %s" % ("; ".join("%s %s age %s/%s centre %s/%s" % (x[0][-9:], x[1], x[2], x[3], x[4], x[5]) for x in c4),
                                  "TENU" if not bad4 else "NON TENU (%s)" % bad4))
    bad5 = [x for x in c5 if not (x[1] and x[2]) or x[1][0] < x[2][0]]
    print("C5 verif-guide : %s -> %s" % (c5, "TENU" if not bad5 else "NON TENU"))
    print("C6 erreurs Lua (lot, temoin) : %s -> %s" % (errs, "TENU" if all(e[1] == 0 for e in errs) else "NON TENU"))
    print("Indicatif : plaques qui dorment a 59 min lot %s ; temoin %s" % (dist(dor_l), dist(dor_t)))
    print("Indicatif : packs rouges qui dorment lot %s ; temoin %s" % (dist(red_l), dist(red_t)))
    print("Indicatif : minutes « CENTRE EN ATTENTE » du lot (rien pour la recherche ni l'armee) : %s" % holds)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None))
