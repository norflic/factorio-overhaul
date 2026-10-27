-- Lot IA3-b : la partie du guide du DC (comme ia3d-reduit) AVEC le réglage fo-war-ia3-marche allumé AVANT la guerre
-- (il est figé par chaque équipe à sa première lecture). Avant / après sur la MÊME source : ia3d-reduit (réglage
-- éteint) contre ia3b-reduit, mêmes graines ; même analyse (tools/autotest/ia3d_analyse.py, ia3b_mesures.py).
-- Lancement : fo-autotest.bat nopause 432000 ia3b-reduit <source>. Journal : [FO-IA3B-REDUIT] (lu par ia3b_mesures.py).
local sc = require("scenarios/ia3d_common")("reduit")
local init0 = sc.init
sc.init = function(ctx)
  local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-marche", true)
  ctx.check(v == true, "reglage fo-war-ia3-marche allume (essai IA3-b)", tostring(v))
  init0(ctx)
end
sc.description = sc.description .. ", IA3-b"
return sc
