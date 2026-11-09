--[[
  Lot MALL-LIQUIDATION (directive du DC du 9/11 : « fin de la thésaurisation ») : le stock d'objets de construction FABRIQUÉS (machines, bras, tapis) qui dort au coffre
  paie tout de suite une section de mall de plus, hors une réserve de sécurité. Règle PURE : aucune API du jeu, aucun nom d'objet (un objet est une chaîne opaque).
  Testée hors jeu : tests/mall_liquidation_test.lua. Appelée par Rt.minute (script/team/mall_rangee.lua, allongement au surplus) AVANT la règle du débit (mall_allonge).

  Règle en trois lignes :
    1. de chaque pièce du stock libre, Ml.RESERVE_PCT reste au coffre (réserve de sécurité) ; le reste est « dormant » ;
    2. le stock dormant doit payer au moins UNE section entière en MACHINES (la machine de la rangée doit être au coffre : on n'allonge pas pour la fabriquer) ;
    3. les autres pièces (bras, tapis, poteaux, coffres) ne bloquent pas : elles se fabriquent, « on pose ce qu'on a » (c'est `afford` qui paie la différence en plaques).
  Rend (vrai, nombre de sections que les machines dormantes paient, pièce limitante) ou (faux, 0, raison).
  Déterminisme : `section` est une liste triée par l'appelant ; aucun pairs.
]]

local Ml = {}

Ml.RESERVE_PCT = 0.20 -- part du stock de chaque pièce gardée au coffre (le DC : 15 à 20 %)

--- Ce qu'une pièce du stock peut payer une fois sa réserve retirée (entier).
function Ml.dormant(stock, objet)
  local n = stock[objet] or 0
  if n <= 0 then return 0 end
  return math.floor(n * (1 - Ml.RESERVE_PCT) + 1e-9)
end

--- stock : { [objet] = n } stock libre ; section : liste triée { objet, n, machine } des pièces d'UNE section (machine = vrai pour la machine de la rangée).
--- Rend (vrai, sections payables par les machines dormantes, pièce limitante) ou (faux, 0, raison).
function Ml.surplus(stock, section)
  if type(stock) ~= "table" or type(section) ~= "table" then return false, 0, "donnees absentes" end
  local sections, limitante
  local machine_vue = false
  for _, piece in ipairs(section) do
    local objet, par_section, machine = piece[1], piece[2] or 0, piece[3]
    if machine and par_section > 0 then
      machine_vue = true
      local n = math.floor(Ml.dormant(stock, objet) / par_section)
      if n < 1 then return false, 0, "machine au coffre insuffisante : " .. tostring(objet) end
      if not sections or n < sections then sections, limitante = n, objet end
    end
  end
  if not machine_vue then return false, 0, "section sans machine" end
  return true, sections, limitante
end

return Ml
