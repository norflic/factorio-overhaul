--[[
  Caractère des factions (lot IA2-0) : exécution des tirages purs de shared/faction/traits.lua.

  - Au lancement d'une guerre (script/faction/war.lua) : personnalités réparties par la graine de la carte
    (Character.personalities), puis, par faction, flux, 8 traits et premier multiplicateur du seuil d'attaque
    (Character.found, origine « graine »).
  - PARTIE EXISTANTE (guerre lancée avant IA2-0, sans traits) : la personnalité écrite dans la sauvegarde est
    GARDÉE ; les traits sont tirés UNE fois, à la première lecture du caractère (Character.of), de la même graine
    et autour de cette personnalité (origine « migration »), puis stockés : rechargements et pensées suivantes
    relisent les mêmes nombres. Aucune migration de schéma n'est nécessaire (champ absent = à tirer).
  - Chaque attaque lancée contre une FACTION tire le multiplicateur du seuil de la suivante (Character.redraw).

  État dans la faction (nombres seulement) : f.rng = { seed, state, draws }, f.traits (pour mille),
  f.traits_origin, f.attack_jitter (pour mille).
]]

local Tr = require("shared.faction.traits")
local State = require("script.faction.state")
local Journal = require("script.faction.journal")

local Character = {}

--- Graine de la carte de la guerre en cours (0 sans surface).
function Character.map_seed(surface)
  if not surface then
    local war = State.war()
    surface = war and war.surface and game.surfaces[war.surface] or nil
  end
  return surface and surface.map_gen_settings.seed or 0
end

--- Personnalités des n factions d'une nouvelle guerre (permutation des archétypes tirée de la graine).
function Character.personalities(surface, n)
  return Tr.personalities(Character.map_seed(surface), n)
end

--- Tire et stocke le caractère d'une faction (flux de la faction : sel = son numéro), puis le publie.
function Character.found(f, map_seed, origin, tick)
  local st, traits, jitter = Tr.found(map_seed, f.id, f.personality)
  f.rng, f.traits, f.traits_origin, f.attack_jitter = st, traits, origin, jitter
  Journal.foundation(f, tick or game.tick, origin, Tr.ORDER)
end

--- Caractère effectif d'une faction (tire les traits d'une partie existante à la première lecture).
function Character.of(f)
  if not f.traits then Character.found(f, Character.map_seed(), "migration") end
  return Tr.character(f.personality, f.traits)
end

--- Une attaque contre une faction est partie : seuil de la suivante tiré du flux de la faction.
function Character.redraw(f)
  if not f.rng then Character.of(f) end
  f.attack_jitter = Tr.jitter(f.rng)
  return f.attack_jitter
end

return Character
