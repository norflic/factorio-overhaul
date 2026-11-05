-- Lot AGEBLOCAGE (acier) : la partie du DC (scenarios/ageblocage-dc.lua) avec la sonde [FO-ACIER] ALLUMÉE (lecture seule, éteinte par
-- défaut : script/team/board.lua, script/team/stock.lua). Aucun contrôle ajouté : le BILAN reste celui de ageblocage-dc.
-- Lancement : banc.py --out <archive> --graine 717152950 --qui AGEBLOCAGE -- 216600 ageblocage-dc-acier <source>
local base = require("scenarios/ageblocage-dc")
local out = {}
for k, v in pairs(base) do out[k] = v end
out.description = tostring(base.description) .. " ; sonde [FO-ACIER] allumee"
out.init = function(ctx)
  base.init(ctx)
  local on = remote.interfaces["fo-acier"] and remote.call("fo-acier", "watch",
    { "steel-plate", "assembling-machine-2", "medium-electric-pole", "steel-furnace", "electronic-circuit" })
  ctx.log("sonde [FO-ACIER] allumee : " .. tostring(on))
end
return out
