# Lot CHAMP : devenir de CHAQUE bande du champ demandée (demande du lead, 2/11 : « cause chiffrée des bandes qui ne produisent pas »).
# Lit les lignes [FO-MIGRATION] (demande, attente, retrait, production, annulation, chantier lent, abandon) et [FO-CHAMP-ETAT] (état des
# bandes, ce qui leur manque, bandes finies aux foreuses figées, fours sans entrée, bras sans courant) d'une ou plusieurs archives de banc.
# Usage :
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/champ_bandes.py <archive> [<archive> ...]
# Par archive : une ligne par demande (équipe, minute, cible, bande, projet, foreuses, fours, issue), puis le compte des issues. Une même
# bande redemandée après une annulation compte pour une demande de plus (c'est ce que compte champ_mesures.py « bandes demandees »).
import gzip
import os
import re
import sys

CLOCK = [re.compile(r"\| tick (\d+) \|"), re.compile(r"\[FO-CHAMP-ETAT\] \w+ min (\d+)"), re.compile(r"\[FO-CHAMP-MESURE\] minute ([\d.]+)")]
MIG = re.compile(r"\[FO-MIGRATION\] (\w+) : (.*)$")
REQ = re.compile(r"(?:avant-poste|gisement) (\d+) \((\w+)\) : bande (-?\d+) du champ demandee, projet (\d+) : (\d+) foreuse\(s\) electrique\(s\), (\d+) four\(s\), (\d+) paire")
ETAT = re.compile(r"\[FO-CHAMP-ETAT\] (\w+) min (\d+) \| bandes \d+ \(([^)]*)\)(?: ; manque ([^|]*))? ?\|(.*)$")
CANCEL = re.compile(r"\[FO-IA1D\] (\w+) : projet (\d+) annule \(([^)]*)\)")
BAD = re.compile(r"p(\d+) bande (-?\d+) : figees (\d+), fours sans entree (\d+), bras sans courant (\d+), pieces manquantes \[([^\]]*)\]")


def read(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            op = gzip.open if name.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


def analyse(lines):
    minute = 0.0
    reqs = []            # demandes dans l'ordre
    by_pid = {}          # (équipe, projet) -> demande
    cur = {}             # (équipe, cible) -> demande ouverte
    last_etat = {}       # équipe -> (minute, manque, détails des bandes finies en défaut)
    for ln in lines:
        for rx in CLOCK:
            m = rx.search(ln)
            if m:
                v = float(m.group(1))
                minute = v / 3600.0 if rx is CLOCK[0] else v
                break
        me = ETAT.search(ln)
        if me:
            bad = {int(b[0]): b for b in BAD.findall(me.group(5))}
            last_etat[me.group(1)] = (int(me.group(2)), (me.group(4) or "").strip(), bad, me.group(3))
            continue
        mc = CANCEL.search(ln)
        if mc and (mc.group(1), int(mc.group(2))) in by_pid:
            q = by_pid[(mc.group(1), int(mc.group(2)))]
            if not q["end"]:
                q["end"] = ("annulee : " + mc.group(3).replace("migration: ", ""), minute)
            continue
        mm = MIG.search(ln)
        if not mm:
            continue
        team, text = mm.group(1), mm.group(2)
        r = REQ.search(text)
        if r:
            q = {"team": team, "min": minute, "target": int(r.group(1)), "kind": r.group(2), "band": r.group(3), "pid": int(r.group(4)),
                 "drills": int(r.group(5)), "furn": int(r.group(6)), "pairs": int(r.group(7)), "events": [], "end": None,
                 "capi": "voulue par la capitalisation" in text}
            reqs.append(q)
            by_pid[(team, q["pid"])] = q
            cur[(team, q["target"])] = q
            continue
        mp = re.search(r"projet (\d+)", text)
        mt = re.match(r"(?:avant-poste|gisement) (\d+)", text)
        q = None
        if mp and (team, int(mp.group(1))) in by_pid:
            q = by_pid[(team, int(mp.group(1)))]
        elif mt and (team, int(mt.group(1))) in cur:
            q = cur[(team, int(mt.group(1)))]
        if not q or q["end"]:
            continue
        if "la ligne neuve du projet" in text and "produit" in text:
            q["end"] = ("produit", minute)
        elif "laissee au plan, bande suivante" in text:
            q["end"] = ("bloquee, laissee au plan", minute)
        elif "partie annulee" in text:
            why = re.search(r"partie annulee \(([^)]*)\)", text)
            q["end"] = ("annulee : " + (why.group(1) if why else "?"), minute)
        elif "n'aboutit pas" in text or "est perdue" in text or "migration abandonnee" in text or "migration arretee" in text:
            q["end"] = ("arretee : " + text[:90], minute)
        else:
            q["events"].append((minute, text))
    return reqs, last_etat, minute


def end_state(q, last_etat):
    """Issue d'une demande sans production ni annulation à la fin du banc : sa dernière étape connue, et les défauts relevés."""
    ev = [t for _, t in q["events"]]
    retired = any("partie retiree" in t or "rien n'est retire" in t for t in ev)
    wait = [t for t in ev if "en attente" in t]
    lent = any("chantier lent" in t for t in ev)
    fini = any("ligne finie" in t for t in ev)
    le = last_etat.get(q["team"])
    bad = le[2].get(q["pid"]) if le else None
    if fini or bad:
        s = "bande finie, pas encore 10 plaques"
        if bad:
            s += " (figees %s, fours sans entree %s, bras sans courant %s, pieces manquantes [%s])" % (bad[2], bad[3], bad[4], bad[5])
        return s
    if retired:
        return "en chantier a la fin" + (" (chantier lent > 45 min)" if lent else "")
    if wait:
        return "attend " + re.search(r"en attente \(([^)]*)\)", wait[-1]).group(1) + " a la fin" + (
            (" ; manque de l'equipe : " + le[1]) if le and le[1] else "")
    return "demandee, aucune etape a la fin"


def main():
    for arch in sys.argv[1:]:
        reqs, last_etat, last_min = analyse(read(arch))
        print("== %s : %d demande(s) de bande, fin a %.0f min" % (arch, len(reqs), last_min))
        counts = {}
        for q in reqs:
            if q["end"]:
                issue, at = q["end"]
                dur = at - q["min"]
                label = issue.split(" : ")[0] if issue.startswith("arretee") else issue
                line = "%s apres %.0f min" % (issue, dur)
            else:
                label = end_state(q, last_etat)
                label_key = re.sub(r" ; manque.*", "", re.sub(r" \(.*", "", label))
                line = "%s (demandee depuis %.0f min)" % (label, last_min - q["min"])
                label = label_key
            counts[label] = counts.get(label, 0) + 1
            print("   %-8s min %5.1f  %s %6d (%s)  bande %5s  projet %3d : %2d foreuses, %2d fours, %2d paires dessous%s -> %s" % (
                q["team"], q["min"], "gisement" if q["target"] >= 100000 else "a-poste", q["target"], q["kind"], q["band"], q["pid"], q["drills"],
                q["furn"], q["pairs"], " [capi]" if q["capi"] else "", line))
        print("   BILAN des demandes : " + ", ".join("%s %d" % (k, counts[k]) for k in sorted(counts, key=lambda k: (-counts[k], k))))
        for team in sorted(last_etat):
            m, manque, bad, st = last_etat[team]
            print("   etat final %-8s (min %d) : bandes [%s]%s" % (team, m, st, (" ; manque " + manque) if manque else ""))


if __name__ == "__main__":
    main()
