-- La partie dc-evolution, petrole des factions allume : pour chiffrer la question Q20 du DC (mur du palier 3).
local base = require("scenarios/dc-evolution")
local init0 = base.init
base.description = base.description .. ", petrole allume"
base.init = function(ctx)
  init0(ctx)
  ctx.check(ctx.remote("factorio-overhaul", "war_setting", "fo-war-petrole", true) == true, "petrole des factions allume")
end
return base
