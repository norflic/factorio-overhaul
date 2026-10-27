--[[
  Lot CAPIB : un scénario de main joué RÉGLAGES fo-war-ia3e ET fo-war-capi ALLUMÉS (la capitalisation n'agit qu'avec
  l'automatisation, son exécutant). Les deux réglages sont ÉTEINTS par défaut : verif-guide et pnj-reduit joués tels quels
  mesurent le mod livré (doit égaler main 0.6.4) ; ces variantes mesurent le lot allumé, sans toucher aux scénarios de
  main. Seule différence avec le scénario d'origine : les réglages sont écrits au début de son init (relais war_setting),
  avec deux contrôles de plus au BILAN. Journal : [FO-CAPI-<NOM>] au lieu de [FO-<NOM>].
  Lancement : banc.py ... -- 216000 capi-verif-guide <source> ; banc.py ... -- 216000 capi-pnj-reduit <source>.
]]

return function(name)
  local base = require("scenarios/" .. name)
  local init0 = base.init
  base.description = "CAPIB (reglages fo-war-ia3e et fo-war-capi allumes) : " .. tostring(base.description or name)
  base.init = function(ctx)
    local a = ctx.call("war_setting", "fo-war-ia3e", true)
    ctx.check(a == true, "reglage fo-war-ia3e allume", tostring(a))
    local on = ctx.call("war_setting", "fo-war-capi", true)
    ctx.check(on == true, "reglage fo-war-capi allume", tostring(on))
    if init0 then init0(ctx) end
  end
  return base
end
