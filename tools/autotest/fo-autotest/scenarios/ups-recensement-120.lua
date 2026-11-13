-- Lot UPS (13/11) : partie-reelle-120 (mêmes mesures, même profileur) plus le recensement du stockage persistant du mod
-- ([FO-RECENSEMENT], script/core/recensement.lua) à 60 et 120 min, un tick après les mesures. Lecture seule.
local S = require("scenarios/pavage_common")(120, "partie")
S.description = "UPS : partie-reelle-120 et recensement du stockage a 60 et 120 min"
local tick0 = S.tick
S.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick == 216001 or e.tick == 432001 then
    ctx.call("storage_census", string.format("min=%d", (e.tick - 1) / 3600), 5, 200)
  end
end
return S
