-- Lot IA3-c : la partie de MESURE d'IA3-DIAG « reduit » (guide du DC : Facile, 2 factions, 30 soldats, 4 ouvriers, coffre
-- d'équipe) avec le CERVEAU PAR BESOINS (fo-war-ia3-cerveau allumé AVANT la guerre : figé par chaque équipe à sa
-- première pensée). Lancement : fo-autotest.bat nopause 432000 ia3c-reduit <source>. Journal : [FO-IA3C-REDUIT].
-- Avant / après sur la MÊME source : ia3d-reduit (réglage éteint) contre ia3c-reduit ; tools/autotest/ia3c_compare.py.
local base = require("scenarios/ia3d_common")("reduit")
local init0 = base.init
base.init = function(ctx)
  local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-cerveau", true)
  ctx.check(v == true, "reglage fo-war-ia3-cerveau allume (essai IA3-c)", tostring(v))
  init0(ctx)
end
return base
