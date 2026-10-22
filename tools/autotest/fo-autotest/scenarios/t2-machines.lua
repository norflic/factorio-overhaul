--[[
  Scénario GREFFÉ « t2-machines » (lot V3-T2) : les contrôles des greffons checks/levels_machines.lua (emprise
  croissante des machines, du laser et du centre) et checks/levels_points.lua (points de jeu servis, 4 orientations ;
  fabrication à travers le remplacement rapide ; corrections du correcteur) joués TÔT (tick 60) et seuls, pour que la
  session avec images (fo-captures.bat t2-machines <source>) photographie les machines APRÈS leur agrandissement.
  Dans le banc content, les greffons agissent aux ticks 1750 et 1760, après les captures de la galerie : leurs vues
  montreraient l'état d'avant. Les refus de levels_points sont rejoués au tick 1440 : leurs contours (300 ticks) sont
  visibles sur les images (prises à partir du tick 1450).
  Format : tools/autotest/README.md §4.
]]

local Machines = require("checks/levels_machines").module
local Pts = require("checks/levels_points").module

local ZONE = { x0 = 588, y0 = 240, x1 = 716, y1 = 336 }
local ZONE_P = { x0 = 732, y0 = 240, x1 = 860, y1 = 336 }
local ACT = 60
local RETRY = 1440

local function with_zone(ctx, z)
  ctx.zone = z or ZONE
  return ctx
end

--- Les deux greffons partagent ctx.state() : chacun a sa table propre dans l'état du scénario.
local function sub(ctx, key, z)
  local c = setmetatable({}, { __index = ctx })
  c.zone = z
  local root = ctx.state()
  root[key] = root[key] or {}
  c.state = function() return root[key] end
  return c
end

return {
  description = "V3-T2 : machines, laser et centre agrandis sur place, points de jeu servis (greffons levels_machines et levels_points, tick 60)",
  base = nil,
  check_tick = 1400,
  shots_delay = 1450, -- captures après la vérification : machines agrandies ; contours des refus rejoués au tick 1440

  init = function(ctx)
    with_zone(ctx)
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    for _, z in ipairs({ ZONE, ZONE_P }) do
      ctx.prepare_area(z.x0, z.y0, z.x1, z.y1, "grass-1")
      local foes = 0
      for _, en in ipairs(ctx.surface().find_entities_filtered({ area = { { z.x0 - 64, z.y0 - 64 }, { z.x1 + 64, z.y1 + 64 } }, force = "enemy" })) do
        if en.valid then en.destroy(); foes = foes + 1 end
      end
      ctx.log("ennemis retires autour de la zone " .. z.x0 .. " : " .. foes)
    end
    Machines.setup(sub(ctx, "machines", ZONE))
    Pts.setup(sub(ctx, "points", ZONE_P))
  end,

  tick = function(ctx, e)
    local cm, cp = sub(ctx, "machines", ZONE), sub(ctx, "points", ZONE_P)
    if e.tick == ACT then
      Machines.act(cm)
      Pts.act(cp)
    elseif e.tick == ACT + 1 then
      Pts.after1(cp)
    elseif e.tick == ACT + 2 then
      Machines.after(cm)
      Pts.after2(cp)
    elseif e.tick == RETRY then
      Pts.refusals(cp)
    end
  end,

  finish = function(ctx)
    Machines.verify(sub(ctx, "machines", ZONE))
    Pts.verify(sub(ctx, "points", ZONE_P))
  end,

  shots = function(ctx, add)
    Machines.shots(sub(ctx, "machines", ZONE), add)
    Pts.shots(sub(ctx, "points", ZONE_P), add)
    -- Gros plans : assembleur 4×4 et son tuyau, foreuse 4×4, four 3×3, laser 3×3, centre 15 (8×8), chaînes au 30.
    add("gros-plan-assembleur-foreuse", ZONE.x0 + 25, ZONE.y0 + 22, 1.6, 0)
    add("gros-plan-four-laser", ZONE.x0 + 82, ZONE.y0 + 22, 1.6, 0)
    add("gros-plan-chaines-30", ZONE.x0 + 37, ZONE.y0 + 78, 1.4, 0)
    add("gros-plan-centre-15", ZONE.x0 + 78, ZONE.y0 + 78, 1.4, 0)
    -- Points servis : foreuses tournées vers le sud et l'ouest, assembleurs à fluide (après agrandissement).
    add("gros-plan-points-foreuses", ZONE_P.x0 + 27, ZONE_P.y0 + 25, 0.6, 0)
    add("gros-plan-points-assembleurs", ZONE_P.x0 + 83, ZONE_P.y0 + 25, 0.6, 0)
  end,
}
