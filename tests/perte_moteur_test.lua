--[[
  Lot PERIMETRE2 (diagnostic) : le journal [FO-PERTE] au moteur simulé (tests/mock_engine.lua) : votre équipe, un four détruit par un
  mordeur près d'une tourelle vide, une ligne de perte (manque « b ») ; le relevé de 5 min ; une perte causée par la même force : aucune ligne.
  Lancement : lua5.2 tests/perte_moteur_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. m) end end
local function W() return M.world() end
M.new_game({ patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0 })
W().prototypes["gun-turret"].turret_range = 18
local s = game.surfaces[1]
local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
M.run_ticks(18300)
local furnace = s.create_entity({ name = "stone-furnace", position = { x = 60, y = 5 }, force = "player" })
local State = require("script.faction.state")
State.own(furnace, global.fo.pteam.team.id, "sink", 1) -- four de VOTRE ÉQUIPE (relecture du lead, point 7)
local mine = s.create_entity({ name = "stone-furnace", position = { x = 80, y = 5 }, force = "player" }) -- four posé par le JOUEUR
local tur = s.create_entity({ name = "gun-turret", position = { x = 66, y = 5 }, force = "player" })
local biter = s.create_entity({ name = "small-biter", position = { x = 61, y = 6 }, force = "enemy" })
W().events[defines.events.on_entity_died]({ entity = furnace, force = game.forces.enemy, cause = biter, tick = game.tick })
W().events[defines.events.on_entity_died]({ entity = mine, force = game.forces.enemy, cause = biter, tick = game.tick })
local own = s.create_entity({ name = "stone-furnace", position = { x = 70, y = 5 }, force = "player" })
W().events[defines.events.on_entity_died]({ entity = own, force = game.forces.player, tick = game.tick })
local lines, rel = {}, {}
for _, l in ipairs(W().logs) do
  if l:find("[FO-PERTE] player minute", 1, true) then lines[#lines + 1] = l end
  if l:find("[FO-PERTE] player releve", 1, true) then rel[#rel + 1] = l end
end
print("    " .. tostring(lines[1]))
print("    " .. tostring(rel[#rel]))
check(#lines == 1, "une seule ligne de perte (la perte par sa propre force et le four du joueur ignorés) : " .. #lines)
check(lines[1] and lines[1]:find("stone-furnace (fonderie) site base cote E", 1, true) ~= nil, "catégorie, site, côté")
check(lines[1] and lines[1]:find("tueur mordeur | tourelles a portee 1 dont armees 0", 1, true) ~= nil and lines[1]:find("manque b", 1, true) ~= nil,
  "tueur, tourelle vide à portée, manque b")
check(#rel >= 1 and rel[1]:find("couverture armee", 1, true) ~= nil, "relevé de 5 min")
-- ligne « plan » (lot PERIMETRE2, G3) : croissance du plan directeur de votre équipe, lecture seule
local f = global.fo.pteam.team
local saved = f.build
f.build = { radius = 4, order = { 1, 2 }, projects = { { id = 1, state = "fini" }, { id = 2, state = "chantier" } }, stats = { projects_done = 1 },
  lots = { a = { i = 0, j = 0, state = "occupe", used = 1 }, b = { i = 1, j = 0, state = "libre" }, c = { i = 2, j = 0, state = "libre", out = true } },
  enc = { r = 4, segs = { { pid = 1, n = 8 } }, complete = false } }
require("script.team.perte_log").plan_line(f, game.tick)
f.build = saved
local pl
for _, l in ipairs(W().logs) do if l:find("[FO-PERTE] player plan a", 1, true) then pl = l end end
print("    " .. tostring(pl))
check(pl and pl:find("treillis rayon 4 | lots 3 : pris 1, libres 1, ecartes 1 | projets finis 1, en cours 1", 1, true) ~= nil
  and pl:find("segments 1 dont finis 1, murs demandes 8, complete false", 1, true) ~= nil, "ligne « plan » : rayon, lots, projets, enceinte")
print(string.format("[PERTE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
