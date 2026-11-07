-- Banc hors jeu de scenarios/x10_common.lua (moteur simulé minimal, lecture seule) : chaque classe fige ce qu'elle doit et
-- rien d'autre, la revue refige le neuf, la fin compte juste, le témoin ne touche à rien.
-- usage (depuis la racine du mod) : lua5.2 tools/autotest/tests/x10_common_test.lua   (attendu : [X10-COMMON] BILAN : 18 OK, 0 ECHEC(S))
package.path = "./tools/autotest/fo-autotest/?.lua;./?.lua;" .. package.path
local OK, KO = 0, 0
local function check(c, msg) if c then OK = OK + 1 else KO = KO + 1; print("ECHEC " .. msg) end end

local function world()
  local ents = {}
  local function add(force, type, name)
    local e = { valid = true, active = true, destructible = true, type = type, name = name, force = { name = force } }
    ents[#ents + 1] = e
    return e
  end
  for _, f in ipairs({ "fo-amber", "fo-azure" }) do
    add(f, "inserter", "inserter"); add(f, "assembling-machine", "assembling-machine-2"); add(f, "mining-drill", "burner-mining-drill")
    add(f, "ammo-turret", "fo-lvl-gun-2"); add(f, "character", "fo-companion"); add(f, "unit", f .. "-rifleman")
    add(f, "transport-belt", "transport-belt"); add(f, "container", "iron-chest")
  end
  add("player", "character", "fo-companion"); add("player", "unit", "fo-player-rifleman"); add("player", "inserter", "inserter")
  add("player", "character", "character")
  add("enemy", "unit", "small-biter"); add("enemy", "unit-spawner", "biter-spawner")
  -- fantôme : `active` se lit vrai mais son écriture lève une erreur (cas d'un type qui refuse) : doit compter un refus
  local ghost = setmetatable({ valid = true, destructible = true, type = "entity-ghost", name = "entity-ghost", force = { name = "fo-amber" } },
    { __index = function(t, k) if k == "active" then return true end end,
      __newindex = function(t, k, v) if k == "active" then error("pas de active sur un fantome") end rawset(t, k, v) end })
  ents[#ents + 1] = ghost
  local surface = {}
  function surface.find_entities_filtered(f)
    local out = {}
    local types
    if type(f.type) == "table" then types = {} for _, t in ipairs(f.type) do types[t] = true end
    elseif f.type then types = { [f.type] = true } end
    for _, e in ipairs(ents) do
      if e.valid and (not f.force or e.force.name == f.force) and (not types or types[e.type]) and (not f.name or e.name == f.name) then
        out[#out + 1] = e
      end
    end
    return out
  end
  function surface.count_entities_filtered(f) return #surface.find_entities_filtered(f) end
  function surface.get_chunks() local i = 0 return function() i = i + 1 if i <= 3 then return { x = i, y = 0 } end end end
  function surface.get_total_pollution() return 1234 end
  local forces = { ["fo-amber"] = {}, ["fo-azure"] = {}, player = {}, enemy = { evolution_factor = 0.5 }, neutral = {} }
  _G.game = { tick = 919256, forces = forces, connected_players = {}, speed = 1 }
  _G.script = { active_mods = { base = "1.1.91", ["factorio-overhaul"] = "0.6.59" } }
  _G.log = function(s) _G.LOGS[#_G.LOGS + 1] = s end
  return ents, add, surface
end

local function ctx_for(surface)
  local st, res = {}, { ok = 0, fail = 0 }
  local ctx = {}
  function ctx.log(m) log("[T] " .. m) end
  function ctx.surface() return surface end
  function ctx.call(fn) if fn == "points_of_interest" then return { factions = { 1, 2 } } end end
  function ctx.state() return st end
  function ctx.check(c, msg) if c then res.ok = res.ok + 1 else res.fail = res.fail + 1 end end
  return ctx, res
end

local function run(classe, mutate)
  _G.LOGS = {}
  package.loaded["scenarios/x10_common"] = nil
  local ents, add, surface = world()
  local S = require("scenarios/x10_common")("x10-test", classe)
  local ctx, res = ctx_for(surface)
  S.init(ctx)
  local neuf = add("fo-amber", "inserter", "inserter") -- posé après le départ
  if mutate then mutate(ents) end
  for t = game.tick + 1, S.check_tick do if t == game.tick + 1800 or t == game.tick + 3900 then S.tick(ctx, { tick = t }) end end
  S.finish(ctx)
  return ents, res, neuf
end

local function act(ents, pred) local n = 0 for _, e in ipairs(ents) do if e.valid and e.active and pred(e) then n = n + 1 end end return n end

-- témoin : rien ne bouge
local ents, res = run("temoin")
check(act(ents, function() return true end) == #ents, "temoin : toutes actives")
check(res.fail == 0, "temoin : BILAN sans echec")
check(LOGS[1]:find("^%[FO%-PERF4%] debut tick 919256") ~= nil, "ligne d'alignement perf3 en tete")

-- usines : bras, machines, foreuses des fo-* figés ; tourelles, PNJ, unités, tapis, coffres, force player intacts
ents, res, neuf = run("usines")
check(act(ents, function(e) return e.force.name:sub(1, 3) == "fo-" and (e.type == "inserter" or e.type == "assembling-machine" or e.type == "mining-drill") end) == 0, "usines : production des factions figee")
check(act(ents, function(e) return e.type == "ammo-turret" or e.type == "character" or e.type == "unit" or e.type == "transport-belt" or e.type == "container" end) == 2 * 5 + 3 + 1, "usines : le reste actif")
check(act(ents, function(e) return e.force.name == "player" end) == 4, "usines : force player intacte")
check(not neuf.active, "usines : bras pose apres le depart refige par la revue")
check(res.fail == 0, "usines : BILAN sans echec")

-- pnj : tous les fo-companion figés et indestructibles, rien d'autre
ents, res = run("pnj")
check(act(ents, function(e) return e.name == "fo-companion" end) == 0, "pnj : tous figes")
local indes = true
for _, e in ipairs(ents) do if e.name == "fo-companion" and e.destructible then indes = false end end
check(indes, "pnj : indestructibles (F321)")
check(act(ents, function(e) return e.name == "character" end) == 1, "pnj : le personnage du joueur reste actif")
check(act(ents, function(e) return e.type == "inserter" end) == 4, "pnj : bras intacts (dont le neuf)")

-- tout : forces fo-*, PNJ de la force player, unités de la force player ; le bras et le personnage du joueur intacts
ents, res = run("tout")
check(act(ents, function(e) return e.force.name:sub(1, 3) == "fo-" and e.type ~= "entity-ghost" end) == 0, "tout : forces fo-* figees")
check(table.concat(LOGS, " | "):find("1 refus", 1, true) ~= nil, "tout : le fantome compte un refus")
check(act(ents, function(e) return e.force.name == "player" end) == 2, "tout : force player : bras et personnage du joueur seuls actifs")
check(act(ents, function(e) return e.force.name == "enemy" end) == 2, "tout : biters intacts")
check(res.fail == 0, "tout : BILAN sans echec (fantome refuse sans erreur)")

-- mutant : une classe réactivée en masse après la dernière revue doit faire échouer le contrôle de fin
_G.LOGS = {}
package.loaded["scenarios/x10_common"] = nil
local e2, add2, surface2 = world()
for _ = 1, 200 do add2("fo-azure", "inserter", "inserter") end -- taille réaliste : le seuil de 5 % ne doit pas tout absoudre
local S2 = require("scenarios/x10_common")("x10-test", "usines")
local ctx2, res2 = ctx_for(surface2)
S2.init(ctx2)
for _, e in ipairs(e2) do if e.type == "inserter" then e.active = true end end
S2.finish(ctx2)
check(res2.fail == 1, "mutant : classe reactivee vue a la fin")

print(string.format("[X10-COMMON] BILAN : %d OK, %d ECHEC(S)", OK, KO))
os.exit(KO == 0 and 0 or 1)
