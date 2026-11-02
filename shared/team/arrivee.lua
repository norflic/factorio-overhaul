--[[
  Lot C4 PLATEAU 3 (1/11) : une tournee d'avant-poste dont le chemin echoue ALORS QUE le PNJ est deja dans l'avant-poste est arrivee.
  Mesure (banc nav1, graine 20261020, [FO-NAV-SERVICE], 14 tournees refusees « chemin introuvable » de 8 a 41 min) : 9 sur 14 a 4 a 7
  tuiles du but, but libre (find_non_colliding_position rend le but lui-meme), sol sans eau, des foreuses, fours et coffres tout
  autour : le PNJ est au milieu du champ et le pathfinder ne rend rien. Or Outposts.service, Outposts.extend et Outposts.fortify
  n'ont besoin d'aucune distance (ils agissent sur les entites de l'avant-poste par script). La tournee echouee laisse les fours
  pleins (Emerald, 44 fours a plaques « full_output » de 150 a 210 min) et les foreuses a combustion sans combustible (Azure,
  32 a 39 foreuses de fer de 30 a 120 min), d'ou le fer qui s'effondre et la spirale du combustible.
  PUR : aucune API Factorio ; le runtime donne la distance carree du PNJ au batiment de l'avant-poste le plus proche.
]]
local Ar = {}

Ar.KINDS = { service = true, extend = true, fortify = true }  -- taches qui agissent par script sur les entites de l'avant-poste
Ar.NEAR = 8                                                    -- tuiles du batiment le plus proche : le PNJ est dans l'avant-poste

--- Distance carree minimale d'un point (x, y) a une liste de points { x, y } ; nil si la liste est vide.
function Ar.nearest_d2(points, x, y)
  local best
  for _, p in ipairs(points or {}) do
    local dx, dy = p.x - x, p.y - y
    local d2 = dx * dx + dy * dy
    if best == nil or d2 < best then best = d2 end
  end
  return best
end

--- Le PNJ de cette tache est-il arrive (le chemin vers le but a echoue mais il est dans l'avant-poste) ?
function Ar.arrived(kind, d2)
  return Ar.KINDS[kind] == true and d2 ~= nil and d2 <= Ar.NEAR * Ar.NEAR
end

-- PNJ coincés (retour du DC du 2/11, point 7 : « entre foreuses thermiques et fours collés, ils ne bougent plus »).
Ar.STILL_TICKS = 2 * 3600   -- immobile depuis 2 min en marche : dégagé
Ar.STILL_MOVE = 0.5         -- tuiles : en deçà, le PNJ n'a pas bougé
Ar.GOAL_NEAR = 12           -- tuiles du but : un chemin refusé si près est un coincement, pas un but injoignable
Ar.FREE_RADIUS = 6          -- tuiles : rayon de recherche de la case libre
Ar.UNSTICK_MAX = 3          -- dégagements au plus par tâche (au-delà, la tâche est abandonnée comme avant)

--- Suivi d'immobilité : prev = { x, y, t } ou nil ; rend le nouvel état et vrai quand le PNJ est immobile depuis Ar.STILL_TICKS.
--- Un déplacement d'au moins Ar.STILL_MOVE remet l'horloge à zéro ; un dégagement la remet aussi (état neuf).
function Ar.still(prev, x, y, tick)
  if not prev then return { x = x, y = y, t = tick }, false end
  local dx, dy = x - prev.x, y - prev.y
  if dx * dx + dy * dy >= Ar.STILL_MOVE * Ar.STILL_MOVE then return { x = x, y = y, t = tick }, false end
  if tick - prev.t >= Ar.STILL_TICKS then return { x = x, y = y, t = tick }, true end
  return prev, false
end

--- Un chemin refusé à d2 (tuiles²) du but, après `done` dégagements de cette tâche : faut-il dégager le PNJ plutôt qu'abandonner ?
function Ar.free_due(d2_goal, done)
  return d2_goal ~= nil and d2_goal <= Ar.GOAL_NEAR * Ar.GOAL_NEAR and (done or 0) < Ar.UNSTICK_MAX
end

return Ar
