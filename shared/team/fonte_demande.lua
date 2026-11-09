--[[
  FONTE SUIT LA DEMANDE (lot FONTE-CUIVRE, 9/11) : PUR (aucune API Factorio, aucun nom d'objet : entrées et stocks en DONNÉES).
  Constat mesuré (scarlet, graine 20261020, [FO-SONDE-FOURS]) : de 6 à 11 min, 4 à 5 des 7 fours du QG fondent du cuivre en
  continu alors que le plan ne demande plus que du fer ([FO-BRIQUES] : demande {iron-plate 748}) : les plaques de cuivre passent de
  114 à 375 au coffre pendant que 80 à 216 minerais de fer attendent et que 2 fours seulement fondent du fer. Cause lue au code
  (script/faction/outposts.lua, Outposts.smelt_loads) : un four qui porte déjà un MINERAI est complété sans regarder la demande
  (la condition `demanded_item` ne vaut que pour une entrée qui est elle-même un produit de fonte, la plaque de l'acier).

  Règle : un four dont l'entrée n'est plus demandée n'est plus complété QUAND une autre entrée demandée attend au coffre ; il
  finit sa charge, se vide, puis un four vide reçoit une entrée demandée (Charge.least_served, inchangé). Sans autre entrée
  demandée qui attend, rien ne change (un four ne reste pas vide pour rien).
    Fd.refill(a)   a = { demanded = bool (cette entrée est demandée), other_waiting = bool (une AUTRE entrée demandée a du stock) }
                   -> vrai si le four doit être complété avec la même entrée
    Fd.other_waiting(item, demanded_items, stock_of)   vrai si une entrée demandée autre que `item` a du stock (stock_of(entrée) > 0)
  Déterminisme : listes dans l'ordre reçu (aucun pairs).
]]

local Fd = {}

function Fd.refill(a)
  a = a or {}
  if a.demanded then return true end
  return not a.other_waiting
end

function Fd.other_waiting(item, demanded_items, stock_of)
  for _, d in ipairs(demanded_items or {}) do
    if d ~= item and (stock_of(d) or 0) > 0 then return true end
  end
  return false
end

return Fd
