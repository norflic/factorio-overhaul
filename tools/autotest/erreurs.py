"""N104-ERREURS : tableau des erreurs de partie (équipe x catégorie) et score d'erreurs par équipe.

    py -3.9 -B tools/autotest/erreurs.py <archive|journal> [--ref <archive|journal>] [--rejeu] [--detail N] [--jusqua MIN]

<archive> : dossier d'un banc (benchmark.log.gz) ; <journal> : un fichier .log ou .log.gz, y compris un factorio-current.log brut
(partie réelle du DC). Lignes lues :
  - [FO-ERREUR-PARTIE] / [FO-ERREUR-BILAN] (écrites par le mod depuis ce lot, script/debug/erreurs_partie.lua) ;
  - sinon (journal d'avant ce lot) ou avec --rejeu : les FAITS sont reconstitués minute par minute depuis les lignes existantes
    ([FO-CAPI], [FO-VAPEUR], [FO-BILAN], [FO-RESERVE], [FO-BLOQUE], [FO-CAPI-ALERTE], [FO-CHAMP-ETAT], [FO-CUL-DETAIL],
    [FO-CUL-DE-SAC], [FO-IA1D], [FO-RECON], [FO-TOUR-POSE], [FO-DEFENSE]) et REJOUÉS par la même règle Lua
    (tools/autotest/erreurs_rejeu.lua -> shared/debug/erreurs_partie.lua) : un seul code de classification.
Sortie : pour chaque équipe et catégorie, épisodes, minutes cumulées, pire valeur ; score = minutes d'erreur cumulées ; avec --ref,
l'écart contre la référence (négatif = moins d'erreurs que la référence).
Limites du rejeu (faits absents des journaux d'avant) : bandes au cadre posé sans foreuse (aucune ligne par bande), positions des
foreuses figées et des fours à sec, tourelles par case de chunk (approchées par [FO-TOUR-POSE]) ; le besoin non couvert y lit la
baisse du manque (le mod lit la capacité de production).
"""
import argparse
import gzip
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

CATS = [
    "PLACEMENT:chevauchement", "PLACEMENT:cul_de_sac", "PLACEMENT:tapis_coupe", "PLACEMENT:foreuse_sans_sortie",
    "PLACEMENT:four_sans_combustible", "PLACEMENT:sans_courant", "PLACEMENT:bande_sans_foreuses",
    "INVESTISSEMENT:epargne_dort", "INVESTISSEMENT:capital_sans_revenu", "INVESTISSEMENT:projet_bloque",
    "FLUX:deficit_matiere", "FLUX:besoin_non_couvert", "FLUX:deficit_electrique", "FLUX:chaudieres_a_sec",
    "DEFENSE:attaque_repetee", "DEFENSE:perte_non_reconstruite", "DEFENSE:defense_manquante",
]
FAMILLES = ["PLACEMENT", "INVESTISSEMENT", "FLUX", "DEFENSE"]
TEAM_ORDER = ["player", "amber", "azure", "emerald", "scarlet"]


def open_log(path):
    if os.path.isdir(path):
        for name in ("benchmark.log.gz", "benchmark.log", "factorio-current.log"):
            p = os.path.join(path, name)
            if os.path.exists(p):
                path = p
                break
        else:
            sys.exit("aucun journal dans " + path)
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="replace")
    return open(path, "rt", encoding="utf-8", errors="replace")


# ---------------------------------------------------------------------------------------------------------------------------------
# Lignes du mod (depuis ce lot)
# ---------------------------------------------------------------------------------------------------------------------------------
RE_EP = re.compile(r"\[FO-ERREUR-PARTIE\] (\S+) (\S+) min=(\d+) (\S+) etat=(\w+)(.*)")
RE_BIL = re.compile(r"\[FO-ERREUR-BILAN\] (\S+) min=(\d+) actifs=(\d+) score=(\d+) \|(.*)")


def parse_live(lines, until=None):
    """Rend (stats, episodes) : stats[team][cat] = [n, dur, pire] (dernier bilan) ; episodes = lignes « ouvre » et « fin »."""
    stats, eps, last_min = {}, [], {}
    for line in lines:
        if "[FO-ERREUR-" not in line:
            continue
        m = RE_BIL.search(line)
        if m:
            team, mi = m.group(1), int(m.group(2))
            if until is not None and mi > until:
                continue
            d = {}
            for tok in m.group(5).split():
                k, _, v = tok.partition("=")
                n, dur, pire = (v.split("/") + ["0", "0", "0"])[:3]
                d[k] = [int(n), int(dur), int(pire)]
            stats[team] = d
            last_min[team] = mi
            continue
        m = RE_EP.search(line)
        if m:
            mi = int(m.group(3))
            if until is not None and mi > until:
                continue
            eps.append({"team": m.group(1), "cat": m.group(2), "min": mi, "pos": m.group(4), "etat": m.group(5),
                        "txt": m.group(6).strip()})
    return stats, eps, last_min


# ---------------------------------------------------------------------------------------------------------------------------------
# Reconstitution des faits depuis les journaux d'avant ce lot
# ---------------------------------------------------------------------------------------------------------------------------------
F = r"(-?[\d.]+)"
RX = {
    "capi": re.compile(r"\[FO-CAPI\] (\S+) minute (\d+) \| tick \d+ \| s=(\d+) d=(\d+) a=(\d+) Tmax=\S+ g=\S+ Y=" + F + r" K=" + F
                       + r" budget=" + F + "/" + F + r" \(epargne " + F),
    "vap": re.compile(r"\[FO-VAPEUR\] (\S+) : a " + F + r" min : demande nominale (\d+) kW .*?capacite (\d+) kW .*?chaudieres alimentees (\d+)/(\d+)"),
    "bilan": re.compile(r"\[FO-BILAN\] (\S+) partie (\d+) min \| sous \[([^\]]*)\]"),
    "reserve": re.compile(r"\[FO-RESERVE\] (\S+) minute (\d+) \| besoin (NON couvert|COUVERT)[^;|]*(?:; manque ([^|]*))?\|"),
    "bloque": re.compile(r"\[FO-BLOQUE\] (\S+) : projet (\d+) \(([^)]*)\) sans progres depuis (\d+) min : ([^;]*); (\d+) entite\(s\) baties sur (\d+), etat \S+ a " + F + r" min(.*)"),
    "alerte": re.compile(r"\[FO-CAPI-ALERTE\] (\S+) : capacite posee qui produit 0/min depuis (\d+) min : (.+?) \(.*\) a " + F + r" min"),
    "reprise": re.compile(r"\[FO-CAPI-ALERTE\] (\S+) : (.+?) produit de nouveau .* a " + F + r" min"),
    "champ": re.compile(r"\[FO-CHAMP-ETAT\] (\S+) min (\d+) \|.*?foreuses \d+ \(marche \d+, figees (\d+), sans courant (\d+)\) \| fours \d+ \(marche \d+, sans entree \d+, sans combustible (\d+)"),
    "culdet": re.compile(r"\[FO-CUL-DETAIL\] minute=(\d+) equipe=(\S+) classe=(\S+) pos=\(" + F + "," + F + r"\)"),
    "culsac": re.compile(r"\[FO-CUL-DE-SAC\] minute=(\d+) equipe=(\S+) culs_de_sac=\d+ .*?coupes_poteau=(\d+)(.*)"),
    "chev": re.compile(r"\[FO-IA1D\] (\S+) : projet (\d+) refuse \(champ: aucune entite a poser"),
    "detruit": re.compile(r"\[FO-RECON\] (\S+) : (\S+) detruit en \(" + F + ", " + F + r"\) a " + F + " min"),
    "refait": re.compile(r"\[FO-RECON\] (\S+) : \d+ piece\(s\) refaite\(s\) en \(" + F + ", " + F + r"\) a " + F + " min"),
    "tour": re.compile(r"\[FO-TOUR-POSE\] (\S+) avant-poste \S+ en \(" + F + ", " + F + r"\) : (\d+) tourelle"),
    "defense": re.compile(r"\[FO-DEFENSE\] (\S+) a " + F + r" min : .*? postes \[([^\]]*)\]"),
    "minute": re.compile(r"(?:\ba (\d+(?:\.\d+)?) min\b|\bminute[ =](\d+)\b|\bmin (\d+) \|)"),
}
RE_ITEM = re.compile(r"([^\s:]+):(-?[\d.]+)/min")
RE_POST = re.compile(r"(\w+) (\d+)/(\d+)")
RE_POS = re.compile(r" en \(" + F + ", " + F + r"\)")


def lua(v):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(v, 3)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, dict):
        return "{" + ",".join("[%s]=%s" % (lua(k), lua(x)) for k, x in sorted(v.items())) + "}"
    return "{" + ",".join(lua(x) for x in v) + "}"


def build_facts(lines, until=None):
    """Faits par (équipe, minute) : { team: { minute: facts } }, depuis les lignes d'avant ce lot."""
    cur = 0.0
    capi, vap, bil, res, champ, defn = {}, {}, {}, {}, {}, {}
    bloq = {}      # team -> pid -> list of (m0, m1, rec)
    alert = {}     # team -> label -> [start, end or None]
    culs = {}      # team -> minute -> list
    chev = {}      # team -> minute -> list
    lost = {}      # team -> list of dict (x, y, m, done)
    tours = {}     # team -> list of (x, y, m)
    teams = set()

    def tm(team, m):
        teams.add(team)
        return int(m)

    for line in lines:
        if "[FO-" not in line:
            continue
        mm = RX["minute"].search(line)
        if mm:
            v = float(next(g for g in mm.groups() if g))
            if v > cur and v < cur + 30:
                cur = v
        if until is not None and cur > until + 1:
            break
        m = RX["capi"].search(line)
        if m:
            t, mi = m.group(1), tm(m.group(1), m.group(2))
            capi.setdefault(t, {})[mi] = {"s": float(m.group(3)), "delta": float(m.group(4)), "alpha": float(m.group(5)),
                                          "Y": float(m.group(6)), "spent": float(m.group(8)), "budget": float(m.group(9)),
                                          "bank": float(m.group(10))}
            continue
        m = RX["vap"].search(line)
        if m:
            t, mi = m.group(1), tm(m.group(1), float(m.group(2)) + 0.5)
            vap.setdefault(t, {})[mi] = {"demand": float(m.group(3)), "cap": float(m.group(4)), "fed": int(m.group(5)),
                                         "boilers": int(m.group(6))}
            continue
        m = RX["bilan"].search(line)
        if m:
            t, mi = m.group(1), tm(m.group(1), m.group(2))
            bil.setdefault(t, {})[mi] = [[it, float(v), 0.0] for it, v in RE_ITEM.findall(m.group(3))]
            continue
        m = RX["reserve"].search(line)
        if m:
            t, mi = m.group(1), tm(m.group(1), m.group(2))
            items = []
            if m.group(3).startswith("NON") and m.group(4):
                for part in m.group(4).split(","):
                    p = part.strip().rsplit(" ", 1)
                    if len(p) == 2:
                        try:
                            n = float(p[1])
                        except ValueError:
                            continue
                        items.append([p[0], n, -n])  # rejeu : la capacité « monte » quand le manque baisse
            res.setdefault(t, {})[mi] = items
            continue
        m = RX["bloque"].search(line)
        if m:
            t = m.group(1)
            mi = tm(t, float(m.group(8)) + 0.5)
            age = int(m.group(4))
            pos = RE_POS.search(m.group(9))
            rec = {"pid": int(m.group(2)), "kind": m.group(3), "built": int(m.group(6)), "total": int(m.group(7)),
                   "cause": m.group(5).strip().replace(" ", "_"), "x": float(pos.group(1)) if pos else None,
                   "y": float(pos.group(2)) if pos else None}
            bloq.setdefault(t, {}).setdefault(rec["pid"], []).append((mi - age, mi, rec))
            continue
        m = RX["alerte"].search(line)
        if m:
            t = m.group(1)
            mi = tm(t, float(m.group(4)) + 0.5)
            a = alert.setdefault(t, {}).setdefault(m.group(3), [mi - int(m.group(2)), None])
            a[1] = None
            continue
        m = RX["reprise"].search(line)
        if m:
            t = m.group(1)
            a = alert.get(t, {}).get(m.group(2))
            if a:
                a[1] = int(float(m.group(3)) + 0.5)
            continue
        m = RX["champ"].search(line)
        if m:
            t, mi = m.group(1), tm(m.group(1), m.group(2))
            champ.setdefault(t, {})[mi] = {"stuck": int(m.group(3)), "nopow": int(m.group(4)), "nofuel": int(m.group(5))}
            continue
        m = RX["culdet"].search(line)
        if m:
            t, mi = m.group(2), tm(m.group(2), m.group(1))
            cl = m.group(3)
            if cl in ("impasse", "souterrain_ampute"):
                culs.setdefault(t, {}).setdefault(mi, []).append({"classe": cl, "x": float(m.group(4)), "y": float(m.group(5)), "n": 6})
            else:
                culs.setdefault(t, {}).setdefault(mi, [])
            continue
        m = RX["culsac"].search(line)
        if m:
            t, mi = m.group(2), tm(m.group(2), m.group(1))
            lst = culs.setdefault(t, {}).setdefault(mi, [])
            for x, y in re.findall(r"\(" + F + "," + F + r"\)", m.group(4)):
                lst.append({"classe": "coupe", "x": float(x), "y": float(y), "n": 6})
            continue
        m = RX["chev"].search(line)
        if m:
            t = m.group(1)
            chev.setdefault(t, {}).setdefault(tm(t, cur + 0.5), []).append({"pid": int(m.group(2)), "dropped": 1, "total": 1})
            continue
        m = RX["detruit"].search(line)
        if m:
            t = m.group(1)
            tm(t, 0)
            lost.setdefault(t, []).append({"x": float(m.group(3)), "y": float(m.group(4)), "m": float(m.group(5)), "done": None})
            continue
        m = RX["refait"].search(line)
        if m:
            t, x, y, mi = m.group(1), float(m.group(2)), float(m.group(3)), float(m.group(4))
            for r in lost.get(t, []):
                if r["done"] is None and abs(r["x"] - x) < 1 and abs(r["y"] - y) < 1:
                    r["done"] = mi
                    break
            continue
        m = RX["tour"].search(line)
        if m:
            tours.setdefault(m.group(1), []).append((float(m.group(2)), float(m.group(3)), cur))
            continue
        m = RX["defense"].search(line)
        if m:
            t, mi = m.group(1), tm(m.group(1), float(m.group(2)) + 0.5)
            defn.setdefault(t, {})[mi] = [{"post": p, "have": int(h), "want": int(w)} for p, h, w in RE_POST.findall(m.group(3))]
            continue

    last = int(cur + 0.5) if until is None else min(int(cur + 0.5), until)
    out = {}
    for t in sorted(teams):
        def latest(d, mi, span):
            best = None
            for k in d.get(t, {}):
                if k <= mi and mi - k < span and (best is None or k > best):
                    best = k
            return d[t][best] if best is not None else None
        rows = {}
        firsts = [min(d[t]) for d in (capi, vap, champ) if d.get(t)]
        m0 = min(firsts) if firsts else 1
        cul_keys = sorted(culs.get(t, {}))
        for mi in range(max(1, m0), last + 1):
            f = {}
            ca = latest(capi, mi, 2)
            if ca:
                f["capi"] = ca
            v = latest(vap, mi, 2)
            if v:
                f["elec"] = v
            b = latest(bil, mi, 5)
            if b:
                f["sous"] = b
            r = latest(res, mi, 2)
            if r:
                f["besoins"] = r
            c = latest(champ, mi, 6)
            if c:
                f["champ"] = c
            k = [x for x in cul_keys if x <= mi]
            if k:
                f["culs"] = culs[t][k[-1]]
            if mi in chev.get(t, {}):
                f["chevauchements"] = chev[t][mi]
            d = latest(defn, mi, 3)
            if d:
                f["defense"] = d
            bl = []
            for pid, ivs in sorted(bloq.get(t, {}).items()):
                for a0, a1, rec in ivs:
                    if a0 <= mi <= a1:
                        r2 = dict(rec)
                        r2["age"] = mi - a0
                        bl.append(r2)
                        break
            if bl:
                f["bloques"] = bl
            z = []
            for label, (a0, a1) in sorted(alert.get(t, {}).items()):
                if a0 <= mi and (a1 is None or mi < a1):
                    z.append([label, mi - a0])
            if z:
                f["zero"] = z
            # pertes et vagues par case de chunk
            by, waves = {}, {}
            for r in lost.get(t, []):
                if r["m"] > mi:
                    continue
                ck = "%d:%d" % (int(r["x"] // 32), int(r["y"] // 32))
                if r["done"] is None or r["done"] > mi:
                    g = by.setdefault(ck, {"ck": ck, "x": r["x"], "y": r["y"], "n": 0, "age": 0})
                    g["n"] += 1
                    if mi - r["m"] > g["age"]:
                        g["age"], g["x"], g["y"] = mi - r["m"], r["x"], r["y"]
                if mi - r["m"] <= 30:
                    waves.setdefault(ck, []).append(r)
            if by:
                f["pertes"] = [by[k] for k in sorted(by)]
            att = []
            for ck, rs in sorted(waves.items()):
                ms = sorted(x["m"] for x in rs)
                nv = 1 + sum(1 for a, b2 in zip(ms, ms[1:]) if b2 - a > 1)
                cx, cy = (int(v) for v in ck.split(":"))
                t1 = sum(1 for (x, y, mt) in tours.get(t, []) if ms[0] <= mt <= mi and abs(x - (cx * 32 + 16)) <= 32 and abs(y - (cy * 32 + 16)) <= 32)
                att.append({"ck": ck, "x": rs[0]["x"], "y": rs[0]["y"], "vagues": nv, "perdus": len(rs), "pv": len(rs), "t0": 0, "t1": t1, "par": "?"})
            if att:
                f["attaques"] = att
            rows[mi] = f
        out[t] = rows
    return out


def find_lua():
    for c in ("lua5.2", "lua5.2.exe", r"C:\Users\evan2\bin\lua5.2.exe"):
        p = shutil.which(c) or (c if os.path.exists(c) else None)
        if p:
            return p
    sys.exit("lua5.2 introuvable")


def replay(facts):
    fd, path = tempfile.mkstemp(suffix=".lua", prefix="fo-erreurs-")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write("return {\n")
        for t in sorted(facts):
            for mi in sorted(facts[t]):
                fh.write("{team=%s,minute=%d,facts=%s},\n" % (lua(t), mi, lua(facts[t][mi])))
        fh.write("}\n")
    try:
        r = subprocess.run([find_lua(), os.path.join("tools", "autotest", "erreurs_rejeu.lua"), path], cwd=ROOT,
                           capture_output=True, text=True, encoding="utf-8")
        if r.returncode != 0:
            sys.exit("rejeu en erreur : " + r.stderr[-2000:])
        return r.stdout.splitlines()
    finally:
        os.remove(path)


def load(path, force_replay=False, until=None):
    with open_log(path) as fh:
        lines = fh.readlines()
    live = any("[FO-ERREUR-BILAN]" in l for l in lines)
    if live and not force_replay:
        return parse_live(lines, until) + ("mod",)
    return parse_live(replay(build_facts(lines, until)), until) + ("rejeu",)


def score(d):
    return sum(v[1] for v in d.values())


def order(teams):
    return sorted(teams, key=lambda t: (TEAM_ORDER.index(t) if t in TEAM_ORDER else 99, t))


def table(stats, ref=None, label="", last=None):
    print("## %s" % label)
    teams = order(set(stats) | set(ref or {}))
    print("| equipe | " + " | ".join(FAMILLES) + " | score" + (" | ref | ecart" if ref is not None else "") + " |")
    print("|" + "---|" * (len(FAMILLES) + 2 + (2 if ref is not None else 0)))
    for t in teams:
        d = stats.get(t, {})
        cells = []
        for fam in FAMILLES:
            n = sum(v[0] for k, v in d.items() if k.startswith(fam))
            dur = sum(v[1] for k, v in d.items() if k.startswith(fam))
            cells.append("%d / %d min" % (n, dur))
        row = "| %s%s | %s | %d" % (t, (" (%d min)" % last[t]) if last and t in last else "", " | ".join(cells), score(d))
        if ref is not None:
            rs = score(ref.get(t, {}))
            row += " | %d | %+d" % (rs, score(d) - rs)
        print(row + " |")
    print()
    print("| equipe | categorie | episodes | minutes | pire" + (" | ref (ep/min) | ecart min" if ref is not None else "") + " |")
    print("|---|---|---|---|---|" + ("---|---|" if ref is not None else ""))
    for t in teams:
        d, rd = stats.get(t, {}), (ref or {}).get(t, {})
        for c in CATS:
            v, rv = d.get(c), rd.get(c)
            if not v and not rv:
                continue
            v = v or [0, 0, 0]
            row = "| %s | %s | %d | %d | %d" % (t, c, v[0], v[1], v[2])
            if ref is not None:
                rv = rv or [0, 0, 0]
                row += " | %d/%d | %+d" % (rv[0], rv[1], v[1] - rv[1])
            print(row + " |")
    print()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source")
    ap.add_argument("--ref")
    ap.add_argument("--rejeu", action="store_true", help="reconstituer les faits même si le journal porte les lignes du mod")
    ap.add_argument("--detail", type=int, default=0, help="N premiers épisodes ouverts par équipe (position, détail)")
    ap.add_argument("--jusqua", type=int, default=None, help="minute de fin (comparer des parties de durées différentes)")
    a = ap.parse_args()
    stats, eps, last, mode = load(a.source, a.rejeu, a.jusqua)
    ref = None
    if a.ref:
        ref, _, rlast, rmode = load(a.ref, a.rejeu, a.jusqua)
    table(stats, ref, "%s (%s)%s" % (a.source, mode, (" contre " + a.ref + " (" + rmode + ")") if a.ref else ""), last)
    if a.detail:
        for t in order({e["team"] for e in eps}):
            print("### %s : premiers episodes" % t)
            n = 0
            for e in eps:
                if e["team"] == t and e["etat"] == "ouvre":
                    print("- min %d %s %s %s" % (e["min"], e["cat"], e["pos"], e["txt"]))
                    n += 1
                    if n >= a.detail:
                        break
            print()


if __name__ == "__main__":
    main()
