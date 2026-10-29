--[[
  Lot FER-EQUIPE : le fer de VOTRE équipe de PNJ. PUR (aucune API Factorio, aucun nom d'objet : les appelants lisent les noms
  dans T.outposts, tests/iag_test.lua §8 bis).

  Constat mesuré (fo-logs/2026-10-29_NUIT/EFFECTIF) : votre équipe dépensait ses 2 500 plaques de départ en 10 recrues avant la
  4e minute, puis son coffre restait entre 6 et 259 plaques ; 48 à 80 % de ses PNJ étaient inactifs, sans site de fer libre.

  1. RÉSERVE de fer (FE.reserve) : SUPPRIMÉE le 29/10 sur décision du DC (« enlevez la limite, le vrai problème du fer c'est
     principalement le fait qu'ils ne capitalisent pas assez »). La réserve de 750 plaques retenait les recrues au-delà de
     l'effectif de départ ; il ne reste que la réserve de croissance habituelle (T.grow_iron_reserve), quelle que soit la défense.
  2. MINAGE DE FER pour les inactifs (FE.extra_mines) : tant que le coffre est pauvre en fer ET en minerai, jusqu'à
     FE.EXTRA_CAP PNJ sans tâche minent du minerai de fer À LA MAIN près du coffre (rayon T.near_mine), en plus du plafond
     général du travail manuel (O.manual_cap, qui bridait à 20 % des exécutants). Sans gisement libre à portée, le minage
     échoue et l'ordinaire « mine_bad » l'écarte 2 min (script/team/worker.lua) : aucun nouveau cas d'échec.
]]

local FE = {}

FE.IRON_ENOUGH = 1000  -- au-delà, plus de minage de renfort : le coffre a du fer
FE.ORE_ENOUGH = 300    -- minerai déjà au coffre (à fondre) au-delà duquel on ne mine pas plus
FE.EXTRA_CAP = 4       -- PNJ de renfort au plus (en plus du plafond général du minage à la main)

--- La défense est-elle couverte ? a = { turret_ok (tourelle possible : au stock ou fabricable), hq_turrets, defend_hq,
--- outposts = { { turrets, need }, ... } }.
function FE.defended(a)
  if not a.turret_ok then return false end
  if (a.hq_turrets or 0) < (a.defend_hq or 0) then return false end
  for _, o in ipairs(a.outposts or {}) do
    if (o.turrets or 0) < (o.need or 0) then return false end
  end
  return true
end

--- Fer à garder au coffre avant une recrue de croissance. base = réserve de croissance habituelle (nombre, ou nil/0 si elle ne
--- s'applique pas). Rend un nombre ou nil (aucune réserve). `defended` est ignoré : plus de plancher de défense (décision du DC).
function FE.reserve(base, _defended)
  return (base and base > 0) and base or nil
end

--- Nombre de minages à la main de fer de renfort. a = { idle (PNJ sans tâche), plates (fer libre au coffre), ore (minerai libre),
--- smelters (fours au QG : sans eux le minerai ne sert pas), prudent, skip (la ressource a échoué récemment) }.
function FE.extra_mines(a)
  if a.prudent or a.skip or (a.smelters or 0) <= 0 then return 0 end
  if (a.plates or 0) >= FE.IRON_ENOUGH or (a.ore or 0) >= FE.ORE_ENOUGH then return 0 end
  return math.max(0, math.min(FE.EXTRA_CAP, a.idle or 0))
end

--- Quantité de `item` (le fer, nommé par l'appelant) dans une liste de coût { { item, n }, ... } (journal [FO-FER]).
function FE.recruit_iron(cost, item)
  local n = 0
  for _, it in ipairs(cost or {}) do if it[1] == item then n = n + it[2] end end
  return n
end

--- Le renfort de fer sert-il AUSSI quand le fond est coupé ? a = { player, fond_on, threat (QG menacé) }. Le fond n'est allumé
--- pour votre équipe qu'à partir de son effectif de départ (script/team/poles.lua) : sous cet effectif, sans fer pour recruter,
--- elle restait 100 % inactive (parties du 29/10, graine 1618033988 : 6 PNJ sur 8 de la minute 26 à la 60, fer à 0). Le QG menacé
--- garde tout le monde au coffre ; une faction n'a pas de renfort.
function FE.off_fond(a)
  return (a.player and not a.fond_on and not a.threat) and true or false
end

return FE
