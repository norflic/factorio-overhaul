--[[
  Lot CHAMP-TRANCHES (7/11) : registre des travaux du plan de champ (script/team/champ_jobs.lua). Critères :
  fo-logs/2026-11-07_CHAMP-TRANCHES/CRITERES.md (T1 à T4). Moteur simulé, guerre de 2 factions, corpus de champ3 (tests/champ_formes.lua)
  et son sérialiseur (tests/champ_plan_serial.lua).
    T1  plan rendu par le registre = Ch.plan d'un bloc sur une copie de la même spec, pour chaque forme ; livraison dans l'ordre d'arrivée ;
    T2  sauvegarde et chargement (copie de global) à CHAQUE tick : mêmes plans, mêmes ticks de livraison ;
    T3  pas borné, en INSTRUCTIONS Lua (debug.sethook) : pire tick de la voie sous 1 000 000 ;
    T4  ménage : résultat non repris jeté après Jobs.TTL (mutant « TTL ignoré » refusé), équipe disparue, changement de configuration ;
        une ligne [FO-CHAMP-TRAVAUX] chaque fois.
  Usage : lua5.2 tests/champ_jobs_test.lua [--court]   (--court : 3 formes, sans le géant)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local Fm = require("tests.champ_formes")
local Sr = require("tests.champ_plan_serial")

local short = arg[1] == "--court"
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local QUICK = { ["disque r30"] = true, ["r30 + lacs aux deux bouts"] = true, ["joueur 271828182"] = true }
local cases = {}
for _, cs in ipairs(Fm.corpus()) do
  if QUICK[cs.name] or (not short) then cases[#cases + 1] = cs end
end

local function new_game()
  M.new_game({ patches = { { x = 0, y = 60, name = "iron-ore" }, { x = 0, y = -60, name = "coal" } }, p_busy = 0, p_nopath = 0, p_lost = 0 })
  assert(remote.call("factorio-overhaul", "war_start", 2, 100, nil, 320) == true)
  M.run_ticks(30)
  local State = require("script.faction.state")
  local ids = State.alive()
  return State.faction(ids[1]), State.faction(ids[2])
end

local function restore(copy)
  for k in pairs(global) do global[k] = nil end
  local c = M.deepcopy_global(copy)
  for k, v in pairs(c) do global[k] = v end
end

local Ch = require("shared.team.champ")
local REF = {}
for _, cs in ipairs(cases) do REF[cs.name] = Sr.print(Ch.plan(cs.spec())) end

--- Une partie : tous les travaux demandés au même tick, repris dès qu'ils sont prêts (poll à chaque tick). Rend { [nom] = { h, tick } },
--- l'ordre de livraison, le pire tick de la voie en instructions, le nombre de ticks.
local function play(reload, f_override)
  local f1 = new_game()
  local f = f_override or f1
  local Jobs = require("script.team.champ_jobs")
  local o_tick = Jobs.tick
  local worst, cur = 0, 0
  Jobs.tick = function(tick)
    cur = 0
    debug.sethook(function() cur = cur + 1000 end, "", 1000)
    o_tick(tick)
    debug.sethook()
    if cur > worst then worst = cur end
  end
  local pending = {}
  for _, cs in ipairs(cases) do
    local rec, why = Jobs.get(f, "t:" .. cs.name, "frame", function() return cs.spec(), { tag = cs.name }, {} end)
    assert(rec == nil and why == "calcul", "premier appel : calcul attendu")
    pending[#pending + 1] = cs.name
  end
  local got, order = {}, {}
  local t0, n = game.tick, 0
  while #pending > 0 and n < 40000 do
    M.run_ticks(1)
    n = n + 1
    if reload then restore(M.deepcopy_global(global)) end
    local still = {}
    for _, name in ipairs(pending) do
      local rec = Jobs.get(f, "t:" .. name, "frame", function() error("travail perdu : " .. name) end)
      if rec then
        got[name] = { h = Sr.print(rec.p, rec.why), tick = game.tick - t0, tag = rec.names and rec.names.tag }
        order[#order + 1] = name
      else
        still[#still + 1] = name
      end
    end
    pending = still
  end
  Jobs.tick = o_tick
  return got, order, worst, n
end

section("T1. Plan du registre = Ch.plan d'un bloc (" .. #cases .. " forme(s)) ; ordre d'arrivée")
local got, order, worst, n = play(false)
local same, fifo = 0, true
for i, cs in ipairs(cases) do
  local g = got[cs.name]
  if g and g.h == REF[cs.name] and g.tag == cs.name then same = same + 1 else print("  diff : " .. cs.name .. " " .. tostring(g and g.h) .. " / " .. tostring(REF[cs.name])) end
  if order[i] ~= cs.name then fifo = false end
end
print(string.format("  %d plan(s) identiques sur %d, livrés en %d tick(s) ; pire tick de la voie %d instructions", same, #cases, n, worst))
check(same == #cases, "chaque plan livré = Ch.plan d'un bloc sur la même spec")
check(fifo, "livraison dans l'ordre d'arrivée")

section("T3. Pas borné, en instructions Lua")
check(worst > 0 and worst <= 1000000, string.format("pire tick de la voie : %d instructions (au plus 1 000 000)", worst))

section("T2. Sauvegarde et chargement à chaque tick")
do
  local saved = cases
  if not short then
    cases = {}
    for _, cs in ipairs(saved) do if QUICK[cs.name] then cases[#cases + 1] = cs end end
  end
  local g1 = play(false)
  local g2, o2, _, n2 = play(true)
  local ok = true
  for _, cs in ipairs(cases) do
    if not (g1[cs.name] and g2[cs.name] and g1[cs.name].h == g2[cs.name].h and g1[cs.name].tick == g2[cs.name].tick) then ok = false end
  end
  print(string.format("  %d forme(s), %d tick(s), %d chargement(s)", #cases, n2, n2))
  check(ok, "mêmes plans aux mêmes ticks avec un chargement à chaque tick")
  cases = saved
end

section("T4. Ménage : TTL, équipe disparue, changement de configuration")
local function ttl_run(ttl)
  local f1 = new_game()
  local Jobs = require("script.team.champ_jobs")
  local o_ttl = Jobs.TTL
  Jobs.TTL = ttl
  local W = M.world()
  local log0 = #W.logs
  local cs = cases[1]
  Jobs.get(f1, "ttl", "frame", function() return cs.spec(), {}, {} end)
  local ready_at
  for _ = 1, 20000 do
    M.run_ticks(1)
    local st = Jobs.state()
    if st.ready > 0 and not ready_at then ready_at = game.tick end
    if ready_at and game.tick - ready_at > 300 then break end
  end
  local st = Jobs.state()
  local lines = 0
  for i = log0 + 1, #W.logs do if tostring(W.logs[i]):find("[FO-CHAMP-TRAVAUX]", 1, true) and tostring(W.logs[i]):find("non repris", 1, true) then lines = lines + 1 end end
  Jobs.TTL = o_ttl
  return st.stats.expired, st.ready, lines, Jobs, f1
end
local function ttl_ok(expired, ready, lines) return expired == 1 and ready == 0 and lines == 1 end
local e1, r1, l1 = ttl_run(200)
check(ttl_ok(e1, r1, l1), string.format("résultat non repris jeté après le TTL, une ligne au journal (jetés %d, prêts %d, lignes %d)", e1, r1, l1))
local e2, r2, l2 = ttl_run(1e9)
check(not ttl_ok(e2, r2, l2), "mutant « TTL ignoré » refusé (le résultat reste)")
do
  local f1, f2 = new_game()
  local Jobs = require("script.team.champ_jobs")
  local W = M.world()
  local log0 = #W.logs
  Jobs.get(f2, "orph", "frame", function() return cases[1].spec(), {}, {} end)
  f2.eliminated = true
  M.run_ticks(2)
  local st = Jobs.state()
  local lines = 0
  for i = log0 + 1, #W.logs do if tostring(W.logs[i]):find("equipe disparue", 1, true) then lines = lines + 1 end end
  check(st.stats.orphans == 1 and st.queued == 0 and lines == 1, string.format("équipe disparue : travail jeté, une ligne (jetés %d, file %d, lignes %d)", st.stats.orphans, st.queued, lines))
  f2.eliminated = false
  Jobs.get(f1, "cfg1", "frame", function() return cases[1].spec(), {}, {} end)
  Jobs.get(f1, "cfg2", "band", function() return cases[1].spec(), {}, {} end)
  log0 = #W.logs
  W.on_config({ mod_changes = {} })
  st = Jobs.state()
  lines = 0
  for i = log0 + 1, #W.logs do if tostring(W.logs[i]):find("changement de configuration", 1, true) and tostring(W.logs[i]):find("[FO-CHAMP-TRAVAUX]", 1, true) then lines = lines + 1 end end
  check(st.queued == 0 and st.ready == 0 and st.stats.reset == 2 and lines == 1, string.format("changement de configuration : 2 travaux jetés, une ligne (remis %d, lignes %d)", st.stats.reset, lines))
  local rec, why = Jobs.get(f1, "cfg1", "frame", function() return cases[1].spec(), {}, {} end)
  check(rec == nil and why == "calcul", "après le changement : le même travail est redemandé (calcul)")
end

section("Signature du cadre (clé des travaux de bande)")
do
  local Champ = require("script.team.champ")
  local a = Champ.frame_sig({ axis = "x", phase = 2, exit = 1, origin = { x = 3, y = 4 }, umin = -5, umax = 7, v0 = 1, offsets = { 1, 2 } })
  local b = Champ.frame_sig({ v0 = 1, umax = 7, umin = -5, origin = { y = 4, x = 3 }, exit = 1, phase = 2, axis = "x", offsets = { 1, 2 } })
  local c = Champ.frame_sig({ axis = "x", phase = 3, exit = 1, origin = { x = 3, y = 4 }, umin = -5, umax = 7, v0 = 1, offsets = { 1, 2 } })
  check(a == b and a ~= c, "même cadre (ordre de construction différent) : même signature ; autre phase : autre signature")
end

print(string.format("[CHAMP-JOBS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
