--[[
  Scénario GREFFÉ « t2-machines » (lot V3-T2) : les contrôles du greffon checks/levels_machines.lua (emprise
  croissante des machines, du laser et du centre) joués TÔT (tick 60) et seuls, pour que la session avec images
  (fo-captures.bat t2-machines <source>) photographie les machines APRÈS leur agrandissement. Dans le banc content,
  le greffon agit au tick 1750, après les captures de la galerie : ses vues montreraient l'état d'avant.
  Format : tools/autotest/README.md §4.
]]

local Machines = require("checks/levels_machines").module

local ZONE = { x0 = 588, y0 = 240, x1 = 716, y1 = 336 }
local ACT = 60

local function with_zone(ctx)
  ctx.zone = ZONE
  return ctx
end

return {
  description = "V3-T2 : machines, laser et centre agrandis sur place (controles du greffon levels_machines, tick 60)",
  base = nil,
  check_tick = 1400,
  shots_delay = 1450, -- captures après la vérification : machines agrandies, contours effacés

  init = function(ctx)
    with_zone(ctx)
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    ctx.prepare_area(ZONE.x0, ZONE.y0, ZONE.x1, ZONE.y1, "grass-1")
    local foes = 0
    for _, en in ipairs(ctx.surface().find_entities_filtered({ area = { { ZONE.x0 - 64, ZONE.y0 - 64 }, { ZONE.x1 + 64, ZONE.y1 + 64 } }, force = "enemy" })) do
      if en.valid then en.destroy(); foes = foes + 1 end
    end
    ctx.log("ennemis retires autour de la zone : " .. foes)
    Machines.setup(ctx)
  end,

  tick = function(ctx, e)
    with_zone(ctx)
    if e.tick == ACT then Machines.act(ctx) elseif e.tick == ACT + 2 then Machines.after(ctx) end
  end,

  finish = function(ctx)
    Machines.verify(with_zone(ctx))
  end,

  shots = function(ctx, add)
    with_zone(ctx)
    Machines.shots(ctx, add)
    -- Gros plans : assembleur 4×4 et son tuyau, foreuse 4×4, four 3×3, laser 3×3, centre 15 (8×8), chaînes au 30.
    add("gros-plan-assembleur-foreuse", ZONE.x0 + 25, ZONE.y0 + 22, 1.6, 0)
    add("gros-plan-four-laser", ZONE.x0 + 82, ZONE.y0 + 22, 1.6, 0)
    add("gros-plan-chaines-30", ZONE.x0 + 37, ZONE.y0 + 78, 1.4, 0)
    add("gros-plan-centre-15", ZONE.x0 + 78, ZONE.y0 + 78, 1.4, 0)
  end,
}
