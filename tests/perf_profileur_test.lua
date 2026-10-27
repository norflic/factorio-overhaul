--[[
  Lot PERF, correction après revue (27/10) : banc HORS JEU des portées attribuées APRÈS COUP (Profiler.fmark,
  Profiler.fcredit) dans la prise de tâche d'un PNJ au repos (script/team/worker.lua, état « idle »), moteur simulé.
  La revue demandait de compter les passages de la porte d'IA3-k (acceptés ET refusés) et de mesurer à part la branche
  du refus, au lieu de citer comme coût du refus la somme board:claim + worker:program + ia3k:gate de TOUTES les prises.
    - comptes cohérents : chaque passage de la porte finit en « idle:refus » ou en « idle:depart » ; gate:refus = idle:refus ;
    - la porte refuse bien en jeu simulé (morts marquées près de la moitié des gisements) et accepte ailleurs ;
    - mode fin éteint : aucune portée « idle:* » ni « gate:* » (rien n'est créé) ;
    - les mesures ne décident de rien : global (hors espace « prof ») identique profileur éteint, ordinaire et fin ;
    - mutant : une portée créditée au mauvais seau (refus compté comme départ) est vue par le contrôle de cohérence.
  Lancement : lua5.2 tests/perf_profileur_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local TICKS = 3 * 3600

--- Une partie de votre équipe (coffre garni, cerveau libre), morts marquées près d'un gisement sur deux (la porte d'IA3-k
--- refuse ces tournées pendant l'heure qui suit). mode : nil (profileur éteint), "ordinaire", "fin".
--- mutant(Profiler) : facultatif, appelé après le chargement du mod (remplace une fonction du profileur).
local function run(mode, mutant)
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  if W().remote["fo-ia3f"] then remote.call("fo-ia3f", "set_fog", false) end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "coal", 200 }, { "pistol", 2 }, { "firearm-magazine", 40 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local Profiler = require("script.core.profiler")
  if mutant then mutant(Profiler) end
  if mode then remote.call("factorio-overhaul", "profiler", true, mode == "fin") end
  for i, p in ipairs(patches()) do
    if i % 2 == 0 then
      remote.call("fo-ia3k", "death", "player", p.x, p.y)
      remote.call("fo-ia3k", "death", "player", p.x + 2, p.y)
    end
  end
  M.run_ticks(TICKS)
  local counts, names = {}, {}
  local lines = Profiler.report(game.tick)
  for _, l in ipairs(lines) do
    names[#names + 1] = l[3]
    if l[8] == " | passages " then counts[l[3]] = tonumber(l[9]) end
  end
  local prof = global.fo.prof
  global.fo.prof = nil
  local ser = M.serialize(global)
  global.fo.prof = prof
  return counts, ser, names
end

local function n(c, k) return c[k] or 0 end
local function coherent(c)
  return n(c, "gate:accepte") + n(c, "gate:refus") == n(c, "idle:refus") + n(c, "idle:depart")
    and n(c, "gate:refus") == n(c, "idle:refus")
end

---------------------------------------------------------------------------------------------------
section("Mode fin : passages comptés par issue, cohérents")
local cf, sf = run("fin")
print(string.format("  passages : sans-tache %d, sans-programme %d, refus %d, depart %d ; porte acceptee %d, refusee %d",
  n(cf, "idle:sans-tache"), n(cf, "idle:sans-programme"), n(cf, "idle:refus"), n(cf, "idle:depart"),
  n(cf, "gate:accepte"), n(cf, "gate:refus")))
check(coherent(cf), "chaque passage de la porte finit en refus ou en départ, gate:refus = idle:refus")
check(n(cf, "gate:refus") >= 1, "la porte refuse (morts marquées) : " .. n(cf, "gate:refus") .. " refus")
check(n(cf, "gate:accepte") >= 1 and n(cf, "idle:depart") >= 1, "la porte accepte ailleurs : " .. n(cf, "gate:accepte") .. " départs")
check(n(cf, "idle:sans-tache") >= 1, "PNJ sans tâche comptés : " .. n(cf, "idle:sans-tache"))

---------------------------------------------------------------------------------------------------
section("Mode fin éteint : rien n'est créé")
local co, so, names_o = run("ordinaire")
local any = false
for _, k in ipairs(names_o) do if k:match("^idle:") or k:match("^gate:") then any = true end end
check(not any and next(co) == nil, "profileur ordinaire : aucune portée idle:* ni gate:*, aucun passage compté")
check(#names_o > 0, "profileur ordinaire : ses portées habituelles sont là (" .. #names_o .. ")")

---------------------------------------------------------------------------------------------------
section("Les mesures ne décident de rien")
local _, s0 = run(nil)
check(s0 == so, "global identique profileur éteint et ordinaire")
check(s0 == sf, "global identique profileur éteint et fin")

---------------------------------------------------------------------------------------------------
section("Mutant : refus crédité au départ")
local cm = run("fin", function(P)
  local real = P.fcredit
  P.fcredit = function(slot, name)
    if name == "idle:refus" then name = "idle:depart" end
    return real(slot, name)
  end
end)
check(not coherent(cm), "le contrôle de cohérence voit le mutant")

print(string.format("[PERF-PROFILEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
