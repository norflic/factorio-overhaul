-- s52 mesure : la partie de s43-parite-seule (votre equipe seule + 4 factions) avec le profileur en mode DETAIL des le tick 0,
-- pour que Profiler.dump ecrive les entrees de chaque plan de gisement ([FO-PERF3-DUMP] <tick> champ-frame <spec serialisee>).
-- banc.py ... --carte-max --mgs tools/autotest/carte_dc_mgs.json --graine 271828182 -- 54000 s52-dump-champ <source>
-- Extraction : tools/autotest/s52_extrait_spec.py <journal> (spec relisible hors jeu, tests/fixtures/champ_emerald_dc.lua).
local base = require("scenarios/s43-parite-seule")
local init0 = base.init
base.description = "s52 dump champ : s43-parite-seule + profileur detail (Profiler.dump des specs de Champ.frame)"
base.init = function(ctx)
  init0(ctx)
  ctx.call("profiler", true, "detail")
end
return base
