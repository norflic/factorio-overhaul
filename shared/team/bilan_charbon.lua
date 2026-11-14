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
--- Lot FIX-P1 : une foreuse du combustible ne compte dans la capacité que si elle produit (status = working) ou attend la place de sa
--- sortie (waiting_for_space_in_destination) ; à sec, sans courant, sans combustible ou à l'arrêt, elle ne rend rien. S = defines.entity_status.
function Bc.drill_counts(status, S)
  return S ~= nil and status ~= nil and (status == S.working or status == S.waiting_for_space_in_destination)
end

--- Lot s45 charbon-besoin : besoin NOMINAL. Une chaudière ou un four à brûleur posé compte toujours à pleine puissance de prototype,
--- actif ou vide (un four vide brûle 0 : la mesure seule faisait croire le charbon suffisant et laissait les fours éteints) ; une autre
--- machine à brûleur (foreuse) compte si elle marche ou attend son combustible. etype = type d'entité, S = defines.entity_status.
function Bc.consumer_counts(etype, status, S)
  if etype == "boiler" or etype == "furnace" then return true end
  return S ~= nil and status ~= nil and (status == S.working or status == S.no_fuel)
end

--- Besoin retenu : le plus grand de la mesure (objets/s) et du nominal (objets/s).
function Bc.need(measured, nominal) return math.max(measured or 0, nominal or 0) end

function Bc.room(cap) return cap ~= nil and cap.capacity < cap.need end

return Bc
