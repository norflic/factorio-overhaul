--[[
  Boîte à outils de génération de prototypes (étape data uniquement).

  Principe "zéro asset" : on réutilise les sprites vanilla (copie profonde, teinte, échelle) et on
  superpose les chiffres des signaux virtuels pour afficher le palier sur les icônes.
]]

local lib = {}

lib.PREFIX = "fo-"

function lib.copy(ptype, name)
  local src = data.raw[ptype] and data.raw[ptype][name]
  if not src then error("prototype vanilla introuvable : " .. ptype .. "/" .. name) end
  return table.deepcopy(src)
end

---------------------------------------------------------------------------------------------------
-- Icônes
---------------------------------------------------------------------------------------------------
local DIGIT = "__base__/graphics/icons/signal/signal_%d.png"

--- Icône teintée + numéro de palier (1 ou 2 chiffres) en haut à gauche.
function lib.tier_icons(base_icon, base_size, tint, tier, icon_mipmaps)
  local icons = { { icon = base_icon, icon_size = base_size, icon_mipmaps = icon_mipmaps, tint = tint } }
  if tier then
    local s = tostring(tier)
    local scale = 0.2 * (64 / 64) * (base_size == 256 and 4 or 1)
    local step = 6 * (base_size == 256 and 4 or 1)
    local x0 = -10 * (base_size == 256 and 4 or 1)
    for i = 1, #s do
      icons[#icons + 1] = {
        icon = string.format(DIGIT, tonumber(s:sub(i, i))),
        icon_size = 64,
        icon_mipmaps = 4,
        scale = scale,
        shift = { x0 + (i - 1) * step, x0 },
      }
    end
  end
  return icons
end

--- Retire icon/icon_size/icon_mipmaps au profit de icons.
function lib.set_icons(proto, icons)
  proto.icon, proto.icon_size, proto.icon_mipmaps = nil, nil, nil
  proto.icons = icons
end

---------------------------------------------------------------------------------------------------
-- Couleurs
---------------------------------------------------------------------------------------------------
function lib.lerp_color(a, b, t)
  return { r = a.r + (b.r - a.r) * t, g = a.g + (b.g - a.g) * t, b = a.b + (b.b - a.b) * t, a = 1 }
end

--- Dégradé multi-points : stops = { {t=0, c=...}, {t=1, c=...} }
function lib.gradient(stops, t)
  for i = 1, #stops - 1 do
    local s0, s1 = stops[i], stops[i + 1]
    if t <= s1.t then
      return lib.lerp_color(s0.c, s1.c, (t - s0.t) / (s1.t - s0.t))
    end
  end
  return stops[#stops].c
end

---------------------------------------------------------------------------------------------------
-- Parcours génériques
---------------------------------------------------------------------------------------------------
--- Multiplie tous les montants de dégâts (tables { amount = x, type = ... } sous une clé "damage").
function lib.scale_damage(t, factor, seen)
  seen = seen or {}
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if type(t.damage) == "table" and type(t.damage.amount) == "number" then
    t.damage.amount = t.damage.amount * factor
  end
  for _, v in pairs(t) do lib.scale_damage(v, factor, seen) end
end

--- Remplace le type de dégâts partout.
function lib.retype_damage(t, new_type, seen)
  seen = seen or {}
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if type(t.damage) == "table" and t.damage.type then t.damage.type = new_type end
  for _, v in pairs(t) do lib.retype_damage(v, new_type, seen) end
end

local function is_sprite_def(t)
  return t.filename ~= nil or t.filenames ~= nil or t.stripes ~= nil
end

--- Agrandit toutes les définitions de sprite (échelle et décalage) d'une copie profonde.
function lib.scale_sprites(t, factor, seen)
  seen = seen or {}
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if is_sprite_def(t) then
    t.scale = (t.scale or 1) * factor
    if type(t.shift) == "table" then
      t.shift = { (t.shift[1] or t.shift.x or 0) * factor, (t.shift[2] or t.shift.y or 0) * factor }
    end
  end
  for k, v in pairs(t) do
    if k ~= "shift" then lib.scale_sprites(v, factor, seen) end
  end
end

--- Teinte toutes les définitions de sprite (multiplie la teinte existante).
function lib.tint_sprites(t, tint, seen)
  seen = seen or {}
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if is_sprite_def(t) and not t.draw_as_shadow and not t.draw_as_light and not t.draw_as_glow then
    local c = t.tint or { r = 1, g = 1, b = 1, a = 1 }
    t.tint = { r = (c.r or c[1] or 1) * tint.r, g = (c.g or c[2] or 1) * tint.g, b = (c.b or c[3] or 1) * tint.b, a = c.a or c[4] or 1 }
  end
  for _, v in pairs(t) do lib.tint_sprites(v, tint, seen) end
end

function lib.scale_box(box, factor)
  return { { box[1][1] * factor, box[1][2] * factor }, { box[2][1] * factor, box[2][2] * factor } }
end

---------------------------------------------------------------------------------------------------
-- Recettes et technologies
---------------------------------------------------------------------------------------------------
function lib.recipe(name, ingredients, result, count, energy, extra)
  local r = {
    type = "recipe",
    name = name,
    enabled = false,
    ingredients = ingredients,
    energy_required = energy or 5,
    result = result,
    result_count = count or 1,
  }
  if extra then for k, v in pairs(extra) do r[k] = v end end
  return r
end

local SCIENCE = {
  "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack",
  "production-science-pack", "utility-science-pack", "space-science-pack",
}
lib.SCIENCE = SCIENCE

--- Liste d'ingrédients de science : packs = { "automation-science-pack", ... }
function lib.science(packs)
  local out = {}
  for _, p in ipairs(packs) do out[#out + 1] = { p, 1 } end
  return out
end

function lib.technology(spec)
  local t = {
    type = "technology",
    name = spec.name,
    localised_name = spec.localised_name,
    localised_description = spec.localised_description,
    icons = spec.icons,
    icon = spec.icon,
    icon_size = spec.icon_size,
    icon_mipmaps = spec.icon_mipmaps,
    effects = spec.effects or {},
    prerequisites = spec.prerequisites,
    unit = { count = spec.count, ingredients = lib.science(spec.packs), time = spec.time or 30 },
    order = spec.order,
  }
  if t.icons then t.icon, t.icon_size, t.icon_mipmaps = nil, nil, nil end
  return t
end

function lib.unlock(recipe)
  return { type = "unlock-recipe", recipe = recipe }
end

return lib
