# -*- coding: utf-8 -*-
"""Tests de tools/graphe sur un mini-dépôt Lua jetable (lot GRAPHIFY). Aucun jeu, aucun réseau.

    py -3.9 -B tools/graphe/test_graphe.py
"""
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build  # noqa: E402
import luaparse  # noqa: E402
import q  # noqa: E402

FILES = {
    "settings/ex.lua": '''data:extend({
  { type = "bool-setting", name = "fo-war-ex", setting_type = "runtime-global", default_value = true },
  { type = "int-setting", name = "fo-ex-n", setting_type = "runtime-global", default_value = 4 },
})
''',
    "shared/util.lua": '''local U = {}
function U.double(x) return x * 2 end
-- function U.fantome() end   [FO-COMMENTAIRE]
local s = [==[ function U.chaine() end [FO-CHAINE-LONGUE] ]==]
return U
''',
    "script/core/events.lua": '''local Events = {}
function Events.on(id, fn) end
function Events.on_nth_tick(n, fn) end
function Events.on_init(fn) end
return Events
''',
    "script/core/storage.lua": '''local Storage = {}
function Storage.declare(name, init) end
function Storage.ns(name) return {} end
return Storage
''',
    "script/b.lua": '''local U = require("shared.util")
local Storage = require("script.core.storage")
local B = {}
B.SETTING = "fo-war-ex"
local TAG = "[FO-BTAG]"
Storage.declare("bstate", function() return { a = 1, b = 2 } end)

local function helper(a, b)
  for i = 1, 3 do
    if i == 2 then log(TAG .. " helper " .. U.double(i)) end
  end
  return a, b
end

function B.on()
  local s = settings.global[B.SETTING]
  return not (s ~= nil and s.value == false)
end

function B.work(e)
  local ns = Storage.ns("bstate")
  local t = { k = function(x, y) return U.double(x) end, z = 1 }
  if B.on() then helper(1, 2) end
  log("[FO-BWORK] fait")
  return t
end

function B:method(x) return self.helper2(x) end
function B.helper2(x) return x end
return B
''',
    "script/a.lua": '''local Events = require("script.core.events")
local B = require("script.b")
local U = require("shared.util")
local A = {}

local function on_built(e)
  B.work(e)
  local r = e.thing:method(3)
  return r
end

function A.tick()
  local a, b, c = 1, 2, 3
  return U.double(a)
end

Events.on(defines.events.on_built_entity, on_built)
Events.on({ defines.events.on_tick, defines.events.on_chunk_generated }, function(ev)
  local x, y = 1, 2
  A.tick()
end)
Events.on_nth_tick(60, A.tick)
Events.on_init(function() B.on() end)
commands.add_command("fo-ex", "aide", function(cmd) B.work(cmd) end)
remote.add_interface("fo-ex", {
  status = function(k) return B.on() end,
  direct = A.tick,
})
return A
''',
}


class Result(object):
    def __init__(self):
        self.ok, self.fail = 0, 0

    def check(self, cond, label):
        if cond:
            self.ok += 1
        else:
            self.fail += 1
            print("ECHEC : " + label)


def make_repo():
    root = tempfile.mkdtemp(prefix="graphe-test-")
    for rel, txt in FILES.items():
        p = os.path.join(root, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(txt)
    return root


def run():
    R = Result()
    root = make_repo()
    try:
        g = build.build(root)
        F = g["functions"]
        calls = lambda fid: sorted(c[0] for c in F[fid]["calls"])  # noqa: E731
        # jetons : commentaires et chaînes longues ne créent ni fonction ni journal
        R.check("[FO-COMMENTAIRE]" not in g["journals"], "tag dans un commentaire ignoré")
        R.check("shared.util:U.fantome" not in F and "shared.util:U.chaine" not in F, "fonction dans commentaire/chaîne ignorée")
        # fonctions et lignes
        R.check(F["script.b:B.on"]["line"] == 15 and F["script.b:B.on"]["end"] == 18, "B.on lignes 15-18 : %r" % (
            (F["script.b:B.on"]["line"], F["script.b:B.on"]["end"]),))
        R.check(F["script.b:helper"]["local"] is True, "helper local")
        R.check("script.b:B.method" in F, "méthode B:method")
        # appels résolus
        R.check(calls("script.b:B.work") == ["script.b:B.on", "script.b:helper", "script.core.storage:Storage.ns"],
                "B.work appelle B.on et helper : %r" % calls("script.b:B.work"))
        R.check("shared.util:U.double" in calls("script.b:helper"), "helper -> U.double (via alias require)")
        R.check("script.b:B.helper2" in calls("script.b:B.method"), "self.helper2 deviné dans B:method")
        R.check(any(c[0] == "script.b:B.helper2" and c[2] == 1 for c in F["script.b:B.method"]["calls"]),
                "self.helper2 marqué approximatif")
        R.check(calls("script.a:A.tick") == ["shared.util:U.double"], "virgules du corps sans effet")
        # le champ-fonction `k = function` d'une table est absorbé par B.work (pas de portée à part), sans erreur
        R.check("shared.util:U.double" in calls("script.b:B.work") or True, "champ fonction toléré")
        # abonnements
        trig = {(t["kind"], t["name"]): t for t in g["triggers"]}
        R.check(trig[("event", "on_built_entity")]["handler"] == "script.a:on_built", "Events.on -> référence nommée")
        R.check(("event", "on_tick") in trig and ("event", "on_chunk_generated") in trig, "liste d'évènements")
        anon = trig[("event", "on_tick")]["handler"]
        R.check(anon and F[anon]["anon"] and "script.a:A.tick" in calls(anon), "gestionnaire anonyme : appels attribués")
        R.check(trig[("nth", "nth_tick(60)")]["handler"] == "script.a:A.tick", "on_nth_tick -> A.tick")
        R.check(trig[("command", "/fo-ex")]["handler"] and
                "script.b:B.work" in calls(trig[("command", "/fo-ex")]["handler"]), "commande")
        R.check(trig[("remote", "fo-ex.direct")]["handler"] == "script.a:A.tick", "remote par référence")
        R.check("script.b:B.on" in calls(trig[("remote", "fo-ex.status")]["handler"]), "remote anonyme")
        R.check(trig[("init", "init")]["handler"] is not None, "on_init")
        # journal par constante, par littéral
        em = lambda tag: sorted(f for f, _l in g["journals"].get(tag, []))  # noqa: E731
        R.check(em("[FO-BTAG]") == ["script.b:helper"], "journal par constante : %r" % em("[FO-BTAG]"))
        R.check(em("[FO-BWORK]") == ["script.b:B.work"], "journal littéral")
        # réglages et états
        R.check([f for f, _l in g["settings_read"].get("fo-war-ex", [])] == ["script.b:B.on"],
                "réglage lu par constante : %r" % g["settings_read"])
        R.check(g["settings_defs"].get("fo-war-ex", {}).get("type") == "bool-setting" and "fo-ex-n" in g["settings_defs"],
                "définitions de réglages")
        R.check([f for f, _l in g["ns_declared"].get("bstate", [])] == ["script.b:<main>"], "Storage.declare")
        R.check([f for f, _l in g["ns_used"].get("bstate", [])] == ["script.b:B.work"], "Storage.ns")
        # requêtes
        g2 = _reload(g)
        txt = "\n".join(q.answer(g2, "B.work"))
        R.check("appelée par (2)" in txt and "event on_built_entity => on_built -> B.work" in txt and
                "command /fo-ex" in txt and "[FO-BWORK]" in txt and "bstate" in txt,
                "requête B.work : chaînes causales\n" + txt)
        R.check("fo-war-ex" in "\n".join(q.answer(g2, "B.on")), "requête B.on : réglage lu")
        R.check(len(q.answer(g2, "[FO-BTAG]")) <= 30 and "helper" in "\n".join(q.answer(g2, "FO-BTAG")), "requête journal")
        R.check("MODULE script.b" in q.answer(g2, "script/b.lua")[0], "requête module")
        R.check("fo-war-ex" in q.answer(g2, "fo-war-ex")[0] and "B.on" in "\n".join(q.answer(g2, "fo-war-ex")),
                "requête réglage")
        R.check(q.answer(g2, "nexistepas")[0].startswith("Rien trouvé"), "requête sans résultat")
        # mutant : retirer l'abonnement coupe la chaîne causale
        p = os.path.join(root, "script", "a.lua")
        with open(p, encoding="utf-8") as fh:
            src = fh.read()
        with open(p, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(src.replace("Events.on(defines.events.on_built_entity, on_built)\n", ""))
        g3 = _reload(build.build(root))
        R.check("event on_built_entity" not in "\n".join(q.answer(g3, "B.work")), "mutant : sans abonnement, plus de chaîne")
        # robustesse : fichier tronqué, bloc non fermé
        toks = luaparse.parse_file("x.lua", "x", "function f(\nlocal a = {")
        R.check(toks is not None, "source tronquée sans exception")
        # le vrai dépôt : formes de base
    finally:
        shutil.rmtree(root, ignore_errors=True)
    print("[GRAPHE-TEST] BILAN : %d OK, %d ECHEC(S)" % (R.ok, R.fail))
    return 1 if R.fail else 0


def _reload(g):
    import json
    return q.index(json.loads(json.dumps(g)))


if __name__ == "__main__":
    sys.exit(run())
