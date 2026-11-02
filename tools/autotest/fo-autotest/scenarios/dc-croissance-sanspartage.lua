-- Lot BRIQUES (2/11) : TEMOIN INTERNE de la partie dc-croissance pour la regle de partage des fours (shared/team/chaine_main.lua, C.releases) :
-- meme partie, meme code, mais l'interrupteur fo-ia1 set_regle_partage est coupe sur toutes les equipes (comportement de 0.6.37).
-- Lancement : banc.py --out <archive> --graine <g> --qui BRIQUES -- 217000 dc-croissance-sanspartage <source>
local base = require("scenarios/dc_evolution_common")(860000)
local tick0 = base.tick
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick % 600 == 30 and e.tick <= 3000 then pcall(remote.call, "fo-ia1", "set_regle_partage", "*", false) end
end
return base
