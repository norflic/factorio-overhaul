--[[
  Lot ETAGE4 (4/11) : BAIL des tournées d'avant-poste. PUR : aucune API du moteur, aucun nom d'objet.
  Défaut mesuré (fo-logs/2026-11-03_AGEBLOCAGE/fd-croiss-123456789, fo-logs/2026-11-04_ETAGE4/RAPPORT.md) : la tournée de l'avant-poste de
  charbon n° 1 d'Émeraude reste « prise » 41 min, son PNJ immobile à côté ; le tableau garde toute tâche prise tant que le PNJ ne la rend pas
  (script/team/board.lua, Board.sync) : aucun bail, aucune échéance. 12 archives de dc-croissance, témoins de main compris.
  Règles :
    Bl.progress(prev, cur, tick) -> relevé du dernier PROGRÈS du PNJ qui tient la tâche, et le temps sans progrès. Progrès (revue du lead,
                                    M1, 5/11) = autre étape du programme, autre état de la machine, autre BUT d'étape (nouveau point de passage),
                                    ou approche du but d'au moins Bl.MOVE tuile PLUS PRÈS QUE JAMAIS pour ce but. Un PNJ qui tourne en rond
                                    sans s'approcher ne progresse pas. Sans but connu : déplacement d'au moins Bl.MOVE tuile depuis le dernier
                                    progrès (règle de l'essai 1).
    Bl.expired(kind, stall, held, pre_act) -> le bail est-il échu ? Seulement pour les types de Bl.KINDS (les tournées). Échu sans progrès depuis
                                    Bl.LEASE ; ou tenue depuis Bl.MAX_HOLD AVANT l'acte (essai 2 ; M1 : le retour au QG après l'acte, travail
                                    fait, n'est plus coupé par la tenue maximale, seulement par l'absence de progrès).
    Bl.alive(state, free_age, stall, stale, held, pre_act) -> la tournée va-t-elle chercher ce qui attend ? Libre depuis moins de `stale`, ou
                                    prise et pas échue au sens de Bl.expired. Absente : non.
]]
local Bl = {}

Bl.LEASE = 2 * 3600       -- ticks sans progrès au-delà desquels une tournée prise est rendue (une tournée normale dure 1 à 2 min en marchant)
Bl.MOVE = 1               -- tuiles : approche (ou déplacement sans but) qui compte comme un progrès
Bl.GOAL_EPS = 0.5         -- tuiles : un but qui bouge de plus est un AUTRE but (nouveau point de passage)
Bl.MAX_HOLD = 3 * 3600    -- ticks au-delà desquels une tournée prise et pas encore à l'acte est rendue même si son PNJ bouge (essai 2 ; aller
                          -- et retour à 400 tuiles en moins de 2 min de marche : 50 % de marge)
Bl.KINDS = { service = true }

local function num(v) return type(v) == "number" and v or 0 end

local function dist(c)
  local dx, dy = num(c.gx) - num(c.x), num(c.gy) - num(c.y)
  return math.sqrt(dx * dx + dy * dy)
end

local function fresh(cur, tick)
  return { pc = cur.pc, state = cur.state, x = num(cur.x), y = num(cur.y), gx = cur.gx, gy = cur.gy,
    best = cur.gx ~= nil and dist(cur) or nil, t = tick }, 0
end

--- prev = relevé précédent (nil : première lecture) ; cur = { pc, state, x, y, gx, gy } (gx, gy : but de l'étape en cours, nil sans but).
--- Rend (relevé, ticks sans progrès).
function Bl.progress(prev, cur, tick)
  if not prev or prev.pc ~= cur.pc or prev.state ~= cur.state then return fresh(cur, tick) end
  if cur.gx ~= nil then
    if prev.gx == nil or math.abs(num(prev.gx) - num(cur.gx)) + math.abs(num(prev.gy) - num(cur.gy)) > Bl.GOAL_EPS then
      return fresh(cur, tick)
    end
    local d = dist(cur)
    if d <= num(prev.best) - Bl.MOVE then
      return { pc = cur.pc, state = cur.state, x = num(cur.x), y = num(cur.y), gx = cur.gx, gy = cur.gy, best = d, t = tick }, 0
    end
    return prev, tick - num(prev.t)
  end
  local dx, dy = num(cur.x) - num(prev.x), num(cur.y) - num(prev.y)
  if dx * dx + dy * dy >= Bl.MOVE * Bl.MOVE then return fresh(cur, tick) end
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
