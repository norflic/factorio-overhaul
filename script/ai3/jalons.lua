--[[
  Lot VIDEO-TRACES, partie b (V03) : journal [FO-JALON] des factions. Toutes les 10 s (600 ticks), le niveau d'époque du centre de
  chaque faction vivante (script/faction/centre_qg.lua, CentreQG.level) est lu ; chaque époque NOUVELLE donne une ligne, une fois,
  à la minute de partie du relevé (précision : 10 s). La règle est pure (shared/ai3/jalons.lua, tests/jalons_test.lua).
  Mémoire : Storage.ns("jalons").seen (persistante, par storage.lua). Aucune décision ne lit ce journal.
  Branchement : require("script.ai3.jalons") dans control.lua (intégrateur).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local State = require("script.faction.state")
local CentreQG = require("script.faction.centre_qg")
local Jal = require("shared.ai3.jalons")

local M = {}

M.PERIOD = 600 -- ticks entre deux relevés (10 s)

Storage.declare("jalons", function() return { seen = {} } end)

local function seen() return Storage.ns("jalons").seen end

-- Minutes de partie d'une faction (même base que script/ai3/capitalisation.lua : début de la faction, sinon de la guerre).
local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

--- Un relevé : une ligne par époque nouvelle et par faction vivante, ids triés (ordre fixe).
function M.scan(tick)
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f then
      for _, k in ipairs(Jal.crossed(seen(), id, CentreQG.level(f))) do
        log(Jal.line(id, k, minutes(f, tick)))
      end
    end
  end
end

Events.on_nth_tick(M.PERIOD, function(e) M.scan(e.tick) end)

return M
