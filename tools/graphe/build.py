# -*- coding: utf-8 -*-
"""Construit le graphe du mod : tools/graphe/out/graphe.json + INDEX.md (lot GRAPHIFY).

    py -3.9 -B tools/graphe/build.py [--root <dossier du mod>] [--out <dossier de sortie>]

Local, sans réseau, sans LLM : lecture des sources Lua (shared/, script/, prototypes/, settings/, racine, migrations/).
"""
import argparse
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import luaparse  # noqa: E402

SCAN_DIRS = ("shared", "script", "prototypes", "settings", "migrations")
STD_ROOTS = frozenset(
    "table string math game defines settings global script remote commands rendering log os io pairs ipairs type "
    "tostring tonumber select next error assert pcall xpcall setmetatable getmetatable rawget rawset rawequal unpack "
    "require serpent util data localised_string coroutine bit32 debug collectgarbage print load loadstring dofile "
    "self prototypes".split())


def mod_of(rel):
    p = rel[:-4] if rel.endswith(".lua") else rel
    if p.endswith("/init"):
        p = p[:-5]
    return p.replace("/", ".")


def list_sources(root):
    out = []
    for name in sorted(os.listdir(root)):
        if name.endswith(".lua") and os.path.isfile(os.path.join(root, name)):
            out.append(name)
    for d in SCAN_DIRS:
        base = os.path.join(root, d)
        for dp, dn, fn in os.walk(base):
            dn.sort()
            for f in sorted(fn):
                if f.endswith(".lua"):
                    out.append(os.path.relpath(os.path.join(dp, f), root).replace(os.sep, "/"))
    return out


class Index(object):
    """Index de résolution : fichiers, fonctions par table, par nom court."""

    def __init__(self, files):
        self.files = files
        self.mod2file = {f.mod: f for f in files}
        self.tablefuncs = {}   # rel -> {table -> {clé -> [Func]}}
        self.locals = {}       # rel -> {nom -> Func}
        self.keyfuncs = {}     # rel -> {clé -> [Func]}
        self.short = {}        # dernier nom -> [Func] (fonctions pointées seulement)
        for f in files:
            tf, lo, kf = {}, {}, {}
            for fn in f.funcs:
                if fn.anon or fn.qual == "<main>":
                    continue
                q = fn.qual
                if "." not in q:
                    lo[q] = fn
                    continue
                tbl, key = q.split(".", 1)
                tf.setdefault(tbl, {}).setdefault(key, []).append(fn)
                kf.setdefault(key, []).append(fn)
                self.short.setdefault(q.rsplit(".", 1)[1], []).append(fn)
            self.tablefuncs[f.rel], self.locals[f.rel], self.keyfuncs[f.rel] = tf, lo, kf
        self.alias = {}
        for f in files:
            al = {}
            for (m, a, _l) in f.requires:
                if a:
                    al[a] = self.mod2file.get(m)
            self.alias[f.rel] = al

    def lookup_in(self, target, key):
        """Fonction `key` (a.b) d'un fichier cible : table du module d'abord, puis tout candidat unique."""
        tf = self.tablefuncs[target.rel]
        if target.table and key in tf.get(target.table, {}):
            c = tf[target.table][key]
            return c[-1]
        c = self.keyfuncs[target.rel].get(key, [])
        return c[-1] if len(c) == 1 else None

    def resolve(self, f, parts, is_method=False):
        """(Func, approximatif ?) ou (None, False)."""
        root = parts[0]
        if len(parts) == 1:
            fn = self.locals[f.rel].get(root)
            return (fn, False) if fn else (None, False)
        key = ".".join(parts[1:])
        tgt = self.alias[f.rel].get(root)
        if tgt is not None:
            fn = self.lookup_in(tgt, key)
            return (fn, False) if fn else (None, False)
        if root in self.tablefuncs[f.rel] and key in self.tablefuncs[f.rel][root]:
            return self.tablefuncs[f.rel][root][key][-1], False
        if root in STD_ROOTS and root != "self":
            return None, False
        if root in self.alias[f.rel]:
            return None, False
        if root == "self":
            c = self.keyfuncs[f.rel].get(key, [])
            return (c[-1], True) if len(c) == 1 else (None, False)
        last = parts[-1]
        cands = self.short.get(last, [])
        if len(cands) == 1 and len(last) >= 5 and (is_method or root == "?" or len(parts) >= 2):
            return cands[0], True
        return None, False

    def const(self, f, chain):
        """Valeur d'une constante chaîne `A.B` / `NAME` (même fichier ou module requis)."""
        if chain in f.consts:
            return f.consts[chain]
        parts = chain.split(".")
        tgt = self.alias[f.rel].get(parts[0])
        if tgt is not None and len(parts) > 1:
            rest = ".".join(parts[1:])
            for k in ((tgt.table + "." + rest) if tgt.table else None, rest):
                if k and k in tgt.consts:
                    return tgt.consts[k]
            c = [v for kk, v in sorted(tgt.consts.items()) if kk.endswith("." + rest)]
            if len(set(c)) == 1:
                return c[0]
        return None

    def tags_of(self, f, parts):
        key = ".".join(parts)
        if key in f.tagconsts:
            return f.tagconsts[key]
        tgt = self.alias[f.rel].get(parts[0])
        if tgt is not None and len(parts) > 1:
            rest = ".".join(parts[1:])
            for k in ((tgt.table + "." + rest) if tgt.table else None, rest):
                if k and k in tgt.tagconsts:
                    return tgt.tagconsts[k]
        return []


def build(root, verbose=True):
    t0 = time.time()
    rels = list_sources(root)
    files, settings_defs, errors = [], {}, []
    for rel in rels:
        with open(os.path.join(root, rel), "rb") as fh:
            src = fh.read().decode("utf-8", "replace")
        try:
            fi = luaparse.parse_file(rel, mod_of(rel), src)
        except Exception as ex:  # un fichier illisible ne doit pas arrêter la carte
            errors.append("%s : %s" % (rel, ex))
            continue
        if fi.n_unclosed:
            errors.append("%s : %d bloc(s) non fermé(s) (analyse approximative)" % (rel, fi.n_unclosed))
        if rel == "settings.lua" or rel.startswith("settings/"):
            for d in luaparse.parse_settings_defs(src):
                d["file"] = rel
                settings_defs[d["name"]] = d
        files.append(fi)
    idx = Index(files)
    # identifiants
    for f in files:
        seen = {}
        for fn in f.funcs:
            base = "%s:%s" % (f.mod, fn.qual)
            if base in seen:
                base = "%s@%d" % (base, fn.line)
            seen[base] = True
            fn.id = base
    funcs = {}
    edges_in = {}
    unresolved_handlers = []
    for f in files:
        for fn in f.funcs:
            rec = {"file": f.rel, "line": fn.line, "end": fn.end, "qual": fn.qual, "local": fn.local,
                   "anon": fn.anon, "calls": [], "refs": [], "journals": [], "settings": [], "ns": [],
                   "triggers": [], "sched": []}
            for chain in sorted(fn.calls):
                line, cnt, meth = fn.calls[chain]
                tgt, approx = idx.resolve(f, list(chain), meth)
                if tgt is not None and tgt is not fn:
                    rec["calls"].append([tgt.id, line, 1 if approx else 0, cnt])
                for tg in idx.tags_of(f, chain):
                    rec["journals"].append([tg, line])
            for chain in sorted(fn.refs):
                line, cnt = fn.refs[chain]
                tgt, approx = idx.resolve(f, list(chain))
                if tgt is not None and tgt is not fn and not approx:
                    rec["refs"].append([tgt.id, line, 0, cnt])
                for tg in idx.tags_of(f, chain):
                    rec["journals"].append([tg, line])
            for tg, line in sorted(fn.journals.items()):
                rec["journals"].append([tg, line])
            for (kind, val, line) in fn.settings:
                name = val if kind == "lit" else idx.const(f, val)
                rec["settings"].append([name or ("?" + val), line])
            for (use, kind, val, line) in fn.ns:
                name = val if kind == "lit" else idx.const(f, val)
                rec["ns"].append([use, name or ("?" + val), line])
            for (tm, line) in fn.sched:
                rec["sched"].append([tm, line])
            for tg in fn.triggers:
                rec["triggers"].append({"kind": tg["kind"], "name": tg["name"], "line": tg["line"],
                                        "file": tg["file"]})
            funcs[fn.id] = rec
    triggers = []
    for f in files:
        for tg in f.triggers:
            tgt, _ap = idx.resolve(f, tg["chain"]) if tg["chain"] else (None, False)
            ent = {"kind": tg["kind"], "name": tg["name"], "file": tg["file"], "line": tg["line"],
                   "handler": tgt.id if tgt else None}
            if tgt is not None:
                funcs[tgt.id]["triggers"].append({"kind": tg["kind"], "name": tg["name"], "line": tg["line"],
                                                  "file": tg["file"]})
            else:
                unresolved_handlers.append(ent)
            triggers.append(ent)
        for fn in f.funcs:
            for tg in fn.triggers:
                triggers.append({"kind": tg["kind"], "name": tg["name"], "file": tg["file"], "line": tg["line"],
                                 "handler": fn.id})
    # minuteries : Scheduler.after(délai, nom, ...) -> gestionnaire de la minuterie
    timers = {t["name"]: t["handler"] for t in triggers if t["kind"] == "timer" and t["handler"]}
    for fid in sorted(funcs):
        for (tm, line) in funcs[fid]["sched"]:
            h = timers.get(tm)
            if h and h != fid:
                funcs[fid]["refs"].append([h, line, 0, 1])
    triggers.sort(key=lambda t: (t["kind"], t["name"], t["file"], t["line"]))
    modules = {}
    for f in files:
        reqs = sorted(set(m for (m, _a, _l) in f.requires))
        m = {"file": f.rel, "lines": f.lines, "table": f.table, "requires": reqs,
             "funcs": [fn.id for fn in f.funcs]}
        modules[f.mod] = m
    journals, settings_read, ns_users, ns_decl = {}, {}, {}, {}
    for fid in sorted(funcs):
        r = funcs[fid]
        mod = fid.split(":", 1)[0]
        for tg, line in r["journals"]:
            journals.setdefault(tg, [])
            if [fid, line] not in journals[tg]:
                journals[tg].append([fid, line])
        for name, line in r["settings"]:
            settings_read.setdefault(name, []).append([fid, line])
        for use, name, line in r["ns"]:
            (ns_decl if use == "decl" else ns_users).setdefault(name, []).append([fid, line])
    meta = {"fichiers": len(files), "fonctions": len(funcs),
            "appels_resolus": sum(len(r["calls"]) for r in funcs.values()),
            "references": sum(len(r["refs"]) for r in funcs.values()),
            "declencheurs": len(triggers), "declencheurs_sans_gestionnaire": len(unresolved_handlers),
            "journaux": len(journals), "reglages_lus": len(settings_read), "reglages_definis": len(settings_defs),
            "etats_declares": len(ns_decl), "avertissements": errors,
            "secondes": round(time.time() - t0, 2), "commit": git_head(root)}
    return {"meta": meta, "modules": modules, "functions": funcs, "triggers": triggers, "journals": journals,
            "settings_read": settings_read, "settings_defs": settings_defs, "ns_used": ns_users,
            "ns_declared": ns_decl}


def git_head(root):
    try:
        return subprocess.check_output(["git", "-C", root, "rev-parse", "--short", "HEAD"],
                                       stderr=subprocess.DEVNULL).decode().strip()
    except Exception:
        return "?"


def write_index(g, path):
    m = g["meta"]
    L = ["# Index du graphe du mod (généré par tools/graphe/build.py, ne pas éditer)", "",
         "Commit %s. %d fichiers, %d fonctions, %d appels résolus, %d références, %d déclencheurs, %d journaux [FO-*], "
         "%d réglages lus, %d états déclarés. Construit en %s s." % (
             m["commit"], m["fichiers"], m["fonctions"], m["appels_resolus"], m["references"], m["declencheurs"],
             m["journaux"], m["reglages_lus"], m["etats_declares"], m["secondes"]),
         "Requête : `py -3.9 -B tools/graphe/q.py <fonction|module|journal|évènement|réglage>`.", ""]
    L += ["## Déclencheurs (évènements, commandes, remote, voies)", ""]
    last = None
    for t in g["triggers"]:
        if t["kind"] != last:
            L.append("### %s" % t["kind"])
            last = t["kind"]
        h = g["functions"].get(t["handler"]) if t["handler"] else None
        L.append("- %s : %s:%d -> %s" % (t["name"], t["file"], t["line"], t["handler"] or "(gestionnaire non résolu)"))
    L += ["", "## Journaux [FO-*] (fonctions qui les émettent)", ""]
    for tg in sorted(g["journals"]):
        em = g["journals"][tg]
        L.append("- %s : %s" % (tg, ", ".join("%s:%d" % (f, ln) for f, ln in em[:4]) + (
            " … (+%d)" % (len(em) - 4) if len(em) > 4 else "")))
    L += ["", "## Réglages (définis dans settings/, lus par)", ""]
    names = sorted(set(g["settings_defs"]) | set(g["settings_read"]))
    for nm in names:
        d = g["settings_defs"].get(nm)
        rd = sorted(set(f.split(":", 1)[0] for f, _l in g["settings_read"].get(nm, [])))
        L.append("- %s%s : lu par %s" % (nm, " (%s, %s)" % (d["file"], d["type"]) if d else " (non défini)",
                                        ", ".join(rd) if rd else "(personne)"))
    L += ["", "## États persistants (Storage.declare / Storage.ns)", ""]
    for nm in sorted(set(g["ns_declared"]) | set(g["ns_used"])):
        dc = sorted(set(f.split(":", 1)[0] for f, _l in g["ns_declared"].get(nm, [])))
        us = sorted(set(f.split(":", 1)[0] for f, _l in g["ns_used"].get(nm, [])))
        L.append("- %s : déclaré par %s ; utilisé par %d module(s)" % (nm, ", ".join(dc) or "?", len(us)))
    L += ["", "## Modules", "", "Nom du module | fichier | lignes | fonctions | requiert", "---|---|---|---|---"]
    for mod in sorted(g["modules"]):
        mm = g["modules"][mod]
        L.append("%s | %s | %d | %d | %d" % (mod, mm["file"], mm["lines"], len(mm["funcs"]) - 1, len(mm["requires"])))
    if m["avertissements"]:
        L += ["", "## Avertissements d'analyse", ""] + ["- " + w for w in m["avertissements"]]
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(L) + "\n")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=os.path.abspath(os.path.join(HERE, "..", "..")))
    ap.add_argument("--out", default=os.path.join(HERE, "out"))
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    g = build(a.root)
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "graphe.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(g, fh, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    write_index(g, os.path.join(a.out, "INDEX.md"))
    m = g["meta"]
    print("[GRAPHE] %d fichiers, %d fonctions, %d appels, %d références, %d déclencheurs (%d sans gestionnaire), "
          "%d journaux, %d réglages lus, %d états déclarés ; %s s ; %d avertissement(s) -> %s" % (
              m["fichiers"], m["fonctions"], m["appels_resolus"], m["references"], m["declencheurs"],
              m["declencheurs_sans_gestionnaire"], m["journaux"], m["reglages_lus"], m["etats_declares"],
              m["secondes"], len(m["avertissements"]), a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
