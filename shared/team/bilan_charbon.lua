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

--- Lot charbon-dim (14/11, P0) : DIMENSIONNEMENT NOMINAL. Le besoin ne dépend plus d'aucun état de marche : toute machine à combustible
--- POSÉE de l'équipe (chaudières, fours, foreuses à brûleur, assembleurs à brûleur) compte à sa puissance maximale de prototype, avec
--- Bc.MARGE (+ 30 %) ; l'offre est le débit nominal (vitesse de minage du prototype ÷ temps de minage de la ressource) de TOUTES les foreuses
--- posées sur le combustible, sauf celles qui ne peuvent plus rien rendre (gisement épuisé, arrêtées par script ou par circuit). Avant :
--- foreuses et offre comptées seulement en marche, et sans marge : une usine à l'arrêt FAUTE de charbon semblait ne rien demander, et
--- l'extension n'arrivait qu'après la pénurie (cercle vicieux).
Bc.MARGE = 1.3

--- Une foreuse POSÉE du combustible compte à son débit nominal, sauf si elle ne peut plus rien rendre. S = defines.entity_status.
function Bc.drill_nominal(status, S)
  if S == nil or status == nil then return false end
  return status ~= S.no_minable_resources and status ~= S.disabled_by_script and status ~= S.disabled_by_control_behavior
end

--- Dimensionnement. consumers = { watts à pleine puissance } de toutes les machines à combustible posées ; drills = { objets/s nominaux } ;
--- fuel_j = énergie d'un objet de combustible ; marge (défaut Bc.MARGE). Rend { need = besoin avec marge, raw = besoin sans marge,
--- capacity = offre nominale, short = offre sous le besoin (vrai : agrandir l'extraction du combustible) }.
function Bc.dim(consumers, drills, fuel_j, marge)
  local c = Bc.cap(consumers, drills, fuel_j)
  local m = marge or Bc.MARGE
  local out = { raw = c.need, need = c.need * m, capacity = c.capacity }
  out.short = out.capacity < out.need
  return out
end

--- Ligne de journal [FO-CHARBON-DIM] (sans le préfixe) : équipe, besoin, offre, décision.
function Bc.line(team, d, minute, decision)
  return string.format("%s minute %d : besoin %.3f/s (brut %.3f, consommateurs %d), offre %.3f/s (foreuses %d), %s ; decision %s",
    tostring(team), minute or 0, d.need or 0, d.raw or 0, d.n_consumers or 0, d.capacity or 0, d.n_drills or 0,
    d.short and "offre < besoin" or "offre >= besoin", tostring(decision or "-"))
end

function Bc.room(cap) return cap ~= nil and cap.capacity < cap.need end

return Bc
