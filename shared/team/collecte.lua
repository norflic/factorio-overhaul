--[[
  Lot COLLECTE (7/11, partie du DC en 0.6.58, journal fo-logs/2026-11-07_PARTIE-DC-0658) : le fer produit par le champ électrique
  d'un avant-poste s'entasse dans les coffres de SORTIE (projet 12 de votre équipe : de 159 à 174 min, 8 coffres au-dessus du seuil de
  collecte de 200, plaques 2 039 -> 5 312, max 730) pendant que le fer libre du QG est à 0 et que l'équipe, tombée à 2 PNJ, ne se
  reconstruit pas. PUR : aucune API Factorio, aucun nom d'objet (la plaque arrive en donnée) ; tests/collecte_test.lua.

  Pourquoi la collecte attendait (lu au code, script/team/build.lua quai_tasks et shared/ai3/marche.lua) : la tâche « carry/collect »
  d'un coffre de sortie porte la priorité plate du projet (Build.PRIO = 55, sans facteur de besoin) ; à la place de marché, la note d'une
  tâche est priorité x facteur de besoin - distance / 10 : le minage à la main du fer, quand la plaque manque, vaut priorité x 1,5
  (M.NEED_SHORT). Dès qu'un minage de fer a 37 de priorité ou plus, il passe devant la collecte, qui rapporte pourtant jusqu'à 700 plaques
  en un voyage contre 44 minerais en 90 s.

  Règle : quand le fer libre est sous le besoin ET l'équipe sous son effectif, la collecte des coffres de sortie les plus PROCHES du QG
  et SÛRS (ni avant-poste meurtrier, ni nid ou ver à C.DANGER_RADIUS tuiles, ni perte récente alentour) passe à C.PRIO, critique (devant le
  minage et le travail de fond, derrière la défense du QG), au plus C.MAX_TASKS à la fois, et seulement jusqu'à couvrir le manque.

    C.shortfall(s)   -> plaques qui manquent (0 : la règle dort).
    C.refusal(c, now) / C.safe(c, now) -> cause du refus, ou le coffre est-il sûr ?
    C.pick(cands, short) -> clés des coffres à collecter en urgence, le plus proche d'abord.
]]
local T = require("shared.team.config")

local C = {}

C.PRIO = 94            -- sous la défense d'urgence du QG (96) ; marquée « critique » (x 1,5 = 141) : devant le minage urgent du fer (90 x 1,5 = 135)
C.CRITICAL = true      -- (shared/ai3/marche.lua, M.CRITICAL) ; la tâche n'est pas soumise à la ruée (no_rush)
C.MAX_TASKS = 2        -- coffres collectés en urgence à la fois (un PNJ par coffre : l'équipe est à 2 ou 3)
C.DANGER_RADIUS = 40   -- copie de Poles.DANGER_RADIUS (script/team/poles.lua : nid ou ver à moins de 40 tuiles)
C.LOSS_RADIUS = 64     -- copie de Poles.LOSS_RADIUS : une perte de votre équipe à moins de 64 tuiles...
C.LOSS_TICKS = 5 * 3600 -- ... depuis moins de 5 min (Poles.PRUDENCE_TICKS)
C.LETHAL_TICKS = 10 * 3600 -- copie de T.lethal_ticks : avant-poste meurtrier

--- Plaques qui manquent. s = { free = plaques libres au QG, reserve = fer gardé (T.grow_iron_reserve), missing = manque de l'objectif du
--- cerveau, n = PNJ de l'équipe, floor = effectif voulu }. 0 quand l'équipe est au complet ou que le stock couvre.
function C.shortfall(s)
  if (s.n or 0) >= (s.floor or 0) then return 0 end
  local need = (s.reserve or 0) + (s.missing or 0)
  local short = need - (s.free or 0)
  return short > 0 and short or 0
end

--- Cause du refus d'un coffre (« ennemi » : un ennemi à C.DANGER_RADIUS tuiles DU COFFRE, quel que soit l'état du projet ailleurs ; « perte » ;
--- « meurtrier »), nil si sûr. c = { lethal_tick (tick de la dernière mort d'un PNJ à cet avant-poste), enemy (nid ou ver à C.DANGER_RADIUS), loss
--- (perte récente de l'équipe alentour : calculée par l'appelant avec C.LOSS_RADIUS et C.LOSS_TICKS) }.
function C.refusal(c, now)
  if c.enemy then return "ennemi" end
  if c.loss then return "perte" end
  if c.lethal_tick ~= nil and now - c.lethal_tick < C.LETHAL_TICKS then return "meurtrier" end
  return nil
end

function C.safe(c, now) return C.refusal(c, now) == nil end

--- Coffres à collecter en urgence. cands = { { key, d2 (distance au carré au QG), n (plaques du coffre), at (seuil de collecte), enemy,
--- loss, lethal_tick }, ... } ; short = C.shortfall. Rend la liste des clés, le plus proche d'abord (puis clé croissante), au plus
--- C.MAX_TASKS, et on s'arrête dès que le manque est couvert. Rien si le manque est nul.
function C.pick(cands, short, now)
  local out = {}
  if (short or 0) <= 0 then return out end
  local list = {}
  for _, c in ipairs(cands or {}) do
    if (c.n or 0) >= (c.at or 0) and (c.n or 0) > 0 and C.safe(c, now or 0) then list[#list + 1] = c end
  end
  table.sort(list, function(a, b)
    if a.d2 ~= b.d2 then return a.d2 < b.d2 end
    return a.key < b.key
  end)
  local got = 0
  for _, c in ipairs(list) do
    if #out >= C.MAX_TASKS or got >= short then break end
    out[#out + 1] = c.key
    got = got + c.n
  end
  return out
end

--- Un projet dans l'état `state` avec `n_outs` coffres de sortie voit-il ses coffres vidés ? Tout état : un coffre posé se remplit tant que son
--- four tourne, que la bande soit « fini », « chantier », « reserve:pile » ou « refuse:migration » (les coffres absents sont ignorés plus loin).
function C.collects_outs(state, n_outs)
  return (n_outs or 0) > 0 and state ~= nil
end

--- Résultat d'un voyage de collecte : `before` objets dans le coffre à l'arrivée, `got` rapportés (sac). « fail » quand le coffre en tenait et
--- que rien n'est entré (sac plein, QG plein) ; « done » sinon (coffre déjà vidé par un autre, ou voyage utile).
function C.outcome(before, got)
  if (before or 0) > 0 and (got or 0) <= 0 then return "fail" end
  return "done"
end

--- Matières vitales d'une collecte (le fer et le charbon : plaque du fer, produit de l'avant-poste de charbon), lues dans les données.
C.VITAL = { [T.outposts.iron.product] = true, [T.outposts.coal.product] = true }

--- Objets à prendre d'un coffre, dans l'ordre : `items` = noms triés ; `skipped` = prédicat (Stock.skip_fn) ou nil : ce qu'il écarte reste au coffre ;
--- les matières vitales d'abord (le sac plein de pierre ne bloque plus le fer), puis l'ordre des noms.
function C.take_list(items, skipped)
  local vital, rest = {}, {}
  for _, it in ipairs(items or {}) do
    if not (skipped and skipped(it)) then
      if C.VITAL[it] then vital[#vital + 1] = it else rest[#rest + 1] = it end
    end
  end
  for _, it in ipairs(rest) do vital[#vital + 1] = it end
  return vital
end

--- s41 lots-massifs : sorties du MÊME projet vidées dans le voyage de la sortie `idx` (indices croissants, `idx` exclu), à C.SWEEP_R tuiles
--- au plus de celle-ci. `site` : site de pétrole (règle d'origine, lot PETROLE 2). Sinon : tout projet sans borne `keep` (keep_stock d'un
--- bloc de mall : sa sortie doit pouvoir monter à sa barre, une seule sortie par voyage). Sortie sans position : ignorée.
C.SWEEP_R = 40
function C.sweep(outs, idx, site, keep)
  local list = {}
  local o = outs and outs[idx]
  if not o or (keep and not site) then return list end
  for i, o2 in ipairs(outs) do
    if i ~= idx and o2.x and o2.y and (o2.x - o.x) ^ 2 + (o2.y - o.y) ^ 2 <= C.SWEEP_R * C.SWEEP_R then list[#list + 1] = i end
  end
  return list
end

return C
