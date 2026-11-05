--[[
  Lot PERIMETRE2 (demande du lead, 5/11 17 h 55, relevé de revue-etage4 sur corr-etage5 5b5963ef) : PORTE sur la brèche qu'un couloir d'accès
  (lot ÉTAGE 5, Build.couloirs) ouvre dans un anneau de murs. PUR : aucune API du moteur ; les directions sont les nombres de defines.direction
  de Factorio 1.1 (nord 0, est 2).

  Le mur saute les tuiles d'un couloir (2 de large) : la brèche laisse passer les biters. Une porte (entité gate) s'ouvre pour les personnages
  de sa force et reste fermée aux ennemis : posée sur la tuile du couloir quand la force a la recherche des portes ; sans elle, la brèche reste.

  Règle :
    Pc.tile(tx, ty, cor, side, gates) -> "mur" | "porte" | "breche", direction (porte seulement), axe de passage ("x" ou "y")
      cor   : ensemble { [P.tkey(x, y)] = id } des tuiles de couloir (Build.couloirs ; vide : aucun couloir) ;
      side  : côté de l'anneau ("n", "s" : mur le long de x ; "e", "o" : mur le long de y), nil s'il est inconnu ;
      gates : la force a-t-elle la recherche des portes (recette de la porte activée) ?
    Tuile hors couloir : "mur". Tuile de couloir sans recherche : "breche" (rien n'y est posé). Avec recherche : "porte", orientée SELON LE
    COULOIR : axe de passage = axe où la tuile a le plus de voisines de couloir (une bande de 2 tuiles le long de x a 2 voisines en x, 1 en
    y) ; à égalité (bout ou coude du couloir), le passage traverse le mur (côtés n et s : axe y ; e et o : axe x ; côté inconnu : x).
    Direction : passage selon x -> porte VERTICALE (barreaux nord-sud), Pc.DIR.x ; passage selon y -> porte horizontale, Pc.DIR.y.
    DÉDUIT, non prouvé : « direction nord = porte verticale » (à voir sur les images du banc g3-porte) ; ouverte, une porte ne heurte pas un
    personnage (opened_collision_mask sans player-layer) : l'orientation ne change que l'image et le raccord aux murs voisins.
]]
local P = require("shared.team.plan")

local Pc = {}

Pc.DIR = { x = 0, y = 2 } -- passage selon x : direction nord (porte verticale) ; selon y : direction est (porte horizontale)

local function axis_of(tx, ty, cor, side)
  local nx = (cor[P.tkey(tx - 1, ty)] ~= nil and 1 or 0) + (cor[P.tkey(tx + 1, ty)] ~= nil and 1 or 0)
  local ny = (cor[P.tkey(tx, ty - 1)] ~= nil and 1 or 0) + (cor[P.tkey(tx, ty + 1)] ~= nil and 1 or 0)
  if nx > ny then return "x" end
  if ny > nx then return "y" end
  if side == "n" or side == "s" then return "y" end
  return "x"
end

function Pc.tile(tx, ty, cor, side, gates)
  if not (cor and cor[P.tkey(tx, ty)] ~= nil) then return "mur" end
  if not gates then return "breche" end
  local ax = axis_of(tx, ty, cor, side)
  return "porte", Pc.DIR[ax], ax
end

return Pc
