--[[
  Lot EXPANSION, côté RUNTIME (règles pures : shared/ai3/besoin.lua et shared/ai3/expansion.lua) : ce que le cerveau ne sait
  pas lire hors du jeu.
    - Bx.drill_rates() : objets par minute d'UNE foreuse de chaque type d'avant-poste, lus sur les PROTOTYPES
      (vitesse de minage de la foreuse de T.DRILL ÷ temps de minage de la ressource × 60). Cache LOCAL tiré des seuls
      prototypes (constants pendant la partie), jamais dans global.
    - Bx.growth(f, w, threatened) : croissance du capital de l'équipe (‰ par minute), formule de la capitalisation
      (Ca.growth, shared/ai3/capitalisation.lua, lue sans la modifier) sur l'état de la capitalisation de l'équipe (f.team.capi) ;
      0 quand la capitalisation est éteinte ou n'a encore rien décidé (aucune croissance supposée).
  Aucun nom du jeu : les types viennent de T (shared/team/config.lua).
]]

local T = require("shared.team.config")
local Ca = require("shared.ai3.capitalisation")

local Bx = {}

local function get(obj, k)
  local ok, v = pcall(function() return obj[k] end)
  if ok then return v end
  return nil
end

local rates = nil

--- Débit d'une foreuse par type d'avant-poste (objets/min) ; nil si les prototypes manquent.
function Bx.drill_rates()
  if rates then return rates end
  local protos = game and game.entity_prototypes
  local drill = protos and get(protos, T.DRILL)
  local speed = drill and get(drill, "mining_speed")
  if not speed then return nil end
  local out = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local res = get(protos, T.outposts[kind].resource)
    local props = res and get(res, "mineable_properties")
    local time = props and get(props, "mining_time")
    if time and time > 0 then out[kind] = 60 * speed / time end
  end
  rates = out
  return out
end

--- Croissance du capital (‰ par cycle d'une minute), bornée par Ca.G_MAX. Rend 0 sans état de capitalisation.
function Bx.growth(f, w, threatened)
  local cs = f and f.team and f.team.capi
  if not (cs and cs.decisions and cs.decisions > 0) then return 0 end
  local ch = Ca.character(f.traits, w, threatened)
  return Ca.growth(ch, cs.st or {}, true, Ca.CYCLE_MIN, cs.lag)
end

return Bx
