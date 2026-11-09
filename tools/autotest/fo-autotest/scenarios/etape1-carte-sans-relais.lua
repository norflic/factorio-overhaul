--[[
  Lot MODULES-ORDRE (9/11) : TÉMOIN A/B de etape1-carte (partie du guide, Normal, carte aux gisements à 600 %, 120 min) avec le relais de la porte
  du transport ÉTEINT (réglage fo-war-relais décoché) : même arbre, même graine, seule la règle change. L'« après » est etape1-carte telle quelle
  (réglage allumé par défaut, settings/relais.lua).
  Lancement (comme etape1-carte) :
    py -3.9 -B tools/autotest/banc.py --carte-max --graine <N> --out <archive> --qui <lot> -- 432200 etape1-carte-sans-relais <source>
  Lecture : PYTHONUTF8=1 py -3.9 -B tools/autotest/modules_ordre_lecture.py <archive avant> <archive apres>
]]
local carte = require("scenarios/etape1-carte")
local base = {}
for k, v in pairs(carte) do base[k] = v end
local init0 = carte.init

base.description = "ETAPE1-CARTE sans relais : temoin A/B du lot MODULES-ORDRE (fo-war-relais decoche)"
base.init = function(ctx)
  local v = ctx.call("war_setting", "fo-war-relais", false)
  ctx.check(v == false, "reglage fo-war-relais decoche (temoin)", tostring(v))
  if init0 then init0(ctx) end
end

return base
