--[[
  Lot PERIMETRE : TÉMOIN de la mesure [FO-PERIMETRE] sur la partie du guide (verif-guide, 4 ouvriers par faction) : la même partie, la règle
  du périmètre ÉTEINTE pour votre équipe dès l'init (interface fo-perimetre, set_enabled), la mesure gardée (lecture seule). Les lignes
  [FO-VERIF-GUIDE] « mesure minute » de votre équipe doivent être celles de la 0.6.46 (la mesure est inerte). fo-logs/2026-11-03_PERIMETRE/CRITERES.md.
  Lancement : banc.py --out <archive> --graine <g> --qui PERIMETRE -- 216000 verif-guide-perim-temoin <source>.
]]
local base = require("scenarios/verif_guide_common")(4)
local init0 = base.init
base.description = "PERIMETRE : temoin de la mesure (partie du guide, regle du perimetre eteinte)"
base.init = function(ctx)
  init0(ctx)
  local ok = ctx.remote("fo-perimetre", "set_enabled", "player", false)
  ctx.check(ok == true, "regle du perimetre eteinte pour votre equipe des l'init", tostring(ok))
end
return base
