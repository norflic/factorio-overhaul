-- Lot LAYOUT : SONDE au moteur simulé (pas un banc : aucun contrôle) : la guerre à 2 factions de tests/ia3e_sonde.lua, avec des
-- prototypes de foreuses électriques ajoutés au mock, jouée N minutes ; affiche les lignes [FO-LAYOUT] et [FO-IA1D].
-- Lancement : lua5.2 tests/layout_sonde.lua [minutes]. Le gisement du mock est CLAIRSEMÉ (une entité sur quatre) : la sonde sert
-- à voir passer le code de Build.layout_place (aucune erreur Lua), pas à juger l'agencement.
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")
local Mod = require("shared.team.modules")
local MIN = 3600
local minutes = tonumber(arg and arg[1]) or 30
local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end
M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "normal", groups_hit_player = true, turrets_kill = true, ia3e = true })
-- prototypes de foreuses (lus à M.spec, comme le ferait le moteur) et de recettes
local name = "electric-mining-drill"
local sp = Mod.spec(name)
local half = sp.w * 0.5 - 0.1
local DRILLS = { [name] = { name = name, type = "mining-drill", collision_box = { left_top = { x = -half, y = -half }, right_bottom = { x = half, y = half } },
  mining_speed = sp.speed, resource_searching_radius = sp.radius, vector_to_place_result = { x = sp.drop[1], y = sp.drop[2] },
  items_to_place_this = { { name = name, count = 1 } }, electric_energy_source_prototype = {}, resource_categories = { ["basic-solid"] = true },
  has_flag = function() return false end } }
local prev = game.get_filtered_entity_prototypes
game.get_filtered_entity_prototypes = function(filters)
  if filters[1].type == "mining-drill" then return DRILLS end
  return prev(filters)
end
game.get_filtered_recipe_prototypes = function(filters)
  local item = filters[1].elem_filters[1].name
  return { [item] = { name = item } }
end
local protos = game.entity_prototypes
game.entity_prototypes = setmetatable({}, { __index = function(_, k)
  local p = protos[k]
  if p then return p end
  if k == "coal" or k == "iron-ore" or k == "copper-ore" or k == "stone" then return { resource_category = "basic-solid" } end
end })
M.command("fo-war", "start 2 60 8 320")
local seen = 0
local t0 = os.clock()
for m = 1, minutes do
  M.run_ticks(MIN)
  local logs = M.world().logs
  for i = seen + 1, #logs do
    local l = logs[i]
    if l:find("FO%-LAYOUT") or l:find("FO%-AUTO%]") or l:find("rror") then print(l) end
  end
  seen = #logs
end
print(string.format("sonde : %d min de jeu en %.1f s", minutes, os.clock() - t0))
