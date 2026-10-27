--[[
  Lot PERF (27/10) : la partie d'ia1-scale (4 factions × 30 PNJ + votre équipe à 30, 60 min) avec le profileur en mode FIN
  (portées « brain:<machine>:<état> », « ia3k:gate », « ia3k:leg », « ia3k:sense », « worker:program », « board:claim »,
  « act:<action> »…). Sert au CLASSEMENT des contributeurs du coût script (banc ordinaire) ; la mesure K10 de référence se
  fait sur ia1-scale (profileur ordinaire), en --seul. Mêmes décisions qu'ia1-scale (le profileur ne décide de rien).
  Lancement : banc.py ... -- 216000 perf-scale <source>. Lecture : les blocs « Profiler (fenetre N ticks) » du journal.
]]
local base = require("scenarios/ia1-scale")

local S = {}
for k, v in pairs(base) do S[k] = v end
S.description = "PERF : ia1-scale avec le profileur fin (classement des contributeurs du temps script)"
S.init = function(ctx)
  base.init(ctx)
  ctx.call("profiler", true, true)
  ctx.call("reset_stats")
end
return S
