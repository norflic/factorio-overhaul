-- Lot IA3-c : la partie de MESURE d'IA3-DIAG « default » (4 factions, 100 soldats, 10 ouvriers dont 8 au départ, Paisible)
-- avec le CERVEAU PAR BESOINS (fo-war-ia3-cerveau allumé AVANT la guerre). Lancement : fo-autotest.bat nopause 432000
-- ia3c-default <source>. Journal : [FO-IA3C-DEFAULT]. Avant / après sur la MÊME source : ia3d-default contre
-- ia3c-default ; tools/autotest/ia3c_compare.py.
local base = require("scenarios/ia3d_common")("default")
local init0 = base.init
base.init = function(ctx)
  local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-cerveau", true)
  ctx.check(v == true, "reglage fo-war-ia3-cerveau allume (essai IA3-c)", tostring(v))
  init0(ctx)
end
return base
