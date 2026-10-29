--[[
  Lot IA-G : RELEVÉ DE PROTOTYPES hors jeu (format de shared/ai3/catalogue.lua, K.build), bâti depuis les fixtures
  réelles (recettes vanilla + mod : recipes_ia1e.lua ; technologies FINALES : tech_ai3_final.lua ; machines :
  entities_ai3.lua). En jeu, script/ai3/general.lua lit le même relevé dans game.*_prototypes.

  Ce fichier est du TEST : il nomme les objets du jeu (types du moteur des machines, objets militaires, effets des
  technologies de bonus, entrées du laboratoire vanilla), comme le ferait le moteur. Le code de décision n'en voit rien.

  F.dump(opts) -> relevé ; opts.reverse = vrai : toutes les listes dans l'ordre inverse (déterminisme) ;
  opts.mutate = function(dump) (données changées : preuve de généralisation).
]]

local F = {}

local TYPE_OF = {
  ["character"] = "character", ["stone-furnace"] = "furnace", ["steel-furnace"] = "furnace",
  ["electric-furnace"] = "furnace", ["assembling-machine-1"] = "assembling-machine",
  ["assembling-machine-2"] = "assembling-machine", ["assembling-machine-3"] = "assembling-machine",
  ["chemical-plant"] = "assembling-machine", ["oil-refinery"] = "assembling-machine", ["centrifuge"] = "assembling-machine",
  ["burner-mining-drill"] = "mining-drill", ["electric-mining-drill"] = "mining-drill", ["pumpjack"] = "mining-drill",
  ["offshore-pump"] = "offshore-pump", ["boiler"] = "boiler", ["steam-engine"] = "generator", ["lab"] = "lab",
}
local LAB_INPUTS = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack",
  "production-science-pack", "utility-science-pack", "space-science-pack" }
local OTHER_ENTITIES = {
  { "gun-turret", "ammo-turret" }, { "laser-turret", "electric-turret" }, { "flamethrower-turret", "fluid-turret" },
  { "stone-wall", "wall" }, { "gate", "gate" }, { "transport-belt", "transport-belt" }, { "fast-transport-belt", "transport-belt" },
  { "underground-belt", "underground-belt" }, { "splitter", "splitter" }, { "inserter", "inserter" },
  { "burner-inserter", "inserter" }, { "long-handed-inserter", "inserter" }, { "fast-inserter", "inserter" },
  { "small-electric-pole", "electric-pole" }, { "medium-electric-pole", "electric-pole" }, { "pipe", "pipe" },
  { "pipe-to-ground", "pipe-to-ground" }, { "wooden-chest", "container" }, { "iron-chest", "container" },
  { "steel-chest", "container" }, { "radar", "radar" },
}
local ITEM_TYPES = {
  ammo = { "firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine", "shotgun-shell",
    "piercing-shotgun-shell", "cannon-shell", "explosive-cannon-shell", "rocket", "explosive-rocket", "flamethrower-ammo" },
  gun = { "pistol", "submachine-gun", "shotgun", "combat-shotgun", "rocket-launcher", "flamethrower" },
  armor = { "light-armor", "heavy-armor", "modular-armor", "power-armor", "power-armor-mk2" },
  capsule = { "grenade", "cluster-grenade", "poison-capsule", "slowdown-capsule", "defender-capsule",
    "distractor-capsule", "destroyer-capsule" },
}
local FUEL = { coal = 4e6, wood = 2e6, ["solid-fuel"] = 12e6, ["rocket-fuel"] = 100e6 }
local BONUS = {
  { "physical-projectile-damage", { "ammo-damage", "turret-attack" } },
  { "weapon-shooting-speed", { "gun-speed" } },
  { "stronger-explosives", { "ammo-damage" } },
  { "refined-flammables", { "ammo-damage", "turret-attack" } },
  { "energy-weapons-damage", { "ammo-damage" } },
  { "laser-shooting-speed", { "gun-speed" } },
  { "research-speed", { "laboratory-speed" } },
  { "mining-productivity", { "mining-drill-productivity-bonus" } },
  { "toolbelt", { "character-inventory-slots-bonus" } },
  { "follower-robot-count", { "maximum-following-robots-count" } },
  { "inserter-capacity-bonus", { "inserter-stack-size-bonus" } },
  { "worker-robots-speed", { "worker-robot-speed" } },
  { "worker-robots-storage", { "worker-robot-storage" } },
}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function deep(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deep(v) end
  return c
end

local function rev(l)
  local out = {}
  for i = #l, 1, -1 do out[#out + 1] = l[i] end
  return out
end

function F.dump(opts)
  opts = opts or {}
  local recipes = deep(dofile("tests/fixtures/recipes_ia1e.lua"))
  local techs0 = deep(dofile("tests/fixtures/tech_ai3_final.lua"))
  local ent = dofile("tests/fixtures/entities_ai3.lua")
  local techs = {}
  for name, t in pairs(techs0) do
    local effects = {}
    for _, b in ipairs(BONUS) do
      if name:sub(1, #b[1]) == b[1] then for _, e in ipairs(b[2]) do effects[#effects + 1] = e end end
    end
    techs[name] = { count = t.count, time = t.time, ingredients = t.ingredients, prerequisites = t.prerequisites,
      unlocks = t.unlocks, effects = effects, enabled = true, hidden = false }
  end
  local entities = {}
  for _, m in ipairs(ent.machines) do
    local e = { name = m.name, type = TYPE_OF[m.name], item = m.name ~= "character" and m.name or nil,
      crafting_categories = m.crafting_categories, resource_categories = m.resource_categories, energy = m.energy, speed = 1 }
    if m.name == "lab" then e.lab_inputs = LAB_INPUTS end
    if m.name == "offshore-pump" then e.fluid = "water" end
    if m.name == "boiler" then e.fluid_in, e.fluid_out = "water", "steam" end
    if m.name == "steam-engine" then e.fluid_in = "steam" end
    if m.name == "character" then e.crafting_categories = { "crafting" }; e.resource_categories = { "basic-solid" } end
    entities[#entities + 1] = e
  end
  for _, o in ipairs(OTHER_ENTITIES) do entities[#entities + 1] = { name = o[1], type = o[2], item = o[1], energy = "none" } end
  local resources = {}
  for _, name in ipairs(sorted_keys(ent.resources)) do
    local r = ent.resources[name]
    if r.category ~= "ai3-offshore" then
      resources[#resources + 1] = { entity = name, category = r.category,
        products = { { type = r.category == "basic-fluid" and "fluid" or "item", name = name, amount = 1 } } }
    end
  end
  local items = {}
  for ty, list in pairs(ITEM_TYPES) do for _, n in ipairs(list) do items[n] = { type = ty } end end
  for n, v in pairs(FUEL) do items[n] = items[n] or { type = "item" } items[n].fuel_value = v end
  for name in pairs(recipes) do
    for _, p in ipairs(recipes[name].products) do
      if p.type ~= "fluid" and not items[p.name] then items[p.name] = { type = "item" } end
    end
  end
  for _, r in ipairs(resources) do
    local n = r.products[1].name
    if r.products[1].type == "item" and not items[n] then items[n] = { type = "item" } end
  end
  local dump = { recipes = recipes, techs = techs, entities = entities, resources = resources, items = items }
  if opts.reverse then
    dump.entities = rev(dump.entities)
    dump.resources = rev(dump.resources)
    for _, r in pairs(dump.recipes) do r.ingredients = rev(r.ingredients) end
  end
  if opts.mutate then opts.mutate(dump) end
  return dump
end

--- Exécutants d'aujourd'hui (comme script/ai3/general.lua) : la main, le laboratoire du QG, les fours du QG et les
--- foreuses des avant-postes (shared/team/config.lua : T.SMELTER, T.DRILL).
function F.opts()
  local T = require("shared.team.config")
  local function kind_of(res)
    for _, k in ipairs(T.OUTPOST_ORDER) do if T.outposts[k].resource == res then return k end end
    return nil
  end
  return { exec = { [T.SMELTER] = true, [T.DRILL] = true }, exec_roles = { main = true, labo = true },
    labs_unpowered = true, fuel_ok = function(item) return kind_of(item) ~= nil end }
end

--- État de départ d'une faction (kit de départ, fours du QG, gisements de base connus).
function F.start_state(opts)
  opts = opts or {}
  local T = require("shared.team.config")
  local stock = {}
  -- Lot KIT : opts.kit = "egal" : le kit RÉEL d'une faction (coffre vide, aucun four) ; défaut : le kit généreux des bancs.
  local egal = opts.kit == "egal"
  for _, it in ipairs(egal and T.start_kit or T.start_kit_generous) do stock[it[1]] = it[2] end
  local known = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do known[T.outposts[kind].resource] = true end
  for _, k in ipairs(opts.unknown or {}) do known[k] = nil end
  return { stock = stock, techs = opts.techs or {},
    built = { [T.SMELTER] = egal and T.start_smelters or T.start_smelters_generous }, known = known }
end

return F
