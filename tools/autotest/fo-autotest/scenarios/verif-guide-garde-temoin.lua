--[[
  Lot PERIMETRE2 : TÉMOIN de verif-guide (partie du guide du DC) : la même partie, la garde des sites, les murs des avant-postes et
  l'enceinte de votre équipe ÉTEINTS dès l'init (interface fo-garde, temoin : comportement de main), le journal [FO-PERTE] gardé.
  Le BILAN porte un contrôle de plus que verif-guide (l'interrupteur appliqué).
  Lancement : banc.py --out <archive> --graine 271828182 --qui PERIMETRE2 -- 216000 verif-guide-garde-temoin <source>
]]
local base = require("scenarios/verif-guide")
local init0 = base.init
base.description = "PERIMETRE2 : temoin de verif-guide (garde des sites, murs et enceinte de votre equipe eteints)"
base.init = function(ctx)
  init0(ctx)
  local ok = ctx.remote("fo-garde", "temoin")
  ctx.check(ok == true, "garde des sites, murs et enceinte de votre equipe eteints des l'init", tostring(ok))
end
return base
