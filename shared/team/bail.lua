--[[
  Lot ETAGE4 (4/11) : BAIL des tournées d'avant-poste. PUR : aucune API du moteur, aucun nom d'objet.
  Défaut mesuré (fo-logs/2026-11-03_AGEBLOCAGE/fd-croiss-123456789, fo-logs/2026-11-04_ETAGE4/RAPPORT.md) : la tournée de l'avant-poste de
  charbon n° 1 d'Émeraude reste « prise » 41 min, son PNJ immobile à côté ; le tableau garde toute tâche prise tant que le PNJ ne la rend pas
  (script/team/board.lua, Board.sync) : aucun bail, aucune échéance. 12 archives de dc-croissance, témoins de main compris.
  Règles :
    Bl.progress(prev, cur, tick) -> relevé du dernier PROGRÈS du PNJ qui tient la tâche, et le temps sans progrès. Progrès = autre étape
                                    du programme, autre état de la machine, ou déplacement d'au moins Bl.MOVE tuile depuis le dernier progrès.
    Bl.expired(kind, stall)      -> le bail est-il échu ? Seulement pour les types de Bl.KINDS (les tournées : un PNJ en tournée marche ou
                                    agit sans cesse ; une fabrication ou une garde reste sur place par nature).
    Bl.alive(state, free_age, stall, stale) -> la tournée va-t-elle chercher ce qui attend ? Libre depuis moins de `stale`, ou prise avec un
                                    progrès depuis moins de Bl.LEASE. Absente : non.
]]
local Bl = {}

Bl.LEASE = 2 * 3600       -- ticks sans progrès au-delà desquels une tournée prise est rendue (une tournée normale dure 1 à 2 min en marchant)
Bl.MOVE = 1               -- tuiles : déplacement qui compte comme un progrès (cumulé depuis le dernier progrès)
Bl.KINDS = { service = true }

local function num(v) return type(v) == "number" and v or 0 end

--- prev = { pc, state, x, y, t } (nil : première lecture) ; cur = { pc, state, x, y }. Rend (relevé, ticks sans progrès).
function Bl.progress(prev, cur, tick)
  if not prev or prev.pc ~= cur.pc or prev.state ~= cur.state then
    return { pc = cur.pc, state = cur.state, x = num(cur.x), y = num(cur.y), t = tick }, 0
  end
  local dx, dy = num(cur.x) - num(prev.x), num(cur.y) - num(prev.y)
  if dx * dx + dy * dy >= Bl.MOVE * Bl.MOVE then
    return { pc = cur.pc, state = cur.state, x = num(cur.x), y = num(cur.y), t = tick }, 0
  end
  return prev, tick - num(prev.t)
end

--- Bail échu pour une tâche de type `kind` sans progrès depuis `stall` ticks ?
function Bl.expired(kind, stall)
  return Bl.KINDS[kind] == true and num(stall) >= Bl.LEASE
end

--- state = "libre" | "prise" | nil (tournée absente du tableau ou en pause) ; free_age = attente sans preneur ; stall = sans progrès.
function Bl.alive(state, free_age, stall, stale)
  if state == "prise" then return num(stall) < Bl.LEASE end
  if state == "libre" then return num(free_age) < num(stale) end
  return false
end

return Bl
