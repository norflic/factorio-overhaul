--[[
  Lot RECONSTRUIRE : lecture des prototypes du moteur par TYPE. `game.get_filtered_entity_prototypes` rend une LuaCustomTable : elle
  ne s'itère que par `pairs` (moteur réel, 29/10 : `next` y rend la clé « __self » et plante à la lecture). Les noms sont TRIÉS
  aussitôt : aucune décision ne dépend de l'ordre du moteur. Mémoire LOCALE aux prototypes (ils ne changent pas en cours de partie).
]]

local P = {}
local CACHE = {}

--- Noms triés des prototypes d'entité du type donné.
function P.names_of_type(ty)
  local c = CACHE[ty]
  if c then return c end
  local names = {}
  for name in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = ty } })) do names[#names + 1] = name end
  table.sort(names)
  CACHE[ty] = names
  return names
end

return P
