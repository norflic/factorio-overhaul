--[[
  Lot S42 TAPIS-TEINTES (chantier 2.4 du DC) : passe du stade data, EN DERNIER (data-final-fixes), sur tous les prototypes de
  tapis, de souterrains et de répartiteurs. Tout palier dont l'aspect (planches + teintes + icône) est déjà celui d'un palier
  plus lent de la même sorte reçoit la teinte de son rang (shared/content/tapis_teintes.lua) sur ses couches de sprites, sur son
  icône et sur celle de l'objet qui le pose, et une animation proportionnelle à sa vitesse. Aucun nom en dur : les sortes sont
  des TYPES de prototypes, les paliers des vitesses. Aucune planche ajoutée (rien hors de git, décision D-6 sans objet ici).
  En 0.7.96 le mod n'a aucun palier propre : les trois paliers du jeu ont chacun leurs planches, la passe ne teinte rien.
]]

local T = require("shared.content.tapis_teintes")

local KINDS = { "transport-belt", "underground-belt", "splitter" }

local entries, protos = {}, {}
for _, kind in ipairs(KINDS) do
  local names = {}
  for name in pairs(data.raw[kind] or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local p = data.raw[kind][name]
    if type(p.speed) == "number" then
      local key = kind .. "/" .. name
      entries[#entries + 1] = { key = key, kind = kind, speed = p.speed, sig = T.signature(p) }
      protos[key] = p
    end
  end
end

local plan, census = T.plan(entries)

-- Objets qui posent une entité : nom de l'objet trié, jamais l'ordre de pairs.
local function items_placing(name)
  local out = {}
  for _, group in ipairs({ "item", "item-with-entity-data" }) do
    local names = {}
    for n in pairs(data.raw[group] or {}) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do
      local it = data.raw[group][n]
      if it.place_result == name then out[#out + 1] = it end
    end
  end
  return out
end

local keys = {}
for key in pairs(plan) do keys[#keys + 1] = key end
table.sort(keys)
for _, key in ipairs(keys) do
  local p, tint = protos[key], plan[key].tint
  -- Les planches sont souvent une table PARTAGÉE avec le palier d'origine : copie avant de teindre.
  for _, f in ipairs(T.FIELDS) do
    if p[f] then p[f] = table.deepcopy(p[f]) end
  end
  if p.icons then p.icons = table.deepcopy(p.icons) end
  T.apply(p, tint)
  local set = p.belt_animation_set and p.belt_animation_set.animation_set
  p.animation_speed_coefficient = T.coefficient(p.speed, set and set.frame_count)
  for _, it in ipairs(items_placing(p.name)) do
    if it.icons then it.icons = table.deepcopy(it.icons) end
    T.apply_icon(it, tint)
  end
end

-- Contrôle après pose : plus aucun doublon d'aspect dans une même sorte.
local left = {}
do
  local again = {}
  for _, e in ipairs(entries) do
    again[#again + 1] = { key = e.key, kind = e.kind, speed = e.speed, sig = T.signature(protos[e.key]) }
  end
  local plan2 = T.plan(again)
  for key in pairs(plan2) do left[#left + 1] = key end
  table.sort(left)
end

log(string.format("[FO-TAPIS-TEINTES] %d prototype(s), %d palier(s) de vitesse ; aspects partagés : %d ; teintés : %s ; restants : %s",
  census.entries, census.tiers, #census.shared, #keys > 0 and table.concat(keys, ", ") or "aucun",
  #left > 0 and table.concat(left, ", ") or "aucun"))
