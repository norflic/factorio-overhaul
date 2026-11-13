--[[
  Mécaniques runtime des familles de déchiqueteurs (le reste est natif, en data) :
  - Couvée : à sa mort, une unité "couvée" libère E.families.brood.brood unités du palier inférieur.
  Coût : une recherche dans une table par mort (le bus partage on_entity_died avec le commandant,
  donc pas de filtre moteur possible ici).
]]

local Events = require("script.core.events")
local E = require("shared.content.enemies")
local Storage = require("script.core.storage")
local Cv = require("shared.combat.couvee")

Storage.declare("couvee", function() return { file = Cv.file() } end)

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

-- s43 MEGA-BOURDON (tranche 2) : les naissances passent par une file plafonnée (shared/combat/couvee.lua : BUDGET_TICK par tick,
-- ATTENTE_MAX en attente, le surplus abandonné) ; la cascade d'une arme de zone (8 192 unités, 24 s de gel au banc du 13/11) est bornée.
local function file()
  local ns = Storage.ns("couvee")
  return ns and ns.file
end

local function on_died(e)
  local entity = e.entity
  local child = children[entity.name]
  if not child then return end
  local f = file()
  if not f then return end
  local surface, pos, force = entity.surface, entity.position, entity.force
  for i = 1, E.families.brood.brood do
    local o = OFFSETS[(i - 1) % #OFFSETS + 1]
    Cv.ajouter(f, { n = child, s = surface.index, x = pos.x + o[1], y = pos.y + o[2], f = force.name })
  end
end

local function naissances()
  local f = file()
  if not f or Cv.taille(f) == 0 then return end
  for _, b in ipairs(Cv.tranche(f, Cv.BUDGET_TICK)) do
    local surface, force = game.surfaces[b.s], game.forces[b.f]
    local p = surface and force and surface.find_non_colliding_position(b.n, { x = b.x, y = b.y }, 4, 0.5)
    if p then surface.create_entity({ name = b.n, position = p, force = force }) end
  end
end
Events.on_nth_tick(1, naissances)

-- Lot MORTS : le type des unités couvées (noms de `children`, lus aux prototypes), toutes forces.
local brood_names = {}
for _, f in ipairs(filters) do brood_names[#brood_names + 1] = f.name end
Events.on_died(on_died, { noms = brood_names })

return { filters = filters }
