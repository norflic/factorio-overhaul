--[[
  Lot FER-EQUIPE : le fer de VOTRE équipe de PNJ. PUR (aucune API Factorio, aucun nom d'objet : les appelants lisent les noms
  dans T.outposts, tests/iag_test.lua §8 bis).

  Constat mesuré (fo-logs/2026-10-29_NUIT/EFFECTIF) : votre équipe dépensait ses 2 500 plaques de départ en 10 recrues avant la
  4e minute, puis son coffre restait entre 6 et 259 plaques ; 48 à 80 % de ses PNJ étaient inactifs, sans site de fer libre.

  1. RÉSERVE de fer (FE.reserve) : tant que la défense n'est pas couverte (tourelles du QG, avant-postes défendus, tourelle
     possible), les recrues AU-DELÀ de l'effectif de départ ne peuvent pas descendre le coffre sous FE.START_RESERVE plaques
     (au moins la réserve de croissance habituelle). Avant le lot, sans tourelle possible, aucune réserve ne s'appliquait.
  2. MINAGE DE FER pour les inactifs (FE.extra_mines) : tant que le coffre est pauvre en fer ET en minerai, jusqu'à
     FE.EXTRA_CAP PNJ sans tâche minent du minerai de fer À LA MAIN près du coffre (rayon T.near_mine), en plus du plafond
     général du travail manuel (O.manual_cap, qui bridait à 20 % des exécutants). Sans gisement libre à portée, le minage
     échoue et l'ordinaire « mine_bad » l'écarte 2 min (script/team/worker.lua) : aucun nouveau cas d'échec.
]]

local FE = {}

FE.START_RESERVE = 750 -- 30 % du coffre de départ de référence (2 500 plaques) : fer gardé tant que la défense n'est pas couverte
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
--- s'applique pas), defended = FE.defended. Rend un nombre ou nil (aucune réserve).
function FE.reserve(base, defended)
  base = (base and base > 0) and base or nil
  if defended then return base end
  return (base and base > FE.START_RESERVE) and base or FE.START_RESERVE
end

--- Nombre de minages à la main de fer de renfort. a = { idle (PNJ sans tâche), plates (fer libre au coffre), ore (minerai libre),
--- smelters (fours au QG : sans eux le minerai ne sert pas), prudent, skip (la ressource a échoué récemment) }.
function FE.extra_mines(a)
  if a.prudent or a.skip or (a.smelters or 0) <= 0 then return 0 end
  if (a.plates or 0) >= FE.IRON_ENOUGH or (a.ore or 0) >= FE.ORE_ENOUGH then return 0 end
  return math.max(0, math.min(FE.EXTRA_CAP, a.idle or 0))
end

return FE
