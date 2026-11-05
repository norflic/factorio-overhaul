--[[
  Lot PERIMETRE2 (G3, 5/11) : la partie du DC (ageblocage-dc, graine 717152950) avec l'enceinte de votre équipe et les murs de ses avant-postes
  attaqués ALLUMÉS dès l'init (interface fo-garde, g3 : f.garde_g3), les défauts du mod inchangés ; journal [FO-PERTE] (relevés, ligne « plan »)
  et [FO-PERIMETRE]. Avant/après : ageblocage-dc-temoin (tout éteint). Le BILAN porte un contrôle de plus que ageblocage-dc (l'interrupteur).
  Lancement : banc.py --out <archive> --graine 717152950 --qui PERIMETRE2 -- 540000 ageblocage-dc-g3 <source>
]]
local base = require("scenarios/ageblocage-dc")
local init0 = base.init
base.description = "PERIMETRE2 : partie du DC, enceinte de votre equipe et murs des avant-postes attaques allumes (G3)"
base.init = function(ctx)
  init0(ctx)
  local ok = ctx.remote("fo-garde", "g3")
  ctx.check(ok == true, "enceinte de votre equipe et murs des avant-postes allumes des l'init", tostring(ok))
end
return base
