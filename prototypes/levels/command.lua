--[[
  Visuel des niveaux : CENTRE DE COMMANDEMENT (15 niveaux = 15 époques).
  Propriétaire : lot V3-a. Interface : en tête de prototypes/levels/common.lua.

  État : PROVISOIRE (lot V2). Corps de roboport complet (portes fermées) et radar sur le toit ; une antenne
  de balise à l'époque 4, une seconde et un radar agrandi à l'époque 7 ; puis le visuel provisoire commun
  (teinte d'époque, socle, reflet, halo). Ce schéma a été REJETÉ sur le design (E25) : aucun progrès visuel
  n'est revendiqué ici.
]]

local M = {}

--- Image du centre au niveau (= époque) n : roboport + radar + antennes.
local function cc_picture(n, kit)
  local rp = data.raw.roboport.roboport
  local radar = data.raw.radar.radar.pictures.layers[1]
  local beacon_top = data.raw.beacon.beacon.graphics_set.animation_list[2].animation
  local layers = {}
  for _, l in ipairs(rp.base.layers) do layers[#layers + 1] = table.deepcopy(l) end
  layers[#layers + 1] = kit.still(rp.base_patch)
  layers[#layers + 1] = kit.still(rp.door_animation_up)
  layers[#layers + 1] = kit.still(rp.door_animation_down)
  local radar_scale = n >= 7 and 0.58 or 0.46
  layers[#layers + 1] = kit.moved(kit.still(radar), -1.05, -1.45 - (n >= 7 and 0.1 or 0), radar_scale)
  if n >= 4 then layers[#layers + 1] = kit.moved(kit.still(beacon_top), 1.15, -1.25, 0.75) end
  if n >= 7 then layers[#layers + 1] = kit.moved(kit.still(beacon_top), 1.45, 0.35, 0.65) end
  return { layers = layers }
end

function M.dress(p, ctx)
  p.picture = cc_picture(ctx.level, ctx.kit)
  ctx.kit.provisional(p, ctx)
end

return M
