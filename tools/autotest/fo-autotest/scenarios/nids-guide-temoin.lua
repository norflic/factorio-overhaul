-- Lot NIDS : TÉMOIN de nids-guide, réglage fo-war-nids COUPÉ (le nettoyage d'avant le lot, sur le même code). Même partie,
-- mêmes relevés [FO-NIDS-MES].
local base = require("scenarios/nids-guide")
local init0 = base.init
base.description = base.description .. " -- TEMOIN : fo-war-nids coupe"
base.init = function(ctx)
  local c = ctx.call("war_setting", "fo-war-nids", false)
  ctx.check(c == false, "reglage fo-war-nids coupe (temoin)", tostring(c))
  if init0 then init0(ctx) end
end
return base
