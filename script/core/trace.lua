--[[
  Traces de diagnostic (bancs de test uniquement : actives quand le profileur l'est). Une ligne
  « [FO-TRACE] <tick> <type> <a> <b> » par événement potentiellement coûteux ; tools/autotest/analyze.py
  les recoupe avec les temps par tick du benchmark pour attribuer les pics de scriptUpdate.
]]

local Profiler = require("script.core.profiler")

local Trace = {}

function Trace.log(kind, a, b)
  if not Profiler.enabled() then return end
  log("[FO-TRACE] " .. game.tick .. " " .. kind .. " " .. tostring(a) .. " " .. tostring(b))
end

return Trace
