--[[
  Lot PERF3 : PHASE d'une voie de l'ordonnanceur (Scheduler.define_lane(..., phase)) et pensée de votre équipe déplacée de la phase 0
  (le tick de la première faction) à la phase 174, moteur simulé.
    1. une voie à phase φ : chaque id passe exactement toutes les P ticks, au tick % P = φ + créneau - 1 ; jamais deux passages
       dans un tick ; phase 0 = la roue d'avant ;
    2. PARTIE EXISTANTE (sauvegarde faite à la phase 0, rechargée avec le code à la phase 174 : M.load_mod garde global et le monde) :
       aucun passage sauté ni doublé : chaque fenêtre de 300 ticks porte exactement un passage, un seul intervalle diffère de 300
       (174 si le rechargement tombe avant la phase, 474 après), puis 300 exactement ; rechargement à plusieurs moments ;
    3. la vraie équipe du joueur (coffre d'équipe posé) : ses pensées tombent au tick % 300 = 174, jamais au tick % 300 = 0 ;
    4. mutant : une phase oubliée dans run_lane (la roue d'avant) est vue.
  Lancement : lua5.2 tests/perf3_phase_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

---------------------------------------------------------------------------------------------------
section("1. voie à phase : période exacte, créneau décalé")
for _, case in ipairs({ { P = 300, phase = 174 }, { P = 300, phase = 0 }, { P = 7, phase = 3 }, { P = 60, phase = 59 } }) do
  M.new_game({})
  local Scheduler = require("script.core.scheduler")
  local visits, double = {}, false
  local seen = {}
  Scheduler.define_lane("t-phase", case.P, function(id, tick)
    if seen[id] == tick then double = true end
    seen[id] = tick
    visits[id] = visits[id] or {}
    visits[id][#visits[id] + 1] = tick
  end, case.phase)
  for id = 1, 5 do Scheduler.add("t-phase", id) end
  M.run_ticks(case.P * 6 + 17)
  local exact, phase_ok = true, true
  for id = 1, 5 do
    local v = visits[id] or {}
    for i = 2, #v do if v[i] - v[i - 1] ~= case.P then exact = false end end
    local slot = (id - 1) % case.P -- créneaux attribués à tour de rôle : id k au créneau k
    for _, t in ipairs(v) do if (t - case.phase) % case.P ~= slot then phase_ok = false end end
    if #v < 6 then exact = false end
  end
  local tag = string.format(" [P=%d, phase %d]", case.P, case.phase)
  check(exact and not double, "période exacte, aucun double passage" .. tag)
  check(phase_ok, "chaque id au tick % P = phase + créneau - 1" .. tag)
end

---------------------------------------------------------------------------------------------------
section("2. partie existante : phase 0 sauvegardée, rechargée à la phase 174")
for _, reload_after in ipairs({ 37, 173, 174, 175, 250, 299 }) do
  M.new_game({})
  local Scheduler = require("script.core.scheduler")
  local visits, double, last = {}, false, nil
  local function handler(_, tick)
    if last == tick then double = true end
    last = tick
    visits[#visits + 1] = tick
  end
  Scheduler.define_lane("t-sauve", 300, handler, 0)
  Scheduler.add("t-sauve", 1)
  M.run_ticks(900) -- passages aux ticks % 300 = 0 (code d'avant)
  local t_last_old = visits[#visits]
  M.run_ticks(reload_after - (game.tick - t_last_old))
  -- « chargement » avec le nouveau code : modules rechargés, global et monde gardés ; la voie est redéfinie à la phase 174
  M.load_mod()
  Scheduler = require("script.core.scheduler")
  Scheduler.define_lane("t-sauve", 300, handler, 174)
  M.run_ticks(1500)
  local odd, others = 0, true
  for i = 2, #visits do
    local d = visits[i] - visits[i - 1]
    if d ~= 300 then
      odd = odd + 1
      if not (d == 174 or d == 474) then others = false end
    end
  end
  -- chaque fenêtre de 300 ticks qui suit le dernier passage de l'ancien code porte au moins un passage et au plus deux (transition)
  local windows_ok = true
  for w0 = t_last_old, visits[#visits] - 300, 300 do
    local n = 0
    for _, t in ipairs(visits) do if t >= w0 and t < w0 + 300 then n = n + 1 end end
    if n < 1 or n > 2 then windows_ok = false end
  end
  local after = {}
  for _, t in ipairs(visits) do if t > t_last_old then after[#after + 1] = t % 300 end end
  local all174 = #after >= 4
  for _, r in ipairs(after) do if r ~= 174 then all174 = false end end
  local tag = string.format(" [rechargement %d ticks après le dernier passage]", reload_after)
  check(not double, "jamais deux passages dans un tick" .. tag)
  check(odd == 1 and others, "un seul intervalle différent de 300, valant 174 ou 474 (" .. odd .. ")" .. tag)
  check(windows_ok, "aucune fenêtre de 300 ticks sans passage (rien de sauté)" .. tag)
  check(all174, "ensuite, chaque passage au tick % 300 = 174" .. tag)
end

---------------------------------------------------------------------------------------------------
section("3. votre équipe : pensées au tick % 300 = 174")
local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end
local function team_thinks(mutant)
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  if mutant then mutant() end
  local Team = require("script.team.team")
  local real = Team.think
  local ticks = {}
  Team.think = function(f, surface, tick)
    if f.is_player then ticks[#ticks + 1] = tick end
    return real(f, surface, tick)
  end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "coal", 200 }, { "pistol", 2 }, { "firearm-magazine", 40 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(3 * 3600)
  Team.think = real
  return ticks
end
local ticks = team_thinks()
local at174, at0 = 0, 0
for _, t in ipairs(ticks) do
  if t % 300 == 174 then at174 = at174 + 1 end
  if t % 300 == 0 then at0 = at0 + 1 end
end
check(#ticks >= 30 and at174 == #ticks and at0 == 0, string.format("%d pensées de votre équipe, %d au tick %% 300 = 174, %d au tick %% 300 = 0",
  #ticks, at174, at0))

---------------------------------------------------------------------------------------------------
section("4. mutant : phase ignorée par run_lane (la roue d'avant)")
local SRC = io.open("script/core/scheduler.lua"):read("*a")
local a, b = SRC:find("local s = (tick - cfg.phase) % p + 1", 1, true)
check(a ~= nil, "texte du mutant trouvé")
-- (le mutant se charge à la place du module, puis le mod est rechargé dessus)
local mutated = SRC:sub(1, a - 1) .. "local s = tick % p + 1" .. SRC:sub(b + 1)
local function team_thinks_mutant()
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  for name in pairs(package.loaded) do
    if name:match("^script%.") or name:match("^shared%.") then package.loaded[name] = nil end
  end
  package.preload["script.core.scheduler"] = function() return assert(load(mutated, "=scheduler(mutant)"))() end
  M.load_mod()
  package.preload["script.core.scheduler"] = nil
  M.world().on_init()
  local Team = require("script.team.team")
  local real = Team.think
  local out = {}
  Team.think = function(f, surface, tick)
    if f.is_player then out[#out + 1] = tick end
    return real(f, surface, tick)
  end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  chest.insert({ name = "iron-plate", count = 400 })
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(3600)
  Team.think = real
  return out
end
local mt = team_thinks_mutant()
local m174 = 0
for _, t in ipairs(mt) do if t % 300 == 174 then m174 = m174 + 1 end end
check(#mt > 0 and m174 == 0, "le mutant est vu : " .. #mt .. " pensées, " .. m174 .. " au tick % 300 = 174")

print(string.format("[PERF3-PHASE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
