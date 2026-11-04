--[[
  Lot PERIMETRE2 : TÉMOIN de la partie du DC (ageblocage-dc, graine 717152950) : la même partie, la garde des sites, les murs des avant-postes
  et l'enceinte de votre équipe ÉTEINTS dès l'init (interface fo-garde, temoin), le journal [FO-PERTE] gardé. Avant/après du lot PERIMETRE2.
  Lancement : banc.py --out <archive> --graine 717152950 --qui PERIMETRE2 -- 540000 ageblocage-dc-temoin <source>
]]
local base = require("scenarios/ageblocage-dc")
local init0 = base.init
base.description = "PERIMETRE2 : temoin de la partie du DC (garde des sites, murs et enceinte de votre equipe eteints)"
base.init = function(ctx)
  init0(ctx)
  local ok = ctx.remote("fo-garde", "temoin")
  ctx.check(ok == true, "garde des sites, murs et enceinte de votre equipe eteints des l'init", tostring(ok))
end
return base
