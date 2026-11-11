--[[
  GEANTS-MARCHE-PROF (mesure UPS du mandat de nuit, 11/11) : le scénario geants-marche (unités qui bougent
  de 8 directions), profileur du mod allumé à l'init et rapport complet du profileur ([log_report]) à la fin : coût par tick des
  scripts des titans (balayage du corps, segments du Léviathan) quand des titans existent et bougent. Aucun contrôle de plus.
]]
local B = require("scenarios/geants-marche")
local W = {}
for k, v in pairs(B) do W[k] = v end
W.shots = nil
W.init = function(ctx)
  remote.call("factorio-overhaul", "profiler", true)
  remote.call("factorio-overhaul", "reset_stats")
  return B.init(ctx)
end
W.finish = function(ctx)
  remote.call("factorio-overhaul", "log_report", "fin geants-marche-prof")
  return B.finish(ctx)
end
return W
