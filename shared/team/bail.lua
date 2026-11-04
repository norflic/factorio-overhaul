--[[
  Lot ETAGE4 (4/11) : BAIL des tournées d'avant-poste. PUR : aucune API du moteur, aucun nom d'objet.
  Défaut mesuré (fo-logs/2026-11-03_AGEBLOCAGE/fd-croiss-123456789, fo-logs/2026-11-04_ETAGE4/RAPPORT.md) : la tournée de l'avant-poste de
  charbon n° 1 d'Émeraude reste « prise » 41 min, son PNJ immobile à côté ; le tableau garde toute tâche prise tant que le PNJ ne la rend pas
  (script/team/board.lua, Board.sync) : aucun bail, aucune échéance. 12 archives de dc-croissance, témoins de main compris.
  Règles :
    Bl.progress(prev, cur, tick) -> relevé du dernier PROGRÈS du PNJ qui tient la tâche, et le temps sans progrès. Progrès = autre étape
                                    du programme, autre état de la machine, ou déplacement d'au moins Bl.MOVE tuile depuis le dernier progrès.
    Bl.expired(kind, stall, held) -> le bail est-il échu ? Seulement pour les types de Bl.KINDS (les tournées : un PNJ en tournée marche ou
                                    agit sans cesse ; une fabrication ou une garde reste sur place par nature). Échu sans progrès depuis Bl.LEASE,
                                    ou tenue depuis Bl.MAX_HOLD même en bougeant (essai 2 : une tournée d'Azur tenue 489 s en tournant en rond,
                                    banc lot-croiss-123456789 ; aller et retour à 400 tuiles : moins de 2 min de marche).
    Bl.alive(state, free_age, stall, stale, held) -> la tournée va-t-elle chercher ce qui attend ? Libre depuis moins de `stale`, ou prise avec
                                    un progrès depuis moins de Bl.LEASE et depuis moins de Bl.MAX_HOLD. Absente : non.
]]
local Bl = {}

Bl.LEASE = 2 * 3600       -- ticks sans progrès au-delà desquels une tournée prise est rendue (une tournée normale dure 1 à 2 min en marchant)
Bl.MOVE = 1               -- tuiles : déplacement qui compte comme un progrès (cumulé depuis le dernier progrès)
Bl.MAX_HOLD = 3 * 3600    -- ticks au-delà desquels une tournée prise est rendue même si son PNJ bouge (essai 2 ; aller et retour à 400 tuiles en
                          -- moins de 2 min de marche : 50 % de marge)
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

--- Bail échu pour une tâche de type `kind` sans progrès depuis `stall` ticks, tenue depuis `held` ticks ?
function Bl.expired(kind, stall, held)
  if Bl.KINDS[kind] ~= true then return false end
  return num(stall) >= Bl.LEASE or num(held) >= Bl.MAX_HOLD
end

--- state = "libre" | "prise" | nil (tournée absente du tableau ou en pause) ; free_age = attente sans preneur ; stall = sans progrès ;
--- held = tenue depuis.
function Bl.alive(state, free_age, stall, stale, held)
  if state == "prise" then return num(stall) < Bl.LEASE and num(held) < Bl.MAX_HOLD end
  if state == "libre" then return num(free_age) < num(stale) end
  return false
end

return Bl
