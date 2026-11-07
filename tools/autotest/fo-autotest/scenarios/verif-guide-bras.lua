-- Lot AGEBLOCAGE (étage chantiers) : la partie du guide (scenarios/verif-guide.lua, 4 ouvriers) avec la sonde [FO-BRAS] ALLUMÉE (lecture
-- seule, éteinte par défaut dans le mod : script/team/board.lua). Aucun contrôle ajouté : le BILAN reste celui de verif-guide (16 OK).
-- Lancement : banc.py --out <archive> --graine 271828182 --qui AGEBLOCAGE -- 216000 verif-guide-bras <source>
local base = require("scenarios/verif_guide_common")(4)
local out = {}
for k, v in pairs(base) do out[k] = v end
out.description = tostring(base.description) .. " ; sonde [FO-BRAS] allumee"
out.init = function(ctx)
  base.init(ctx)
  local on = remote.interfaces["fo-bras"] and remote.call("fo-bras", "set", true)
  ctx.log("sonde [FO-BRAS] allumee : " .. tostring(on))
end
return out
