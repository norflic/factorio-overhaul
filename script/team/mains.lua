--[[
  LOT MAINS (mesure) : ce que les PNJ d'une équipe font À LA MAIN, par genre de tâche et par détail, avec le travail de fond
  séparé (shared/team/mains.lua). Crochet de fin de tâche (Board.finish) ; une ligne « [FO-MAINS] » toutes les 10 minutes
  par équipe (cumul depuis le début de la partie). Mesure seulement : aucune décision n'en dépend.
]]

local State = require("script.faction.state")
local T = require("shared.team.config")
local Mains = require("shared.team.mains")

local M = {}
M.PERIOD = 10 -- minutes entre deux lignes

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

--- Fin d'une tâche (réussie ou non) de l'équipe `f`.
function M.on_done(f, task, ok, tick)
  if not (f and f.team and task) then return end
  local st = f.team.mains
  if not st then st = { acc = {}, last = 0 }; f.team.mains = st end
  local secs = task.claimed and (tick - task.claimed) / 60 or 0
  local label = Mains.label(task, function(oid)
    local o = f.outposts and f.outposts[oid]
    local spec = o and T.outposts[o.kind]
    return spec and spec.product or nil
  end, function(tk)
    -- minage de l'entrée d'une plaque, ou fonte de plaques : la plaque est-elle saturée au cerveau (f.team.ia3.saturated) ?
    local sat = f.team.ia3 and f.team.ia3.saturated or {}
    if tk.kind == "mine" then
      for _, p in ipairs(Mains.sorted_keys(T.smelter_inputs)) do
        if T.smelter_inputs[p][1] == tk.resource then return sat[p] == true end
      end
    elseif tk.kind == "smelt" then
      local any = false
      for _, p in ipairs(Mains.sorted_keys(tk.smelt)) do
        if sat[p] ~= true then return false end
        any = true
      end
      return any
    end
    return false
  end)
  Mains.add(st.acc, label, ok, secs, Mains.units(task))
  local m = math.floor(minutes(f, tick) / M.PERIOD)
  if m > st.last then
    st.last = m
    log(string.format("[FO-MAINS] %s minute %d | %s", f.key or "player", m * M.PERIOD, Mains.format(st.acc)))
  end
end

return M
