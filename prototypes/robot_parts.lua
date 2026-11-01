-- Lot RB-4 GAMME (1/11) : les pièces d'X3 que les robots exigent (servomoteur, capteur optique, contrôleur, noyau de pilotage,
-- actionneur à aimants, barreau Nd:YAG, module laser), leurs recettes et leurs 3 technologies. Données : shared/content/robot_parts.lua.
-- Icônes PROVISOIRES (copies vanilla teintées). À charger APRÈS prototypes/crafts, bauxite, tin, compute et superconductors (objets
-- et technologies qu'elles exigent) et AVANT prototypes/robots.

local lib = require("prototypes.lib")
local C = require("shared.content.crafts")
local P = require("shared.content.robot_parts")

local out = {}

out[#out + 1] = { type = "item-subgroup", name = "fo-robot-parts", group = "intermediate-products", order = "z[fo]-g[robot-parts]" }

-- { type vanilla, nom vanilla, teinte } : une teinte ne fait que multiplier (F36, F38).
local ICON = {
  ["fo-servo-motor"] = { "item", "electric-engine-unit", { r = 0.85, g = 0.95, b = 1.00 } },
  ["fo-optical-sensor"] = { "item", "radar", { r = 0.70, g = 0.90, b = 1.00 } },
  ["fo-controller"] = { "item", "advanced-circuit", { r = 0.80, g = 1.00, b = 0.85 } },
  ["fo-guidance-core"] = { "item", "processing-unit", { r = 1.00, g = 0.90, b = 0.60 } },
  ["fo-magnetic-actuator"] = { "item", "electric-engine-unit", { r = 1.00, g = 0.70, b = 0.70 } },
  ["fo-ndyag-rod"] = { "item", "pipe", { r = 0.95, g = 0.75, b = 1.00 } },
  ["fo-laser-module"] = { "item", "laser-turret", { r = 1.00, g = 0.55, b = 0.55 } },
}

local function icon_of(name)
  local ic = assert(ICON[name], "robot_parts : icône absente " .. name)
  local src = assert(data.raw[ic[1]][ic[2]], "robot_parts : icône source absente " .. ic[1] .. "/" .. ic[2])
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = ic[3] } }
end

local function amounts(list)
  local res = {}
  for _, g in ipairs(list) do res[#res + 1] = { type = "item", name = g[1], amount = g[2] } end
  return res
end

for i, name in ipairs(P.ITEMS) do
  local x = P.item(name)
  out[#out + 1] = {
    type = "item", name = name,
    localised_name = { "item-name." .. name }, localised_description = { "item-description." .. name },
    icons = icon_of(name), subgroup = "fo-robot-parts", order = string.format("a[part]-%02d", i), stack_size = x.stack,
  }
  local r = P.recipe(name)
  out[#out + 1] = {
    type = "recipe", name = name, category = r.category, enabled = false, energy_required = r.time,
    ingredients = amounts(r.ingredients), results = amounts(r.results), main_product = name,
    localised_name = { "item-name." .. name },
  }
end

for _, t in ipairs(P.TECHS) do
  local effects = {}
  for _, rn in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(rn) end
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = icon_of(t.unlocks[1]),
    effects = effects, prerequisites = t.prerequisites, count = C.tech_count(t), packs = C.packs(t.epoch), time = t.time,
    order = "z[fo]-robot-parts-" .. t.name,
  })
end

data:extend(out)
