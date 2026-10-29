-- Lot FOURS : TEMOIN A' de etape1-guide : la regle de charge des fours et de tournee de fonte utile COUPEE pour toutes les equipes
-- (fo-ia1 set_regle_four "*" faux, repete toutes les 10 s pour les equipes nees apres). Meme code, meme partie : le comportement de 0.6.10.
-- Lancement : banc.py --out <archive> --qui FOURS --graine N -- 216300 etape1-guide-fours-off <source>.
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
base.description = base.description .. " -- TEMOIN A' : regle des fours COUPEE"
base.tick = function(ctx, e)
  if e.tick % 600 == 5 then ctx.remote("fo-ia1", "set_regle_four", "*", false) end
  if tick0 then return tick0(ctx, e) end
end
return base
