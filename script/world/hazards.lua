--[[
  Effets des biomes sur les personnages (joueurs et agents riches) : poison du marais, soin de la plaine
  de cristal. Données : shared/content/world.lua.

  Coût : un contrôle de tuile par personnage toutes les PERIOD ticks (joueurs : quelques-uns ; agents :
  via la voie de l'ordonnanceur, donc étalé). Pas de balayage de zone.

  Ingénieurs de faction EXEMPTÉS (décision session 3) : en moteur réel, le Consortium Émeraude a perdu
  5 ingénieurs au poison du marais en 10 min. Le pathfinder moteur ne pondère pas les tuiles : l'IA ne
  peut pas éviter le marais, la pénalité serait injuste et ruinerait son économie. Les biomes restent un
  défi pour le joueur et ses compagnons.
]]

local Events = require("script.core.events")
local Scheduler = require("script.core.scheduler")
local Registry = require("script.companion.registry")
local W = require("shared.content.world")

local PERIOD = 30
local LANE = "fo-hazard"

local hazard_tiles = {}
for _, b in ipairs(W.biomes) do
  if b.hazard then hazard_tiles[b.name] = true end
end

local function apply(character, tick_dt)
  if not (character and character.valid) then return end
  local pos = character.position
  local tile = character.surface.get_tile(math.floor(pos.x), math.floor(pos.y))
  local name = tile.name
  if not hazard_tiles[name] then return end
  local h = W.hazard_for_tile(name, tick_dt)
  if not h then return end
  if h.kind == "damage" then
    character.damage(h.amount, "neutral", h.type)
  elseif h.kind == "heal" then
    local max = character.prototype.max_health
    if character.health < max then character.health = math.min(max, character.health + h.amount) end
  end
end

-- Joueurs : peu nombreux, contrôle direct.
Events.on_nth_tick(PERIOD, function()
  for _, player in pairs(game.connected_players) do
    apply(player.character, PERIOD)
  end
end)

-- Agents riches : voie dédiée de même période, charge étalée.
Scheduler.define_lane(LANE, PERIOD, function(id)
  local agent = Registry.get(id)
  if not agent then
    Scheduler.remove(LANE, id)
    return
  end
  apply(agent.entity, PERIOD)
end)

local function track(agent)
  if agent.faction then return end -- ingénieurs de faction : acclimatés (voir en-tête)
  Scheduler.add(LANE, agent.id)
end
Registry.on_spawned(track)
Registry.on_removed(function(agent) Scheduler.remove(LANE, agent.id) end)

return {}
