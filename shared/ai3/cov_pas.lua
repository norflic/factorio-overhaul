--[[
  Lot COUT-600 : COUVERTURE d'un gisement par pas (règles PURES, aucune API du moteur).

  Avant le lot, la couverture (script/ai3/capitalisation.lua, coverage) relisait TOUS les gisements à foreuses dans une seule pensée, une fois par
  cycle : 51 k instructions pour un gisement ordinaire de 377 tuiles et 40 foreuses, 382 k par gisement de 600 % (3 209 tuiles, 266 foreuses),
  donc environ 1,9 M à cinq gisements dans le même tick (budget d'une pensée : 0,6 M). Maintenant UN gisement par pensée au plus, le plus ancien
  dû après le curseur, chacun relu au plus toutes les Cp.EVERY ticks (le rythme d'avant : une fois par cycle de 12 pensées).

    Cp.covered(idx, drills, tkey) -> n : tuiles de minerai (idx = { [clé] = vrai }) sous la zone de minage d'au moins une foreuse
                                     { x, y, r } ; EXACTEMENT la boucle d'avant.
    Cp.next_due(ids, last, tick_of, tick, every) -> id ou nil : le premier identifiant de `ids` (liste TRIÉE) strictement après `last`
                                     (cyclique) dont la dernière lecture (`tick_of(id)`, nil : jamais) a au moins `every` ticks. Un gisement
                                     apparu ou disparu change la liste, jamais le curseur : `last` peut ne plus exister.
  Déterminisme : listes triées, comparaisons de chaînes, aucun pairs, aucune horloge.
]]

local Cp = {}

Cp.EVERY = 3000 -- ticks entre deux lectures d'un même gisement (cycle de 12 pensées de 300 ticks : 3 600)

function Cp.covered(idx, drills, tkey)
  local seen, n = {}, 0
  for _, dp in ipairs(drills) do
    local r = dp.r
    for x = math.floor(dp.x - r + 0.01), math.floor(dp.x + r - 0.01) do
      for y = math.floor(dp.y - r + 0.01), math.floor(dp.y + r - 0.01) do
        local k = tkey(x, y)
        if idx[k] and not seen[k] then seen[k] = true n = n + 1 end
      end
    end
  end
  return n
end

function Cp.next_due(ids, last, tick_of, tick, every)
  local n = #ids
  if n == 0 then return nil end
  every = every or Cp.EVERY
  -- premier rang strictement après le curseur (liste triée) ; sans curseur, le premier
  local start = 1
  if last ~= nil then
    start = n + 1
    for i = 1, n do
      if ids[i] > last then start = i break end
    end
  end
  for step = 0, n - 1 do
    local i = (start - 1 + step) % n + 1
    local t = tick_of(ids[i])
    if t == nil or tick - t >= every then return ids[i] end
  end
  return nil
end

return Cp
