--[[
  UN GISEMENT, UN CHAMP (lot CHAMP-COUVERTURE, R7 ; point B de charbonmain, accordé par le lead le 5/11). PUR : aucune API Factorio.

  Défaut mesuré (partie du DC du 5/11, fo-logs/2026-11-05_PARTIE-DC-ESSAI) : les avant-postes 1 et 14 du joueur (fer) sont sur le MÊME
  gisement mais à plus de Champ.SIB_R = 64 tuiles l'un de l'autre ; chacun voyait les paires thermiques de l'autre comme des obstacles
  (« burner-mining-drill 103 » au plan de l'avant-poste 1, « 399 » à celui du 14) et aucun ne posait de bande. Deux avant-postes du même
  minerai sont donc AUSSI voisins quand l'un est posé sur le gisement de l'autre (sa position, ou une tuile d'une de ses paires, est une
  tuile de la composante de minerai lue pour le plan), à toute distance.

  V.on_deposit(ore, cands) -> liste triée des numéros des candidats posés sur le gisement.
    ore    liste plate { x1, y1, x2, y2, ... } des tuiles du gisement (coins nord-ouest, entiers)
    cands  { { id = numéro, tiles = liste plate des tuiles à essayer (position de l'avant-poste, tuiles de ses paires) } }
  Déterminisme : ensemble de clés entières, candidats parcourus dans l'ordre donné, résultat trié.
]]

local V = {}

local function key(x, y) return (x + 50000) * 100000 + (y + 50000) end

function V.on_deposit(ore, cands)
  local set = {}
  for i = 1, #(ore or {}) - 1, 2 do set[key(ore[i], ore[i + 1])] = true end
  local out = {}
  for _, c in ipairs(cands or {}) do
    local t = c.tiles or {}
    local hit = false
    for i = 1, #t - 1, 2 do
      if not hit and set[key(math.floor(t[i]), math.floor(t[i + 1]))] then hit = true end
    end
    if hit then out[#out + 1] = c.id end
  end
  table.sort(out)
  return out
end

return V
