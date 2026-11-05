--[[
  Lot REARMEMENT (5/11, revue-danger puis lead) : les PNJ ne rechargeaient JAMAIS leur arme. PUR : aucune API Factorio, aucun nom d'objet ;
  l'appelant (script/team/worker.lua, dépôt au QG) passe des nombres. Testé hors jeu : tests/rearmement_test.lua (mutants) et
  tests/rearmement_moteur_test.lua (moteur simulé, votre équipe et une faction).

  Chaîne lue dans le code (main a85ed80b) : seul le recrutement remplit l'emplacement des munitions (Worker.recruit, 10 chargeurs) ; `take`
  écrit dans le sac, et le dépôt au QG (deposit_all) vide le sac au coffre en ne gardant dans l'emplacement que la dotation de 10, sans jamais
  y AJOUTER ; seule la fabrication à la main d'un chargeur l'y met (F29). Un PNJ qui a tiré ses 10 chargeurs reste à arme vide : la porte et la
  place de marché le disent désarmé (Board.has_ammo), il fuit à l'approche (Re.decide, « desarme ») et ne prend plus la garde.

  Règle (Ra.take) : au dépôt au QG, l'emplacement est complété jusqu'à la dotation avec des chargeurs pris au coffre, sans jamais faire
  descendre le coffre sous le PLANCHER de la défense (Ra.floor : la réserve minimale de munitions et la part urgente des tourelles : les
  tourelles d'abord). Déterminisme : entiers, aucun hasard, aucune horloge, aucun `pairs`.
]]

local Ra = {}

local function num(x)
  if type(x) ~= "number" or x ~= x or x < 0 then return 0 end
  return x
end

--- Chargeurs à prendre au coffre pour l'emplacement. slot = chargeurs dans l'emplacement, keep = dotation, stock = chargeurs au coffre,
--- floor = plancher de la défense. Rend 0 si l'emplacement est plein ou si le coffre n'a rien au-dessus du plancher.
function Ra.take(slot, keep, stock, floor)
  slot, keep, stock, floor = num(slot), num(keep), num(stock), num(floor)
  if slot >= keep then return 0 end
  local free = stock - floor
  if free <= 0 then return 0 end
  local n = keep - slot
  return n < free and n or free
end

--- Plancher de la défense : la réserve minimale de munitions (min_reserve) ou la part urgente des tourelles (chargeurs qui leur manquent
--- jusqu'à la cible ordinaire), la plus grande des deux.
function Ra.floor(min_reserve, turret_urgent)
  min_reserve, turret_urgent = num(min_reserve), num(turret_urgent)
  return min_reserve > turret_urgent and min_reserve or turret_urgent
end

return Ra
