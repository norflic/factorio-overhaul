--[[
  Mécaniques runtime des familles de déchiqueteurs (le reste est natif, en data) :
  - Couvée : à sa mort, une unité "couvée" libère E.families.brood.brood unités du palier inférieur.
  Coût : une recherche dans une table par mort (le bus partage on_entity_died avec le commandant,
  donc pas de filtre moteur possible ici).
]]

local Events = require("script.core.events")
local E = require("shared.content.enemies")

local children = {}   -- [nom d'unité couvée] = nom de l'enfant
local filters = {}
for _, kind in ipairs({ "biter", "spitter" }) do
  for tier = 2, E.TIERS do
    local name = E.unit_name(kind, tier, "brood")
    children[name] = E.brood_child(kind, tier)
    filters[#filters + 1] = { filter = "name", name = name }
  end
end

local OFFSETS = { { 0.8, 0 }, { -0.8, 0 }, { 0, 0.8 }, { 0, -0.8 } }

local function on_died(e)
  local entity = e.entity
  local child = children[entity.name]
  if not child then return end
  local surface, pos, force = entity.surface, entity.position, entity.force
  for i = 1, E.families.brood.brood do
    local o = OFFSETS[(i - 1) % #OFFSETS + 1]
    local p = surface.find_non_colliding_position(child, { x = pos.x + o[1], y = pos.y + o[2] }, 4, 0.5)
    if p then surface.create_entity({ name = child, position = p, force = force }) end
  end
end

Events.on(defines.events.on_entity_died, on_died)

return { filters = filters }
