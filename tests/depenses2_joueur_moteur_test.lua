--[[
  Lot DEPENSES2 (b ; QCM-4/11-RECRUES du DC : « Oui, comme les factions ») : VOTRE ÉQUIPE recrute sur son stock qui dort, au moteur
  simulé (tests/mock_engine.lua). Ce n'est pas une preuve en jeu. Critères R1 à R5 (fo-logs/2026-11-04_DEPENSES2/CRITERES.md).
    §1 fer qui dort (30 000 fer, 30 000 cuivre, équipements au coffre) : votre équipe a la défense minimale des factions (10 premiers
       soldats, R1 : décision du lead) et recrute 1 à 6 soldats de plus sur son stock qui dort, unités
       « fo-player-* » de sa force, jamais au-delà du plafond des factions ; journal [FO-DEPENSES] player « soldats cible » ; aucune cible
       relevée pendant que sa matière clé manque (espion) ;
    §2 seul le cuivre dort (le fer, matière clé, ne dort pas) : la base de 10 soldats, rien de plus ; §10 mutant (base retirée) : 0 ;
    §3 plafond des factions à 2 : jamais plus de 2 soldats ;
    §4 alerte près du QG : ses soldats prennent le rôle « defense » des factions (même code : script/ai3/soldats.lua, pass) ;
    §5 mutant : la branche de votre équipe retirée du cerveau (cible jamais relevée) : aucun soldat ;
    §6 mutant : le but « armée » de votre équipe retiré (shared/ai3/buts.lua) : aucun soldat ;
    §7 (relecture, point 1) fin de l'équipe (coffre retiré) : ses soldats partent avec elle (aucune unité sans suivi, propriété rendue) ;
       une nouvelle équipe repart de 0 et recrute de nouveau avec des comptes justes ;
    §8 renvoi des PNJ : l'équipe reste, ses soldats restent comptés ;
    §9 (relecture, point 3) plafond 0 : journal « rien de plus (plafond 0) », jamais « soldats cible 0 » ;
    §11 (R1, demande du lead) le fer manque : cible 0 (ni base ni relèvement), même avec les équipements au coffre ; mutant (garde
       retirée) détecté ; §1 : journal de la paie « soldat(s) ... paye(s) ... matiere cle qui manque : non ».
  Usage : lua5.2 tests/depenses2_joueur_moteur_test.lua   (depuis la racine du mod ; environ 2 min)
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
  if opts.no_base then require("shared.ai3.buts").ARMY_FIRST_N = 0 end -- mutant : défense minimale de votre équipe retirée
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
  local spy = { calls = 0, short_raised = 0, max_t = 0, max_raise = 0, short_calls = 0, short_target = 0 }
  if opts.unguarded then -- mutant : la base de votre équipe ignore la matière clé qui manque
    local o_u = Dep.soldiers_target
    Dep.soldiers_target = function(ff, army, max, now, tick, key, key_short, cost)
      if ff.is_player and key_short then army = math.min(10, max or 0) end
      return o_u(ff, army, max, now, tick, key, key_short, cost)
    end
  end
  local o_st = Dep.soldiers_target
  Dep.soldiers_target = function(ff, army, max, now, tick, key, key_short, cost)
    local t = o_st(ff, army, max, now, tick, key, key_short, cost)
    if ff.is_player then
      spy.calls = spy.calls + 1
      if key_short and t > army then spy.short_raised = spy.short_raised + 1 end
      if t > spy.max_t then spy.max_t = t end
      if t - army > spy.max_raise then spy.max_raise = t - army end
      if key_short then
        spy.short_calls = spy.short_calls + 1
        if t > spy.short_target then spy.short_target = t end
      end
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

-- Sections choisies : lua5.2 tests/depenses2_joueur_moteur_test.lua 1,4  (sans argument : toutes ; chacune tient sous 60 s, ce qui
-- laisse passer le garde des tests lourds quand le DC joue)
local SEL = arg and arg[1]
local function want(id)
  if not SEL then return true end
  for x in SEL:gmatch("[^,]+") do if x == id then return true end end
  return false
end
local function fo_player_alive()
  local n = 0
  for _, e in ipairs(W().entities) do
    if e.valid and type(e.name) == "string" and e.name:sub(1, 10) == "fo-player-" then n = n + 1 end
  end
  return n
end
local IRON = { { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }

if want("1") then
say("§1 votre equipe, le fer dort")
local a = run({ minutes = 14, stock = with({ { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local na, bada = player_soldiers(a.f)
local sold_lines = 0
for _, l in ipairs(a.lines) do if l:find("soldats cible", 1, true) then sold_lines = sold_lines + 1 end end
say("§1 soldats par minute : " .. table.concat(a.series, " ") .. " ; lignes « soldats cible » " .. sold_lines .. " ; cible max " .. a.spy.max_t)
check(#a.lines >= 5, "§1 journal [FO-DEPENSES] player (" .. #a.lines .. ")")
check(na >= 11 and na <= 16, "§1 votre équipe : sa base de 10 soldats et 1 à 6 de plus sur son stock qui dort (" .. na .. ")")
check(bada == 0, "§1 soldats fo-player-* de sa force (" .. bada .. " autre(s))")
check(sold_lines >= 1, "§1 journal : soldats cible")
check(a.spy.max_raise >= 1 and a.spy.max_raise <= 6 and a.spy.max_t <= 16, "§1 cible relevée de 1 à 6 au-dessus de la base 10 (" .. a.spy.max_raise .. ", cible max " .. a.spy.max_t .. ")")
check(a.spy.short_raised == 0, "§1 aucune cible relevée pendant que la matière clé manque")
local paid, paid_short = 0, 0
for _, l in ipairs(a.lines) do
  if l:find("paye(s) a", 1, true) then
    paid = paid + 1
    if l:find("matiere cle qui manque : OUI", 1, true) then paid_short = paid_short + 1 end
  end
end
say("§1 journal de la paie : " .. paid .. " ligne(s)" .. ((function() for _, l in ipairs(a.lines) do if l:find("paye(s) a", 1, true) then return " ; " .. l:sub(1, 230) end end return "" end)()))
check(paid >= 1 and paid_short == 0, "§1 journal : soldats de votre équipe payés, jamais quand la matière clé manque (" .. paid .. " ligne(s))")
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

end
if want("2") then
say("§2 seul le cuivre dort : le fer ne dort pas, votre equipe a sa base")
local b = run({ minutes = 14, stock = with({ { "iron-plate", 150 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local nb = player_soldiers(b.f)
say("§2 soldats par minute : " .. table.concat(b.series, " "))
check(nb == 10, "§2 le fer ne dort pas : la base de 10 soldats, rien de plus (" .. nb .. ")")

end
if want("3") then
say("§3 plafond des factions a 2")
local c = run({ minutes = 14, cap = 2, stock = with({ { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local maxc = 0
for _, v in ipairs(c.series) do if v > maxc then maxc = v end end
say("§3 soldats par minute : " .. table.concat(c.series, " "))
check(maxc >= 1 and maxc <= 2, "§3 jamais au-delà du plafond des factions (" .. maxc .. " <= 2)")

end
if want("5") then
say("§5 mutant : branche de votre equipe retiree")
local d = run({ minutes = 14, mutant = true, stock = with({ { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local nd = player_soldiers(d.f)
check(nd == 10, "§5 mutant détecté : sans le relèvement du stock qui dort, la base seule (" .. nd .. " ; §1 : 11 à 16)")

end
if want("11") then
say("§11 le fer manque : ni base ni soldat de plus, meme avec les equipements au coffre")
local k11 = run({ minutes = 14, stock = with({ { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local n11 = player_soldiers(k11.f)
say("§11 soldats par minute : " .. table.concat(k11.series, " ") .. " ; appels « fer qui manque » " .. k11.spy.short_calls .. ", cible alors " .. k11.spy.short_target)
check(k11.spy.short_calls >= 1, "§11 le cerveau voit le fer manquer (" .. k11.spy.short_calls .. " appel(s))")
check(k11.spy.short_target == 0, "§11 cible 0 tant que le fer manque (" .. k11.spy.short_target .. ")")
end
if want("11m") then
say("§11 mutant : la base ignore le fer qui manque")
local k11m = run({ minutes = 14, unguarded = true, stock = with({ { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
check(k11m.spy.short_target >= 1, "§11 mutant détecté : sans la garde, une cible de soldats pendant que le fer manque (" .. k11m.spy.short_target .. ")")

end
if want("10") then
say("§10 mutant : defense minimale de votre equipe retiree (le fer ne dort pas)")
local m10 = run({ minutes = 14, no_base = true, stock = with({ { "iron-plate", 150 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local n10 = player_soldiers(m10.f)
check(n10 == 0, "§10 mutant détecté : sans la base, aucun soldat quand le fer ne dort pas (" .. n10 .. ")")

end
if want("6") then
say("§6 mutant : but « armee » de votre equipe retire")
local g6 = run({ minutes = 14, no_goal = true, stock = with({ { "iron-plate", 30000 }, { "copper-plate", 30000 }, { "coal", 500 }, { "stone", 500 } }) })
local n6 = player_soldiers(g6.f)
check(n6 == 0, "§6 mutant détecté : sans le but « armée », aucun soldat (" .. n6 .. ")")

end
if want("8") then
say("§8 renvoi des PNJ : l'equipe reste, ses soldats restent suivis")
do
  local r = run({ minutes = 10, stock = with(IRON) })
  local n0 = player_soldiers(r.f)
  M.command("fo-team", "dismiss")
  M.run_ticks(2)
  local f = global.fo.pteam.team
  check(f ~= nil and n0 >= 1 and f.soldiers_count == n0 and fo_player_alive() == n0,
    "§8 renvoi : équipe gardée, " .. n0 .. " soldat(s) toujours comptés (" .. tostring(f and f.soldiers_count) .. ", vivants " .. fo_player_alive() .. ")")
end

end
if want("7") then
say("§7 fin de l'equipe : ses soldats partent avec elle ; une nouvelle equipe repart de zero")
do
  local r = run({ minutes = 10, stock = with(IRON) })
  local ids = {}
  for id in pairs(r.f.soldiers or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  local n0 = #ids
  r.f.hq.destroy() -- (retiré, pas tué : l'équipe prend fin même avec des soldats vivants, Sq.chest_fate)
  M.run_ticks(2)
  local owned = 0
  for _, id in ipairs(ids) do if global.fo.war.owners[id] then owned = owned + 1 end end
  check(n0 >= 1 and global.fo.pteam.team == nil, "§7 coffre retiré : l'équipe prend fin (" .. n0 .. " soldat(s) avant)")
  check(fo_player_alive() == 0, "§7 aucun soldat fo-player-* ne reste sans suivi (" .. fo_player_alive() .. ")")
  check(owned == 0, "§7 propriété rendue : aucune perte ne sera comptée à une équipe suivante (" .. owned .. ")")
  local released = 0
  for _, l in ipairs(W().logs) do if l:find("soldat(s) de votre equipe retire(s) avec elle", 1, true) then released = released + 1 end end
  check(released == 1, "§7 journal [FO-PTEAM] : soldats retirés avec l'équipe")
  local chest = game.surfaces[1].create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local g = global.fo.pteam.team
  check(g ~= nil and g ~= r.f and (g.soldiers_count or 0) == 0, "§7 nouvelle équipe : 0 soldat compté au départ")
  local Stock = require("script.team.stock")
  for _, it in ipairs(with(IRON)) do Stock.insert(g, it[1], it[2]) end
  M.run_ticks(10 * MIN)
  local ng = player_soldiers(g)
  check(ng >= 1 and ng <= 16 and g.soldiers_count == ng and fo_player_alive() == ng,
    "§7 nouvelle équipe : recrute de nouveau, comptes justes (" .. ng .. " suivis, " .. fo_player_alive() .. " vivants)")
end

end
if want("7m") then
say("§7 mutant : les soldats ne partent pas avec l'equipe")
do
  local r = run({ minutes = 10, stock = with(IRON) })
  local n0 = player_soldiers(r.f)
  require("script.team.player_team").release_soldiers = function() return 0 end
  r.f.hq.destroy()
  M.run_ticks(2)
  check(n0 >= 1 and global.fo.pteam.team == nil and fo_player_alive() == n0,
    "§7 mutant détecté : sans le retrait, " .. fo_player_alive() .. " soldat(s) fo-player-* restent sans suivi")
end

end
if want("9") then
say("§9 plafond 0 (aucun soldat permis) : journal « rien de plus (plafond 0) »")
do
  local r = run({ minutes = 10, cap = 0, stock = with(IRON) })
  local zero, note = 0, 0
  for _, l in ipairs(r.lines) do
    if l:find("soldats cible 0", 1, true) then zero = zero + 1 end
    if l:find("soldats : rien de plus (plafond 0)", 1, true) then note = note + 1 end
  end
  check(player_soldiers(r.f) == 0 and zero == 0 and note >= 1,
    "§9 plafond 0 : aucun soldat, aucune ligne « soldats cible 0 », " .. note .. " ligne(s) « rien de plus (plafond 0) »")
end

end
print(string.format("[DEPENSES2-JOUEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
