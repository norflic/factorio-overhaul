-- Lot ECHELON : TEMOIN de dc-croissance, reglage fo-war-echelon ETEINT des l'init (meme partie, meme graine).
-- Lancement : banc.py --out <archive> --graine <g> --qui ECHELON -- 216000 dc-croissance-sansechelon <source>
local base = require("scenarios/dc_evolution_common")(860000)
local init0 = base.init
base.init = function(ctx)
  init0(ctx)
  local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-echelon", false)
  ctx.check(v == false, "TEMOIN : fo-war-echelon eteint", tostring(v))
end
return base
