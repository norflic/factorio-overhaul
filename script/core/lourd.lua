--[[
  Lot LOURD (S6 de l'objectif x10, point 2 ; fo-logs\2026-11-07_LOURD\CRITERES.md §2) : ORDONNANCEUR des travaux lourds, à BUDGET par
  tick et en file équitable, pour tout le mod. Généralisé du jeton du pouls (lot POULS) : script/team/pouls_jeton.lua en est un alias.

  J.take(tick, qui, periode, cout) : vrai si `qui` peut faire son travail lourd à ce tick (le faire maintenant) ; faux sinon (ne rien
  faire de lourd : `qui` est en file, il redemande à son prochain passage).
  - cout : part du budget du tick (J.BUDGET unités) que le travail DÉCLARE : un nombre fixé par le code, jamais un temps mesuré
    (déterminisme) ; pour les relevés par zone, le nombre de chunks couverts. ABSENT : tout le budget (un travail par tick, la règle du lot
    POULS). Plusieurs petits travaux passent au même tick tant que la somme tient dans le budget ; un travail plus grand que le budget a
    son tick à lui seul.
  - periode : `qui` ne redemande que tous les `periode` ticks ; il ne retient les autres (réserve, ci-dessous) qu'aux ticks où il
    redemande : dernière demande + k × periode. ABSENT : 1 (tous les ticks, comme le jeton du lot POULS).
  - File : premier refusé, premier servi. Le budget est RÉSERVÉ aux demandeurs de la file qui sont devant, attendus à ce tick et pas encore
    servis (leur coût déclaré à leur dernier refus) : on ne prend que ce qui reste après eux. Le premier de la file passe donc à sa
    demande : personne n'est affamé (tests/lourd_jeton_test.lua, J4). Une entrée qui ne redemande pas dans les max(J.STALE, periode)
    ticks sort de la file.
  J.COSTS = false : chaque travail coûte tout le budget, quoi qu'il déclare : exactement le jeton de la 0.6.61 (témoin d'identité,
  tests/lourd_jeton_test.lua J1 et tests/pouls_test.lua P14).
  État : la file est dans global (ns « pouls_jeton », nom gardé pour les sauvegardes de la 0.6.59 à 0.6.61 : q = demandeurs en attente,
  dans l'ordre ; last, per, cost = dernière demande, période et coût de chacun) : elle dure d'un tick à l'autre, donc elle est la même sur
  tous les clients et après un chargement. Seuls `used` et `served` (ce qui est pris à CE tick) sont des locales : un tick ne
  s'interrompt pas par une sauvegarde. `served` garde le TICK du service (aucune table neuve par tick : F403).
  Sans demandeur (bancs d'avant le lot POULS), le premier appel du tick l'emporte (tout le budget).
]]

local Storage = require("script.core.storage")

local J = {}

J.STALE = 5      -- ticks (Build.PULSE) : une demande non renouvelée au pouls suivant sort de la file
-- Unité : un chunk relevé par find_entities_filtered. MESURÉ (LOURD-ABAB série 2, sauvegarde du DC, 0.6.59) : une ligne de 76 chunks du
-- relevé du réseau 1,11 ms en moyenne, 7,13 ms au pire ; une bande de 2 lignes du raccord 7,1 ms au pire. 64 : deux tranches de 32 chunks
-- (Rv.COLS) par tick ; une bande du raccord (2 × 76 = 152) a son tick à elle seule.
J.BUDGET = 64    -- unités par tick (un coût absent vaut J.BUDGET)
J.COSTS = true   -- faux : chaque travail coûte J.BUDGET (le jeton de la 0.6.61, témoin)

Storage.declare("pouls_jeton", function() return { q = {}, last = {}, per = {}, cost = {} } end)

local cur = -1     -- tick de `used`
local used = 0     -- unités prises à ce tick
local served = {}  -- [qui] = tick de son dernier service
local purged = -1

local function S()
  local s = Storage.ns("pouls_jeton")
  if s then
    s.q = s.q or {}
    s.last = s.last or {}
    s.per = s.per or {}   -- (absents d'une sauvegarde de la 0.6.59 à 0.6.61)
    s.cost = s.cost or {}
  end
  return s
end

local function new_tick(tick)
  if cur ~= tick then cur, used = tick, 0 end
end

--- Une fois par tick : les demandeurs qui n'ont pas redemandé depuis plus de max(J.STALE, période) ticks sortent de la file.
local function purge(s, tick)
  if purged == tick then return end
  purged = tick
  local q = {}
  for _, k in ipairs(s.q) do
    if (s.last[k] or -1) >= tick - math.max(J.STALE, s.per[k] or 1) then
      q[#q + 1] = k
    else
      s.last[k], s.per[k], s.cost[k] = nil, nil, nil
    end
  end
  s.q = q
end

--- `k` (en file) est-il attendu à ce tick ? (dernière demande + k × période)
local function eligible(s, k, tick)
  local p = s.per[k] or 1
  return (tick - (s.last[k] or tick)) % p == 0
end

--- Budget réservé, à ce tick, aux demandeurs attendus DEVANT `who` dans la file et pas encore servis (tous, si `who` n'y est pas) ; rend
--- aussi s'il y en a un, et la place de `who` dans la file (nil s'il n'y est pas).
local function reserved_before(s, who, tick)
  local r, any = 0, false
  for i, k in ipairs(s.q) do
    if k == who then return r, any, i end
    if served[k] ~= tick and eligible(s, k, tick) then
      r = r + ((J.COSTS and s.cost[k]) or J.BUDGET)
      any = true
    end
  end
  return r, any, nil
end

function J.take(tick, who, period, cost)
  new_tick(tick)
  local c = (J.COSTS and cost) or J.BUDGET
  local s = who and S()
  if not s then
    if used > 0 then return false end
    used = J.BUDGET
    return true
  end
  purge(s, tick)
  local r, ahead, i = reserved_before(s, who, tick)
  local ok = (used + r + c <= J.BUDGET) or (used == 0 and not ahead)
  s.per[who] = (period and period > 1) and period or nil
  if not ok then
    if not i then s.q[#s.q + 1] = who end
    s.last[who] = tick
    s.cost[who] = cost
    return false
  end
  used = used + c
  served[who] = tick
  if i then table.remove(s.q, i) end
  s.last[who], s.per[who], s.cost[who] = nil, nil, nil
  return true
end

--- Lot LOURD (point 2 c ; décision du lead du 8/11, trou relevé par effondrement) : retire `who` de la file (pensée abandonnée ou
--- effacée au changement de configuration) : une entrée qui ne redemandera plus ne retient pas le budget jusqu'à sa purge (J.STALE).
function J.drop(who)
  local s = who and S()
  if not s then return end
  for i = #s.q, 1, -1 do
    if s.q[i] == who then table.remove(s.q, i) end
  end
  s.last[who], s.per[who], s.cost[who] = nil, nil, nil
end

--- Unités encore libres à ce tick (lecture seule ; bancs et journaux).
function J.left(tick)
  new_tick(tick)
  return math.max(0, J.BUDGET - used)
end

--- Lot TV-VAPEUR (V89) : nombre de demandeurs refusés en attente dans la file à ce tick (lecture de l'état de jeu, la même sur tous les
--- clients ; les entrées périmées sont purgées d'abord, comme au prochain J.take). Signal de la dégradation graduée (script/core/charge.lua).
function J.waiting(tick)
  local s = S()
  if not s then return 0 end
  purge(s, tick)
  return #s.q
end

--- Bancs hors jeu seulement : rend le jeton (nouvelle partie simulée).
function J.reset()
  cur, used, purged = -1, 0, -1
  served = {}
  local s = Storage.ns("pouls_jeton")
  if s then s.q, s.last, s.per, s.cost = {}, {}, {}, {} end
end

return J
