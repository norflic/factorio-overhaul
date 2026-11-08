--[[
  Lot ÉTALEMENT (5/11) : pensées des factions ESPACÉES sur la période (script/faction/commander.lua, Commander.spread ;
  script/core/scheduler.lua, Scheduler.add_at). Avant : 4 ticks consécutifs (phases 0 à 3 modulo 300), un bloc de 0,22 à 0,5 s
  toutes les 300 ticks chez le DC (mesure de perf3) ; après : phases 7, 82, 157 et 232.
    1. Scheduler.add_at : place, déplacement, jamais deux passages dans un tick, période exacte après le déplacement, retrait ;
       mutants.
    2. Commander.slot_for : phases distinctes, espacées de P / n, hors des multiples de 5, des restes 0 à 3 de 30, loin de 174
       (votre équipe), pour n = 2 à F.MAX_FACTIONS.
    3. Partie au moteur simulé (4 factions) : chaque faction pense une fois par période, à sa phase, jamais deux le même tick.
    4. Migration d'une partie d'avant (factions à la suite) : replacées au changement de configuration, journal [FO-ETALEMENT] ;
       pendant le passage, jamais deux pensées d'une faction dans un tick, aucun écart au-delà de 2 périodes ; puis période exacte.
  Lancement : lua5.2 tests/etalement_phases_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local M = require("tests.mock_engine")
M.new_game({ patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0 })
local W = M.world()
local Scheduler = require("script.core.scheduler")
local Commander = require("script.faction.commander")
local State = require("script.faction.state")
local F = require("shared.faction.config")

---------------------------------------------------------------------------------------------------
section("1. Scheduler.add_at : place, déplacement, période exacte")
---------------------------------------------------------------------------------------------------
do
  local P = 10
  local passes_of = {}
  local lane = "t-etalement"
  Scheduler.define_lane(lane, P, function(id, tick)
    passes_of[id] = passes_of[id] or {}
    local l = passes_of[id]
    l[#l + 1] = tick
  end)
  for id = 1, 4 do Scheduler.add(lane, id) end
  check(Scheduler.slot(lane, 1) == 1 and Scheduler.slot(lane, 4) == 4, "ajout tournant : créneaux 1 à 4")
  check(Scheduler.period(lane) == P, "Scheduler.period")
  M.run_ticks(23) -- au milieu d'un cycle
  local t_move = game.tick
  Scheduler.add_at(lane, 2, 8)
  Scheduler.add_at(lane, 3, 3) -- déjà à sa place : sans effet
  Scheduler.add_at(lane, 4, 14) -- ramené dans la période : 4
  Scheduler.add_at(lane, 9, 6) -- absent : ajouté
  check(Scheduler.count(lane) == 5, "compte : 4 + 1 ajouté par add_at (" .. Scheduler.count(lane) .. ")")
  check(Scheduler.slot(lane, 2) == 8 and Scheduler.slot(lane, 4) == 4 and Scheduler.slot(lane, 9) == 6, "créneaux après add_at")
  M.run_ticks(60)
  local ok_tick, ok_period, ok_phase = true, true, true
  for _, id in ipairs({ 1, 2, 3, 4, 9 }) do
    local l = passes_of[id] or {}
    local after = {}
    for _, t in ipairs(l) do if t > t_move then after[#after + 1] = t end end
    for k = 2, #after do
      if after[k] == after[k - 1] then ok_tick = false end
      if k >= 3 and after[k] - after[k - 1] ~= P then ok_period = false end
    end
    local s = Scheduler.slot(lane, id)
    for _, t in ipairs(after) do if (t % P) + 1 ~= s then ok_phase = false end end
    check(#after >= 5, "id " .. id .. " passe après le déplacement (" .. #after .. " fois)")
  end
  check(ok_tick, "jamais deux passages d'un id dans un tick")
  check(ok_period, "période exacte après le premier passage qui suit le déplacement")
  check(ok_phase, "chaque passage au créneau de l'id")
  Scheduler.remove(lane, 2)
  local n2 = #(passes_of[2] or {})
  M.run_ticks(20)
  check(#passes_of[2] == n2, "retrait après add_at : plus de passage")
  -- déplacé puis ramené (entrée périmée et entrée neuve dans le même seau) : un seul passage par tick
  Scheduler.add_at(lane, 1, 5)
  Scheduler.add_at(lane, 1, 1)
  local before = #passes_of[1]
  M.run_ticks(30)
  local l = passes_of[1]
  local dup = false
  for k = before + 2, #l do if l[k] == l[k - 1] then dup = true end end
  check(not dup and #l - before == 3, "aller-retour dans un seau : un passage par période (" .. (#l - before) .. " en 30 ticks)")
end

---------------------------------------------------------------------------------------------------
section("2. Commander.slot_for : phases espacées, hors des rythmes des autres passes")
---------------------------------------------------------------------------------------------------
do
  local P = F.defaults.think_period
  check(P == 300, "période des pensées de faction : 300")
  local ok = true
  for n = 2, F.MAX_FACTIONS do
    local seen, phases = {}, {}
    for i = 1, n do
      local ph = Commander.slot_for(i, n, P) - 1
      phases[#phases + 1] = ph
      if seen[ph] then ok = false print("  phase en double, n = " .. n) end
      seen[ph] = true
      if ph % 5 == 0 then ok = false print("  multiple de 5 : " .. ph) end
      if ph % 30 <= 3 then ok = false print("  reste 0 à 3 de 30 : " .. ph) end
      if math.abs(ph - 174) < 10 then ok = false print("  trop près de 174 : " .. ph) end
    end
    table.sort(phases)
    for k = 2, #phases do
      local gap = phases[k] - phases[k - 1]
      if math.abs(gap - P / n) > 1 then ok = false print(string.format("  écart %d (n = %d)", gap, n)) end
    end
    if n == 4 then check(table.concat(phases, ",") == "7,82,157,232", "4 factions : phases 7, 82, 157, 232 (" .. table.concat(phases, ",") .. ")") end
  end
  check(ok, "phases distinctes, espacées de P / n, hors des multiples de 5 et des restes 0 à 3 de 30, à 10 ticks au moins de 174")
  -- mutant : sans PHASE0, les phases tombent sur des multiples de 5 (passes du plan directeur)
  local save = Commander.PHASE0
  Commander.PHASE0 = 0
  check(Commander.slot_for(1, 4, 300) - 1 == 0, "mutant PHASE0 = 0 : phase 0, refusé par la règle des multiples de 5")
  Commander.PHASE0 = save
end

---------------------------------------------------------------------------------------------------
section("3. Partie à 4 factions : une pensée par faction et par période, à sa phase, jamais deux au même tick")
---------------------------------------------------------------------------------------------------
local function watch(ticks)
  local war = State.war()
  local by = {}
  local same_tick = 0
  for _ = 1, ticks do
    M.run_ticks(1)
    local t = game.tick
    local n = 0
    for i, f in ipairs(war.factions) do
      if f.last_think == t then
        n = n + 1
        by[i] = by[i] or {}
        by[i][#by[i] + 1] = t
      end
    end
    if n > 1 then same_tick = same_tick + 1 end
  end
  return by, same_tick
end
assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
remote.call("factorio-overhaul", "war_fund", 1000)
do
  local war = State.war()
  check(#war.factions == 4, "4 factions")
  for i = 1, 4 do
    check(Scheduler.slot(Commander.LANE, i) == Commander.slot_for(i, 4, 300), "faction " .. i .. " à son créneau dès le lancement")
  end
  local by, same = watch(3000)
  check(same == 0, "jamais deux pensées de faction au même tick (" .. same .. ")")
  for i = 1, 4 do
    local l = by[i] or {}
    local ok = #l >= 9
    for k = 2, #l do if l[k] - l[k - 1] ~= 300 then ok = false end end
    for _, t in ipairs(l) do if t % 300 ~= Commander.slot_for(i, 4, 300) - 1 then ok = false end end
    check(ok, string.format("faction %d : %d pensées, toutes les 300 ticks, à la phase %d", i, #l, Commander.slot_for(i, 4, 300) - 1))
  end
end

---------------------------------------------------------------------------------------------------
section("4. Migration d'une partie d'avant : factions à la suite, replacées au changement de configuration")
---------------------------------------------------------------------------------------------------
do
  local war = State.war()
  -- état d'une sauvegarde 0.6.53 : créneaux consécutifs (ajout tournant)
  for i = 1, 4 do Scheduler.add_at(Commander.LANE, i, ((game.tick + 40 + i) % 300) + 1) end
  local by0, same0 = watch(600)
  check(same0 == 0, "avant migration, une pensée par tick")
  local old_ph = {}
  for i = 1, 4 do old_ph[i] = (Scheduler.slot(Commander.LANE, i) - 1) end
  check(old_ph[2] == old_ph[1] + 1 and old_ph[4] == old_ph[3] + 1, "avant : phases consécutives (" .. table.concat(old_ph, ",") .. ")")
  local nlog = #W.logs
  local last = {}
  for i = 1, 4 do last[i] = war.factions[i].last_think end
  W.on_config({ mod_changes = {}, mod_startup_settings_changed = false, migration_applied = false })
  local logged = false
  for k = nlog + 1, #W.logs do if tostring(W.logs[k]):find("[FO-ETALEMENT]", 1, true) then logged = true end end
  check(logged, "journal [FO-ETALEMENT] de la migration")
  for i = 1, 4 do
    check(Scheduler.slot(Commander.LANE, i) == Commander.slot_for(i, 4, 300), "faction " .. i .. " replacée")
  end
  local by, same = watch(1500)
  check(same == 0, "après migration, jamais deux pensées de faction au même tick")
  for i = 1, 4 do
    local l = by[i] or {}
    local gaps_ok = #l >= 4 and l[1] - last[i] >= 1 and l[1] - last[i] <= 600
    for k = 2, #l do if l[k] - l[k - 1] ~= 300 then gaps_ok = false end end
    check(gaps_ok, string.format("faction %d : premier écart %d ticks (1 à 600), puis 300 exactement", i, (l[1] or 0) - last[i]))
  end
  -- deuxième changement de configuration : rien ne bouge, pas de journal
  local nlog2 = #W.logs
  W.on_config({ mod_changes = {} })
  local relog = false
  for k = nlog2 + 1, #W.logs do if tostring(W.logs[k]):find("[FO-ETALEMENT]", 1, true) then relog = true end end
  check(not relog, "migration jouée une seule fois (déjà en place : sans journal)")
  check(pcall(M.serialize, global), "global sérialisable")
end

print(string.format("[ETALEMENT-PHASES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
