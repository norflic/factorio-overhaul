--[[
  Lot PERIMETRE2 (G3) : la partie du DC (ageblocage-dc, graine 717152950) avec l'enceinte de votre équipe et les murs de ses avant-postes
  attaqués allumés (fo-garde g3) et l'anneau court en zone « qg » (fo-garde zone) ; défauts du mod inchangés. Témoin : ageblocage-dc-temoin.
  Lancement : banc.py --out <archive> --graine 717152950 --qui PERIMETRE2 -- 540000 ageblocage-dc-g3-qg <source>
]]
local base = require("scenarios/ageblocage-dc-g3")
local init0 = base.init
base.description = "PERIMETRE2 : partie du DC, G3 allume, anneau court en zone qg"
base.init = function(ctx)
  init0(ctx)
  local ok = ctx.remote("fo-garde", "zone", "qg")
  ctx.check(ok == true, "zone de l'anneau court : qg", tostring(ok))
end
return base
