# -*- coding: utf-8 -*-
"""Analyse structurelle d'un fichier Lua 5.2 (lot GRAPHIFY) : jetons, blocs, fonctions, appels, abonnements.

Aucun module hors de la bibliothèque standard. Rien n'est exécuté, rien n'est envoyé : lecture seule du source.
Meilleur effort : l'analyse est lexicale (pas de portée complète) ; ce qui n'est pas sûr est marqué approximatif
par build.py (résolution des appels).
"""
import re

KW = frozenset("and break do else elseif end false for function goto if in local nil not or repeat return then "
               "true until while".split())
LONGOPEN = re.compile(r"\[(=*)\[")
NUM = re.compile(r"0[xX][0-9a-fA-F.]+(?:[pP][+-]?\d+)?|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?")
NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
OPS3 = ("...",)
OPS2 = ("..", "==", "~=", "<=", ">=", "::", "//")
TAGRE = re.compile(r"\[FO-[A-Za-z0-9_-]+\]")

EVENT_CALLS = {
    ("Events", "on"): "event", ("Events", "on_nth_tick"): "nth", ("Events", "on_init"): "init",
    ("Events", "on_load"): "load", ("Events", "on_configuration_changed"): "config",
    ("script", "on_event"): "event", ("script", "on_nth_tick"): "nth", ("script", "on_init"): "init",
    ("script", "on_load"): "load", ("script", "on_configuration_changed"): "config",
}
NO_ARG_EVENTS = {"init", "load", "config"}


def tokenize(src):
    """Liste de (genre, valeur, ligne) ; genres : n nom, k mot-clé, s chaîne, d nombre, o opérateur."""
    toks = []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
        elif c in " \t\r":
            i += 1
        elif c == "-" and src.startswith("--", i):
            m = LONGOPEN.match(src, i + 2)
            if m:
                close = "]" + m.group(1) + "]"
                e = src.find(close, m.end())
                e = n if e < 0 else e + len(close)
                line += src.count("\n", i, e)
                i = e
            else:
                e = src.find("\n", i)
                i = n if e < 0 else e
        elif c in "\"'":
            j, start_line = i + 1, line
            while j < n:
                ch = src[j]
                if ch == "\\":
                    if j + 1 < n and src[j + 1] == "\n":
                        line += 1
                    j += 2
                    continue
                if ch == c or ch == "\n":
                    break
                j += 1
            toks.append(("s", src[i + 1:j], start_line))
            i = j + 1 if j < n and src[j] == c else j
        elif c == "[" and LONGOPEN.match(src, i):
            m = LONGOPEN.match(src, i)
            close = "]" + m.group(1) + "]"
            e = src.find(close, m.end())
            end = n if e < 0 else e + len(close)
            toks.append(("s", src[m.end():e if e >= 0 else n], line))
            line += src.count("\n", i, end)
            i = end
        elif c.isdigit() or (c == "." and i + 1 < n and src[i + 1].isdigit()):
            m = NUM.match(src, i)
            toks.append(("d", m.group(0), line))
            i = m.end()
        elif c.isalpha() or c == "_":
            m = NAME.match(src, i)
            v = m.group(0)
            toks.append(("k" if v in KW else "n", v, line))
            i = m.end()
        else:
            if src.startswith("...", i):
                toks.append(("o", "...", line))
                i += 3
            elif src[i:i + 2] in OPS2:
                toks.append(("o", src[i:i + 2], line))
                i += 2
            else:
                toks.append(("o", c, line))
                i += 1
    return toks


def _match_brackets(toks):
    match = [-1] * len(toks)
    st = []
    for i, t in enumerate(toks):
        if t[0] == "o":
            v = t[1]
            if v in ("(", "[", "{"):
                st.append(i)
            elif v in (")", "]", "}") and st:
                j = st.pop()
                match[j] = i
                match[i] = j
    return match


def _is(t, kind, val=None):
    return t is not None and t[0] == kind and (val is None or t[1] == val)


class Func(object):
    def __init__(self, qual, line, local=False, anon=False):
        self.qual = qual
        self.line = line
        self.end = line
        self.local = local
        self.anon = anon
        self.calls = {}      # chaîne (tuple) -> [première ligne, nombre, méthode ?]
        self.refs = {}       # chaîne (tuple) -> [première ligne, nombre]
        self.journals = {}   # tag -> première ligne
        self.settings = []   # (lit|const, valeur, ligne)
        self.ns = []         # (use|decl, lit|const, valeur, ligne)
        self.triggers = []   # dicts de déclencheurs dont cette fonction est le gestionnaire
        self.sched = []      # (nom de minuterie, ligne)
        self.id = None


class FileInfo(object):
    def __init__(self, rel, mod):
        self.rel = rel
        self.mod = mod
        self.funcs = []
        self.requires = []     # (module, alias|None, ligne)
        self.consts = {}       # "A.B" ou "NAME" -> chaîne
        self.tagconsts = {}    # idem -> [tags]
        self.triggers = []     # abonnements dont le gestionnaire est une référence nommée
        self.table = None
        self.settings_defs = []
        self.lines = 0


def _chain_back(toks, k):
    """Chaîne de noms finissant à l'indice k (a.b.c) ; rend (parties, indice du premier jeton)."""
    if not _is(toks[k], "n"):
        return None, k
    parts = [toks[k][1]]
    while k >= 2 and _is(toks[k - 1], "o") and toks[k - 1][1] in ".:" and _is(toks[k - 2], "n"):
        parts.insert(0, toks[k - 2][1])
        k -= 2
    return parts, k


def _function_end(toks, match, i):
    """Indice du jeton qui suit le `end` de la fonction ouverte en i (les virgules du corps ne séparent rien)."""
    n = len(toks)

    def params_end(k):
        while k < n and not (toks[k][0] == "o" and toks[k][1] == "("):
            k += 1
        return match[k] + 1 if k < n and match[k] > 0 else None

    k = params_end(i + 1)
    if k is None:
        return i + 1
    st = ["f"]
    while k < n and st:
        t = toks[k]
        if t[0] == "o" and t[1] in "([{" and match[k] > k:
            k = match[k] + 1
            continue
        if t[0] == "k":
            v = t[1]
            if v == "function":
                st.append("f")
                nk = params_end(k + 1)
                k = nk if nk is not None else k + 1
                continue
            if v in ("if", "repeat"):
                st.append("b")
            elif v in ("for", "while"):
                st.append("w")
            elif v == "do":
                if st[-1] == "w":
                    st[-1] = "l"
                else:
                    st.append("d")
            elif v in ("end", "until"):
                st.pop()
        k += 1
    return k


def _arg_text(toks, a, b):
    if b == a + 1 and toks[a][0] in "sdn":
        return toks[a][1]
    ch = _simple_chain(toks, a, b)
    return ".".join(ch) if ch else "?"


def _split_args(toks, match, open_i):
    close = match[open_i]
    args, start, j = [], open_i + 1, open_i + 1
    while j < close:
        t = toks[j]
        if t[0] == "o" and t[1] in "([{" and match[j] > j:
            j = match[j] + 1
            continue
        if t[0] == "k" and t[1] == "function":
            j = _function_end(toks, match, j)
            continue
        if t[0] == "o" and t[1] == ",":
            args.append((start, j))
            start = j + 1
        j += 1
    if start < close:
        args.append((start, close))
    return args


def _simple_chain(toks, a, b):
    """Si toks[a:b] est une chaîne a.b.c pure, rend ses parties."""
    if a >= b:
        return None
    parts, k = [], a
    while k < b:
        if not _is(toks[k], "n"):
            return None
        parts.append(toks[k][1])
        k += 1
        if k < b:
            if _is(toks[k], "o") and toks[k][1] in ".:":
                k += 1
                if k >= b:
                    return None
            else:
                return None
    return parts


def parse_file(rel, mod, src):
    toks = tokenize(src)
    match = _match_brackets(toks)
    fi = FileInfo(rel, mod)
    fi.lines = src.count("\n") + 1
    main = Func("<main>", 1)
    fi.funcs.append(main)
    scopes = [main]
    blocks = []       # 'func+' (pousse une portée), 'func' (hérite), 'blk', 'loop_wait', 'loop', 'do', 'repeat'
    brk = []          # pile des ouvrants : None ou dict(tname) pour les tables
    handler_by_idx = {}
    skip_str = set()
    sett_alias = set()
    n = len(toks)
    i = 0

    def newfunc(qual, line, local=False, anon=False):
        f = Func(qual, line, local, anon)
        fi.funcs.append(f)
        return f

    def table_name_at(open_i):
        """Nom de la table ouverte en open_i : `local T = {`, `T.x = {` ou champ `k = {` d'une table nommée."""
        if open_i >= 2 and _is(toks[open_i - 1], "o", "="):
            parts, k = _chain_back(toks, open_i - 2)
            if parts:
                before = toks[k - 1] if k > 0 else None
                if _is(before, "o") and before[1] in "{,":
                    top = brk[-1] if brk else None
                    if top and top.get("tname") and len(parts) == 1:
                        return top["tname"] + "." + parts[0]
                    return None
                return ".".join(parts)
        return None

    def reg_trigger(kind, name, line, arg_range):
        """Gestionnaire = dernier argument : fonction anonyme, ou référence nommée."""
        a, b = arg_range
        trig = {"kind": kind, "name": name, "file": rel, "line": line, "chain": None, "func": None}
        if a < b and _is(toks[a], "k", "function"):
            handler_by_idx.setdefault(a, []).append(trig)
        else:
            parts = _simple_chain(toks, a, b)
            if parts:
                trig["chain"] = parts
                fi.triggers.append(trig)
            else:
                for k in range(a, b):
                    if _is(toks[k], "k", "function"):
                        handler_by_idx.setdefault(k, []).append(trig)
                        break
                else:
                    fi.triggers.append(trig)
        return trig

    def event_names(a, b):
        out = []
        k = a
        while k < b:
            if (_is(toks[k], "n", "defines") and k + 4 < b + 1 and _is(toks[k + 2], "n", "events")
                    and _is(toks[k + 4], "n")):
                out.append(toks[k + 4][1])
                k += 5
                continue
            k += 1
        if out:
            return out
        parts = _simple_chain(toks, a, b)
        if parts:
            return [".".join(parts)]
        if b == a + 1 and toks[a][0] in "ds":
            return [toks[a][1]]
        return ["?"]

    while i < n:
        t = toks[i]
        k, v, line = t
        if k == "o":
            if v in ("(", "[", "{"):
                brk.append({"tname": table_name_at(i)} if v == "{" else None)
            elif v in (")", "]", "}"):
                if brk:
                    brk.pop()
            elif v == "=" and i + 1 < n and _is(toks[i + 1], "s") and not (
                    i + 2 < n and _is(toks[i + 2], "o", "..")):
                parts, ks = _chain_back(toks, i - 1)
                if parts:
                    before = toks[ks - 1] if ks > 0 else None
                    top = brk[-1] if brk else None
                    key = None
                    if _is(before, "o") and before[1] in "{," and top and top.get("tname") and len(parts) == 1:
                        key = top["tname"] + "." + parts[0]
                    elif not (_is(before, "o") and before[1] in "{,("):
                        key = ".".join(parts)
                    if key:
                        sv = toks[i + 1][1]
                        fi.consts[key] = sv
                        tags = TAGRE.findall(sv)
                        if tags:
                            fi.tagconsts[key] = tags
                            skip_str.add(i + 1)
            i += 1
            continue
        if k == "s":
            if i not in skip_str:
                for tg in TAGRE.findall(v):
                    scopes[-1].journals.setdefault(tg, line)
            i += 1
            continue
        if k == "k":
            if v == "function":
                prev = toks[i - 1] if i > 0 else None
                j = i + 1
                rec, pushed = None, False
                if _is(toks[j], "n"):
                    parts = [toks[j][1]]
                    j += 1
                    while _is(toks[j], "o") and toks[j][1] in ".:" and _is(toks[j + 1], "n"):
                        parts.append(toks[j + 1][1])
                        j += 2
                    rec = newfunc(".".join(parts), line, local=_is(prev, "k", "local"))
                else:
                    trigs = handler_by_idx.get(i)
                    named = None
                    if _is(prev, "o", "="):
                        parts, ks = _chain_back(toks, i - 2)
                        if parts:
                            before = toks[ks - 1] if ks > 0 else None
                            if _is(before, "o") and before[1] in "{,":
                                top = brk[-1] if brk else None
                                if top and top.get("tname") and len(parts) == 1:
                                    named = (top["tname"] + "." + parts[0], False)
                            else:
                                named = (".".join(parts), _is(before, "k", "local"))
                    if trigs:
                        t0 = trigs[0]
                        label = "<%s %s@%d>" % (t0["kind"], t0["name"], line)
                        rec = newfunc(named[0] if named and t0["kind"] == "remote" else label, line, anon=True)
                        rec.triggers.extend(trigs)
                        for tg in trigs:
                            tg["func"] = rec
                    elif named:
                        rec = newfunc(named[0], line, local=named[1])
                if rec is not None:
                    scopes.append(rec)
                    blocks.append("func+")
                else:
                    blocks.append("func")
                if j < n and _is(toks[j], "o", "(") and match[j] > j:
                    i = match[j] + 1
                else:
                    i = j
                continue
            if v in ("if", "repeat"):
                blocks.append("repeat" if v == "repeat" else "blk")
            elif v in ("for", "while"):
                blocks.append("loop_wait")
            elif v == "do":
                if blocks and blocks[-1] == "loop_wait":
                    blocks[-1] = "loop"
                else:
                    blocks.append("do")
            elif v in ("end", "until"):
                if blocks:
                    b = blocks.pop()
                    if b == "func+" and len(scopes) > 1:
                        scopes.pop().end = line
            elif v == "return" and not blocks and not brk:
                if _is(toks[i + 1] if i + 1 < n else None, "n") and not (
                        i + 2 < n and _is(toks[i + 2], "o") and toks[i + 2][1] in ".(:"):
                    fi.table = toks[i + 1][1]
            i += 1
            continue
        if k != "n":
            i += 1
            continue
        # k == "n" : début éventuel d'une chaîne
        prev = toks[i - 1] if i > 0 else None
        method_on_expr = False
        if _is(prev, "o") and prev[1] in ".:":
            if i >= 2 and (_is(toks[i - 2], "o") and toks[i - 2][1] in ")]") and i + 1 < n and \
                    _is(toks[i + 1], "o", "("):
                method_on_expr = True
            else:
                i += 1
                continue
        if method_on_expr:
            parts, j = ["?", v], i
        else:
            parts, j = [v], i
            while j + 2 < n and _is(toks[j + 1], "o") and toks[j + 1][1] in ".:" and _is(toks[j + 2], "n"):
                parts.append(toks[j + 2][1])
                j += 2
        nxt = toks[j + 1] if j + 1 < n else None
        scope = scopes[-1]
        is_call = nxt is not None and ((nxt[0] == "o" and nxt[1] in "({") or nxt[0] == "s")
        pj = tuple(parts)
        # require
        if parts == ["require"] and is_call:
            a = j + 2 if _is(nxt, "o", "(") else j + 1
            if a < n and _is(toks[a], "s"):
                alias = None
                if i >= 2 and _is(toks[i - 1], "o", "=") and _is(toks[i - 2], "n"):
                    alias = toks[i - 2][1]
                fi.requires.append((toks[a][1], alias, line))
            i = j + 1
            continue
        # réglages lus : settings.global[...] / settings.startup[...]
        if len(parts) == 2 and parts[0] == "settings" and parts[1] in ("global", "startup") and \
                not _is(nxt, "o", "[") and _is(prev, "o", "=") and i >= 2 and _is(toks[i - 2], "n"):
            sett_alias.add(toks[i - 2][1])
        if ((len(parts) == 2 and parts[0] == "settings" and parts[1] in ("global", "startup"))
                or (len(parts) == 1 and parts[0] in sett_alias)) and _is(nxt, "o", "[") and match[j + 1] > 0:
            a, b = j + 2, match[j + 1]
            if b == a + 1 and _is(toks[a], "s"):
                scope.settings.append(("lit", toks[a][1], line))
            else:
                ch = _simple_chain(toks, a, b)
                if ch:
                    scope.settings.append(("const", ".".join(ch), line))
            i = j + 1
            continue
        if is_call and _is(nxt, "o", "(") and match[j + 1] > 0:
            args = _split_args(toks, match, j + 1)
            # états
            if len(parts) == 2 and parts[0] == "Storage" and parts[1] in ("ns", "declare") and args:
                a, b = args[0]
                use = "use" if parts[1] == "ns" else "decl"
                if b == a + 1 and _is(toks[a], "s"):
                    scope.ns.append((use, "lit", toks[a][1], line))
                else:
                    ch = _simple_chain(toks, a, b)
                    if ch:
                        scope.ns.append((use, "const", ".".join(ch), line))
            # abonnements
            if len(parts) == 2 and (parts[0], parts[1]) in EVENT_CALLS and args:
                kind = EVENT_CALLS[(parts[0], parts[1])]
                if kind in NO_ARG_EVENTS:
                    reg_trigger(kind, kind, line, args[-1])
                elif len(args) >= 2:
                    names = event_names(*args[0])
                    if kind == "nth":
                        names = ["nth_tick(%s)" % x for x in names]
                    for nm in names:
                        reg_trigger("nth" if kind == "nth" else "event", nm, line, args[-1])
            elif parts == ["commands", "add_command"] and len(args) >= 2:
                a, b = args[0]
                nm = toks[a][1] if b == a + 1 and _is(toks[a], "s") else "?"
                reg_trigger("command", "/" + nm, line, args[-1])
            elif parts == ["remote", "add_interface"] and len(args) >= 2:
                a, b = args[0]
                iface = toks[a][1] if b == a + 1 and _is(toks[a], "s") else "?"
                ta, tb = args[1]
                if ta < tb and _is(toks[ta], "o", "{") and match[ta] > 0:
                    for (sa, sb) in _split_args(toks, match, ta):
                        if sb - sa >= 3 and _is(toks[sa], "n") and _is(toks[sa + 1], "o", "="):
                            reg_trigger("remote", "%s.%s" % (iface, toks[sa][1]), line, (sa + 2, sb))
            elif len(parts) == 2 and parts[0] == "Scheduler" and parts[1] in ("define_lane", "define_timer") \
                    and len(args) >= 2:
                a, b = args[0]
                nm = _arg_text(toks, a, b)
                if parts[1] == "define_lane" and len(args) >= 3:
                    pa, pb = args[1]
                    per = _arg_text(toks, pa, pb)
                    reg_trigger("lane", "%s/%s" % (nm, per), line, args[-1])
                elif parts[1] == "define_timer":
                    reg_trigger("timer", nm, line, args[-1])
            elif len(parts) == 2 and parts[0] == "Scheduler" and parts[1] == "after" and len(args) >= 2:
                a, b = args[1]
                if b == a + 1 and _is(toks[a], "s"):
                    scope.sched.append((toks[a][1], line))
        # appel ou référence ordinaire
        if is_call:
            e = scope.calls.get(pj)
            if e:
                e[1] += 1
            else:
                ismeth = (method_on_expr and prev[1] == ":") or any(
                    toks[x][0] == "o" and toks[x][1] == ":" for x in range(i, j))
                scope.calls[pj] = [line, 1, ismeth]
        elif not _is(nxt, "o", "=") and parts[0] != "?":
            e = scope.refs.get(pj)
            if e:
                e[1] += 1
            else:
                scope.refs[pj] = [line, 1]
        i = j + 1
    fi.n_unclosed = len(blocks)
    return fi


def parse_settings_defs(src):
    """Définitions de réglages (`type = "bool-setting", name = "...", default_value = ...`) d'un fichier settings."""
    toks = tokenize(src)
    match = _match_brackets(toks)
    out = []
    for i, t in enumerate(toks):
        if t[0] == "o" and t[1] == "{" and match[i] > 0:
            fields = {}
            for (a, b) in _split_args(toks, match, i):
                if b - a >= 3 and _is(toks[a], "n") and _is(toks[a + 1], "o", "=") and b == a + 3:
                    fields[toks[a][1]] = toks[a + 2][1]
            ty = fields.get("type", "")
            if ty.endswith("-setting") and "name" in fields:
                out.append({"name": fields["name"], "type": ty, "default": fields.get("default_value"),
                            "line": t[2]})
    return out
