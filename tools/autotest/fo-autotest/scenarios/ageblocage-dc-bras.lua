-- Lot AGEBLOCAGE (étage chantiers) : la partie du DC (scenarios/ageblocage-dc.lua) avec la sonde [FO-BRAS] ALLUMÉE (lecture seule, éteinte
-- par défaut dans le mod : script/team/board.lua). Aucun contrôle ajouté : le BILAN reste celui de ageblocage-dc.
-- Lancement : banc.py --out <archive> --graine 717152950 --qui AGEBLOCAGE -- 216600 ageblocage-dc-bras <source>
local base = require("scenarios/ageblocage-dc")
local out = {}
for k, v in pairs(base) do out[k] = v end
out.description = tostring(base.description) .. " ; sonde [FO-BRAS] allumee"
out.init = function(ctx)
  base.init(ctx)
  local on = remote.interfaces["fo-bras"] and remote.call("fo-bras", "set", true)
  ctx.log("sonde [FO-BRAS] allumee : " .. tostring(on))
end
return out
