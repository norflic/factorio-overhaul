-- Lot EXPERIMENTAUX-PUISSANCE (7/11) : xp-zone avec d'autres budgets par tick (200 coups, 75 morts : 5 forces à 40 et 15 chacune, revue 0.6.57 point 3), pour mesurer le coût du
-- script et des débris par mort à plusieurs cadences (pics_zone.py --debris). Bancs de mesure seulement (--seul) ; mêmes contrôles qu'xp-zone.
local Z = require("scenarios/xp-zone")
local W = {}
for _, k in ipairs({ "description", "check_tick", "tick", "finish" }) do W[k] = Z[k] end
W.description = Z.description .. " ; budgets 200 coups, 75 morts par tick (5 forces)"
W.init = function(ctx)
  remote.call("fo-xp", "budgets", 200, 75)
  return Z.init(ctx)
end
return W
