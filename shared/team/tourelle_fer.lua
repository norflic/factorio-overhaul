--[[
  Lot TOURELLE-FER (9/11, option B validée par l'orchestrateur) : la tourelle qui débloque l'agrandissement du fer. PUR (aucune API Factorio,
  aucun nom d'objet : `iron` vient du poste, posé par shared/team/planner.lua d'après T.outposts).
  Mesuré (sonde de fer, 3 graines) : l'agrandissement du fer sur le champ déjà pris attend les tourelles de « défendre d'abord » (non_defendu :
  4,6 / 1,2 / 4,3 min sur 15 chez player) ; la tourelle d'un avant-poste ordinaire se paie AU-DESSUS du plancher de la défense (T.defend_iron_floor
  = 150) plus son prix (80 avec ses chargeurs) : 230 plaques, que le coffre n'atteint pas tant que d'autres dépenses le vident (precedent :
  shared/team/premiere_tourelle.lua, QG : « la première tourelle ne doit pas attendre qu'une économie qu'elle protège se soit enrichie »).
  Une tourelle d'avant-poste de fer coûte environ 80 plaques et débloque +8 foreuses (+120 plaques/min) : remboursée en 40 s.
  Règle : un poste d'avant-poste de FER sous son nombre de tourelles se paie au plancher RÉDUIT (celui du QG en péril, Sq.floors). La défense
  n'est pas baissée : la même tourelle, les mêmes chargeurs, achetés plus tôt.
]]
local Tf = {}

local function num(x) return tonumber(x) or 0 end

--- Planchers de fer et de cuivre d'un poste. `post` = { iron (vrai pour un avant-poste de la plaque clé), have, want } ; base_* : planchers retenus
--- par l'appelant ; low_* : planchers réduits. Rend fer, cuivre, réduit (vrai si abaissés).
function Tf.floors(post, base_iron, base_copper, low_iron, low_copper)
  base_iron, base_copper = num(base_iron), num(base_copper)
  if type(post) ~= "table" or not post.iron or num(post.have) >= num(post.want) then return base_iron, base_copper, false end
  local fi, fc = math.min(base_iron, num(low_iron)), math.min(base_copper, num(low_copper))
  return fi, fc, (fi < base_iron or fc < base_copper)
end

return Tf
