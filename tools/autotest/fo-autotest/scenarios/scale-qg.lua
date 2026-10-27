--[[
  Lot SCALE (correction après revue, 27/10) : le QG des factions à 30 PNJ, à 45 min de jeu, VU ET MESURÉ. Revue adverse :
  « rien ne montre visuellement ce changement : aucune capture du QG avec 15 fours et 6 laboratoires ».
  Partie : protocole ia1b-scale30 (scenarios/ia1b_scale_common.lua, N = 30 : frein levé, financées, Paisible) ; fonderie
  (jusqu'à 15 fours) et laboratoires (jusqu'à 6) posés par shared/ai3/places.lua (pas = emprise du prototype).
  Au tick CHECK (45 min) : par faction, fours et laboratoires à moins de 40 tuiles du QG, chacun avec sa position par
  rapport au QG, et les CHEVAUCHEMENTS de boîtes de collision (jamais) ; journal [FO-SCALE-QG].
  Session avec images : ×8 jusqu'à SHOTS - 600, puis ×1 ; au tick SHOTS : une capture du QG de chaque faction (zoom 1,
  1920 × 1080, jour) et une vue serrée de la fonderie et des laboratoires (zoom 2).
  Lancement : banc.py --out <archive> --captures --visuel="--ticks 164500 --timeout 5400" --qui SCALE -- 164500 scale-qg <source>
  Sans images (banc.py -- 162100 scale-qg <source>) : les contrôles seulement.
]]
local base = require("scenarios/ia1b_scale_common")(30)

local MIN = 3600
local CHECK = 45 * MIN
local SHOTS = CHECK + 60

local function boxes_overlap(a, b)
  return a.left_top.x < b.right_bottom.x - 0.01 and b.left_top.x < a.right_bottom.x - 0.01
    and a.left_top.y < b.right_bottom.y - 0.01 and b.left_top.y < a.right_bottom.y - 0.01
end

local function layout(ctx, f)
  local s = ctx.surface()
  local force = "fo-" .. f.key
  local found = s.find_entities_filtered({ position = f.hq, radius = 40, type = { "furnace", "lab" }, force = force })
  table.sort(found, function(a, b)
    if a.type ~= b.type then return a.type < b.type end
    if a.position.y ~= b.position.y then return a.position.y > b.position.y end
    return a.position.x < b.position.x
  end)
  local n = { furnace = 0, lab = 0 }
  local parts = { furnace = {}, lab = {} }
  for _, e in ipairs(found) do
    n[e.type] = n[e.type] + 1
    local p = parts[e.type]
    p[#p + 1] = string.format("(%g, %g)", e.position.x - f.hq.x, e.position.y - f.hq.y)
  end
  local over = 0
  for i = 1, #found do
    for j = i + 1, #found do
      if boxes_overlap(found[i].bounding_box, found[j].bounding_box) then over = over + 1 end
    end
  end
  return n, parts, over, found
end

return {
  description = "SCALE : QG des factions a 30 PNJ a 45 min (fonderie et laboratoires en rangees), captures",
  base = nil,
  check_tick = CHECK,
  shots_delay = SHOTS,

  init = base.init,

  tick = function(ctx, e)
    base.tick(ctx, e)
    if #game.connected_players == 0 then return end
    local want = e.tick < SHOTS - 600 and 8 or 1
    if game.speed ~= want then game.speed = want end
  end,

  finish = function(ctx)
    local poi = ctx.call("points_of_interest")
    local total_f, total_l, total_over = 0, 0, 0
    for _, f in ipairs(poi.factions) do
      local n, parts, over = layout(ctx, f)
      total_f, total_l, total_over = total_f + n.furnace, total_l + n.lab, total_over + over
      ctx.log(string.format("%s : QG (%d, %d) ; %d four(s) %s ; %d laboratoire(s) %s ; chevauchements %d", f.key,
        f.hq.x, f.hq.y, n.furnace, table.concat(parts.furnace, " "), n.lab, table.concat(parts.lab, " "), over))
    end
    ctx.check(#poi.factions >= 1, "factions vivantes a 45 min", #poi.factions)
    ctx.check(total_over == 0, "aucune machine du QG sur une autre (boites de collision)", total_over)
    ctx.check(total_f > 0 and total_l > 0, "fours et laboratoires poses aux QG", total_f .. " fours, " .. total_l .. " laboratoires")
  end,

  shots = function(ctx, add)
    local poi = ctx.call("points_of_interest")
    for _, f in ipairs(poi.factions) do
      add("qg-" .. f.key, f.hq.x, f.hq.y - 6, 1, 0, { res = { 1920, 1080 } })
      add("fonderie-" .. f.key, f.hq.x + 15, f.hq.y - 11, 2, 0, { res = { 1920, 1080 } })
      add("laboratoires-" .. f.key, f.hq.x - 16, f.hq.y - 11, 2, 0, { res = { 1920, 1080 } })
      local n, _, over = layout(ctx, f)
      ctx.log(string.format("capture %s : %d four(s), %d laboratoire(s), chevauchements %d", f.key, n.furnace, n.lab, over))
    end
  end,
}
