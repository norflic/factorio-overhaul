--[[
  RECETTES PAR LOTS (lot MOD-2, D-15, Q-M2 a). Étape data-final-fixes : la liste des recettes doit être COMPLÈTE.

  Pour chaque recette (non cachée) d'une catégorie qu'une machine d'assemblage À MODULES sait faire (assembleurs,
  usine chimique, raffinerie, centrifugeuse : celles que les modules multipliés peuvent porter au-delà de 60
  fabrications par seconde), deux copies : lot × 10 et lot × 100 (shared/content/recipe_lots.lua). Ingrédients,
  produits et durée multipliés ; même catégorie (toute machine qui fait la recette fait ses lots) ; cachées des menus,
  jamais fabricables à la main, désactivées ici : le script les active avec la recette de base (script/modules/lots.lua ;
  aucune technologie n'est touchée : le calcul des époques lit leurs effets, shared/levels/config.lua).
  Fours : non concernés ici (un four choisit sa recette par l'objet entré, set_recipe ne s'y applique pas ; voir
  fo-logs\2026-10-25_MOD2\NOTES.md).
  Modules de productivité : la limitation est étendue aux lots des recettes qu'elle admet.
]]

local R = require("shared.content.recipe_lots")

local DIGIT = "__base__/graphics/icons/signal/signal_%d.png"
local ITEM_TYPES = { "item", "ammo", "capsule", "gun", "item-with-entity-data", "item-with-label", "item-with-inventory",
  "blueprint-book", "item-with-tags", "selection-tool", "blueprint", "copy-paste-tool", "deconstruction-item",
  "upgrade-item", "module", "rail-planner", "spidertron-remote", "tool", "armor", "repair-tool", "mining-tool" }

local function item_proto(name)
  for _, t in ipairs(ITEM_TYPES) do
    local p = data.raw[t] and data.raw[t][name]
    if p then return p end
  end
  return nil
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

-- Catégories des machines d'assemblage à modules (sans recette fixe).
local categories = {}
for _, name in ipairs(sorted_keys(data.raw["assembling-machine"])) do
  local m = data.raw["assembling-machine"][name]
  local slots = m.module_specification and m.module_specification.module_slots or 0
  if slots > 0 and not m.fixed_recipe then
    for _, c in ipairs(m.crafting_categories or {}) do categories[c] = true end
  end
end

--- Couches d'icône d'un prototype (icons ou icon), copiées, icon_size reporté sur chaque couche.
local function layers_of(p)
  if not p then return nil end
  if p.icons then
    local out = {}
    for _, l in ipairs(p.icons) do
      local c = R.copy(l)
      c.icon_size = c.icon_size or p.icon_size
      c.icon_mipmaps = c.icon_mipmaps or p.icon_mipmaps
      out[#out + 1] = c
    end
    return out
  end
  if p.icon then
    return { { icon = p.icon, icon_size = p.icon_size, icon_mipmaps = p.icon_mipmaps } }
  end
  return nil
end

--- Nom affiché de la recette de base (règle du moteur : nom de la recette, sinon celui du produit principal).
local function display_name(base, blk)
  if base.localised_name then return R.copy(base.localised_name) end
  local p = R.main_product(blk)
  if not p then return { "recipe-name." .. base.name } end
  if p.type == "fluid" then
    local f = data.raw.fluid[p.name]
    return (f and f.localised_name and R.copy(f.localised_name)) or { "fluid-name." .. p.name }
  end
  local it = item_proto(p.name)
  if it and it.localised_name then return R.copy(it.localised_name) end
  if it and it.place_result then return { "entity-name." .. it.place_result } end
  if it and it.placed_as_equipment_result then return { "equipment-name." .. it.placed_as_equipment_result } end
  return { "item-name." .. p.name }
end

--- Icônes du lot : celles de la recette (ou du produit principal) et le chiffre du lot en bas, centré. Chiffres côte à
--- côte sans se chevaucher (première image, MOD-2 : « 100 » serré à 5 unités pour des chiffres de ~10 se lisait « 10 »).
local function lot_icons(base, blk, k)
  local layers = layers_of(base)
  if not layers then
    local p = R.main_product(blk)
    if p then layers = layers_of(p.type == "fluid" and data.raw.fluid[p.name] or item_proto(p.name)) end
  end
  if not layers or not layers[1].icon_size then return nil end
  local f = layers[1].icon_size / 64
  local s = tostring(k)
  local step = 7.5 * f
  local x0 = -(#s - 1) * step / 2
  for i = 1, #s do
    layers[#layers + 1] = {
      icon = string.format(DIGIT, tonumber(s:sub(i, i))),
      icon_size = 64,
      icon_mipmaps = 4,
      scale = 0.14 * f,
      shift = { x0 + (i - 1) * step, 11 * f },
    }
  end
  return layers
end

--- Un objet non empilable (pile de 1, ou drapeau « not-stackable ») dans la recette ? Moteur réel (MOD-2, E151) :
--- « Recipe item-product "modular-armor" is not stackable but has a max count of 10 » refuse le chargement.
local function unstackable(blk)
  for _, list in ipairs({ blk.ingredients, blk.results }) do
    for _, x in ipairs(list) do
      if x.type ~= "fluid" then
        local it = item_proto(x.name)
        if it then
          if (it.stack_size or 1) <= 1 then return x.name end
          for _, fl in ipairs(it.flags or {}) do if fl == "not-stackable" then return x.name end end
        end
      end
    end
  end
  return nil
end

local out, skipped, made = {}, {}, {}
local nbase = 0
for _, name in ipairs(sorted_keys(data.raw.recipe)) do
  local base = data.raw.recipe[name]
  local cat = base.category or "crafting"
  local def = base.normal or base.expensive or base
  local hidden = (base.hidden or (type(def) == "table" and def.hidden)) and true or false
  if categories[cat] and not R.is_lot(name) and not hidden and type(def) == "table" then
    nbase = nbase + 1
    local blk = R.block_of(def)
    local single = unstackable(blk)
    if single then skipped[#skipped + 1] = name .. " (objet non empilable : " .. single .. ")" end
    for _, k in ipairs(single and {} or R.SIZES) do
      local r, why = R.lot_recipe(base, k)
      if r then
        r.localised_name = { "fo-lots.lot-name", display_name(base, blk), tostring(k) }
        r.localised_description = { "fo-lots.lot-desc", tostring(k) }
        local icons = lot_icons(base, blk, k)
        if icons then
          r.icons = icons
        else
          skipped[#skipped + 1] = name .. " x" .. k .. " (icone)"
          r = nil
        end
      else
        skipped[#skipped + 1] = name .. " x" .. k .. " (" .. why .. ")"
      end
      if r then
        out[#out + 1] = r
        made[name] = made[name] or {}
        made[name][#made[name] + 1] = r.name
      end
    end
  end
end
if #out > 0 then data:extend(out) end

-- Modules de productivité : la limitation suit la recette de base (même économie, même droit).
local nlim = 0
for _, mname in ipairs(sorted_keys(data.raw.module)) do
  local m = data.raw.module[mname]
  for _, key in ipairs({ "limitation", "limitation_blacklist" }) do
    local list = m[key]
    if type(list) == "table" and #list > 0 then
      local present = {}
      for _, r in ipairs(list) do present[r] = true end
      local n0 = #list
      for i = 1, n0 do
        for _, lot in ipairs(made[list[i]] or {}) do
          if not present[lot] then
            list[#list + 1] = lot
            present[lot] = true
            nlim = nlim + 1
          end
        end
      end
    end
  end
end

local cats = sorted_keys(categories)
log("[FO-LOTS] recettes par lots : " .. #out .. " lot(s) pour " .. nbase .. " recette(s) de base ; categories "
  .. table.concat(cats, ",") .. " ; " .. #skipped .. " ecarte(s)" .. (#skipped > 0 and (" : " .. table.concat(skipped, " ; ")) or "")
  .. " ; " .. nlim .. " ajout(s) aux limitations de productivite")
