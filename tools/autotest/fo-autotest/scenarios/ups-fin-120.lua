-- Lot UPS (13/11) : partie-reelle-120 avec les portées FINES du profileur (cumul par fenêtre, tools/autotest : blocs « Profiler »)
-- et le recensement du stockage à 60 et 120 min. Mêmes décisions que partie-reelle-120 (le profileur ne décide de rien).
local S = require("scenarios/ups-recensement-120")
S.description = "UPS : partie-reelle-120, profileur fin, recensement"
S.init = function(ctx)
  ctx.call("profiler", true, true)
end
return S
