-- Lot EXPERIMENTAUX-PUISSANCE (7/11) : xp-zone avec d'autres budgets par tick (80 coups, 60 morts au lieu de 40 et 15), pour mesurer le coût du
-- script et des débris par mort à plusieurs cadences (pics_zone.py --debris). Bancs de mesure seulement (--seul) ; mêmes contrôles qu'xp-zone.
local Z = require("scenarios/xp-zone")
local W = {}
for _, k in ipairs({ "description", "check_tick", "tick", "finish" }) do W[k] = Z[k] end
W.description = Z.description .. " ; budgets 80 coups, 60 morts par tick"
W.init = function(ctx)
  remote.call("fo-xp", "budgets", 80, 60)
  return Z.init(ctx)
end
return W
