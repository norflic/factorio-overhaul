--[[
  Machine à états générique.

  - Les états sont des tables de fonctions { enter, think, exit } définies au chargement (jamais stockées).
  - L'objet piloté ne porte que des données sérialisables : obj.state (chaîne) et obj.state_tick.
  - Un observateur optionnel par machine (ex. rendu de debug) est notifié à chaque transition.
]]

local FSM = {}

local machines = {}  -- [machine] = { states = {...}, observer = fn|nil }

function FSM.define(machine, states)
  assert(not machines[machine], "machine déjà définie : " .. machine)
  machines[machine] = { states = states }
end

function FSM.observe(machine, fn)
  machines[machine].observer = fn
end

function FSM.set(machine, obj, new_state, tick)
  local m = machines[machine]
  local states = m.states
  local nxt = states[new_state]
  if not nxt then error("FSM " .. machine .. " : état inconnu " .. tostring(new_state)) end
  local cur = states[obj.state]
  if cur and cur.exit then cur.exit(obj, tick) end
  obj.state = new_state
  obj.state_tick = tick
  if nxt.enter then nxt.enter(obj, tick) end
  if m.observer then m.observer(obj, tick) end
end

function FSM.think(machine, obj, tick)
  local m = machines[machine]
  if not m then return end -- machine d'une ancienne version (sauvegarde migrée) : inerte
  local s = m.states[obj.state]
  if s and s.think then s.think(obj, tick) end
end

--- Événement externe (ex. "nav_arrived") : appelle states[état].on[event] s'il existe.
function FSM.event(machine, obj, event, tick)
  local m = machines[machine]
  if not m then return end
  local s = m.states[obj.state]
  local h = s and s.on and s.on[event]
  if h then h(obj, tick) end
end

function FSM.exists(machine)
  return machines[machine] ~= nil
end

return FSM
