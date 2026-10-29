--[[
  Lot DEFENSE-CHOIX : état de la base d'une FACTION (menacée ou envahie), relu dans le moteur et jugé par la règle pure
  shared/team/defchoix.lua (Dc.base). Aucun état écrit ici : f.threatened_until est écrit par script/faction/commander.lua (perte près du
  QG), f.hq_lethal_tick par script/team/worker.lua (QG occupé) ; les unités ennemies sont comptées à chaque appel (limit = 1).
  Lecteurs : script/team/team.lua (view.base_alert -> shared/team/planner.lua, tourelles du QG avant les soldats) et script/faction/pvp.lua
  (aucune attaque contre une autre faction tant que la base n'est pas sûre).
]]
local Dc = require("shared.team.defchoix")
local T = require("shared.team.config")

local DefChoix = {}

--- État de la base de la faction `f` à `tick` : { insecure, why, ago, invaders }.
function DefChoix.base(f, surface, tick)
  local invaders = 0
  if f.hq_pos and surface and surface.valid ~= false then
    invaders = surface.count_entities_filtered({ position = f.hq_pos, radius = Dc.BASE_R, force = "enemy", type = "unit", limit = 1 })
  end
  local b = Dc.base({ tick = tick, threatened_until = f.threatened_until, hq_lethal_tick = f.hq_lethal_tick,
    lethal_ticks = T.hq_lethal_ticks, invaders = invaders })
  b.invaders = invaders
  return b
end

return DefChoix
