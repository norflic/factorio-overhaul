--[[
  Lot EXPLO (diagnostic) : carte ASCII du terrain autour du QG de chaque faction et de votre coffre, pour comprendre les
  fins d'éclaireur sur « chemin » (eau, falaise, nid). Cellule de 12 tuiles : w eau, c falaise à 6 tuiles, e ennemi à
  24 tuiles, # chunk non généré, . libre, H le QG. Lignes « [FO-EXPLO-CARTE] ». Lancement : banc.py -- 1200 explo-carte <source>.
]]
local base = require("scenarios/verif_guide_common")(30)
local tick0 = base.tick
local R, STEP = 336, 12

local function dump(ctx, label, c)
  local s = ctx.surface()
  s.request_to_generate_chunks(c, math.ceil(R / 32) + 1)
  s.force_generate_chunk_requests()
  log(string.format("[FO-EXPLO-CARTE] %s centre (%d, %d), cellule %d, rayon %d", label, c.x, c.y, STEP, R))
  for y = -R, R, STEP do
    local row = {}
    for x = -R, R, STEP do
      local p = { x = c.x + x, y = c.y + y }
      local ch
      if not s.is_chunk_generated({ x = math.floor(p.x / 32), y = math.floor(p.y / 32) }) then
        ch = "#"
      elseif x == 0 and y == 0 then
        ch = "H"
      elseif s.get_tile(p.x, p.y).collides_with("water-tile") then
        ch = "w"
      elseif s.count_entities_filtered({ position = p, radius = 6, type = "cliff", limit = 1 }) > 0 then
        ch = "c"
      elseif s.count_entities_filtered({ position = p, radius = 24, force = "enemy", limit = 1 }) > 0 then
        ch = "e"
      else
        ch = "."
      end
      row[#row + 1] = ch
    end
    log("[FO-EXPLO-CARTE] " .. string.format("%5d ", c.y + y) .. table.concat(row))
  end
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick == 700 then
    local s = ctx.surface()
    for _, hq in ipairs(s.find_entities_filtered({ name = "fo-faction-hq" })) do dump(ctx, hq.force.name, hq.position) end
    local chest = s.find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
    if chest then dump(ctx, "player", chest.position) end
  end
end
base.description = "EXPLO : cartes ASCII du terrain autour des QG"
return base
