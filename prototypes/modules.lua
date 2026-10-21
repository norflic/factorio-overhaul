-- Modules paliers 4 à 10 (vitesse, productivité, efficacité). Données : shared/content/modules.lua.

local lib = require("prototypes.lib")
local M = require("shared.content.modules")

local out = {}

for _, family in ipairs(M.ORDER) do
  local spec = M.families[family]
  local vanilla_top = data.raw.module[spec.vanilla[M.VANILLA_TIERS]]
  local vanilla_tech = data.raw.technology[spec.vanilla[M.VANILLA_TIERS]]
  for k = M.VANILLA_TIERS + 1, M.TIERS do
    local name = M.name(family, k)
    local t = (k - M.VANILLA_TIERS) / (M.TIERS - M.VANILLA_TIERS)
    local tint = lib.gradient(spec.tint, t)

    local item = table.deepcopy(vanilla_top)
    item.name = name
    item.tier = k
    item.effect = M.effect(family, k)
    item.order = string.format("a[%s]-z[fo-%02d]", family, k)
    item.localised_name = { "", { "item-name." .. spec.vanilla[1] }, " " .. k }
    item.localised_description = { "item-description." .. spec.vanilla[1] }
    local icons = lib.tier_icons(vanilla_top.icon, vanilla_top.icon_size, tint, k, vanilla_top.icon_mipmaps)
    -- Évolution visible (session 4) : la puce du module change de nature avec le palier, comme ses
    -- ingrédients (circuit avancé 6-7, processeur 8-9, cristal de résonance au 10).
    local chip = (k >= 10 and data.raw.item["uranium-235"]) or (k >= 8 and data.raw.item["processing-unit"])
      or (k >= 6 and data.raw.item["advanced-circuit"]) or nil
    if chip then
      icons[#icons + 1] = {
        icon = chip.icon, icon_size = chip.icon_size, icon_mipmaps = chip.icon_mipmaps,
        scale = 0.25 * 64 / chip.icon_size, shift = { 8, 8 },
        tint = k >= 10 and { r = 0.85, g = 0.45, b = 1.00 } or nil,
      }
    end
    lib.set_icons(item, icons)
    item.beacon_tint = { primary = tint, secondary = tint }
    -- limitation (productivité) : complétée en data-final-fixes, une fois toutes les recettes connues
    out[#out + 1] = item

    local r = M.recipe(family, k)
    out[#out + 1] = lib.recipe(name, r.ingredients, name, 1, r.energy)

    local tech = M.technology(family, k)
    out[#out + 1] = lib.technology({
      name = name,
      localised_name = { "", { "technology-name." .. spec.vanilla[1] }, " " .. k },
      localised_description = { "technology-description." .. spec.vanilla[1] },
      icons = lib.tier_icons(vanilla_tech.icon, vanilla_tech.icon_size, tint, k, vanilla_tech.icon_mipmaps),
      effects = { lib.unlock(name) },
      prerequisites = { tech.prerequisite },
      count = tech.count,
      packs = tech.packs,
      time = tech.time,
      order = string.format("i-fo-%s-%02d", family, k),
    })
  end
end

data:extend(out)
