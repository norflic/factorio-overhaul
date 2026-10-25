-- Modules paliers 4 à 10 (vitesse, productivité, efficacité). Données : shared/content/modules.lua.
-- Lot MOD-1 (D-15, 24/10) : effets des modules de vitesse vanilla (paliers 1 à 3) réécrits ; modules MULTIPLICATIFS :
-- balise cachée et modules de complément cachés (shared/content/module_mult.lua) ; emplacements de modules du
-- niveau 1 des familles à niveaux qui en ont (shared/levels/config.lua, L.module_slots).

local lib = require("prototypes.lib")
local M = require("shared.content.modules")
local MM = require("shared.content.module_mult")
local L = require("shared.levels.config")
-- Lot MOD-V : icônes propres des 30 modules et de leurs 30 technologies (forme = type, couleurs = âge qui débloque le
-- palier, chiffre romain gravé), générées par tools/render/pieces/modules/icones.py ; teintes de balise assorties.
local ICONES = require("__factorio-overhaul__/graphics/modules/icons")
local DIR_ICONES = "__factorio-overhaul__/graphics/modules/"

--- Pose l'icône générée de l'objet ou de la technologie `name` (sans couche ni teinte : une seule image par prototype).
local function poser_icone(proto, spec)
  proto.icons = nil
  proto.icon = DIR_ICONES .. spec.fichier
  proto.icon_size = spec.icon_size
  proto.icon_mipmaps = spec.icon_mipmaps
end

local out = {}

-- Paliers vanilla : effets réécrits quand la famille le demande (vitesse, D-15) ; description de la règle pour tous ;
-- icônes et teintes de balise du lot MOD-V (objets et technologies vanilla).
for _, family in ipairs(M.ORDER) do
  local spec = M.families[family]
  for k = 1, M.VANILLA_TIERS do
    local item = data.raw.module[spec.vanilla[k]]
    if item then
      if spec.vanilla_overridden then item.effect = M.effect(family, k) end
      item.localised_description = { "", { "item-description." .. spec.vanilla[1] }, "\n", { "fo-mm.module-desc-" .. family } }
      local ic = ICONES.objets[spec.vanilla[k]]
      poser_icone(item, ic)
      item.beacon_tint = table.deepcopy(ic.beacon_tint)
    end
    local tech = data.raw.technology[spec.vanilla[k]]
    if tech then poser_icone(tech, ICONES.technos[spec.vanilla[k]]) end
  end
end

for _, family in ipairs(M.ORDER) do
  local spec = M.families[family]
  local vanilla_top = data.raw.module[spec.vanilla[M.VANILLA_TIERS]]
  for k = M.VANILLA_TIERS + 1, M.TIERS do
    local name = M.name(family, k)

    local item = table.deepcopy(vanilla_top)
    item.name = name
    item.tier = k
    item.effect = M.effect(family, k)
    item.order = string.format("a[%s]-z[fo-%02d]", family, k)
    item.localised_name = { "", { "item-name." .. spec.vanilla[1] }, " " .. k }
    -- Lot MOD-V : icône propre (avant : icône vanilla du palier 3 teintée, chiffre et puce superposés).
    local ic = ICONES.objets[name]
    poser_icone(item, ic)
    item.localised_description = { "", { "item-description." .. spec.vanilla[1] }, "\n", { "fo-mm.module-desc-" .. family } }
    item.beacon_tint = table.deepcopy(ic.beacon_tint)
    -- limitation (productivité) : complétée en data-final-fixes, une fois toutes les recettes connues
    out[#out + 1] = item

    local r = M.recipe(family, k)
    out[#out + 1] = lib.recipe(name, r.ingredients, name, 1, r.energy)

    local tech = M.technology(family, k)
    out[#out + 1] = lib.technology({
      name = name,
      localised_name = { "", { "technology-name." .. spec.vanilla[1] }, " " .. k },
      localised_description = { "technology-description." .. spec.vanilla[1] },
      icon = DIR_ICONES .. ICONES.technos[name].fichier,
      icon_size = ICONES.technos[name].icon_size,
      icon_mipmaps = ICONES.technos[name].icon_mipmaps,
      effects = { lib.unlock(name) },
      prerequisites = { tech.prerequisite },
      count = tech.count,
      packs = tech.packs,
      time = tech.time,
      order = string.format("i-fo-%s-%02d", family, k),
    })
  end
end

---------------------------------------------------------------------------------------------------
-- Modules MULTIPLICATIFS (lot MOD-1) : modules de complément cachés et balise cachée (MOD-0, F192).
---------------------------------------------------------------------------------------------------
-- Modules de complément : ±2^bit centièmes par effet (shared/content/module_mult.lua). Cachés, sans recette, sans
-- limitation (le script ne leur donne de la productivité que si la règle le demande), jamais dans un inventaire du
-- joueur : seule la balise cachée les porte.
local CATEGORY = { speed = "speed", consumption = "effectivity", productivity = "productivity" }
local ICON_OF = { speed = "speed-module", consumption = "effectivity-module", productivity = "productivity-module" }
for _, m in ipairs(MM.all_modules()) do
  local src = data.raw.module[ICON_OF[m.effect]]
  out[#out + 1] = {
    type = "module",
    name = m.name,
    localised_name = { "fo-mm.complement-name", { "fo-mm.effect-" .. m.effect }, (m.sign > 0 and "+" or "-") .. tostring(2 ^ m.bit) },
    localised_description = { "fo-mm.complement-desc" },
    icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps,
    flags = { "hidden" },
    subgroup = "module",
    category = CATEGORY[m.effect],
    tier = 1,
    order = "z[fo-mm]-" .. m.name,
    stack_size = 50,
    effect = { [m.effect] = { bonus = m.value } },
  }
end

-- Balise cachée : énergie void, boîte de 0,2 tuile sans collision, zone 0,3 (n'agit que sur la machine sous elle,
-- machines collées comprises : MOD-0, R3), invisible, non sélectionnable, hors carte, indestructible par le script.
do
  local EMPTY = { filename = "__core__/graphics/empty.png", priority = "extra-high", width = 1, height = 1 }
  local b = lib.copy("beacon", "beacon")
  b.name = MM.BEACON
  b.localised_name = { "fo-mm.beacon-name" }
  b.localised_description = { "fo-mm.beacon-desc" }
  b.flags = { "placeable-neutral", "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable",
    "not-selectable-in-game", "hidden", "not-upgradable", "not-in-kill-statistics", "hide-alt-info", "no-copy-paste",
    "no-automated-item-removal", "no-automated-item-insertion", "not-repairable", "not-flammable" }
  b.minable = nil
  b.placeable_by = nil
  b.fast_replaceable_group = nil
  b.next_upgrade = nil
  b.collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } }
  b.collision_mask = {}
  b.selection_box = nil
  b.drawing_box = { { -0.1, -0.1 }, { 0.1, 0.1 } }
  b.energy_source = { type = "void" }
  b.energy_usage = "1W"
  b.supply_area_distance = 0.3
  b.distribution_effectivity = 1
  b.module_specification = { module_slots = MM.BEACON_SLOTS }
  b.allowed_effects = { "speed", "productivity", "consumption", "pollution" }
  b.graphics_set = nil
  b.base_picture = EMPTY
  b.animation = { filename = "__core__/graphics/empty.png", priority = "extra-high", width = 1, height = 1, frame_count = 1 }
  b.animation_shadow = nil
  b.radius_visualisation_picture = nil
  b.water_reflection = nil
  b.corpse = nil
  b.dying_explosion = nil
  b.damaged_trigger_effect = nil
  b.vehicle_impact_sound = nil
  b.working_sound = nil
  b.open_sound = nil
  b.close_sound = nil
  b.alert_when_damaged = false
  b.map_color = nil
  b.resistances = nil
  out[#out + 1] = b
end

-- Emplacements de modules du NIVEAU 1 des familles à niveaux qui en ont (Q-B2 du DC : 5 au niveau 1, puis +1 par
-- niveau ; foreuse et assembleur). Le niveau 1 est le prototype vanilla : SEUL module_slots y est réécrit, avant la
-- génération des niveaux (prototypes/levels, requis après ce fichier par data.lua), qui en hérite et pose les suivants.
for _, f in ipairs(L.families) do
  local slots = L.module_slots(f, 1)
  local p = slots and data.raw[f.type] and data.raw[f.type][f.base]
  if p then
    p.module_specification = p.module_specification or {}
    p.module_specification.module_slots = slots
  end
end

data:extend(out)
