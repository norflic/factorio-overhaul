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
-- Lot IA1-a : 8 PNJ offerts à la pose (fo-npc-start) ; les suivants sont PAYÉS avec le contenu du coffre.
check(f.engineers_count >= 2 and (f.stats.recruited or 0) >= 1,
  "ouvriers recrutés avec les équipements du coffre (" .. f.engineers_count .. ", dont " .. tostring(f.stats.recruited) .. " payés)")
check(f.outposts_count >= 2, "avant-postes construits (" .. f.outposts_count .. ")")
check(f.team.done.coal and f.team.done.iron, "objectifs Charbon et Fer atteints")
check((f.team.task_stats.service and f.team.task_stats.service.ok or 0) > 0, "tournées d'entretien")
check(f.soldiers_count == 0, "pas de soldats pour l'équipe du joueur")
check(f.tech == 0, "pas de recherche payée par l'équipe du joueur")
local ok_ser = pcall(M.serialize, global)
check(ok_ser, "global sérialisable")
M.command("fo-team", "status")
check(W().prints[#W().prints]:find("objectif") ~= nil, "statut affiché")

section("Renvoi et destruction du coffre")
local pistols = chest.get_item_count("pistol")
M.command("fo-team", "dismiss")
M.run_ticks(2)
check(global.fo.pteam.team.engineers_count == 0, "ouvriers renvoyés")
check(chest.get_item_count("pistol") > pistols, "équipements rendus au coffre")
chest.die()
M.run_ticks(2)
check(global.fo.pteam.team == nil, "coffre détruit : équipe dissoute")

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
