-- Lot RECONSTRUCTION-0716 : partie-jalons-120 SANS les deux règles du lot (fabrication des pièces d'avant-poste, combustible des pièces refaites),
-- coupées par l'interface de banc fo-recon : témoin de la même source sur la même carte.
local base = require("scenarios/jalons_common")(120)
local init0, tick0 = base.init, base.tick
local function off()
  remote.call("fo-recon", "set_ruin_craft", false)
  remote.call("fo-recon", "set_prime", false)
end
base.init = function(ctx) init0(ctx) off() end
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick % 3600 == 0 then off() end
end
return base
