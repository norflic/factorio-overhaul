--- Lot PURGE-FER-CHARBON (DC, 11/11 13 h 55 : « Plafonne strictement le nombre de foreuses de charbon allouées aux besoins réels combinés des
--- centrales électriques et des fours actifs, sans aucune sur-allocation préventive ») : PLAFOND UNIQUE du combustible. Il remplace la marge de
--- 40 % du planificateur (Bc.MARGIN), la retenue « fer d'abord » et son exception « combustible », et la réserve de 3 000 au stock du champ.
--- Règle pure : l'appelant (script/team/plafond_charbon.lua) lit en jeu les consommateurs (puissance des prototypes) et les foreuses du combustible.
local Bc = {}

--- Plafond. consumers = { watts } des chaudières et des brûleurs actifs (puissance de combustion lue aux prototypes, rendement compris) ;
--- drills = { objets/s } des foreuses posées sur le combustible ; fuel_j = énergie d'un objet de combustible (J).
--- Rend { need = objets/s brûlés, capacity = objets/s extraits }.
function Bc.cap(consumers, drills, fuel_j)
  local w, c = 0, 0
  for _, x in ipairs(consumers or {}) do w = w + math.max(0, x) end
  for _, x in ipairs(drills or {}) do c = c + math.max(0, x) end
  return { need = (fuel_j and fuel_j > 0) and w / fuel_j or 0, capacity = c }
end

--- Une foreuse (ou une bande) de combustible de plus n'est permise que tant que l'extraction posée reste SOUS le besoin réel.
function Bc.room(cap) return cap ~= nil and cap.capacity < cap.need end

return Bc
