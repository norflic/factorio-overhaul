--[[
  Lot CAPITAL (correction après revue, 27/10) : un scénario de main joué RÉGLAGE fo-war-capital ALLUMÉ.
  Le réglage est ÉTEINT par défaut (settings/capital.lua) : verif-guide et pnj-reduit joués tels quels mesurent le mod
  livré (lot éteint, doit égaler main) ; ces variantes mesurent le lot allumé, sans toucher aux scénarios de main.
  Seule différence avec le scénario d'origine : le réglage est écrit au début de son init (relais war_setting), avec un
  contrôle de plus au BILAN (« reglage fo-war-capital allume »). Journal : [FO-CAPITAL-<NOM>] au lieu de [FO-<NOM>].
  Lancement : banc.py ... -- 216000 capital-verif-guide <source> ; banc.py ... -- 108000 capital-pnj-reduit <source>.
]]

return function(name)
  local base = require("scenarios/" .. name)
  local init0 = base.init
  base.description = "CAPITAL (reglage fo-war-capital allume) : " .. tostring(base.description or name)
  base.init = function(ctx)
    local on = ctx.call("war_setting", "fo-war-capital", true)
    ctx.check(on == true, "reglage fo-war-capital allume", tostring(on))
    if init0 then init0(ctx) end
  end
  return base
end
