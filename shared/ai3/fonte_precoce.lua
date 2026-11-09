--[[
  Lot FONTE-PRECOCE (9/11) : les fours du QG avant le premier avant-poste de fer. PUR (aucun nom d'objet : le minerai et la plaque clés viennent de
  l'appelant, d'après T.outposts).
  Mesuré (sonde-8min f0fa3f06, 3 graines, scarlet et azure) : le premier avant-poste de fer des factions est bâti à 7,2 / 9,2 min parce que sa commande
  (213 plaques de fer) n'est fondue qu'à la minute 7 ou 8 : le QG n'a que 4 fours de pierre (2 à 3 sur le fer : 37 à 70 plaques/min, plafond 75) ; le minerai
  de fer ATTEND au coffre (68 à 260 minerais, 515 à 995 minerai-minutes sur les minutes 3 à 8) ; la croissance de la fonderie du QG ne s'ouvre qu'avec un avant-poste
  de fer à 75 % de capacité (shared/ai3/buts.lua) et ses vagues exigent un manque de plaques couvert 2 fois par le minerai (Br.smelters) : jamais avant l'avant-poste.
  Un four de pierre coûte 5 pierres.
  Règle (Fp.extra) : tant que l'avant-poste de fer n'a pas la capacité visée (cap < Fp.CAP_MIN), si la plaque clé est SOUS son plancher et que le minerai clé
  qui attend au coffre couvre Fp.SECONDS secondes du débit des fours déjà posés (le minerai s'accumule : ce sont les fours qui limitent), la fonderie du
  QG reçoit Fp.STEP fours de plus, au plus Fp.HARD en tout. Le flux décide, aucune horloge.
]]
local Fp = {}

Fp.CAP_MIN = 0.75   -- capacité de l'avant-poste de la ressource clé à partir de laquelle la règle d'avant (B.generate) prend le relais
Fp.PER_MIN = 19     -- plaques par minute et par four de pierre (3,2 s par plaque : 18,75 ; mesuré : 4 fours = 37 à 70/min)
Fp.SECONDS = 30     -- le minerai qui attend doit couvrir ce nombre de secondes du débit des fours posés
Fp.STEP = 2         -- fours de plus par décision
Fp.HARD = 8         -- fours du QG au plus pour cette règle (les vagues d'avant montent plus haut, Br.SMELT_HARD)

--- a = { cap (capacité de l'avant-poste clé), plate (stock de la plaque clé), floor (plancher du besoin), ore (stock du minerai clé), have (fours posés ou en
--- cours) }. Rend le nombre de fours de plus (0 : rien).
function Fp.extra(a)
  a = a or {}
  local have = a.have or 0
  if (a.cap or 0) >= Fp.CAP_MIN then return 0 end
  if (a.plate or 0) >= (a.floor or 0) then return 0 end
  if (a.ore or 0) < have * Fp.PER_MIN * Fp.SECONDS / 60 then return 0 end
  return math.max(0, math.min(Fp.STEP, Fp.HARD - have))
end

return Fp
