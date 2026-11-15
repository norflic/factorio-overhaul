--[[
  Lot joueur-parite (14/11) : journal [FO-PARITE-JOUEUR] toutes les 5 minutes de partie : votre équipe contre la moyenne des factions
  vivantes (règle pure : shared/team/parite_joueur.lua). Lecture seule, aucune décision n'en dépend.
  Branchement : require depuis script/team/player_team.lua (aucune ligne dans control.lua).
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Pj = require("shared.team.parite_joueur")

local M = {}

M.PERIOD = 5 * 3600

local function techs_of(force)
  local n = 0
  for _, t in pairs(force.technologies) do if t.researched then n = n + 1 end end -- un compte : l'ordre de pairs est sans effet
  return n
end

local function row(key, f)
  local drills = 0
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do drills = drills + ((f.outposts[oid].drills) or 0) end
  local force = f.force and game.forces[f.force]
  return { key = key, workers = f.engineers_count or 0, outposts = f.outposts_count or #State.sorted_keys(f.outposts or {}),
    drills = drills, smelters = #(f.smelters or {}), techs = (force and force.valid) and techs_of(force) or 0 }
end

function M.scan(tick)
  local me = State.faction("player")
  if not (me and me.hq and me.hq.valid) then return end
  local rows = {}
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and f.hq_pos then rows[#rows + 1] = row(tostring(f.key or id), f) end
  end
  rows[#rows + 1] = row("player", me)
  local line = Pj.line(rows, tick / 3600)
  if line then log(line) end
end

Events.on_nth_tick(M.PERIOD, function(e) M.scan(e.tick) end)

return M
