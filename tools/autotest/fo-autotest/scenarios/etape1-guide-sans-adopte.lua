-- Lot ADOPTE : TÉMOIN de etape1-guide, réglage fo-war-adopte COUPÉ (ni adoption ni pose des fours dormants : le comportement
-- d'avant, sur le même code). Même partie, mêmes relevés ; comparer les « dormants fours » de [FO-ETAPE1-GUIDE].
local base = require("scenarios/etape1-guide")
local init0 = base.init
base.description = base.description .. " -- TEMOIN : fo-war-adopte coupe"
base.init = function(ctx)
  local c = ctx.call("war_setting", "fo-war-adopte", false)
  ctx.check(c == false, "reglage fo-war-adopte coupe (temoin)", tostring(c))
  if init0 then init0(ctx) end
end
return base
