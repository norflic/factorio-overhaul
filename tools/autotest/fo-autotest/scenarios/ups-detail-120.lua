-- Lot UPS (13/11) : partie-reelle-120 avec le profileur en détail par tick ([FO-PERF3-T], tools/autotest/perf3.py) pour
-- attribuer les pics de script entre 60 et 120 min. Mêmes décisions que partie-reelle-120 (le profileur ne décide de rien).
local S = require("scenarios/pavage_common")(120, "partie")
S.description = "UPS : partie-reelle-120, profileur detail"
S.init = function(ctx)
  ctx.call("profiler", true, "detail")
end
return S
