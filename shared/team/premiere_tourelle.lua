--[[
  Lot EQUIPE (1/11, parité de votre équipe avec les factions) : le PREMIER PALIER de la défense du QG. Règle PURE (aucune API Factorio,
  aucun nom d'objet), déterministe, testée hors jeu par tests/equipe_defense_test.lua (avec mutants).

  Constat (partie de 3 h 45 sur la 0.6.33, aucun joueur humain, fo-logs/2026-11-01_CROISSANCE/g1 ; fo-logs/2026-11-01_EQUIPE/RAPPORT.md) :
    - une faction naît avec T.start_hq_turrets tourelles au QG (shared/team/fondation.lua : « votre équipe n'en reçoit jamais ») ; votre
      équipe naît sans tourelle ni recette ;
    - son QG est attaqué dès 8,6 min ; la recette de la tourelle n'est là qu'à 10,9 min (la technologie n'est un palier que pour une
      faction : script/ai3/general.lua, DEFENSE-FACTIONS D2) ; le fer vaut 203 à 7 min et 0 à 9 min (ordre de capitalisation de 29
      foreuses à 7,8 min) ;
    - même recette acquise, la première tourelle exige le fer au-dessus du plancher de la défense (T.defend_iron_floor = 150) PLUS
      le prix de la commande partielle (80) : 230 plaques ; le coffre n'a jamais dépassé 214 : 0 tourelle pendant 225 min, 153 PNJ tués sur 173 à
      moins de 10 tuiles du QG, par des petits cracheurs.
  Règle : tant que le QG a moins de P.FIRST_N tourelles, la défense du QG se paie au PLANCHER RÉDUIT (celui du QG en péril, Sq.floors),
  péril ou non : la première tourelle ne doit pas attendre qu'une économie qu'elle protège se soit enrichie. Au-delà, les planchers
  ordinaires reviennent (la règle n'élargit pas la défense, elle ouvre le premier palier).
]]

local P = {}

P.FIRST_N = 2 -- tourelles au QG en dessous desquelles les planchers sont réduits (le QG d'une faction n'en veut que 0 ou 2 : front.lua F.hq_post)

local function num(x) return tonumber(x) or 0 end

--- Planchers de fer et de cuivre d'un poste. `post_id` : "hq" pour le QG (les autres postes gardent leurs planchers) ; `have` : tourelles au
--- QG ; base_* : planchers déjà retenus par l'appelant ; low_* : planchers réduits. Rend fer, cuivre, premier_palier (vrai si abaissés).
function P.floors(post_id, have, base_iron, base_copper, low_iron, low_copper)
  base_iron, base_copper = num(base_iron), num(base_copper)
  if post_id ~= "hq" or num(have) >= P.FIRST_N then return base_iron, base_copper, false end
  local fi, fc = math.min(base_iron, num(low_iron)), math.min(base_copper, num(low_copper))
  return fi, fc, (fi < base_iron or fc < base_copper)
end

return P
