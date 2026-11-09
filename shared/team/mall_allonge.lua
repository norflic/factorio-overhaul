--[[
  Lot MALL (feu vert du 9/11 ; le DC : « Malls duplicables », « lignes de production massives ») : allongement d'une rangée AU-DELÀ de la demande immédiate, quand la matière est réellement en surplus. Règle PURE :
  aucune API du jeu, aucun nom d'objet (un objet est une chaîne opaque). Testée hors jeu : tests/mall_allonge_test.lua. Appelée par Rt.minute (script/team/mall_rangee.lua).

  Une rangée vise N cellules, lu du débit MESURÉ de chacune de ses entrées :
    1. pas de débit de cette entrée : pas d'allongement ;
    2. stock LIBRE de cette entrée (hors besoin, hors réserve de défense : c'est l'appelant qui le lit) sous Ma.RESERVE_MIN minutes de son débit : pas d'allongement (le fer qui manque reste aux bandes, à la défense, au charbon) ;
    3. le mall entier a droit à Ma.PART du débit d'une entrée ; ce que ses machines déjà posées peuvent boire est retiré ; ce qui reste se divise par ce qu'une machine de cette rangée boit au plus : autant de machines de plus ;
    4. l'entrée la plus serrée borne ; une cellule porte deux machines.
  Sous surplus, N = le nombre de cellules actuel : le comportement d'avant (la demande seule). Valeurs NON MESURÉES : Ma.PART, Ma.RESERVE_MIN.
  Déterminisme : liste d'entrées dans l'ordre donné par l'appelant (triée), aucun pairs.
]]

local Ma = {}

Ma.PART = 0.25        -- part du débit mesuré d'une entrée que le mall entier peut boire
Ma.RESERVE_MIN = 5    -- minutes de débit à garder au stock libre avant d'allonger
Ma.PAR_CELLULE = 2    -- machines par cellule

--- cells : cellules actuelles ; besoins : liste { item, per_machine } (objets/min qu'une machine de la rangée boit au plus) ; flow, libre, conso : { [objet] = nombre } (débit mesuré en objets/min, stock libre, objets/min que
--- les machines déjà posées de tout le mall peuvent boire) ; max_cells : plafond. Rend (cible en cellules, raison).
function Ma.cible(cells, besoins, flow, libre, conso, max_cells)
  if #besoins == 0 then return cells, "aucune entree" end
  local extra
  for _, b in ipairs(besoins) do
    local debit = flow[b.item] or 0
    if debit <= 0 then return cells, "sans debit : " .. b.item end
    if (libre[b.item] or 0) < debit * Ma.RESERVE_MIN then return cells, "stock libre insuffisant : " .. b.item end
    local marge = debit * Ma.PART - (conso[b.item] or 0)
    if marge <= 0 then return cells, "debit deja bu : " .. b.item end
    if b.per_machine > 0 then
      local m = math.floor(marge / b.per_machine)
      if not extra or m < extra then extra = m end
    end
  end
  if not extra then return cells, "entrees sans consommation" end
  local n = cells + math.floor(extra / Ma.PAR_CELLULE)
  if n > max_cells then n = max_cells end
  if n < cells then n = cells end
  return n, "surplus"
end

return Ma
