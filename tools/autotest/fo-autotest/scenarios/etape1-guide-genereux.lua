-- Lot KIT : TÉMOIN de etape1-guide, kit de départ GÉNÉREUX des factions (réglage fo-war-kit-genereux allumé : l'ancien kit,
-- 12 foreuses, 8 fours, 200 plaques de fer…, moins les 50 bois). Même partie, mêmes relevés (dont [FO-ETAPE1-GUIDE] kit-mesure).
local base = require("scenarios/etape1-guide")
local init0 = base.init
base.description = base.description .. " -- TEMOIN : kit de depart genereux des factions"
base.init = function(ctx)
  if init0 then init0(ctx) end
  local k = ctx.call("war_setting", "fo-war-kit-genereux", true)
  ctx.check(k == true, "kit genereux des factions allume (temoin)", tostring(k))
end
return base
