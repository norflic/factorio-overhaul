--[[
  Tests hors-jeu de l'équipe du JOUEUR (compagnons ouvriers autour du coffre d'équipe), moteur simulé.
  Usage, depuis la racine du mod :   lua5.2 tests/pteam_test.lua
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
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

section("Pose du coffre d'équipe")
M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
local s = game.surfaces[1]
local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
  { "pistol", 2 }, { "firearm-magazine", 40 }, { "burner-mining-drill", 6 }, { "stone-furnace", 6 }, { "iron-chest", 4 } }) do
  chest.insert({ name = it[1], count = it[2] })
end
W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
local f = global.fo.pteam.team
check(f ~= nil and f.is_player, "équipe du joueur créée")
check(game.forces.player.technologies["military"].researched == false, "aucune technologie offerte au joueur")
local other = s.create_entity({ name = "fo-team-chest", position = { x = 15, y = 5 }, force = "player" })
W().events[defines.events.on_built_entity]({ created_entity = other, player_index = 1, tick = game.tick })
check(global.fo.pteam.team.hq == chest, "un seul coffre d'équipe")

section("Dix minutes de travail")
local ok, err = pcall(M.run_ticks, 10 * 3600)
check(ok, "simulation sans erreur (" .. tostring(err) .. ")")
f = global.fo.pteam.team
print("  " .. require("script.team.team").status_line(f))
-- Lot IA1-a : 8 PNJ offerts à la pose (fo-npc-start) ; les suivants sont PAYÉS avec le contenu du coffre, et
-- (correction IA1-a) seulement quand aucun PNJ n'est inactif (fo-recruit-idle-max = 0 par défaut).
check(f.engineers_count >= 2 and (f.stats.recruit_held or 0) > 0,
  "ouvriers au travail ; frein par le travail actif (" .. f.engineers_count .. " PNJ, dont " .. tostring(f.stats.recruited or 0)
  .. " payés ; frein " .. tostring(f.stats.recruit_held) .. ")")
check(f.outposts_count >= 2, "avant-postes construits (" .. f.outposts_count .. ")")
check(f.team.done.coal and f.team.done.iron, "objectifs Charbon et Fer atteints")
check((f.team.task_stats.service and f.team.task_stats.service.ok or 0) > 0, "tournées d'entretien")
check(f.soldiers_count == 0, "pas de soldats pour l'équipe du joueur")
-- 27/10 au soir : l'équipe du joueur cherche quand SA force est libre (Ia3.player_research_free), jamais à la place du joueur
check(f.tech >= 0, "recherche de l'équipe du joueur : niveau de packs " .. tostring(f.tech))
local ok_ser = pcall(M.serialize, global)
check(ok_ser, "global sérialisable")
M.command("fo-team", "status")
check(W().prints[#W().prints]:find("objectif") ~= nil, "statut affiché")

section("Sans frein (fo-recruit-idle-max = 60) : recrues payées au coffre")
check(remote.call("fo-ia1", "set_setting", "fo-recruit-idle-max", 60) == 60, "frein levé par l'interface fo-ia1")
local paid0 = f.stats.recruited or 0
-- Lot IA1-b2 : la croissance garde T.grow_iron_reserve plaques au coffre (le moteur simulé donne la recette des tourelles :
-- la défense a pris le fer de départ) ; le coffre est regarni pour éprouver le paiement des recrues.
chest.insert({ name = "iron-plate", count = 2000 })
check(pcall(M.run_ticks, 3 * 3600), "simulation sans erreur, sans frein")
check((f.stats.recruited or 0) > paid0, "recrues payées avec le contenu du coffre (" .. paid0 .. " -> "
  .. tostring(f.stats.recruited) .. ")")

section("Renvoi et destruction du coffre")
local pistols = chest.get_item_count("pistol")
M.command("fo-team", "dismiss")
M.run_ticks(2)
check(global.fo.pteam.team.engineers_count == 0, "ouvriers renvoyés")
check(chest.get_item_count("pistol") > pistols, "équipements rendus au coffre")
chest.die()
M.run_ticks(2)
check(global.fo.pteam.team == nil, "coffre détruit : équipe dissoute")

---------------------------------------------------------------------------------------------------
-- Correction VERIF-NUIT (25/10) : votre équipe, décimée, se reconstruit avec les plaques du coffre (règle pure du
-- cerveau, view.recover_floor, shared/team/planner.lua ; moteur réel : banc verif-guide).
---------------------------------------------------------------------------------------------------
section("Cerveau (règle pure) : recrue équipée au QG sous l'effectif de départ")
local Planner = require("shared.team.planner")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local function pview(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {},
    outposts = {}, pending = {}, sites = {}, smelters = 0, smelters_pending = 0, smelter_task = false,
    smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0, turret_groups = {},
    soldiers = 0, soldiers_max = 0, workers = 1, workers_max = 30, workers_idle = 0, threatened = false, open = {},
    workers_wanted = 30, no_research = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function sig(plan)
  local out = {}
  for _, t in ipairs(plan.tasks) do out[#out + 1] = t.key .. "@" .. tostring(t.prio) end
  local m = {}
  for _, x in ipairs(plan.missing) do m[#m + 1] = x[1] .. "x" .. x[2] end
  local u = {}
  for _, x in ipairs(plan.recruit_uses or {}) do u[#u + 1] = x[1] .. "x" .. x[2] end
  return table.concat(out, ",") .. "|" .. table.concat(m, ",") .. "|" .. tostring(plan.recruit_workers) .. ","
    .. tostring(plan.recruit_unarmed) .. "|" .. table.concat(u, ",")
end
local plates = { ["iron-plate"] = 2000, ["copper-plate"] = 500, coal = 100 }
-- 1. Sous le départ (1 sur 8), plaques au coffre, aucun pistolet : recrue équipée tout de suite, rien à fabriquer.
local pa = Planner.plan(pview({ workers = 1, stock = plates, recover_floor = 8 }), book)
local iron_used, craft_recruit = 0, false
for _, it in ipairs(pa.recruit_uses or {}) do if it[1] == "iron-plate" then iron_used = it[2] end end
for _, t in ipairs(pa.tasks) do if t.kind == "craft" and t.tag == "ouvrier" then craft_recruit = true end end
check(pa.recruit_workers == 1 and not pa.recruit_unarmed and iron_used > 0 and not craft_recruit,
  "1 ouvrier sur 8, plaques au coffre : recrue équipée au QG (" .. iron_used .. " fer), sans fabrication par un ouvrier")
local pa0 = Planner.plan(pview({ workers = 1, stock = plates }), book)
check(not pa0.recruit_workers, "même vue sans la règle (avant la correction) : aucune recrue, pistolet demandé à un ouvrier")
-- 1 bis. Le kit complet au coffre : recrue payée comme avant (pas de plaques transformées).
local pk = Planner.plan(pview({ workers = 1, stock = { ["iron-plate"] = 100, pistol = 2, ["firearm-magazine"] = 30 },
  recover_floor = 8 }), book)
check(pk.recruit_workers == 1 and not pk.recruit_unarmed and pk.recruit_uses == nil, "kit au coffre : recrue payée avec le kit")
-- 2. À l'effectif de départ (8 sur 8) : plan identique à celui d'avant la correction.
local pb = Planner.plan(pview({ workers = 8, stock = plates, recover_floor = 8 }), book)
local pb0 = Planner.plan(pview({ workers = 8, stock = plates }), book)
check(sig(pb) == sig(pb0) and pb.recruit_uses == nil, "effectif de départ atteint : plan inchangé (" .. sig(pb):sub(1, 60) .. ")")
-- 3. Fer insuffisant : rien de plus que la règle ordinaire (ni recrue, ni plaques prélevées).
local poor = { ["iron-plate"] = 20, ["copper-plate"] = 20 }
local pc = Planner.plan(pview({ workers = 1, stock = poor, recover_floor = 8 }), book)
local pc0 = Planner.plan(pview({ workers = 1, stock = poor }), book)
check(not pc.recruit_workers and pc.recruit_uses == nil and sig(pc) == sig(pc0), "fer insuffisant : aucune recrue, plan inchangé")
-- 4. Équipe vide, sans plaques : le secours ordinaire (ouvrier sans arme) reste.
local pd = Planner.plan(pview({ workers = 0, stock = {}, recover_floor = 8 }), book)
check(pd.recruit_workers == 1 and pd.recruit_unarmed, "équipe vide sans plaques : embauche de secours sans arme (inchangé)")
-- 5. Garde d'agents atteinte : aucune recrue payée.
local pe = Planner.plan(pview({ workers = 1, stock = plates, recover_floor = 8, recruit_blocked = true }), book)
check(not pe.recruit_uses and not (pe.recruit_workers and not pe.recruit_unarmed), "garde d'agents : aucune recrue équipée")
-- 6. Ni fonderie du QG ni minage à la main ni garde (survie des factions) pour votre équipe (forme large, essai D1).
local pf = Planner.plan(pview({ workers = 1, smelters = 0, stock = { stone = 100, coal = 100 }, recover_floor = 8,
  done = { army = true } }), book)
local extra = false
for _, t in ipairs(pf.tasks) do if t.prio == 92 or t.prio == 90 then extra = true end end
check(not pf.emergency_smelters and not extra and not pf.train, "pas de fonderie du QG, de minage à la main ni de garde")
-- 7. Une faction (view.emergency) garde sa règle : recover_floor ignoré.
local em = { floor = 8, rebuild = false }
local pg1 = Planner.plan(pview({ workers = 1, stock = plates, emergency = em, recover_floor = 8, soldiers_max = 30 }), book)
local pg0 = Planner.plan(pview({ workers = 1, stock = plates, emergency = em, soldiers_max = 30 }), book)
check(sig(pg1) == sig(pg0), "faction : règle de survie d'IA2-a2 inchangée")
-- 8. Déterminisme : deux pensées identiques.
check(sig(Planner.plan(pview({ workers = 1, stock = plates, recover_floor = 8 }), book)) == sig(pa), "deux pensées identiques")

section("Correction VERIF-NUIT (moteur simulé) : 7 ouvriers tués, plaques au coffre sans pistolet, sans guerre")
M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
local s2 = game.surfaces[1]
local chest2 = s2.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
for _, it in ipairs({ { "iron-plate", 2000 }, { "copper-plate", 500 }, { "coal", 400 }, { "stone", 200 },
  { "burner-mining-drill", 6 }, { "stone-furnace", 6 } }) do
  chest2.insert({ name = it[1], count = it[2] })
end
W().events[defines.events.on_built_entity]({ created_entity = chest2, player_index = 1, tick = game.tick })
local g = global.fo.pteam.team
check(g ~= nil and g.engineers_count == 8, "8 PNJ offerts à la pose du coffre (" .. tostring(g and g.engineers_count) .. ")")
M.run_ticks(600)
local Registry = require("script.companion.registry")
local ids = {}
for id in pairs(g.engineers) do ids[#ids + 1] = id end
table.sort(ids)
for i = 2, #ids do
  local a = Registry.get(ids[i])
  if a and a.entity and a.entity.valid then a.entity.die() end
end
M.run_ticks(2)
check(g.engineers_count == 1 and chest2.get_item_count("pistol") == 0, "1 ouvrier restant, aucun pistolet au coffre ("
  .. g.engineers_count .. ")")
local r0 = g.stats.emergency_recruits or 0
local ok3, err3 = pcall(M.run_ticks, 4 * 3600)
check(ok3, "4 min sans erreur, sans guerre (" .. tostring(err3) .. ")")
check((g.stats.emergency_recruits or 0) - r0 >= 7 and g.engineers_count >= 8, "équipe reconstruite au QG : "
  .. tostring((g.stats.emergency_recruits or 0) - r0) .. " recrues équipées, " .. g.engineers_count .. " PNJ")

section("Lot IA-V2 : PNJ tué loin du QG : les PNJ au travail à moins de 64 tuiles rentrent (moteur réel, ia1b2-guide 1618033988)")
M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
local s3 = game.surfaces[1]
local chest3 = s3.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
for _, it in ipairs({ { "iron-plate", 2000 }, { "copper-plate", 500 }, { "coal", 400 }, { "stone", 200 } }) do
  chest3.insert({ name = it[1], count = it[2] })
end
W().events[defines.events.on_built_entity]({ created_entity = chest3, player_index = 1, tick = game.tick })
local g3 = global.fo.pteam.team
M.run_ticks(1200)
local busy = {}
local ids3 = {}
for id in pairs(g3.engineers) do ids3[#ids3 + 1] = id end
table.sort(ids3)
for _, id in ipairs(ids3) do
  local a = Registry.get(id)
  if a and a.entity and a.entity.valid and a.task and a.task.kind ~= "garrison" and a.task.kind ~= "fortify"
    and not a.task.fail then busy[#busy + 1] = a end
end
check(#busy >= 3, "au moins 3 PNJ au travail après 20 s (" .. #busy .. ")")
if #busy >= 3 then
  local victim, near, far = busy[1], busy[2], busy[3]
  victim.entity.teleport({ x = 120, y = 120 })
  near.entity.teleport({ x = 140, y = 120 })
  far.entity.teleport({ x = 300, y = 300 })
  local recalls0 = g3.stats.danger_recalls or 0
  victim.entity.die()
  M.run_ticks(1)
  check(near.task and near.task.fail == "danger", "PNJ à 20 tuiles de la perte : rappelé au QG (« danger »)")
  check(not (far.task and far.task.fail == "danger"), "PNJ à plus de 64 tuiles : continue")
  check((g3.stats.danger_recalls or 0) - recalls0 >= 1, "rappel compté (" .. tostring(g3.stats.danger_recalls) .. ")")
  -- Perte près du QG (moins de 24 tuiles) : personne n'est rappelé.
  -- Lot CRAFT-PARALLELE : seul le témoin (b2[2]) doit avoir une tâche (le rappel ne touche que les PNJ au travail) ; la victime
  -- (b2[1]) peut être un PNJ sans tâche (un PNJ qui fabrique en arrière-plan n'a plus de tâche « craft » : avec deux PNJ au
  -- travail exigés, le contrôle était sauté en silence).
  local witness, victim2
  for _, id in ipairs(ids3) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid and a ~= far then
      if not witness and a.task and not a.task.fail then witness = a elseif not victim2 then victim2 = a end
    end
  end
  local b2 = { victim2, witness }
  check(witness ~= nil and victim2 ~= nil, "un témoin au travail et une victime près du QG")
  if witness and victim2 then
    b2[1].entity.teleport({ x = 10, y = 10 })
    b2[2].entity.teleport({ x = 12, y = 10 })
    local r1 = g3.stats.danger_recalls or 0
    b2[1].entity.die()
    M.run_ticks(1)
    check((g3.stats.danger_recalls or 0) == r1, "perte à moins de 24 tuiles du QG : aucun rappel")
  end
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
