--[[
  Lot GISEMENTS-GEANTS : micro-banc de etape1-geants (3 000 ticks, contrôles au tick 2 900) : prouve que le scénario se charge, que les
  gisements immenses existent (taille, distance au QG, forme, richesse, minerai présent) et que le RELEVÉ [FO-GEANTS] compte juste
  (témoin : gisement synthétique, 2 foreuses électriques sur un tapis, 1 thermique sur un autre tapis, 1 thermique dans un coffre).
  Relevé toutes les 600 ticks. Les contrôles de la partie du guide (fer livré, 59 minutes...) n'ont pas de sens à 3 000 ticks : seuls
  ceux des gisements sont joués.
  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui <lot> -- 3000 etape1-geants-court <source>
]]

local G = require("scenarios/geants_common")
local guide = require("scenarios/etape1-guide")

local base = {}
for k, v in pairs(guide) do base[k] = v end
local tick0 = guide.tick

base.description = "ETAPE1-GEANTS-COURT : gisements immenses et releve [FO-GEANTS], 3 000 ticks"
base.check_tick = 2900
base.shots = nil
base.shots_delay = nil

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  G.on_tick(ctx, e, { every = 600, control = true })
end

base.finish = function(ctx)
  G.checks(ctx, { control = true })
end

return base
