# -*- coding: utf-8 -*-
"""Requête du graphe du mod (lot GRAPHIFY) : chaîne causale déclencheur -> décision -> action -> journal.

    py -3.9 -B tools/graphe/q.py <fonction|module|journal|évènement|réglage|ns:<état>> [--graphe <graphe.json>]

Rend au plus 30 lignes. `~` marque un appel DEVINÉ (nom court unique dans le dépôt), jamais un appel prouvé.
"""
import argparse
import collections
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MAX_LINES = 30


def load(path):
    with open(path, "r", encoding="utf-8") as fh:
        return index(json.load(fh))


def index(g):
    callers = collections.defaultdict(list)    # id -> [(appelant, ligne, approx, genre)]
    for fid in sorted(g["functions"]):
        r = g["functions"][fid]
        for (tgt, line, ap, _c) in r["calls"]:
            callers[tgt].append((fid, line, ap, "appel"))
        for (tgt, line, ap, _c) in r["refs"]:
            callers[tgt].append((fid, line, ap, "réf"))
    g["_callers"] = callers
    return g


def short(fid):
    return fid.replace("script.", "s.", 1) if fid.startswith("script.") else fid


def label_trigger(t):
    return "%s %s" % (t["kind"], t["name"])


def find_functions(g, name):
    fs = g["functions"]
    if name in fs:
        return [name]
    exact = [fid for fid, r in sorted(fs.items()) if r["qual"] == name]
    if exact:
        return exact
    suffix = [fid for fid, r in sorted(fs.items()) if r["qual"].endswith("." + name) and not r["anon"]]
    if suffix:
        return suffix
    return [fid for fid in sorted(fs) if name.lower() in fid.lower() and not fs[fid]["anon"]][:12]


def chains_up(g, fid, limit=3, depth=9):
    """Plus courtes chaînes d'appelants jusqu'à une fonction déclenchée (évènement, remote, commande, voie)."""
    fs = g["functions"]
    parent = {fid: None}
    order = collections.deque([(fid, 0)])
    found = []
    while order and len(found) < limit:
        cur, d = order.popleft()
        if cur != fid and fs[cur]["triggers"]:
            found.append(cur)
            continue
        if d >= depth:
            continue
        for (c, _ln, _ap, _k) in sorted(g["_callers"].get(cur, [])):
            if c not in parent and not c.endswith(":<main>"):
                parent[c] = cur
                order.append((c, d + 1))
    out = []
    for root in found:
        path, cur = [], root
        while cur is not None:
            path.append(cur)
            cur = parent[cur]
        out.append(path)
    return out


def journals_down(g, fid, depth=3, limit=6):
    fs = g["functions"]
    seen = {fid}
    level = [fid]
    out = []
    for _d in range(depth + 1):
        nxt = []
        for cur in level:
            for tg, _ln in fs[cur]["journals"]:
                out.append((tg, cur))
            for (t, _l, ap, _c) in fs[cur]["calls"] + fs[cur]["refs"]:
                if t not in seen and not ap:
                    seen.add(t)
                    nxt.append(t)
        level = nxt
    uniq, seen_t = [], set()
    for tg, cur in out:
        if tg not in seen_t:
            seen_t.add(tg)
            uniq.append((tg, cur))
    return uniq[:limit]


def fmt_list(items, cap):
    shown = items[:cap]
    return ", ".join(shown) + (" … (+%d)" % (len(items) - cap) if len(items) > cap else "")


def q_function(g, fid):
    r = g["functions"][fid]
    L = ["FONCTION %s  (%s:%d-%d)" % (fid, r["file"], r["line"], r["end"])]
    if r["triggers"]:
        L.append("  déclenchée par : " + fmt_list(["%s (%s:%d)" % (label_trigger(t), t["file"], t["line"])
                                                    for t in r["triggers"]], 4))
    cs = sorted(g["_callers"].get(fid, []))
    L.append("  appelée par (%d) : %s" % (len(cs), fmt_list(
        ["%s%s:%d%s" % ("~" if ap else "", short(c), ln, " [réf]" if k == "réf" else "") for c, ln, ap, k in cs], 7)
        if cs else "personne (dans le graphe)"))
    callees = [(t, ln, ap) for (t, ln, ap, _c) in r["calls"]] + [(t, ln, 0) for (t, ln, _a, _c) in r["refs"]]
    L.append("  appelle (%d) : %s" % (len(callees), fmt_list(
        ["%s%s:%d" % ("~" if ap else "", short(t), ln) for t, ln, ap in callees], 9) if callees else "aucune fonction du mod"))
    ch = chains_up(g, fid)
    if ch:
        L.append("  chaîne causale (déclencheur -> ... -> fonction) :")
        for path in ch:
            trig = g["functions"][path[0]]["triggers"]
            head = label_trigger(trig[0]) if trig else "?"
            L.append("    %s => %s" % (head, " -> ".join(g["functions"][p]["qual"] for p in path)))
    elif not r["triggers"]:
        L.append("  chaîne causale : aucun déclencheur trouvé en amont (appel dynamique ou non résolu)")
    own = sorted(set(tg for tg, _ in r["journals"]))
    if own:
        L.append("  journal émis : " + fmt_list(own, 6))
    down = [(tg, c) for tg, c in journals_down(g, fid) if tg not in own]
    if down:
        L.append("  journal en aval (<=3 appels) : " + fmt_list(["%s<-%s" % (tg, g["functions"][c]["qual"])
                                                              for tg, c in down], 4))
    st = sorted(set(s[0] for s in r["settings"]))
    if st:
        L.append("  réglages lus : " + fmt_list(st, 6))
    ns = sorted(set("%s:%s" % (u, nm) for u, nm, _l in r["ns"]))
    if ns:
        L.append("  états : " + fmt_list(ns, 6))
    return L


def q_journal(g, tag):
    em = g["journals"][tag]
    L = ["JOURNAL %s : émis par %d fonction(s)" % (tag, len(em))]
    for fid, ln in em[:6]:
        L.append("  %s  (%s:%d)" % (fid, g["functions"][fid]["file"], ln))
        ch = chains_up(g, fid, limit=1)
        if ch:
            path = ch[0]
            trig = g["functions"][path[0]]["triggers"]
            L.append("    <= %s => %s" % (label_trigger(trig[0]) if trig else "?",
                                            " -> ".join(g["functions"][p]["qual"] for p in path)))
        else:
            L.append("    <= (pas de déclencheur en amont trouvé)")
    if len(em) > 6:
        L.append("  … (+%d autres fonctions)" % (len(em) - 6))
    return L


def q_module(g, mod):
    m = g["modules"][mod]
    fs = g["functions"]
    L = ["MODULE %s  (%s, %d lignes, table %s)" % (mod, m["file"], m["lines"], m["table"] or "-"),
         "  requiert (%d) : %s" % (len(m["requires"]), fmt_list(m["requires"], 8))]
    rq = sorted(k for k, v in g["modules"].items() if mod in v["requires"])
    L.append("  requis par (%d) : %s" % (len(rq), fmt_list(rq, 8)))
    trig = [(fs[f]["qual"], t) for f in m["funcs"] for t in fs[f]["triggers"]]
    if trig:
        L.append("  abonnements : " + fmt_list(["%s -> %s" % (label_trigger(t), q) for q, t in trig], 6))
    pub = [fs[f]["qual"] + ":" + str(fs[f]["line"]) for f in m["funcs"] if not fs[f]["local"]
           and not fs[f]["anon"] and fs[f]["qual"] != "<main>"]
    L.append("  fonctions (%d, hors locales) : %s" % (len(pub), fmt_list(pub, 10)))
    jt = sorted(set(tg for f in m["funcs"] for tg, _ in fs[f]["journals"]))
    if jt:
        L.append("  journaux : " + fmt_list(jt, 8))
    st = sorted(set(s[0] for f in m["funcs"] for s in fs[f]["settings"]))
    if st:
        L.append("  réglages lus : " + fmt_list(st, 8))
    ns = sorted(set("%s:%s" % (u, nm) for f in m["funcs"] for u, nm, _l in fs[f]["ns"]))
    if ns:
        L.append("  états : " + fmt_list(ns, 8))
    return L


def q_setting(g, name):
    d = g["settings_defs"].get(name)
    L = ["RÉGLAGE %s : %s" % (name, "défini %s (%s, défaut %s)" % (d["file"], d["type"], d["default"]) if d
                             else "non défini dans settings/")]
    rd = g["settings_read"].get(name, [])
    for fid, ln in rd[:12]:
        L.append("  lu par %s  (%s:%d)" % (fid, g["functions"][fid]["file"], ln))
    if not rd:
        L.append("  lu par : personne par lecture directe settings.global[...] (accès indirect possible)")
    return L


def q_trigger(g, name):
    ts = [t for t in g["triggers"] if t["name"] == name or t["name"].endswith("." + name)]
    L = ["DÉCLENCHEUR %s : %d abonnement(s)" % (name, len(ts))]
    for t in ts[:24]:
        L.append("  %s %s:%d -> %s" % (t["kind"], t["file"], t["line"], t["handler"] or "?"))
    return L


def q_ns(g, name):
    L = ["ÉTAT %s : déclaré par %s" % (name, fmt_list(sorted(set(f for f, _ in g["ns_declared"].get(name, []))), 3) or "?")]
    us = g["ns_used"].get(name, [])
    mods = sorted(set(f.split(":", 1)[0] for f, _ in us))
    L.append("  utilisé par %d module(s) : %s" % (len(mods), fmt_list(mods, 14)))
    return L


def answer(g, what):
    w = what.strip()
    tag = w if w.startswith("[") else "[" + w + "]"
    if re.match(r"^\[FO-[A-Za-z0-9_-]+\]$", tag) and tag in g["journals"]:
        return q_journal(g, tag)
    if w.startswith("ns:"):
        return q_ns(g, w[3:])
    if w in g["settings_defs"] or w in g["settings_read"]:
        return q_setting(g, w)
    mod = w[:-4].replace("/", ".") if w.endswith(".lua") else w
    if mod in g["modules"]:
        return q_module(g, mod)
    if "/" in w or w.startswith("script.") or w.startswith("shared."):
        c = sorted(m for m in g["modules"] if w.replace("/", ".") in m)
        if len(c) == 1:
            return q_module(g, c[0])
    fids = find_functions(g, w)
    if len(fids) == 1:
        return q_function(g, fids[0])
    if len(fids) > 1:
        L = ["%d fonctions pour « %s » (préciser par module:qual) :" % (len(fids), w)]
        for f in fids[:MAX_LINES - 2]:
            L.append("  %s  (%s:%d)" % (f, g["functions"][f]["file"], g["functions"][f]["line"]))
        return L
    if any(t["name"] == w or t["name"].endswith("." + w) for t in g["triggers"]):
        return q_trigger(g, w)
    return ["Rien trouvé pour « %s » (fonction, module, journal [FO-*], évènement, réglage, ns:<état>)." % w]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("what")
    ap.add_argument("--graphe", default=os.path.join(HERE, "out", "graphe.json"))
    a = ap.parse_args(argv)
    if not os.path.isfile(a.graphe):
        print("graphe absent : lancer d'abord py -3.9 -B tools/graphe/build.py")
        return 2
    lines = answer(load(a.graphe), a.what)
    if len(lines) > MAX_LINES:
        lines = lines[:MAX_LINES - 1] + ["… (%d ligne(s) coupée(s))" % (len(lines) - MAX_LINES + 1)]
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
