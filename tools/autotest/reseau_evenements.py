#!/usr/bin/env python3
"""Lot RESEAU-VIVANT : lecture des événements provoqués (scénario reseau-vivant, lignes [FO-RESEAU-BANC]) et des journaux
[FO-RESEAU] / [FO-POSE] du mod, archives de banc.py (benchmark.log ou benchmark.log.gz).

Critères (fo-logs/2026-10-29_NUIT/RESEAU/CRITERES.md, écrits AVANT la mesure) :
  C2 genre « sur »    : le courant revient (kw > 0 ET consommateurs sur le réseau >= RATIO du posé) en N minutes au plus ;
  C3 genre « danger » : aucune pièce de centrale posée avec un ennemi à 28 tuiles ([FO-POSE] ... OUI) ; une centrale de
                        remplacement finie à plus de 28 tuiles du site écarté ; le courant revient en N3 minutes ;
  C4 genre « pivot »  : les consommateurs sur le réseau d'une centrale reviennent à RATIO du posé en N4 minutes, avec au plus
                        POLES_MAX poteaux rouverts au plus (somme des « N rouvert(s) » des décisions [FO-RESEAU] « reseau: » après l'événement).
Usage : py -3.9 -B tools/autotest/reseau_evenements.py <archive> [<archive> ...] [--n2 10] [--n3 15] [--n4 6] [--ratio 0.9]
"""
import argparse
import glob
import gzip
import os
import re
import sys

REL = re.compile(r"\[FO-RESEAU-BANC\] releve t=(\d+) \| (\w+) \| genre=(\S+) kw=(-?[\d.]+) chaudieres=(\d+) machines=(\d+) "
                 r"conso_pose=(\d+) conso_reseau=(\d+) bras_pose=(\d+) bras_reseau=(\d+) ennemi28=(\d) fantomes40=(\d+) site=(\S+)")
EVT = re.compile(r"\[FO-RESEAU-BANC\] evenement t=(\d+) \| (\w+) \| genre=(\S+)(.*)$")
POSE = re.compile(r"\[FO-POSE\] (\w+) : projet (\d+), (\S+) en \(([-\d.]+), ([-\d.]+)\), ennemi a 28 tuiles : (OUI|non), a ([\d.]+) min")
POLE = re.compile(r"\[FO-POLE\] (\w+) : projet (\d+) .* pose en \(")
RESEAU = re.compile(r"\[FO-RESEAU\] (\w+) : (.*) a ([\d.]+) min")


def lines(arch):
    for name in ("benchmark.log", "benchmark.log.gz"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            op = gzip.open if p.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as f:
                for line in f:
                    yield line
            return


def analyse(arch, n2, n3, n4, ratio, poles_max):
    rel, evt, pose, reseau, poles = {}, {}, [], [], []
    for line in lines(arch):
        m = REL.search(line)
        if m:
            t, key = int(m.group(1)), m.group(2)
            rel.setdefault(key, []).append(dict(t=t, genre=m.group(3), kw=float(m.group(4)), chd=int(m.group(5)), mach=int(m.group(6)),
                                                pose=int(m.group(7)), net=int(m.group(8)), bpose=int(m.group(9)), bnet=int(m.group(10)),
                                                enemy=int(m.group(11)), site=m.group(13)))
            continue
        m = EVT.search(line)
        if m:
            evt[m.group(2)] = dict(t=int(m.group(1)), genre=m.group(3), rest=m.group(4))
            continue
        m = POSE.search(line)
        if m:
            pose.append(dict(key=m.group(1), name=m.group(3), x=float(m.group(4)), y=float(m.group(5)), enemy=m.group(6) == "OUI",
                             minute=float(m.group(7))))
            continue
        m = RESEAU.search(line)
        if m:
            reseau.append((m.group(1), m.group(2), float(m.group(3))))
            continue
        m = re.search(r"\[FO-POLE\] (\w+) : .* pose en \(([-\d.]+), ([-\d.]+)\) a ([\d.]+) min", line)
        if m:
            poles.append((m.group(1), float(m.group(4))))
    out = []
    for key in sorted(evt):
        e = evt[key]
        g = e["genre"]
        if g in ("temoin",):
            continue
        rows = [r for r in rel.get(key, []) if r["t"] >= e["t"]]
        res = dict(equipe=key, genre=g, t_evt=e["t"], verdict="", detail="")
        if not rows:
            res["verdict"], res["detail"] = "SANS_RELEVE", "aucun releve apres l'evenement"
            out.append(res)
            continue
        base_pose = max(1, rows[0]["pose"])
        rec = None
        for r in rows:
            if g in ("sur", "danger"):
                if r["kw"] > 0 and r["net"] >= ratio * base_pose:
                    rec = r
                    break
            elif g == "pivot":
                if r["net"] >= ratio * base_pose and r["t"] > e["t"]:
                    rec = r
                    break
        minutes = (rec["t"] - e["t"]) / 3600.0 if rec else None
        res["minutes"] = minutes
        lim = {"sur": n2, "danger": n3, "pivot": n4}.get(g, n2)
        ok = minutes is not None and minutes <= lim
        d = [f"retour {'%.1f min' % minutes if minutes is not None else 'JAMAIS'} (limite {lim})",
             f"fin: kw={rows[-1]['kw']:.0f} chaudieres={rows[-1]['chd']} machines={rows[-1]['mach']} conso {rows[-1]['net']}/{rows[-1]['pose']}"]
        if g == "danger":
            under = [p for p in pose if p["key"] == key and p["minute"] * 3600 >= e["t"] and p["enemy"]]
            d.append(f"poses sous le feu: {len(under)}")
            ok = ok and not under
            m = re.search(r"site=([-\d.]+),([-\d.]+)", e["rest"])
            last = rows[-1]["site"]
            if m and last != "-":
                sx, sy = [float(v) for v in last.split(",")]
                dist = ((sx - float(m.group(1))) ** 2 + (sy - float(m.group(2))) ** 2) ** 0.5
                d.append(f"site final a {dist:.0f} tuiles du site d'origine")
                moved = dist > 28
                d.append("centrale AILLEURS" if moved else "centrale sur place")
        if g == "pivot":
            n_reopen = 0
            for k, txt, mn in reseau:
                if k == key and mn * 3600 >= e["t"] - 1 and txt.startswith("reseau:"):
                    mm = re.search(r"(\d+) rouvert", txt)
                    if mm:
                        n_reopen += int(mm.group(1))
            d.append(f"poteaux rouverts par la decision (journal [FO-RESEAU]) : {n_reopen} (limite {poles_max})")
            ok = ok and n_reopen <= poles_max
        res["verdict"] = "OK" if ok else "ECHEC"
        res["detail"] = " ; ".join(d)
        res["decisions"] = [x for x in reseau if x[0] == key and x[2] * 3600 >= e["t"] - 1]
        out.append(res)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("archives", nargs="+")
    ap.add_argument("--n2", type=float, default=12)
    ap.add_argument("--n3", type=float, default=20)
    ap.add_argument("--n4", type=float, default=6)
    ap.add_argument("--ratio", type=float, default=0.9)
    ap.add_argument("--poles-max", type=int, default=3)
    a = ap.parse_args()
    bad = 0
    total = 0
    for arch in a.archives:
        print(f"== {arch}")
        for r in analyse(arch, a.n2, a.n3, a.n4, a.ratio, a.poles_max):
            total += 1
            if r["verdict"] != "OK":
                bad += 1
            print(f"  {r['verdict']:8} {r['equipe']:8} {r['genre']:7} t={r['t_evt']} : {r['detail']}")
            for k, txt, mn in r.get("decisions", [])[:6]:
                print(f"           [{mn:.1f} min] {txt}")
    print(f"BILAN : {total - bad} OK sur {total} evenement(s), {bad} ECHEC(S)")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
