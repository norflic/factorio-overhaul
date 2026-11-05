--[[
  Lot ETAGE4 (4/11) : BAIL des tournées d'avant-poste. PUR : aucune API du moteur, aucun nom d'objet.
  Défaut mesuré (fo-logs/2026-11-03_AGEBLOCAGE/fd-croiss-123456789, fo-logs/2026-11-04_ETAGE4/RAPPORT.md) : la tournée de l'avant-poste de
  charbon n° 1 d'Émeraude reste « prise » 41 min, son PNJ immobile à côté ; le tableau garde toute tâche prise tant que le PNJ ne la rend pas
  (script/team/board.lua, Board.sync) : aucun bail, aucune échéance. 12 archives de dc-croissance, témoins de main compris.
  Règles :
    Bl.progress(prev, cur, tick) -> relevé du dernier PROGRÈS du PNJ qui tient la tâche, et le temps sans progrès. Progrès (revue du lead,
                                    M1, 5/11) = autre ÉTAPE du programme, autre but d'ÉTAPE, ou approche de ce but d'au moins Bl.MOVE tuile
                                    PLUS PRÈS QUE JAMAIS. Le but est celui de l'ÉTAPE (position d'un « goto », QG d'un « home »), pas le point de
                                    passage des comportements visibles, qui change à chaque itinéraire. Un changement d'ÉTAT seul (marche /
                                    arrêt) n'est pas un progrès : PNJ 22 d'Azur et PNJ 3 de votre équipe (lot3-croiss-123456789) recalculaient
                                    sur place un itinéraire « BLOQUE » et passaient pour « 0 à 5 s sans progrès ». Sans but d'étape (étapes
                                    instantanées) : déplacement d'au moins Bl.MOVE tuile depuis le dernier progrès (règle de l'essai 1).
    Bl.expired(kind, stall, held, pre_act) -> le bail est-il échu ? Seulement pour les types de Bl.KINDS (les tournées). Échu sans progrès depuis
                                    Bl.LEASE ; ou tenue depuis Bl.MAX_HOLD AVANT l'acte (essai 2 ; M1 : le retour au QG après l'acte, travail
                                    fait, n'est plus coupé par la tenue maximale, seulement par l'absence de progrès).
    Bl.alive(state, free_age, stall, stale, held, pre_act) -> la tournée va-t-elle chercher ce qui attend ? Libre depuis moins de `stale`, ou
                                    prise et pas échue au sens de Bl.expired. Absente : non.
  Revue du lead (5/11, m4 et m5) :
    Bl.busy(k, shooting, tick)   -> le PNJ est-il au COMBAT sur place (arrêt « engage » des comportements visibles, ou autodéfense qui tire) ou
                                    en FUITE (refuge en cours depuis moins de Bl.FLEE_MAX) ? Ce temps-là ne compte ni comme temps sans progrès
                                    (Bl.progress, cur.busy : progrès) ni comme temps de tenue (Bl.held_base).
    Bl.count(prev, reset), Bl.pause(n) -> bails de suite d'une même tournée sans tournée réussie entre deux ; au-delà de Bl.HOLD_AFTER, pause de
                                    la tournée Bl.PAUSE_TICKS (modèle d'Ad.hold, shared/team/adopte.lua) : un accès muré ne boucle plus sans fin.
]]
local Bl = {}

Bl.LEASE = 2 * 3600       -- ticks sans progrès au-delà desquels une tournée prise est rendue (une tournée normale dure 1 à 2 min en marchant)
Bl.MOVE = 1               -- tuiles : approche (ou déplacement sans but) qui compte comme un progrès
Bl.GOAL_EPS = 0.5         -- tuiles : un but qui bouge de plus est un AUTRE but (nouveau point de passage)
Bl.MAX_HOLD = 3 * 3600    -- ticks au-delà desquels une tournée prise et pas encore à l'acte est rendue même si son PNJ bouge (essai 2 ; aller
                          -- et retour à 400 tuiles en moins de 2 min de marche : 50 % de marge)
Bl.KINDS = { service = true, ghost = true } -- tournées ; reconstructions du bâtisseur (« ghost », accord du lead du 5/11 : mesuré 240 s sans
                                           -- progrès chez Azur, lot5-croiss-123456789). Pas d'étape « act » : la tenue maximale ne s'y applique pas.
Bl.FLEE_MAX = 2 * 3600    -- ticks : une fuite plus longue (refuge jamais atteint) recompte comme temps sans progrès
Bl.HOLD_AFTER = 2         -- bails de suite d'une tournée (sans tournée réussie entre deux) avant sa pause (A.HOLD_AFTER du lot ADOPTE)
Bl.PAUSE_TICKS = 10 * 3600 -- pause de la tournée : elle n'est plus reposée au tableau (le minage à la main n'est plus bloqué par elle)

local function num(v) return type(v) == "number" and v or 0 end

--- m5 : combat sur place ou fuite ? k = état des comportements visibles du PNJ { hold, hold_stop, refuge, flee_t } (nil : éteints) ; un
--- arrêt d'ALERTE (hold_stop) n'est pas un combat. shooting = l'autodéfense tire.
function Bl.busy(k, shooting, tick)
  if shooting == true then return true end
  if type(k) ~= "table" then return false end
  if k.hold ~= nil and k.hold_stop == nil and num(tick) < num(k.hold) then return true end
  return k.refuge ~= nil and k.flee_t ~= nil and num(tick) - num(k.flee_t) < Bl.FLEE_MAX
end

--- m5 : origine du temps de tenue, décalée du temps passé au combat ou en fuite depuis la pensée précédente (`last`).
function Bl.held_base(base, last, tick, busy)
  if busy == true and last ~= nil then return num(base) + (num(tick) - num(last)) end
  return base
end

--- m4 : bails de suite d'une tournée (`reset` : la tournée d'avant a réussi, ou aucune n'a échoué).
function Bl.count(prev, reset)
  if reset then return 1 end
  return num(prev) + 1
end

function Bl.pause(n)
  return num(n) >= Bl.HOLD_AFTER
end

local function dist(c)
  local dx, dy = num(c.gx) - num(c.x), num(c.gy) - num(c.y)
  return math.sqrt(dx * dx + dy * dy)
end

--- Relevé : maxpc = étape la plus avancée atteinte pour cette tâche ; work = compteur de travail de l'étape (reconstructions du bâtisseur) ;
--- best = meilleure distance au but de l'étape ; t = tick du dernier progrès.
local function record(cur, best, maxpc, t)
  return { pc = cur.pc, maxpc = maxpc, x = num(cur.x), y = num(cur.y), gx = cur.gx, gy = cur.gy, best = best, work = cur.work, t = t }
end

local function fresh(cur, tick, maxpc)
  return record(cur, cur.gx ~= nil and dist(cur) or nil, maxpc, tick), 0
end

--- prev = relevé précédent (nil : première lecture) ; cur = { pc, x, y, gx, gy, busy, work } (gx, gy : but de l'ÉTAPE en cours, nil sans but ;
--- busy : Bl.busy, le temps au combat ou en fuite ne compte pas ; work : compteur de travail de l'étape, nil sans). Rend (relevé, ticks sans
--- progrès). Lot ETAGE4 (tâches « ghost », accord du lead du 5/11) : une étape compte si elle est PLUS AVANCÉE que toutes celles déjà atteintes
--- (un retour en arrière, « refaire la marche » du bâtisseur, n'est pas un progrès : sinon la boucle marche / chantier / marche le serait à
--- chaque tour) ; un travail fait sur place (compteur qui monte) est un progrès.
function Bl.progress(prev, cur, tick)
  local top = prev and (prev.maxpc or prev.pc)
  if not prev or cur.busy == true or num(cur.pc) > num(top) then return fresh(cur, tick, math.max(num(cur.pc), num(top))) end
  if prev.pc ~= cur.pc then
    -- étape déjà franchie : le temps continue ; l'approche repart de ce point, vers le but de cette étape
    return record(cur, cur.gx ~= nil and dist(cur) or nil, top, prev.t), tick - num(prev.t)
  end
  if cur.work ~= nil and num(cur.work) > num(prev.work) then return fresh(cur, tick, top) end
  if cur.gx ~= nil then
    if prev.gx == nil or math.abs(num(prev.gx) - num(cur.gx)) + math.abs(num(prev.gy) - num(cur.gy)) > Bl.GOAL_EPS then
      return fresh(cur, tick, top)
    end
    local d = dist(cur)
    if d <= num(prev.best) - Bl.MOVE then return record(cur, d, top, tick), 0 end
    return prev, tick - num(prev.t)
  end
  local dx, dy = num(cur.x) - num(prev.x), num(cur.y) - num(prev.y)
  if dx * dx + dy * dy >= Bl.MOVE * Bl.MOVE then return fresh(cur, tick, top) end
  return prev, tick - num(prev.t)
end

--- Bail échu pour une tâche de type `kind` sans progrès depuis `stall` ticks, tenue depuis `held` ticks, pas encore à l'acte (`pre_act`) ?
function Bl.expired(kind, stall, held, pre_act)
  if Bl.KINDS[kind] ~= true then return false end
  if num(stall) >= Bl.LEASE then return true end
  return pre_act == true and num(held) >= Bl.MAX_HOLD
end

--- state = "libre" | "prise" | nil (tournée absente du tableau ou en pause) ; free_age = attente sans preneur ; stall = sans progrès ;
--- held = tenue depuis ; pre_act = pas encore à l'acte.
function Bl.alive(state, free_age, stall, stale, held, pre_act)
  if state == "prise" then return not Bl.expired("service", stall, held, pre_act) end
  if state == "libre" then return num(free_age) < num(stale) end
  return false
end

return Bl
