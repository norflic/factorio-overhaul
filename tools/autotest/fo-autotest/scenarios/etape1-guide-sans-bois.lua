--[[
  Lot CORR-RECONSTRUIRE : A' de la mesure. Le scénario etape1-guide tel quel, MÊME code du lot, mais la récolte du bois pour les
  poteaux perdus est COUPÉE (interface fo-recon, set_gather false, reposé toutes les 300 ticks : réglage local au jeu en cours).
  La différence avec etape1-guide sur le même code est donc la seule règle ; A/A' = lot montre que l'écart est du chaos.
  Lancement : banc.py --out <archive> --graine <g> --qui RECONSTRUIRE -- 216300 etape1-guide-sans-bois <source>.
]]
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
base.description = "CORR-RECONSTRUIRE (A') : " .. tostring(base.description or "etape1-guide") .. ", recolte du bois coupee"
base.tick = function(ctx, e)
  if e.tick % 300 == 0 then pcall(ctx.remote, "fo-recon", "set_gather", false) end
  if tick0 then return tick0(ctx, e) end
end
return base
