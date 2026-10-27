-- Lot IA3-b : la partie `default` (comme ia3d-default) AVEC le réglage fo-war-ia3-marche allumé au début du scénario.
-- La base « default » lance la guerre AVANT l'init du scénario : les équipes figent le réglage à leur PREMIÈRE pensée
-- (Board.market), qui vient après (pensée toutes les 300 ticks). Journal : [FO-IA3B-DEFAULT] (lu par ia3b_mesures.py).
-- Lancement : fo-autotest.bat nopause 432000 ia3b-default <source>.
local sc = require("scenarios/ia3d_common")("default")
local init0 = sc.init
sc.init = function(ctx)
  local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-marche", true)
  ctx.check(v == true, "reglage fo-war-ia3-marche allume (essai IA3-b)", tostring(v))
  init0(ctx)
end
sc.description = sc.description .. ", IA3-b"
return sc
