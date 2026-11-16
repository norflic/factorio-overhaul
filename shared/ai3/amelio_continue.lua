--[[
  Lot AMELIO-CONTINUE (DC 14/11 : « chaîne d'amélioration continue sur l'existant : convoyeurs, puis foreuses, puis fours ») : règle PURE
  (aucune API Factorio). Le remplacement lui-même reste celui du lot AMELIORER (script/ai3/capital.lua, replace_one : fast_replace).
    - AC.order(list, type_of, n)  : relevé trié par priorité de TYPE (R.AMELIO_PRIO), puis par numéro ; borné à n pièces ;
    - AC.kit_want(need, have, cap) : objets cibles à fabriquer d'avance (quota de kit, indépendant de la réservation du cerveau) ;
    - AC.pile_permits(hold, have) : la pile ne retient pas un remplacement dont le kit est déjà au stock (rien à réserver) ;
    - AC.log_ok(st)               : journal [FO-AMELIO-CONTINUE] borné (AC.LOGS lignes par équipe).
  Aucun nom d'objet ni de type ici : les types viennent de shared/ai3/reglages.lua. Déterminisme : tris totaux, aucun pairs décisionnel.
]]
local R = require("shared.ai3.reglages")

local AC = {}

AC.MAX_SCAN = 600 -- pièces au plus dans le relevé d'une pensée (borne N)
AC.LOGS = 30      -- lignes [FO-AMELIO-CONTINUE] au plus par équipe
AC.ZONE_KIT = 40  -- majz-0716 : pièces d'une zone Maj + Z servies par un même kit (réserve et quota élargis)
AC.ZONE_PRIO = 30 -- majz-0716 : priorité de plus pour le kit d'une zone Maj + Z
AC.ZONE_HOLD = 3600 -- majz-0716 : ticks pendant lesquels la tâche du kit d'une zone survit aux synchros du tableau (Board.sync)

--- Rang de priorité d'un type du moteur (1 = d'abord) ; un type absent passe après tous.
function AC.rank(t)
  return (R.AMELIO_PRIO or {})[t] or 99
end

--- Trie `list` (entrées { id, ... }) par (rang du type, id) et la borne à `n` entrées. `type_of(entry)` rend le type du moteur.
--- Lot TIERS-MACHINES : chaque rang PRÉSENT a d'abord sa part (⌊n ÷ rangs présents⌋ pièces), le reste va par priorité. Mesuré
--- (banc DC60-cand0715, azure) : 600 tapis à 30,8 min remplissaient seuls le relevé, les 55 fours en pierre et les 81 foreuses en sortaient,
--- leur remplacement ne pouvait plus être décidé. La priorité tapis -> foreuses -> fours reste celle du choix (engagement, scores).
--- majz-0716 : `first(entry)` (facultatif) vrai pour une pièce d'une ZONE D'AMÉLIORATION PRIORITAIRE du joueur (Maj + Z) : ces pièces entrent
--- TOUTES au relevé avant les parts des rangs (dans la borne n) ; sans elles, 600 tapis du reste de la base pouvaient en sortir les pièces
--- de la zone, que le choix (groupe « z| », rang 0) ne voyait alors jamais.
function AC.order(list, type_of, n, first)
  local keyed = {}
  for i, m in ipairs(list or {}) do keyed[i] = { m = m, r = AC.rank(type_of(m)), id = m.id or 0, z = (first and first(m)) and 0 or 1 } end
  table.sort(keyed, function(a, b)
    if a.z ~= b.z then return a.z < b.z end
    if a.r ~= b.r then return a.r < b.r end
    return a.id < b.id
  end)
  n = n or AC.MAX_SCAN
  local taken, picked, total = {}, {}, 0
  for i, k in ipairs(keyed) do -- la zone d'abord (ordre du tri)
    if k.z == 0 and total < n then taken[i] = true; total = total + 1 end
  end
  local ranks, by = {}, {}
  for i, k in ipairs(keyed) do
    if not taken[i] and not by[k.r] then by[k.r] = 0; ranks[#ranks + 1] = k.r end
  end
  local quota = #ranks > 0 and math.floor((n - total) / #ranks) or 0
  for i, k in ipairs(keyed) do -- part de chaque rang (ordre du tri : rang, puis numéro)
    if taken[i] then goto continue end
    if by[k.r] < quota and total < n then by[k.r] = by[k.r] + 1; taken[i] = true; total = total + 1 end
    ::continue::
  end
  for i = 1, #keyed do -- le reste, par priorité
    if total >= n then break end
    if not taken[i] then taken[i] = true; total = total + 1 end
  end
  for i, k in ipairs(keyed) do if taken[i] then picked[#picked + 1] = k end end
  local out = {}
  for i = 1, #picked do out[i] = picked[i].m end
  table.sort(out, function(a, b) return (a.id or 0) < (b.id or 0) end) -- le relevé du capital reste trié par numéro
  return out
end

--- Quota de kit : `need` = { [objet] = pièces à remplacer }, `have` = { [objet] = au stock }. Rend une liste triée { objet, n } à
--- fabriquer (au plus `cap` au stock par objet quand `cap` est donné ; sinon la réserve entière du lot, déjà bornée par Cap.pool au lot
--- demandé à la fabrication). Lot n100-kits : plus de borne propre au kit (12 : un kit plus petit que la réserve qu'il doit payer) ;
--- la matière reste bornée par le stock libre (Bm.best, script/ai3/capital.lua).
function AC.kit_want(need, have, cap)
  local names = {}
  for k in pairs(need or {}) do names[#names + 1] = k end
  table.sort(names)
  local out = {}
  for _, k in ipairs(names) do
    local w = math.min(cap or need[k] or 0, need[k] or 0) - ((have or {})[k] or 0)
    if w > 0 then out[#out + 1] = { k, w } end
  end
  return out
end

--- La pile retient-elle ce remplacement ? Non si elle ne retient rien, ou si le kit est déjà au stock (`have` >= 1).
function AC.pile_permits(hold, have)
  return (not hold) or (have or 0) >= 1
end

--- Journal borné : rend vrai (et compte) tant que l'équipe n'a pas écrit AC.LOGS lignes.
function AC.log_ok(st)
  st.logs = (st.logs or 0) + 1
  return st.logs <= AC.LOGS
end

return AC
