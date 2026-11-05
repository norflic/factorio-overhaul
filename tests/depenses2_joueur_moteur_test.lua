--[[
  Lot DEPENSES2 (b ; QCM-4/11-RECRUES du DC : « Oui, comme les factions ») : VOTRE ÉQUIPE recrute sur son stock qui dort, au moteur
  simulé (tests/mock_engine.lua). Ce n'est pas une preuve en jeu. Critères R1 à R5 (fo-logs/2026-11-04_DEPENSES2/CRITERES.md).
    §1 fer qui dort (30 000 fer, 30 000 cuivre, équipements au coffre) : votre équipe recrute 1 à 6 soldats (cible de base 0), unités
       « fo-player-* » de sa force, jamais au-delà du plafond des factions ; journal [FO-DEPENSES] player « soldats cible » ; aucune cible
       relevée pendant que sa matière clé manque (espion) ;
    §2 seul le cuivre dort (le fer, matière clé, ne dort pas) : aucun soldat ;
    §3 plafond des factions à 2 : jamais plus de 2 soldats ;
    §4 alerte près du QG : ses soldats prennent le rôle « defense » des factions (même code : script/ai3/soldats.lua, pass) ;
    §5 mutant : la branche de votre équipe retirée du cerveau (cible jamais relevée) : aucun soldat ;
    §6 mutant : le but « armée » de votre équipe retiré (shared/ai3/buts.lua) : aucun soldat.
  Usage : lua5.2 tests/depenses2_joueur_moteur_test.lua   (depuis la racine du mod ; environ 1 min)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[DEPENSES2-JOUEUR] ECHEC : " .. msg) end
end
local function say(s) print("[DEPENSES2-JOUEUR] " .. s) end
local function W() return M.world() end
local MIN = 3600

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 0 } }) do
    for i = 0, 11 do
      out[#out + 1] = { x = c[1] * 320 + math.cos(i * math.pi / 6) * 60, y = math.sin(i * math.pi / 6) * 60, name = names[i % 4 + 1] }
    end
  end
  return out
end

local function player_soldiers(f)
  local n, bad = 0, 0
  for _, s in pairs(f.soldiers or {}) do
    if s.entity and s.entity.valid then
      n = n + 1
      if s.entity.name:sub(1, 10) ~= "fo-player-" or s.entity.force.name ~= f.force then bad = bad + 1 end
    end
  end
  return n, bad
end

local function run(opts)
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
  M.load_mod()
  M.dispatch(W().on_init)
  M.command("fo-war", "start 2 30 30 320")
  M.run_ticks(60)
  if opts.cap then global.fo.war.settings.soldiers_max = opts.cap end
  game.forces.player.technologies["gun-turret"].researched = true -- (la tourelle passerait en tête de la recherche : faite d'avance)
  local Dep = require("script.ai3.depenses")
  if opts.mutant then Dep.soldiers_target = function(_, army) return army end end
  if opts.no_goal then -- mutant du but « armée » de votre équipe (shared/ai3/buts.lua)
    local B = require("shared.ai3.buts")
    local o_gen = B.generate
    B.generate = function(sit, st)
      local g = o_gen(sit, st)
      if not sit.is_player then return g end
      local out = {}
      for _, x in ipairs(g) do if x.kind ~= "army" then out[#out + 1] = x end end
      return out
    end
  end
  local spy = { calls = 0, short_raised = 0, max_t = 0 }
  local o_st = Dep.soldiers_target
  Dep.soldiers_target = function(ff, army, max, now, tick, key, key_short)
    local t = o_st(ff, army, max, now, tick, key, key_short)
    if ff.is_player then
      spy.calls = spy.calls + 1
      if key_short and t > army then spy.short_raised = spy.short_raised + 1 end
      if t > spy.max_t then spy.max_t = t end
    end
    return t
  end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local f = global.fo.pteam.team
  -- (au stock de l'équipe, comme tests/depenses2_moteur_test.lua : le coffre simulé n'a pas la place de 30 000 plaques)
  local Stock = require("script.team.stock")
  for _, it in ipairs(opts.stock) do Stock.insert(f, it[1], it[2]) end
  local log0 = #W().logs
  local series = {}
  for m = 1, opts.minutes do
    M.run_ticks(MIN)
    series[m] = (player_soldiers(f))
  end
  local lines = {}
  for i = log0 + 1, #W().logs do
    local l = W().logs[i]
    if l:find("[FO-DEPENSES] player", 1, true) then lines[#lines + 1] = l end
  end
  return { f = f, series = series, lines = lines, spy = spy }
end

local KITS = { { "submachine-gun", 20 }, { "firearm-magazine", 200 }, { "pistol", 10 } }
local function with(list)
  local out = {}
  for _, it in ipairs(KITS) do out[#out + 1] = it end
  for _, it in ipairs(list) do out[#out + 1] = it end
  return out
end

say("§1 votre equipe, le fer dort")
local a = run({ minutes = 14, stock = with({ { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local na, bada = player_soldiers(a.f)
local sold_lines = 0
for _, l in ipairs(a.lines) do if l:find("soldats cible", 1, true) then sold_lines = sold_lines + 1 end end
say("§1 soldats par minute : " .. table.concat(a.series, " ") .. " ; lignes « soldats cible » " .. sold_lines .. " ; cible max " .. a.spy.max_t)
check(#a.lines >= 5, "§1 journal [FO-DEPENSES] player (" .. #a.lines .. ")")
check(na >= 1 and na <= 6, "§1 votre équipe recrute 1 à 6 soldats sur son stock qui dort (" .. na .. ")")
check(bada == 0, "§1 soldats fo-player-* de sa force (" .. bada .. " autre(s))")
check(sold_lines >= 1, "§1 journal : soldats cible")
check(a.spy.max_t <= 6, "§1 cible jamais au-delà de 6 (cible de base 0)")
check(a.spy.short_raised == 0, "§1 aucune cible relevée pendant que la matière clé manque")
local f1 = a.f

say("§4 alerte pres du QG : role « defense » des factions")
do
  local C = require("script.ai3.comportement")
  local ep = { x = f1.hq_pos.x + 20, y = f1.hq_pos.y + 5 }
  local ok = C.on_alert(f1, ep, "unit", game.tick)
  M.run_ticks(120)
  local t = C.team(f1)
  local roles = {}
  for _, id in ipairs((function() local ks = {} for k in pairs((t.sd and t.sd.per) or {}) do ks[#ks + 1] = k end table.sort(ks) return ks end)()) do
    local r = t.sd.per[id].role
    if r then roles[r] = (roles[r] or 0) + 1 end
  end
  local txt = {}
  for _, k in ipairs((function() local ks = {} for k in pairs(roles) do ks[#ks + 1] = k end table.sort(ks) return ks end)()) do txt[#txt + 1] = k .. "=" .. roles[k] end
  say("§4 alerte acceptee " .. tostring(ok) .. " ; roles " .. table.concat(txt, " "))
  check(ok == true, "§4 l'alerte de votre équipe est acceptée (elle a des soldats)")
  check((roles.defense or 0) >= 1, "§4 au moins un soldat de votre équipe en défense (" .. tostring(roles.defense) .. ")")
end

say("§2 seul le cuivre dort")
local b = run({ minutes = 14, stock = with({ { "iron-plate", 150 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local nb = player_soldiers(b.f)
say("§2 soldats par minute : " .. table.concat(b.series, " "))
check(nb == 0, "§2 la matière clé (fer) ne dort pas : aucun soldat (" .. nb .. ")")

say("§3 plafond des factions a 2")
local c = run({ minutes = 14, cap = 2, stock = with({ { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local maxc = 0
for _, v in ipairs(c.series) do if v > maxc then maxc = v end end
say("§3 soldats par minute : " .. table.concat(c.series, " "))
check(maxc >= 1 and maxc <= 2, "§3 jamais au-delà du plafond des factions (" .. maxc .. " <= 2)")

say("§5 mutant : branche de votre equipe retiree")
local d = run({ minutes = 14, mutant = true, stock = with({ { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local nd = player_soldiers(d.f)
check(nd == 0, "§5 mutant détecté : sans la branche, aucun soldat (" .. nd .. ")")

say("§6 mutant : but « armee » de votre equipe retire")
local g6 = run({ minutes = 14, no_goal = true, stock = with({ { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local n6 = player_soldiers(g6.f)
check(n6 == 0, "§6 mutant détecté : sans le but « armée », aucun soldat (" .. n6 .. ")")

print(string.format("[DEPENSES2-JOUEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
